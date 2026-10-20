//
//  UIBuilderController.j
//  This is the main controller for the UI Builder application.
//  It manages the data model for all elements on the canvas and acts
//  as a delegate for the UICanvasView to respond to user interactions.
//
//  Every change to the document goes through a small set of primitives that
//  register their inverse with one document-wide CPUndoManager:
//
//    - insertElement:intoParent:atIndex:   <->  _detachElement:
//    - addConnection:                      <->  removeConnection:
//    - moveElement:toIndex:                <->  moveElement:toIndex:
//    - per-key property changes            (recorded by CPConservativeDictionary)
//    - interactive drags                   (one coalesced geometry step)
//
//  Higher-level commands (add, delete, paste, group, ...) are composed from
//  these, so each of them is a single, fully redoable undo step.
//
//  By Daniel Boehringer in 2025.
//

@import <Foundation/CPObject.j>
@class UIElementView
@import "UICanvasView.j"
@import "UIBuilderConstants.j";
@import "CappusanceCodec.j";

// Recorded for interactive drags (markupKeys: a resize fixes the size in the markup).
var UIBGeometryKeys = ["originX", "originY", "width", "height", "markupKeys"];

// Builder defaults for an element type (view class defaults + Cappusance schema).
function UIBDefaultsForType(aType)
{
    return [CappusanceCodec defaultsForType:aType];
}

function UIBIsLayoutType(aType)
{
    return !!UIBLayoutElementTypes[aType];
}

// A vbox stacks rows. Anything that is not a row (or a vertical spacer, a
// nested vbox or a big view) gets wrapped in an hbox before it goes into a vbox.
function UIBVBoxAcceptsDirectly(aType)
{
    return aType === "hbox" || aType === "vbox" || aType === "vspace" || aType === "box" ||
           aType === "scrollView" || aType === "splitView" || aType === "tabView";
}

// Containers that stack their children vertically.
function UIBIsVerticalStackType(aType)
{
    return aType === "vbox" || aType === "tabViewItem";
}

// This is a simple data model. In a real app, it might have more properties.
// We use a custom dictionary to ensure KVO compatibility and proper value setting.
// It also reports every value change to UIBModelUndoDelegate, which is how
// edits made through bindings (e.g. in the inspector) become undoable.
@implementation CPConservativeDictionary : CPDictionary
{ }

- (id)init
{
    self = [super init];
    if (self) {
        // Rely on superclass to initialize _buckets
    }
    return self;
}

+ (id)dictionary
{
    return [[self alloc] init];
}

- (void)setValue:(id)aVal forKey:(CPString)aKey
{
    var currentValue = [super valueForKey:aKey];

    // Geometry must stay numeric; ignore garbage (e.g. a cleared inspector field).
    if (UIBNumericKeys[aKey])
    {
        if (aVal === nil || aVal === undefined || aVal === "")
        {
            // Some numbers (a window's x/y) may be removed again.
            if (UIBClearableNumericKeys[aKey] && currentValue !== nil && currentValue !== undefined)
            {
                if (UIBModelUndoDelegate)
                    [UIBModelUndoDelegate dataObject:self willChangeValueForKey:aKey fromValue:currentValue];
                [self removeObjectForKey:aKey];
            }
            return;
        }

        aVal = Number(aVal);

        if (isNaN(aVal))
            return;
    }

    // Checkboxes bound to boolean properties deliver 0/1.
    if (typeof currentValue === "boolean" && typeof aVal === "number")
        aVal = !!aVal;

    // Only set the value if it's different from the current value
    if (currentValue !== null && currentValue !== undefined && currentValue == aVal && typeof currentValue === typeof aVal)
        return;

    if (UIBModelUndoDelegate && !UIBStructuralKeys[aKey])
        [UIBModelUndoDelegate dataObject:self willChangeValueForKey:aKey fromValue:currentValue];

    [super setValue:aVal forKey:aKey];
}

- (BOOL)isEqual:(id)otherObject
{
    if (self === otherObject)
        return YES;

    if (!otherObject || !otherObject.isa || ![otherObject respondsToSelector:@selector(valueForKey:)])
        return NO;

    return [self valueForKey:'id'] == [otherObject valueForKey:'id'];
}

- (id)initWithCoder:(CPCoder)aCoder
{
    self = [super initWithCoder:aCoder];
    if (self)
    {
        var allKeys = [aCoder decodeObjectForKey:@"CPConservativeDictionaryKeys"];
        if (allKeys)
        {
            for (var i = 0; i < [allKeys count]; i++)
            {
                var key = allKeys[i];
                var value = [aCoder decodeObjectForKey:key];
                [self setObject:value forKey:key];
            }
        }
    }
    return self;
}

- (void)encodeWithCoder:(CPCoder)aCoder
{
    [super encodeWithCoder:aCoder];
    var allKeys = [self allKeys];
    [aCoder encodeObject:allKeys forKey:@"CPConservativeDictionaryKeys"];
    for (var i = 0; i < [allKeys count]; i++)
    {
        var key = allKeys[i];
        [aCoder encodeObject:[self objectForKey:key] forKey:key];
    }
}

@end


@implementation UIBuilderController : CPViewController
{
    CPArrayController _elementsController @accessors(property=elementsController);
    CPArrayController _connectionsController @accessors(property=connectionsController);
    UICanvasView      _canvasView @accessors(property=canvasView);
    CPUndoManager     _undoManager;
    BOOL              _documentEdited @accessors(getter=isDocumentEdited);

    int               _elementCounter; // To generate unique IDs
    JSObject          _elementsByID;   // id -> data object, for every element in the document

    // Cappusance document state
    id                _ownerElement;
    CappusanceCodec   _codec;
    CPArray           _markupOrder;         // top-level order of the imported document
    CPArray           _unknownConnectors;   // connectors the builder does not model

    // Data model (sort descriptors, array controllers, entities)
    CPArray           _sortDescriptors;
    CPArray           _arrayControllers;
    CPArray           _entities;
    CPArray           _modelConnectors;
    id                _modelObjects;        // Set of all model objects, for undo tracking

    // Interactive (mouse-drag) change tracking
    int               _interactiveDepth;
    CPArray           _interactiveSnapshot;
    CPArray           _interactiveInsertions;
}

+ (Class)classForElementType:(CPString)elementType
{
    return [[UIElementView classMap] objectForKey:elementType] || UIElementView;
}

- (id)init
{
    self = [super init];
    if (self) {
        _elementsController = [[CPArrayController alloc] init];
        [_elementsController setContent:[CPMutableArray array]];
        [_elementsController setSelectsInsertedObjects:NO];
        [_elementsController setAvoidsEmptySelection:NO];

        _connectionsController = [[CPArrayController alloc] init];
        [_connectionsController setContent:[CPMutableArray array]];
        [_connectionsController setSelectsInsertedObjects:NO];
        [_connectionsController setAvoidsEmptySelection:NO];
        if ([_connectionsController respondsToSelector:@selector(setClearsFilterPredicateOnInsertion:)])
            [_connectionsController setClearsFilterPredicateOnInsertion:NO];

        _elementCounter = 0;
        _elementsByID = {};
        _interactiveDepth = 0;

        _undoManager = [[CPUndoManager alloc] init];
        if ([_undoManager respondsToSelector:@selector(setLevelsOfUndo:)])
            [_undoManager setLevelsOfUndo:200];

        var center = [CPNotificationCenter defaultCenter];
        if (typeof CPUndoManagerDidUndoChangeNotification !== "undefined")
            [center addObserver:self selector:@selector(_undoManagerDidUndoOrRedo:) name:CPUndoManagerDidUndoChangeNotification object:_undoManager];
        if (typeof CPUndoManagerDidRedoChangeNotification !== "undefined")
            [center addObserver:self selector:@selector(_undoManagerDidUndoOrRedo:) name:CPUndoManagerDidRedoChangeNotification object:_undoManager];

        UIBModelUndoDelegate = self;

        _codec = [[CappusanceCodec alloc] initWithController:self];
        _markupOrder = [];
        _unknownConnectors = [];
        [self _resetDataModel];
    }
    return self;
}

- (id)ownerElement
{
    return _ownerElement;
}

// Every element of the interface (windows and their contents).
- (CPArray)allElements
{
    return [_elementsController arrangedObjects] || [];
}

- (CPUndoManager)undoManager
{
    return _undoManager;
}

#pragma mark -
#pragma mark Document State

- (void)setDocumentEdited:(BOOL)flag
{
    // KVO notifications are sent automatically for this setter.
    _documentEdited = !!flag;
}

- (void)_noteDocumentChanged
{
    if (!_documentEdited)
        [self setDocumentEdited:YES];
}

- (void)_undoManagerDidUndoOrRedo:(CPNotification)aNotification
{
    [self _noteDocumentChanged];
    [_canvasView setNeedsDisplay:YES];
}

- (void)_setActionName:(CPString)anActionName
{
    if (!anActionName || [_undoManager isUndoing] || [_undoManager isRedoing])
        return;

    if ([_undoManager respondsToSelector:@selector(groupingLevel)] && [_undoManager groupingLevel] === 0)
        return;

    [_undoManager setActionName:UIBLocalized(anActionName)];
}

- (CPString)_actionNameForKey:(CPString)aKey
{
    if (aKey === @"originX" || aKey === @"originY")
        return @"Move";
    if (aKey === @"width" || aKey === @"height")
        return @"Resize";
    if (aKey === @"value")
        return @"Change Value";

    // "horizontalTextAlign" -> "Change Horizontal Text Align"
    var words = String(aKey).replace(/([a-z0-9])([A-Z])/g, "$1 $2");
    return @"Change " + words.charAt(0).toUpperCase() + words.substring(1);
}

#pragma mark -
#pragma mark Undo Primitives

// Called by CPConservativeDictionary before any non-structural value change.
- (void)dataObject:(id)anObject willChangeValueForKey:(CPString)aKey fromValue:(id)oldValue
{
    if (UIBUndoSuppressionCount > 0)
        return;

    // Only objects that are part of the document are tracked. Freshly built
    // elements (not inserted yet) and detached ones are ignored.
    if (_elementsByID[[anObject objectForKey:@"id"]] !== anObject && !(_modelObjects && _modelObjects.has(anObject)))
        return;

    [[_undoManager prepareWithInvocationTarget:self] _setValue:oldValue forKey:aKey ofElement:anObject];
    [self _setActionName:[self _actionNameForKey:aKey]];
    [self _noteDocumentChanged];

    // What the user changes is written to the markup from now on.
    if (aKey !== "markupKeys" && aKey !== "originX" && aKey !== "originY" && aKey !== "extraAttributes" &&
        ![_undoManager isUndoing] && ![_undoManager isRedoing])
        [self _markKeys:[aKey] forMarkupOfElement:anObject];
}

- (void)_markKeys:(CPArray)keys forMarkupOfElement:(id)anElement
{
    var markupKeys = ([anElement valueForKey:@"markupKeys"] || []).slice(),
        changed = NO;

    for (var i = 0; i < keys.length; i++)
        if (markupKeys.indexOf(keys[i]) < 0)
        {
            markupKeys.push(keys[i]);
            changed = YES;
        }

    if (changed)
        [anElement setValue:markupKeys forKey:@"markupKeys"];
}

// Undo target for per-key changes. The value change itself registers the
// inverse again (through dataObject:willChangeValueForKey:fromValue:), which
// is what makes redo work.
- (void)_setValue:(id)aValue forKey:(CPString)aKey ofElement:(id)anElement
{
    if (aValue === nil || aValue === undefined)
    {
        var current = [anElement valueForKey:aKey];
        if (current === nil || current === undefined)
            return;

        // Record the inverse manually, removeObjectForKey: bypasses setValue:forKey:
        if (UIBUndoSuppressionCount === 0 && (_elementsByID[[anElement objectForKey:@"id"]] === anElement || _modelObjects.has(anElement)))
            [[_undoManager prepareWithInvocationTarget:self] _setValue:current forKey:aKey ofElement:anElement];

        [anElement removeObjectForKey:aKey];
    }
    else
        [anElement setValue:aValue forKey:aKey];

    if (_modelObjects.has(anElement))
        [self _postDataModelChange];
    else
        [self _relayoutElement:[self parentOfElement:anElement]];
}

- (void)_registerUndoForInsertionOfElement:(id)elementData
{
    if (UIBUndoSuppressionCount > 0)
    {
        // Elements created while dragging (spacers) are undone together with the drag.
        if (_interactiveDepth > 0 && _interactiveInsertions)
            [_interactiveInsertions addObject:elementData];
        return;
    }

    [[_undoManager prepareWithInvocationTarget:self] _detachElement:elementData];
    [self _noteDocumentChanged];
}

/*!
    Inserts an element (and its whole subtree) into the document. This is the
    only way elements enter the document. Undo: _detachElement:.
*/
- (void)insertElement:(id)elementData intoParent:(id)parentData atIndex:(int)anIndex
{
    if (!elementData)
        return;

    if (parentData)
    {
        var children = [parentData valueForKey:@"children"];
        if (!children)
        {
            children = [];
            [parentData setValue:children forKey:@"children"];
        }

        var existingIndex = children.indexOf(elementData);
        if (existingIndex >= 0)
            children.splice(existingIndex, 1);

        if (anIndex === nil || anIndex === undefined || anIndex < 0 || anIndex > children.length)
            anIndex = children.length;

        children.splice(anIndex, 0, elementData);
        [elementData setValue:[parentData valueForKey:@"id"] forKey:@"parentID"];
    }
    else
        [elementData removeObjectForKey:@"parentID"];

    var subtree = [self _subtreeOfElement:elementData normalizingParents:YES];
    for (var i = 0; i < subtree.length; i++)
        _elementsByID[[subtree[i] valueForKey:@"id"]] = subtree[i];

    [_elementsController addObjects:subtree];
    [self _relayoutElement:parentData];
    [_canvasView setNeedsDisplay:YES];

    [self _registerUndoForInsertionOfElement:elementData];
}

/*!
    Takes an element (and its whole subtree) out of the document, keeping its
    connections. Undo: insertElement:intoParent:atIndex: at the same place.
*/
- (void)_detachElement:(id)elementData
{
    if (!elementData || _elementsByID[[elementData valueForKey:@"id"]] !== elementData)
        return;

    var parentData = [self parentOfElement:elementData],
        index = -1;

    if (parentData)
    {
        var children = [parentData valueForKey:@"children"] || [];
        index = children.indexOf(elementData);
        if (index >= 0)
            children.splice(index, 1);
    }

    var subtree = [self _subtreeOfElement:elementData normalizingParents:NO];
    for (var i = 0; i < subtree.length; i++)
        delete _elementsByID[[subtree[i] valueForKey:@"id"]];

    var previousSelection = [[_elementsController selectedObjects] copy] || [];

    [_elementsController removeObjects:subtree];

    var remainingSelection = [];
    for (var i = 0; i < previousSelection.length; i++)
        if (subtree.indexOf(previousSelection[i]) < 0)
            remainingSelection.push(previousSelection[i]);
    [_elementsController setSelectedObjects:remainingSelection];

    [self _relayoutElement:parentData];
    [_canvasView setNeedsDisplay:YES];

    if (UIBUndoSuppressionCount === 0)
    {
        [[_undoManager prepareWithInvocationTarget:self] insertElement:elementData intoParent:parentData atIndex:index];
        [self _noteDocumentChanged];
    }
}

/*!
    Deletes an element: removes all connections from/to its subtree and
    detaches it. Undo restores both.
*/
- (void)removeElement:(id)elementData
{
    if (!elementData || _elementsByID[[elementData valueForKey:@"id"]] !== elementData)
        return;

    var subtree = [self _subtreeOfElement:elementData normalizingParents:NO],
        ids = {};

    for (var i = 0; i < subtree.length; i++)
        ids[[subtree[i] valueForKey:@"id"]] = YES;

    var connections = [self allConnections];
    for (var i = 0; i < connections.length; i++)
    {
        var connection = connections[i];
        if (ids[[connection valueForKey:@"sourceID"]] || ids[[connection valueForKey:@"targetID"]])
            [self removeConnection:connection];
    }

    [self _detachElement:elementData];
}

/*!
    Reorders an element among its siblings. Undo: the same with the old index.
*/
- (void)moveElement:(id)elementData toIndex:(int)newIndex
{
    var parentData = [self parentOfElement:elementData];
    if (!parentData)
        return;

    var children = [parentData valueForKey:@"children"],
        oldIndex = children.indexOf(elementData);

    newIndex = MAX(0, MIN(newIndex, children.length - 1));

    if (oldIndex < 0 || oldIndex === newIndex)
        return;

    children.splice(oldIndex, 1);
    children.splice(newIndex, 0, elementData);

    // Recreate the views so they are stacked (and laid out) in the new order.
    var subtree = [self _subtreeOfElement:elementData normalizingParents:NO],
        selection = [[_elementsController selectedObjects] copy] || [];

    [_elementsController removeObjects:subtree];
    [_elementsController addObjects:subtree];
    [_elementsController setSelectedObjects:selection];

    [self _relayoutElement:parentData];

    if (UIBUndoSuppressionCount === 0)
    {
        [[_undoManager prepareWithInvocationTarget:self] moveElement:elementData toIndex:oldIndex];
        [self _noteDocumentChanged];
    }
}

- (void)addConnection:(id)aConnection
{
    if (!aConnection)
        return;

    [_connectionsController addObject:aConnection];
    [_connectionsController rearrangeObjects];
    [_canvasView setNeedsDisplay:YES];

    if (UIBUndoSuppressionCount === 0)
    {
        [[_undoManager prepareWithInvocationTarget:self] removeConnection:aConnection];
        [self _noteDocumentChanged];
    }
}

- (void)removeConnection:(id)aConnection
{
    if (!aConnection || [[self allConnections] indexOfObjectIdenticalTo:aConnection] == CPNotFound)
        return;

    [_connectionsController removeObject:aConnection];
    [_canvasView setNeedsDisplay:YES];

    if (UIBUndoSuppressionCount === 0)
    {
        [[_undoManager prepareWithInvocationTarget:self] addConnection:aConnection];
        [self _noteDocumentChanged];
    }
}

- (void)removeConnections:(CPArray)connections
{
    connections = [connections copy] || [];
    if (connections.length === 0)
        return;

    for (var i = 0; i < connections.length; i++)
        [self removeConnection:connections[i]];

    [self _setActionName:connections.length === 1 ? @"Delete Connection" : @"Delete Connections"];
}

// All connections, regardless of the filter the inspector puts on the controller.
- (CPArray)allConnections
{
    return [[_connectionsController content] copy] || [];
}

#pragma mark -
#pragma mark Interactive Changes (mouse drags)

- (CPArray)_geometrySnapshot
{
    var snapshot = [];
    for (var elementID in _elementsByID)
    {
        if (!_elementsByID.hasOwnProperty(elementID))
            continue;

        var element = _elementsByID[elementID],
            record = { element: element };

        for (var i = 0; i < UIBGeometryKeys.length; i++)
            record[UIBGeometryKeys[i]] = [element valueForKey:UIBGeometryKeys[i]];

        snapshot.push(record);
    }
    return snapshot;
}

- (CPArray)_currentGeometryForRecords:(CPArray)records
{
    var result = [];
    for (var i = 0; i < records.length; i++)
    {
        var element = records[i].element,
            record = { element: element };

        for (var j = 0; j < UIBGeometryKeys.length; j++)
            record[UIBGeometryKeys[j]] = [element valueForKey:UIBGeometryKeys[j]];

        result.push(record);
    }
    return result;
}

// Undo target for interactive changes: applies a geometry snapshot and
// registers the current geometry as the inverse.
- (void)_applyGeometry:(CPArray)records
{
    if (UIBUndoSuppressionCount === 0)
        [[_undoManager prepareWithInvocationTarget:self] _applyGeometry:[self _currentGeometryForRecords:records]];

    [self _applyGeometryWithoutUndo:records];
}

- (void)_applyGeometryWithoutUndo:(CPArray)records
{
    UIBPerformWithoutUndo(function()
    {
        for (var i = 0; i < records.length; i++)
        {
            var record = records[i];
            for (var j = 0; j < UIBGeometryKeys.length; j++)
            {
                var key = UIBGeometryKeys[j];
                if (record[key] !== nil && record[key] !== undefined)
                    [record.element setValue:record[key] forKey:key];
                else if (key === "markupKeys")
                    [record.element setValue:[] forKey:key];
            }
        }
    });

    for (var i = 0; i < records.length; i++)
    {
        var view = [_canvasView viewForElementWithID:[records[i].element valueForKey:@"id"]];
        if (view)
            [view invalidateLayoutUpwards];
    }
    [_canvasView setNeedsLayout:YES];
    [_canvasView setNeedsDisplay:YES];
}

/*!
    Called by the canvas when a mouse drag (move, resize, connect) starts.
    Until the matching end, model changes are not recorded one by one; the
    whole drag becomes a single undo step.
*/
- (void)beginInteractiveChange
{
    if (_interactiveDepth++ > 0)
        return;

    _interactiveSnapshot = [self _geometrySnapshot];
    _interactiveInsertions = [];
    UIBUndoSuppressionCount++;
}

- (void)endInteractiveChangeWithActionName:(CPString)anActionName
{
    if (_interactiveDepth <= 0)
        return;

    if (--_interactiveDepth > 0)
        return;

    UIBUndoSuppressionCount = MAX(0, UIBUndoSuppressionCount - 1);

    var before = _interactiveSnapshot || [],
        insertions = _interactiveInsertions || [],
        changed = [],
        insertedAndAlive = [];

    _interactiveSnapshot = nil;
    _interactiveInsertions = nil;

    for (var i = 0; i < before.length; i++)
    {
        var record = before[i];
        for (var j = 0; j < UIBGeometryKeys.length; j++)
        {
            var key = UIBGeometryKeys[j];
            if ([record.element valueForKey:key] !== record[key])
            {
                changed.push(record);
                break;
            }
        }
    }

    for (var i = 0; i < insertions.length; i++)
        if (_elementsByID[[insertions[i] valueForKey:@"id"]] === insertions[i])
            insertedAndAlive.push(insertions[i]);

    if (changed.length === 0 && insertedAndAlive.length === 0)
        return;

    // Undo runs in reverse order: first the new spacers go away, then the
    // geometry is restored.
    [[_undoManager prepareWithInvocationTarget:self] _applyGeometry:changed];

    for (var i = 0; i < insertedAndAlive.length; i++)
        [[_undoManager prepareWithInvocationTarget:self] _detachElement:insertedAndAlive[i]];

    [self _setActionName:anActionName || @"Change Layout"];
    [self _noteDocumentChanged];
}

- (void)cancelInteractiveChange
{
    if (_interactiveDepth <= 0)
        return;

    var before = _interactiveSnapshot || [],
        insertions = _interactiveInsertions || [];

    _interactiveDepth = 0;
    _interactiveSnapshot = nil;
    _interactiveInsertions = nil;

    // Still suppressed: nothing of this is recorded.
    for (var i = insertions.length - 1; i >= 0; i--)
        [self _detachElement:insertions[i]];

    [self _applyGeometryWithoutUndo:before];

    UIBUndoSuppressionCount = MAX(0, UIBUndoSuppressionCount - 1);
}

#pragma mark -
#pragma mark Tree Helpers

- (CPString)_nextElementID
{
    var newID;
    do
        newID = @"id_" + _elementCounter++;
    while (_elementsByID[newID]);

    return newID;
}

// The element plus all descendants, parents before children.
- (CPArray)_subtreeOfElement:(id)elementData normalizingParents:(BOOL)normalize
{
    var result = [];
    var walk = function(element)
    {
        result.push(element);
        var children = [element valueForKey:@"children"];
        if (!children)
            return;

        for (var i = 0; i < children.length; i++)
        {
            if (normalize)
                [children[i] setValue:[element valueForKey:@"id"] forKey:@"parentID"];
            walk(children[i]);
        }
    };
    walk(elementData);
    return result;
}

- (CPDictionary)parentOfElement:(CPDictionary)elementData
{
    var parentID = [elementData valueForKey:@"parentID"];
    if (!parentID)
        return nil;

    return _elementsByID[parentID] || nil;
}

- (id)elementWithID:(CPString)anID
{
    return _elementsByID[anID] || nil;
}

- (BOOL)containsElement:(id)elementData
{
    return !!elementData && _elementsByID[[elementData valueForKey:@"id"]] === elementData;
}

- (BOOL)_isElement:(id)possibleAncestor ancestorOf:(id)elementData
{
    var parent = [self parentOfElement:elementData];
    while (parent)
    {
        if (parent === possibleAncestor)
            return YES;
        parent = [self parentOfElement:parent];
    }
    return NO;
}

- (int)_indexOfElement:(id)elementData
{
    var parentData = [self parentOfElement:elementData];
    if (!parentData)
        return -1;

    return ([parentData valueForKey:@"children"] || []).indexOf(elementData);
}

- (BOOL)_isRootContainer:(id)elementData
{
    return !!elementData && !![elementData valueForKey:@"isRootVBox"];
}

// Elements that cannot be deleted, copied or grouped.
- (BOOL)_isFixedElement:(id)elementData
{
    return [self _isRootContainer:elementData] || [elementData valueForKey:@"type"] === "owner";
}

// The selection without root containers and without elements whose ancestor
// is also selected, in document order.
- (CPArray)_topLevelSelection
{
    return [self _topLevelSelectionIncludingOwner:NO];
}

- (CPArray)_topLevelSelectionIncludingOwner:(BOOL)includeOwner
{
    var selected = [[_elementsController selectedObjects] copy] || [],
        result = [];

    for (var i = 0; i < selected.length; i++)
    {
        var element = selected[i],
            covered = NO;

        if ([self _isRootContainer:element] || ![self containsElement:element])
            continue;

        if (!includeOwner && [element valueForKey:@"type"] === "owner")
            continue;

        for (var j = 0; j < selected.length && !covered; j++)
            if (selected[j] !== element && [self _isElement:selected[j] ancestorOf:element])
                covered = YES;

        if (!covered)
            result.push(element);
    }

    var order = [_elementsController arrangedObjects];
    result.sort(function(a, b)
    {
        var parentA = [a valueForKey:@"parentID"], parentB = [b valueForKey:@"parentID"];
        if (parentA && parentA === parentB)
            return [self _indexOfElement:a] - [self _indexOfElement:b];
        return [order indexOfObjectIdenticalTo:a] - [order indexOfObjectIdenticalTo:b];
    });

    return result;
}

- (void)_relayoutElement:(id)elementData
{
    if (!elementData || !_canvasView)
        return;

    var view = [_canvasView viewForElementWithID:[elementData valueForKey:@"id"]];
    if (view)
    {
        [view setNeedsLayout:YES];
        [view setNeedsDisplay:YES];
    }
}

- (void)_selectElements:(CPArray)elements
{
    [_elementsController setSelectedObjects:elements || []];
}

#pragma mark -
#pragma mark Element Factory

/*!
    Builds the data for a new element of the given type with default values,
    a fresh ID and a sensible initial size. The element is not part of the
    document until it is passed to insertElement:intoParent:atIndex:.
*/
- (id)_newElementDataOfType:(CPString)elementType
{
    var viewClass = [UIBuilderController classForElementType:elementType],
        defaults = UIBDefaultsForType(elementType),
        data = [CPConservativeDictionary dictionary];

    [data setValue:elementType forKey:@"type"];
    [data setValue:[self _nextElementID] forKey:@"id"];

    for (var key in defaults)
        if (defaults.hasOwnProperty(key) && !UIBNumericKeys[key])
            [data setValue:defaults[key] forKey:key];

    [data setValue:[] forKey:@"markupKeys"];
    [data setValue:{} forKey:@"extraAttributes"];

    // Determine the initial size with a temporary view.
    var tempView = [[viewClass alloc] initWithFrame:CGRectMakeZero()];
    [tempView setDataObject:data];

    var size = tempView._isContainer ? [tempView frame].size : [tempView intrinsicContentSize];
    [tempView setDataObject:nil];

    var width = (size.width >= 4) ? size.width : (defaults.width || 20),
        height = (size.height >= 4) ? size.height : (defaults.height || 20);

    if (tempView._isContainer && defaults.width && defaults.height)
    {
        width = defaults.width;
        height = defaults.height;
    }

    if (elementType === "window")
    {
        width = 320;
        height = 240;
    }

    [data setValue:width forKey:@"width"];
    [data setValue:height forKey:@"height"];
    [data setValue:0 forKey:@"originX"];
    [data setValue:0 forKey:@"originY"];
    [data setValue:[] forKey:@"children"];

    if (elementType === "window" || elementType === "scrollView" || elementType === "splitView")
        [data valueForKey:@"children"].push([self _newRootVBoxForContainer:data]);

    if (elementType === "tabView")
    {
        for (var i = 1; i <= 2; i++)
        {
            var item = [self _newElementDataOfType:@"tabViewItem"];
            [item setValue:@"Tab " + i forKey:@"value"];
            [item setValue:[data valueForKey:@"id"] forKey:@"parentID"];
            [item valueForKey:@"children"].push([self _newElementDataOfType:@"vbox"]);
            [data valueForKey:@"children"].push(item);
        }
    }

    if (elementType === "box")
        [data valueForKey:@"children"].push([self _newElementDataOfType:@"vbox"]);

    return data;
}

- (CGRect)_rootFrameForContainer:(id)containerData
{
    var width = [containerData valueForKey:@"width"],
        height = [containerData valueForKey:@"height"];

    if ([containerData valueForKey:@"type"] === "window")
        return CGRectMake(0, 22, width, MAX(0, height - 22));

    return CGRectMake(0, 0, width, height);
}

- (id)_newRootVBoxForContainer:(id)containerData
{
    var vbox = [self _newElementDataOfType:@"vbox"],
        frame = [self _rootFrameForContainer:containerData];

    [vbox setValue:YES forKey:@"isRootVBox"];
    [vbox setValue:@"expand" forKey:@"halign"];
    [vbox setValue:@"expand" forKey:@"valign"];
    [vbox setValue:frame.origin.x forKey:@"originX"];
    [vbox setValue:frame.origin.y forKey:@"originY"];
    [vbox setValue:frame.size.width forKey:@"width"];
    [vbox setValue:frame.size.height forKey:@"height"];
    [vbox setValue:[containerData valueForKey:@"id"] forKey:@"parentID"];

    return vbox;
}

- (id)_newRowContainingElement:(id)elementData width:(float)aWidth
{
    var hbox = [self _newElementDataOfType:@"hbox"];
    if (aWidth > 0)
        [hbox setValue:aWidth forKey:@"width"];

    [hbox valueForKey:@"children"].push(elementData);
    [elementData setValue:[hbox valueForKey:@"id"] forKey:@"parentID"];

    return hbox;
}

// Wraps an element in a row if it cannot live directly in the given container.
- (id)_element:(id)elementData adaptedForContainer:(id)containerData
{
    if (!containerData)
        return elementData;

    var containerType = [containerData valueForKey:@"type"],
        parentType = [[self parentOfElement:containerData] valueForKey:@"type"];

    // The document view of a scroll view / the panes of a split view go in directly.
    if ([containerData valueForKey:@"isRootVBox"] && (parentType === "scrollView" || parentType === "splitView"))
        return elementData;

    if (UIBIsVerticalStackType(containerType) && !UIBVBoxAcceptsDirectly([elementData valueForKey:@"type"]))
        return [self _newRowContainingElement:elementData width:[containerData valueForKey:@"width"]];

    return elementData;
}

// Where the content of an element goes: windows, scroll views and split views
// keep their content in a root vbox, boxes and tab items in their content view
// (created on demand, as an undoable step); tab views in the visible tab.
- (id)_contentContainerOfElement:(id)elementData
{
    var type = [elementData valueForKey:@"type"],
        children = [elementData valueForKey:@"children"] || [];

    if (type === "window" || type === "scrollView" || type === "splitView")
    {
        for (var i = 0; i < children.length; i++)
            if ([children[i] valueForKey:@"isRootVBox"])
                return children[i];

        var vbox = [self _newRootVBoxForContainer:elementData];
        [self insertElement:vbox intoParent:elementData atIndex:-1];
        return vbox;
    }

    if (type === "tabView")
    {
        if (!children.length)
        {
            var item = [self _newElementDataOfType:@"tabViewItem"];
            [self insertElement:item intoParent:elementData atIndex:-1];
            return [self _contentContainerOfElement:item];
        }

        var index = MAX(0, MIN(Number([elementData valueForKey:@"selectedTabIndex"]) || 0, children.length - 1));
        return [self _contentContainerOfElement:children[index]];
    }

    if (type === "box" || type === "tabViewItem")
    {
        if (children.length === 1 && ([children[0] valueForKey:@"type"] === "vbox" || [children[0] valueForKey:@"type"] === "hbox"))
            return children[0];

        if (children.length === 0)
        {
            var content = [self _newElementDataOfType:@"vbox"];
            [self insertElement:content intoParent:elementData atIndex:-1];
            return content;
        }

        return elementData;
    }

    return elementData;
}

- (BOOL)_isContainerElement:(id)elementData
{
    var type = [elementData valueForKey:@"type"];
    return type === "window" || type === "vbox" || type === "hbox" || type === "box" || type === "scrollView" ||
           type === "splitView" || type === "tabView" || type === "tabViewItem";
}

#pragma mark -
#pragma mark Adding Elements

- (id)addNewElementOfType:(CPString)elementType atPoint:(CGPoint)aPoint inParent:(CPDictionary)parentData
{
    return [self addNewElementOfType:elementType atPoint:aPoint inParent:parentData atIndex:-1];
}

- (id)addNewElementOfType:(CPString)elementType atPoint:(CGPoint)aPoint inParent:(CPDictionary)parentData atIndex:(int)index
{
    if (!parentData || elementType === "window")
    {
        if (elementType !== "window")
            return [self addNewElementOfType:elementType inNewWindowAtPoint:aPoint];

        var windowData = [self _newElementDataOfType:@"window"];
        [windowData setValue:aPoint.x - [windowData valueForKey:@"width"] / 2 forKey:@"originX"];
        [windowData setValue:aPoint.y - [windowData valueForKey:@"height"] / 2 forKey:@"originY"];

        [self insertElement:windowData intoParent:nil atIndex:-1];
        [self _selectElements:[windowData]];
        [self _setActionName:@"Add Window"];
        return windowData;
    }

    if (elementType === "tabViewItem" && [parentData valueForKey:@"type"] === "tabView")
    {
        var newItem = [self _newElementDataOfType:@"tabViewItem"];
        [newItem valueForKey:@"children"].push([self _newElementDataOfType:@"vbox"]);
        [self insertElement:newItem intoParent:parentData atIndex:-1];
        [self _selectElements:[newItem]];
        [self _setActionName:@"Add Tab"];
        return newItem;
    }

    var newElementData = [self _newElementDataOfType:elementType],
        containerData = [self _contentContainerOfElement:parentData];

    // The drop index was computed for the view under the mouse.
    if (containerData !== parentData)
        index = -1;

    [self insertElement:[self _element:newElementData adaptedForContainer:containerData] intoParent:containerData atIndex:index];

    [self _selectElements:[newElementData]];
    [self _setActionName:@"Add " + [self _displayNameForType:elementType]];

    return newElementData;
}

- (id)addNewElementOfType:(CPString)elementType inNewWindowAtPoint:(CGPoint)aPoint
{
    var windowData = [self _newElementDataOfType:@"window"],
        rootVBox = [windowData valueForKey:@"children"][0],
        newElementData = [self _newElementDataOfType:elementType],
        child = [self _element:newElementData adaptedForContainer:rootVBox];

    [windowData setValue:aPoint.x - [windowData valueForKey:@"width"] / 2 forKey:@"originX"];
    [windowData setValue:aPoint.y - [windowData valueForKey:@"height"] / 2 forKey:@"originY"];
    [rootVBox valueForKey:@"children"].push(child);

    [self insertElement:windowData intoParent:nil atIndex:-1];
    [self _selectElements:[newElementData]];
    [self _setActionName:@"Add " + [self _displayNameForType:elementType]];

    return newElementData;
}

// Used by the canvas while dragging inside boxes. Recorded as part of the drag.
- (id)insertSpacerOfType:(CPString)spacerType inParent:(id)parentData atIndex:(int)anIndex
{
    var spacer = [self _newElementDataOfType:spacerType];

    UIBPerformWithoutUndo(function()
    {
        if (spacerType === "hspace")
        {
            [spacer setValue:0 forKey:@"width"];
            [spacer setValue:@"min" forKey:@"halign"];
        }
        else
        {
            [spacer setValue:0 forKey:@"height"];
            [spacer setValue:@"min" forKey:@"valign"];
        }
    });

    [self insertElement:spacer intoParent:parentData atIndex:anIndex];
    return spacer;
}

- (CPString)_displayNameForType:(CPString)aType
{
    var names = {
        "hbox": "HBox", "vbox": "VBox", "hspace": "Horizontal Space", "vspace": "Vertical Space",
        "progresIndicator": "Progress Indicator"
    };

    if (names[aType])
        return names[aType];

    var words = String(aType).replace(/([a-z])([A-Z])/g, "$1 $2");
    return words.charAt(0).toUpperCase() + words.substring(1);
}

#pragma mark -
#pragma mark Deleting

- (void)removeSelectedElementsWithActionName:(CPString)actionName
{
    var elements = [self _topLevelSelection];
    if (elements.length === 0)
        return;

    for (var i = elements.length - 1; i >= 0; i--)
        [self removeElement:elements[i]];

    [self _selectElements:[]];
    [self _setActionName:actionName];
}

- (void)removeSelectedElements
{
    [self removeSelectedElementsWithActionName:@"Delete"];
}

- (void)deleteElement:(CPDictionary)elementData
{
    if (![self containsElement:elementData] || [self _isFixedElement:elementData])
        return;

    [self removeElement:elementData];
    [self _setActionName:@"Delete"];
}

// Kept for compatibility with older callers.
- (void)removeElement:(CPDictionary)elementData fromParent:(CPDictionary)parentData
{
    [self removeElement:elementData];
}

#pragma mark -
#pragma mark Selection

- (void)selectAll:(id)sender
{
    // Select the siblings of the current selection, or all windows.
    var selection = [self _topLevelSelection],
        parentData = selection.length ? [self parentOfElement:selection[0]] : nil,
        candidates = parentData ? [parentData valueForKey:@"children"] : [_elementsController arrangedObjects],
        result = [];

    for (var i = 0; i < candidates.length; i++)
    {
        var element = candidates[i];
        if ([self _isRootContainer:element])
            continue;
        if (!parentData && [element valueForKey:@"parentID"])
            continue;
        result.push(element);
    }

    [self _selectElements:result];
}

- (void)selectParent:(id)sender
{
    var selection = [self _topLevelSelection];
    if (selection.length !== 1)
        return;

    var parentData = [self parentOfElement:selection[0]];
    if ([self _isRootContainer:parentData])
        parentData = [self parentOfElement:parentData];

    if (parentData)
        [self _selectElements:[parentData]];
}

#pragma mark -
#pragma mark Grouping

- (BOOL)canGroupSelection
{
    var selection = [self _topLevelSelection];
    if (selection.length < 2)
        return NO;

    var parentID = [selection[0] valueForKey:@"parentID"];
    if (!parentID)
        return NO;

    for (var i = 0; i < selection.length; i++)
    {
        if ([selection[i] valueForKey:@"parentID"] !== parentID || [selection[i] valueForKey:@"type"] === "window")
            return NO;
    }

    return YES;
}

- (BOOL)canUngroupSelection
{
    var selection = [self _topLevelSelection];
    if (selection.length !== 1)
        return NO;

    var element = selection[0],
        type = [element valueForKey:@"type"];

    return (type === "hbox" || type === "vbox" || type === "box") && !![self parentOfElement:element] && ([element valueForKey:@"children"] || []).length > 0;
}

- (void)groupSelectionInHBox:(id)sender
{
    [self _groupSelectionInContainerOfType:@"hbox" withActionName:@"Group in HBox"];
}

- (void)groupSelectionInVBox:(id)sender
{
    [self _groupSelectionInContainerOfType:@"vbox" withActionName:@"Group in VBox"];
}

- (void)_groupSelectionInContainerOfType:(CPString)containerType withActionName:(CPString)actionName
{
    if (![self canGroupSelection])
        return;

    var selection = [self _topLevelSelection],
        parentData = [self parentOfElement:selection[0]],
        parentType = [parentData valueForKey:@"type"],
        insertIndex = [self _indexOfElement:selection[0]],
        minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

    for (var i = 0; i < selection.length; i++)
    {
        var element = selection[i],
            x = [element valueForKey:@"originX"] || 0,
            y = [element valueForKey:@"originY"] || 0;

        minX = MIN(minX, x);
        minY = MIN(minY, y);
        maxX = MAX(maxX, x + ([element valueForKey:@"width"] || 0));
        maxY = MAX(maxY, y + ([element valueForKey:@"height"] || 0));
    }

    // In free-form containers the visual order decides the order in the new box.
    if (parentType !== "hbox" && parentType !== "vbox")
    {
        var sortKey = (containerType === "hbox") ? @"originX" : @"originY";
        selection.sort(function(a, b) { return [a valueForKey:sortKey] - [b valueForKey:sortKey]; });
    }

    var containerData = [self _newElementDataOfType:containerType];
    [containerData setValue:minX forKey:@"originX"];
    [containerData setValue:minY forKey:@"originY"];
    [containerData setValue:MAX(10, maxX - minX + 10) forKey:@"width"];
    [containerData setValue:MAX(10, maxY - minY + 10) forKey:@"height"];

    // 1. Make the positions relative to the new container (while still in the document, so it is recorded).
    for (var i = 0; i < selection.length; i++)
    {
        [selection[i] setValue:([selection[i] valueForKey:@"originX"] || 0) - minX forKey:@"originX"];
        [selection[i] setValue:([selection[i] valueForKey:@"originY"] || 0) - minY forKey:@"originY"];
    }

    // 2. Take them out of their current parent (highest index first).
    var byIndex = selection.slice().sort(function(a, b) { return [self _indexOfElement:b] - [self _indexOfElement:a]; });
    for (var i = 0; i < byIndex.length; i++)
        [self _detachElement:byIndex[i]];

    // 3. Fill the container and insert it where the first element was.
    var children = [containerData valueForKey:@"children"];
    for (var i = 0; i < selection.length; i++)
        children.push([self _element:selection[i] adaptedForContainer:containerData]);

    [self insertElement:[self _element:containerData adaptedForContainer:parentData] intoParent:parentData atIndex:insertIndex];

    [self _selectElements:[containerData]];
    [self _setActionName:actionName];

    var containerView = [_canvasView viewForElementWithID:[containerData valueForKey:@"id"]];
    if (containerView)
        [containerView setNeedsLayout:YES];
}

- (void)ungroupSelection:(id)sender
{
    if (![self canUngroupSelection])
        return;

    var containerData = [self _topLevelSelection][0],
        parentData = [self parentOfElement:containerData],
        index = [self _indexOfElement:containerData],
        offsetX = [containerData valueForKey:@"originX"] || 0,
        offsetY = [containerData valueForKey:@"originY"] || 0,
        children = ([containerData valueForKey:@"children"] || []).slice(),
        result = [];

    // Make the positions absolute again (while still in the document, so it is recorded).
    for (var i = 0; i < children.length; i++)
    {
        [children[i] setValue:([children[i] valueForKey:@"originX"] || 0) + offsetX forKey:@"originX"];
        [children[i] setValue:([children[i] valueForKey:@"originY"] || 0) + offsetY forKey:@"originY"];
    }

    [self _detachElement:containerData];

    for (var i = 0; i < children.length; i++)
    {
        var child = [self _element:children[i] adaptedForContainer:parentData];
        [self insertElement:child intoParent:parentData atIndex:index + i];
        result.push(children[i]);
    }

    [self _selectElements:result];
    [self _setActionName:@"Ungroup"];
}

#pragma mark -
#pragma mark Ordering

- (BOOL)canMoveSelectionBy:(int)aDelta
{
    var selection = [self _topLevelSelection];
    if (selection.length !== 1)
        return NO;

    var parentData = [self parentOfElement:selection[0]];
    if (!parentData)
        return NO;

    var index = [self _indexOfElement:selection[0]] + aDelta;
    return index >= 0 && index < ([parentData valueForKey:@"children"] || []).length;
}

- (void)moveSelectionEarlier:(id)sender
{
    if (![self canMoveSelectionBy:-1])
        return;

    var element = [self _topLevelSelection][0];
    [self moveElement:element toIndex:[self _indexOfElement:element] - 1];
    [self _setActionName:@"Move Earlier"];
}

- (void)moveSelectionLater:(id)sender
{
    if (![self canMoveSelectionBy:1])
        return;

    var element = [self _topLevelSelection][0];
    [self moveElement:element toIndex:[self _indexOfElement:element] + 1];
    [self _setActionName:@"Move Later"];
}

#pragma mark -
#pragma mark Keyboard Movement

- (void)moveSelectedElementsByDeltaX:(int)deltaX deltaY:(int)deltaY
{
    var selection = [self _topLevelSelection];
    if (selection.length === 0)
        return;

    for (var i = 0; i < selection.length; i++)
    {
        var data = selection[i];
        [data setValue:([data valueForKey:@"originX"] || 0) + deltaX forKey:@"originX"];
        [data setValue:([data valueForKey:@"originY"] || 0) + deltaY forKey:@"originY"];
    }

    [self _setActionName:@"Move"];
    [_canvasView setNeedsDisplay:YES];
}

- (void)moveLeft:(id)sender  { [self moveSelectedElementsByDeltaX:-1 deltaY:0]; }
- (void)moveRight:(id)sender { [self moveSelectedElementsByDeltaX:1 deltaY:0]; }
- (void)moveUp:(id)sender    { [self moveSelectedElementsByDeltaX:0 deltaY:-1]; }
- (void)moveDown:(id)sender  { [self moveSelectedElementsByDeltaX:0 deltaY:1]; }

- (void)moveLeftAndModifySelection:(id)sender  { [self moveSelectedElementsByDeltaX:-10 deltaY:0]; }
- (void)moveRightAndModifySelection:(id)sender { [self moveSelectedElementsByDeltaX:10 deltaY:0]; }
- (void)moveUpAndModifySelection:(id)sender    { [self moveSelectedElementsByDeltaX:0 deltaY:-10]; }
- (void)moveDownAndModifySelection:(id)sender  { [self moveSelectedElementsByDeltaX:0 deltaY:10]; }

#pragma mark -
#pragma mark Copy & Paste

- (JSObject)_plainObjectForElement:(id)elementData
{
    var result = {},
        keys = [elementData allKeys];

    for (var i = 0; i < [keys count]; i++)
    {
        var key = keys[i],
            value = [elementData objectForKey:key];

        if (key === "parentID" || value === nil || value === undefined)
            continue;

        if (key === "children")
        {
            result.children = [];
            for (var j = 0; j < value.length; j++)
                result.children.push([self _plainObjectForElement:value[j]]);
        }
        else if (typeof value !== "object")
            result[key] = value;
        else if (!value.isa)
            result[key] = JSON.parse(JSON.stringify(value));
    }

    return result;
}

- (id)_elementFromPlainObject:(JSObject)anObject
{
    var data = [CPConservativeDictionary dictionary];

    for (var key in anObject)
    {
        // Copies get no markup id: ids must stay unique.
        if (!anObject.hasOwnProperty(key) || key === "children" || key === "parentID" || key === "identifier")
            continue;

        [data setValue:anObject[key] forKey:key];
    }

    // Fresh identity for the copy.
    [data setValue:[self _nextElementID] forKey:@"id"];

    var children = [];
    for (var i = 0; anObject.children && i < anObject.children.length; i++)
    {
        var child = [self _elementFromPlainObject:anObject.children[i]];
        [child setValue:[data valueForKey:@"id"] forKey:@"parentID"];
        children.push(child);
    }
    [data setValue:children forKey:@"children"];

    return data;
}

- (CPString)_serializedSelection
{
    var selection = [self _topLevelSelection];
    if (selection.length === 0)
        return nil;

    var plain = [];
    for (var i = 0; i < selection.length; i++)
        plain.push([self _plainObjectForElement:selection[i]]);

    return JSON.stringify({ marker: UIBuilderDocumentPasteboardMarker, version: 1, elements: plain });
}

- (CPArray)_elementsFromSerializedString:(CPString)aString
{
    if (!aString)
        return nil;

    try
    {
        var payload = JSON.parse(aString);
        if (!payload || payload.marker !== UIBuilderDocumentPasteboardMarker || !payload.elements)
            return nil;

        var result = [];
        for (var i = 0; i < payload.elements.length; i++)
            result.push([self _elementFromPlainObject:payload.elements[i]]);

        return result;
    }
    catch (e)
    {
        return nil;
    }
}

- (BOOL)canPaste
{
    var pboard = [CPPasteboard generalPasteboard],
        types = [pboard types];

    if ([types containsObject:UIBuilderElementPboardType])
        return YES;

    if ([types containsObject:CPStringPboardType])
    {
        var string = [pboard stringForType:CPStringPboardType];
        return !!string && string.indexOf(UIBuilderDocumentPasteboardMarker) >= 0;
    }

    return NO;
}

- (void)copy:(id)sender
{
    var serialized = [self _serializedSelection];
    if (!serialized)
        return;

    var pboard = [CPPasteboard generalPasteboard];
    [pboard declareTypes:[UIBuilderElementPboardType, CPStringPboardType] owner:nil];
    [pboard setString:serialized forType:UIBuilderElementPboardType];
    [pboard setString:serialized forType:CPStringPboardType];
}

- (void)cut:(id)sender
{
    [self copy:sender];
    [self removeSelectedElementsWithActionName:@"Cut"];
}

- (void)paste:(id)sender
{
    var pboard = [CPPasteboard generalPasteboard],
        elements = [self _elementsFromSerializedString:[pboard stringForType:UIBuilderElementPboardType]];

    if (!elements)
        elements = [self _elementsFromSerializedString:[pboard stringForType:CPStringPboardType]];

    if (!elements || elements.length === 0)
        return;

    [self _insertElementsNearSelection:elements];
    [self _setActionName:@"Paste"];
}

- (void)duplicate:(id)sender
{
    var elements = [self _elementsFromSerializedString:[self _serializedSelection]];
    if (!elements || elements.length === 0)
        return;

    [self _insertElementsNearSelection:elements];
    [self _setActionName:@"Duplicate"];
}

// Inserts copied elements: into the selected container, or after the
// selected element, or (with nothing selected) into the first window.
- (void)_insertElementsNearSelection:(CPArray)elements
{
    var selection = [self _topLevelSelection],
        anchor = selection.length ? selection[selection.length - 1] : nil,
        targetParent = nil,
        index = -1,
        inserted = [];

    if (anchor)
    {
        if ([self _isContainerElement:anchor])
            targetParent = [self _contentContainerOfElement:anchor];
        else
        {
            targetParent = [self parentOfElement:anchor];
            index = [self _indexOfElement:anchor] + 1;
        }
    }

    for (var i = 0; i < elements.length; i++)
    {
        var element = elements[i];

        if ([element valueForKey:@"type"] === "window" || !targetParent)
        {
            if ([element valueForKey:@"type"] !== "window")
            {
                // Nothing to paste into: give the element its own window.
                var windowData = [self _newElementDataOfType:@"window"],
                    rootVBox = [windowData valueForKey:@"children"][0];

                [windowData setValue:120 + 20 * i forKey:@"originX"];
                [windowData setValue:120 + 20 * i forKey:@"originY"];
                [rootVBox valueForKey:@"children"].push([self _element:element adaptedForContainer:rootVBox]);
                [self insertElement:windowData intoParent:nil atIndex:-1];
            }
            else
            {
                [element setValue:([element valueForKey:@"originX"] || 0) + 20 forKey:@"originX"];
                [element setValue:([element valueForKey:@"originY"] || 0) + 20 forKey:@"originY"];
                [self insertElement:element intoParent:nil atIndex:-1];
            }
        }
        else
        {
            if (![self _isLayoutContainer:targetParent])
            {
                [element setValue:([element valueForKey:@"originX"] || 0) + 10 forKey:@"originX"];
                [element setValue:([element valueForKey:@"originY"] || 0) + 10 forKey:@"originY"];
            }

            [self insertElement:[self _element:element adaptedForContainer:targetParent] intoParent:targetParent atIndex:index];

            if (index >= 0)
                index++;
        }

        inserted.push(element);
    }

    [self _selectElements:inserted];
}

- (BOOL)_isLayoutContainer:(id)elementData
{
    var type = [elementData valueForKey:@"type"];
    return type === "hbox" || type === "vbox";
}

#pragma mark -
#pragma mark Connections

- (void)addConnectionFrom:(CPDictionary)sourceData to:(CPDictionary)targetData atPoint:(CGPoint)atPoint outlet:(CPString)outlet action:(CPString)action
{
    var sourceID = [sourceData valueForKey:@"id"],
        targetID = [targetData valueForKey:@"id"],
        existing = [self allConnections];

    for (var i = 0; i < existing.length; i++)
    {
        var connection = existing[i];
        if ([connection valueForKey:@"sourceID"] === sourceID && [connection valueForKey:@"targetID"] === targetID &&
            ([connection valueForKey:@"outlet"] || nil) == (outlet || nil) && ([connection valueForKey:@"action"] || nil) == (action || nil))
            return;
    }

    var newConnection = [CPConservativeDictionary dictionary];
    [newConnection setValue:sourceID forKey:@"sourceID"];
    [newConnection setValue:targetID forKey:@"targetID"];
    if (outlet)
        [newConnection setValue:outlet forKey:@"outlet"];
    if (action)
        [newConnection setValue:action forKey:@"action"];
    [newConnection setValue:@"connection_" + _elementCounter++ forKey:@"id"];

    if (atPoint)
        [newConnection setValue:{x: atPoint.x, y: atPoint.y} forKey:@"atPoint"];

    [self addConnection:newConnection];
    [self _setActionName:action ? @"Connect Action" : @"Connect Outlet"];
}

#pragma mark -
#pragma mark UICanvasView Delegate Methods

/*!
    Applies a list of {data, frame} changes. Inside an interactive drag this
    is not recorded individually; otherwise every key change is undoable.
*/
- (void)applyFrameChanges:(CPArray)changes withActionName:(CPString)actionName
{
    for (var i = 0; i < [changes count]; i++)
    {
        var change = changes[i],
            data = change.data,
            newFrame = change.frame;

        if (newFrame.origin)
        {
            [data setValue:newFrame.origin.x forKey:@"originX"];
            [data setValue:newFrame.origin.y forKey:@"originY"];
        }

        if (newFrame.size)
        {
            [data setValue:newFrame.size.width forKey:@"width"];
            [data setValue:newFrame.size.height forKey:@"height"];
        }
    }

    [self _setActionName:actionName];
}

- (void)canvasView:(UICanvasView)aCanvas didMoveElement:(UIElementView)anElement
{
    var selectedViews = [aCanvas selectedSubViews];
    var changes = [CPMutableArray array];
    for (var i = 0; i < [selectedViews count]; i++)
    {
        var view = selectedViews[i];
        [changes addObject:{ data: [view dataObject], frame: { origin: [view frame].origin } }];
    }
    [self applyFrameChanges:changes withActionName:@"Move"];
}

- (void)canvasView:(UICanvasView)aCanvas didResizeElement:(UIElementView)anElement
{
    // The data object was updated while dragging; the drag itself is the undo
    // step. A resized dimension is fixed in the markup from now on.
    var data = [anElement dataObject],
        snapshot = _interactiveSnapshot || [],
        changedKeys = [];

    for (var i = 0; i < snapshot.length; i++)
    {
        if (snapshot[i].element !== data)
            continue;

        if (snapshot[i].width !== [data valueForKey:@"width"])
            changedKeys.push("width");
        if (snapshot[i].height !== [data valueForKey:@"height"])
            changedKeys.push("height");
    }

    if (changedKeys.length)
        [self _markKeys:changedKeys forMarkupOfElement:data];

    [self _relayoutElement:[self parentOfElement:data]];
    [anElement invalidateLayoutUpwards];
}

- (void)canvasView:(UICanvasView)aCanvas didConnectElement:(UIElementView)sourceElement toElement:(UIElementView)targetElement asTargetAction:(CPString)actionName
{
    // For a target-action, the outlet is typically 'target'
    [self addConnectionFrom:[sourceElement dataObject] to:[targetElement dataObject] atPoint:nil outlet:@"target" action:actionName];
}

- (void)canvasView:(UICanvasView)aCanvas didConnectElement:(UIElementView)sourceElement toElement:(UIElementView)targetElement asOutlet:(CPString)outletName
{
    // For a simple outlet connection, there is no action.
    [self addConnectionFrom:[sourceElement dataObject] to:[targetElement dataObject] atPoint:nil outlet:outletName action:nil];
}

- (void)changeValue:(id)newValue forObject:(id)dataObject
{
    [dataObject setValue:newValue forKey:@"value"];
    [self _setActionName:@"Change Value"];
}

- (void)changeValueForSelectedObject:(id)newValue
{
    var selectedObjects = [[self elementsController] selectedObjects];
    if ([selectedObjects count] === 1)
        [self changeValue:newValue forObject:selectedObjects[0]];
}

#pragma mark -
#pragma mark Document

- (void)_removeEverythingWithoutUndo
{
    // (the data model is reset separately)
    _elementsByID = {};
    _ownerElement = nil;
    _markupOrder = [];
    _unknownConnectors = [];
    [_elementsController setSelectionIndexes:[CPIndexSet indexSet]];
    [_elementsController setContent:[CPMutableArray array]];
    [_connectionsController setContent:[CPMutableArray array]];
    [_canvasView setNeedsDisplay:YES];
}

- (id)_newOwnerElement
{
    var owner = [self _newElementDataOfType:@"owner"];
    [owner setValue:@"owner" forKey:@"id"];
    [owner setValue:24 forKey:@"originX"];
    [owner setValue:16 forKey:@"originY"];
    return owner;
}

// Inserts complete subtrees in one go (fast for large documents). Not undoable.
- (void)_insertTopLevelElementsWithoutUndo:(CPArray)elements
{
    var all = [];
    for (var i = 0; i < elements.length; i++)
    {
        [elements[i] removeObjectForKey:@"parentID"];
        var subtree = [self _subtreeOfElement:elements[i] normalizingParents:YES];
        for (var j = 0; j < subtree.length; j++)
        {
            _elementsByID[[subtree[j] valueForKey:@"id"]] = subtree[j];
            all.push(subtree[j]);
        }
    }

    [_elementsController addObjects:all];
}

- (void)newDocument
{
    UIBPerformWithoutUndo(function()
    {
        [self _removeEverythingWithoutUndo];
        [self _resetDataModel];
        _elementCounter = 0;
        _ownerElement = [self _newOwnerElement];
        [self _insertTopLevelElementsWithoutUndo:[_ownerElement]];
    });
    [self _postDataModelChange];

    [_undoManager removeAllActions];
    [self setDocumentEdited:NO];
    [_canvasView setNeedsLayout:YES];
}

#pragma mark -
#pragma mark Cappusance Import / Export

/*!
    Replaces the document with the given Cappusance markup.
    Returns nil on success, otherwise an error message. The current document
    is left untouched when the markup cannot be read.
*/
- (CPString)loadCappusanceMarkup:(CPString)aString
{
    var owner = [self _newOwnerElement],
        result = [_codec parseMarkup:aString ownerData:owner];

    if (result.error)
        return result.error;

    UIBPerformWithoutUndo(function()
    {
        [self _removeEverythingWithoutUndo];
        _ownerElement = owner;

        [owner setValue:result.ownerActions.join(", ") forKey:@"actions"];
        [owner setValue:result.ownerOutlets.join(", ") forKey:@"outlets"];

        [self _arrangeImportedWindows:result.windows];
        [self _insertTopLevelElementsWithoutUndo:[owner].concat(result.windows)];

        _markupOrder = result.order;
        _unknownConnectors = result.unknownConnectors;

        // A file without data model keeps the current one (gui.gsmarkup + model.gsmarkup).
        if (result.hasModel)
            [self _setDataModelFromResult:result];

        [_connectionsController addObjects:result.connections];
        [_connectionsController rearrangeObjects];
    });

    [self _selectElements:[]];
    [_undoManager removeAllActions];
    [self setDocumentEdited:NO];
    [_canvasView setNeedsLayout:YES];
    [_canvasView setNeedsDisplay:YES];

    return nil;
}

// Places imported windows on the canvas in rows, so none of them overlap.
// (Their x/y in the markup are separate properties and stay untouched.)
- (void)_arrangeImportedWindows:(CPArray)windows
{
    var maxWidth = MAX(900, ([_canvasView enclosingScrollView] ? [[[_canvasView enclosingScrollView] contentView] bounds].size.width : 1200) - 40),
        x = 24, y = 100, rowHeight = 0;

    for (var i = 0; i < windows.length; i++)
    {
        var data = windows[i],
            markupKeys = [data valueForKey:@"markupKeys"] || [];

        // Windows without a size in the markup get a usable default.
        if (markupKeys.indexOf("width") < 0)
            [data setValue:[data valueForKey:@"bridge"] ? 1100 : 400 forKey:@"width"];
        if (markupKeys.indexOf("height") < 0)
            [data setValue:[data valueForKey:@"bridge"] ? 750 : 300 forKey:@"height"];

        var width = [data valueForKey:@"width"],
            height = [data valueForKey:@"height"];

        if (x > 24 && x + width > maxWidth)
        {
            x = 24;
            y += rowHeight + 40;
            rowHeight = 0;
        }

        [data setValue:x forKey:@"originX"];
        [data setValue:y forKey:@"originY"];

        // Keep the root vbox in sync with the window size.
        var children = [data valueForKey:@"children"] || [];
        for (var j = 0; j < children.length; j++)
        {
            if ([children[j] valueForKey:@"isRootVBox"])
            {
                var frame = [self _rootFrameForContainer:data];
                [children[j] setValue:frame.origin.x forKey:@"originX"];
                [children[j] setValue:frame.origin.y forKey:@"originY"];
                [children[j] setValue:frame.size.width forKey:@"width"];
                [children[j] setValue:frame.size.height forKey:@"height"];
            }
        }

        x += width + 40;
        rowHeight = MAX(rowHeight, height);
    }
}

- (CPString)cappusanceMarkup
{
    return [self cappusanceMarkupIncludingInterface:YES model:NO];
}

- (BOOL)hasDataModel
{
    return _sortDescriptors.length + _arrayControllers.length + _entities.length > 0;
}

- (BOOL)hasInterface
{
    var all = [_elementsController arrangedObjects];
    for (var i = 0; i < all.length; i++)
        if ([all[i] valueForKey:@"type"] === "window")
            return YES;
    return NO;
}

- (CPString)cappusanceMarkupIncludingInterface:(BOOL)includeInterface model:(BOOL)includeModel
{
    var windows = [],
        all = [_elementsController arrangedObjects];

    for (var i = 0; i < all.length; i++)
        if (![all[i] valueForKey:@"parentID"] && [all[i] valueForKey:@"type"] === "window")
            windows.push(all[i]);

    // Keep imported windows in their original order, new ones after them.
    var ordered = [];
    for (var i = 0; i < _markupOrder.length; i++)
        if (_markupOrder[i].element && windows.indexOf(_markupOrder[i].element) >= 0)
            ordered.push(_markupOrder[i].element);
    for (var i = 0; i < windows.length; i++)
        if (ordered.indexOf(windows[i]) < 0)
            ordered.push(windows[i]);

    return [_codec exportDocumentWithWindows:ordered order:_markupOrder connections:[self allConnections] unknownConnectors:_unknownConnectors
                                       model:[self _dataModelSnapshot] includeInterface:includeInterface includeModel:includeModel];
}

// Kept for compatibility with the earlier menu commands.
- (CPString)generateGSMarkup
{
    return [self cappusanceMarkup];
}

- (CPString)loadGSMarkup:(CPString)aString
{
    return [self loadCappusanceMarkup:aString];
}

- (void)parseGSMarkup:(CPString)aString
{
    var error = [self loadCappusanceMarkup:aString];
    if (error)
        console.error("Could not load markup:", error);
}

#pragma mark -
#pragma mark Inspector Support

// Sets one preserved markup attribute (bindings etc.), undoably.
- (void)setMarkupAttribute:(CPString)aName value:(CPString)aValue ofElement:(id)anElement
{
    if (!aName || ![self containsElement:anElement])
        return;

    var extras = {},
        current = [anElement valueForKey:@"extraAttributes"] || {};

    for (var key in current)
        if (current.hasOwnProperty(key))
            extras[key] = current[key];

    if (aValue === nil || aValue === undefined)
        delete extras[aName];
    else
        extras[aName] = String(aValue);

    [anElement setValue:extras forKey:@"extraAttributes"];
    [self _setActionName:@"Change Attribute"];
}

- (void)renameMarkupAttribute:(CPString)oldName to:(CPString)newName ofElement:(id)anElement
{
    newName = String(newName || "").trim();
    if (!newName || newName === oldName || ![self containsElement:anElement])
        return;

    var extras = {},
        current = [anElement valueForKey:@"extraAttributes"] || {};

    for (var key in current)
        if (current.hasOwnProperty(key))
            extras[key === oldName ? newName : key] = current[key];

    [anElement setValue:extras forKey:@"extraAttributes"];
    [self _setActionName:@"Rename Attribute"];
}

// Whether width/height is fixed in the markup (otherwise the content decides).
- (void)setExplicitSize:(BOOL)flag forKey:(CPString)aKey ofElement:(id)anElement
{
    if (![self containsElement:anElement])
        return;

    var markupKeys = ([anElement valueForKey:@"markupKeys"] || []).slice(),
        index = markupKeys.indexOf(aKey);

    if (flag && index < 0)
    {
        var view = [_canvasView viewForElementWithID:[anElement valueForKey:@"id"]];
        markupKeys.push(aKey);

        // Start from what is shown on the canvas.
        if (view)
            [anElement setValue:Math.round(aKey === "width" ? [view frame].size.width : [view frame].size.height) forKey:aKey];
    }
    else if (!flag && index >= 0)
        markupKeys.splice(index, 1);
    else
        return;

    [anElement setValue:markupKeys forKey:@"markupKeys"];
    [self _setActionName:flag ? @"Fix Size" : @"Automatic Size"];
}

- (CPArray)connectionsInvolvingElement:(id)anElement
{
    var elementID = [anElement valueForKey:@"id"],
        result = [],
        connections = [self allConnections];

    for (var i = 0; i < connections.length; i++)
        if ([connections[i] valueForKey:@"sourceID"] === elementID || [connections[i] valueForKey:@"targetID"] === elementID)
            result.push(connections[i]);

    return result;
}

// A readable name for one end of a connection.
- (CPString)describeEndpointOfConnection:(id)aConnection prefix:(CPString)aPrefix
{
    var elementID = [aConnection valueForKey:aPrefix + "ID"];
    if (elementID)
    {
        var element = _elementsByID[elementID];
        if (!element)
            return "(missing)";
        if ([element valueForKey:@"type"] === "owner")
            return "#CPOwner";

        var identifier = [element valueForKey:@"identifier"],
            label = [element valueForKey:@"markupTag"] || [element valueForKey:@"type"],
            title = [element valueForKey:@"value"] || [element valueForKey:@"title"];

        return (identifier ? "#" + identifier + " " : "") + label + (title && typeof title === "string" ? " “" + title + "”" : "");
    }

    return [aConnection valueForKey:aPrefix + "Ref"] || "(first responder)";
}

/*!
    Adds a connection from an element to a reference typed in the inspector:
    "CPOwner", "#someID", or anything else (e.g. "#CPOwner.listsController"),
    which is written as is.
*/
- (void)addConnectionFromElement:(id)anElement toReference:(CPString)aReference outlet:(CPString)anOutlet action:(CPString)anAction
{
    if (![self containsElement:anElement])
        return;

    var reference = String(aReference || "").trim(),
        name = reference.replace(/^#/, ""),
        target = nil;

    if (name === UIBOwnerReference)
        target = _ownerElement;
    else if (name.length)
    {
        var all = [_elementsController arrangedObjects];
        for (var i = 0; i < all.length && !target; i++)
            if ([all[i] valueForKey:@"identifier"] === name)
                target = all[i];
    }

    var connection = [CPConservativeDictionary dictionary];
    [connection setValue:[anElement valueForKey:@"id"] forKey:@"sourceID"];

    if (target)
        [connection setValue:[target valueForKey:@"id"] forKey:@"targetID"];
    else
        [connection setValue:(reference.length && reference.charAt(0) !== "#" ? "#" + reference : reference) forKey:@"targetRef"];

    if (anOutlet)
        [connection setValue:anOutlet forKey:@"outlet"];
    if (anAction)
        [connection setValue:anAction forKey:@"action"];

    [connection setValue:@"connection_" + _elementCounter++ forKey:@"id"];

    [self addConnection:connection];
    [self _setActionName:anAction ? @"Connect Action" : @"Connect Outlet"];

    // Actions sent to the owner become part of its action list.
    if (anAction && target === _ownerElement)
    {
        var actions = UIBSplitList([_ownerElement valueForKey:@"actions"]);
        if (actions.indexOf(anAction) < 0)
        {
            actions.push(anAction);
            [_ownerElement setValue:actions.join(", ") forKey:@"actions"];
        }
    }
}

#pragma mark -
#pragma mark Data Model

- (void)_resetDataModel
{
    _sortDescriptors = [];
    _arrayControllers = [];
    _entities = [];
    _modelConnectors = [];
    _modelObjects = new Set();
}

- (void)_rebuildModelObjectSet
{
    _modelObjects = new Set(_sortDescriptors.concat(_arrayControllers, _entities));
}

- (void)_postDataModelChange
{
    [[CPNotificationCenter defaultCenter] postNotificationName:UIBDataModelDidChangeNotification object:self];
}

- (void)_setDataModelFromResult:(JSObject)result
{
    _sortDescriptors = result.sortDescriptors.slice();
    _arrayControllers = result.arrayControllers.slice();
    _entities = result.entities.slice();
    _modelConnectors = result.modelConnectors.slice();
    [self _rebuildModelObjectSet];
    [self _postDataModelChange];
}

- (JSObject)_dataModelSnapshot
{
    return { sortDescriptors: _sortDescriptors, arrayControllers: _arrayControllers, entities: _entities, connectors: _modelConnectors };
}

- (CPArray)sortDescriptors   { return _sortDescriptors; }
- (CPArray)arrayControllers  { return _arrayControllers; }
- (CPArray)entities          { return _entities; }

- (CPString)_listKeyForKind:(CPString)aKind
{
    return { "sortDescriptor": "sortDescriptors", "arrayController": "arrayControllers", "entity": "entities" }[aKind];
}

- (CPArray)_modelListForKey:(CPString)aKey
{
    if (aKey === "sortDescriptors") return _sortDescriptors;
    if (aKey === "arrayControllers") return _arrayControllers;
    return _entities;
}

// Replaces a whole list (add/remove/reorder). Undo restores the old list.
- (void)_replaceModelListForKey:(CPString)aKey with:(CPArray)aList
{
    var old = [self _modelListForKey:aKey].slice();

    if (aKey === "sortDescriptors") _sortDescriptors = aList.slice();
    else if (aKey === "arrayControllers") _arrayControllers = aList.slice();
    else _entities = aList.slice();

    [self _rebuildModelObjectSet];

    if (UIBUndoSuppressionCount === 0)
    {
        [[_undoManager prepareWithInvocationTarget:self] _replaceModelListForKey:aKey with:old];
        [self _noteDocumentChanged];
    }

    [self _postDataModelChange];
}

- (id)modelObjectOfKind:(CPString)aKind named:(CPString)aName
{
    var list = [self _modelListForKey:[self _listKeyForKind:aKind]];
    for (var i = 0; i < list.length; i++)
        if ([list[i] valueForKey:@"name"] === aName)
            return list[i];
    return nil;
}

- (id)addModelObjectOfKind:(CPString)aKind
{
    var base = { "sortDescriptor": "by_", "arrayController": "new_controller", "entity": "new_entity" }[aKind],
        name = base,
        counter = 1;

    while ([self modelObjectOfKind:aKind named:name])
        name = base + (++counter);

    var object = UIBNewModelObject(aKind);
    [object setValue:name forKey:@"name"];

    if (aKind === "entity")
        [object setValue:[UIBNewModelItem({ name: "id", primaryKey: "YES" })] forKey:@"columns"];
    if (aKind === "sortDescriptor")
        [object setValue:"name" forKey:@"key"];
    if (aKind === "arrayController" && _entities.length)
        [object setValue:[_entities[0] valueForKey:@"name"] forKey:@"entity"];

    var listKey = [self _listKeyForKind:aKind];
    [self _replaceModelListForKey:listKey with:[self _modelListForKey:listKey].concat([object])];
    [self _setActionName:@"Add " + aKind];
    return object;
}

- (void)removeModelObjects:(CPArray)objects
{
    if (!objects || !objects.length)
        return;

    var listKey = [self _listKeyForKind:[objects[0] valueForKey:@"kind"]],
        remaining = [self _modelListForKey:listKey].filter(function(o) { return objects.indexOf(o) < 0; });

    [self _replaceModelListForKey:listKey with:remaining];
    [self _setActionName:@"Delete"];
}

// Sets one property of a model object (undoable). Renaming an entity or a
// sort descriptor also updates the array controllers that use it.
- (void)setModelValue:(id)aValue forKey:(CPString)aKey ofObject:(id)anObject
{
    if (!_modelObjects.has(anObject))
        return;

    var kind = [anObject valueForKey:@"kind"],
        oldValue = [anObject valueForKey:aKey];

    if (aKey === "name")
    {
        aValue = String(aValue || "").trim();
        if (!aValue.length || aValue === oldValue)
            return;

        for (var i = 0; i < _arrayControllers.length; i++)
        {
            if (kind === "entity" && [_arrayControllers[i] valueForKey:@"entity"] === oldValue)
                [_arrayControllers[i] setValue:aValue forKey:@"entity"];
            if (kind === "sortDescriptor" && [_arrayControllers[i] valueForKey:@"sortDescriptor"] === oldValue)
                [_arrayControllers[i] setValue:aValue forKey:@"sortDescriptor"];
        }
    }

    if (aValue === "" || aValue === nil)
        [self _setValue:nil forKey:aKey ofElement:anObject];
    else
        [anObject setValue:aValue forKey:aKey];

    [self _setActionName:aKey === "name" ? @"Rename" : @"Change " + aKey];
    [self _postDataModelChange];
}

// Columns and relationships are replaced as a whole (undoable).
- (void)setModelItems:(CPArray)items forKey:(CPString)aKey ofEntity:(id)anEntity
{
    if (!_modelObjects.has(anEntity))
        return;

    [anEntity setValue:items.slice() forKey:aKey];
    [self _setActionName:aKey === "columns" ? @"Edit Columns" : @"Edit Relationships"];
    [self _postDataModelChange];
}

/*!
    Replaces the data model with the one in the given markup (undoable).
    The interface stays as it is.
*/
- (CPString)importDataModelFromMarkup:(CPString)aString
{
    var result = [_codec parseMarkup:aString ownerData:_ownerElement || [self _newOwnerElement]];

    if (result.error)
        return result.error;

    if (!result.hasModel)
        return "The markup contains no sort descriptors, array controllers or entities.";

    [self _replaceModelListForKey:@"sortDescriptors" with:result.sortDescriptors];
    [self _replaceModelListForKey:@"arrayControllers" with:result.arrayControllers];
    [self _replaceModelListForKey:@"entities" with:result.entities];
    _modelConnectors = result.modelConnectors.slice();
    [self _setActionName:@"Import Data Model"];

    return nil;
}

#pragma mark -
#pragma mark Bindings Support

// How the interface refers to a controller: through the owner's outlet if it has one.
- (CPString)referenceForArrayController:(id)aController
{
    var outlet = [aController valueForKey:@"ownerOutlet"];
    return outlet ? "#CPOwner." + outlet : "#" + [aController valueForKey:@"name"];
}

// The array controller a binding path starts with, or nil.
- (id)arrayControllerForBinding:(CPString)aBinding
{
    var path = String(aBinding || "").replace(/^#/, "");
    if (!path.length)
        return nil;

    for (var i = 0; i < _arrayControllers.length; i++)
    {
        var controller = _arrayControllers[i],
            outlet = [controller valueForKey:@"ownerOutlet"],
            name = [controller valueForKey:@"name"];

        if (outlet && (path === "CPOwner." + outlet || path.indexOf("CPOwner." + outlet + ".") === 0))
            return controller;
        if (name && (path === name || path.indexOf(name + ".") === 0))
            return controller;
    }

    return nil;
}

- (CPArray)columnNamesForArrayController:(id)aController
{
    var entity = [self modelObjectOfKind:@"entity" named:[aController valueForKey:@"entity"]];
    if (!entity)
        return [];

    return ([entity valueForKey:@"columns"] || []).map(function(column) { return column.attributes.name; }).filter(function(n) { return !!n; });
}

// Values offered in the inspector's binding fields.
- (CPArray)bindingSuggestionsForKey:(CPString)aBindingKey elementType:(CPString)aType
{
    var result = [];

    for (var i = 0; i < _arrayControllers.length; i++)
    {
        var controller = _arrayControllers[i],
            reference = [self referenceForArrayController:controller],
            columns = [self columnNamesForArrayController:controller];

        if (aBindingKey === "valueBinding" && aType === "tableView")
            result.push(reference);
        else if (aBindingKey === "itemsBinding")
            columns.forEach(function(c) { result.push(reference + ".arrangedObjects." + c); });
        else if (aBindingKey === "enabledBinding")
            result.push(reference + ".selection.@count");
        else
            columns.forEach(function(c) { result.push(reference + ".selection." + c); });
    }

    return result;
}

/*!
    Sets the columns of a table view to the columns of the entity of the
    array controller it is bound to. Returns an error message or nil.
*/
- (CPString)takeTableColumnsFromEntityForElement:(id)anElement
{
    var extras = [anElement valueForKey:@"extraAttributes"] || {},
        controller = [self arrayControllerForBinding:extras.valueBinding];

    if (!controller)
        return "Bind the table view to an array controller first (valueBinding).";

    var columns = [self columnNamesForArrayController:controller];
    if (!columns.length)
        return UIBLocalizedFormat("The entity of %@ has no columns.", [controller valueForKey:@"name"]);

    [anElement setValue:columns.join(", ") forKey:@"columns"];
    [self _setActionName:@"Columns from Entity"];
    return nil;
}

/*!
    Inserts a scroll view with a table view bound to the controller, with one
    column per entity column, next to the selection (or in a new window).
*/
- (id)insertTableForArrayController:(id)aController
{
    var scrollView = [self _newElementDataOfType:@"scrollView"],
        tableView = [self _newElementDataOfType:@"tableView"],
        root = [scrollView valueForKey:@"children"][0],
        columns = [self columnNamesForArrayController:aController];

    [tableView setValue:columns.join(", ") forKey:@"columns"];
    [tableView setValue:{ valueBinding: [self referenceForArrayController:aController], zebra: "YES" } forKey:@"extraAttributes"];
    [root valueForKey:@"children"].push(tableView);

    [self _insertElementsNearSelection:[scrollView]];
    [self _selectElements:[tableView]];
    [self _setActionName:@"Insert Table"];
    return tableView;
}

@end

@implementation CPString (UIBAdditions)

/**
 * @brief Returns a new string containing the receiver's characters repeated a given number of times.
 */
- (CPString)repeat:(int)aCount
{
    if (aCount < 0)
    {
        CPLog.warn("CPString -repeat: count must be a non-negative integer.");
        return @"";
    }

    if (aCount === 0)
        return @"";

    if (aCount === 1)
        return self;

    return new Array(aCount + 1).join(self);
}

@end

//
//  UIBuilderController.j
//  This is the main controller for the UI Builder application.
//  It manages the data model for all elements on the canvas and acts
//  as a delegate for the UICanvasView to respond to user interactions.
//
//  By Daniel Boehringer in 2025.
//

@import <Foundation/CPObject.j>
@import "UIElementView.j"
@import "UICanvasView.j"
@import "UIBuilderConstants.j";

// This is a simple data model. In a real app, it might have more properties.
// We use a custom dictionary to ensure KVO compatibility and proper value setting.
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
    // Only set the value if it's different from the current value
    var currentValue = [super valueForKey:aKey];
    

    // Always set the value if the current value is null or undefined
    if (currentValue == null || currentValue == undefined || currentValue != aVal) {
        [super setValue:aVal forKey:aKey];
    }
}

- (BOOL)isEqual:(id)otherObject
{
    return [self valueForKey:'id'] == [otherObject valueForKey:'id'];
}

@end


@implementation UIBuilderController : CPViewController
{
    CPArrayController _elementsController @accessors(property=elementsController);
    CPMutableArray _connections;
    int _elementCounter; // To generate unique IDs
}

+ (Class)classForElementType:(CPString)elementType
{
    if (elementType === "window") return UIWindowView;
    if (elementType === "button") return UIButtonView;
    if (elementType === "slider") return UISliderView;
    if (elementType === "textfield") return UITextFieldView;
    return UIElementView;
}

- (id)init
{
    self = [super init];
    if (self) {
        _elementsController = [[CPArrayController alloc] init];
        _connections = [CPMutableArray array];
        _elementCounter = 0;
    }
    return self;
}

#pragma mark -
#pragma mark Data Management

- (CPDictionary)_containerDataAtPoint:(CGPoint)aPoint
{
    var allElements = [_elementsController arrangedObjects];
    for (var i = [allElements count] - 1; i >= 0; i--)
    {
        var elementData = allElements[i];
        var type = [elementData valueForKey:@"type"];
        if (type === "window")
        {
            var frame = CGRectMake([elementData valueForKey:@"originX"], [elementData valueForKey:@"originY"], [elementData valueForKey:@"width"], [elementData valueForKey:@"height"]);
            if (CGRectContainsPoint(frame, aPoint))
                return elementData;
        }
    }
    return nil;
}

- (void)addNewElementOfType:(CPString)elementType atPoint:(CGPoint)aPoint
{
    var newElementData = [CPConservativeDictionary dictionary];
    var containerData = [self _containerDataAtPoint:aPoint];
    var viewClass = [UIBuilderController classForElementType:elementType];

    // Set default properties based on type
    [newElementData setValue:elementType forKey:@"type"];
    [newElementData setValue:aPoint.x forKey:@"originX"];
    [newElementData setValue:aPoint.y forKey:@"originY"];
    [newElementData setValue:@"id_" + _elementCounter++ forKey:@"id"];

    // Set default values from the view class
    var defaultValues = [viewClass defaultValues];
    for (var key in defaultValues) {
        [newElementData setValue:defaultValues[key] forKey:key];
    }

    // Set default sizes
    if (elementType === "window") {
        [newElementData setValue:250 forKey:@"width"];
        [newElementData setValue:200 forKey:@"height"];
        [newElementData setValue:[] forKey:@"children"];
    } else if (elementType === "button") {
        [newElementData setValue:100 forKey:@"width"];
        [newElementData setValue:24 forKey:@"height"];
    } else if (elementType === "slider") {
        [newElementData setValue:150 forKey:@"width"];
        [newElementData setValue:20 forKey:@"height"];
    } else { // textfield
        [newElementData setValue:150 forKey:@"width"];
        [newElementData setValue:22 forKey:@"height"];
    }

    if (containerData && elementType !== "window")
    {
        // Convert point to be relative to the container
        var relativeX = aPoint.x - [containerData valueForKey:@"originX"];
        var relativeY = aPoint.y - [containerData valueForKey:@"originY"];
        [newElementData setValue:relativeX forKey:@"originX"];
        [newElementData setValue:relativeY forKey:@"originY"];

        // Add as a child to the container
        [newElementData setValue:[containerData valueForKey:@"id"] forKey:@"parentID"];
        [[containerData mutableArrayValueForKey:@"children"] addObject:newElementData];
    }

    // Add to the main controller regardless, so selection works.
    [[[[CPApp keyWindow] undoManager] prepareWithInvocationTarget:_elementsController] removeObject:newElementData];
    [[[CPApp keyWindow] undoManager] setActionName:@"Add Element"];
    [_elementsController addObject:newElementData];

    document.title = [[_elementsController arrangedObjects] count];
    [_elementsController setSelectedObjects:[CPArray arrayWithObject:newElementData]];
}

- (void)removeSelectedElementsWithActionName:(CPString)actionName
{
    var selectedObjects = [[_elementsController selectedObjects] copy];
    if ([selectedObjects count] === 0) return;

    [[[[CPApp keyWindow] undoManager] prepareWithInvocationTarget:_elementsController] addObjects:selectedObjects];
    [[[CPApp keyWindow] undoManager] setActionName:actionName];
    [_elementsController removeObjects:selectedObjects];
}

- (void)removeSelectedElements
{
    [self removeSelectedElementsWithActionName:@"Delete"];
}

- (void)cut:(id)sender
{
    [self copy:sender];
    [self removeSelectedElementsWithActionName:@"Cut"];
}

#pragma mark - 
#pragma mark Keyboard Movement

- (void)moveSelectedElementsByDeltaX:(int)deltaX deltaY:(int)deltaY
{
    var selectedDataObjects = [_elementsController selectedObjects];
    var changes = [CPMutableArray array];
    for (var i = 0; i < [selectedDataObjects count]; i++)
    {
        var data = selectedDataObjects[i];
        var newFrame = {
            origin: {
                x: [data valueForKey:@"originX"] + deltaX,
                y: [data valueForKey:@"originY"] + deltaY
            }
        };
        [changes addObject:{ data: data, frame: newFrame }];
    }
    [self applyFrameChanges:changes withActionName:@"Move"];
}

- (void)moveLeft:(id)sender
{
    [self moveSelectedElementsByDeltaX:-1 deltaY:0];
}

- (void)moveRight:(id)sender
{
    [self moveSelectedElementsByDeltaX:1 deltaY:0];
}

- (void)moveUp:(id)sender
{
    [self moveSelectedElementsByDeltaX:0 deltaY:-1];
}

- (void)moveDown:(id)sender
{
    [self moveSelectedElementsByDeltaX:0 deltaY:1];
}

#pragma mark - 
#pragma mark Copy & Paste

- (void)copy:(id)sender
{
    var selectedData = [_elementsController selectedObjects];

    if ([selectedData count] > 0)
    {
        var pboard = [CPPasteboard generalPasteboard];
        var data = [CPKeyedArchiver archivedDataWithRootObject:selectedData];
        [pboard declareTypes:[UIBuilderElementPboardType] owner:nil];
        [pboard setData:data forType:UIBuilderElementPboardType];
    }
}

- (void)paste:(id)sender
{
    var pboard = [CPPasteboard generalPasteboard];
    var types = [pboard types];

    if ([types containsObject:UIBuilderElementPboardType])
    {
        var data = [pboard dataForType:UIBuilderElementPboardType];
        var pastedElements = [CPKeyedUnarchiver unarchiveObjectWithData:data];
        var newSelection = [CPMutableArray array];

        for (var i = 0; i < [pastedElements count]; i++)
        {
            var elementData = pastedElements[i];
            var archivedData = [CPKeyedArchiver archivedDataWithRootObject:elementData];
            var newElement = [CPKeyedUnarchiver unarchiveObjectWithData:archivedData];

            // Offset the new element and give it a new ID
            [newElement setValue:[newElement valueForKey:@"originX"] + 10 forKey:@"originX"];
            [newElement setValue:[newElement valueForKey:@"originY"] + 10 forKey:@"originY"];
            [newElement setValue:@"id_" + _elementCounter++ forKey:@"id"];

            [_elementsController addObject:newElement];
            [newSelection addObject:newElement];
        }
        
        [[[[CPApp keyWindow] undoManager] prepareWithInvocationTarget:_elementsController] removeObjects:newSelection];
        [[[CPApp keyWindow] undoManager] setActionName:@"Paste"];
        [_elementsController setSelectedObjects:newSelection];
    }
}

- (void)addNewElementOfType:(CPString)elementType inNewWindowAtPoint:(CGPoint)aPoint
{
    // 1. Create the new element to be placed in the window
    var newElementData = [CPConservativeDictionary dictionary];
    var viewClass = [UIBuilderController classForElementType:elementType];
    [newElementData setValue:elementType forKey:@"type"];
    [newElementData setValue:@"id_" + _elementCounter++ forKey:@"id"];

    var defaultValues = [viewClass defaultValues];
    for (var key in defaultValues)
        [newElementData setValue:defaultValues[key] forKey:key];

    var elementWidth, elementHeight;

    if (elementType === "button") {
        elementWidth = 100;
        elementHeight = 24;
    } else if (elementType === "slider") {
        elementWidth = 150;
        elementHeight = 20;
    } else { // textfield
        elementWidth = 150;
        elementHeight = 22;
    }
    [newElementData setValue:elementWidth forKey:@"width"];
    [newElementData setValue:elementHeight forKey:@"height"];

    // 2. Create the window that will contain the new element
    var windowData = [CPConservativeDictionary dictionary];
    var windowClass = [UIBuilderController classForElementType:"window"];
    var windowWidth = 250, windowHeight = 200;
    [windowData setValue:@"window" forKey:@"type"];
    [windowData setValue:@"id_" + _elementCounter++ forKey:@"id"];
    [windowData setValue:windowWidth forKey:@"width"];
    [windowData setValue:windowHeight forKey:@"height"];
    [windowData setValue:[] forKey:@"children"];

    defaultValues = [windowClass defaultValues];
    for (var key in defaultValues) {
        [windowData setValue:defaultValues[key] forKey:key];
    }

    // 3. Position the new element in the center of the window
    var elementX = (windowWidth - elementWidth) / 2;
    var elementY = (windowHeight - elementHeight) / 2;
    [newElementData setValue:elementX forKey:@"originX"];
    [newElementData setValue:elementY forKey:@"originY"];

    // 4. Position the window so the element is at the drop point
    var windowX = aPoint.x - elementX;
    var windowY = aPoint.y - elementY;
    [windowData setValue:windowX forKey:@"originX"];
    [windowData setValue:windowY forKey:@"originY"];

    // 5. Add the element to the window's children
    [newElementData setValue:[windowData valueForKey:@"id"] forKey:@"parentID"];
    [[windowData mutableArrayValueForKey:@"children"] addObject:newElementData];

    console.log("UIBuilderController: addNewElementOfType:inNewWindowAtPoint: - Adding new element to window's children:", newElementData);

    // 6. Add both to the elements controller
    var undoManager = [[CPApp keyWindow] undoManager];
    [undoManager beginUndoGrouping];
    [[undoManager prepareWithInvocationTarget:_elementsController] removeObject:newElementData];
    [[undoManager prepareWithInvocationTarget:_elementsController] removeObject:windowData];
    [undoManager setActionName:@"Add Element in New Window"];
    [_elementsController addObject:windowData];
    [_elementsController addObject:newElementData];
    [undoManager endUndoGrouping];

    // 7. Select the new element
    [_elementsController setSelectedObjects:[CPArray arrayWithObject:newElementData]];
}

- (void)addNewElementOfType:(CPString)elementType inWindow:(CPDictionary)windowData atPoint:(CGPoint)aPoint
{
    console.log("UIBuilderController: addNewElementOfType:inWindow:atPoint: - Adding element ", elementType, " to window ", windowData, " at point ", aPoint);
    var newElementData = [CPConservativeDictionary dictionary];
    var viewClass = [UIBuilderController classForElementType:elementType];

    [newElementData setValue:elementType forKey:@"type"];
    [newElementData setValue:@"id_" + _elementCounter++ forKey:@"id"];

    var defaultValues = [viewClass defaultValues];
    for (var key in defaultValues)
        [newElementData setValue:defaultValues[key] forKey:key];

    var elementWidth, elementHeight;

    if (elementType === "button") {
        elementWidth = 100;
        elementHeight = 24;
    } else if (elementType === "slider") {
        elementWidth = 150;
        elementHeight = 20;
    } else { // textfield
        elementWidth = 150;
        elementHeight = 22;
    }
    [newElementData setValue:elementWidth forKey:@"width"];
    [newElementData setValue:elementHeight forKey:@"height"];

    // Position the new element relative to the window's origin
    [newElementData setValue:aPoint.x forKey:@"originX"];
    [newElementData setValue:aPoint.y forKey:@"originY"];

    // Add as a child to the container window
    [newElementData setValue:[windowData valueForKey:@"id"] forKey:@"parentID"];
    [[windowData mutableArrayValueForKey:@"children"] addObject:newElementData];

    // Add to the main controller
    var undoManager = [[CPApp keyWindow] undoManager];
    [undoManager beginUndoGrouping];
    [[undoManager prepareWithInvocationTarget:_elementsController] removeObject:newElementData];
    [undoManager setActionName:@"Add Element to Window"];
    [_elementsController addObject:newElementData];
    [undoManager endUndoGrouping];

    [_elementsController setSelectedObjects:[CPArray arrayWithObject:newElementData]];
}

- (void)addConnectionFrom:(CPDictionary)sourceData to:(CPDictionary)targetData atPoint:(CGPoint)atPoint
{
    var newConnection = [CPConservativeDictionary dictionary];
    [newConnection setValue:[sourceData valueForKey:@"id"] forKey:@"sourceID"];
    [newConnection setValue:[targetData valueForKey:@"id"] forKey:@"targetID"];
    [newConnection setValue:@"connection_" + _elementCounter++ forKey:@"id"];
    [newConnection setValue:{x: atPoint.x, y: atPoint.y} forKey:@"atPoint"];

    [[[[CPApp keyWindow] undoManager] prepareWithInvocationTarget:_connections] removeObject:newConnection];
    [[[CPApp keyWindow] undoManager] setActionName:@"Add Connection"];
    [_connections addObject:newConnection];
    console.log("UIBuilderController: addConnectionFrom:to: - Added connection: ", newConnection);
}

#pragma mark -
#pragma mark UICanvasView Delegate Methods

- (void)applyFrameChanges:(CPArray)changes withActionName:(CPString)actionName
{
    var undoManager = [[CPApp keyWindow] undoManager];
    var undoChanges = [CPMutableArray array];

    [undoManager beginUndoGrouping];
    [undoManager setActionName:actionName];

    for (var i = 0; i < [changes count]; i++)
    {
        var change = changes[i];
        var data = change.data;
        var newFrame = change.frame;
        var oldValues = { data: data, frame: {} };

        if (newFrame.origin)
        {
            oldValues.frame.origin = {
                x: [data valueForKey:@"originX"],
                y: [data valueForKey:@"originY"]
            };
            [data setValue:newFrame.origin.x forKey:@"originX"];
            [data setValue:newFrame.origin.y forKey:@"originY"];
        }

        if (newFrame.size)
        {
            oldValues.frame.size = {
                width: [data valueForKey:@"width"],
                height: [data valueForKey:@"height"]
            };
            [data setValue:newFrame.size.width forKey:@"width"];
            [data setValue:newFrame.size.height forKey:@"height"];
        }
        [undoChanges addObject:oldValues];
    }

    [[undoManager prepareWithInvocationTarget:self] applyFrameChanges:undoChanges withActionName:actionName];
    [undoManager endUndoGrouping];
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
    var changes = [CPMutableArray array];
    var frame = [anElement frame];
    [changes addObject:{ data: [anElement dataObject], frame: { origin: frame.origin, size: frame.size } }];
    [self applyFrameChanges:changes withActionName:@"Resize"];
}

- (void)canvasView:(UICanvasView)aCanvas didConnectElement:(UIElementView)sourceElement toElement:(UIElementView)targetElement atPoint:(CGPoint)aPoint
{
    [self addConnectionFrom:[sourceElement dataObject] to:[targetElement dataObject] atPoint:aPoint];
}

- (void)changeValue:(id)newValue forObject:(id)dataObject
{
    var oldValue = [dataObject valueForKey:@"value"];
    if (oldValue != newValue)
    {
        var undoManager = [[CPApp keyWindow] undoManager];
        [[undoManager prepareWithInvocationTarget:self] changeValue:oldValue forObject:dataObject];
        [undoManager setActionName:@"Change Value"];
        [dataObject setValue:newValue forKey:@"value"];
    }
}

- (void)changeValueForSelectedObject:(id)newValue
{
    var selectedObjects = [[self elementsController] selectedObjects];
    if ([selectedObjects count] === 1)
    {
        [self changeValue:newValue forObject:selectedObjects[0]];
    }
}

@end

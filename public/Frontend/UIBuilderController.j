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

// This is a simple data model. In a real app, it might have more properties.
// We use CPConservativeDictionary to avoid unnecessary KVO notifications.
@implementation CPConservativeDictionary : CPDictionary
- (void)setValue:(id)aVal forKey:(CPString)aKey
{
    if ([self objectForKey:aKey] != aVal)
        [super setValue:aVal forKey:aKey];
}
- (BOOL)isEqual:(id)otherObject
{
    // A simple way to identify objects for the array controller
    return [self valueForKey:'id'] == [otherObject valueForKey:'id'];
}
@end


@implementation UIBuilderController : CPViewController
{
    CPArrayController _elementsController @accessors(property=elementsController);
    int _elementCounter; // To generate unique IDs
}

- (id)init
{
    self = [super init];
    if (self) {
        _elementsController = [[CPArrayController alloc] init];
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

    // Set default properties based on type
    [newElementData setValue:elementType forKey:@"type"];
    [newElementData setValue:aPoint.x forKey:@"originX"];
    [newElementData setValue:aPoint.y forKey:@"originY"];
    [newElementData setValue:@"id_" + _elementCounter++ forKey:@"id"];

    // Set default sizes and value
    if (elementType === "window") {
        [newElementData setValue:250 forKey:@"width"];
        [newElementData setValue:200 forKey:@"height"];
        [newElementData setValue:[] forKey:@"children"];
        [newElementData setValue:@"Untitled window" forKey:@"value"];
    } else if (elementType === "button") {
        [newElementData setValue:100 forKey:@"width"];
        [newElementData setValue:24 forKey:@"height"];
        [newElementData setValue:@"Button" forKey:@"value"];
    } else if (elementType === "slider") {
        [newElementData setValue:150 forKey:@"width"];
        [newElementData setValue:20 forKey:@"height"];
        [newElementData setValue:0.5 forKey:@"value"];
    } else { // textfield
        [newElementData setValue:150 forKey:@"width"];
        [newElementData setValue:22 forKey:@"height"];
        [newElementData setValue:@"Text Field" forKey:@"value"];
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

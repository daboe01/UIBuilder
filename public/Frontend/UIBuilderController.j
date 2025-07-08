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
    [newElementData setValue:@"Untitled " + elementType forKey:@"title"];
    [newElementData setValue:@"id_" + _elementCounter++ forKey:@"id"];

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
    [_elementsController addObject:newElementData];

    document.title = [[_elementsController arrangedObjects] count];
    [_elementsController setSelectedObjects:[CPArray arrayWithObject:newElementData]];
}

- (void)removeSelectedElements
{
    [_elementsController removeObjects:[_elementsController selectedObjects]];
}

#pragma mark - 
#pragma mark Keyboard Movement

- (void)moveSelectedElementsByDeltaX:(int)deltaX deltaY:(int)deltaY
{
    var selectedDataObjects = [_elementsController selectedObjects];

    for (var i = 0; i < [selectedDataObjects count]; i++)
    {
        var data = selectedDataObjects[i];
        var currentX = [data valueForKey:@"originX"];
        var currentY = [data valueForKey:@"originY"];

        [data setValue:currentX + deltaX forKey:@"originX"];
        [data setValue:currentY + deltaY forKey:@"originY"];
    }
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

        [_elementsController setSelectedObjects:@[]];

        for (var i = 0; i < [pastedElements count]; i++)
        {
            var elementData = pastedElements[i];
            var newElement = [elementData deepMutableCopy];

            // Offset the new element and give it a new ID
            [newElement setValue:[newElement valueForKey:@"originX"] + 10 forKey:@"originX"];
            [newElement setValue:[newElement valueForKey:@"originY"] + 10 forKey:@"originY"];
            [newElement setValue:@"id_" + _elementCounter++ forKey:@"id"];

            [_elementsController addObject:newElement];
            [_elementsController addSelectedObjects:[CPArray arrayWithObject:newElement]];
        }
    }
}

#pragma mark -
#pragma mark UICanvasView Delegate Methods

- (void)canvasView:(UICanvasView)aCanvas didMoveElement:(UIElementView)anElement
{
    // This method is called after a drag operation completes for one or more elements.
    // We update the data model for all selected objects to reflect their new positions.
    var selectedDataObjects = [_elementsController selectedObjects];
    var selectedViews = [aCanvas selectedSubViews];

    for (var i = 0; i < [selectedViews count]; i++)
    {
        var view = selectedViews[i];
        var data = [view dataObject];
        var frame = [view frame];
        
        // Find the corresponding data object and update its position.
        // Using KVC ensures that if the view is bound, it gets the final, snapped value.
        [data setValue:frame.origin.x forKey:@"originX"];
        [data setValue:frame.origin.y forKey:@"originY"];
    }
}

- (void)canvasView:(UICanvasView)aCanvas didResizeElement:(UIElementView)anElement
{
    // This method is called after a resize operation completes.
    var data = [anElement dataObject];
    var frame = [anElement frame];
    
    // Update size and position in the data model.
    [data setValue:frame.origin.x forKey:@"originX"];
    [data setValue:frame.origin.y forKey:@"originY"];
    [data setValue:frame.size.width forKey:@"width"];
    [data setValue:frame.size.height forKey:@"height"];
}

@end

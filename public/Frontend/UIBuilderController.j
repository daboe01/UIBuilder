//
//  UIBuilderController.j
//  This is the main controller for the UI Builder application.
//  It manages the data model for all elements on the canvas and acts
//  as a delegate for the UICanvasView to respond to user interactions.
//
//  By Daniel Boehringer in 2025.
//

@import <Foundation/CPObject.j>
@class UIElementView
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
    CPMutableArray _connections;
    int _elementCounter; // To generate unique IDs
    UICanvasView _canvasView @accessors(property=canvasView);
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
        _connectionsController = [[CPArrayController alloc] init];
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

- (CPDictionary)_ensureVBoxForWindow:(CPDictionary)windowData
{
    var children = [windowData valueForKey:@"children"];
    for (var i = 0; i < [children count]; i++) {
        if ([[children[i] valueForKey:@"type"] isEqualToString:@"vbox"]) {
            console.log("-> Found existing VBox in window.");
            return children[i];
        }
    }

    // No VBox found, create one.
    console.log("-> No VBox found in window. Creating one on-the-fly.");
    var vboxData = [CPConservativeDictionary dictionary];
    var vboxClass = [UIBuilderController classForElementType:@"vbox"];
    var windowWidth = [windowData valueForKey:@"width"];
    var windowHeight = [windowData valueForKey:@"height"];

    [vboxData setValue:@"vbox" forKey:@"type"];
    [vboxData setValue:@"id_" + _elementCounter++ forKey:@"id"];
    [vboxData setValue:[windowData valueForKey:@"id"] forKey:@"parentID"];

    var defaultVBoxValues = [vboxClass defaultValues];
    for (var key in defaultVBoxValues) {
        [vboxData setValue:defaultVBoxValues[key] forKey:key];
    }

    // Make the vbox fill the window's content area
    [vboxData setValue:0 forKey:@"originX"];
    [vboxData setValue:22 forKey:@"originY"]; // Below title bar
    [vboxData setValue:windowWidth forKey:@"width"];
    [vboxData setValue:windowHeight - 22 forKey:@"height"];
    [vboxData setValue:[] forKey:@"children"];

    [[windowData mutableArrayValueForKey:@"children"] addObject:vboxData];
    [_elementsController addObject:vboxData]; // IMPORTANT: Add to controller for KVO

    return vboxData;
}

- (void)addNewElementOfType:(CPString)elementType atPoint:(CGPoint)aPoint inParent:(CPDictionary)parentData
{
    [self addNewElementOfType:elementType atPoint:aPoint inParent:parentData atIndex:-1];
}

- (void)addNewElementOfType:(CPString)elementType atPoint:(CGPoint)aPoint inParent:(CPDictionary)parentData atIndex:(int)index
{
    console.log("UIBuilderController: addNewElementOfType:", elementType, "atPoint:", aPoint, "inParent:", parentData);

    if (parentData)
        console.log("-> Parent data type is: '" + [parentData valueForKey:@"type"] + "'");

    var isLayoutElement = (elementType === "hbox" || elementType === "vbox" || elementType === "hspace" || elementType === "vspace");

    // Scenario: Dropping into a window. Ensure it has a VBox.
    if (parentData && [parentData valueForKey:@"type"] === "window" && !isLayoutElement)
    {
        var vboxData = [self _ensureVBoxForWindow:parentData];
        // Retarget the drop operation to the VBox
        parentData = vboxData;
        console.log("-> Retargeted drop to VBox:", [parentData valueForKey:@"id"]);
    }

    // Scenario: Dropping a non-layout element into a VBox
    if (parentData && [parentData valueForKey:@"type"] === "vbox" && !isLayoutElement)
    {
        var canvas = [self canvasView];
        var viewAtDropPoint = [canvas viewAtPoint:aPoint];
        var targetHBox = nil;

        // Determine if the drop is on an existing HBox
        if (viewAtDropPoint)
        {
            var currentView = viewAtDropPoint;
            while(currentView && currentView != canvas) {
                if ([currentView isKindOfClass:[UIHBoxView class]]) {
                    targetHBox = [currentView dataObject];
                    break;
                }
                currentView = [currentView superview];
            }
        }

        if (targetHBox)
        {
            // Scenario 1: Dropped on an existing HBox. Add the element to it.
            console.log("-> VBox Drop: Adding to existing HBox:", [targetHBox valueForKey:@"id"]);
            [self addNewElementOfType:elementType atPoint:aPoint inParent:targetHBox atIndex:index];

            return;
        }
        else
        {
            // Scenario 2: Dropped elsewhere in the VBox. Create a new HBox at the bottom.
            console.log("-> VBox Drop: Creating new HBox at the end.");
            var newHBoxData = [self addNewHBoxInParent:parentData atIndex:-1]; // -1 appends to the end
            [_elementsController addObject:newHBoxData];

            // Add the new element inside the newly created HBox.
            [self addNewElementOfType:elementType atPoint:CGPointMake(0, 0) inParent:newHBoxData atIndex:index];
            // perform initial layout
            [[canvas viewForElementWithID:[newHBoxData valueForKey:@"id"]] layoutSubviews];
            return;
        }
    }

    var newElementData = [CPConservativeDictionary dictionary];
    var containerData = parentData || [self _containerDataAtPoint:aPoint];
    var viewClass = [UIBuilderController classForElementType:elementType];

    // Set default properties based on type
    [newElementData setValue:elementType forKey:@"type"];
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
    } else if (elementType === "label") {
        [newElementData setValue:100 forKey:@"width"];
        [newElementData setValue:20 forKey:@"height"];
    } else if (elementType === "hspace") {
        [newElementData setValue:50 forKey:@"width"];
        [newElementData setValue:20 forKey:@"height"];
    } else if (elementType === "vspace") {
        [newElementData setValue:20 forKey:@"width"];
        [newElementData setValue:50 forKey:@"height"];
    } else { // textfield
        [newElementData setValue:150 forKey:@"width"];
        [newElementData setValue:22 forKey:@"height"];
    }

    // Calculate centered position
    var elementWidth = [newElementData valueForKey:@"width"];
    var elementHeight = [newElementData valueForKey:@"height"];
    var centeredX = aPoint.x - (elementWidth / 2);
    var centeredY = aPoint.y - (elementHeight / 2);
    [newElementData setValue:centeredX forKey:@"originX"];
    [newElementData setValue:centeredY forKey:@"originY"];

    if (containerData && elementType !== "window")
    {
        console.log("-> Adding as child to container:", [containerData valueForKey:@"id"]);
        // Convert point to be relative to the container
        var relativeX = aPoint.x - [containerData valueForKey:@"originX"];
        var relativeY = aPoint.y - [containerData valueForKey:@"originY"];

        // For HBox, we don't center, we just add. Layout is managed by the HBox.
        if ([containerData valueForKey:@"type"] === 'hbox') {
             [newElementData setValue:0 forKey:@"originX"];
             [newElementData setValue:0 forKey:@"originY"];
        } else {
            [newElementData setValue:relativeX - (elementWidth / 2) forKey:@"originX"];
            [newElementData setValue:relativeY - (elementHeight / 2) forKey:@"originY"];
        }

        [newElementData setValue:[containerData valueForKey:@"id"] forKey:@"parentID"];
        var children = [containerData mutableArrayValueForKey:@"children"];
        if (index >= 0 && index < [children count])
            [children insertObject:newElementData atIndex:index];
        else
            [children addObject:newElementData];
    }

    // Add to the main elements controller to trigger KVO
    [[[[CPApp keyWindow] undoManager] prepareWithInvocationTarget:self] removeElement:newElementData fromParent:containerData];
    [[[CPApp keyWindow] undoManager] setActionName:@"Add Element"];

    var arrangedObjects = [_elementsController arrangedObjects];
    var insertionIndex = -1;

    if (containerData)
    {
        var childDataObjects = [containerData valueForKey:@"children"];
        var referenceChild = childDataObjects[index];
        insertionIndex = [arrangedObjects indexOfObject:referenceChild] - 1;
    }
    if (insertionIndex < 0)
        insertionIndex = 0;

    if (insertionIndex >= 0 && insertionIndex <= [arrangedObjects count])
    {
        [_elementsController insertObject:newElementData atArrangedObjectIndex:insertionIndex];
    }
    else
        [_elementsController insertObject:newElementData];


    // If we just created a new top-level window, ensure it has a VBox by default.
    if (elementType === "window" && !containerData) {
        [self _ensureVBoxForWindow:newElementData];
    }

    [_elementsController setSelectedObjects:[CPArray arrayWithObject:newElementData]];
    console.log("-> Finished addNewElementOfType. New element data:", newElementData);
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

- (void)removeElement:(CPDictionary)elementData fromParent:(CPDictionary)parentData
{
    if (parentData)
    {
        [[parentData mutableArrayValueForKey:@"children"] removeObject:elementData];
    }
    [_elementsController removeObject:elementData];
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

        // 1. Declare that you are providing BOTH a custom type and a standard string type.
        [pboard declareTypes:[UIBuilderElementPboardType, CPStringPboardType] owner:nil];

        // 2. Set the data for your custom type, for your app's internal 'paste' to use.
        [pboard setData:data forType:UIBuilderElementPboardType];

        // 3. Set a string representation for the browser and other applications.
        //    This can be a simple description or a more complex JSON representation.
        var description = [selectedData count] + " UI element(s) copied.";
        [pboard setString:description forType:CPStringPboardType];
    }
}

- (void)_assignNewIDsToElement:(CPMutableDictionary)elementData
{
    [elementData setValue:@"id_" + _elementCounter++ forKey:@"id"];

    var children = [elementData valueForKey:@"children"];
    if (children)
    {
        var newChildren = [CPMutableArray array];
        for (var i = 0; i < [children count]; i++)
        {
            var child = children[i];
            // Deep copy child before modifying
            var newChild = [CPKeyedUnarchiver unarchiveObjectWithData:[CPKeyedArchiver archivedDataWithRootObject:child]];
            [newChild setValue:[elementData valueForKey:@"id"] forKey:@"parentID"];
            [self _assignNewIDsToElement:newChild];
            [newChildren addObject:newChild];
        }
        [elementData setValue:newChildren forKey:@"children"];
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

        // Determine the target container
        var targetContainer = nil;
        var selectedObjects = [_elementsController selectedObjects];
        if ([selectedObjects count] > 0)
        {
            var firstSelected = selectedObjects[0];
            var parentID = [firstSelected valueForKey:@"parentID"];
            if (parentID)
            {
                // Find the parent container in the elements controller
                var allElements = [_elementsController arrangedObjects];
                for (var i = 0; i < [allElements count]; i++)
                {
                    if ([[allElements[i] valueForKey:@"id"] isEqualToString:parentID])
                    {
                        targetContainer = allElements[i];
                        break;
                    }
                }
            }
            else
            {
                // If the selected object has no parent, it must be a window
                targetContainer = firstSelected;
            }
        }
        else
        {
            // If no selection, find the first window
            var allElements = [_elementsController arrangedObjects];
            for (var i = 0; i < [allElements count]; i++)
            {
                if ([[allElements[i] valueForKey:@"type"] isEqualToString:@"window"])
                {
                    targetContainer = allElements[i];
                    break;
                }
            }
        }

        for (var i = 0; i < [pastedElements count]; i++)
        {
            var newElement = [CPKeyedUnarchiver unarchiveObjectWithData:[CPKeyedArchiver archivedDataWithRootObject:pastedElements[i]]];

            [newElement setValue:[newElement valueForKey:@"originX"] + 10 forKey:@"originX"];
            [newElement setValue:[newElement valueForKey:@"originY"] + 10 forKey:@"originY"];
            
            [self _assignNewIDsToElement:newElement];

            if (targetContainer && [newElement valueForKey:@"type"] !== @"window")
            {
                [newElement setValue:[targetContainer valueForKey:@"id"] forKey:@"parentID"];
                [[targetContainer mutableArrayValueForKey:@"children"] addObject:newElement];
            }
            else
            {
                [newElement removeObjectForKey:@"parentID"];
            }

            [_elementsController addObject:newElement];
            
            if ([newElement valueForKey:@"children"])
                [_elementsController addObjects:[newElement valueForKey:@"children"]];

            [newSelection addObject:newElement];
        }
        
        [[[[CPApp keyWindow] undoManager] prepareWithInvocationTarget:_elementsController] removeObjects:newSelection];
        [[[CPApp keyWindow] undoManager] setActionName:@"Paste"];
        [_elementsController setSelectedObjects:newSelection];
    }
}

- (CPDictionary)parentOfElement:(CPDictionary)elementData
{
    var parentID = [elementData valueForKey:@"parentID"];
    if (!parentID) return nil;

    var allElements = [_elementsController arrangedObjects];
    for (var i = 0; i < [allElements count]; i++)
    {
        if ([[allElements[i] valueForKey:@"id"] isEqualToString:parentID])
            return allElements[i];
    }
    return nil;
}

- (void)addNewElementOfType:(CPString)elementType inNewWindowAtPoint:(CGPoint)aPoint
{
    // 1. Create the window data
    var windowData = [CPConservativeDictionary dictionary];
    var windowClass = [UIBuilderController classForElementType:@"window"];
    var windowWidth = 250, windowHeight = 200;
    [windowData setValue:@"window" forKey:@"type"];
    [windowData setValue:@"id_" + _elementCounter++ forKey:@"id"];
    [windowData setValue:windowWidth forKey:@"width"];
    [windowData setValue:windowHeight forKey:@"height"];
    [windowData setValue:[] forKey:@"children"];

    var defaultWindowValues = [windowClass defaultValues];
    for (var key in defaultWindowValues) {
        [windowData setValue:defaultWindowValues[key] forKey:key];
    }

    // 2. Position the window so its center is at the drop point
    [windowData setValue:aPoint.x - (windowWidth / 2) forKey:@"originX"];
    [windowData setValue:aPoint.y - (windowHeight / 2) forKey:@"originY"];

    // 3. Add the window to the elements controller
    [[[[CPApp keyWindow] undoManager] prepareWithInvocationTarget:_elementsController] removeObject:windowData];
    [[[CPApp keyWindow] undoManager] setActionName:@"Add Element in New Window"];
    [_elementsController addObject:windowData];

    // 4. Create the VBox data and add it as a child of the window
    var vboxData = [CPConservativeDictionary dictionary];
    var vboxClass = [UIBuilderController classForElementType:@"vbox"];
    [vboxData setValue:@"vbox" forKey:@"type"];
    [vboxData setValue:@"id_" + _elementCounter++ forKey:@"id"];
    [vboxData setValue:[windowData valueForKey:@"id"] forKey:@"parentID"];
    var defaultVBoxValues = [vboxClass defaultValues];
    for (var key in defaultVBoxValues) {
        [vboxData setValue:defaultVBoxValues[key] forKey:key];
    }
    // Make the vbox fill the window's content area
    [vboxData setValue:0 forKey:@"originX"];
    [vboxData setValue:22 forKey:@"originY"]; // Below title bar
    [vboxData setValue:windowWidth forKey:@"width"];
    [vboxData setValue:windowHeight - 22 forKey:@"height"];
    [vboxData setValue:[] forKey:@"children"];

    [[windowData mutableArrayValueForKey:@"children"] addObject:vboxData];
    [_elementsController addObject:vboxData];


    // 5. Add the new element inside the VBOX
    [self addNewElementOfType:elementType atPoint:CGPointMake(0,0) inParent:vboxData];

    // 6. Select the newly added element
    var newElementData = [[vboxData valueForKey:@"children"] objectAtIndex:0];
    [_elementsController setSelectedObjects:[CPArray arrayWithObject:newElementData]];

    console.log("UIBuilderController: addNewElementOfType:inNewWindowAtPoint: - Added new element in new window.");
}

- (CPDictionary)addNewHBoxInParent:(CPDictionary)parentData
{
    var hboxData = [CPConservativeDictionary dictionary];
    var hboxClass = [UIBuilderController classForElementType:@"hbox"];
    [hboxData setValue:@"hbox" forKey:@"type"];
    [hboxData setValue:@"id_" + _elementCounter++ forKey:@"id"];
    [hboxData setValue:[parentData valueForKey:@"id"] forKey:@"parentID"];
    var defaultHBoxValues = [hboxClass defaultValues];
    for (var key in defaultHBoxValues) {
        [hboxData setValue:defaultHBoxValues[key] forKey:key];
    }
    [hboxData setValue:0 forKey:@"originX"];
    [hboxData setValue:0 forKey:@"originY"];
    [hboxData setValue:[parentData valueForKey:@"width"] forKey:@"width"];
    [hboxData setValue:50 forKey:@"height"]; // Default height
    [hboxData setValue:[] forKey:@"children"];

    [[parentData mutableArrayValueForKey:@"children"] addObject:hboxData];

    return hboxData;
}

- (CPDictionary)addNewHBoxInParent:(CPDictionary)parentData atIndex:(int)index
{
    var hboxData = [CPConservativeDictionary dictionary];
    var hboxClass = [UIBuilderController classForElementType:@"hbox"];
    [hboxData setValue:@"hbox" forKey:@"type"];
    [hboxData setValue:@"id_" + _elementCounter++ forKey:@"id"];
    [hboxData setValue:[parentData valueForKey:@"id"] forKey:@"parentID"];
    var defaultHBoxValues = [hboxClass defaultValues];
    for (var key in defaultHBoxValues) {
        [hboxData setValue:defaultHBoxValues[key] forKey:key];
    }
    [hboxData setValue:0 forKey:@"originX"];
    [hboxData setValue:0 forKey:@"originY"]; // VBox will handle layout
    [hboxData setValue:[parentData valueForKey:@"width"] forKey:@"width"];
    [hboxData setValue:50 forKey:@"height"]; // Default height
    [hboxData setValue:[] forKey:@"children"];

    var parentChildren = [parentData mutableArrayValueForKey:@"children"];
    if (index >= 0 && index <= [parentChildren count]) {
        [parentChildren insertObject:hboxData atIndex:index];
    } else {
        [parentChildren addObject:hboxData]; // Fallback to adding at the end
    }
    
    return hboxData;
}

- (CPDictionary)addNewHBoxAfterHBox:(CPDictionary)siblingHBoxData inParent:(CPDictionary)parentData
{
    var hboxData = [CPConservativeDictionary dictionary];
    var hboxClass = [UIBuilderController classForElementType:@"hbox"];
    [hboxData setValue:@"hbox" forKey:@"type"];
    [hboxData setValue:@"id_" + _elementCounter++ forKey:@"id"];
    [hboxData setValue:[parentData valueForKey:@"id"] forKey:@"parentID"];
    var defaultHBoxValues = [hboxClass defaultValues];
    for (var key in defaultHBoxValues) {
        [hboxData setValue:defaultHBoxValues[key] forKey:key];
    }
    [hboxData setValue:0 forKey:@"originX"];
    [hboxData setValue:0 forKey:@"originY"];
    [hboxData setValue:[parentData valueForKey:@"width"] forKey:@"width"];
    [hboxData setValue:50 forKey:@"height"]; // Default height
    [hboxData setValue:[] forKey:@"children"];

    var parentChildren = [parentData mutableArrayValueForKey:@"children"];
    var index = [parentChildren indexOfObject:siblingHBoxData];
    if (index != CPNotFound)
    {
        [parentChildren insertObject:hboxData atIndex:index + 1];
    }
    else
    {
        [parentChildren addObject:hboxData];
    }
    
    return hboxData;
}

- (void)addNewElementOfType:(CPString)elementType inWindow:(CPDictionary)windowData atPoint:(CGPoint)aPoint
{
    // This method is now deprecated. Use addNewElementOfType:atPoint:inParent: instead.
    console.error("addNewElementOfType:inWindow:atPoint: is deprecated. Use addNewElementOfType:atPoint:inParent: instead.");
    [self addNewElementOfType:elementType atPoint:aPoint inParent:windowData];
}

- (void)addConnectionFrom:(CPDictionary)sourceData to:(CPDictionary)targetData atPoint:(CGPoint)atPoint outlet:(CPString)outlet action:(CPString)action
{
    var newConnection = [CPConservativeDictionary dictionary];
    [newConnection setValue:[sourceData valueForKey:@"id"] forKey:@"sourceID"];
    [newConnection setValue:[targetData valueForKey:@"id"] forKey:@"targetID"];
    [newConnection setValue:outlet forKey:@"outlet"];
    [newConnection setValue:action forKey:@"action"];
    [newConnection setValue:@"connection_" + _elementCounter++ forKey:@"id"];
    
    if (atPoint)
        [newConnection setValue:{x: atPoint.x, y: atPoint.y} forKey:@"atPoint"];

    [[[[CPApp keyWindow] undoManager] prepareWithInvocationTarget:_connectionsController] removeObject:newConnection];
    [[[CPApp keyWindow] undoManager] setActionName:@"Add Connection"];

    [_connectionsController addObject:newConnection];

    console.log("UIBuilderController: addConnectionFrom:to: - Added connection: ", newConnection);
    console.log("Connections controller count after add: " + [[_connectionsController arrangedObjects] count]);
}

- (void)removeConnection:(CPDictionary)connection
{
    [[[[CPApp keyWindow] undoManager] prepareWithInvocationTarget:_connectionsController] addObject:connection];
    [[[CPApp keyWindow] undoManager] setActionName:@"Remove Connection"];

    [_connectionsController removeObject:connection];
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

- (void)canvasView:(UICanvasView)aCanvas didConnectElement:(UIElementView)sourceElement toElement:(UIElementView)targetElement asTargetAction:(CPString)actionName
{
    var sourceData = [sourceElement dataObject];
    var targetData = [targetElement dataObject];

    // For a target-action, the outlet is typically 'target'
    var outletName = @"target";

    [self addConnectionFrom:sourceData to:targetData atPoint:nil outlet:outletName action:actionName];
}

- (void)canvasView:(UICanvasView)aCanvas didConnectElement:(UIElementView)sourceElement toElement:(UIElementView)targetElement asOutlet:(CPString)outletName
{
    var sourceData = [sourceElement dataObject];
    var targetData = [targetElement dataObject];

    // For a simple outlet connection, there is no action.
    var actionName = nil;

    [self addConnectionFrom:sourceData to:targetData atPoint:nil outlet:outletName action:actionName];
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

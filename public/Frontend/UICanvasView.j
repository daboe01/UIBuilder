//
//  UICanvasView.j
//  A full-window canvas for the UI Builder.
//
//  By Daniel Boehringer in 2025.
//  - It acts as a drag-and-drop destination for new UI elements from the palette.
//  - It correctly instantiates different UIElementView subclasses based on the data model.
//

@import "UIElementView.j";

// These are the types we can drag from the palette.
// They must match the types used in the palette's draggable symbols.
var UIWindowDragType = "UIWindowDragType";
var UIButtonDragType = "UIButtonDragType";
var UISliderDragType = "UISliderDragType";
var UITextFieldDragType = "UITextFieldDragType";

@implementation UICanvasView : CPView
{
    // Data binding ivars
    id               _dataObjectsContainer;
    CPString         _dataObjectsKeyPath;
    id               _selectionIndexesContainer;
    CPString         _selectionIndexesKeyPath;
    CPArray          _oldDataObjects;

    // Rubber-band selection ivars
    CGPoint          _rubberStart;
    CGPoint          _rubberEnd;
    BOOL             _isRubbing;
    
    id               _delegate;
}

-(BOOL)acceptsFirstMouse:(CPEvent)aEvent
{
    return YES;
}

// KVO contexts
var _propertyObservationContext = 1091;
var _dataObjectsObservationContext = 1092;
var _selectionIndexesObservationContext = 1093;

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        // Register to accept drops from the palette
        [self registerForDraggedTypes:[
            UIWindowDragType,
            UIButtonDragType,
            UISliderDragType,
            UITextFieldDragType
        ]];
    }
    return self;
}

#pragma mark - Bindings & KVO (Largely from EFLaceView)

+ (void)initialize
{
    [self exposeBinding:"dataObjects"];
    [self exposeBinding:"selectionIndexes"];
}

- (void)bind:(CPString)bindingName toObject:(id)observableObject withKeyPath:(CPString)observableKeyPath options:(CPDictionary)options
{
    if ([bindingName isEqualToString:@"dataObjects"])
    {
        _dataObjectsContainer = observableObject;
        _dataObjectsKeyPath = observableKeyPath;
        [_dataObjectsContainer addObserver:self forKeyPath:_dataObjectsKeyPath options:(CPKeyValueObservingOptionNew | CPKeyValueObservingOptionOld) context:_dataObjectsObservationContext];
        [self startObservingDataObjects:[self dataObjects]];
        _oldDataObjects = [[self dataObjects] copy] || @[];
    }
    else if ([bindingName isEqualToString:@"selectionIndexes"])
    {
        _selectionIndexesContainer = observableObject;
        _selectionIndexesKeyPath = observableKeyPath;
        [_selectionIndexesContainer addObserver:self forKeyPath:_selectionIndexesKeyPath options:0 context:_selectionIndexesObservationContext];
    }
    else { [super bind:bindingName toObject:observableObject withKeyPath:observableKeyPath options:options]; }

    [self setNeedsDisplay:YES];
}

- (void)unbind:(CPString)bindingName
{
    if ([bindingName isEqualToString:@"dataObjects"]) {
        [self stopObservingDataObjects:[self dataObjects]];
        [_dataObjectsContainer removeObserver:self forKeyPath:_dataObjectsKeyPath];
        _dataObjectsContainer = nil; _dataObjectsKeyPath = nil;
    } else if ([bindingName isEqualToString:@"selectionIndexes"]) {
        [_selectionIndexesContainer removeObserver:self forKeyPath:_selectionIndexesKeyPath];
        _selectionIndexesContainer = nil; _selectionIndexesKeyPath = nil;
    } else { [super unbind:bindingName]; }
    [self setNeedsDisplay:YES];
}

- (CPArray)dataObjects
{
    var result = [_dataObjectsContainer valueForKeyPath:_dataObjectsKeyPath];
    return (result == [CPNull null]) ? @[] : result;
}

- (CPIndexSet)selectionIndexes
{
    return [_selectionIndexesContainer valueForKeyPath:_selectionIndexesKeyPath];
}

- (void)startObservingDataObjects:(CPArray)dataObjects
{
    if (!dataObjects || dataObjects == [CPNull null]) return;

    for (var i = 0;  i < [dataObjects count]; i++)
    {
        var newDataObject =  dataObjects[i];
        [self _createViewForDataObject:newDataObject superview:self];
    }
}

- (void)_createViewForDataObject:(CPDictionary)dataObject superview:(CPView)superview
{
    var type = [dataObject valueForKey:@"type"];
    var newView;

    // === THIS IS THE KEY CHANGE ===
    // Instantiate the correct view based on the data model's 'type'
    if (type === "window") newView = [[UIWindowView alloc] init];
    else if (type === "button") newView = [[UIButtonView alloc] init];
    else if (type === "slider") newView = [[UISliderView alloc] init];
    else if (type === "textfield") newView = [[UITextFieldView alloc] init];
    else newView = [[UIElementView alloc] init]; // Fallback

    [superview addSubview:newView];
    [newView setDataObject:dataObject];

    // Bind view properties to the data model
    [newView bind:@"title" toObject:dataObject withKeyPath:@"title" options:nil];
    [newView bind:@"originX" toObject:dataObject withKeyPath:@"originX" options:nil];
    [newView bind:@"originY" toObject:dataObject withKeyPath:@"originY" options:nil];
    [newView bind:@"width" toObject:dataObject withKeyPath:@"width" options:nil];
    [newView bind:@"height" toObject:dataObject withKeyPath:@"height" options:nil];

    if (type === "window")
    {
        var children = [dataObject valueForKey:@"children"];
        for (var j = 0; j < [children count]; j++)
        {
            [self _createViewForDataObject:children[j] superview:newView];
        }
    }
}

- (void)stopObservingDataObjects:(CPArray)dataObjects
{
    if (!dataObjects || dataObjects == [CPNull null]) return;

    var viewsToRemove = [];
    for (var i = 0; i < [[self subviews] count]; i++) {
        var aView = [self subviews][i];
        if ([dataObjects containsObject:[aView dataObject]]) {
            [viewsToRemove addObject:aView];
        }
    }
    
    for (var i = 0; i < [viewsToRemove count]; i++) {
        var viewToRemove = viewsToRemove[i];
        [self _removeViewAndChildren:viewToRemove];
    }
}

- (void)_removeViewAndChildren:(UIElementView)viewToRemove
{
    // Unbind everything before removing
    [viewToRemove unbind:@"title"];
    [viewToRemove unbind:@"originX"];
    [viewToRemove unbind:@"originY"];
    [viewToRemove unbind:@"width"];
    [viewToRemove unbind:@"height"];

    var subviews = [[viewToRemove subviews] copy];
    for (var i = 0; i < [subviews count]; i++)
    {
        [self _removeViewAndChildren:subviews[i]];
    }

    [viewToRemove removeFromSuperview];
}

- (void)observeValueForKeyPath:(CPString)keyPath ofObject:(id)object change:(CPDictionary)change context:(id)context
{
    if (context == _dataObjectsObservationContext)
    {
        var newDataObjects = [object valueForKeyPath:_dataObjectsKeyPath];
        var oldDataObjects = _oldDataObjects;

        var added = [newDataObjects mutableCopy];
        [added removeObjectsInArray:oldDataObjects];
        [self startObservingDataObjects:added];

        var removed = [oldDataObjects mutableCopy];
        [removed removeObjectsInArray:newDataObjects];
        [self stopObservingDataObjects:removed];

        _oldDataObjects = [newDataObjects copy];
        [self setNeedsDisplay:YES];
    }
    else if (context == _selectionIndexesObservationContext)
    {
        [[self subviews] makeObjectsPerformSelector:@selector(setNeedsDisplay:) withObject:YES];
    }
}


#pragma mark - Drawing & Mouse

- (void)drawRect:(CPRect)rect
{
    // The background is drawn by the window. We only draw the rubber-band.
    if (_isRubbing)
    {
        var rubber = CGRectUnion(CGRectMake(_rubberStart.x, _rubberStart.y, 0.1, 0.1), CGRectMake(_rubberEnd.x, _rubberEnd.y, 0.1, 0.1));
        [[[[CPColor alternateSelectedControlColor] colorWithAlphaComponent:0.2] setFill]];
        [CPBezierPath fillRect:rubber];
        [[CPColor alternateSelectedControlColor] setStroke];
        [CPBezierPath setDefaultLineWidth:1.0];
        [CPBezierPath strokeRect:rubber];
    }
}

- (void)mouseDown:(CPEvent)theEvent
{
    // A click on the canvas background starts a rubber-band selection.
    [self deselectViews];
    _isRubbing = YES;
    _rubberStart = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    _rubberEnd = _rubberStart;

    [CPApp setTarget:self selector:@selector(_dragOpenSpaceWithEvent:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
}

- (void)_dragOpenSpaceWithEvent:(CPEvent)theEvent
{
    var mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    _rubberEnd = mouseLoc;
    var rubberRect = CGRectUnion(CGRectMake(_rubberStart.x, _rubberStart.y, 1, 1), CGRectMake(_rubberEnd.x, _rubberEnd.y, 1, 1));
    
    switch ([theEvent type])
    {
        case CPLeftMouseDragged:
            var indexesToSelect = [CPMutableIndexSet indexSet];
            var allDataObjects = [self dataObjects];
            for (var i = 0; i < [[self subviews] count]; i++) {
                var aView = [self subviews][i];
                if (CGRectIntersectsRect([aView frame], rubberRect)) {
                    var dataIndex = [allDataObjects indexOfObject:[aView dataObject]];
                    if (dataIndex != CPNotFound) {
                        [indexesToSelect addIndex:dataIndex];
                    }
                }
            }
            [_selectionIndexesContainer setValue:indexesToSelect forKeyPath:_selectionIndexesKeyPath];
            [self setNeedsDisplay:YES];
            [CPApp setTarget:self selector:@selector(_dragOpenSpaceWithEvent:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
            break;
        
        case CPLeftMouseUp:
            _isRubbing = NO;
            [self setNeedsDisplay:YES];
            break;
    }
}

- (void)delete:(id)sender
{
    // Forward the delete action to the delegate/controller
    if (_delegate && [_delegate respondsToSelector:@selector(removeSelectedElements)]) {
        [_delegate removeSelectedElements];
    }
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

#pragma mark - Drag and Drop Destination

- (CPDragOperation)draggingEntered:(CPDraggingInfo)sender
{
    // We accept any of the registered types
    return CPDragOperationCopy;
}

- (BOOL)performDragOperation:(CPDraggingInfo)sender
{
    var dropPoint = [self convertPoint:[sender draggingLocation] fromView:nil];
    var pasteboard = [sender draggingPasteboard];
    var types = [pasteboard types];
    var draggedType = types[0]; // Assuming only one type is being dragged
    var elementType;
    
    // Convert Drag Type to Element Type
    if (draggedType === UIWindowDragType) elementType = "window";
    else if (draggedType === UIButtonDragType) elementType = "button";
    else if (draggedType === UISliderDragType) elementType = "slider";
    else if (draggedType === UITextFieldDragType) elementType = "textfield";

    if (elementType && _delegate && [_delegate respondsToSelector:@selector(addNewElementOfType:atPoint:)])
    {
        if (elementType === "window")
        {
            [_delegate addNewElementOfType:elementType atPoint:dropPoint];
            [self setNeedsDisplay:YES];
            return YES;
        }
    }

    return NO;
}

#pragma mark - Delegate & Selection Management

- (id)delegate { return _delegate; }
- (void)setDelegate:(id)newDelegate { _delegate = newDelegate; }

- (void)deselectViews
{
    [_selectionIndexesContainer setValue:nil forKeyPath:_selectionIndexesKeyPath];
}

- (void)selectView:(UIElementView)aView state:(BOOL)select
{
    var selection = [[self selectionIndexes] mutableCopy] || [CPMutableIndexSet indexSet];
    var dataObjectIndex = [[self dataObjects] indexOfObject:[aView dataObject]];

    if (dataObjectIndex != CPNotFound) {
        if (select) [selection addIndex:dataObjectIndex];
        else [selection removeIndex:dataObjectIndex];
    }
    
    [_selectionIndexesContainer setValue:selection forKeyPath:_selectionIndexesKeyPath];
}

- (CPArray)selectedSubViews
{
    var selectedDataObjects = [[self dataObjects] objectsAtIndexes:[self selectionIndexes]];
    var selectedViews = [];

    for (var i = 0; i < [[self subviews] count]; i++) {
        var aView = [self subviews][i];
        if ([selectedDataObjects containsObject:[aView dataObject]]) {
            [selectedViews addObject:aView];
        }
    }
    return selectedViews;
}

// These methods are called by the UIElementView children to notify the controller
- (void)elementDidMove:(UIElementView)anElement
{
    if (_delegate && [_delegate respondsToSelector:@selector(canvasView:didMoveElement:)]) {
        [_delegate canvasView:self didMoveElement:anElement];
    }
}

- (void)elementDidResize:(UIElementView)anElement
{
    if (_delegate && [_delegate respondsToSelector:@selector(canvasView:didResizeElement:)]) {
        [_delegate canvasView:self didResizeElement:anElement];
    }
}

@end

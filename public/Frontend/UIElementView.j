//
//  UIElementView.j by Daniel Böhringer in 2025

//  This file is a drawing engine for a UI builder, with features such as:
//      - Skeleton drawing for common UI elements (Window, Button, Slider, TextField).
//      - Selection highlights.
//      - Resize handles ("dimples") on selected views.
//      - Mouse logic for moving and resizing elements.
//      - Visual hints for drop targets (e.g., a Window accepting a Button).
//
//

// --- Drag Types --- (have to be global, no var)
UIBuilderElementPboardType = "UIBuilderElementPboardType";
UIWindowDragType = "UIWindowDragType";
UIButtonDragType = "UIButtonDragType";
UISliderDragType = "UISliderDragType";
UITextFieldDragType = "UITextFieldDragType";

// --- Constants for Resizing ---
var kUIElementHandleSize = 8.0;
var kUIElementNoHandle = 0;
var kUIElementTopLeftHandle = 1;
var kUIElementTopMiddleHandle = 2;
var kUIElementTopRightHandle = 3;
var kUIElementMiddleLeftHandle = 4;
var kUIElementMiddleRightHandle = 5;
var kUIElementBottomLeftHandle = 6;
var kUIElementBottomMiddleHandle = 7;
var kUIElementBottomRightHandle = 8;


@class UIWindowView
@class UIButtonView
@class UISliderView
@class UITextFieldView;

@implementation UIElementView : CPView
{
    CPString                _title;
    CPMutableDictionary     _stringAttributes;
    id                      _dataObject @accessors(property=dataObject);

    // State for dragging and resizing
    CGPoint                 _lastMouseLoc;
    int                     _activeHandle;
    BOOL                    _isDragTarget; // Used by subclasses (e.g. UIWindowView)
    CPTrackingArea          _trackingArea;
    BOOL                    _isContainer;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _stringAttributes = [[CPMutableDictionary alloc] init];
        [_stringAttributes setObject:[CPFont boldSystemFontOfSize:12] forKey:CPFontAttributeName];
        [_stringAttributes setObject:[CPColor blackColor] forKey:CPForegroundColorAttributeName];

        _title = @"Element";
        _activeHandle = kUIElementNoHandle;

        if ([self frame].size.width < 50 || [self frame].size.height < 20)
            [self setFrameSize:CGSizeMake(MAX(50, [self frame].size.width), MAX(20, [self frame].size.height))];

        [self setNeedsDisplay:YES];

        _trackingArea = [[CPTrackingArea alloc] initWithRect:CGRectMakeZero()
                                                    options:CPTrackingMouseMoved | CPTrackingActiveInKeyWindow | CPTrackingInVisibleRect | CPTrackingMouseEnteredAndExited
                                                      owner:self
                                                   userInfo:nil];
        [self addTrackingArea:_trackingArea];
        _isContainer = NO;
    }
    return self;
}

- (BOOL)acceptsFirstMouse
{
    // This view should accept first mouse events for interaction.
    return YES;
}

- (void)removeFromSuperview
{
    // This is the correct place to clean up view-related resources.
    // When the view is removed from its superview, we no longer need to track
    // mouse events within its bounds.
    [self removeTrackingArea:_trackingArea];
    
    // It's crucial to call the superclass's implementation at the end.
    [super removeFromSuperview];
}

#pragma mark -
#pragma mark *** Geometry Accessors (for KVC Binding) ***

- (float)originX
{
    return [self frame].origin.x;
}

- (void)setOriginX:(float)aFloat
{
    // Only update if the value has actually changed.
    if (aFloat !== [self originX])
    {
        var frame = [self frame];
        frame.origin.x = aFloat;
        [self setFrame:frame];
        
        // Notify the superview (the canvas) that it might need to redraw
        // if anything depends on this view's position.
        [[self superview] setNeedsDisplay:YES];
    }
}

- (float)originY
{
    return [self frame].origin.y;
}

- (void)setOriginY:(float)aFloat
{
    if (aFloat !== [self originY])
    {
        var frame = [self frame];
        frame.origin.y = aFloat;
        [self setFrame:frame];
        [[self superview] setNeedsDisplay:YES];
    }
}

- (float)width
{
    return [self frame].size.width;
}

- (void)setWidth:(float)aFloat
{
    if (aFloat !== [self width])
    {
        var frame = [self frame];
        // Enforce a minimum width to prevent rendering issues.
        frame.size.width = MAX(aFloat, 20.0);
        [self setFrame:frame];
        [[self superview] setNeedsDisplay:YES];
    }
}

- (float)height
{
    return [self frame].size.height;
}

- (void)setHeight:(float)aFloat
{
    if (aFloat !== [self height])
    {
        var frame = [self frame];
        // Enforce a minimum height.
        frame.size.height = MAX(aFloat, 20.0);
        [self setFrame:frame];
        [[self superview] setNeedsDisplay:YES];
    }
}

#pragma mark -
#pragma mark *** Accessors ***

- (CPString)title
{
    return (_title == nil) ? @"" : _title;
}

- (void)setTitle:(CPString)aTitle
{
    if (aTitle != _title)
    {
        _title = aTitle;
        [self setNeedsDisplay:YES];
    }
}

// You will need a way to get a reference to the canvas.
// This is often done by walking up the superview chain.
- (UICanvasView)canvas
{
    var aView = self;
    while (aView = [aView superview]) {
        if ([aView isKindOfClass:[UICanvasView class]])
            return aView;
    }
    return nil;
}

#pragma mark -
#pragma mark *** Drawing ***

- (void)drawRect:(CGRect)rect
{
    // 1. Draw the specific skeleton for the element subclass
    [self drawSkeleton:rect];

    // 2. If this view is a drop target, draw a highlight
    if (_isDragTarget)
    {
        [[[CPColor redColor] colorWithAlphaComponent:0.8] setStroke];
        var highlightPath = [CPBezierPath bezierPathWithRect:CGRectInset([self bounds], 1, 1)];
        [highlightPath setLineWidth:2.0];
        [highlightPath stroke];
    }

    // 3. If selected, draw selection outline and resize handles
    if ([self isSelected])
    {
        // Draw selection highlight
        [[CPColor keyboardFocusIndicatorColor] setStroke];
        var selectionPath = [CPBezierPath bezierPathWithRect:CGRectInset([self bounds], -2, -2)];
        [selectionPath setLineWidth:1.0];
        [selectionPath stroke];

        // Draw resize handles ("dimples")
        [self drawHandles];
    }
}

- (void)drawSkeleton:(CGRect)rect
{
    // Base implementation: a simple placeholder box.
    // Subclasses should override this to draw their specific look.
    var bounds = [self bounds];
    [[CPColor lightGrayColor] setFill];
    [CPBezierPath fillRect:bounds];
    [[CPColor darkGrayColor] setStroke];
    [CPBezierPath strokeRect:bounds];

    var titleSize = [[self title] sizeWithAttributes:_stringAttributes];
    [[self title] drawAtPoint:CGPointMake((bounds.size.width - titleSize.width) / 2.0, (bounds.size.height - titleSize.height) / 2.0) withAttributes:_stringAttributes];
}

- (CGRect)rectForHandle:(int)handle
{
    var bounds = [self bounds];
    var x, y;

    // Top Row
    if (handle >= kUIElementTopLeftHandle && handle <= kUIElementTopRightHandle)
        y = bounds.origin.y - kUIElementHandleSize / 2.0;
    // Middle Row
    if (handle === kUIElementMiddleLeftHandle || handle === kUIElementMiddleRightHandle)
        y = bounds.origin.y + bounds.size.height / 2.0 - kUIElementHandleSize / 2.0;
    // Bottom Row
    if (handle >= kUIElementBottomLeftHandle && handle <= kUIElementBottomRightHandle)
        y = bounds.origin.y + bounds.size.height - kUIElementHandleSize / 2.0;

    // Left Column
    if (handle === kUIElementTopLeftHandle || handle === kUIElementMiddleLeftHandle || handle === kUIElementBottomLeftHandle)
        x = bounds.origin.x - kUIElementHandleSize / 2.0;
    // Center Column
    if (handle === kUIElementTopMiddleHandle || handle === kUIElementBottomMiddleHandle)
        x = bounds.origin.x + bounds.size.width / 2.0 - kUIElementHandleSize / 2.0;
    // Right Column
    if (handle === kUIElementTopRightHandle || handle === kUIElementMiddleRightHandle || handle === kUIElementBottomRightHandle)
        x = bounds.origin.x + bounds.size.width - kUIElementHandleSize / 2.0;

    return CGRectMake(x, y, kUIElementHandleSize, kUIElementHandleSize);
}

- (void)drawHandles
{
    [[CPColor controlDarkShadowColor] setFill];
    for (var i = 1; i <= 8; i++)
    {
        [CPBezierPath fillRect:[self rectForHandle:i]];
    }
}

- (BOOL)isSelected
{
    return [[self canvas] isViewSelected:self];
}

#pragma mark -
#pragma mark *** Mouse Handling & Resizing ***

- (int)handleAtPoint:(CGPoint)aPoint
{
    if (![self isSelected]) return kUIElementNoHandle;

    for (var i = 1; i <= 8; i++)
    {
        if (CGRectContainsPoint([self rectForHandle:i], aPoint))
            return i;
    }
    return kUIElementNoHandle;
}

- (void)mouseDown:(CPEvent)theEvent
{
    var canvas = [self canvas];
    var localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];

    // First, check if we clicked a resize handle
    _activeHandle = [self handleAtPoint:localPoint];
    if (_activeHandle != kUIElementNoHandle)
    {
        // A handle was clicked, begin a resize session
        _lastMouseLoc = [[self superview] convertPoint:[theEvent locationInWindow] fromView:nil];
        [CPApp setTarget:self selector:@selector(_resizeWithEvent:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
        return;
    }

    // No handle was clicked, proceed with selection and movement logic
    if ([theEvent modifierFlags] & CPShiftKeyMask)
    {
        [canvas selectView:self state:YES];
    }
    else if ([theEvent modifierFlags] & CPCommandKeyMask)
    {
        [canvas selectView:self state:![self isSelected]];
    }
    else if (![self isSelected])
    {
        [canvas deselectViews];
        [canvas selectView:self state:YES];
    }

    // Begin a move session
    _lastMouseLoc = [[self canvas] convertPoint:[theEvent locationInWindow] fromView:nil];
    [CPApp setTarget:self selector:@selector(_dragWithEvent:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
}

- (void)_dragWithEvent:(CPEvent)theEvent
{
    // This is the move logic, largely from the original EFView.
    var canvas = [self canvas];
    var mouseLoc;

    switch ([theEvent type])
    {
        case CPLeftMouseDragged:
        {
            [[CPCursor closedHandCursor] set];
            mouseLoc = [canvas convertPoint:[theEvent locationInWindow] fromView:nil];
            var deltaX = mouseLoc.x - _lastMouseLoc.x;
            var deltaY = mouseLoc.y - _lastMouseLoc.y;

            for (var i = 0;  i < [[canvas selectedSubViews] count]; i++)
            {
                var view = [canvas selectedSubViews][i];
                var newOrigin = CGPointMake([view frame].origin.x + deltaX, [view frame].origin.y + deltaY);

                var parentView = [view superview];
                if ([parentView isKindOfClass:[UIWindowView class]])
                {
                    var parentBounds = [parentView bounds];
                    var viewFrame = [view frame];
                    newOrigin.x = MAX(0, MIN(newOrigin.x, parentBounds.size.width - viewFrame.size.width));
                    newOrigin.y = MAX(0, MIN(newOrigin.y, parentBounds.size.height - viewFrame.size.height));
                }

                [view setFrameOrigin:newOrigin];
            }

            _lastMouseLoc = mouseLoc;
            [canvas setNeedsDisplay:YES];
            [CPApp setTarget:self selector:@selector(_dragWithEvent:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
            break;
        }
        case CPLeftMouseUp:
            [[CPCursor openHandCursor] set];
            _lastMouseLoc = null;
            [canvas setNeedsDisplay:YES];
            [canvas elementDidMove:self];
            break;
    }
}

- (void)_resizeWithEvent:(CPEvent)theEvent
{
    var sView = [self superview];
    var canvas = [self canvas];
    var mouseLoc;

    switch ([theEvent type])
    {
        case CPLeftMouseDragged:
        {
            [[CPCursor crosshairCursor] set]; // A generic resize cursor
            mouseLoc = [sView convertPoint:[theEvent locationInWindow] fromView:nil];
            var deltaX = mouseLoc.x - _lastMouseLoc.x;
            var deltaY = mouseLoc.y - _lastMouseLoc.y;

            var frame = [self frame];
            var minSize = CGSizeMake(2 * kUIElementHandleSize, 2 * kUIElementHandleSize);

            // Left handles
            if (_activeHandle === kUIElementTopLeftHandle || _activeHandle === kUIElementMiddleLeftHandle || _activeHandle === kUIElementBottomLeftHandle) {
                if (frame.size.width - deltaX > minSize.width) {
                    frame.origin.x += deltaX;
                    frame.size.width -= deltaX;
                }
            }
            // Right handles
            if (_activeHandle === kUIElementTopRightHandle || _activeHandle === kUIElementMiddleRightHandle || _activeHandle === kUIElementBottomRightHandle) {
                if (frame.size.width + deltaX > minSize.width) {
                    frame.size.width += deltaX;
                }
            }
            // Top handles
            if (_activeHandle === kUIElementTopLeftHandle || _activeHandle === kUIElementTopMiddleHandle || _activeHandle === kUIElementTopRightHandle) {
                if (frame.size.height - deltaY > minSize.height) {
                    frame.origin.y += deltaY;
                    frame.size.height -= deltaY;
                }
            }
            // Bottom handles
            if (_activeHandle === kUIElementBottomLeftHandle || _activeHandle === kUIElementBottomMiddleHandle || _activeHandle === kUIElementBottomRightHandle) {
                if (frame.size.height + deltaY > minSize.height) {
                    frame.size.height += deltaY;
                }
            }
            
            [self setFrame:frame];
            
            _lastMouseLoc = mouseLoc;
            [canvas setNeedsDisplay:YES];
            [CPApp setTarget:self selector:@selector(_resizeWithEvent:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
            break;
        }
        case CPLeftMouseUp:
            [[CPCursor arrowCursor] set];
            _activeHandle = kUIElementNoHandle;
            _lastMouseLoc = null;
            [canvas setNeedsDisplay:YES];
            [canvas elementDidResize:self];
            break;
    }
}

- (void)mouseEntered:(CPEvent)theEvent
{
    [[CPCursor openHandCursor] set];
}

- (void)mouseExited:(CPEvent)theEvent
{
    [[CPCursor arrowCursor] set];
}

- (void)mouseMoved:(CPEvent)theEvent
{
    var localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    var handle = [self handleAtPoint:localPoint];
    
    if (handle != kUIElementNoHandle) {
        // In a full implementation, you could return a specific two-headed arrow cursor
        // based on the handle. For now, we use a generic one.
        [[CPCursor crosshairCursor] set];
    } else {
        [[CPCursor openHandCursor] set];
    }
}

@end


#pragma mark -
#pragma mark *** UI Element Subclasses ***

// =================================================================================================
// UIWindowView
// A skeleton that looks like a window, and can act as a drop target.
// =================================================================================================

var _windowChildrenObservationContext = 1094;

@implementation UIWindowView : UIElementView
{
    CGPoint          _rubberStart;
    CGPoint          _rubberEnd;
    BOOL             _isRubbing;
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];

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
    var localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    var titleBarHeight = 30.0;

    // 1. Check for resize handle click first.
    if ([self handleAtPoint:localPoint] != kUIElementNoHandle) {
        [super mouseDown:theEvent];
        return;
    }

    // 2. Check if the click is within the title bar area.
    if (localPoint.y <= titleBarHeight) {
        // Click is in the title bar. Allow the superclass to handle moving the window.
        [super mouseDown:theEvent];
        return;
    }

    // 3. If not a resize handle and not in the title bar, it's the background. Start rubber-banding.
    var canvas = [self canvas];
    [canvas deselectViews];

    _isRubbing = YES;
    _rubberStart = localPoint;
    _rubberEnd = _rubberStart;

    [CPApp setTarget:self selector:@selector(_dragOpenSpaceWithEvent:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
}

- (void)_dragOpenSpaceWithEvent:(CPEvent)theEvent
{
    var canvas = [self canvas];
    var mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    _rubberEnd = mouseLoc;
    var rubberRect = CGRectUnion(CGRectMake(_rubberStart.x, _rubberStart.y, 1, 1), CGRectMake(_rubberEnd.x, _rubberEnd.y, 1, 1));

    switch ([theEvent type])
    {
        case CPLeftMouseDragged:
            var indexesToSelect = [CPMutableIndexSet indexSet];
            var allDataObjects = [canvas dataObjects];

            for (var i = 0; i < [[self subviews] count]; i++) {
                var aView = [self subviews][i];
                if (CGRectIntersectsRect([aView frame], rubberRect)) {
                    var dataIndex = [allDataObjects indexOfObject:[aView dataObject]];
                    if (dataIndex != CPNotFound) {
                        [indexesToSelect addIndex:dataIndex];
                    }
                }
            }
            [canvas setSelectionIndexes:indexesToSelect];
            [self setNeedsDisplay:YES];
            [CPApp setTarget:self selector:@selector(_dragOpenSpaceWithEvent:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
            break;

        case CPLeftMouseUp:
            _isRubbing = NO;
            [self setNeedsDisplay:YES];
            break;
    }
}

- (void)dealloc
{
    [self setDataObject:nil];
    [super dealloc];
}

- (void)setDataObject:(id)newDataObject
{
    var oldDataObject = [self dataObject];

    if (newDataObject != oldDataObject)
    {
        if (oldDataObject)
            [oldDataObject removeObserver:self forKeyPath:@"children" context:_windowChildrenObservationContext];

        [super setDataObject:newDataObject];

        if (newDataObject)
        {
            [newDataObject addObserver:self forKeyPath:@"children" options:CPKeyValueObservingOptionNew | CPKeyValueObservingOptionOld context:_windowChildrenObservationContext];
            [self _addChildrenViews:[newDataObject valueForKey:@"children"]];
        }
    }
}

- (void)_addChildrenViews:(CPArray)childDataObjects
{
    if (!childDataObjects) return;

    var canvas = [self superview];

    for (var i = 0; i < [childDataObjects count]; i++)
    {
        var childData = childDataObjects[i];
        // This is a bit of a hack. We are reaching into the canvas's private method.
        // A better solution would be a dedicated ViewFactory or similar.
        if ([canvas respondsToSelector:@selector(_createViewForDataObject:superview:)])
            [canvas _createViewForDataObject:childData superview:self];
    }
}

- (void)_removeChildrenViews:(CPArray)childDataObjects
{
    if (!childDataObjects) return;

    var canvas = [self superview];
    var viewsToRemove = [];
    var subviews = [self subviews];

    for (var i = 0; i < [subviews count]; i++)
    {
        var subview = subviews[i];
        if ([childDataObjects containsObject:[subview dataObject]])
            [viewsToRemove addObject:subview];
    }

    for (i = 0; i < [viewsToRemove count]; i++)
    {
        if ([canvas respondsToSelector:@selector(_removeViewAndChildren:)])
            [canvas _removeViewAndChildren:viewsToRemove[i]];
    }
}


- (void)observeValueForKeyPath:(CPString)keyPath ofObject:(id)object change:(CPDictionary)change context:(id)context
{
    if (context == _windowChildrenObservationContext)
    {
        var oldChildren = [change objectForKey:CPKeyValueChangeOldKey];
        var newChildren = [change objectForKey:CPKeyValueChangeNewKey];

        var added = [newChildren mutableCopy];
        [added removeObjectsInArray:oldChildren];
        [self _addChildrenViews:added];

        var removed = [oldChildren mutableCopy];
        [removed removeObjectsInArray:newChildren];
        [self _removeChildrenViews:removed];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        _title = @"Window";
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(250, 200)];
        }
        _isContainer = YES;
        
        // This view can accept drops of other elements.
        [self registerForDraggedTypes:[
            UIButtonDragType,
            UISliderDragType,
            UITextFieldDragType
        ]];
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    var titleBarHeight = 22.0;
    
    // Main window background
    [[[CPColor windowBackgroundColor] colorWithAlphaComponent:0.9] setFill];
    var bgPath = [CPBezierPath bezierPathWithRoundedRect:bounds radius:6.0];
    [bgPath fill];
    
    // Title bar
    var titleBarRect = CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, titleBarHeight);
    var titleBarPath = [CPBezierPath bezierPathWithRoundedRect:titleBarRect xRadius:6.0 yRadius:6.0];
    [[[CPColor secondarySelectedControlColor] colorWithAlphaComponent:0.6] setFill];
    [titleBarPath fill];
    
    // Window border
    [[CPColor darkGrayColor] setStroke];
    [bgPath setLineWidth:1.0];
    [bgPath stroke];
    
    // Title text
    [_stringAttributes setObject:[CPColor whiteColor] forKey:CPForegroundColorAttributeName];
    var titleSize = [[self title] sizeWithAttributes:_stringAttributes];
    [[self title] drawAtPoint:CGPointMake((bounds.size.width - titleSize.width) / 2.0, (titleBarHeight - titleSize.height) / 2.0 - 4) withAttributes:_stringAttributes];
    [_stringAttributes setObject:[CPColor blackColor] forKey:CPForegroundColorAttributeName]; // reset color
    
    // Traffic light buttons
    var circleRadius = 5.0;
    var startX = 10.0;
    var startY = titleBarHeight / 2.0;
    [[CPColor redColor] setFill];
    [CPBezierPath fillRect:CGRectMake(startX, startY - circleRadius, circleRadius*2, circleRadius*2)];
    [[CPColor orangeColor] setFill];
    [CPBezierPath fillRect:CGRectMake(startX + 18, startY - circleRadius, circleRadius*2, circleRadius*2)];
    [[CPColor greenColor] setFill];
    [CPBezierPath fillRect:CGRectMake(startX + 36, startY - circleRadius, circleRadius*2, circleRadius*2)];
}

// --- Drag Destination Methods ---

- (CPDragOperation)draggingEntered:(CPDraggingInfo)sender
{
    var pasteboard = [sender draggingPasteboard];
    var acceptedTypes = [self registeredDraggedTypes];

    for (var i = 0; i < [[pasteboard types] count]; i++)
    {
        var draggedType = [[pasteboard types] objectAtIndex:i];
        if ([acceptedTypes containsObject:draggedType])
        {
            _isDragTarget = YES;
            [self setNeedsDisplay:YES];
            return CPDragOperationGeneric;
        }
    }

    return CPDragOperationNone;
}

- (void)draggingExited:(CPDraggingInfo)sender
{
    _isDragTarget = NO;
    [self setNeedsDisplay:YES];
}

- (BOOL)performDragOperation:(CPDraggingInfo)sender
{
    var dropPoint = [self convertPoint:[sender draggingLocation] fromView:nil];
    var pasteboard = [sender draggingPasteboard];
    var types = [pasteboard types];
    var draggedType = types[0];
    var elementType;

    if (draggedType === UIButtonDragType) elementType = "button";
    else if (draggedType === UISliderDragType) elementType = "slider";
    else if (draggedType === UITextFieldDragType) elementType = "textfield";

    if (elementType)
    {
        // We need to find the canvas and then the delegate
        var canvas = [self superview];
        var delegate = [canvas delegate];
        if (delegate && [delegate respondsToSelector:@selector(addNewElementOfType:atPoint:)])
        {
            var canvasPoint = [self convertPoint:dropPoint toView:canvas];
            [delegate addNewElementOfType:elementType atPoint:canvasPoint];
        }
    }

    _isDragTarget = NO;
    [self setNeedsDisplay:YES];
    
    return YES;
}

@end


// =================================================================================================
// UIButtonView
// A skeleton that looks like a push button.
// =================================================================================================
@implementation UIButtonView : UIElementView
- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        _title = @"Button";
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(100, 24)];
        }
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = CGRectInset([self bounds], 1, 1);
    
    // Draw button shape with gradient
    var buttonPath = [CPBezierPath bezierPathWithRoundedRect:bounds radius:5.0];
    var gradient = [[CPGradient alloc] initWithStartingColor:[CPColor whiteColor]
                                                 endingColor:[CPColor controlColor]];
    [gradient drawInBezierPath:buttonPath angle:90];
    
    // Draw button border
    [[CPColor grayColor] setStroke];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];
    
    // Draw title
    var titleSize = [[self title] sizeWithAttributes:_stringAttributes];
    [[self title] drawAtPoint:CGPointMake((bounds.size.width - titleSize.width) / 2.0 + 1, (bounds.size.height - titleSize.height) / 2.0 - 2) withAttributes:_stringAttributes];
}
@end

// =================================================================================================
// UISliderView
// A skeleton that looks like a slider.
// =================================================================================================
@implementation UISliderView : UIElementView
- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        _title = @"Slider";
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(150, 20)];
        }
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = CGRectInset([self bounds], 8, 0);
    var midY = bounds.size.height / 2.0;

    // Draw track
    [[CPColor grayColor] setStroke];
    var trackPath = [CPBezierPath bezierPath];
    [trackPath setLineWidth:3.0];
    [trackPath moveToPoint:CGPointMake(bounds.origin.x, midY)];
    [trackPath lineToPoint:CGPointMake(bounds.origin.x + bounds.size.width, midY)];
    [trackPath stroke];
    
    // Draw knob
    var knobX = bounds.origin.x + bounds.size.width / 2.0;
    var knobRect = CGRectMake(knobX - 8, midY - 8, 16, 16);
    var knobPath = [CPBezierPath bezierPathWithOvalInRect:knobRect];
    [[CPColor whiteColor] setFill];
    [knobPath fill];
    [[CPColor darkGrayColor] setStroke];
    [knobPath setLineWidth:1.0];
    [knobPath stroke];
}
@end

// =================================================================================================
// UITextFieldView
// A skeleton that looks like a text field.
// =================================================================================================
@implementation UITextFieldView : UIElementView
- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self)
    {
        _title = @"Text Field Content";
        if (CGRectIsEmpty(aRect))
        {
            [self setFrameSize:CGSizeMake(150, 22)];
        }
        [_stringAttributes setObject:[CPFont systemFontOfSize:12] forKey:CPFontAttributeName];
        [_stringAttributes setObject:[CPColor grayColor] forKey:CPForegroundColorAttributeName];
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = CGRectInset([self bounds], 1, 1);
    
    // Background
    [[CPColor textBackgroundColor] setFill];
    [CPBezierPath fillRect:bounds];
    
    // Inset border
    [[CPColor grayColor] setStroke];
    [CPBezierPath strokeRect:bounds];
    
    // Draw placeholder title
    var titleSize = [[self title] sizeWithAttributes:_stringAttributes];
    [[self title] drawAtPoint:CGPointMake(5, (bounds.size.height - titleSize.height) / 2.0 - 2) withAttributes:_stringAttributes];
}
@end

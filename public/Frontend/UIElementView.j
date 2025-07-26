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

@import "UIBuilderConstants.j"

@class UIWindowView
@class UIButtonView;
@class UISliderView;
@class UITextFieldView;
@class UICheckBoxView;
@class UILabelView;
@class UISearchFieldView;
@class UISecureFieldView;
@class UITextViewView;
@class UIScrollViewView;
@class UITableViewView;
@class UISplitViewView;
@class UIImageViewView;
@class UIPopUpButtonView;
@class UIComboBoxView;
@class UIStepperView;
@class UIDatePickerView;
@class UIProgressIndicatorView;
@class UIBoxView;
@class UIHBoxView;
@class UIVBoxView;
@class UICanvasView;
@class UIHSpaceView;
@class UIVSpaceView;
@class UICanvasView;

var _classMap = [CPMutableDictionary dictionary];


@implementation UIElementView : CPView
{
    CPMutableDictionary     _stringAttributes;
    id                      _dataObject @accessors(property=dataObject);

    // State for dragging and resizing
    CGPoint                 _lastMouseLoc;
    int                     _activeHandle;
    BOOL                    _isDragTarget; // Used by subclasses (e.g. UIWindowView)
    CPTrackingArea          _trackingArea;
    BOOL                    _isContainer;
    BOOL                    _isConnecting;
    BOOL                    _isNewlyCreated;
}

#pragma mark -
#pragma mark *** Class Methods ***

+ (void)initialize
{
    if (self === [UIElementView class])
    {
        _classMap = [CPMutableDictionary dictionary];

        // Register all UIElementView subclasses here
        [self registerViewClass:UIWindowView forElementType:@"window"];
        [self registerViewClass:UIButtonView forElementType:@"button"];
        [self registerViewClass:UISliderView forElementType:@"slider"];
        [self registerViewClass:UITextFieldView forElementType:@"textfield"];
        [self registerViewClass:UICheckBoxView forElementType:@"checkBox"];
        [self registerViewClass:UILabelView forElementType:@"label"];
        [self registerViewClass:UISearchFieldView forElementType:@"searchField"];
        [self registerViewClass:UISecureFieldView forElementType:@"secureField"];
        [self registerViewClass:UITextViewView forElementType:@"textView"];
        [self registerViewClass:UIScrollViewView forElementType:@"scrollView"];
        [self registerViewClass:UITableViewView forElementType:@"tableView"];
        [self registerViewClass:UISplitViewView forElementType:@"splitView"];
        [self registerViewClass:UIImageViewView forElementType:@"imageView"];
        [self registerViewClass:UIPopUpButtonView forElementType:@"popUpButton"];
        [self registerViewClass:UIComboBoxView forElementType:@"comboBox"];
        [self registerViewClass:UIStepperView forElementType:@"stepper"];
        [self registerViewClass:UIDatePickerView forElementType:@"datePicker"];
        [self registerViewClass:UIProgressIndicatorView forElementType:@"progresIndicator"];
        [self registerViewClass:UIBoxView forElementType:@"box"];
        [self registerViewClass:UIHBoxView forElementType:@"hbox"];
        [self registerViewClass:UIVBoxView forElementType:@"vbox"];
        [self registerViewClass:UIHSpaceView forElementType:@"hspace"];
        [self registerViewClass:UIVSpaceView forElementType:@"vspace"];
        [self registerViewClass:UICanvasView forElementType:@"canvas"];
    }
}

+ (void)registerViewClass:(Class)viewClass forElementType:(CPString)elementType
{
    if (!_classMap)
        [self initialize];

    [_classMap setObject:viewClass forKey:elementType];
}

+ (CPArray)persistentProperties
{
    return ["value", "halign", "valign"];
}

+ (CPDictionary)defaultValues
{
    return @{
        value: "Element",
        halign: "expand",
        valign: "expand"
    };
}

+ (CPDictionary)propertyTypes
{
    return @{
                "value": UIBString,
                "halign": UIBEnumeration,
                "valign": UIBEnumeration
             };
}

+ (CPDictionary)propertyEnumerations
{
    return @{
                "halign": ["expand", "min"],
                "valign": ["expand", "min"]
            }
}

+ (CPMutableDictionary)classMap
{
    return _classMap;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self)
    {
        // console.log("UIElementView initWithFrame: for", [self class], "- self.window:", [self window]);
        _stringAttributes = [[CPMutableDictionary alloc] init];
        [_stringAttributes setObject:[CPFont boldSystemFontOfSize:12] forKey:CPFontAttributeName];
        [_stringAttributes setObject:[CPColor blackColor] forKey:CPForegroundColorAttributeName];

        _activeHandle = kUIElementNoHandle;

        if ([self frame].size.width < 50 || [self frame].size.height < 20)
            [self setFrameSize:CGSizeMake(MAX(50, [self frame].size.width), MAX(20, [self frame].size.height))];

        [self setNeedsDisplay:YES];

        _isContainer = NO;
        _isConnecting = NO;
    }

    return self;
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    [self setupTrackingArea];
}

- (void)setupTrackingArea
{
    console.log("UIElementView setupTrackingArea: for", [self class], "- self.window:", [self window]);
    if ([self window])
    {
        if (_trackingArea)
        {
            [self removeTrackingArea:_trackingArea];
        }
        _trackingArea = [[CPTrackingArea alloc] initWithRect:[self bounds]
                                                     options:(CPTrackingMouseMoved | CPTrackingActiveInKeyWindow | CPTrackingInVisibleRect | CPTrackingMouseEnteredAndExited)
                                                       owner:self
                                                    userInfo:nil];
        [self addTrackingArea:_trackingArea];
        console.log("  - Tracking area added/updated.");
    }
    else if (_trackingArea)
    {
        [self removeTrackingArea:_trackingArea];
        _trackingArea = nil;
        console.log("  - Tracking area removed.");
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
        var properties = [[self class] persistentProperties];
        if (oldDataObject)
            for (var i = 0; i < [properties count]; i++)
                [oldDataObject removeObserver:self forKeyPath:properties[i]];

        _dataObject = newDataObject;

        if (newDataObject)
        {
            for (var i = 0; i < [properties count]; i++)
            {
                var propertyName = properties[i];
                [newDataObject addObserver:self forKeyPath:propertyName options:CPKeyValueObservingOptionNew context:self];
            }
        }
    }
}

- (void)observeValueForKeyPath:(CPString)keyPath ofObject:(id)object change:(CPDictionary)change context:(id)context
{
    if (context == self)
    {
        // When a property on the dataObject changes, simply tell the view to redraw itself.
        [self setNeedsDisplay:YES];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (BOOL)acceptsFirstMouse
{
    // This view should accept first mouse events for interaction.
    return YES;
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
        if (![self isKindOfClass:[UIWindowView class]])
        {
            [[self superview] setNeedsLayout:YES];
        }
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
        if (![self isKindOfClass:[UIWindowView class]])
        {
            [[self superview] setNeedsLayout:YES];
        }
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
        [[self superview] setNeedsLayout:YES];
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
        [[self superview] setNeedsLayout:YES];
    }
}

#pragma mark -
#pragma mark *** Accessors ***

- (id)value
{
    return ([self dataObject] == nil) ? @"" : [[self dataObject] valueForKey:@"value"];
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

    var valueSize = [[self value] sizeWithAttributes:_stringAttributes];
    [[self value] drawAtPoint:CGPointMake((bounds.size.width - valueSize.width) / 2.0, (bounds.size.height - valueSize.height) / 2.0) withAttributes:_stringAttributes];
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

- (void)rightMouseDown:(CPEvent)theEvent
{
    [self mouseDown:theEvent];
}
- (void)rightMouseUp:(CPEvent)theEvent
{
    [self mouseUp:theEvent];
}

- (void)mouseDown:(CPEvent)theEvent
{
    var canvas = [self canvas];
    var localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];

    _lastMouseLoc = [[self canvas] convertPoint:[theEvent locationInWindow] fromView:nil];

    // First, check if we clicked a resize handle
    _activeHandle = [self handleAtPoint:localPoint];

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
}



- (void)mouseDragged:(CPEvent)theEvent
{
    var canvas = [self canvas];
    var mouseLoc = [canvas convertPoint:[theEvent locationInWindow] fromView:nil];

    if (!_lastMouseLoc) {
        _lastMouseLoc = mouseLoc;
    }

    if ([theEvent modifierFlags] & CPControlKeyMask)
    {
        _isConnecting = YES;
        // If control key is pressed, handle connection drawing
        var startPointInView = CGPointMake(CGRectGetMidX([self bounds]), CGRectGetMidY([self bounds]));
        var startPointInCanvas = [self convertPoint:startPointInView toView:canvas];

        var canvasSubviews = [canvas subviews];
        for (var k = 0; k < [canvasSubviews count]; k++) {
            var subview = [canvasSubviews objectAtIndex:k];
            if ([subview isKindOfClass:[UIElementView class]]) {
                [subview setAsDropTarget:NO];
            }
        }
        var targetView = [canvas viewAtPoint:mouseLoc];

        if (targetView && targetView != self)
        {
            var localPoint = [targetView convertPoint:mouseLoc fromView:canvas];
            if ([targetView canAcceptConnectionAtPoint:localPoint])
            {
                var endPointInView = CGPointMake(CGRectGetMidX([targetView bounds]), CGRectGetMidY([targetView bounds]));
                var endPointInCanvas = [targetView convertPoint:endPointInView toView:canvas];
                [canvas drawConnectionFrom:startPointInCanvas to:endPointInCanvas];
                [targetView setAsDropTarget:YES];
            }
            else
            {
                [canvas drawConnectionFrom:startPointInCanvas to:mouseLoc];
            }
        }
        else
        {
            [canvas drawConnectionFrom:startPointInCanvas to:mouseLoc];
        }
    }
    else if (_activeHandle != kUIElementNoHandle)
    {
        [self _resizeWithEvent:theEvent];
    }
    else
    {
        // Move logic
        [[CPCursor closedHandCursor] set];
        var deltaX = mouseLoc.x - _lastMouseLoc.x;
        var deltaY = mouseLoc.y - _lastMouseLoc.y;

        var selectedViews = [canvas selectedSubViews];
        var processedHBoxes = [CPSet set];
        var processedVBoxes = [CPSet set];

        for (var i = 0; i < [selectedViews count]; i++)
        {
            var view = selectedViews[i];
            var appController = [CPApp delegate];
            var isFreeForm = YES;

            // --- Handle Horizontal Drag (within an HBox) ---
            var hBoxParent = [view superview];
            if ([hBoxParent isKindOfClass:[UIHBoxView class]] && ![processedHBoxes containsObject:hBoxParent])
            {
                isFreeForm = NO;
                var viewIndex = [[hBoxParent subviews] indexOfObject:view];
                var precedingView = (viewIndex > 0) ? [[hBoxParent subviews] objectAtIndex:viewIndex - 1] : nil;

                if ([view isKindOfClass:[UIHSpaceView class]]) {
                    precedingView = view;
                }

                if (!precedingView || ![precedingView isKindOfClass:[UIHSpaceView class]]) {
                    precedingView = [appController addNewElementOfType:@"hspace" atPoint:CGPointMake(0,0)
                                                           inParent:[hBoxParent dataObject]
                                                            atIndex:viewIndex];
                    [[precedingView dataObject] setValue:0 forKey:@"width"];
                }
                
                var currentWidth = [[precedingView dataObject] valueForKey:@"width"];
                var newWidth = currentWidth + deltaX;
                [[precedingView dataObject] setValue:MAX(0, newWidth) forKey:@"width"];

                [hBoxParent setNeedsLayout:YES];
                [processedHBoxes addObject:hBoxParent];
            }

            // --- Handle Vertical Drag (of an HBox or VSpace within a VBox) ---
            var itemInVBox = view;
            if ([hBoxParent isKindOfClass:[UIHBoxView class]])
                itemInVBox = hBoxParent;

            if (itemInVBox)
            {
                var vBoxParent = [itemInVBox superview];
                if ([vBoxParent isKindOfClass:[UIVBoxView class]] && ![processedVBoxes containsObject:vBoxParent])
                {
                    isFreeForm = NO;
                    var viewIndex = [[vBoxParent subviews] indexOfObject:itemInVBox];
                    var precedingView = (viewIndex > 0) ? [[vBoxParent subviews] objectAtIndex:viewIndex - 1] : nil;

                    if ([itemInVBox isKindOfClass:[UIVSpaceView class]]) {
                        precedingView = itemInVBox;
                    }

                    if (!precedingView || ![precedingView isKindOfClass:[UIVSpaceView class]]) {
                        precedingView = [appController addNewElementOfType:@"vspace" atPoint:CGPointMake(0,0) inParent:[vBoxParent dataObject] atIndex:viewIndex];
                        [[precedingView dataObject] setValue:0 forKey:@"height"];
                    }

                    var currentHeight = [[precedingView dataObject] valueForKey:@"height"];
                    var newHeight = currentHeight + deltaY;
                    [[precedingView dataObject] setValue:MAX(0, newHeight) forKey:@"height"];
                    
                    [vBoxParent setNeedsLayout:YES];
                    [processedVBoxes addObject:vBoxParent];
                }
            }

            // --- Handle Free-form Drag ---
            if (isFreeForm)
            {
                var newOrigin = CGPointMake([view frame].origin.x + deltaX, [view frame].origin.y + deltaY);
                var superview = [view superview];
                if ([superview isKindOfClass:[UIWindowView class]])
                {
                    var parentBounds = [superview bounds];
                    var viewFrame = [view frame];
                    newOrigin.x = MAX(0, MIN(newOrigin.x, parentBounds.size.width - viewFrame.size.width));
                    newOrigin.y = MAX(0, MIN(newOrigin.y, parentBounds.size.height - viewFrame.size.height));
                }
                [view setFrameOrigin:newOrigin];
            }
        }

        _lastMouseLoc = mouseLoc;
        [canvas setNeedsDisplay:YES];
    }
}

- (void)mouseUp:(CPEvent)theEvent
{
    var canvas = [self canvas];
    var mouseLoc = [canvas convertPoint:[theEvent locationInWindow] fromView:nil];

    if (_isConnecting)
    {
        // Handle mouse up for connection
        var targetView = [canvas viewAtPoint:mouseLoc];

        if (targetView && targetView != self)
        {
            var localPoint = [targetView convertPoint:mouseLoc fromView:canvas];
            if ([targetView canAcceptConnectionAtPoint:localPoint])
            {
                [canvas showConnectionMenuForSource:self target:targetView at:mouseLoc];
            }
            else
            {
                [canvas clearConnection];
            }
        }
        else
        {
            [canvas clearConnection];
        }

        var canvasSubviews = [canvas subviews];

        for (var k = 0; k < [canvasSubviews count]; k++) {
            var subview = [canvasSubviews objectAtIndex:k];
            if ([subview isKindOfClass:[UIElementView class]] && subview != targetView) {
                [subview setAsDropTarget:NO];
            }
        }
        [canvas setNeedsDisplay:YES];
        _isConnecting = NO;
    }
    else if (_activeHandle != kUIElementNoHandle)
    {
        // Handle mouse up for resize
        [[CPCursor arrowCursor] set];
        _activeHandle = kUIElementNoHandle;
        _lastMouseLoc = nil;
        [canvas setNeedsDisplay:YES];
        [canvas elementDidResize:self];
    }
    else
    {
        // Handle mouse up for move
        [[CPCursor openHandCursor] set];
        _lastMouseLoc = nil;
        [canvas setNeedsDisplay:YES];
        [canvas elementDidMove:self];
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
        case CPLeftMouseUp:
            [[CPCursor arrowCursor] set];
            _activeHandle = kUIElementNoHandle;
            _lastMouseLoc = null;
            [canvas setNeedsDisplay:YES];
            [canvas elementDidResize:self];
            break;
    }
}

- (void)setAsDropTarget:(BOOL)isTarget
{
    if (_isDragTarget !== isTarget)
    {
        _isDragTarget = isTarget;
        [self setNeedsDisplay:YES];
    }
}

- (void)_connectWithEvent:(CPEvent)theEvent
{
    var canvas = [self canvas];
    var mouseLoc = [canvas convertPoint:[theEvent locationInWindow] fromView:nil];

    // Convert the start point (center of the view) to the canvas's coordinate system
    var startPointInView = CGPointMake(CGRectGetMidX([self bounds]), CGRectGetMidY([self bounds]));
    var startPointInCanvas = [self convertPoint:startPointInView toView:canvas];

    var canvasSubviews = [canvas subviews];
    for (var k = 0; k < [canvasSubviews count]; k++) {
        var subview = [canvasSubviews objectAtIndex:k];
        if ([subview isKindOfClass:[UIElementView class]]) {
            [subview setAsDropTarget:NO];
        }
    }
    var targetView = [canvas viewAtPoint:mouseLoc];
    var validTargetFound = NO;
    var endPointForDrawing = mouseLoc; // Default to follow mouse

    if (targetView && targetView != self)
    {
        if ([targetView isKindOfClass:[UIWindowView class]])
        {
            validTargetFound = YES;
            // Snap to center of the window for drawing feedback
            endPointForDrawing = CGPointMake(CGRectGetMidX([targetView bounds]), CGRectGetMidY([targetView bounds]));
            endPointForDrawing = [targetView convertPoint:endPointForDrawing toView:canvas];
        }
        else
        {
            // For non-window elements, allow connection anywhere on their bounds
            validTargetFound = YES;
            endPointForDrawing = mouseLoc; // Follow mouse for other elements during drag
        }
    }

    if ([theEvent type] == CPLeftMouseDragged)
    {
        if (validTargetFound)
        {
            [canvas drawConnectionFrom:startPointInCanvas to:endPointForDrawing];
            [targetView setAsDropTarget:YES];
        }
        else
        {
            [canvas drawConnectionFrom:startPointInCanvas to:mouseLoc];
        }
    }
    else if ([theEvent type] == CPLeftMouseUp)
    {
        // For final connection, snap to center of non-window elements, or title bar for windows
        var finalEndPoint = mouseLoc;
        var currentValidTarget = validTargetFound; // Store the initial state

        if (targetView && targetView != self) {
            finalEndPoint = CGPointMake(CGRectGetMidX([targetView bounds]), CGRectGetMidY([targetView bounds]));
            finalEndPoint = [targetView convertPoint:finalEndPoint toView:canvas];
        } else {
            currentValidTarget = NO; // No valid target or target is self
        }

        if (currentValidTarget) {
            [[self canvas] elementDidConnect:self to:targetView atPoint:finalEndPoint]; // Pass finalEndPoint
        }
        [[self canvas] clearConnection];
        var canvasSubviews = [canvas subviews];
        for (var k = 0; k < [canvasSubviews count]; k++) {
            var subview = [canvasSubviews objectAtIndex:k];
            if ([subview isKindOfClass:[UIElementView class]]) {
                [subview setAsDropTarget:NO];
            }
        }
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

- (id)nativeUIElement
{
    return [self nativeUIElementWithMap:nil];
}

- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap
{
    // Base implementation returns a generic view with a red background to indicate it's not a real UI element.
    var view = [[CPView alloc] initWithFrame:[self frame]];
    [view setBackgroundColor:[CPColor redColor]];

    if (aMap)
    {
        var elementID = [[self dataObject] valueForKey:@"id"];
        [aMap setObject:view forKey:elementID];
    }

    return view;
}

- (BOOL)canAcceptConnectionAtPoint:(CGPoint)aPoint
{
    // By default, any part of the view can be a connection target.
    return YES;
}

- (CPDragOperation)draggingUpdated:(CPDraggingInfo)sender
{
    if (_isNewlyCreated)
        return CPDragOperationNone;

    return CPDragOperationCopy;
}

- (void)setIsNewlyCreated:(BOOL)isNew
{
    _isNewlyCreated = isNew;
}

@end


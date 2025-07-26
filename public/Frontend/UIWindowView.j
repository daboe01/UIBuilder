@import "UIElementView.j"

var _windowChildrenObservationContext = 1094;
@class UIElementView;

@implementation UIWindowView : UIElementView
{
    CPTextField _titleView;
    BOOL _isDropTarget;

    CGPoint          _rubberStart;
    CGPoint          _rubberEnd;
    BOOL             _isRubbing;
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types setObject:UIBBoolean forKey:@"CPHUDBackgroundWindowMask"];
    [types setObject:UIBBoolean forKey:@"CPTitledWindowMask"];
    [types setObject:UIBBoolean forKey:@"CPClosableWindowMask"];
    return types;
}

+ (CPArray)persistentProperties
{
    return [super persistentProperties].concat(["CPHUDBackgroundWindowMask", "CPTitledWindowMask", "CPClosableWindowMask"]);
}

+ (JSObject)defaultValues
{
    return {
        value: "Untitled Window",
        CPHUDBackgroundWindowMask: true,
        CPTitledWindowMask: true,
        CPClosableWindowMask: true,
        outlets: "delegate",
        actions: "makeKeyAndOrderFront:, orderOut:"
    };
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
    }

    // Border
    if (_isDropTarget) {
        [[CPColor redColor] set];
        [CPBezierPath setDefaultLineWidth:2.0];
    } else {
        [[CPColor darkGrayColor] set];
        [CPBezierPath setDefaultLineWidth:1.0];
    }
    [CPBezierPath strokeRect:_bounds];
}

#pragma mark - Drag and Drop

- (CPDragOperation)draggingEntered:(id <CPDraggingInfo>)sender
{
    _isDropTarget = YES;
    [self setNeedsDisplay:YES];
    return CPDragOperationGeneric;
}

- (void)draggingExited:(id <CPDraggingInfo>)sender
{
    _isDropTarget = NO;
    [self setNeedsDisplay:YES];
}

- (void)concludeDragOperation:(id <CPDraggingInfo>)sender
{
    _isDropTarget = NO;
    [self setNeedsDisplay:YES];
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

    // On a click into the window's content area, deselect all elements.
    [[self canvas] deselectViews];

    _rubberStart = localPoint;
    _rubberEnd = _rubberStart;
    _isRubbing = YES;
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
    [super dealloc];
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self)
    {
        [self registerForDraggedTypes:[
            UIButtonDragType,
            UISliderDragType,
            UITextFieldDragType,
            UICheckBoxDragType,
            UILabelDragType,
            UISearchFieldDragType,
            UISecureFieldDragType,
            UITextViewDragType,
            UIScrollViewDragType,
            UITableViewDragType,
            UISplitViewDragType,
            UIImageViewDragType,
            UIPopUpButtonDragType,
            UIComboBoxDragType,
            UIStepperDragType,
            UIDatePickerDragType,
            UIProgressIndicatorDragType,
            UIBoxDragType
        ]];

        _isContainer = YES;
        console.log("UIWindowView specific init. self after super init:", self);

        _titleView = [[CPTextField alloc] initWithFrame:CGRectMake(0, 2, [self bounds].size.width, 22)];
        [_titleView setBezeled:NO];
        [_titleView setDrawsBackground:NO];
        [_titleView setEditable:NO];
        [_titleView setSelectable:NO];
        [_titleView setFont:[CPFont boldSystemFontOfSize:13]];
        [_titleView setTextColor:[CPColor whiteColor]];
        [_titleView setAlignment:CPCenterTextAlignment];
        [_titleView setAutoresizingMask:CPViewWidthSizable];
        [self addSubview:_titleView];

        [_titleView bind:@"value" toObject:self withKeyPath:@"dataObject.value" options:nil];
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

- (CPDragOperation)draggingUpdated:(id <CPDraggingInfo>)sender
{
    return [[self superview] draggingUpdated:sender];
}

- (BOOL)prepareForDragOperation:(id <CPDraggingInfo>)sender
{
    return [[self superview] prepareForDragOperation:sender];
}

- (BOOL)performDragOperation:(id <CPDraggingInfo>)sender
{
    return [[self superview] performDragOperation:sender];
}

- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap
{
    var newPlatformWindow = [[CPPlatformWindow alloc] initWithContentRect:[self frame]];

    var styleMask = 0;
    if ([[self dataObject] valueForKey:@"CPHUDBackgroundWindowMask"]) styleMask |= CPHUDBackgroundWindowMask;
    if ([[self dataObject] valueForKey:@"CPTitledWindowMask"]) styleMask |= CPTitledWindowMask;
    if ([[self dataObject] valueForKey:@"CPClosableWindowMask"]) styleMask |= CPClosableWindowMask;

    var theNewWindow = [[CPWindow alloc] initWithContentRect:CGRectMake(0, 0, [self frame].size.width, [self frame].size.height) styleMask:styleMask];
    [theNewWindow setPlatformWindow:newPlatformWindow];

    if (aMap)
    {
        var elementID = [[self dataObject] valueForKey:@"id"];
        [aMap setObject:theNewWindow forKey:elementID];
    }

    var contentView = [theNewWindow contentView];
    var subviews = [self subviews];
    for (var i = 0; i < [subviews count]; i++)
    {
        var subview = subviews[i];
        var nativeSubview = [subview nativeUIElementWithMap:aMap];
        [contentView addSubview:nativeSubview];
    }

    return theNewWindow;
}

- (BOOL)canAcceptConnectionAtPoint:(CGPoint)aPoint
{
    var titleBarHeight = 22.0;
    return aPoint.y <= titleBarHeight;
}

@end


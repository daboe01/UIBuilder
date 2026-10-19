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
@class UITabViewView;
@class UITabViewItemView;
@class UICustomView;
@class UIOwnerView;

// Keys every element view watches in addition to its persistent properties.
var UIBObservedKeys = ["value", "title", "halign", "valign", "width", "height", "markupKeys", "items", "columns",
                       "identifier", "markupTag", "hasBorder", "selectedTabIndex", "isIndeterminate", "minValue",
                       "maxValue", "style", "vertical", "pullsDown", "actions", "outlets", "color", "horizontalTextAlign"];

// Changes to these keys can change the size an element wants in a box.
var UIBLayoutKeys = { "value": YES, "title": YES, "halign": YES, "valign": YES, "width": YES, "height": YES,
                      "markupKeys": YES, "items": YES, "selectedTabIndex": YES, "hasBorder": YES };

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
        [self registerViewClass:UITextFieldView forElementType:@"textField"];
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
        [self registerViewClass:UITabViewView forElementType:@"tabView"];
        [self registerViewClass:UITabViewItemView forElementType:@"tabViewItem"];
        [self registerViewClass:UICustomView forElementType:@"custom"];
        [self registerViewClass:UIOwnerView forElementType:@"owner"];
        [self registerViewClass:UIProgressIndicatorView forElementType:@"progressIndicator"];
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
    return ["value", "halign", "valign", "width", "height"];
}

+ (CPDictionary)defaultValues
{
    return @{
        "value": "Element",
        "halign": "min",
        "valign": "min",
        "width": 100,
        "height": 20,
        "outlets": "",
        "actions": ""
    };
}

+ (CPDictionary)propertyTypes
{
    return @{
                "value": UIBString,
                "halign": UIBEnumeration,
                "valign": UIBEnumeration,
                "width": UIBNumber,
                "height": UIBNumber
             };
}

+ (CPDictionary)propertyGroups
{
    return @{
        "value": UIBPropertyTabProperties,
        "halign": UIBPropertyTabLayout,
        "valign": UIBPropertyTabLayout,
        "width": UIBPropertyTabLayout,
        "height": UIBPropertyTabLayout
    };
}

+ (CPDictionary)propertyEnumerations
{
    return @{
                "halign": UIBHorizontalAlignValues,
                "valign": UIBVerticalAlignValues
            }
}

+ (CPMutableDictionary)classMap
{
    return _classMap;
}

+ (CPMenu)defaultMenu
{
    var menu = [[CPMenu alloc] initWithTitle:@""];

    [menu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Duplicate" action:@selector(duplicate:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];
    [menu addItem:[CPMenuItem separatorItem]];
    [menu addItemWithTitle:@"Group in HBox" action:@selector(groupInHBox:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Group in VBox" action:@selector(groupInVBox:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Ungroup" action:@selector(ungroup:) keyEquivalent:@""];
    [menu addItem:[CPMenuItem separatorItem]];
    [menu addItemWithTitle:@"Move Earlier" action:@selector(moveEarlier:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Move Later" action:@selector(moveLater:) keyEquivalent:@""];

    return menu;
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

        if (![self isKindOfClass:[UIHBoxView class]] && ![self isKindOfClass:[UIVBoxView class]])
        {
            if ([self frame].size.width < 3 || [self frame].size.height < 3)
                [self setFrameSize:CGSizeMake(MAX(3, [self frame].size.width), MAX(3, [self frame].size.height))];
        }
        if ([self isKindOfClass:[UIHSpaceView class]])
        {
            if ([self frame].size.width < 0)
                [self setFrameSize:CGSizeMake(MAX(0, [self frame].size.width), MAX(3, [self frame].size.height))];
        }

        if ([self isKindOfClass:[UIVSpaceView class]])
        {
            if ([self frame].size.height < 0)
                [self setFrameSize:CGSizeMake(MAX(3, [self frame].size.width), MAX(0, [self frame].size.height))];
        }

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
    }
    else if (_trackingArea)
    {
        [self removeTrackingArea:_trackingArea];
        _trackingArea = nil;
    }
}

- (void)dealloc
{
    [self setDataObject:nil];
    [super dealloc];
}

+ (CPArray)observedProperties
{
    var result = [[self persistentProperties] copy] || [];
    for (var i = 0; i < UIBObservedKeys.length; i++)
        if (result.indexOf(UIBObservedKeys[i]) < 0)
            result.push(UIBObservedKeys[i]);
    return result;
}

- (void)setDataObject:(id)newDataObject
{
    var oldDataObject = [self dataObject];
    if (newDataObject !== oldDataObject)
    {
        var properties = [[self class] observedProperties];
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
        if (UIBLayoutKeys[keyPath])
            [self invalidateLayoutUpwards];

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
        var minWidth = 0.0;
        if ([self isKindOfClass:[UIHBoxView class]] || [self isKindOfClass:[UIVBoxView class]] || [self isKindOfClass:[UIHSpaceView class]] || [self isKindOfClass:[UIVSpaceView class]])
            minWidth = 0;
        
        frame.size.width = MAX(aFloat, minWidth);
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
        var minHeight = 0.0;
        if ([self isKindOfClass:[UIHBoxView class]] || [self isKindOfClass:[UIVBoxView class]] || [self isKindOfClass:[UIHSpaceView class]] || [self isKindOfClass:[UIVSpaceView class]])
            minHeight = 0;

        frame.size.height = MAX(aFloat, minHeight);
        [self setFrame:frame];
        [[self superview] setNeedsLayout:YES];
    }
}

#pragma mark -
#pragma mark *** Root Container ***

// The frame the root vbox of a container (window, scroll view, split view) should fill.
- (CGRect)rootContainerFrame
{
    return [self bounds];
}

- (void)setFrameSize:(CGSize)aSize
{
    var oldSize = [self frame].size;
    [super setFrameSize:aSize];

    if (_isContainer)
    {
        [self _syncRootContainerFrame];

        if (oldSize.width !== aSize.width || oldSize.height !== aSize.height)
            [self setNeedsLayout:YES];
    }
}

// Keeps the root vbox the same size as its container. This is derived state,
// so it is never recorded for undo on its own.
- (void)_syncRootContainerFrame
{
    var subviews = [self subviews],
        frame = [self rootContainerFrame];

    for (var i = 0; i < [subviews count]; i++)
    {
        var subview = subviews[i];

        if (![subview isKindOfClass:[UIElementView class]] || ![[subview dataObject] valueForKey:@"isRootVBox"])
            continue;

        var data = [subview dataObject];
        UIBPerformWithoutUndo(function()
        {
            [data setValue:frame.origin.x forKey:@"originX"];
            [data setValue:frame.origin.y forKey:@"originY"];
            [data setValue:frame.size.width forKey:@"width"];
            [data setValue:frame.size.height forKey:@"height"];
        });
    }
}

#pragma mark -
#pragma mark *** Layout Sizes ***

// A change of this element's preferred size affects every enclosing box.
- (void)invalidateLayoutUpwards
{
    var view = self;
    while (view && [view isKindOfClass:[UIElementView class]])
    {
        [view setNeedsLayout:YES];
        [view setNeedsDisplay:YES];
        view = [view superview];
    }
}

// YES if the markup fixes this dimension (width or height).
- (BOOL)hasExplicitSizeForKey:(CPString)aKey
{
    var markupKeys = [[self dataObject] valueForKey:@"markupKeys"] || [];
    return markupKeys.indexOf(aKey) >= 0;
}

// The size the element would like without an explicit width/height.
// Subclasses measure their content (labels, buttons, boxes, ...).
- (CGSize)intrinsicContentSize
{
    var data = [self dataObject];
    return CGSizeMake(Number([data valueForKey:@"width"]) || [self frame].size.width,
                      Number([data valueForKey:@"height"]) || [self frame].size.height);
}

// The size a box uses for this element: explicit sizes win over the intrinsic size.
- (CGSize)preferredLayoutSize
{
    var size = [self intrinsicContentSize],
        data = [self dataObject];

    if ([self hasExplicitSizeForKey:@"width"])
        size.width = Number([data valueForKey:@"width"]) || size.width;
    if ([self hasExplicitSizeForKey:@"height"])
        size.height = Number([data valueForKey:@"height"]) || size.height;

    return CGSizeMake(MAX(0, size.width), MAX(0, size.height));
}

#pragma mark -
#pragma mark *** Accessors ***

- (id)value
{
    return ([self dataObject] == nil) ? @"" : [[self dataObject] valueForKey:@"value"];
}

- (void)sizeToFit
{
    //subview responsibility
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
        var selectionPath = [CPBezierPath bezierPathWithRect:CGRectInset([self bounds], 0, 0)];
        [selectionPath setLineWidth:2.0];
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
    var halign = UIBAlignKind([[self dataObject] valueForKey:@"halign"]);
    var valign = UIBAlignKind([[self dataObject] valueForKey:@"valign"]);

    [[CPColor controlDarkShadowColor] setFill];

    for (var i = 1; i <= 8; i++)
    {
        var shouldDraw = YES;
        // Horizontal handles
        if (halign === @"expand" && (i === kUIElementTopLeftHandle || i === kUIElementMiddleLeftHandle || i === kUIElementBottomLeftHandle || i === kUIElementTopRightHandle || i === kUIElementMiddleRightHandle || i === kUIElementBottomRightHandle))
            shouldDraw = NO;

        // Vertical handles
        if (valign === @"expand" && (i === kUIElementTopLeftHandle || i === kUIElementTopMiddleHandle || i === kUIElementTopRightHandle || i === kUIElementBottomLeftHandle || i === kUIElementBottomMiddleHandle || i === kUIElementBottomRightHandle))
            shouldDraw = NO;

        if (shouldDraw)
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

    var halign = UIBAlignKind([[self dataObject] valueForKey:@"halign"]);
    var valign = UIBAlignKind([[self dataObject] valueForKey:@"valign"]);

    for (var i = 1; i <= 8; i++)
    {
        var shouldCheck = YES;
        // Horizontal handles
        if (halign === @"expand" && (i === kUIElementTopLeftHandle || i === kUIElementMiddleLeftHandle || i === kUIElementBottomLeftHandle || i === kUIElementTopRightHandle || i === kUIElementMiddleRightHandle || i === kUIElementBottomRightHandle))
            shouldCheck = NO;

        // Vertical handles
        if (valign === @"expand" && (i === kUIElementTopLeftHandle || i === kUIElementTopMiddleHandle || i === kUIElementTopRightHandle || i === kUIElementBottomLeftHandle || i === kUIElementBottomMiddleHandle || i === kUIElementBottomRightHandle))
            shouldCheck = NO;

        if (shouldCheck && CGRectContainsPoint([self rectForHandle:i], aPoint))
            return i;
    }
    return kUIElementNoHandle;
}

- (BOOL)isConnecting
{
    return _isConnecting;
}

- (void)rightMouseDown:(CPEvent)theEvent
{
    [self mouseDown:theEvent];
}
- (void)rightMouseUp:(CPEvent)theEvent
{
    [self mouseUp:theEvent];
}

- (UIElementView)_findSelectedSubviewUnderPoint:(CGPoint)canvasPoint startingFromView:(UIElementView)topView
{
    var localPoint = [topView convertPoint:canvasPoint fromView:[self canvas]];
    var subviews = [topView subviews];

    // Search children first, in reverse order to check top-most views first
    for (var i = [subviews count] - 1; i >= 0; i--) {
        var subview = subviews[i];
        if ([subview isKindOfClass:[UIElementView class]] && ![subview isHidden] && CGRectContainsPoint([subview frame], localPoint)) {

            if ([[self canvas] isViewSelected:subview])
            {
                return subview;
            }

            // A subview is under the point, recurse into it.
            var deeperView = [self _findSelectedSubviewUnderPoint:canvasPoint startingFromView:subview];

            if (deeperView)
                return deeperView;
            }
    }

    return nil;
}

- (UIElementView)_findSubviewUnderPoint:(CGPoint)canvasPoint startingFromView:(UIElementView)topView
{
    var localPoint = [topView convertPoint:canvasPoint fromView:[self canvas]];
    var subviews = [topView subviews];

    // Search children first, in reverse order to check top-most views first
    for (var i = [subviews count] - 1; i >= 0; i--) {
        var subview = subviews[i];

        if ([subview isKindOfClass:[UIElementView class]] && ![subview isHidden] && CGRectContainsPoint([subview frame], localPoint))
            return subview;
    }

    return nil;
}


- (void)mouseDown:(CPEvent)theEvent
{
    var canvas = [self canvas];
    [[self canvas] dragDidStart:self];

    var localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];

    _lastMouseLoc = [[self canvas] convertPoint:[theEvent locationInWindow] fromView:nil];

    // First, check if we clicked a resize handle
    _activeHandle = [self handleAtPoint:localPoint];

    // Drill down (every click selects one view deeper)
    if (_activeHandle == kUIElementNoHandle && !([theEvent modifierFlags] & CPShiftKeyMask) && !([theEvent modifierFlags] & CPCommandKeyMask))
    {

        // Find the deepest selected view under the cursor, starting the search from the top-most view hit by the event (`self`).
        var targetView = [self _findSelectedSubviewUnderPoint:_lastMouseLoc startingFromView:self];

        // no subview is selected, so we select ourself unless we are already selected or a matching subview if we are selected
        if (!targetView)
        {
            if ([self isSelected])
            {
                // If we are already selected, we look for a subview under the click point
                targetView = [self _findSubviewUnderPoint:_lastMouseLoc startingFromView:self] || self;
            }
            else
                targetView = self;
        }
        else
        {
            // If we found a selected subview, we use its subview as the target
            targetView = [self _findSubviewUnderPoint:_lastMouseLoc startingFromView:targetView] || self;
        }

        [canvas deselectViews];
        [canvas selectView:targetView state:YES];

        // Consume the event to prevent dragging the container
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
}



- (void)mouseDragged:(CPEvent)theEvent
{
    var canvas = [self canvas];

    // The drag was cancelled (Escape) or never started.
    if (!canvas || ![canvas isDragActive])
        return;

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

        var builder = [canvas delegate];

        for (var i = 0; i < [selectedViews count]; i++)
        {
            var view = selectedViews[i];
            var isFreeForm = YES;

            // --- Handle Horizontal Drag (within an HBox) ---
            // Moving an element inside a box changes the spacer in front of it.
            // Spacers created here are part of the drag's single undo step.
            var hBoxParent = [view superview];
            if ([hBoxParent isKindOfClass:[UIHBoxView class]] && ![processedHBoxes containsObject:hBoxParent])
            {
                isFreeForm = NO;
                var siblings = [hBoxParent subviews];
                var viewIndex = [siblings indexOfObject:view];
                var spacerData = nil;

                if ([view isKindOfClass:[UIHSpaceView class]])
                    spacerData = [view dataObject];
                else if (viewIndex > 0 && [siblings[viewIndex - 1] isKindOfClass:[UIHSpaceView class]])
                    spacerData = [siblings[viewIndex - 1] dataObject];
                else if (deltaX !== 0 && [builder respondsToSelector:@selector(insertSpacerOfType:inParent:atIndex:)])
                    spacerData = [builder insertSpacerOfType:@"hspace" inParent:[hBoxParent dataObject] atIndex:viewIndex];

                if (spacerData)
                    [spacerData setValue:MAX(0, (Number([spacerData valueForKey:@"width"]) || 0) + deltaX) forKey:@"width"];

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
                    var rows = [vBoxParent subviews];
                    var rowIndex = [rows indexOfObject:itemInVBox];
                    var vSpacerData = nil;

                    if ([itemInVBox isKindOfClass:[UIVSpaceView class]])
                        vSpacerData = [itemInVBox dataObject];
                    else if (rowIndex > 0 && [rows[rowIndex - 1] isKindOfClass:[UIVSpaceView class]])
                        vSpacerData = [rows[rowIndex - 1] dataObject];
                    else if (deltaY !== 0 && [builder respondsToSelector:@selector(insertSpacerOfType:inParent:atIndex:)])
                        vSpacerData = [builder insertSpacerOfType:@"vspace" inParent:[vBoxParent dataObject] atIndex:rowIndex];

                    if (vSpacerData)
                        [vSpacerData setValue:MAX(0, (Number([vSpacerData valueForKey:@"height"]) || 0) + deltaY) forKey:@"height"];

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

- (void)resetMouseTrackingState
{
    _isConnecting = NO;
    _activeHandle = kUIElementNoHandle;
    _lastMouseLoc = nil;
    [[CPCursor arrowCursor] set];
}

- (void)mouseUp:(CPEvent)theEvent
{
    var canvas = [self canvas];

    // The drag was cancelled with Escape: nothing to commit.
    if (!theEvent || !canvas || ![canvas isDragActive])
    {
        [self resetMouseTrackingState];
        return;
    }

    var mouseLoc = [canvas convertPoint:[theEvent locationInWindow] fromView:nil];
    var actionName = nil;

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
        actionName = @"Resize";
    }
    else
    {
        // Handle mouse up for move
        [[CPCursor openHandCursor] set];
        _lastMouseLoc = nil;
        [canvas setNeedsDisplay:YES];
        [canvas elementDidMove:self];
        actionName = @"Move";
    }

    // Commit the whole drag as a single undo step (no-op if nothing changed).
    [canvas dragDidEndWithActionName:actionName];
}

- (void)_resizeWithEvent:(CPEvent)theEvent
{
    var canvas = [self canvas];
    var mouseLoc = [canvas convertPoint:[theEvent locationInWindow] fromView:nil];
    var deltaX = mouseLoc.x - _lastMouseLoc.x;
    var deltaY = mouseLoc.y - _lastMouseLoc.y;

    var frame = [self frame];
    var minSize = CGSizeMake(2 * kUIElementHandleSize, 2 * kUIElementHandleSize);
    var data = [self dataObject];

    // Left handles
    if (_activeHandle === kUIElementTopLeftHandle || _activeHandle === kUIElementMiddleLeftHandle || _activeHandle === kUIElementBottomLeftHandle) {
        var newWidth = frame.size.width - deltaX;
        if (newWidth > minSize.width) {
            [data setValue:newWidth forKey:@"width"];
            // We don't change origin here as layout manager handles it
        }
    }
    // Right handles
    if (_activeHandle === kUIElementTopRightHandle || _activeHandle === kUIElementMiddleRightHandle || _activeHandle === kUIElementBottomRightHandle) {
        var newWidth = frame.size.width + deltaX;
        if (newWidth > minSize.width) {
            [data setValue:newWidth forKey:@"width"];
        }
    }
    // Top handles
    if (_activeHandle === kUIElementTopLeftHandle || _activeHandle === kUIElementTopMiddleHandle || _activeHandle === kUIElementTopRightHandle) {
        var newHeight = frame.size.height - deltaY;
        if (newHeight > minSize.height) {
            [data setValue:newHeight forKey:@"height"];
        }
    }
    // Bottom handles
    if (_activeHandle === kUIElementBottomLeftHandle || _activeHandle === kUIElementBottomMiddleHandle || _activeHandle === kUIElementBottomRightHandle) {
        var newHeight = frame.size.height + deltaY;
        if (newHeight > minSize.height) {
            [data setValue:newHeight forKey:@"height"];
        }
    }

    // The KVO on the data object will trigger setNeedsLayout on the superview.
    _lastMouseLoc = mouseLoc;
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
    var view = [[CPView alloc] initWithFrame:[self frame]];

    if (_isContainer)
    {
        // Layout containers become plain views holding their native children.
        var subviews = [self subviews];
        for (var i = 0; i < [subviews count]; i++)
        {
            if ([subviews[i] isKindOfClass:[UIElementView class]])
                [view addSubview:[subviews[i] nativeUIElementWithMap:aMap]];
        }
    }
    else
    {
        // Elements without a native implementation yet: a labelled placeholder.
        [view setBackgroundColor:[CPColor colorWithCalibratedWhite:0.85 alpha:1.0]];

        var label = [[CPTextField alloc] initWithFrame:[view bounds]];
        [label setStringValue:[[self dataObject] valueForKey:@"type"] || @""];
        [label setAlignment:CPCenterTextAlignment];
        [label setTextColor:[CPColor darkGrayColor]];
        [label setFont:[CPFont systemFontOfSize:10]];
        [label setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
        [view addSubview:label];
    }

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

- (void)copy:(id)sender
{
    [[self canvas] copy:sender];
}

- (void)paste:(id)sender
{
    [[self canvas] paste:sender];
}

- (void)cut:(id)sender       { [[self canvas] cut:sender]; }
- (void)delete:(id)sender    { [[self canvas] delete:sender]; }
- (void)duplicate:(id)sender { [[self canvas] duplicate:sender]; }
- (void)groupInHBox:(id)sender { [[self canvas] groupInHBox:sender]; }
- (void)groupInVBox:(id)sender { [[self canvas] groupInVBox:sender]; }
- (void)ungroup:(id)sender   { [[self canvas] ungroup:sender]; }
- (void)moveEarlier:(id)sender { [[self canvas] moveEarlier:sender]; }
- (void)moveLater:(id)sender { [[self canvas] moveLater:sender]; }

- (BOOL)validateMenuItem:(CPMenuItem)aMenuItem
{
    // Forward validation to the canvas, which is the main handler.
    return [[self canvas] validateMenuItem:aMenuItem];
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



// --- Box layout (Renaissance-style) ---

UIBStackPadding = 4;

// The element views among someViews that take part in layout.
UIBLayoutViews = function(someViews)
{
    var result = [];
    for (var i = 0; i < someViews.length; i++)
    {
        var view = someViews[i];
        if ([view isKindOfClass:[UIElementView class]] && ![view isHidden])
            result.push(view);
    }
    return result;
};

/*!
    Lays out views along one axis inside aRect, like a Renaissance vbox/hbox:
    along the axis, "expand" elements share the remaining space and all
    others get their preferred size; across the axis each element is
    aligned min / center / max or stretched (expand).
*/
UIBLayoutStack = function(someViews, aRect, isVertical)
{
    var views = UIBLayoutViews(someViews),
        mainAlignKey = isVertical ? "valign" : "halign",
        crossAlignKey = isVertical ? "halign" : "valign",
        available = isVertical ? aRect.size.height : aRect.size.width,
        crossAvailable = isVertical ? aRect.size.width : aRect.size.height,
        preferred = [],
        fixedTotal = 0,
        expanders = 0;

    for (var i = 0; i < views.length; i++)
    {
        var size = [views[i] preferredLayoutSize];
        preferred.push(size);

        if (UIBAlignKind([[views[i] dataObject] valueForKey:mainAlignKey]) === "expand")
            expanders++;
        else
            fixedTotal += isVertical ? size.height : size.width;
    }

    var flexible = expanders ? MAX(0, (available - fixedTotal) / expanders) : 0,
        position = isVertical ? aRect.origin.y : aRect.origin.x,
        crossStart = isVertical ? aRect.origin.x : aRect.origin.y;

    for (var i = 0; i < views.length; i++)
    {
        var view = views[i],
            data = [view dataObject],
            size = preferred[i],
            mainSize = (UIBAlignKind([data valueForKey:mainAlignKey]) === "expand") ? flexible : (isVertical ? size.height : size.width),
            crossKind = UIBAlignKind([data valueForKey:crossAlignKey]),
            crossPreferred = isVertical ? size.width : size.height,
            crossSize = (crossKind === "expand") ? crossAvailable : MIN(crossPreferred, MAX(0, crossAvailable)),
            offset = 0;

        if (crossKind === "center")
            offset = (crossAvailable - crossSize) / 2;
        else if (crossKind === "max")
            offset = crossAvailable - crossSize;

        var frame = isVertical ? CGRectMake(crossStart + offset, position, crossSize, mainSize)
                               : CGRectMake(position, crossStart + offset, mainSize, crossSize);

        if (!CGRectEqualToRect([view frame], frame))
            [view setFrame:frame];

        position += mainSize;
    }
};

// The size needed to show someViews stacked along one axis.
UIBFittingStackSize = function(someViews, isVertical)
{
    var views = UIBLayoutViews(someViews),
        main = 0,
        cross = 0;

    for (var i = 0; i < views.length; i++)
    {
        var size = [views[i] preferredLayoutSize];
        main += isVertical ? size.height : size.width;
        cross = MAX(cross, isVertical ? size.width : size.height);
    }

    return isVertical ? CGSizeMake(cross, main) : CGSizeMake(main, cross);
};

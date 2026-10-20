
@class UIElementView;
@class UISplitViewView;

@implementation UIVBoxView : UIElementView
{
    BOOL _isDropTarget;
    CGPoint          _rubberStart;
    CGPoint          _rubberEnd;
    BOOL             _isRubbing;
}

+ (CPArray)persistentProperties
{
    var properties = [CPMutableSet setWithArray:[super persistentProperties]];
    [properties minusSet:[CPSet setWithArray:['value']]];
    return [properties allObjects];
}

+ (CPDictionary)defaultValues
{
    return @{
                "width": 200,
                "height": 100,
                "halign": "expand",
                "valign": "expand"
            };
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types removeObjectForKey:@"value"];
    return types;
}

+ (CPDictionary)propertyGroups
{
    var groups = [[super propertyGroups] copy];
    [groups removeObjectForKey:@"value"];
    return groups;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        [self setBackgroundColor:[CPColor clearColor]];
        [self setClipsToBounds:NO];
        _isContainer = YES;
    }
    return self;
}

- (void)addSubview:(CPView)aView
{
    [super addSubview:aView];
    [self invalidateLayoutUpwards];
}

// Children are stacked top to bottom (see UIBLayoutStack).
- (CGRect)stackRect
{
    return CGRectInset([self bounds], UIBStackPadding, UIBStackPadding);
}

// The root box of a vertical split view lays its panes out side by side.
- (BOOL)_uib_isHorizontalSplit
{
    return !![[self dataObject] valueForKey:@"isRootVBox"] && [[self superview] isKindOfClass:[UISplitViewView class]] &&
           !![[[self superview] dataObject] valueForKey:@"vertical"];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    UIBLayoutStack([self subviews], [self stackRect], ![self _uib_isHorizontalSplit]);
}

// The size of the stacked content, used when this box sits in another box.
- (CGSize)intrinsicContentSize
{
    var size = UIBFittingStackSize([self subviews], ![self _uib_isHorizontalSplit]);
    return CGSizeMake(MAX(20, size.width + 2 * UIBStackPadding), MAX(20, size.height + 2 * UIBStackPadding));
}

- (void)drawRect:(CGRect)rect
{
    [self drawSkeleton:rect];

    if ([self isSelected])
    {
        UIBFillStroke([CPBezierPath bezierPathWithRect:CGRectInset([self bounds], 1, 1)], nil, UIBTheme("accent"), 2);
        [self drawHandles];
    }

    if (_isRubbing)
    {
        var rubber = CGRectUnion(CGRectMake(_rubberStart.x, _rubberStart.y, 0.1, 0.1), CGRectMake(_rubberEnd.x, _rubberEnd.y, 0.1, 0.1));
        UIBFillStroke([CPBezierPath bezierPathWithRect:rubber], UIBTheme("accentSoft"), UIBTheme("accent"), 1);
    }
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds],
        data = [self dataObject],
        isRoot = !![data valueForKey:@"isRootVBox"],
        path = [CPBezierPath bezierPathWithRect:CGRectInset(bounds, 0.5, 0.5)];

    if (_isDropTarget)
    {
        UIBFillStroke(path, UIBTheme("accentSoft"), UIBTheme("accent"), 2);
        return;
    }

    // Boxes are only hinted at: a fine dashed outline (fainter for a window's root box).
    [path setLineDash:[3, 3] count:2 phase:0];
    UIBFillStroke(path, nil, UIBTheme(isRoot ? "rootLine" : "containerLine"), 1);

    // In a split view the panes sit side by side (vertical) or stacked: draw the dividers.
    if (isRoot && [[self superview] isKindOfClass:[UISplitViewView class]])
    {
        var panes = UIBLayoutViews([self subviews]),
            sideBySide = !![[[self superview] dataObject] valueForKey:@"vertical"];

        for (var i = 1; i < panes.length; i++)
        {
            var frame = [panes[i] frame],
                divider = sideBySide ? CGRectMake(frame.origin.x - 1, 0, 2, bounds.size.height) : CGRectMake(0, frame.origin.y - 1, bounds.size.width, 2);
            [UIBTheme("controlBorder") setFill];
            [CPBezierPath fillRect:divider];
        }
    }
}

- (void)setAsDropTarget:(BOOL)isDropTarget
{
    if (_isDropTarget !== isDropTarget)
    {
        _isDropTarget = isDropTarget;
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseDown:(CPEvent)theEvent
{
    if ([[self dataObject] valueForKey:@"isRootVBox"]) {
        // On a click into the window's content area, deselect all elements.
        [[self canvas] deselectViews];

        var localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        _rubberStart = localPoint;
        _rubberEnd = _rubberStart;
        _isRubbing = YES;
        [CPApp setTarget:self selector:@selector(_dragOpenSpaceWithEvent:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
        return;
    }
    [super mouseDown:theEvent];
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
                if ([aView isKindOfClass:[UIElementView class]] && ![aView isHidden] && CGRectIntersectsRect([aView frame], rubberRect)) {
                    var dataIndex = [allDataObjects indexOfObjectIdenticalTo:[aView dataObject]];
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

@end

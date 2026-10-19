
@class UIElementView;

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

- (void)layoutSubviews
{
    [super layoutSubviews];
    UIBLayoutStack([self subviews], [self stackRect], YES);
}

// The size of the stacked content, used when this box sits in another box.
- (CGSize)intrinsicContentSize
{
    var size = UIBFittingStackSize([self subviews], YES);
    return CGSizeMake(MAX(20, size.width + 2 * UIBStackPadding), MAX(20, size.height + 2 * UIBStackPadding));
}

- (void)drawRect:(CGRect)rect
{
    [self drawSkeleton:rect];

    if ([self isSelected])
    {
        [self drawHandles];
    }

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

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    var path = [CPBezierPath bezierPathWithRect:CGRectInset(bounds, 0.5, 0.5)];
    [[[CPColor grayColor] colorWithAlphaComponent:[[self dataObject] valueForKey:@"isRootVBox"] ? 0.25 : 0.6] setStroke];
    [path setLineWidth:[self isSelected] ? 3.0 : 1.0];
    [path setLineDash:[2,2] count:2 phase:0];
    [path stroke];

    if (_isDropTarget)
    {
        [[[CPColor yellowColor] colorWithAlphaComponent:0.5] setFill];
        [CPBezierPath fillRect:bounds];
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

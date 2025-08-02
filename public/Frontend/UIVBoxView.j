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
    return [super persistentProperties].filter(p => p !== 'value').concat(["width", "height"]);
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
    return @{
        "width": UIBNumber,
        "height": UIBNumber,
        "halign": UIBEnumeration,
        "valign": UIBEnumeration
    };
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
    [self setNeedsLayout:YES];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    var subviews = [self subviews];
    var count = [subviews count];
    if (count === 0) return;

    var bounds = [self bounds];
    var totalFixedHeight = 0;
    var expandableChildren = 0;

    // First pass: Calculate total height of fixed elements and count expandable ones.
    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var valign = [[subview dataObject] valueForKey:@"valign"];

        if (valign === "expand")
        {
            expandableChildren++;
        }
        else // "min"
        {
            totalFixedHeight += [subview frame].size.height;
        }
    }

    var flexibleHeight = 0;
    if (expandableChildren > 0)
    {
        var remainingSpace = bounds.size.height - totalFixedHeight;
        flexibleHeight = (remainingSpace > 0) ? (remainingSpace / expandableChildren) : 0;
    }

    var currentY = 0;

    // Second pass: Set the frames.
    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var frame = [subview frame];
        var frameWidth;
        var frameHeight = 0;
        var valign = [[subview dataObject] valueForKey:@"valign"];

        if (valign === "expand")
        {
            frameHeight = flexibleHeight;
        }
        else // "min"
        {
            frameHeight = [[subview dataObject] valueForKey:@"height"];
        }

        var halign = [[subview dataObject] valueForKey:@"halign"];
        if (halign === "min")
        {
            if ([subview respondsToSelector:@selector(sizeToFit)])
            {
                [subview sizeToFit];
                frameWidth = [subview frame].size.width;
            }
            else
            {
                frameWidth = [subview frame].size.width;
            }
        }
        else // "expand"
        {
            frameWidth = bounds.size.width;
        }
        
        // Center horizontally
        var x = (bounds.size.width - frameWidth) / 2.0;

        [subview setFrame:CGRectMake(x, currentY, frameWidth, frameHeight)];
        currentY += frameHeight;
    }
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
    var path = [CPBezierPath bezierPathWithRect:bounds];
    [[CPColor grayColor] setStroke];
    [path setLineWidth:1.0];
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

@end


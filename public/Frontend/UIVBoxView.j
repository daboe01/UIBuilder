@class UIElementView;

@implementation UIVBoxView : UIElementView
{
    BOOL _isDropTarget;
}

+ (CPDictionary)defaultValues
{
    return {
        value: "VBox"
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
    var totalFixedAndMinHeight = 0;
    var expandableSpaces = 0;

    // First pass: Calculate total height of fixed elements and count expandable ones.
    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        if ([subview isKindOfClass:[UIVSpaceView class]])
        {
            if ([[subview dataObject] valueForKey:@"size"] === "min")
                totalFixedAndMinHeight += [[subview dataObject] valueForKey:@"height"];
            else
                expandableSpaces++;
        }
        else // This is a regular view like an HBox
        {
            // Treat its current height as fixed.
            totalFixedAndMinHeight += [subview frame].size.height;
        }
    }

    var flexibleHeight = 0;
    if (expandableSpaces > 0) {
        var remainingSpace = bounds.size.height - totalFixedAndMinHeight;
        flexibleHeight = (remainingSpace > 0) ? (remainingSpace / expandableSpaces) : 0;
    }

    var currentY = 0;

    // Second pass: Set the frames.
    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var frameHeight = 0;

        if ([subview isKindOfClass:[UIVSpaceView class]])
        {
            if ([[subview dataObject] valueForKey:@"size"] === "min")
                frameHeight = [[subview dataObject] valueForKey:@"height"];
            else
                frameHeight = flexibleHeight;
        }
        else // Regular view (HBox)
        {
            frameHeight = [subview frame].size.height; // Use its own height
        }

        [subview setFrame:CGRectMake(0, currentY, bounds.size.width, frameHeight)];
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

@end


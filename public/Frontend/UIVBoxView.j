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
    [super drawRect:rect];
    [self drawSkeleton:rect];
}

- (void)drawSkeleton:(CGRect)rect
{
    var layer = [self layer];
    [layer setBorderColor:[[CPColor grayColor] CGColor]];
    [layer setBorderWidth:1.0];
    [layer setLineDashPattern:[2,2]];

    if (_isDropTarget)
    {
        [[[CPColor yellowColor] colorWithAlphaComponent:0.5] setFill];
        [CPBezierPath fillRect:[self bounds]];
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


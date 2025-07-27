@class UIElementView;

@implementation UIVBoxView : UIElementView
{
    BOOL _isDropTarget;
}

+ (CPDictionary)defaultValues
{
    return @{
        "value": "VBox"
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
            frameHeight = [subview frame].size.height;
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


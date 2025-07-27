@class UIElementView;

@implementation UIHBoxView : UIElementView
{
    BOOL _isDropTarget;
}

+ (CPDictionary)defaultValues
{
    return @{
        "value": "HBox"
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
    var totalFixedWidth = 0;
    var expandableSpaces = 0;

    // First pass: Calculate total width of fixed elements and count expandable ones.
    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        if ([subview isKindOfClass:[UIHSpaceView class]])
        {
            if ([[subview dataObject] valueForKey:@"size"] === "min")
                totalFixedWidth += [[subview dataObject] valueForKey:@"width"];
            else
                expandableSpaces++;
        }
        else // This is a regular view
        {
            totalFixedWidth += [subview frame].size.width;
        }
    }

    var flexibleWidth = 0;
    if (expandableSpaces > 0) {
        var remainingSpace = bounds.size.width - totalFixedWidth;
        flexibleWidth = (remainingSpace > 0) ? (remainingSpace / expandableSpaces) : 0;
    }

    var currentX = 0;

    // Second pass: Set the frames.
    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var frame = [subview frame];
        var frameHeight = frame.size.height;
        var frameWidth = 0;

        if ([subview isKindOfClass:[UIHSpaceView class]])
        {
            if ([[subview dataObject] valueForKey:@"size"] === "min")
                frameWidth = [[subview dataObject] valueForKey:@"width"];
            else
                frameWidth = flexibleWidth;
        }
        else // Regular view
        {
            frameWidth = [subview frame].size.width;
        }
        
        var valign = [[subview dataObject] valueForKey:@"valign"];
        if (valign === "expand")
        {
            frameHeight = bounds.size.height;
        }

        // Center vertically
        var y = (bounds.size.height - frameHeight) / 2.0;

        [subview setFrame:CGRectMake(currentX, y, frameWidth, frameHeight)];
        currentX += frameWidth;
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


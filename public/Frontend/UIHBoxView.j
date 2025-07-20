@class UIElementView;

@implementation UIHBoxView : UIElementView
{
    BOOL _isDropTarget;
}

+ (CPDictionary)defaultValues
{
    return {
        value: "HBox"
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
    var currentX = 0;

    // A simple layout that respects the width of each subview.
    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var frameWidth = [subview frame].size.width;

        // Set the origin, but keep the width and height from the subview itself.
        [subview setFrameOrigin:CGPointMake(currentX, 0)];
        subview._frame.size.height = [self bounds].size.height;

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


@import "UIElementView.j"

@implementation UIImageViewView : UIElementView

+ (void)initialize
{
    if (self === [UIImageViewView class])
    {
        [UIElementView registerViewClass:self forElementType:@"imageView"];
    }
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(100, 100)];
        }
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    [[CPColor controlColor] setFill];
    [CPBezierPath fillRect:bounds];
    [[CPColor darkGrayColor] setStroke];
    [CPBezierPath strokeRect:bounds];

    // Draw a placeholder image icon
    var path = [CPBezierPath bezierPath];
    [path moveToPoint:CGPointMake(20, 20)];
    [path lineToPoint:CGPointMake(80, 80)];
    [path moveToPoint:CGPointMake(80, 20)];
    [path lineToPoint:CGPointMake(20, 80)];
    [path stroke];
}

@end
@class UIElementView

@implementation UIStepperView : UIElementView

+ (void)initialize
{
    if (self === [UIStepperView class])
    {
        [UIElementView registerViewClass:self forElementType:@"stepper"];
    }
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(20, 40)];
        }
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    // Draw up arrow
    var upRect = CGRectMake(0, 0, bounds.size.width, bounds.size.height / 2);
    [[CPColor controlColor] setFill];
    [CPBezierPath fillRect:upRect];
    [[CPColor blackColor] setStroke];
    [CPBezierPath strokeRect:upRect];
    var path = [CPBezierPath bezierPath];
    [path moveToPoint:CGPointMake(5, 15)];
    [path lineToPoint:CGPointMake(10, 5)];
    [path lineToPoint:CGPointMake(15, 15)];
    [path stroke];

    // Draw down arrow
    var downRect = CGRectMake(0, bounds.size.height / 2, bounds.size.width, bounds.size.height / 2);
    [[CPColor controlColor] setFill];
    [CPBezierPath fillRect:downRect];
    [[CPColor blackColor] setStroke];
    [CPBezierPath strokeRect:downRect];
    path = [CPBezierPath bezierPath];
    [path moveToPoint:CGPointMake(5, 25)];
    [path lineToPoint:CGPointMake(10, 35)];
    [path lineToPoint:CGPointMake(15, 25)];
    [path stroke];
}

@end
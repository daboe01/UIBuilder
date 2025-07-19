@class UIElementView

@implementation UIPopUpButtonView : UIElementView

+ (void)initialize
{
    if (self === [UIPopUpButtonView class])
    {
        [UIElementView registerViewClass:self forElementType:@"popUpButton"];
    }
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(120, 24)];
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

    // Draw arrows
    var path = [CPBezierPath bezierPath];
    [path moveToPoint:CGPointMake(bounds.size.width - 15, 10)];
    [path lineToPoint:CGPointMake(bounds.size.width - 10, 15)];
    [path lineToPoint:CGPointMake(bounds.size.width - 5, 10)];
    [path stroke];
}

@end
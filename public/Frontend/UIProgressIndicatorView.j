@class UIElementView

@implementation UIProgressIndicatorView : UIElementView

+ (void)initialize
{
    if (self === [UIProgressIndicatorView class])
    {
        [UIElementView registerViewClass:self forElementType:@"progresIndicator"];
    }
}

+ (JSObject)defaultValues
{
    return @{
        "value": 50,
        "maxValue": 100,
        "isIndeterminate": false,
        "style": "Bar",
        "outlets": "delegate",
        "actions": "takeDoubleValueFrom:"
    };
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(150, 20)];
        }
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    var style = [[self dataObject] valueForKey:@"style"];

    if (style === "Bar") {
        [[CPColor controlColor] setFill];
        [CPBezierPath fillRect:bounds];
        [[CPColor blueColor] setFill];
        var progressRect = CGRectMake(0, 0, bounds.size.width * 0.5, bounds.size.height);
        [CPBezierPath fillRect:progressRect];
    } else { // Spinning
        var center = CGPointMake(bounds.size.width / 2, bounds.size.height / 2);
        [[CPColor blueColor] setStroke];
        var path = [CPBezierPath bezierPathWithOvalInRect:CGRectMake(center.x - 10, center.y - 10, 20, 20)];
        [path setLineWidth:3];
        [path stroke];
    }
}

@end
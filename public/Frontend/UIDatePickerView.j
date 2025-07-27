@class UIElementView

@implementation UIDatePickerView : UIElementView

+ (void)initialize
{
    if (self === [UIDatePickerView class])
    {
        [UIElementView registerViewClass:self forElementType:@"datePicker"];
    }
}

+ (JSObject)defaultValues
{
    return @{
        "value": "now",
        "outlets": "delegate",
        "actions": "takeDateValueFrom:"
    };
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(150, 24)];
        }
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    [[CPColor whiteColor] setFill];
    [CPBezierPath fillRect:bounds];
    [[CPColor blackColor] setStroke];
    [CPBezierPath strokeRect:bounds];

    // Draw calendar icon
    var iconRect = CGRectMake(bounds.size.width - 20, 2, 18, 18);
    [[CPColor grayColor] setFill];
    [CPBezierPath fillRect:iconRect];
}

@end
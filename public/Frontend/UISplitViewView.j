@import "UIElementView.j"

@implementation UISplitViewView : UIElementView

+ (void)initialize
{
    if (self === [UISplitViewView class])
    {
        [UIElementView registerViewClass:self forElementType:@"splitView"];
    }
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(300, 200)];
        }
        _isContainer = YES;
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

    // Draw divider
    var vertical = [[self dataObject] valueForKey:@"vertical"];
    if (vertical) {
        var dividerRect = CGRectMake(0, bounds.size.height / 2 - 2, bounds.size.width, 4);
        [[CPColor grayColor] setFill];
        [CPBezierPath fillRect:dividerRect];
    } else {
        var dividerRect = CGRectMake(bounds.size.width / 2 - 2, 0, 4, bounds.size.height);
        [[CPColor grayColor] setFill];
        [CPBezierPath fillRect:dividerRect];
    }
}

@end
@class UIElementView

@implementation UITableViewView : UIElementView

+ (void)initialize
{
    if (self === [UITableViewView class])
    {
        [UIElementView registerViewClass:self forElementType:@"tableView"];
    }
}

+ (JSObject)defaultValues
{
    return @{
        "columns": "Column 1, Column 2",
        "outlets": "delegate, dataSource",
        "actions": "reloadData"
    };
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(300, 200)];
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

    // Draw header
    var headerRect = CGRectMake(0, 0, bounds.size.width, 22);
    [[CPColor controlColor] setFill];
    [CPBezierPath fillRect:headerRect];
    [[CPColor blackColor] setStroke];
    [CPBezierPath strokeRect:headerRect];

    // Draw some rows
    for (var i = 1; i < 8; i++) {
        var rowRect = CGRectMake(0, 22 * i, bounds.size.width, 22);
        if (i % 2 == 0) {
            [[CPColor controlHighlightColor] setFill];
            [CPBezierPath fillRect:rowRect];
        }
        [[CPColor gridColor] setStroke];
        [CPBezierPath strokeRect:rowRect];
    }
}

@end
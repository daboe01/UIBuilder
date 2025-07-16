@import "UIElementView.j"

@implementation UIScrollViewView : UIElementView

+ (void)initialize
{
    if (self === [UIScrollViewView class])
    {
        [UIElementView registerViewClass:self forElementType:@"scrollView"];
    }
}

+ (CPArray)persistentProperties
{
    return [super persistentProperties].concat(["hasHorizontalScroller", "hasVerticalScroller", "borderType"]);
}

+ (CPDictionary)defaultValues
{
    return {
        hasHorizontalScroller: YES,
        hasVerticalScroller: YES,
        borderType: "bezel"
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [super propertyTypes];
    [types setObject:UIBBoolean forKey:@"hasHorizontalScroller"];
    [types setObject:UIBBoolean forKey:@"hasVerticalScroller"];
    [types setObject:UIBString forKey:@"borderType"];
    return types;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(200, 150)];
        }
        _isContainer = YES;
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

    var hasVerticalScroller = [[self dataObject] valueForKey:@"hasVerticalScroller"];
    if (hasVerticalScroller) {
        var scrollbarRect = CGRectMake(bounds.size.width - 15, 0, 15, bounds.size.height);
        [[CPColor controlColor] setFill];
        [CPBezierPath fillRect:scrollbarRect];
    }

    var hasHorizontalScroller = [[self dataObject] valueForKey:@"hasHorizontalScroller"];
    if (hasHorizontalScroller) {
        var scrollbarRect = CGRectMake(0, bounds.size.height - 15, bounds.size.width, 15);
        [[CPColor controlColor] setFill];
        [CPBezierPath fillRect:scrollbarRect];
    }
}

@end
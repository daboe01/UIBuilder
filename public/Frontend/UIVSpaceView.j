@class UIElementView;

@implementation UIVSpaceView : UIElementView
{
}

+ (CPArray)persistentProperties
{
    return [super persistentProperties].concat(["size", "height"]);
}

+ (CPDictionary)defaultValues
{
    return {
        value: "VSpace",
        size: "min",
        height: 10
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [super propertyTypes];
    [types setObject:UIBString forKey:@"size"];
    [types setObject:UIBNumber forKey:@"height"];
    return types;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        [self setBackgroundColor:[CPColor clearColor]];
        [self setClipsToBounds:NO];
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var layer = [self layer];
    [layer setBorderColor:[[CPColor grayColor] CGColor]];
    [layer setBorderWidth:1.0];
    [layer setLineDashPattern:[2,2]];

    var context = [[CPGraphicsContext currentContext] graphicsPort];
    var bounds = [self bounds];

    CGContextBeginPath(context);
    CGContextMoveToPoint(context, CGRectGetMidX(bounds), CGRectGetMinY(bounds));
    CGContextAddLineToPoint(context, CGRectGetMidX(bounds), CGRectGetMaxY(bounds));
    CGContextStrokePath(context);
}

@end

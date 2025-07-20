@class UIElementView;

@implementation UIHSpaceView : UIElementView
{
}

+ (CPArray)persistentProperties
{
    return [super persistentProperties].concat(["size", "width"]);
}

+ (CPDictionary)defaultValues
{
    return {
        value: "HSpace",
        size: "min",
        width: 10
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [super propertyTypes];
    [types setObject:UIBString forKey:@"size"];
    [types setObject:UIBNumber forKey:@"width"];
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
    CGContextMoveToPoint(context, CGRectGetMinX(bounds), CGRectGetMidY(bounds));
    CGContextAddLineToPoint(context, CGRectGetMaxX(bounds), CGRectGetMidY(bounds));
    CGContextStrokePath(context);
}

@end

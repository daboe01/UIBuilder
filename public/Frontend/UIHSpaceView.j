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

- (void)drawRect:(CGRect)rect
{
    // Don't call super, we want a completely custom look.
    [self drawSkeleton:rect];

    // We still want to see selection handles if it's selected.
    if ([self isSelected])
    {
        [self drawHandles];
    }
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    var midY = CGRectGetMidY(bounds);

    // Draw a simple horizontal line
    var path = [CPBezierPath bezierPath];
    [path moveToPoint:CGPointMake(bounds.origin.x, midY)];
    [path lineToPoint:CGPointMake(bounds.origin.x + bounds.size.width, midY)];

    [[CPColor grayColor] setStroke];
    [path setLineWidth:1.0];
    [path setLineDash:[2,2] count:2 phase:0];
    [path stroke];
}

@end

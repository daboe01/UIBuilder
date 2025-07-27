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
    return @{
        "size": "min",
        "width": 10
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types setObject:UIBEnumeration forKey:@"size"];
    [types setObject:UIBNumber forKey:@"width"];
    return types;
}

+ (CPDictionary)propertyEnumerations
{
    return @{
        "size": ["min", "expand"]
    };
}

- (id)init
{
    self = [super initWithFrame:CPMakeRect(0,0,0,0)];
    if (self) {
        console.log("UIHSpaceView init");
        [self setBackgroundColor:[CPColor clearColor]];
        [self setClipsToBounds:NO];
    }
    return self;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        console.log("UIHSpaceView initWithFrame:");
        [self setBackgroundColor:[CPColor clearColor]];
        [self setClipsToBounds:NO];
    }
    return self;
}

- (void)drawRect:(CGRect)aRect
{
    console.log("UIHSpaceView drawRect:");
    if ([self isSelected])
    {
        [super drawRect:aRect];
        return;
    }

    var bounds = [self bounds];
    var path = [CPBezierPath bezierPath];
    var y = bounds.size.height / 2.0;

    [path moveToPoint:CGPointMake(bounds.origin.x, y)];
    [path lineToPoint:CGPointMake(bounds.origin.x + bounds.size.width, y)];

    [[CPColor blackColor] set];
    var dashes = [2.0, 2.0];
    [path setLineDash:dashes count:2 phase:0.0];
    [path setLineWidth:1.0];
    [path stroke];
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

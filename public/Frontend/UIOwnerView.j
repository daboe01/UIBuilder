//
//  UIOwnerView.j
//  "File's Owner": the object that loads the markup (#CPOwner). It is not
//  written to the markup, but connections to and from it are. Control-drag
//  from it to create outlets, or to it to connect actions.
//

@import "UIElementView.j"

@implementation UIOwnerView : UIElementView

+ (CPArray)persistentProperties
{
    return ["value", "actions", "outlets"];
}

+ (CPDictionary)defaultValues
{
    return @{ "value": "File's Owner", "actions": "", "outlets": "" };
}

+ (CPDictionary)propertyTypes
{
    return @{ "value": UIBString, "actions": UIBString, "outlets": UIBString };
}

+ (CPDictionary)propertyGroups
{
    return @{ "value": UIBPropertyTabProperties, "actions": UIBPropertyTabProperties, "outlets": UIBPropertyTabProperties };
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self)
        [self setFrameSize:CGSizeMake(120, 64)];
    return self;
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(120, 64);
}

- (void)drawHandles
{
    // The owner has a fixed size.
}

- (int)handleAtPoint:(CGPoint)aPoint
{
    return kUIElementNoHandle;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds],
        path = [CPBezierPath bezierPathWithRoundedRect:CGRectInset(bounds, 1, 1) radius:8];

    [[CPColor colorWithCalibratedRed:1.0 green:0.97 blue:0.85 alpha:1.0] setFill];
    [path fill];
    [[CPColor colorWithCalibratedRed:0.75 green:0.6 blue:0.2 alpha:1.0] setStroke];
    [path stroke];

    // A small cube icon
    var cube = [CPBezierPath bezierPath];
    [cube moveToPoint:CGPointMake(12, 22)];
    [cube lineToPoint:CGPointMake(24, 16)];
    [cube lineToPoint:CGPointMake(36, 22)];
    [cube lineToPoint:CGPointMake(36, 38)];
    [cube lineToPoint:CGPointMake(24, 44)];
    [cube lineToPoint:CGPointMake(12, 38)];
    [cube closePath];
    [cube moveToPoint:CGPointMake(12, 22)];
    [cube lineToPoint:CGPointMake(24, 28)];
    [cube lineToPoint:CGPointMake(36, 22)];
    [cube moveToPoint:CGPointMake(24, 28)];
    [cube lineToPoint:CGPointMake(24, 44)];
    [[CPColor colorWithCalibratedRed:0.75 green:0.6 blue:0.2 alpha:1.0] setStroke];
    [cube stroke];

    var title = [[self dataObject] valueForKey:@"value"] || "File's Owner";
    [title drawAtPoint:CGPointMake(44, 16) withAttributes:@{ CPFontAttributeName: [CPFont boldSystemFontOfSize:11], CPForegroundColorAttributeName: [CPColor blackColor] }];
    [@"#CPOwner" drawAtPoint:CGPointMake(44, 34) withAttributes:@{ CPFontAttributeName: [CPFont systemFontOfSize:10], CPForegroundColorAttributeName: [CPColor grayColor] }];
}

- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap
{
    return nil;
}

@end

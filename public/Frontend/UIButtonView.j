@class UIElementView

@implementation UIButtonView : UIElementView

+ (void)initialize
{
    if (self === [UIButtonView class])
    {
        [UIElementView registerViewClass:self forElementType:@"button"];
    }
}

+ (CPDictionary)defaultValues
{
    return {
        value: "Button",
        outlets: "target, delegate",
        actions: "takeValueFrom:",
        halign: "min",
        valign: "min"
    };
}

+ (CPDictionary)propertyTypes
{
    return [super propertyTypes].copy({value: UIBString});
}
- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(100, 24)];
        }
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = CGRectInset([self bounds], 1, 1);
    
    // Draw button shape with gradient
    var buttonPath = [CPBezierPath bezierPathWithRoundedRect:bounds radius:5.0];
    var gradient = [[CPGradient alloc] initWithStartingColor:[CPColor whiteColor]
                                                 endingColor:[CPColor controlColor]];
    [gradient drawInBezierPath:buttonPath angle:90];
    
    // Draw button border
    [[CPColor grayColor] setStroke];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];
    
    // Draw value
    var valueSize = [[self value] sizeWithAttributes:_stringAttributes];
    [[self value] drawAtPoint:CGPointMake((bounds.size.width - valueSize.width) / 2.0 + 1, (bounds.size.height - valueSize.height) / 2.0 - 2) withAttributes:_stringAttributes];
}

- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap
{
    var button = [[CPButton alloc] initWithFrame:[self frame]];
    [button setTitle:[self value]];

    if (aMap)
    {
        var elementID = [[self dataObject] valueForKey:@"id"];
        [aMap setObject:button forKey:elementID];
    }

    return button;
}

@end
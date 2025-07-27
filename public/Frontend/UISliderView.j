@class UIElementView

@implementation UISliderView : UIElementView

+ (void)initialize
{
    if (self === [UISliderView class])
    {
        [UIElementView registerViewClass:self forElementType:@"slider"];
    }
}

+ (CPDictionary)defaultValues
{
    var defaults = [[super defaultValues] copy];
    [defaults setValue:0.5 forKey:@"value"];
    [defaults setValue:"target, delegate" forKey:@"outlets"];
    [defaults setValue:"takeFloatValueFrom:, takeIntegerValueFrom:" forKey:@"actions"];
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types setObject:UIBNumber forKey:@"value"];
    return types;
}
- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(150, 20)];
        }
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = CGRectInset([self bounds], 8, 0);
    var midY = bounds.size.height / 2.0;

    // Draw track
    [[CPColor grayColor] setStroke];
    var trackPath = [CPBezierPath bezierPath];
    [trackPath setLineWidth:3.0];
    [trackPath moveToPoint:CGPointMake(bounds.origin.x, midY)];
    [trackPath lineToPoint:CGPointMake(bounds.origin.x + bounds.size.width, midY)];
    [trackPath stroke];
    
    // Draw knob
    var knobX = bounds.origin.x + bounds.size.width * [self value];
    var knobRect = CGRectMake(knobX - 8, midY - 8, 16, 16);
    var knobPath = [CPBezierPath bezierPathWithOvalInRect:knobRect];
    [[CPColor whiteColor] setFill];
    [knobPath fill];
    [[CPColor darkGrayColor] setStroke];
    [knobPath setLineWidth:1.0];
    [knobPath stroke];
}

- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap
{
    var slider = [[CPSlider alloc] initWithFrame:[self frame]];
    [slider setFloatValue:[self value]];

    if (aMap)
    {
        var elementID = [[self dataObject] valueForKey:@"id"];
        [aMap setObject:slider forKey:elementID];
    }

    return slider;
}

@end

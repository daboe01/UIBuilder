@class UIElementView

@implementation UITextFieldView : UIElementView

+ (void)initialize
{
    if (self === [UITextFieldView class])
    {
        [UIElementView registerViewClass:self forElementType:@"textfield"];
    }
}

+ (CPDictionary)defaultValues
{
    return {value: "Text Field", outlets: "target, delegate", actions: "takeStringValueFrom:, takeIntegerValueFrom:"};
}

+ (CPDictionary)propertyTypes
{
    return [super propertyTypes].copy({value: UIBString});
}
- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self)
    {
        if (CGRectIsEmpty(aRect))
        {
            [self setFrameSize:CGSizeMake(150, 22)];
        }
        [_stringAttributes setObject:[CPFont systemFontOfSize:12] forKey:CPFontAttributeName];
        [_stringAttributes setObject:[CPColor grayColor] forKey:CPForegroundColorAttributeName];
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = CGRectInset([self bounds], 1, 1);
    
    // Background
    [[CPColor textBackgroundColor] setFill];
    [CPBezierPath fillRect:bounds];
    
    // Inset border
    [[CPColor grayColor] setStroke];
    [CPBezierPath strokeRect:bounds];
    
    // Draw placeholder value
    var valueSize = [[self value] sizeWithAttributes:_stringAttributes];
    [[self value] drawAtPoint:CGPointMake(5, (bounds.size.height - valueSize.height) / 2.0 - 2) withAttributes:_stringAttributes];
}

- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap
{
    var textField = [[CPTextField alloc] initWithFrame:[self frame]];
    [textField setStringValue:[self value]];

    if (aMap)
    {
        var elementID = [[self dataObject] valueForKey:@"id"];
        [aMap setObject:textField forKey:elementID];
    }

    return textField;
}

@end
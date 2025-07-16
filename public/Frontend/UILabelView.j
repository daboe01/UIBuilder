@import "UIElementView.j"

@implementation UILabelView : UIElementView

+ (void)initialize
{
    if (self === [UILabelView class])
    {
        [UIElementView registerViewClass:self forElementType:@"label"];
    }
}

+ (CPArray)persistentProperties
{
    return [super persistentProperties].concat(["value"]);
}

+ (CPDictionary)defaultValues
{
    return {
        value: "Label"
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [super propertyTypes];
    [types setObject:UIBString forKey:@"value"];
    return types;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(100, 20)];
        }
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    var value = [[self dataObject] valueForKey:@"value"];
    if (value) {
        var valueSize = [value sizeWithAttributes:_stringAttributes];
        [value drawAtPoint:CGPointMake(0, (bounds.size.height - valueSize.height) / 2) withAttributes:_stringAttributes];
    }
}

@end
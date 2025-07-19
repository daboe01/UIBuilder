@import "UIBuilderConstants.j"
@import "UIBuilderConstants.j"
@class UIElementView

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
    return [super persistentProperties].concat(["textAlign"]);
}

+ (CPDictionary)defaultValues
{
    return {
        value: "Label",
        textAlign: "left"
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [super propertyTypes];
    [types setObject:UIBString forKey:@"value"];
    [types setObject:UIBEnumeration forKey:@"textAlign"];
    return types;
}

+ (CPDictionary)propertyEnumerations
{
    return {
        textAlign: ["left", "center", "right"]
    };
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
    var data = [self dataObject];
    var value = [data valueForKey:@"value"];
    var textAlign = [data valueForKey:@"textAlign"] || "left";

    if (value) {
        var valueSize = [value sizeWithAttributes:_stringAttributes];
        var x;

        if (textAlign === "center") {
            x = (bounds.size.width - valueSize.width) / 2;
        } else if (textAlign === "right") {
            x = bounds.size.width - valueSize.width;
        } else { // left
            x = 0;
        }

        [value drawAtPoint:CGPointMake(x, (bounds.size.height - valueSize.height) / 2) withAttributes:_stringAttributes];
    }
}

@end

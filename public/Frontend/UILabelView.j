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
    var defaults = [[super defaultValues] mutableCopy];
    [defaults setValue:@"Label" forKey:@"value"];
    [defaults setValue:@"left" forKey:@"textAlign"];
    [defaults setValue:@"min" forKey:@"halign"];
    [defaults setValue:@"min" forKey:@"valign"];
    return defaults;
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types setObject:UIBEnumeration forKey:@"textAlign"];
    return types;
}

+ (CPDictionary)propertyEnumerations
{
    var enums = [[super propertyEnumerations] copy];
    [enums setObject:["left", "center", "right"] forKey:@"textAlign"];

    return enums;
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
    console.log("UILabelView drawSkeleton: for " + [self class]);
    var bounds = [self bounds];
    var data = [self dataObject];
    var value = [data valueForKey:@"value"];
    var textAlign = [data valueForKey:@"textAlign"] || "left";

    console.log("UILabelView drawSkeleton: value is " + value);

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

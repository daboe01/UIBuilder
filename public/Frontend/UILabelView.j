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
    var defaults = [[super defaultValues] copy];
    [defaults setValue:@"Label" forKey:@"value"];
    [defaults setValue:@"left" forKey:@"textAlign"];
    [defaults setValue:@"min" forKey:@"halign"];
    [defaults setValue:@"min" forKey:@"valign"];
    [defaults setValue:@"takeStringValueFrom:, takeIntegerValueFrom:" forKey:@"actions"];
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

    if (self)
    {
        [self sizeToFit];
    }
    
    return self;
}

- (void)sizeToFit
{
    var value = [self value] || @"";
    var valueSize = [value sizeWithFont:[CPFont boldSystemFontOfSize:12]];
    var newSize = CGSizeMake(valueSize.width + 10, valueSize.height + 10);
    [self setFrameSize:newSize];
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

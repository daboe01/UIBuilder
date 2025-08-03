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
    return [super persistentProperties].concat(["horizontalTextAlign", "verticalTextAlign", "color"]);
}

+ (CPDictionary)defaultValues
{
    var defaults = [[super defaultValues] copy];
    [defaults setValue:@"Label" forKey:@"value"];
    [defaults setValue:@"left" forKey:@"horizontalTextAlign"];
    [defaults setValue:@"center" forKey:@"verticalTextAlign"];
    [defaults setValue:@"min" forKey:@"halign"];
    [defaults setValue:@"min" forKey:@"valign"];
    [defaults setValue:@"#000000" forKey:@"color"];
    [defaults setValue:@"takeStringValueFrom:, takeIntegerValueFrom:" forKey:@"actions"];
    return defaults;
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types setObject:UIBEnumeration forKey:@"horizontalTextAlign"];
    [types setObject:UIBEnumeration forKey:@"verticalTextAlign"];
    [types setObject:UIBColor forKey:@"color"];
    return types;
}

+ (CPDictionary)propertyGroups
{
    var groups = [[super propertyGroups] copy];
    [groups setObject:UIBPropertyTabProperties forKey:@"horizontalTextAlign"];
    [groups setObject:UIBPropertyTabProperties forKey:@"verticalTextAlign"];
    return groups;
}

+ (CPDictionary)propertyEnumerations
{
    var enums = [[super propertyEnumerations] copy];
    [enums setObject:["left", "center", "right"] forKey:@"horizontalTextAlign"];
    [enums setObject:["top", "center", "bottom"] forKey:@"verticalTextAlign"];

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
    var horizontalTextAlign = [data valueForKey:@"horizontalTextAlign"] || "left";
    var verticalTextAlign = [data valueForKey:@"verticalTextAlign"] || "center";
    var color = [data valueForKey:@"color"] || "#000000";

    if (value) {
        var valueSize = [value sizeWithAttributes:_stringAttributes];
        var x, y;

        if (horizontalTextAlign === "center") {
            x = (bounds.size.width - valueSize.width) / 2;
        } else if (horizontalTextAlign === "right") {
            x = bounds.size.width - valueSize.width;
        } else { // left
            x = 0;
        }

        if (verticalTextAlign === "center") {
            y = (bounds.size.height - valueSize.height) / 2;
        } else if (verticalTextAlign === "bottom") {
            y = bounds.size.height - valueSize.height;
        } else { // top
            y = 0;
        }
        
        var attributes = @{
            CPForegroundColorAttributeName:[CPColor colorWithHexString:[color substringFromIndex:1]]
        };

        [value drawAtPoint:CGPointMake(x, y) withAttributes:attributes];
    }
}

@end

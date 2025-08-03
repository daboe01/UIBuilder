@class UIElementView

@implementation UITextViewView : UIElementView

+ (void)initialize
{
    if (self === [UITextViewView class])
    {
        [UIElementView registerViewClass:self forElementType:@"textView"];
    }
}

+ (CPArray)persistentProperties
{
    return [super persistentProperties].concat(["value", "editable", "richText"]);
}

+ (CPDictionary)defaultValues
{
    return {
        value: "Text View",
        editable: YES,
        richText: YES
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [super propertyTypes];
    [types setObject:UIBString forKey:@"value"];
    [types setObject:UIBBoolean forKey:@"editable"];
    [types setObject:UIBBoolean forKey:@"richText"];
    return types;
}

+ (CPDictionary)propertyGroups
{
    var groups = [[super propertyGroups] copy];
    [groups setObject:UIBPropertyTabProperties forKey:@"value"];
    [groups setObject:UIBPropertyTabProperties forKey:@"editable"];
    [groups setObject:UIBPropertyTabProperties forKey:@"richText"];
    return groups;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(200, 100)];
        }
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    [[CPColor whiteColor] setFill];
    [CPBezierPath fillRect:bounds];
    [[CPColor blackColor] setStroke];
    [CPBezierPath strokeRect:bounds];

    var value = [[self dataObject] valueForKey:@"value"];
    if (value) {
        [value drawInRect:CGRectInset(bounds, 5, 5) withAttributes:_stringAttributes];
    }
}

@end
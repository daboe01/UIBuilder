@class UIElementView

@implementation UICheckBoxView : UIElementView

+ (void)initialize
{
    if (self === [UICheckBoxView class])
    {
        [UIElementView registerViewClass:self forElementType:@"checkBox"];
    }
}

+ (CPArray)persistentProperties
{
    return [super persistentProperties].concat(["title"]);
}

+ (CPDictionary)defaultValues
{
    return @{
        "title": "Checkbox"
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types setObject:UIBString forKey:@"title"];
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
    var boxRect = CGRectMake(0, (bounds.size.height - 16) / 2, 16, 16);

    [[CPColor whiteColor] setFill];
    [CPBezierPath fillRect:boxRect];
    [[CPColor blackColor] setStroke];
    [CPBezierPath strokeRect:boxRect];

    var title = [[self dataObject] valueForKey:@"title"];
    if (title) {
        var titleSize = [title sizeWithAttributes:_stringAttributes];
        [title drawAtPoint:CGPointMake(20, (bounds.size.height - titleSize.height) / 2) withAttributes:_stringAttributes];
    }
}

@end

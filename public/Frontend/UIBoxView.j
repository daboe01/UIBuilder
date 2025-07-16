@import "UIElementView.j"

@implementation UIBoxView : UIElementView

+ (void)initialize
{
    if (self === [UIBoxView class])
    {
        [UIElementView registerViewClass:self forElementType:@"box"];
    }
}

+ (CPArray)persistentProperties
{
    return [super persistentProperties].concat(["title", "hasBorder"]);
}

+ (CPDictionary)defaultValues
{
    return {
        title: "Box",
        hasBorder: YES
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [super propertyTypes];
    [types setObject:UIBString forKey:@"title"];
    [types setObject:UIBBoolean forKey:@"hasBorder"];
    return types;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        if (CGRectIsEmpty(aRect)) {
            [self setFrameSize:CGSizeMake(200, 100)];
        }
        _isContainer = YES;
    }
    return self;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    var hasBorder = [[self dataObject] valueForKey:@"hasBorder"];

    if (hasBorder) {
        [[CPColor controlColor] setFill];
        [CPBezierPath fillRect:bounds];
        [[CPColor darkGrayColor] setStroke];
        [CPBezierPath strokeRect:bounds];
    }

    var title = [[self dataObject] valueForKey:@"title"];
    if (title) {
        var titleSize = [title sizeWithAttributes:_stringAttributes];
        [title drawAtPoint:CGPointMake(10, 5) withAttributes:_stringAttributes];
    }
}

@end
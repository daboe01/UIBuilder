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
                "value": true,
                "title": "Checkbox"
            };
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types setObject:UIBString forKey:@"title"];
    [types setObject:UIBBoolean forKey:@"value"];
    return types;
}

+ (CPDictionary)propertyGroups
{
    var groups = [[super propertyGroups] copy];
    [groups setObject:UIBPropertyTabProperties forKey:@"title"];
    return groups;
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

    // Draw the box
    [[CPColor whiteColor] setFill];
    [CPBezierPath fillRect:boxRect];
    [[CPColor blackColor] setStroke];
    [CPBezierPath strokeRect:boxRect];

    var value = [[self dataObject] valueForKey:@"value"];
    if (value) {
        // Draw the checkmark
        var checkPath = [CPBezierPath bezierPath];
        [checkPath moveToPoint:CGPointMake(boxRect.origin.x + 4, boxRect.origin.y + 8)];
        [checkPath lineToPoint:CGPointMake(boxRect.origin.x + 7, boxRect.origin.y + 11)];
        [checkPath lineToPoint:CGPointMake(boxRect.origin.x + 12, boxRect.origin.y + 6)];
        [checkPath setLineWidth:2.0];
        [[CPColor blackColor] setStroke];
        [checkPath stroke];
    }

    var title = [[self dataObject] valueForKey:@"title"];
    if (title) {
        var titleSize = [title sizeWithAttributes:_stringAttributes];
        [title drawAtPoint:CGPointMake(20, (bounds.size.height - titleSize.height) / 2) withAttributes:_stringAttributes];
    }
}

@end

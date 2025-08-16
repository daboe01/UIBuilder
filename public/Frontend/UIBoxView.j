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
    return @{
        "title": "Box",
        "hasBorder": YES
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types setObject:UIBString forKey:@"title"];
    [types setObject:UIBBoolean forKey:@"hasBorder"];
    return types;
}

+ (CPDictionary)propertyGroups
{
    var groups = [[super propertyGroups] copy];
    [groups setObject:UIBPropertyTabProperties forKey:@"title"];
    [groups setObject:UIBPropertyTabProperties forKey:@"hasBorder"];
    return groups;
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

- (void)sizeToFit
{
    var subviews = [self subviews];
    var count = [subviews count];
    if (count === 0) {
        [self setFrameSize:CGSizeMake(20, 20)]; // Minimal size for an empty box
        return;
    }

    const PADDING = 10;
    var boundingBox = CGRectZero();

    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        if (i === 0) {
            boundingBox = [subview frame];
        } else {
            boundingBox = CGRectUnion(boundingBox, [subview frame]);
        }
    }

    var newWidth = boundingBox.size.width + (2 * PADDING);
    var newHeight = boundingBox.size.height + (2 * PADDING);

    // Adjust children's origins to be relative to the new padded box
    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var frame = [subview frame];
        frame.origin.x = frame.origin.x - boundingBox.origin.x + PADDING;
        frame.origin.y = frame.origin.y - boundingBox.origin.y + PADDING;
        [subview setFrameOrigin:frame.origin];
    }

    [self setFrameSize:CGSizeMake(newWidth, newHeight)];
    var data = [self dataObject];
    [data setValue:newWidth forKey:@"width"];
    [data setValue:newHeight forKey:@"height"];
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

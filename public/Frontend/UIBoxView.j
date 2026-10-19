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

- (float)_titleHeight
{
    var title = [[self dataObject] valueForKey:@"title"];
    return (title && String(title).length) ? 18 : 0;
}

// A box holds its content view below the title, like CPBox.
- (CGRect)contentRect
{
    var bounds = [self bounds],
        inset = [[self dataObject] valueForKey:@"hasBorder"] ? 6 : 2,
        titleHeight = [self _titleHeight];

    return CGRectMake(inset, titleHeight + inset, MAX(0, bounds.size.width - 2 * inset), MAX(0, bounds.size.height - titleHeight - 2 * inset));
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    UIBLayoutStack([self subviews], [self contentRect], YES);
}

- (CGSize)intrinsicContentSize
{
    var size = UIBFittingStackSize([self subviews], YES),
        inset = [[self dataObject] valueForKey:@"hasBorder"] ? 6 : 2;

    if (size.width === 0 && size.height === 0)
        return CGSizeMake(120, 60);

    return CGSizeMake(size.width + 2 * inset, size.height + [self _titleHeight] + 2 * inset);
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    var hasBorder = [[self dataObject] valueForKey:@"hasBorder"];
    var titleHeight = [self _titleHeight];

    if (hasBorder) {
        var frameRect = CGRectMake(0.5, titleHeight ? titleHeight / 2 : 0.5, bounds.size.width - 1, bounds.size.height - (titleHeight ? titleHeight / 2 : 0) - 1);
        var path = [CPBezierPath bezierPathWithRoundedRect:frameRect radius:4];
        [[CPColor colorWithCalibratedWhite:0.0 alpha:0.04] setFill];
        [path fill];
        [[CPColor colorWithCalibratedWhite:0.55 alpha:1.0] setStroke];
        [path stroke];
    }
    else
    {
        var dashed = [CPBezierPath bezierPathWithRect:CGRectInset(bounds, 0.5, 0.5)];
        [[[CPColor grayColor] colorWithAlphaComponent:0.4] setStroke];
        [dashed setLineDash:[3,3] count:2 phase:0];
        [dashed stroke];
    }

    var title = [[self dataObject] valueForKey:@"title"];
    if (titleHeight) {
        var titleSize = [title sizeWithFont:[CPFont boldSystemFontOfSize:11]];
        [[CPColor colorWithCalibratedWhite:0.93 alpha:1.0] setFill];
        [CPBezierPath fillRect:CGRectMake(8, 0, titleSize.width + 8, titleHeight)];
        [title drawAtPoint:CGPointMake(12, 2) withAttributes:@{ CPFontAttributeName: [CPFont boldSystemFontOfSize:11], CPForegroundColorAttributeName: [CPColor darkGrayColor] }];
    }
}

@end

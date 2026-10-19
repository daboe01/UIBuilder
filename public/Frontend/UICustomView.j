//
//  UICustomView.j
//  Any Cappusance element the builder has no special support for
//  (ButtonBar, collectionView, segmentedControl, your own classes, ...).
//  Tag, attributes and children are kept exactly as imported.
//

@import "UIElementView.j"

@implementation UICustomView : UIElementView

+ (CPArray)persistentProperties
{
    return ["markupTag", "halign", "valign", "width", "height"];
}

+ (CPDictionary)defaultValues
{
    return @{ "markupTag": "view", "halign": "min", "valign": "min", "width": 120, "height": 32 };
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types setObject:UIBString forKey:@"markupTag"];
    return types;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self && CGRectIsEmpty(aRect))
        [self setFrameSize:CGSizeMake(120, 32)];
    return self;
}

- (CGSize)intrinsicContentSize
{
    var data = [self dataObject],
        label = "<" + ([data valueForKey:@"markupTag"] || "view") + ">",
        width = [label sizeWithFont:[CPFont systemFontOfSize:11]].width + 16,
        size = [super intrinsicContentSize];

    // Unknown elements without a size get a readable placeholder.
    if (![self hasExplicitSizeForKey:@"width"])
        size.width = MAX(width, 60);
    if (![self hasExplicitSizeForKey:@"height"])
        size.height = 26;

    return size;
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds],
        data = [self dataObject],
        path = [CPBezierPath bezierPathWithRoundedRect:CGRectInset(bounds, 0.5, 0.5) radius:3];

    [[CPColor colorWithCalibratedRed:0.55 green:0.35 blue:0.8 alpha:0.08] setFill];
    [path fill];
    [[CPColor colorWithCalibratedRed:0.55 green:0.35 blue:0.8 alpha:0.7] setStroke];
    [path setLineDash:[4,2] count:2 phase:0];
    [path stroke];

    var label = "<" + ([data valueForKey:@"markupTag"] || "view") + ">",
        identifier = [data valueForKey:@"identifier"];

    if (identifier && bounds.size.height > 30)
        label += "  #" + identifier;

    [label drawAtPoint:CGPointMake(6, MAX(2, (bounds.size.height - 14) / 2)) withAttributes:@{ CPFontAttributeName: [CPFont systemFontOfSize:11], CPForegroundColorAttributeName: [CPColor colorWithCalibratedRed:0.4 green:0.2 blue:0.6 alpha:1.0] }];
}

@end

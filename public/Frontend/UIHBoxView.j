
@class UIElementView;

@implementation UIHBoxView : UIElementView
{
    BOOL _isDropTarget;
}

+ (CPArray)persistentProperties
{
    var properties = [CPMutableSet setWithArray:[super persistentProperties]];
    [properties minusSet:[CPSet setWithArray:['value']]];
    return [properties allObjects];
}

+ (CPDictionary)defaultValues
{
    return @{
        "width": 200,
        "height": 30,
        "halign": "expand",
        "valign": "min"
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types removeObjectForKey:@"value"];
    return types;
}

+ (CPDictionary)propertyGroups
{
    var groups = [[super propertyGroups] copy];
    [groups removeObjectForKey:@"value"];
    return groups;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        [self setBackgroundColor:[CPColor clearColor]];
        [self setClipsToBounds:NO];
        _isContainer = YES;
    }
    return self;
}

- (void)addSubview:(CPView)aView
{
    [super addSubview:aView];
    [self invalidateLayoutUpwards];
}

// Children are laid out left to right (see UIBLayoutStack).
- (void)layoutSubviews
{
    [super layoutSubviews];
    UIBLayoutStack([self subviews], CGRectInset([self bounds], UIBStackPadding, UIBStackPadding), NO);
}

- (CGSize)intrinsicContentSize
{
    var size = UIBFittingStackSize([self subviews], NO);
    return CGSizeMake(MAX(20, size.width + 2 * UIBStackPadding), MAX(20, size.height + 2 * UIBStackPadding));
}

- (void)drawRect:(CGRect)rect
{
    [self drawSkeleton:rect];

    if ([self isSelected])
    {
        UIBFillStroke([CPBezierPath bezierPathWithRect:CGRectInset([self bounds], 1, 1)], nil, UIBTheme("accent"), 2);
        [self drawHandles];
    }
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds],
        data = [self dataObject],
        isRoot = !!NO,
        path = [CPBezierPath bezierPathWithRect:CGRectInset(bounds, 0.5, 0.5)];

    if (_isDropTarget)
    {
        UIBFillStroke(path, UIBTheme("accentSoft"), UIBTheme("accent"), 2);
        return;
    }

    // Boxes are only hinted at: a fine dashed outline (fainter for a window's root box).
    [path setLineDash:[3, 3] count:2 phase:0];
    UIBFillStroke(path, nil, UIBTheme(isRoot ? "rootLine" : "containerLine"), 1);
}

- (void)setAsDropTarget:(BOOL)isDropTarget
{
    if (_isDropTarget !== isDropTarget)
    {
        _isDropTarget = isDropTarget;
        [self setNeedsDisplay:YES];
    }
}

@end

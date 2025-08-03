@class UIElementView;

@implementation UIHSpaceView : UIElementView
{
}


+ (CPArray)persistentProperties
{
    var properties = [CPMutableSet setWithArray:[super persistentProperties]];
    [properties minusSet:[CPSet setWithArray:['value', 'valign', 'height']]];
    return [properties allObjects];
}

+ (CPDictionary)defaultValues
{
    return @{
        "width": 100,
        "halign": "min"
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types removeObjectForKey:@"value"];
    [types removeObjectForKey:@"valign"];
    return types;
}

+ (CPDictionary)propertyGroups
{
    var groups = [[super propertyGroups] copy];
    [groups removeObjectForKey:@"value"];
    [groups removeObjectForKey:@"valign"];
    return groups;
}

+ (CPDictionary)propertyEnumerations
{
    return @{
        "halign": ["min", "expand"]
    };
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];

    if (self)
    {
        [self setBackgroundColor:[CPColor clearColor]];
        [self setClipsToBounds:NO];
    }

    return self;
}

- (void)drawRect:(CGRect)rect
{
    // Don't call super, we want a completely custom look.
    [self drawSkeleton:rect];
}


- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    var midY = CGRectGetMidY(bounds);

    // Draw a simple horizontal line
    var path = [CPBezierPath bezierPath];
    [path moveToPoint:CGPointMake(bounds.origin.x, midY)];
    [path lineToPoint:CGPointMake(bounds.origin.x + bounds.size.width, midY)];

    [[CPColor grayColor] setStroke];
    [path setLineWidth:[self isSelected] ? 3.0 : 1.0];
    [path setLineDash:[2,2] count:2 phase:0];
    [path stroke];
}

- (void)observeValueForKeyPath:(CPString)keyPath ofObject:(id)object change:(CPDictionary)change context:(id)context
{
    if ([keyPath isEqualToString:@"width"])
    {
        var frame = [self frame];
        frame.size.width = [[change objectForKey:CPKeyValueChangeNewKey] floatValue];
        [self setFrame:frame];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


- (void)setWidth:(float)aFloat
{
    if (aFloat !== [self width])
    {
        [super setWidth:aFloat];
        [[self dataObject] setValue:aFloat forKey:@"width"];
    }
}



@end

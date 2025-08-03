@class UIElementView;

@implementation UIVSpaceView : UIElementView
{
}

+ (CPArray)persistentProperties
{
    var properties = [CPMutableSet setWithArray:[super persistentProperties]];
    [properties minusSet:[CPSet setWithArray:['value', 'halign', 'width']]];
    return [properties allObjects];
}

+ (CPDictionary)defaultValues
{
    return @{
        "height": 100,
        "valign": "min"
    };
}

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types removeObjectForKey:@"value"];
    [types removeObjectForKey:@"halign"];
    return types;
}

+ (CPDictionary)propertyGroups
{
    var groups = [[super propertyGroups] copy];
    [groups removeObjectForKey:@"value"];
    [groups removeObjectForKey:@"halign"];
    return groups;
}

+ (CPDictionary)propertyEnumerations
{
    return @{
        "valign": ["min", "expand"]
    };
}

+ (CPDictionary)propertyEnumerations
{
    return @{
        "valign": ["min", "expand"]
    };
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
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
    var midX = CGRectGetMidX(bounds);

    // Draw a simple vertical line
    var path = [CPBezierPath bezierPath];
    [path moveToPoint:CGPointMake(midX, bounds.origin.y)];
    [path lineToPoint:CGPointMake(midX, bounds.origin.y + bounds.size.height)];

    [[CPColor grayColor] setStroke];
    [path setLineWidth:[self isSelected] ? 3.0 : 1.0];
    [path setLineDash:[2,2] count:2 phase:0];
    [path stroke];
}

- (void)observeValueForKeyPath:(CPString)keyPath ofObject:(id)object change:(CPDictionary)change context:(id)context
{
    if ([keyPath isEqualToString:@"height"])
    {
        var frame = [self frame];
        frame.size.height = [[change objectForKey:CPKeyValueChangeNewKey] floatValue];
        [self setFrame:frame];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


- (void)setHeight:(float)aFloat
{
    if (aFloat !== [self height])
    {
        [super setHeight:aFloat];
        [[self dataObject] setValue:aFloat forKey:@"height"];
    }
}



@end

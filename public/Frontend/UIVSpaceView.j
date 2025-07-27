@class UIElementView;

@implementation UIVSpaceView : UIElementView
{
}

+ (CPDictionary)defaultValues
{
    return @{
        "halign": "min",
        "valign": "min"
    };
}

+ (CPDictionary)propertyTypes
{
    return @{
        "halign": UIBEnumeration,
        "valign": UIBEnumeration,
    };
}

+ (CPDictionary)propertyEnumerations
{
    return @{
        "halign": ["min", "expand"],
        "valign": ["min", "expand"]
    };
}

+ (CPDictionary)propertyEnumerations
{
    return @{
                "halign": ["min", "expand"],
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

    // We still want to see selection handles if it's selected.
    if ([self isSelected])
    {
        [self drawHandles];
    }
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
    [path setLineWidth:1.0];
    [path setLineDash:[2,2] count:2 phase:0];
    [path stroke];
}

@end

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
        "height": 50,
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
    [self setNeedsLayout:YES];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    var subviews = [self subviews];
    var count = [subviews count];
    if (count === 0) return;

    var bounds = [self bounds];
    var totalMinWidth = 0;
    var maxHeight = 0;
    var expandableChildren = 0;

    // First pass: Calculate total minimum width and max height.
    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var data = [subview dataObject];
        var halign = [data objectForKey:@"halign"];

        if (halign !== "expand")
        {
            totalMinWidth += [[subview dataObject] valueForKey:@"width"];
        }
        else
        {
            expandableChildren++;
        }
        maxHeight = MAX(maxHeight, [[subview dataObject] valueForKey:@"height"]);
    }

    // Determine the container's new size.
    var newWidth = totalMinWidth;
    var newHeight = maxHeight;
    var currentFrame = [self frame];

    if (currentFrame.size.width > totalMinWidth)
    {
        newWidth = currentFrame.size.width;
    }
    else
    {
        [[self dataObject] setValue:newWidth forKey:@"width"];
    }

    if (currentFrame.size.height !== newHeight)
    {
        [[self dataObject] setValue:newHeight forKey:@"height"];
    }

    var flexibleWidth = 0;
    if (expandableChildren > 0)
    {
        var remainingSpace = newWidth - totalMinWidth;
        flexibleWidth = (remainingSpace > 0) ? (remainingSpace / expandableChildren) : 0;
    }

    var currentX = 0;

    // Second pass: Set the frames.
    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var frame = [subview frame];
        var frameHeight = frame.size.height;
        var frameWidth = 0;
        var halign = [[subview dataObject] valueForKey:@"halign"];

        if (halign === "expand")
        {
            frameWidth = flexibleWidth;
        }
        else // "min"
        {
            frameWidth = [[subview dataObject] valueForKey:@"width"];
        }
        
        var valign = [[subview dataObject] valueForKey:@"valign"];
        if (valign === "expand")
        {
            frameHeight = newHeight;
        }

        // Center vertically
        var y = (newHeight - frameHeight) / 2.0;

        [subview setFrame:CGRectMake(currentX, y, frameWidth, frameHeight)];
        currentX += frameWidth;
    }
}

- (void)drawRect:(CGRect)rect
{
    [self drawSkeleton:rect];

    if ([self isSelected])
    {
        [self drawHandles];
    }
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];
    var path = [CPBezierPath bezierPathWithRect:bounds];
    [[CPColor grayColor] setStroke];
    [path setLineWidth:[self isSelected] ? 3.0 : 1.0];
    [path setLineDash:[2,2] count:2 phase:0];
    [path stroke];

    if (_isDropTarget)
    {
        [[[CPColor yellowColor] colorWithAlphaComponent:0.5] setFill];
        [CPBezierPath fillRect:bounds];
    }
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


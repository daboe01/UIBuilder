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

    const PADDING = 5;
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

    // Determine the container's new size, including padding.
    var requiredWidth = totalMinWidth + (2 * PADDING);
    var requiredHeight = maxHeight + (2 * PADDING);
    var containerWidth = [self frame].size.width;
    var containerHeight = [self frame].size.height;

    if (containerWidth < requiredWidth)
    {
        containerWidth = requiredWidth;
        [[self dataObject] setValue:containerWidth forKey:@"width"];
    }
    if (containerHeight < requiredHeight)
    {
        containerHeight = requiredHeight;
        [[self dataObject] setValue:containerHeight forKey:@"height"];
    }

    // Calculate layout for children within the padded area.
    var layoutAreaWidth = containerWidth - (2 * PADDING);
    var layoutAreaHeight = containerHeight - (2 * PADDING);

    var flexibleWidth = 0;
    if (expandableChildren > 0)
    {
        var remainingSpace = layoutAreaWidth - totalMinWidth;
        flexibleWidth = (remainingSpace > 0) ? (remainingSpace / expandableChildren) : 0;
    }

    var currentX = PADDING;
    var layoutAreaY = PADDING;

    // Second pass: Set the frames.
    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var frameHeight = [[subview dataObject] valueForKey:@"height"];
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
            frameHeight = layoutAreaHeight;
        }

        // Center vertically within the padded layout area
        var y = layoutAreaY + Math.max(0, (layoutAreaHeight - frameHeight) / 2.0);

        [subview setFrame:CGRectMake(currentX, y, frameWidth, frameHeight)];
        currentX += frameWidth;
    }
}

- (void)sizeToFit
{
    var subviews = [self subviews];
    var count = [subviews count];
    const PADDING = 5;
    const MIN_EXPANDABLE_WIDTH = 10;

    if (count === 0) {
        [self setFrameSize:CGSizeMake(PADDING * 2, PADDING * 2)];
        return;
    }

    var totalMinWidth = 0;
    var maxHeight = 0;
    var expandableChildren = 0;

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
        maxHeight = Math.max(maxHeight, [[subview dataObject] valueForKey:@"height"]);
    }

    // Calculate the total width required
    var newWidth = totalMinWidth + (expandableChildren * MIN_EXPANDABLE_WIDTH);
    
    // Add padding between elements
    if (count > 1) {
        newWidth += (count - 1) * PADDING;
    }

    // Add padding around the container
    newWidth += (2 * PADDING);
    var newHeight = maxHeight + (2 * PADDING);

    var data = [self dataObject];
    [data setValue:newWidth forKey:@"width"];
    [data setValue:newHeight forKey:@"height"];

    [self setNeedsLayout:YES];
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


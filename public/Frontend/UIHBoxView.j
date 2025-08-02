@class UIElementView;

@implementation UIHBoxView : UIElementView
{
    BOOL _isDropTarget;
}

+ (CPArray)persistentProperties
{
    return [super persistentProperties].filter(p => p !== 'value').concat(["width", "height"]);
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
    return @{
        "width": UIBNumber,
        "height": UIBNumber,
        "halign": UIBEnumeration,
        "valign": UIBEnumeration
    };
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

    console.log("--- UIHBoxView layoutSubviews ---");
    var bounds = [self bounds];
    console.log("HBox bounds:", bounds.size.width);
    var totalFixedWidth = 0;
    var expandableChildren = 0;
    var expandableSpacer = nil;

    // First pass: Calculate total width of fixed elements and find expandable ones.
    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var data = [subview dataObject];
        var halign = [data objectForKey:@"halign"];
        var subviewWidth = [subview frame].size.width;
        console.log("Subview", i, [subview class], "halign:", halign, "width:", subviewWidth);
        console.log("  -> Data object:", data);

        if ([subview isKindOfClass:[UIHSpaceView class]] && halign === "expand")
        {
            expandableSpacer = subview;
            console.log("  -> Found expandable spacer");
        }
        else if (halign === "expand")
        {
            expandableChildren++;
        }
        else // "min"
        {
            totalFixedWidth += subviewWidth;
        }
    }

    console.log("Total fixed width:", totalFixedWidth);
    console.log("Expandable children:", expandableChildren);

    var flexibleWidth = 0;
    var remainingSpace = bounds.size.width - totalFixedWidth;
    console.log("Remaining space for expansion:", remainingSpace);

    if (expandableSpacer)
    {
        flexibleWidth = remainingSpace > 0 ? remainingSpace : 0;
        console.log("  -> Assigning", flexibleWidth, "to expandable spacer");
        var frame = [expandableSpacer frame];
        frame.size.width = flexibleWidth;
        [expandableSpacer setFrame:frame];
    }
    else if (expandableChildren > 0)
    {
        flexibleWidth = (remainingSpace > 0) ? (remainingSpace / expandableChildren) : 0;
        console.log("  -> Assigning", flexibleWidth, "to each of", expandableChildren, "expandable children");
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

        if (subview == expandableSpacer)
        {
            frameWidth = [subview frame].size.width;
        }
        else if (halign === "expand")
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
            frameHeight = bounds.size.height;
        }

        // Center vertically
        var y = (bounds.size.height - frameHeight) / 2.0;

        console.log("Setting frame for subview", i, ": x=", currentX, "y=", y, "w=", frameWidth, "h=", frameHeight);
        [subview setFrame:CGRectMake(currentX, y, frameWidth, frameHeight)];
        currentX += frameWidth;
    }
    console.log("---------------------------------");
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
    [path setLineWidth:1.0];
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


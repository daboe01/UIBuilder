@class UIElementView;

@implementation UIHBoxView : UIElementView
{
    BOOL _isDropTarget;
}

+ (CPDictionary)defaultValues
{
    return {
        value: "HBox"
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

    var bounds = [self bounds];
    var totalMinWidth = 0;
    var expandableSpaces = 0;
    var regularViews = 0;

    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        if ([subview isKindOfClass:[UIHSpaceView class]])
        {
            if ([[subview dataObject] valueForKey:@"size"] === "min")
                totalMinWidth += [[subview dataObject] valueForKey:@"width"];
            else
                expandableSpaces++;
        }
        else
        {
            regularViews++;
        }
    }

    var flexibleWidth = 0;
    if (regularViews + expandableSpaces > 0)
        flexibleWidth = (bounds.size.width - totalMinWidth) / (regularViews + expandableSpaces);

    if (flexibleWidth < 0)
        flexibleWidth = 0;

    var currentX = 0;

    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var frameWidth = 0;

        if ([subview isKindOfClass:[UIHSpaceView class]])
        {
            if ([[subview dataObject] valueForKey:@"size"] === "min")
                frameWidth = [[subview dataObject] valueForKey:@"width"];
            else
                frameWidth = flexibleWidth;
        }
        else
        {
            frameWidth = flexibleWidth;
        }

        [subview setFrame:CGRectMake(currentX, 0, frameWidth, bounds.size.height)];
        currentX += frameWidth;
    }
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    [self drawSkeleton:rect];
}

- (void)drawSkeleton:(CGRect)rect
{
    var layer = [self layer];
    [layer setBorderColor:[[CPColor grayColor] CGColor]];
    [layer setBorderWidth:1.0];
    [layer setLineDashPattern:[2,2]];

    if (_isDropTarget)
    {
        [[[CPColor yellowColor] colorWithAlphaComponent:0.5] setFill];
        [CPBezierPath fillRect:[self bounds]];
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


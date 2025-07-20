@class UIElementView

@implementation UIVBoxView : UIElementView
{
}

+ (CPDictionary)defaultValues
{
    return {
        value: "VBox"
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
    var totalMinHeight = 0;
    var expandableSpaces = 0;
    var regularViews = 0;

    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        if ([subview isKindOfClass:[UIVSpaceView class]])
        {
            if ([[subview dataObject] valueForKey:@"size"] === "min")
                totalMinHeight += [[subview dataObject] valueForKey:@"height"];
            else
                expandableSpaces++;
        }
        else
        {
            regularViews++;
        }
    }

    var flexibleHeight = 0;
    if (regularViews + expandableSpaces > 0)
        flexibleHeight = (bounds.size.height - totalMinHeight) / (regularViews + expandableSpaces);

    if (flexibleHeight < 0)
        flexibleHeight = 0;

    var currentY = 0;

    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var frameHeight = 0;

        if ([subview isKindOfClass:[UIVSpaceView class]])
        {
            if ([[subview dataObject] valueForKey:@"size"] === "min")
                frameHeight = [[subview dataObject] valueForKey:@"height"];
            else
                frameHeight = flexibleHeight;
        }
        else
        {
            frameHeight = flexibleHeight;
        }

        [subview setFrame:CGRectMake(0, currentY, bounds.size.width, frameHeight)];
        currentY += frameHeight;
    }
}

- (void)drawSkeleton:(CGRect)rect
{
    var layer = [self layer];
    [layer setBorderColor:[[CPColor grayColor] CGColor]];
    [layer setBorderWidth:1.0];
    [layer setLineDashPattern:[2,2]];
}

@end


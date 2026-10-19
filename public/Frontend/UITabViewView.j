//
//  UITabViewView.j
//  Tab views (<tabView>) and their items (<tabViewItem>). Only the selected
//  item is shown on the canvas; click a tab to switch.
//

@import "UIElementView.j"
@import "UIVBoxView.j"

var UIBTabStripHeight = 24.0;

@implementation UITabViewView : UIElementView

+ (CPArray)persistentProperties
{
    return [super persistentProperties].concat(["tabViewType"]);
}

+ (CPDictionary)defaultValues
{
    return @{ "tabViewType": "topBezel", "halign": "expand", "valign": "expand" };
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self)
    {
        if (CGRectIsEmpty(aRect))
            [self setFrameSize:CGSizeMake(300, 200)];
        _isContainer = YES;
    }
    return self;
}

- (CPArray)_itemViews
{
    var result = [], subviews = [self subviews];
    for (var i = 0; i < subviews.length; i++)
        if ([subviews[i] isKindOfClass:[UIElementView class]])
            result.push(subviews[i]);
    return result;
}

- (int)selectedTabIndex
{
    var count = [self _itemViews].length,
        index = Number([[self dataObject] valueForKey:@"selectedTabIndex"]) || 0;
    return count ? MAX(0, MIN(index, count - 1)) : -1;
}

- (CGRect)contentRect
{
    var bounds = [self bounds];
    return CGRectMake(4, UIBTabStripHeight + 4, MAX(0, bounds.size.width - 8), MAX(0, bounds.size.height - UIBTabStripHeight - 8));
}

- (void)addSubview:(CPView)aView
{
    [super addSubview:aView];
    [self setNeedsLayout:YES];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    var items = [self _itemViews],
        selected = [self selectedTabIndex],
        contentRect = [self contentRect];

    for (var i = 0; i < items.length; i++)
    {
        [items[i] setHidden:(i !== selected)];
        if (!CGRectEqualToRect([items[i] frame], contentRect))
            [items[i] setFrame:contentRect];
    }

    [self setNeedsDisplay:YES];
}

- (CGSize)intrinsicContentSize
{
    var items = [self _itemViews],
        width = 200, height = 100;

    for (var i = 0; i < items.length; i++)
    {
        var size = [items[i] intrinsicContentSize];
        width = MAX(width, size.width);
        height = MAX(height, size.height);
    }

    return CGSizeMake(width + 8, height + UIBTabStripHeight + 8);
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds],
        items = [self _itemViews],
        selected = [self selectedTabIndex];

    var body = [CPBezierPath bezierPathWithRoundedRect:CGRectMake(0.5, UIBTabStripHeight / 2, bounds.size.width - 1, bounds.size.height - UIBTabStripHeight / 2 - 1) radius:4];
    [[CPColor colorWithCalibratedWhite:0.0 alpha:0.03] setFill];
    [body fill];
    [[CPColor colorWithCalibratedWhite:0.6 alpha:1.0] setStroke];
    [body stroke];

    if (!items.length)
        return;

    var font = [CPFont systemFontOfSize:11],
        widths = [],
        total = 0;

    for (var i = 0; i < items.length; i++)
    {
        var title = [[items[i] dataObject] valueForKey:@"value"] || "Tab";
        widths.push([title sizeWithFont:font].width + 20);
        total += widths[i];
    }

    var x = MAX(4, (bounds.size.width - total) / 2);
    for (var i = 0; i < items.length; i++)
    {
        var tabRect = CGRectMake(x, 1, widths[i], UIBTabStripHeight - 2),
            path = [CPBezierPath bezierPathWithRoundedRect:tabRect radius:4];

        [(i === selected ? [CPColor alternateSelectedControlColor] : [CPColor controlColor]) setFill];
        [path fill];
        [[CPColor colorWithCalibratedWhite:0.6 alpha:1.0] setStroke];
        [path stroke];

        var title = [[items[i] dataObject] valueForKey:@"value"] || "Tab";
        [title drawAtPoint:CGPointMake(x + 10, 5) withAttributes:@{ CPFontAttributeName: font, CPForegroundColorAttributeName: (i === selected ? [CPColor whiteColor] : [CPColor blackColor]) }];

        items[i]._uibTabRect = tabRect;
        x += widths[i];
    }
}

- (void)mouseDown:(CPEvent)theEvent
{
    var localPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];

    if (localPoint.y <= UIBTabStripHeight && [self handleAtPoint:localPoint] == kUIElementNoHandle)
    {
        var items = [self _itemViews];
        for (var i = 0; i < items.length; i++)
        {
            if (items[i]._uibTabRect && CGRectContainsPoint(items[i]._uibTabRect, localPoint))
            {
                var data = [self dataObject];

                // Which tab is shown is canvas state, not a document change.
                UIBPerformWithoutUndo(function() { [data setValue:i forKey:@"selectedTabIndex"]; });
                [self setNeedsLayout:YES];

                // Select the item so the inspector shows its title.
                var canvas = [self canvas];
                [canvas deselectViews];
                [canvas selectView:items[i] state:YES];
                return;
            }
        }
    }

    [super mouseDown:theEvent];
}

@end


@implementation UITabViewItemView : UIVBoxView

+ (CPDictionary)defaultValues
{
    return @{ "value": "Tab", "halign": "expand", "valign": "expand" };
}

+ (CPArray)persistentProperties
{
    return ["value"];
}

- (void)drawSkeleton:(CGRect)rect
{
    // The tab view draws the frame; only show the drop highlight.
    if (_isDropTarget)
    {
        [[[CPColor yellowColor] colorWithAlphaComponent:0.5] setFill];
        [CPBezierPath fillRect:[self bounds]];
    }
}

// Clicking the empty area of a tab selects nothing (like a window's content).
- (void)mouseDown:(CPEvent)theEvent
{
    if ([self isSelected])
    {
        [super mouseDown:theEvent];
        return;
    }

    [[self canvas] deselectViews];
}

@end

//
//  UIBSkeletons.j
//  Content sizes and nicer canvas drawing for the element views. These are
//  categories so the individual view files stay small; this file is imported
//  after all view classes.
//

@import "UIElementView.j"

function UIBDrawText(aString, aPoint, aFont, aColor)
{
    [String(aString) drawAtPoint:aPoint withAttributes:@{ CPFontAttributeName: aFont, CPForegroundColorAttributeName: aColor }];
}

function UIBTextWidth(aString, aFont)
{
    return [String(aString || "") sizeWithFont:aFont].width;
}

var UIBControlFont = nil;

function UIBFont()
{
    if (!UIBControlFont)
        UIBControlFont = [CPFont systemFontOfSize:12];
    return UIBControlFont;
}


@implementation UILabelView (UIBContentSize)

- (CGSize)intrinsicContentSize
{
    var value = [[self dataObject] valueForKey:@"value"] || "";
    return CGSizeMake(MAX(10, UIBTextWidth(value, UIBFont()) + 6), 20);
}

- (void)sizeToFit
{
    [self setFrameSize:[self intrinsicContentSize]];
}

@end


@implementation UIButtonView (UIBContentSize)

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(MAX(40, UIBTextWidth([[self dataObject] valueForKey:@"value"], [CPFont boldSystemFontOfSize:12]) + 28), 24);
}

- (void)sizeToFit
{
    [self setFrameSize:[self intrinsicContentSize]];
}

@end


@implementation UICheckBoxView (UIBContentSize)

- (CGSize)intrinsicContentSize
{
    var title = [[self dataObject] valueForKey:@"title"] || "";
    return CGSizeMake(20 + (title.length ? UIBTextWidth(title, [CPFont boldSystemFontOfSize:12]) + 6 : 0), 20);
}

@end


@implementation UITextFieldView (UIBPlaceholder)

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = CGRectInset([self bounds], 1, 1),
        value = [[self dataObject] valueForKey:@"value"],
        data = [self dataObject];

    [[CPColor textBackgroundColor] setFill];
    [CPBezierPath fillRect:bounds];
    [[CPColor grayColor] setStroke];
    [CPBezierPath strokeRect:bounds];

    if (value !== nil && value !== undefined && String(value).length)
        UIBDrawText(value, CGPointMake(5, (bounds.size.height - 14) / 2), UIBFont(), [CPColor blackColor]);
    else
    {
        // Show what the field is bound to, or its kind.
        var extras = [data valueForKey:@"extraAttributes"] || {},
            hint = extras.valueBinding ? "⟶ " + String(extras.valueBinding).replace(/^#CPOwner\./, "") : ([data valueForKey:@"markupTag"] || [data valueForKey:@"type"]);
        UIBDrawText(hint, CGPointMake(5, (bounds.size.height - 14) / 2), [CPFont systemFontOfSize:11], [CPColor lightGrayColor]);
    }
}

@end


@implementation UIPopUpButtonView (UIBContentSize)

- (CGSize)intrinsicContentSize
{
    var items = UIBSplitList([[self dataObject] valueForKey:@"items"]),
        width = 60;

    for (var i = 0; i < items.length; i++)
        width = MAX(width, UIBTextWidth(items[i], UIBFont()) + 36);

    return CGSizeMake(width, 24);
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = CGRectInset([self bounds], 0.5, 0.5),
        path = [CPBezierPath bezierPathWithRoundedRect:bounds radius:4],
        items = UIBSplitList([[self dataObject] valueForKey:@"items"]);

    [[CPColor controlColor] setFill];
    [path fill];
    [[CPColor grayColor] setStroke];
    [path stroke];

    var extras = [[self dataObject] valueForKey:@"extraAttributes"] || {},
        title = items.length ? items[0] : (extras.itemsBinding ? "⟶ " + String(extras.itemsBinding).replace(/^#CPOwner\./, "") : "");

    UIBDrawText(title, CGPointMake(8, (bounds.size.height - 14) / 2), UIBFont(), items.length ? [CPColor blackColor] : [CPColor grayColor]);

    var arrow = [CPBezierPath bezierPath],
        x = bounds.size.width - 14,
        midY = bounds.size.height / 2;
    [arrow moveToPoint:CGPointMake(x, midY - 2)];
    [arrow lineToPoint:CGPointMake(x + 4, midY - 6)];
    [arrow lineToPoint:CGPointMake(x + 8, midY - 2)];
    [arrow moveToPoint:CGPointMake(x, midY + 2)];
    [arrow lineToPoint:CGPointMake(x + 4, midY + 6)];
    [arrow lineToPoint:CGPointMake(x + 8, midY + 2)];
    [[CPColor darkGrayColor] setStroke];
    [arrow stroke];
}

@end


@implementation UITableViewView (UIBColumns)

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds],
        columns = UIBSplitList([[self dataObject] valueForKey:@"columns"]),
        headerHeight = 20;

    [[CPColor whiteColor] setFill];
    [CPBezierPath fillRect:bounds];

    for (var row = 1; row * 20 < bounds.size.height; row += 2)
    {
        [[CPColor colorWithCalibratedRed:0.93 green:0.95 blue:1.0 alpha:1.0] setFill];
        [CPBezierPath fillRect:CGRectMake(0, headerHeight + row * 20, bounds.size.width, 20)];
    }

    [[CPColor controlColor] setFill];
    [CPBezierPath fillRect:CGRectMake(0, 0, bounds.size.width, headerHeight)];

    var x = 0,
        columnWidth = columns.length ? MAX(40, bounds.size.width / columns.length) : bounds.size.width;

    for (var i = 0; i < columns.length; i++)
    {
        UIBDrawText(columns[i], CGPointMake(x + 4, 3), [CPFont systemFontOfSize:11], [CPColor darkGrayColor]);
        x += columnWidth;

        var line = [CPBezierPath bezierPath];
        [line moveToPoint:CGPointMake(x, 0)];
        [line lineToPoint:CGPointMake(x, bounds.size.height)];
        [[CPColor colorWithCalibratedWhite:0.85 alpha:1.0] setStroke];
        [line stroke];
    }

    [[CPColor grayColor] setStroke];
    [CPBezierPath strokeRect:CGRectInset(bounds, 0.5, 0.5)];
}

@end


@implementation UISliderView (UIBRange)

- (void)drawSkeleton:(CGRect)rect
{
    var data = [self dataObject],
        bounds = CGRectInset([self bounds], 8, 0),
        midY = bounds.size.height / 2.0,
        minValue = Number([data valueForKey:@"minValue"]) || 0,
        maxValue = Number([data valueForKey:@"maxValue"]),
        value = Number([data valueForKey:@"value"]) || 0;

    if (isNaN(maxValue) || maxValue <= minValue)
        maxValue = minValue + 1;

    var fraction = MAX(0, MIN(1, (value - minValue) / (maxValue - minValue)));

    var track = [CPBezierPath bezierPath];
    [track setLineWidth:3.0];
    [track moveToPoint:CGPointMake(bounds.origin.x, midY)];
    [track lineToPoint:CGPointMake(bounds.origin.x + bounds.size.width, midY)];
    [[CPColor grayColor] setStroke];
    [track stroke];

    var knob = [CPBezierPath bezierPathWithOvalInRect:CGRectMake(bounds.origin.x + bounds.size.width * fraction - 8, midY - 8, 16, 16)];
    [[CPColor whiteColor] setFill];
    [knob fill];
    [[CPColor darkGrayColor] setStroke];
    [knob stroke];
}

@end


@implementation UIProgressIndicatorView (UIBIndeterminate)

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];

    if ([[self dataObject] valueForKey:@"isIndeterminate"])
    {
        var size = MIN(bounds.size.width, bounds.size.height) - 4,
            center = CGPointMake(bounds.size.width / 2, bounds.size.height / 2);

        for (var i = 0; i < 8; i++)
        {
            var angle = i * Math.PI / 4,
                spoke = [CPBezierPath bezierPath];
            [spoke setLineWidth:2];
            [spoke moveToPoint:CGPointMake(center.x + Math.cos(angle) * size * 0.25, center.y + Math.sin(angle) * size * 0.25)];
            [spoke lineToPoint:CGPointMake(center.x + Math.cos(angle) * size * 0.5, center.y + Math.sin(angle) * size * 0.5)];
            [[CPColor colorWithCalibratedWhite:0.2 alpha:0.2 + i * 0.1] setStroke];
            [spoke stroke];
        }
        return;
    }

    [[CPColor controlColor] setFill];
    [CPBezierPath fillRect:bounds];
    [[CPColor alternateSelectedControlColor] setFill];
    [CPBezierPath fillRect:CGRectMake(0, 0, bounds.size.width * 0.5, bounds.size.height)];
    [[CPColor grayColor] setStroke];
    [CPBezierPath strokeRect:CGRectInset(bounds, 0.5, 0.5)];
}

- (CGSize)intrinsicContentSize
{
    if ([[self dataObject] valueForKey:@"isIndeterminate"] && ![self hasExplicitSizeForKey:@"width"])
        return CGSizeMake(20, 20);

    var size = [super intrinsicContentSize];
    return size;
}

@end


@implementation UIDatePickerView (UIBStyle)

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = CGRectInset([self bounds], 0.5, 0.5);

    [[CPColor whiteColor] setFill];
    [CPBezierPath fillRect:bounds];
    [[CPColor grayColor] setStroke];
    [CPBezierPath strokeRect:bounds];

    if ([[self dataObject] valueForKey:@"style"] === "graphical" && bounds.size.height > 60)
    {
        // A small month grid
        var cell = MIN((bounds.size.width - 8) / 7, (bounds.size.height - 24) / 6);
        for (var row = 0; row < 6; row++)
            for (var col = 0; col < 7; col++)
                UIBDrawText(String(row * 7 + col + 1 <= 31 ? row * 7 + col + 1 : ""), CGPointMake(4 + col * cell, 20 + row * cell), [CPFont systemFontOfSize:9], [CPColor darkGrayColor]);
        UIBDrawText("Month", CGPointMake(6, 3), [CPFont boldSystemFontOfSize:10], [CPColor blackColor]);
        return;
    }

    UIBDrawText("31.12.2025", CGPointMake(5, (bounds.size.height - 14) / 2), UIBFont(), [CPColor darkGrayColor]);
}

@end

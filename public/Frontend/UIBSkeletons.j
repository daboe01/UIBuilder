//
//  UIBSkeletons.j
//  The look of the builder: how every element is drawn on the canvas
//  ("construction mode"), the selection and resize handles, and the icons of
//  the element palette. Everything shares the colors and helpers below, so
//  the canvas, the palette and the File's Owner look like one app.
//
//  These are categories, imported after all view classes.
//

@import "UIElementView.j"

#pragma mark - Theme

var UIBThemeColors = nil;

UIBRGB = function(r, g, b, a)
{
    return [CPColor colorWithCalibratedRed:r / 255 green:g / 255 blue:b / 255 alpha:(a === undefined ? 1.0 : a)];
};

// Colors are created lazily (CPColor must be loaded).
UIBTheme = function(aName)
{
    if (!UIBThemeColors)
    {
        UIBThemeColors = {
            accent:          UIBRGB(10, 132, 255),
            accentSoft:      UIBRGB(10, 132, 255, 0.14),
            accentDark:      UIBRGB(0, 98, 210),
            text:            UIBRGB(29, 29, 31),
            secondaryText:   UIBRGB(110, 110, 115),
            placeholder:     UIBRGB(160, 160, 166),
            controlFill:     UIBRGB(255, 255, 255),
            controlFillLow:  UIBRGB(246, 246, 248),
            controlBorder:   UIBRGB(0, 0, 0, 0.20),
            controlShadow:   UIBRGB(0, 0, 0, 0.10),
            fieldBorder:     UIBRGB(0, 0, 0, 0.18),
            track:           UIBRGB(0, 0, 0, 0.12),
            windowFill:      UIBRGB(236, 236, 238),
            titleBarTop:     UIBRGB(232, 232, 235),
            titleBarBottom:  UIBRGB(222, 222, 226),
            titleBarLine:    UIBRGB(0, 0, 0, 0.12),
            windowBorder:    UIBRGB(0, 0, 0, 0.28),
            containerLine:   UIBRGB(0, 0, 0, 0.16),
            rootLine:        UIBRGB(0, 0, 0, 0.07),
            spacer:          UIBRGB(10, 132, 255, 0.45),
            zebra:           UIBRGB(244, 246, 250),
            header:          UIBRGB(246, 246, 248),
            grid:            UIBRGB(0, 0, 0, 0.07),
            red:             UIBRGB(255, 95, 87),
            yellow:          UIBRGB(254, 188, 46),
            green:           UIBRGB(40, 200, 64),
            tile:            UIBRGB(255, 255, 255),
            tileBorder:      UIBRGB(0, 0, 0, 0.10)
        };
    }
    return UIBThemeColors[aName];
};

var UIBFonts = {};

UIBFont = function(aSize, isBold)
{
    var key = (isBold ? "b" : "r") + (aSize || 12);
    if (!UIBFonts[key])
        UIBFonts[key] = isBold ? [CPFont boldSystemFontOfSize:aSize || 12] : [CPFont systemFontOfSize:aSize || 12];
    return UIBFonts[key];
};

UIBContext = function()
{
    return [[CPGraphicsContext currentContext] graphicsPort];
};

// Draws with a soft drop shadow (if the canvas context supports it).
UIBWithShadow = function(anOffsetY, aBlur, aColor, aFunction)
{
    var context = UIBContext();
    if (typeof CGContextSetShadowWithColor === "undefined" || !context)
    {
        aFunction();
        return;
    }

    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, CGSizeMake(0, anOffsetY), aBlur, aColor);
    aFunction();
    CGContextRestoreGState(context);
};

UIBRoundedPath = function(aRect, aRadius)
{
    return [CPBezierPath bezierPathWithRoundedRect:aRect xRadius:aRadius yRadius:aRadius];
};

UIBFillStroke = function(aPath, aFill, aStroke, aWidth)
{
    if (aFill)
    {
        [aFill setFill];
        [aPath fill];
    }
    if (aStroke)
    {
        [aPath setLineWidth:aWidth || 1];
        [aStroke setStroke];
        [aPath stroke];
    }
};

UIBDrawText = function(aString, aPoint, aFont, aColor)
{
    [String(aString) drawAtPoint:aPoint withAttributes:@{ CPFontAttributeName: aFont, CPForegroundColorAttributeName: aColor }];
};

UIBTextWidth = function(aString, aFont)
{
    return [String(aString || "") sizeWithFont:aFont || UIBFont(12)].width;
};

// Text vertically centered in aRect; anAlignment: "left", "center", "right".
UIBDrawTextInRect = function(aString, aRect, aFont, aColor, anAlignment)
{
    if (aString === nil || aString === undefined || String(aString) === "")
        return;

    var text = String(aString),
        size = [text sizeWithFont:aFont],
        x = aRect.origin.x;

    // Shorten text that does not fit.
    if (size.width > aRect.size.width && text.length > 2)
    {
        while (text.length > 1 && [text + "…" sizeWithFont:aFont].width > aRect.size.width)
            text = text.substring(0, text.length - 1);
        text += "…";
        size = [text sizeWithFont:aFont];
    }

    if (anAlignment === "center")
        x += (aRect.size.width - size.width) / 2;
    else if (anAlignment === "right")
        x += aRect.size.width - size.width;

    var y = aRect.origin.y + (aRect.size.height - [[aFont fontDescriptor] pointSize]) / 2 - 2;
    UIBDrawText(text, CGPointMake(x, y), aFont, aColor);
};

// A macOS-like push button bezel.
UIBDrawBezel = function(aRect, aRadius, isProminent)
{
    var path = UIBRoundedPath(aRect, aRadius === undefined ? 5 : aRadius);

    UIBWithShadow(1, 1.5, UIBTheme("controlShadow"), function()
    {
        UIBFillStroke(path, isProminent ? UIBTheme("accent") : UIBTheme("controlFill"), nil);
    });

    UIBFillStroke(path, nil, isProminent ? UIBTheme("accentDark") : UIBTheme("controlBorder"), 1);
};

// A text field bezel (white, thin border, slight inner top line).
UIBDrawFieldBezel = function(aRect, aRadius)
{
    var path = UIBRoundedPath(aRect, aRadius === undefined ? 4 : aRadius);
    UIBFillStroke(path, UIBTheme("controlFill"), UIBTheme("fieldBorder"), 1);

    var inner = [CPBezierPath bezierPath];
    [inner moveToPoint:CGPointMake(aRect.origin.x + (aRadius || 4), aRect.origin.y + 1.5)];
    [inner lineToPoint:CGPointMake(aRect.origin.x + aRect.size.width - (aRadius || 4), aRect.origin.y + 1.5)];
    [inner setLineWidth:1];
    [UIBTheme("grid") setStroke];
    [inner stroke];
};

UIBDrawChevronUpDown = function(aCenter, aSize, aColor)
{
    var path = [CPBezierPath bezierPath];
    [path moveToPoint:CGPointMake(aCenter.x - aSize, aCenter.y - 1.5)];
    [path lineToPoint:CGPointMake(aCenter.x, aCenter.y - 1.5 - aSize)];
    [path lineToPoint:CGPointMake(aCenter.x + aSize, aCenter.y - 1.5)];
    [path moveToPoint:CGPointMake(aCenter.x - aSize, aCenter.y + 1.5)];
    [path lineToPoint:CGPointMake(aCenter.x, aCenter.y + 1.5 + aSize)];
    [path lineToPoint:CGPointMake(aCenter.x + aSize, aCenter.y + 1.5)];
    [path setLineWidth:1.5];
    [aColor setStroke];
    [path stroke];
};

UIBDrawChevronDown = function(aCenter, aSize, aColor)
{
    var path = [CPBezierPath bezierPath];
    [path moveToPoint:CGPointMake(aCenter.x - aSize, aCenter.y - aSize / 2)];
    [path lineToPoint:CGPointMake(aCenter.x, aCenter.y + aSize / 2)];
    [path lineToPoint:CGPointMake(aCenter.x + aSize, aCenter.y - aSize / 2)];
    [path setLineWidth:1.5];
    [aColor setStroke];
    [path stroke];
};

UIBDrawCheckMark = function(aRect, aColor)
{
    var path = [CPBezierPath bezierPath],
        x = aRect.origin.x, y = aRect.origin.y, w = aRect.size.width, h = aRect.size.height;
    [path moveToPoint:CGPointMake(x + w * 0.22, y + h * 0.52)];
    [path lineToPoint:CGPointMake(x + w * 0.42, y + h * 0.72)];
    [path lineToPoint:CGPointMake(x + w * 0.78, y + h * 0.30)];
    [path setLineWidth:2];
    [aColor setStroke];
    [path stroke];
};

UIBDrawMagnifier = function(anOrigin, aSize, aColor)
{
    var circle = [CPBezierPath bezierPathWithOvalInRect:CGRectMake(anOrigin.x, anOrigin.y, aSize * 0.7, aSize * 0.7)];
    [circle setLineWidth:1.4];
    [aColor setStroke];
    [circle stroke];

    var handle = [CPBezierPath bezierPath];
    [handle moveToPoint:CGPointMake(anOrigin.x + aSize * 0.6, anOrigin.y + aSize * 0.6)];
    [handle lineToPoint:CGPointMake(anOrigin.x + aSize, anOrigin.y + aSize)];
    [handle setLineWidth:1.6];
    [handle stroke];
};

// Shows what a control is bound to when it has no content of its own.
UIBBindingHint = function(aData)
{
    var extras = [aData valueForKey:@"extraAttributes"] || {},
        binding = extras.valueBinding || extras.itemsBinding;

    return binding ? "⟶ " + String(binding).replace(/^#CPOwner\./, "") : nil;
};

#pragma mark - Selection and Handles

@implementation UIElementView (UIBTheme)

- (void)drawRect:(CGRect)rect
{
    [self drawSkeleton:rect];

    if (self._isDragTarget)
        [self _uib_drawDropHighlight];

    if ([self isSelected])
    {
        var outline = [CPBezierPath bezierPathWithRect:CGRectInset([self bounds], 1, 1)];
        [outline setLineWidth:2];
        [UIBTheme("accent") setStroke];
        [outline stroke];
        [self drawHandles];
    }
}

- (void)_uib_drawDropHighlight
{
    var path = UIBRoundedPath(CGRectInset([self bounds], 1.5, 1.5), 4);
    UIBFillStroke(path, UIBTheme("accentSoft"), UIBTheme("accent"), 2);
}

- (void)drawHandles
{
    var halign = UIBAlignKind([[self dataObject] valueForKey:@"halign"]),
        valign = UIBAlignKind([[self dataObject] valueForKey:@"valign"]);

    for (var i = 1; i <= 8; i++)
    {
        var horizontal = (i === kUIElementTopLeftHandle || i === kUIElementMiddleLeftHandle || i === kUIElementBottomLeftHandle ||
                          i === kUIElementTopRightHandle || i === kUIElementMiddleRightHandle || i === kUIElementBottomRightHandle),
            vertical = (i === kUIElementTopLeftHandle || i === kUIElementTopMiddleHandle || i === kUIElementTopRightHandle ||
                        i === kUIElementBottomLeftHandle || i === kUIElementBottomMiddleHandle || i === kUIElementBottomRightHandle);

        if ((halign === "expand" && horizontal) || (valign === "expand" && vertical))
            continue;

        var handleRect = CGRectInset([self rectForHandle:i], 0.5, 0.5),
            handle = [CPBezierPath bezierPathWithOvalInRect:handleRect];

        UIBWithShadow(0.5, 1, UIBRGB(0, 0, 0, 0.25), function()
        {
            UIBFillStroke(handle, UIBTheme("controlFill"), nil);
        });
        UIBFillStroke(handle, nil, UIBTheme("accent"), 1.5);
    }
}

- (void)drawSkeleton:(CGRect)rect
{
    // Elements without their own look: a neutral rounded placeholder.
    var bounds = CGRectInset([self bounds], 0.5, 0.5);
    UIBFillStroke(UIBRoundedPath(bounds, 4), UIBTheme("controlFillLow"), UIBTheme("controlBorder"), 1);
    UIBDrawTextInRect([[self dataObject] valueForKey:@"value"] || [[self dataObject] valueForKey:@"type"], CGRectInset(bounds, 6, 0), UIBFont(11), UIBTheme("secondaryText"), "center");
}

@end

#pragma mark - Windows

@implementation UIWindowView (UIBTheme)

- (void)drawRect:(CGRect)rect
{
    [self drawSkeleton:rect];

    var bounds = [self bounds],
        frame = UIBRoundedPath(CGRectInset(bounds, 0.5, 0.5), 8);

    if (self._isDropTarget || self._isDragTarget)
        UIBFillStroke(frame, nil, UIBTheme("accent"), 2.5);

    if ([self isSelected])
    {
        UIBFillStroke(UIBRoundedPath(CGRectInset(bounds, 1.5, 1.5), 8), nil, UIBTheme("accent"), 2.5);
        [self drawHandles];
    }

    if (self._isRubbing)
    {
        var rubber = CGRectUnion(CGRectMake(self._rubberStart.x, self._rubberStart.y, 0.1, 0.1), CGRectMake(self._rubberEnd.x, self._rubberEnd.y, 0.1, 0.1));
        UIBFillStroke([CPBezierPath bezierPathWithRect:rubber], UIBTheme("accentSoft"), UIBTheme("accent"), 1);
    }
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds],
        titleBarHeight = 22.0,
        windowRect = CGRectInset(bounds, 0.5, 0.5),
        windowPath = UIBRoundedPath(windowRect, 8);

    // Body with a soft shadow
    UIBWithShadow(3, 10, UIBRGB(0, 0, 0, 0.22), function()
    {
        UIBFillStroke(windowPath, UIBTheme("windowFill"), nil);
    });

    // Title bar: two tones (rounded on top, square at the bottom) and a hairline
    UIBFillStroke(UIBRoundedPath(CGRectMake(0.5, 0.5, bounds.size.width - 1, titleBarHeight), 8), UIBTheme("titleBarTop"), nil);
    [UIBTheme("titleBarBottom") setFill];
    [CPBezierPath fillRect:CGRectMake(0.5, titleBarHeight / 2, bounds.size.width - 1, titleBarHeight / 2)];

    var line = [CPBezierPath bezierPath];
    [line moveToPoint:CGPointMake(0, titleBarHeight - 0.5)];
    [line lineToPoint:CGPointMake(bounds.size.width, titleBarHeight - 0.5)];
    [UIBTheme("titleBarLine") setStroke];
    [line stroke];

    UIBFillStroke(windowPath, nil, UIBTheme("windowBorder"), 1);

    // Traffic lights
    var colors = [UIBTheme("red"), UIBTheme("yellow"), UIBTheme("green")];
    for (var i = 0; i < 3; i++)
    {
        var light = [CPBezierPath bezierPathWithOvalInRect:CGRectMake(9 + i * 17, 5.5, 11, 11)];
        UIBFillStroke(light, colors[i], UIBRGB(0, 0, 0, 0.12), 0.5);
    }

    // Title (the title text field is a subview; make it fit this look)
    var subviews = [self subviews];
    for (var i = 0; i < subviews.length; i++)
    {
        var subview = subviews[i];
        if ([subview isKindOfClass:[CPTextField class]] && !subview._uibStyled)
        {
            [subview setTextColor:UIBTheme("text")];
            [subview setFont:UIBFont(13, YES)];
            [subview setAlignment:CPCenterTextAlignment];
            subview._uibStyled = YES;
        }
    }

    // Badges for things that are not visible on the canvas
    var data = [self dataObject],
        badges = [];

    if ([data valueForKey:@"bridge"])
        badges.push("bridge");
    if ([data valueForKey:@"visible"] === false)
        badges.push("hidden");
    if ([data valueForKey:@"identifier"])
        badges.push("#" + [data valueForKey:@"identifier"]);

    var x = bounds.size.width - 8;
    for (var i = badges.length - 1; i >= 0; i--)
    {
        var width = UIBTextWidth(badges[i], UIBFont(10)) + 10;
        x -= width;
        UIBFillStroke(UIBRoundedPath(CGRectMake(x, 4, width, 14), 7), UIBRGB(0, 0, 0, 0.07), nil);
        UIBDrawTextInRect(badges[i], CGRectMake(x, 4, width, 14), UIBFont(10), UIBTheme("secondaryText"), "center");
        x -= 4;
    }
}

@end

#pragma mark - Controls

@implementation UIButtonView (UIBTheme)

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(MAX(56, UIBTextWidth([[self dataObject] valueForKey:@"value"], UIBFont(13)) + 30), 24);
}

- (void)sizeToFit
{
    [self setFrameSize:[self intrinsicContentSize]];
}

- (void)drawSkeleton:(CGRect)rect
{
    var data = [self dataObject],
        bounds = [self bounds],
        bezel = CGRectMake(1, MAX(1, (bounds.size.height - 22) / 2), bounds.size.width - 2, MIN(22, bounds.size.height - 2)),
        keyEquivalent = [data valueForKey:@"keyEquivalent"],
        isDefault = keyEquivalent === "\r" || keyEquivalent === "\\r",
        isEnabled = [data valueForKey:@"enabled"] !== false;

    UIBDrawBezel(bezel, 5, isDefault);
    UIBDrawTextInRect([data valueForKey:@"value"], CGRectInset(bezel, 8, 0), UIBFont(13), isDefault ? [CPColor whiteColor] : (isEnabled ? UIBTheme("text") : UIBTheme("placeholder")), "center");
}

@end


@implementation UICheckBoxView (UIBTheme)

- (CGSize)intrinsicContentSize
{
    var title = [[self dataObject] valueForKey:@"title"] || "";
    return CGSizeMake(18 + (title.length ? UIBTextWidth(title, UIBFont(13)) + 6 : 0), 20);
}

- (void)drawSkeleton:(CGRect)rect
{
    var data = [self dataObject],
        bounds = [self bounds],
        box = CGRectMake(1.5, (bounds.size.height - 14) / 2, 14, 14),
        checked = !![data valueForKey:@"value"];

    if (checked)
    {
        UIBFillStroke(UIBRoundedPath(box, 3.5), UIBTheme("accent"), UIBTheme("accentDark"), 1);
        UIBDrawCheckMark(box, [CPColor whiteColor]);
    }
    else
        UIBWithShadow(0.5, 1, UIBTheme("controlShadow"), function()
        {
            UIBFillStroke(UIBRoundedPath(box, 3.5), UIBTheme("controlFill"), UIBTheme("controlBorder"), 1);
        });

    var title = [data valueForKey:@"title"];
    if (title)
        UIBDrawTextInRect(title, CGRectMake(22, 0, bounds.size.width - 22, bounds.size.height), UIBFont(13), UIBTheme("text"), "left");
}

@end


@implementation UILabelView (UIBTheme)

- (CGSize)intrinsicContentSize
{
    var value = [[self dataObject] valueForKey:@"value"] || "";
    return CGSizeMake(MAX(10, UIBTextWidth(value, UIBFont(13)) + 6), 20);
}

- (void)sizeToFit
{
    [self setFrameSize:[self intrinsicContentSize]];
}

- (void)drawSkeleton:(CGRect)rect
{
    var data = [self dataObject],
        value = [data valueForKey:@"value"],
        colorString = [data valueForKey:@"color"],
        color = UIBTheme("text"),
        extras = [data valueForKey:@"extraAttributes"] || {},
        font = /bold/i.test(extras.font || "") ? UIBFont(Number(extras.size) || 13, YES) : UIBFont(Number(extras.size) || 13);

    if (colorString && String(colorString).charAt(0) === "#" && colorString !== "#000000")
        color = [CPColor colorWithHexString:String(colorString).substring(1)] || color;

    if (value === nil || value === undefined || String(value).trim() === "")
    {
        var hint = UIBBindingHint(data);
        if (hint)
            UIBDrawTextInRect(hint, CGRectInset([self bounds], 2, 0), UIBFont(11), UIBTheme("placeholder"), "left");
        return;
    }

    UIBDrawTextInRect(value, CGRectInset([self bounds], 2, 0), font, color, [data valueForKey:@"horizontalTextAlign"] || "left");
}

@end


@implementation UITextFieldView (UIBTheme)

// Text fields, search fields, secure fields and combo boxes share this.
- (void)drawSkeleton:(CGRect)rect
{
    var data = [self dataObject],
        type = [data valueForKey:@"type"],
        bounds = [self bounds],
        height = MIN(22, bounds.size.height - 2),
        field = CGRectMake(1, MAX(1, (bounds.size.height - height) / 2), bounds.size.width - 2, height),
        textRect = CGRectInset(field, 6, 0),
        value = [data valueForKey:@"value"],
        hasValue = value !== nil && value !== undefined && String(value).length > 0;

    if (type === "searchField")
    {
        UIBDrawFieldBezel(field, height / 2);
        UIBDrawMagnifier(CGPointMake(field.origin.x + 8, field.origin.y + (height - 11) / 2), 11, UIBTheme("secondaryText"));
        textRect = CGRectMake(field.origin.x + 24, field.origin.y, field.size.width - 30, height);
    }
    else
        UIBDrawFieldBezel(field, 4);

    if (type === "comboBox")
    {
        var buttonRect = CGRectMake(field.origin.x + field.size.width - 20, field.origin.y + 2, 18, height - 4);
        UIBFillStroke(UIBRoundedPath(buttonRect, 4), UIBTheme("accent"), nil);
        UIBDrawChevronDown(CGPointMake(CGRectGetMidX(buttonRect), CGRectGetMidY(buttonRect)), 3.5, [CPColor whiteColor]);
        textRect.size.width -= 22;
    }

    if (type === "secureField" && hasValue)
    {
        var dots = Math.min(String(value).length, Math.floor(textRect.size.width / 9));
        for (var i = 0; i < dots; i++)
        {
            var dot = [CPBezierPath bezierPathWithOvalInRect:CGRectMake(textRect.origin.x + i * 9, CGRectGetMidY(field) - 3, 6, 6)];
            UIBFillStroke(dot, UIBTheme("text"), nil);
        }
        return;
    }

    if (hasValue)
        UIBDrawTextInRect(value, textRect, UIBFont(13), UIBTheme("text"), "left");
    else
        UIBDrawTextInRect(UIBBindingHint(data) || ({ searchField: "Suchen", secureField: "Passwort", comboBox: "" }[type] || ""), textRect, UIBFont(12), UIBTheme("placeholder"), "left");
}

@end

@implementation UISearchFieldView (UIBTheme)
- (void)drawSkeleton:(CGRect)rect { [super drawSkeleton:rect]; }
@end

@implementation UISecureFieldView (UIBTheme)
- (void)drawSkeleton:(CGRect)rect { [super drawSkeleton:rect]; }
@end

@implementation UIComboBoxView (UIBTheme)
- (void)drawSkeleton:(CGRect)rect { [super drawSkeleton:rect]; }
@end


@implementation UIPopUpButtonView (UIBTheme)

- (CGSize)intrinsicContentSize
{
    var items = UIBSplitList([[self dataObject] valueForKey:@"items"]),
        width = 70;

    for (var i = 0; i < items.length; i++)
        width = MAX(width, UIBTextWidth(items[i], UIBFont(13)) + 40);

    return CGSizeMake(width, 24);
}

- (void)drawSkeleton:(CGRect)rect
{
    var data = [self dataObject],
        bounds = [self bounds],
        bezel = CGRectMake(1, MAX(1, (bounds.size.height - 22) / 2), bounds.size.width - 2, MIN(22, bounds.size.height - 2)),
        items = UIBSplitList([data valueForKey:@"items"]),
        title = items.length ? items[0] : UIBBindingHint(data);

    UIBDrawBezel(bezel, 5, NO);

    var arrowBox = CGRectMake(bezel.origin.x + bezel.size.width - 19, bezel.origin.y + 3, 16, bezel.size.height - 6);
    UIBFillStroke(UIBRoundedPath(arrowBox, 4), UIBTheme("accent"), nil);

    if ([data valueForKey:@"pullsDown"])
        UIBDrawChevronDown(CGPointMake(CGRectGetMidX(arrowBox), CGRectGetMidY(arrowBox)), 3.5, [CPColor whiteColor]);
    else
        UIBDrawChevronUpDown(CGPointMake(CGRectGetMidX(arrowBox), CGRectGetMidY(arrowBox)), 3, [CPColor whiteColor]);

    UIBDrawTextInRect(title || "", CGRectMake(bezel.origin.x + 8, bezel.origin.y, bezel.size.width - 32, bezel.size.height), items.length ? UIBFont(13) : UIBFont(11), items.length ? UIBTheme("text") : UIBTheme("placeholder"), "left");
}

@end


@implementation UISliderView (UIBTheme)

- (void)drawSkeleton:(CGRect)rect
{
    var data = [self dataObject],
        bounds = [self bounds],
        midY = bounds.size.height / 2,
        minValue = Number([data valueForKey:@"minValue"]) || 0,
        maxValue = Number([data valueForKey:@"maxValue"]),
        value = Number([data valueForKey:@"value"]) || 0;

    if (isNaN(maxValue) || maxValue <= minValue)
        maxValue = minValue + 1;

    var fraction = MAX(0, MIN(1, (value - minValue) / (maxValue - minValue))),
        left = 9, width = MAX(0, bounds.size.width - 18),
        knobX = left + width * fraction;

    UIBFillStroke(UIBRoundedPath(CGRectMake(left, midY - 2, width, 4), 2), UIBTheme("track"), nil);
    UIBFillStroke(UIBRoundedPath(CGRectMake(left, midY - 2, knobX - left, 4), 2), UIBTheme("accent"), nil);

    var knob = [CPBezierPath bezierPathWithOvalInRect:CGRectMake(knobX - 8, midY - 8, 16, 16)];
    UIBWithShadow(1, 3, UIBRGB(0, 0, 0, 0.3), function()
    {
        UIBFillStroke(knob, UIBTheme("controlFill"), nil);
    });
    UIBFillStroke(knob, nil, UIBTheme("controlBorder"), 0.5);
}

@end


@implementation UIStepperView (UIBTheme)

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds],
        width = MIN(19, bounds.size.width - 2),
        height = MIN(26, bounds.size.height - 2),
        body = CGRectMake(1 + (bounds.size.width - 2 - width) / 2, (bounds.size.height - height) / 2, width, height);

    UIBDrawBezel(body, 5, NO);

    var divider = [CPBezierPath bezierPath];
    [divider moveToPoint:CGPointMake(body.origin.x + 3, CGRectGetMidY(body))];
    [divider lineToPoint:CGPointMake(body.origin.x + body.size.width - 3, CGRectGetMidY(body))];
    [UIBTheme("controlBorder") setStroke];
    [divider stroke];

    UIBDrawChevronUpDown(CGPointMake(CGRectGetMidX(body), CGRectGetMidY(body)), 3, UIBTheme("text"));
}

@end


@implementation UIProgressIndicatorView (UIBTheme)

- (CGSize)intrinsicContentSize
{
    if ([[self dataObject] valueForKey:@"isIndeterminate"] && ![self hasExplicitSizeForKey:@"width"])
        return CGSizeMake(20, 20);

    return [super intrinsicContentSize];
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds];

    if ([[self dataObject] valueForKey:@"isIndeterminate"])
    {
        var size = MIN(bounds.size.width, bounds.size.height) - 2,
            center = CGPointMake(bounds.size.width / 2, bounds.size.height / 2);

        for (var i = 0; i < 12; i++)
        {
            var angle = i * Math.PI / 6,
                spoke = [CPBezierPath bezierPath];
            [spoke setLineWidth:MAX(1.5, size / 10)];
            [spoke moveToPoint:CGPointMake(center.x + Math.cos(angle) * size * 0.24, center.y + Math.sin(angle) * size * 0.24)];
            [spoke lineToPoint:CGPointMake(center.x + Math.cos(angle) * size * 0.46, center.y + Math.sin(angle) * size * 0.46)];
            [UIBRGB(60, 60, 67, 0.15 + i * 0.06) setStroke];
            [spoke stroke];
        }
        return;
    }

    var track = CGRectMake(1, bounds.size.height / 2 - 3, bounds.size.width - 2, 6);
    UIBFillStroke(UIBRoundedPath(track, 3), UIBTheme("track"), nil);
    UIBFillStroke(UIBRoundedPath(CGRectMake(track.origin.x, track.origin.y, track.size.width * 0.45, 6), 3), UIBTheme("accent"), nil);
}

@end


@implementation UIDatePickerView (UIBTheme)

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds],
        data = [self dataObject];

    if ([data valueForKey:@"style"] === "graphical" && bounds.size.height > 60)
    {
        var body = CGRectInset(bounds, 1, 1);
        UIBFillStroke(UIBRoundedPath(body, 6), UIBTheme("controlFill"), UIBTheme("fieldBorder"), 1);
        UIBDrawTextInRect("Oktober 2026", CGRectMake(8, 4, body.size.width - 16, 16), UIBFont(11, YES), UIBTheme("text"), "left");

        var cell = MIN((body.size.width - 12) / 7, (body.size.height - 28) / 6);
        for (var row = 0; row < 6; row++)
            for (var col = 0; col < 7; col++)
            {
                var day = row * 7 + col + 1;
                if (day > 31)
                    continue;

                var cellRect = CGRectMake(6 + col * cell, 24 + row * cell, cell, cell);
                if (day === 19)
                    UIBFillStroke([CPBezierPath bezierPathWithOvalInRect:CGRectInset(cellRect, 1, 1)], UIBTheme("accent"), nil);
                UIBDrawTextInRect(String(day), cellRect, UIBFont(9), day === 19 ? [CPColor whiteColor] : UIBTheme("secondaryText"), "center");
            }
        return;
    }

    var height = MIN(22, bounds.size.height - 2),
        field = CGRectMake(1, (bounds.size.height - height) / 2, bounds.size.width - 2, height);

    UIBDrawFieldBezel(field, 4);
    UIBDrawTextInRect(UIBBindingHint(data) || "19.10.2026", CGRectMake(7, field.origin.y, field.size.width - 30, height), UIBFont(13), UIBBindingHint(data) ? UIBTheme("placeholder") : UIBTheme("text"), "left");

    // Calendar glyph
    var icon = CGRectMake(field.origin.x + field.size.width - 19, field.origin.y + (height - 12) / 2, 13, 12);
    UIBFillStroke(UIBRoundedPath(icon, 2), nil, UIBTheme("secondaryText"), 1);
    [UIBTheme("secondaryText") setFill];
    [CPBezierPath fillRect:CGRectMake(icon.origin.x, icon.origin.y, icon.size.width, 3)];
}

@end


@implementation UIImageViewView (UIBTheme)

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = CGRectInset([self bounds], 1, 1);
    UIBFillStroke(UIBRoundedPath(bounds, 4), UIBRGB(242, 244, 247), UIBTheme("fieldBorder"), 1);

    // A small picture glyph: sun and mountains
    var size = MIN(bounds.size.width, bounds.size.height) * 0.5,
        origin = CGPointMake(CGRectGetMidX(bounds) - size / 2, CGRectGetMidY(bounds) - size / 2);

    if (size < 8)
        return;

    UIBFillStroke([CPBezierPath bezierPathWithOvalInRect:CGRectMake(origin.x + size * 0.62, origin.y + size * 0.1, size * 0.22, size * 0.22)], UIBRGB(255, 196, 0), nil);

    var mountains = [CPBezierPath bezierPath];
    [mountains moveToPoint:CGPointMake(origin.x, origin.y + size)];
    [mountains lineToPoint:CGPointMake(origin.x + size * 0.35, origin.y + size * 0.4)];
    [mountains lineToPoint:CGPointMake(origin.x + size * 0.6, origin.y + size * 0.75)];
    [mountains lineToPoint:CGPointMake(origin.x + size * 0.75, origin.y + size * 0.55)];
    [mountains lineToPoint:CGPointMake(origin.x + size, origin.y + size)];
    [mountains closePath];
    UIBFillStroke(mountains, UIBRGB(120, 170, 120), nil);
}

@end


@implementation UITextViewView (UIBTheme)

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = CGRectInset([self bounds], 0.5, 0.5),
        data = [self dataObject],
        value = [data valueForKey:@"value"];

    UIBFillStroke([CPBezierPath bezierPathWithRect:bounds], UIBTheme("controlFill"), UIBTheme("fieldBorder"), 1);

    if (value)
    {
        var lines = String(value).split("\n");
        for (var i = 0; i < lines.length && 6 + i * 16 < bounds.size.height - 12; i++)
            UIBDrawTextInRect(lines[i], CGRectMake(6, 4 + i * 16, bounds.size.width - 12, 16), UIBFont(12), UIBTheme("text"), "left");
        return;
    }

    // Faint text lines
    for (var y = 10, i = 0; y < bounds.size.height - 8 && i < 8; y += 12, i++)
    {
        var width = (bounds.size.width - 16) * ((i % 3 === 2) ? 0.55 : 0.9);
        UIBFillStroke(UIBRoundedPath(CGRectMake(8, y, width, 4), 2), UIBRGB(0, 0, 0, 0.06), nil);
    }

    var hint = UIBBindingHint(data);
    if (hint)
        UIBDrawTextInRect(hint, CGRectMake(8, bounds.size.height - 20, bounds.size.width - 16, 16), UIBFont(11), UIBTheme("placeholder"), "left");
}

@end


@implementation UIScrollViewView (UIBTheme)

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = CGRectInset([self bounds], 0.5, 0.5),
        data = [self dataObject];

    UIBFillStroke([CPBezierPath bezierPathWithRect:bounds], UIBTheme("controlFill"), UIBTheme("fieldBorder"), 1);

    // Overlay scrollers
    if ([data valueForKey:@"hasVerticalScroller"] !== false && bounds.size.height > 30)
        UIBFillStroke(UIBRoundedPath(CGRectMake(bounds.size.width - 7, 4, 4, MIN(60, bounds.size.height * 0.35)), 2), UIBRGB(0, 0, 0, 0.25), nil);
    if ([data valueForKey:@"hasHorizontalScroller"] !== false && bounds.size.width > 30)
        UIBFillStroke(UIBRoundedPath(CGRectMake(4, bounds.size.height - 7, MIN(80, bounds.size.width * 0.35), 4), 2), UIBRGB(0, 0, 0, 0.25), nil);
}

@end


@implementation UISplitViewView (UIBTheme)

- (void)drawSkeleton:(CGRect)rect
{
    // The panes draw themselves; the divider is drawn by the root box.
    var bounds = CGRectInset([self bounds], 0.5, 0.5);
    UIBFillStroke([CPBezierPath bezierPathWithRect:bounds], nil, UIBTheme("containerLine"), 1);
}

@end


@implementation UITableViewView (UIBTheme)

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds],
        data = [self dataObject],
        columns = UIBSplitList([data valueForKey:@"columns"]),
        headerHeight = 22,
        rowHeight = 20;

    [UIBTheme("controlFill") setFill];
    [CPBezierPath fillRect:bounds];

    for (var row = 1, y = headerHeight + rowHeight; y < bounds.size.height; row += 2, y += 2 * rowHeight)
    {
        [UIBTheme("zebra") setFill];
        [CPBezierPath fillRect:CGRectMake(0, y, bounds.size.width, rowHeight)];
    }

    [UIBTheme("header") setFill];
    [CPBezierPath fillRect:CGRectMake(0, 0, bounds.size.width, headerHeight)];

    var line = [CPBezierPath bezierPath];
    [line moveToPoint:CGPointMake(0, headerHeight - 0.5)];
    [line lineToPoint:CGPointMake(bounds.size.width, headerHeight - 0.5)];
    [UIBTheme("controlBorder") setStroke];
    [line stroke];

    var x = 0,
        columnWidth = columns.length ? MAX(50, bounds.size.width / columns.length) : bounds.size.width;

    for (var i = 0; i < columns.length && x < bounds.size.width; i++)
    {
        UIBDrawTextInRect(columns[i], CGRectMake(x + 6, 0, columnWidth - 12, headerHeight), UIBFont(11, YES), UIBTheme("secondaryText"), "left");
        x += columnWidth;

        var divider = [CPBezierPath bezierPath];
        [divider moveToPoint:CGPointMake(x - 0.5, 4)];
        [divider lineToPoint:CGPointMake(x - 0.5, headerHeight - 4)];
        [UIBTheme("controlBorder") setStroke];
        [divider stroke];
    }

    var hint = UIBBindingHint(data);
    if (hint && bounds.size.height > headerHeight + 30)
        UIBDrawTextInRect(hint, CGRectMake(8, headerHeight + 4, bounds.size.width - 16, 16), UIBFont(11), UIBTheme("accent"), "left");
}

@end


@implementation UIHSpaceView (UIBTheme)

- (void)drawRect:(CGRect)rect
{
    if ([self isSelected])
        UIBFillStroke([CPBezierPath bezierPathWithRect:[self bounds]], UIBTheme("accentSoft"), nil);

    [self drawSkeleton:rect];

    if ([self isSelected])
    {
        UIBFillStroke([CPBezierPath bezierPathWithRect:CGRectInset([self bounds], 0.5, 0.5)], nil, UIBTheme("accent"), 1);
        [self drawHandles];
    }
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds],
        midY = bounds.size.height / 2,
        expanding = UIBAlignKind([[self dataObject] valueForKey:@"halign"]) === "expand",
        path = [CPBezierPath bezierPath];

    if (bounds.size.width < 4)
        return;

    if (expanding)
    {
        // A spring
        var steps = MAX(2, Math.floor((bounds.size.width - 8) / 6));
        [path moveToPoint:CGPointMake(4, midY)];
        for (var i = 1; i <= steps; i++)
            [path lineToPoint:CGPointMake(4 + i * (bounds.size.width - 8) / steps, midY + ((i % 2) ? -3 : 3))];
    }
    else
    {
        // A measurement bar
        [path moveToPoint:CGPointMake(1, midY - 4)];
        [path lineToPoint:CGPointMake(1, midY + 4)];
        [path moveToPoint:CGPointMake(1, midY)];
        [path lineToPoint:CGPointMake(bounds.size.width - 1, midY)];
        [path moveToPoint:CGPointMake(bounds.size.width - 1, midY - 4)];
        [path lineToPoint:CGPointMake(bounds.size.width - 1, midY + 4)];
    }

    [path setLineWidth:1];
    [UIBTheme("spacer") setStroke];
    [path stroke];
}

@end


@implementation UIVSpaceView (UIBTheme)

- (void)drawRect:(CGRect)rect
{
    if ([self isSelected])
        UIBFillStroke([CPBezierPath bezierPathWithRect:[self bounds]], UIBTheme("accentSoft"), nil);

    [self drawSkeleton:rect];

    if ([self isSelected])
    {
        UIBFillStroke([CPBezierPath bezierPathWithRect:CGRectInset([self bounds], 0.5, 0.5)], nil, UIBTheme("accent"), 1);
        [self drawHandles];
    }
}

- (void)drawSkeleton:(CGRect)rect
{
    var bounds = [self bounds],
        midX = bounds.size.width / 2,
        expanding = UIBAlignKind([[self dataObject] valueForKey:@"valign"]) === "expand",
        path = [CPBezierPath bezierPath];

    if (bounds.size.height < 4)
        return;

    if (expanding)
    {
        var steps = MAX(2, Math.floor((bounds.size.height - 8) / 6));
        [path moveToPoint:CGPointMake(midX, 4)];
        for (var i = 1; i <= steps; i++)
            [path lineToPoint:CGPointMake(midX + ((i % 2) ? -3 : 3), 4 + i * (bounds.size.height - 8) / steps)];
    }
    else
    {
        [path moveToPoint:CGPointMake(midX - 4, 1)];
        [path lineToPoint:CGPointMake(midX + 4, 1)];
        [path moveToPoint:CGPointMake(midX, 1)];
        [path lineToPoint:CGPointMake(midX, bounds.size.height - 1)];
        [path moveToPoint:CGPointMake(midX - 4, bounds.size.height - 1)];
        [path lineToPoint:CGPointMake(midX + 4, bounds.size.height - 1)];
    }

    [path setLineWidth:1];
    [UIBTheme("spacer") setStroke];
    [path stroke];
}

@end


#pragma mark - Palette Icons

/*!
    Draws the palette icon of an element type into aRect (about 44×30).
    The icons are miniatures of the canvas look above.
*/
UIBDrawElementIcon = function(aType, aRect)
{
    var x = aRect.origin.x, y = aRect.origin.y, w = aRect.size.width, h = aRect.size.height,
        cx = x + w / 2, cy = y + h / 2;

    switch (aType)
    {
        case "window":
            var body = CGRectMake(x + 2, y + 2, w - 4, h - 4),
                path = UIBRoundedPath(body, 4);
            UIBFillStroke(path, UIBTheme("windowFill"), UIBTheme("windowBorder"), 1);
            [UIBTheme("titleBarBottom") setFill];
            [CPBezierPath fillRect:CGRectMake(body.origin.x + 1, body.origin.y + 1, body.size.width - 2, 7)];
            var lights = [UIBTheme("red"), UIBTheme("yellow"), UIBTheme("green")];
            for (var i = 0; i < 3; i++)
                UIBFillStroke([CPBezierPath bezierPathWithOvalInRect:CGRectMake(body.origin.x + 3 + i * 5, body.origin.y + 2.5, 3.5, 3.5)], lights[i], nil);
            break;

        case "box":
            UIBFillStroke(UIBRoundedPath(CGRectMake(x + 3, y + 6, w - 6, h - 9), 4), UIBRGB(0, 0, 0, 0.04), UIBTheme("secondaryText"), 1);
            UIBFillStroke([CPBezierPath bezierPathWithRect:CGRectMake(x + 8, y + 3, 16, 6)], UIBTheme("tile"), nil);
            UIBFillStroke(UIBRoundedPath(CGRectMake(x + 9, y + 4, 14, 4), 2), UIBTheme("secondaryText"), nil);
            break;

        case "tabView":
            UIBFillStroke(UIBRoundedPath(CGRectMake(x + 2, y + 7, w - 4, h - 9), 3), UIBTheme("tile"), UIBTheme("secondaryText"), 1);
            UIBFillStroke(UIBRoundedPath(CGRectMake(cx - 13, y + 3, 13, 8), 2), UIBTheme("accent"), nil);
            UIBFillStroke(UIBRoundedPath(CGRectMake(cx, y + 3, 13, 8), 2), UIBTheme("tile"), UIBTheme("secondaryText"), 1);
            break;

        case "scrollView":
            UIBFillStroke([CPBezierPath bezierPathWithRect:CGRectMake(x + 3, y + 2, w - 6, h - 4)], UIBTheme("tile"), UIBTheme("secondaryText"), 1);
            UIBFillStroke(UIBRoundedPath(CGRectMake(x + w - 8, y + 5, 3, 10), 1.5), UIBTheme("secondaryText"), nil);
            for (var i = 0; i < 3; i++)
                UIBFillStroke(UIBRoundedPath(CGRectMake(x + 7, y + 6 + i * 6, w - 20, 2.5), 1), UIBRGB(0, 0, 0, 0.15), nil);
            break;

        case "splitView":
            UIBFillStroke([CPBezierPath bezierPathWithRect:CGRectMake(x + 3, y + 2, w - 6, h - 4)], UIBTheme("tile"), UIBTheme("secondaryText"), 1);
            UIBFillStroke([CPBezierPath bezierPathWithRect:CGRectMake(x + 3, y + 2, (w - 6) * 0.38, h - 4)], UIBRGB(0, 0, 0, 0.06), nil);
            [UIBTheme("secondaryText") setFill];
            [CPBezierPath fillRect:CGRectMake(x + 3 + (w - 6) * 0.38, y + 2, 1.5, h - 4)];
            break;

        case "tableView":
            UIBFillStroke([CPBezierPath bezierPathWithRect:CGRectMake(x + 3, y + 2, w - 6, h - 4)], UIBTheme("tile"), UIBTheme("secondaryText"), 1);
            [UIBTheme("header") setFill];
            [CPBezierPath fillRect:CGRectMake(x + 4, y + 3, w - 8, 6)];
            [UIBTheme("zebra") setFill];
            [CPBezierPath fillRect:CGRectMake(x + 4, y + 15, w - 8, 5)];
            [UIBTheme("controlBorder") setFill];
            [CPBezierPath fillRect:CGRectMake(cx - 4, y + 3, 1, h - 6)];
            [CPBezierPath fillRect:CGRectMake(x + 4, y + 9, w - 8, 1)];
            break;

        case "vbox":
        case "hbox":
            var vertical = aType === "vbox",
                frame = CGRectMake(x + 4, y + 2, w - 8, h - 4),
                dashed = [CPBezierPath bezierPathWithRect:frame];
            [dashed setLineDash:[2, 2] count:2 phase:0];
            UIBFillStroke(dashed, nil, UIBTheme("secondaryText"), 1);
            for (var i = 0; i < 3; i++)
            {
                var item = vertical ? CGRectMake(frame.origin.x + 4, frame.origin.y + 3 + i * 8, frame.size.width - 8, 5)
                                    : CGRectMake(frame.origin.x + 3 + i * ((frame.size.width - 6) / 3), frame.origin.y + 4, (frame.size.width - 6) / 3 - 3, frame.size.height - 8);
                UIBFillStroke(UIBRoundedPath(item, 1.5), UIBTheme("accent"), nil);
            }
            break;

        case "hspace":
        case "vspace":
            var spring = [CPBezierPath bezierPath],
                horizontal = aType === "hspace";
            if (horizontal)
            {
                [spring moveToPoint:CGPointMake(x + 5, cy - 6)]; [spring lineToPoint:CGPointMake(x + 5, cy + 6)];
                [spring moveToPoint:CGPointMake(x + w - 5, cy - 6)]; [spring lineToPoint:CGPointMake(x + w - 5, cy + 6)];
                [spring moveToPoint:CGPointMake(x + 7, cy)];
                for (var i = 1; i <= 8; i++)
                    [spring lineToPoint:CGPointMake(x + 7 + i * (w - 14) / 8, cy + ((i % 2) ? -4 : 4))];
            }
            else
            {
                [spring moveToPoint:CGPointMake(cx - 6, y + 2)]; [spring lineToPoint:CGPointMake(cx + 6, y + 2)];
                [spring moveToPoint:CGPointMake(cx - 6, y + h - 2)]; [spring lineToPoint:CGPointMake(cx + 6, y + h - 2)];
                [spring moveToPoint:CGPointMake(cx, y + 4)];
                for (var i = 1; i <= 6; i++)
                    [spring lineToPoint:CGPointMake(cx + ((i % 2) ? -4 : 4), y + 4 + i * (h - 8) / 6)];
            }
            [spring setLineWidth:1.5];
            [UIBTheme("accent") setStroke];
            [spring stroke];
            break;

        case "label":
            UIBDrawTextInRect("Aa", CGRectMake(x, y, w, h), UIBFont(17, YES), UIBTheme("text"), "center");
            break;

        case "textField":
        case "secureField":
        case "comboBox":
        case "searchField":
        case "datePicker":
            var field = CGRectMake(x + 2, cy - 8, w - 4, 16);
            UIBDrawFieldBezel(field, aType === "searchField" ? 8 : 3);
            if (aType === "textField")
            {
                [UIBTheme("text") setFill];
                [CPBezierPath fillRect:CGRectMake(x + 7, cy - 5, 1, 10)];
            }
            else if (aType === "secureField")
                for (var i = 0; i < 4; i++)
                    UIBFillStroke([CPBezierPath bezierPathWithOvalInRect:CGRectMake(x + 7 + i * 6, cy - 2, 4, 4)], UIBTheme("text"), nil);
            else if (aType === "searchField")
                UIBDrawMagnifier(CGPointMake(x + 6, cy - 4), 8, UIBTheme("secondaryText"));
            else if (aType === "comboBox")
            {
                var button = CGRectMake(x + w - 14, cy - 6, 10, 12);
                UIBFillStroke(UIBRoundedPath(button, 2.5), UIBTheme("accent"), nil);
                UIBDrawChevronDown(CGPointMake(CGRectGetMidX(button), CGRectGetMidY(button)), 2.5, [CPColor whiteColor]);
            }
            else
            {
                UIBDrawTextInRect("19.10.", CGRectMake(x + 5, cy - 8, w - 20, 16), UIBFont(8), UIBTheme("text"), "left");
                UIBFillStroke(UIBRoundedPath(CGRectMake(x + w - 13, cy - 4, 8, 8), 1.5), nil, UIBTheme("secondaryText"), 1);
            }
            break;

        case "textView":
            UIBFillStroke([CPBezierPath bezierPathWithRect:CGRectMake(x + 4, y + 2, w - 8, h - 4)], UIBTheme("tile"), UIBTheme("secondaryText"), 1);
            for (var i = 0; i < 4; i++)
                UIBFillStroke(UIBRoundedPath(CGRectMake(x + 8, y + 6 + i * 5, (i === 3) ? (w - 16) * 0.5 : w - 16, 2), 1), UIBRGB(0, 0, 0, 0.3), nil);
            break;

        case "button":
            UIBDrawBezel(CGRectMake(x + 3, cy - 8, w - 6, 16), 4, NO);
            UIBFillStroke(UIBRoundedPath(CGRectMake(x + 12, cy - 1, w - 24, 2.5), 1), UIBTheme("text"), nil);
            break;

        case "checkBox":
            var box = CGRectMake(cx - 8, cy - 8, 16, 16);
            UIBFillStroke(UIBRoundedPath(box, 4), UIBTheme("accent"), UIBTheme("accentDark"), 1);
            UIBDrawCheckMark(box, [CPColor whiteColor]);
            break;

        case "popUpButton":
            var bezel = CGRectMake(x + 2, cy - 8, w - 4, 16);
            UIBDrawBezel(bezel, 4, NO);
            var arrows = CGRectMake(bezel.origin.x + bezel.size.width - 12, bezel.origin.y + 2, 10, 12);
            UIBFillStroke(UIBRoundedPath(arrows, 2.5), UIBTheme("accent"), nil);
            UIBDrawChevronUpDown(CGPointMake(CGRectGetMidX(arrows), CGRectGetMidY(arrows)), 2, [CPColor whiteColor]);
            UIBFillStroke(UIBRoundedPath(CGRectMake(x + 7, cy - 1, w - 26, 2.5), 1), UIBTheme("text"), nil);
            break;

        case "stepper":
            var stepper = CGRectMake(cx - 6, cy - 11, 12, 22);
            UIBDrawBezel(stepper, 4, NO);
            UIBDrawChevronUpDown(CGPointMake(cx, cy), 2.5, UIBTheme("text"));
            break;

        case "slider":
            UIBFillStroke(UIBRoundedPath(CGRectMake(x + 3, cy - 1.5, w - 6, 3), 1.5), UIBTheme("track"), nil);
            UIBFillStroke(UIBRoundedPath(CGRectMake(x + 3, cy - 1.5, w * 0.5 - 3, 3), 1.5), UIBTheme("accent"), nil);
            var knob = [CPBezierPath bezierPathWithOvalInRect:CGRectMake(cx - 6, cy - 6, 12, 12)];
            UIBWithShadow(1, 2, UIBRGB(0, 0, 0, 0.3), function() { UIBFillStroke(knob, UIBTheme("controlFill"), nil); });
            UIBFillStroke(knob, nil, UIBTheme("controlBorder"), 0.5);
            break;

        case "progresIndicator":
            UIBFillStroke(UIBRoundedPath(CGRectMake(x + 3, cy - 3, w - 6, 6), 3), UIBTheme("track"), nil);
            UIBFillStroke(UIBRoundedPath(CGRectMake(x + 3, cy - 3, (w - 6) * 0.6, 6), 3), UIBTheme("accent"), nil);
            break;

        case "imageView":
            UIBFillStroke(UIBRoundedPath(CGRectMake(x + 6, y + 2, w - 12, h - 4), 3), UIBRGB(242, 244, 247), UIBTheme("secondaryText"), 1);
            UIBFillStroke([CPBezierPath bezierPathWithOvalInRect:CGRectMake(x + w - 17, y + 6, 5, 5)], UIBRGB(255, 196, 0), nil);
            var hills = [CPBezierPath bezierPath];
            [hills moveToPoint:CGPointMake(x + 7, y + h - 3)];
            [hills lineToPoint:CGPointMake(x + 17, y + 11)];
            [hills lineToPoint:CGPointMake(x + 24, y + 19)];
            [hills lineToPoint:CGPointMake(x + 29, y + 14)];
            [hills lineToPoint:CGPointMake(x + w - 7, y + h - 3)];
            [hills closePath];
            UIBFillStroke(hills, UIBRGB(120, 170, 120), nil);
            break;

        case "custom":
            var custom = UIBRoundedPath(CGRectMake(x + 3, y + 3, w - 6, h - 6), 4);
            [custom setLineDash:[3, 2] count:2 phase:0];
            UIBFillStroke(custom, UIBRGB(140, 90, 205, 0.1), UIBRGB(140, 90, 205), 1);
            UIBDrawTextInRect("</>", CGRectMake(x, y, w, h), UIBFont(11, YES), UIBRGB(110, 60, 170), "center");
            break;

        default:
            UIBFillStroke(UIBRoundedPath(CGRectInset(aRect, 4, 4), 4), UIBTheme("controlFillLow"), UIBTheme("controlBorder"), 1);
    }
};


// Switching a split view between side by side and stacked re-lays out its panes.
@implementation UISplitViewView (UIBOrientation)

- (void)observeValueForKeyPath:(CPString)keyPath ofObject:(id)object change:(CPDictionary)change context:(id)context
{
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];

    if (keyPath === @"vertical")
    {
        var subviews = [self subviews];
        for (var i = 0; i < subviews.length; i++)
        {
            [subviews[i] setNeedsLayout:YES];
            [subviews[i] setNeedsDisplay:YES];
        }
    }
}

@end

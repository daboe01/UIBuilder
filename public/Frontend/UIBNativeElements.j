//
//  UIBNativeElements.j
//  "Run": real Cappuccino views for every element on the canvas.
//
//  Every element view builds its native counterpart in
//  -nativeUIElementWithMap:. Boxes become UIBNativeBoxView, which lays out
//  its children with the same rules as the canvas (and keeps doing so when a
//  preview window is resized). The map collects all natives by element id,
//  so connections can be applied afterwards.
//
//  Imported after all view classes; the categories replace the earlier
//  per-class implementations.
//

@import "UIElementView.j"


#pragma mark - Native Box

/*!
    A vbox/hbox at runtime: stacks its subviews like the canvas does, using
    the alignment and preferred size each child carried over from the canvas
    (child._uibLayout = { halign, valign, width, height }).
*/
@implementation UIBNativeBoxView : CPView
{
    BOOL    _isVertical;
    float   _padding;
}

- (id)initWithFrame:(CGRect)aFrame vertical:(BOOL)isVertical
{
    self = [super initWithFrame:aFrame];
    if (self)
    {
        _isVertical = isVertical;
        _padding = UIBStackPadding;
    }
    return self;
}

- (void)setVertical:(BOOL)isVertical
{
    _isVertical = isVertical;
    [self layoutNativeChildren];
}

- (void)resizeSubviewsWithOldSize:(CGSize)aSize
{
    [self layoutNativeChildren];
}

- (void)layoutNativeChildren
{
    var bounds = CGRectInset([self bounds], _padding, _padding),
        views = [self subviews],
        mainAlignKey = _isVertical ? "valign" : "halign",
        crossAlignKey = _isVertical ? "halign" : "valign",
        available = _isVertical ? bounds.size.height : bounds.size.width,
        crossAvailable = _isVertical ? bounds.size.width : bounds.size.height,
        fixedTotal = 0,
        expanders = 0;

    for (var i = 0; i < views.length; i++)
    {
        var info = views[i]._uibLayout;
        if (!info)
            continue;

        if (UIBAlignKind(info[mainAlignKey]) === "expand")
            expanders++;
        else
            fixedTotal += _isVertical ? info.height : info.width;
    }

    var flexible = expanders ? MAX(0, (available - fixedTotal) / expanders) : 0,
        position = _isVertical ? bounds.origin.y : bounds.origin.x,
        crossStart = _isVertical ? bounds.origin.x : bounds.origin.y;

    for (var i = 0; i < views.length; i++)
    {
        var view = views[i],
            info = view._uibLayout;

        if (!info)
            continue;

        var mainSize = (UIBAlignKind(info[mainAlignKey]) === "expand") ? flexible : (_isVertical ? info.height : info.width),
            crossKind = UIBAlignKind(info[crossAlignKey]),
            crossPreferred = _isVertical ? info.width : info.height,
            crossSize = (crossKind === "expand") ? crossAvailable : MIN(crossPreferred, MAX(0, crossAvailable)),
            offset = 0;

        if (crossKind === "center")
            offset = (crossAvailable - crossSize) / 2;
        else if (crossKind === "max")
            offset = crossAvailable - crossSize;

        [view setFrame:_isVertical ? CGRectMake(crossStart + offset, position, crossSize, mainSize)
                                   : CGRectMake(position, crossStart + offset, mainSize, crossSize)];
        position += mainSize;
    }
}

@end


// Shown for elements that have no Cappuccino class (your own tags, …).
@implementation UIBNativePlaceholderView : CPView
{
    CPString _caption;
}

- (void)setCaption:(CPString)aCaption
{
    _caption = aCaption;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(CGRect)aRect
{
    var bounds = CGRectInset([self bounds], 0.5, 0.5),
        path = [CPBezierPath bezierPathWithRoundedRect:bounds xRadius:3 yRadius:3];

    [[CPColor colorWithCalibratedRed:0.55 green:0.35 blue:0.8 alpha:0.08] setFill];
    [path fill];
    [path setLineDash:[4, 2] count:2 phase:0];
    [[CPColor colorWithCalibratedRed:0.55 green:0.35 blue:0.8 alpha:0.6] setStroke];
    [path stroke];

    if (_caption)
        UIBDrawTextInRect(_caption, CGRectInset(bounds, 6, 0), [CPFont systemFontOfSize:11], [CPColor colorWithCalibratedRed:0.4 green:0.2 blue:0.6 alpha:1.0], "center");
}

@end


#pragma mark - Helpers

function UIBBool(aValue, aDefault)
{
    if (aValue === nil || aValue === undefined || aValue === "")
        return aDefault;
    if (typeof aValue === "string")
        return /^(yes|true|1)$/i.test(aValue);
    return !!aValue;
}

function UIBNumber(aValue, aDefault)
{
    var number = Number(aValue);
    return (aValue === nil || aValue === undefined || aValue === "" || isNaN(number)) ? aDefault : number;
}

// Titles of child items in preserved raw markup (<segmentedControlItem title="…"/> …).
function UIBRawItemTitles(aData, aTag)
{
    var raw = [aData valueForKey:@"rawChildren"] || [],
        result = [],
        pattern = new RegExp("<" + aTag + "\\b[^>]*\\btitle=\"([^\"]*)\"", "g");

    for (var i = 0; i < raw.length; i++)
    {
        var match;
        pattern.lastIndex = 0;
        while ((match = pattern.exec(raw[i])) !== null)
            result.push(match[1].replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\""));
    }
    return result;
}

function UIBClassNamed(aName)
{
    return (typeof objj_getClass === "function") ? objj_getClass(aName) : nil;
}

function UIBNativeFont(anExtras, aDefaultSize)
{
    var size = UIBNumber(anExtras.size, aDefaultSize || 12);
    return /bold/i.test(anExtras.font || "") ? [CPFont boldSystemFontOfSize:size] : [CPFont systemFontOfSize:size];
}

function UIBNativeColor(aString)
{
    if (!aString)
        return nil;

    if (String(aString).charAt(0) === "#")
        return [CPColor colorWithHexString:String(aString).substring(1)];

    var named = { white: [CPColor whiteColor], black: [CPColor blackColor], gray: [CPColor grayColor], red: [CPColor redColor],
                  blue: [CPColor blueColor], green: [CPColor greenColor], yellow: [CPColor yellowColor], clear: [CPColor clearColor] };
    return named[String(aString).toLowerCase()] || nil;
}


#pragma mark - Native Elements

@implementation UIElementView (UIBNative)

// The natives of the element children (for containers).
- (CPArray)_uib_nativeChildrenWithMap:(CPMutableDictionary)aMap
{
    var result = [],
        subviews = [self subviews];

    for (var i = 0; i < subviews.length; i++)
        if ([subviews[i] isKindOfClass:[UIElementView class]])
        {
            var native = [subviews[i] nativeUIElementWithMap:aMap];
            if (native)
                result.push(native);
        }

    return result;
}

// A native box holding the children of this element.
- (UIBNativeBoxView)_uib_nativeBoxWithMap:(CPMutableDictionary)aMap vertical:(BOOL)isVertical
{
    var box = [[UIBNativeBoxView alloc] initWithFrame:[self bounds] vertical:isVertical],
        children = [self _uib_nativeChildrenWithMap:aMap];

    for (var i = 0; i < children.length; i++)
        [box addSubview:children[i]];

    [box layoutNativeChildren];
    return box;
}

// The single content view of windows, scroll views, boxes, tab items, …
- (CPView)_uib_nativeContentWithMap:(CPMutableDictionary)aMap
{
    var children = [self _uib_nativeChildrenWithMap:aMap];

    if (children.length === 1)
        return children[0];

    var box = [[UIBNativeBoxView alloc] initWithFrame:[self bounds] vertical:YES];
    for (var i = 0; i < children.length; i++)
        [box addSubview:children[i]];
    [box layoutNativeChildren];
    return box;
}

- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap
{
    var data = [self dataObject],
        native = [self _uib_makeNativeWithMap:aMap];

    if (!native)
        return nil;

    // Layout information for the enclosing box
    var preferred = [self preferredLayoutSize];
    native._uibLayout = {
        halign: [data valueForKey:@"halign"],
        valign: [data valueForKey:@"valign"],
        width: preferred.width,
        height: preferred.height
    };

    if (!CGRectEqualToRect([native frame], [self frame]) && ![native isKindOfClass:[CPWindow class]])
        [native setFrame:[self frame]];

    var extras = [data valueForKey:@"extraAttributes"] || {};

    if ([native respondsToSelector:@selector(setEnabled:)] && ([data valueForKey:@"enabled"] === false || /^no$/i.test(extras.enabled || "")))
        [native setEnabled:NO];

    if (extras.toolTip && [native respondsToSelector:@selector(setToolTip:)])
        [native setToolTip:extras.toolTip];

    var background = UIBNativeColor(extras.backgroundColor);
    if (background && [native isKindOfClass:[CPView class]] && ![native isKindOfClass:[CPControl class]])
        [native setBackgroundColor:background];

    if (aMap)
        [aMap setObject:native forKey:[data valueForKey:@"id"]];

    return native;
}

- (id)_uib_makeNativeWithMap:(CPMutableDictionary)aMap
{
    var data = [self dataObject],
        type = [data valueForKey:@"type"],
        extras = [data valueForKey:@"extraAttributes"] || {},
        frame = [self frame],
        value = [data valueForKey:@"value"];

    switch (type)
    {
        case "owner":
            return nil;

        case "vbox":
        case "tabViewItem":
            return [self _uib_nativeBoxWithMap:aMap vertical:YES];

        case "hbox":
            return [self _uib_nativeBoxWithMap:aMap vertical:NO];

        case "hspace":
        case "vspace":
            return [[CPView alloc] initWithFrame:frame];

        case "label":
            var label = [[CPTextField alloc] initWithFrame:frame];
            [label setStringValue:value || @""];
            [label setBezeled:NO];
            [label setDrawsBackground:NO];
            [label setEditable:NO];
            [label setSelectable:UIBBool([data valueForKey:@"selectable"], NO)];
            [label setFont:UIBNativeFont(extras, 12)];
            [label setVerticalAlignment:CPCenterVerticalTextAlignment];
            [label setAlignment:{ center: CPCenterTextAlignment, right: CPRightTextAlignment }[[data valueForKey:@"horizontalTextAlign"]] || CPLeftTextAlignment];
            var textColor = UIBNativeColor([data valueForKey:@"color"]);
            if (textColor)
                [label setTextColor:textColor];
            return label;

        case "textField":
        case "secureField":
        case "searchField":
            var fieldClass = (type === "secureField") ? CPSecureTextField : (type === "searchField" ? CPSearchField : CPTextField),
                field = [[fieldClass alloc] initWithFrame:frame];
            [field setStringValue:value || @""];
            [field setEditable:UIBBool([data valueForKey:@"editable"], YES)];
            [field setSelectable:UIBBool([data valueForKey:@"selectable"], YES)];
            [field setBezeled:UIBBool([data valueForKey:@"bezeled"], YES)];
            if (type !== "searchField")
                [field setBezelStyle:CPTextFieldSquareBezel];
            if (extras.placeholder || extras.placeholderString)
                [field setPlaceholderString:extras.placeholder || extras.placeholderString];
            return field;

        case "comboBox":
            var combo = [[CPComboBox alloc] initWithFrame:frame];
            [combo addItemsWithObjectValues:UIBSplitList([data valueForKey:@"items"])];
            [combo setStringValue:value || @""];
            [combo setCompletes:UIBBool([data valueForKey:@"completes"], NO)];
            [combo setEditable:UIBBool([data valueForKey:@"isEditable"], YES)];
            return combo;

        case "textView":
            var textView = [[CPTextView alloc] initWithFrame:frame];
            [textView setString:value || @""];
            [textView setEditable:UIBBool([data valueForKey:@"editable"], YES)];
            if (extras.font)
                [textView setFont:UIBNativeFont(extras, 12)];
            return textView;

        case "button":
            var button = [[CPButton alloc] initWithFrame:frame];
            [button setTitle:value || @""];
            var keyEquivalent = [data valueForKey:@"keyEquivalent"];
            if (keyEquivalent)
                [button setKeyEquivalent:(keyEquivalent === "\\r" ? CPCarriageReturnCharacter : keyEquivalent)];
            return button;

        case "checkBox":
            var checkBox = [[CPCheckBox alloc] initWithFrame:frame];
            [checkBox setTitle:[data valueForKey:@"title"] || @""];
            [checkBox setState:[data valueForKey:@"value"] ? CPOnState : CPOffState];
            return checkBox;

        case "slider":
            var slider = [[CPSlider alloc] initWithFrame:frame];
            [slider setMinValue:UIBNumber([data valueForKey:@"minValue"], 0)];
            [slider setMaxValue:UIBNumber([data valueForKey:@"maxValue"], 100)];
            [slider setDoubleValue:UIBNumber(value, 0)];
            [slider setContinuous:UIBBool([data valueForKey:@"continuous"], YES)];
            return slider;

        case "stepper":
            var stepper = [[CPStepper alloc] initWithFrame:frame];
            [stepper setMinValue:UIBNumber([data valueForKey:@"minValue"], 0)];
            [stepper setMaxValue:UIBNumber([data valueForKey:@"maxValue"], 100)];
            [stepper setIncrement:UIBNumber([data valueForKey:@"increment"], 1)];
            [stepper setDoubleValue:UIBNumber(value, 0)];
            return stepper;

        case "popUpButton":
            var popUp = [[CPPopUpButton alloc] initWithFrame:frame pullsDown:UIBBool([data valueForKey:@"pullsDown"], NO)];
            [popUp addItemsWithTitles:UIBSplitList([data valueForKey:@"items"])];
            return popUp;

        case "datePicker":
            var picker = [[CPDatePicker alloc] initWithFrame:frame];
            if ([data valueForKey:@"style"] === "graphical")
                [picker setDatePickerStyle:CPClockAndCalendarDatePickerStyle];
            else
                [picker setDatePickerStyle:CPTextFieldAndStepperDatePickerStyle];
            [picker setDateValue:[CPDate date]];
            return picker;

        case "progresIndicator":
        case "progressIndicator":
            var progress = [[CPProgressIndicator alloc] initWithFrame:frame],
                indeterminate = UIBBool([data valueForKey:@"isIndeterminate"], NO);
            [progress setStyle:(indeterminate && frame.size.width <= frame.size.height * 2) ? CPProgressIndicatorSpinningStyle : CPProgressIndicatorBarStyle];
            [progress setIndeterminate:indeterminate];
            [progress setMinValue:0];
            [progress setMaxValue:UIBNumber([data valueForKey:@"maxValue"], 100)];
            [progress setDoubleValue:UIBNumber(value, 45)];
            if (indeterminate)
                [progress startAnimation:self];
            return progress;

        case "imageView":
            var imageView = [[CPImageView alloc] initWithFrame:frame],
                source = extras.image || extras.src || (/\.(png|jpe?g|gif|svg)$/i.test(value || "") ? value : nil);
            [imageView setImageScaling:CPImageScaleProportionallyUpOrDown];
            if (source)
                [imageView setImage:[[CPImage alloc] initWithContentsOfFile:source]];
            return imageView;

        case "tableView":
            var table = [[CPTableView alloc] initWithFrame:frame],
                columns = UIBSplitList([data valueForKey:@"columns"]),
                columnWidth = columns.length ? MAX(40, Math.floor(frame.size.width / columns.length) - 4) : 100;
            for (var i = 0; i < columns.length; i++)
            {
                var column = [[CPTableColumn alloc] initWithIdentifier:columns[i]];
                [[column headerView] setStringValue:columns[i]];
                [column setWidth:columnWidth];
                [table addTableColumn:column];
            }
            [table setUsesAlternatingRowBackgroundColors:UIBBool(extras.zebra, NO)];
            [table setAllowsMultipleSelection:UIBBool(extras.allowsMultipleSelection, NO)];
            return table;

        case "scrollView":
            // The document view is the content of the root box (usually one table or text view).
            var scrollView = [[CPScrollView alloc] initWithFrame:frame],
                rootView = nil,
                scrollSubviews = [self subviews];

            for (var i = 0; i < scrollSubviews.length; i++)
                if ([scrollSubviews[i] isKindOfClass:[UIElementView class]])
                    rootView = scrollSubviews[i];

            var document = rootView ? [rootView _uib_nativeContentWithMap:aMap] : nil;
            [scrollView setHasHorizontalScroller:UIBBool([data valueForKey:@"hasHorizontalScroller"], YES)];
            [scrollView setHasVerticalScroller:UIBBool([data valueForKey:@"hasVerticalScroller"], YES)];
            [scrollView setAutohidesScrollers:YES];
            if (document)
            {
                var documentFrame = [[scrollView contentView] bounds];
                if (![document isKindOfClass:[CPTableView class]] && ![document isKindOfClass:[CPTextView class]])
                    documentFrame.size.height = MAX(documentFrame.size.height, [document frame].size.height);
                [document setFrame:documentFrame];
                [document setAutoresizingMask:CPViewWidthSizable];
                [scrollView setDocumentView:document];
            }
            return scrollView;

        case "splitView":
            var split = [[CPSplitView alloc] initWithFrame:frame],
                rootChildren = [];
            [split setVertical:UIBBool([data valueForKey:@"vertical"], NO)];

            // The panes are the children of the root box.
            var subviews = [self subviews];
            for (var i = 0; i < subviews.length; i++)
                if ([subviews[i] isKindOfClass:[UIElementView class]])
                    rootChildren = rootChildren.concat([subviews[i] _uib_nativeChildrenWithMap:aMap]);

            for (var i = 0; i < rootChildren.length; i++)
                [split addSubview:rootChildren[i]];

            [split adjustSubviews];
            return split;

        case "box":
            var nativeBox = [[CPBox alloc] initWithFrame:frame],
                title = [data valueForKey:@"title"],
                content = [self _uib_nativeContentWithMap:aMap];
            if ([nativeBox respondsToSelector:@selector(setTitle:)])
                [nativeBox setTitle:title || @""];
            if ([nativeBox respondsToSelector:@selector(setTitlePosition:)])
                [nativeBox setTitlePosition:(title ? CPAtTop : CPNoTitle)];
            [nativeBox setBorderType:UIBBool([data valueForKey:@"hasBorder"], YES) ? CPBezelBorder : CPNoBorder];
            if (content)
            {
                [content setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
                [nativeBox setContentView:content];
            }
            return nativeBox;

        case "tabView":
            var tabView = [[CPTabView alloc] initWithFrame:frame],
                items = [self subviews];
            for (var i = 0; i < items.length; i++)
            {
                if (![items[i] isKindOfClass:[UIElementView class]])
                    continue;

                var item = [[CPTabViewItem alloc] initWithIdentifier:[[items[i] dataObject] valueForKey:@"id"]],
                    itemView = [items[i] nativeUIElementWithMap:aMap];
                [item setLabel:[[items[i] dataObject] valueForKey:@"value"] || @"Tab"];
                [itemView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
                [item setView:itemView];
                [tabView addTabViewItem:item];
            }
            return tabView;

        case "custom":
            return [self _uib_makeCustomNativeWithMap:aMap];
    }

    // Anything else: a container becomes a box, a leaf a placeholder.
    if (_isContainer)
        return [self _uib_nativeBoxWithMap:aMap vertical:YES];

    var placeholder = [[UIBNativePlaceholderView alloc] initWithFrame:frame];
    [placeholder setCaption:"<" + type + ">"];
    return placeholder;
}

// Cappusance tags that are not builder types but have Cappuccino classes.
- (id)_uib_makeCustomNativeWithMap:(CPMutableDictionary)aMap
{
    var data = [self dataObject],
        tag = [data valueForKey:@"markupTag"] || "view",
        extras = [data valueForKey:@"extraAttributes"] || {},
        frame = [self frame],
        lowerTag = tag.toLowerCase();

    if (lowerTag === "buttonbar" && UIBClassNamed("CPButtonBar"))
    {
        var bar = [[CPButtonBar alloc] initWithFrame:frame],
            plus = [CPButtonBar plusButton],
            minus = [CPButtonBar minusButton],
            buttons = [plus, minus];

        var barTarget = [UIBRunOwner ownerForReference:extras.target];
        [plus setTarget:barTarget];
        [plus setAction:[UIBRunOwner selectorForAction:extras.plusButtonAction || "insert:"]];
        [minus setTarget:barTarget];
        [minus setAction:[UIBRunOwner selectorForAction:extras.minusButtonAction || "remove:"]];

        if (UIBBool(extras.actionsButton, NO) && [CPButtonBar respondsToSelector:@selector(actionPopupButton)])
        {
            var actions = [CPButtonBar actionPopupButton],
                titles = UIBRawItemTitles(data, "popUpButtonItem");
            [actions addItemsWithTitles:titles];
            buttons.push(actions);
        }

        if ([bar respondsToSelector:@selector(setHasResizeControl:)])
            [bar setHasResizeControl:NO];
        [bar setButtons:buttons];
        return bar;
    }

    if (lowerTag === "segmentedcontrol" && UIBClassNamed("CPSegmentedControl"))
    {
        var segmented = [[CPSegmentedControl alloc] initWithFrame:frame],
            titles = UIBRawItemTitles(data, "segmentedControlItem");

        [segmented setSegmentCount:titles.length];
        for (var i = 0; i < titles.length; i++)
        {
            [segmented setLabel:titles[i] forSegment:i];
            [segmented setWidth:MAX(40, [titles[i] sizeWithFont:[CPFont systemFontOfSize:12]].width + 20) forSegment:i];
        }
        if (titles.length)
            [segmented setSelectedSegment:0];
        [segmented sizeToFit];
        return segmented;
    }

    if (lowerTag === "levelindicator" && UIBClassNamed("CPLevelIndicator"))
    {
        var level = [[CPLevelIndicator alloc] initWithFrame:frame];
        [level setMinValue:UIBNumber(extras.min, 0)];
        [level setMaxValue:UIBNumber(extras.max, 100)];
        if (extras.critical && [level respondsToSelector:@selector(setCriticalValue:)])
            [level setCriticalValue:UIBNumber(extras.critical, 0)];
        [level setDoubleValue:UIBNumber(extras.max, 100) * 0.4];
        return level;
    }

    if (lowerTag === "collectionview" && UIBClassNamed("CPCollectionView"))
        return [[CPCollectionView alloc] initWithFrame:frame];

    if (lowerTag === "outlineview" && UIBClassNamed("CPOutlineView"))
        return [[CPOutlineView alloc] initWithFrame:frame];

    // A class of your own that is loaded in the builder: instantiate it.
    var customClass = UIBClassNamed(tag);
    if (customClass && [customClass isSubclassOfClass:[CPView class]])
        return [[customClass alloc] initWithFrame:frame];

    var placeholder = [[UIBNativePlaceholderView alloc] initWithFrame:frame];
    [placeholder setCaption:"<" + tag + ">"];
    return placeholder;
}

@end


// Classes that had their own (simpler) implementation use the shared one.
@implementation UIButtonView (UIBNative)
- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap { return [super nativeUIElementWithMap:aMap]; }
@end

@implementation UISliderView (UIBNative)
- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap { return [super nativeUIElementWithMap:aMap]; }
@end

@implementation UITextFieldView (UIBNative)
- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap { return [super nativeUIElementWithMap:aMap]; }
@end

@implementation UILabelView (UIBNative)
- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap { return [super nativeUIElementWithMap:aMap]; }
@end

@implementation UICheckBoxView (UIBNative)
- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap { return [super nativeUIElementWithMap:aMap]; }
@end


@implementation UIWindowView (UIBNative)

// A real window inside the page. Its content is the native root box.
- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap
{
    var data = [self dataObject],
        frame = [self frame],
        titleBarHeight = 22.0,
        styleMask = CPTitledWindowMask;

    if (UIBBool([data valueForKey:@"closable"], YES)) styleMask |= CPClosableWindowMask;
    if (UIBBool([data valueForKey:@"resizable"], YES)) styleMask |= CPResizableWindowMask;
    if (UIBBool([data valueForKey:@"miniaturizable"], YES)) styleMask |= CPMiniaturizableWindowMask;

    var window = [[CPWindow alloc] initWithContentRect:CGRectMake(0, 0, frame.size.width, MAX(40, frame.size.height - titleBarHeight)) styleMask:styleMask];
    [window setTitle:[data valueForKey:@"value"] || @""];

    var content = [self _uib_nativeContentWithMap:aMap],
        contentView = [window contentView];

    if (content)
    {
        [content setFrame:[contentView bounds]];
        [content setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
        [contentView addSubview:content];
        if ([content respondsToSelector:@selector(layoutNativeChildren)])
            [content layoutNativeChildren];
    }

    if (aMap)
        [aMap setObject:window forKey:[data valueForKey:@"id"]];

    return window;
}

@end


@implementation UIOwnerView (UIBNative)
- (id)nativeUIElementWithMap:(CPMutableDictionary)aMap { return nil; }
@end


#pragma mark - The Owner while Running

/*!
    Stands in for #CPOwner in a preview: every action it receives is logged
    (the methods are added on demand), so you can check the wiring.
*/
// Stand-ins of the current preview, by reference ("#CPOwner", "#CPOwner.listController", …)
var UIBRunOwners = {},
    UIBRunLogFunction = nil;

@implementation UIBRunOwner : CPObject
{
    Function _logger;
}

// Starts a new preview: forgets the old stand-ins and sets where log lines go.
+ (void)resetWithLogger:(Function)aFunction
{
    UIBRunOwners = {};
    UIBRunLogFunction = aFunction;
}

// One stand-in per reference: "#CPOwner", "#CPOwner.listController", …
+ (UIBRunOwner)ownerForReference:(CPString)aReference
{
    var reference = aReference || "#CPOwner";
    if (reference.charAt(0) !== "#")
        reference = "#" + reference;

    if (!UIBRunOwners[reference])
    {
        var owner = [[UIBRunOwner alloc] init];
        owner._uibTarget = reference;
        [owner setLogger:UIBRunLogFunction];
        UIBRunOwners[reference] = owner;
    }

    return UIBRunOwners[reference];
}

// Makes the stand-ins answer anAction (the method logs the call) and returns its selector.
+ (SEL)selectorForAction:(CPString)anAction
{
    var selector = CPSelectorFromString(anAction);

    if (![self instancesRespondToSelector:selector])
    {
        class_addMethod(self, selector, function(aStandIn, aSelector, sender)
        {
            var senderDescription = sender ? [sender className] : "nil",
                title = (sender && [sender respondsToSelector:@selector(title)]) ? [sender title] : nil;

            if (title)
                senderDescription += " “" + title + "”";

            [aStandIn log:(aStandIn._uibTarget || "#CPOwner") + "  " + CPStringFromSelector(aSelector) + "  ← " + senderDescription];
        }, "");
    }

    return selector;
}

- (void)setLogger:(Function)aFunction
{
    _logger = aFunction;
}

- (void)log:(CPString)aMessage
{
    if (_logger)
        _logger(aMessage);
    else
        console.log(aMessage);
}

@end

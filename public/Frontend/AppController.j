//
//  AppController.j
//  Main application controller. Sets up the window, canvas, palette,
//  and controllers on launch.
//

@import <Foundation/CPObject.j>
@import "UIBuilderController.j"
@import "UICanvasView.j"
@import "UIElementView.j";
@import "InspectorController.j";

var CGSizeZero = CGSizeMake(0, 0);

@implementation CPColor (StandardColors)

// A standard light gray for control backgrounds, like buttons.
+ (CPColor)controlColor
{
    return [CPColor colorWithCalibratedWhite:0.9 alpha:1.0];
}

// A medium gray for shadows or borders.
+ (CPColor)controlShadowColor
{
    return [CPColor grayColor];
}

// A dark gray for text on light controls.
+ (CPColor)controlDarkShadowColor
{
    return [CPColor darkGrayColor];
}

// The primary color for selected items.
+ (CPColor)selectedControlColor
{
    // Corresponds to the default blue selection color in macOS.
    return [CPColor colorWithCalibratedRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}

// A secondary selection color, often used for inactive windows or rubber-band selections.
+ (CPColor)alternateSelectedControlColor
{
    return [CPColor colorWithCalibratedRed:0.2 green:0.5 blue:0.9 alpha:1.0];
}

// The color for an inactive or secondary selection, like a window title bar.
+ (CPColor)secondarySelectedControlColor
{
    return [CPColor lightGrayColor];
}

// The highlight color for an element that has keyboard focus.
+ (CPColor)keyboardFocusIndicatorColor
{
    return [CPColor colorWithCalibratedRed:0.3 green:0.6 blue:1.0 alpha:1.0];
}

// The standard background color for a window's content area.
+ (CPColor)windowBackgroundColor
{
    return [CPColor colorWithCalibratedWhite:0.93 alpha:1.0];
}

// The background color for text-editing views.
+ (CPColor)textBackgroundColor
{
    return [CPColor whiteColor];
}

@end

// Required additions from original EFView.j for graphics and text handling
@implementation CPString(SizingAddition)
- (CPSize)sizeWithAttributes:(CPDictionary)stringAttributes
{
    var font = [stringAttributes objectForKey:CPFontAttributeName] || [CPFont systemFontOfSize:12];
    // This is a simplified implementation. For more complex text, you might need a more robust solution.
    var ctx = [[CPGraphicsContext currentContext] graphicsPort];
    var oldFont = ctx.font;
    ctx.font = [font cssString];
    var metrics = ctx.measureText(self);
    ctx.font = oldFont;
    return CGSizeMake(metrics.width, [[font fontDescriptor] pointSize]);
}
- (void)drawAtPoint:(CGPoint)aPoint withAttributes:(CPDictionary)attributes
{
    var ctx = [[CPGraphicsContext currentContext] graphicsPort];
    var font = [attributes objectForKey:CPFontAttributeName] || [CPFont systemFontOfSize:12];
    var color = [attributes objectForKey:CPForegroundColorAttributeName] || [CPColor blackColor];

    ctx.font = [font cssString];
    [color setFill];
    ctx.fillText(self, aPoint.x, aPoint.y + [[font fontDescriptor] pointSize]);
}
@end

@implementation CPBezierPath(RoundedRectangle)
+ (CPBezierPath)bezierPathWithRoundedRect:(CPRect)aRect radius:(float)radius
{
    return [self bezierPathWithRoundedRect:aRect xRadius:radius yRadius:radius];
}
@end



// A simple draggable symbol for the palette
@implementation DraggableSymbolView : CPView
{
    CPString _dragType;
    CPString _elementType;
}

- (void)setDragType:(CPString)aType
{
    _dragType = aType;
}

- (void)setElementType:(CPString)anElementType
{
    _elementType = anElementType;
}

- (CGSize)size
{
    return [self bounds].size;
}

-(BOOL)acceptsFirstMouse:(CPEvent)aEvent
{
    return YES;
}

- (void)mouseDown:(CPEvent)theEvent
{
    // 1. Create a placeholder view that is a visual copy of this one.
    var dragPlaceholder = [[DraggableSymbolView alloc] initWithFrame:[self bounds]];
    [dragPlaceholder setDragType:_dragType]; // Ensure it can draw its title correctly
    [dragPlaceholder setAlphaValue:0.75]; // Make it semi-transparent for good UX

    var pasteboard = [CPPasteboard pasteboardWithName:CPDragPboard];
    [pasteboard declareTypes:[_dragType] owner:nil];
    [pasteboard setString:@"1" forType:_dragType];

    [self dragView:dragPlaceholder
                at:[self bounds].origin
            offset:nil
             event:theEvent
        pasteboard:pasteboard
            source:self
         slideBack:YES];
}

// The drawRect: method defines what the view looks like, and therefore
// what the dragged placeholder view will look like.
- (void)drawRect:(CGRect)rect
{
    var bounds = [self bounds];

    // Background
    [[CPColor controlColor] set];
    [CPBezierPath fillRect:bounds];
    [[CPColor controlShadowColor] set];
    [CPBezierPath strokeRect:bounds];

    if ([_dragType isEqualToString:UIWindowDragType])
    {
        // Draw a window
        var windowRect = CGRectInset(bounds, 5, 5);
        var titleBarHeight = 10;

        // Draw the title bar
        var titleBarRect = CGRectMake(windowRect.origin.x, windowRect.origin.y, windowRect.size.width, titleBarHeight);
        [[CPColor grayColor] set];
        [CPBezierPath fillRect:titleBarRect];

        // Draw the content area
        var contentRect = CGRectMake(windowRect.origin.x, windowRect.origin.y + titleBarHeight, windowRect.size.width, windowRect.size.height - titleBarHeight);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:contentRect];

        // Draw the border for the whole window
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:windowRect];
    }
    else if ([_dragType isEqualToString:UIButtonDragType])
    {
        // Draw a button
        var buttonRect = CGRectInset(bounds, 8, 10);
        var path = [CPBezierPath bezierPathWithRoundedRect:buttonRect radius:5];
        [[CPColor whiteColor] set];
        [path fill];
        [[CPColor blackColor] set];
        [path stroke];
    }
    else if ([_dragType isEqualToString:UISliderDragType])
    {
        // Draw a slider
        var sliderY = bounds.size.height / 2;
        var path = [CPBezierPath bezierPath];
        [path moveToPoint:CGPointMake(bounds.origin.x + 5, sliderY)];
        [path lineToPoint:CGPointMake(bounds.origin.x + bounds.size.width - 5, sliderY)];
        [[CPColor blackColor] set];
        [path stroke];

        var knobRect = CGRectMake(bounds.size.width / 2 - 5, sliderY - 5, 10, 10);
        var knobPath = [CPBezierPath bezierPathWithOvalInRect:knobRect];
        [[CPColor whiteColor] set];
        [knobPath fill];
        [[CPColor blackColor] set];
        [knobPath stroke];
    }
    else if ([_dragType isEqualToString:UITextFieldDragType])
    {
        // Draw a text field
        var fieldRect = CGRectInset(bounds, 5, 12);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:fieldRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:fieldRect];

        // Draw an I-beam cursor
        var ibeamX = CGRectGetMidX(fieldRect);
        var ibeamY1 = CGRectGetMinY(fieldRect) + 3;
        var ibeamY2 = CGRectGetMaxY(fieldRect) - 3;

        var ibeamPath = [CPBezierPath bezierPath];
        [ibeamPath moveToPoint:CGPointMake(ibeamX, ibeamY1)];
        [ibeamPath lineToPoint:CGPointMake(ibeamX, ibeamY2)];
        [ibeamPath moveToPoint:CGPointMake(ibeamX - 2, ibeamY1)];
        [ibeamPath lineToPoint:CGPointMake(ibeamX + 2, ibeamY1)];
        [ibeamPath moveToPoint:CGPointMake(ibeamX - 2, ibeamY2)];
        [ibeamPath lineToPoint:CGPointMake(ibeamX + 2, ibeamY2)];
        
        [ibeamPath setLineWidth:0.5];
        [[CPColor blackColor] set];
        [ibeamPath stroke];
    }
    else if ([_dragType isEqualToString:UICheckBoxDragType])
    {
        var boxRect = CGRectInset(bounds, 12, 12);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:boxRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:boxRect];
    }
    else if ([_dragType isEqualToString:UILabelDragType])
    {
        var text = "Label";
        var textAttributes = @{
            CPFontAttributeName: [CPFont systemFontOfSize:10],
            CPForegroundColorAttributeName: [CPColor blackColor]
        };
        var textSize = [text sizeWithAttributes:textAttributes];
        [text drawAtPoint:CGPointMake((bounds.size.width - textSize.width) / 2, (bounds.size.height - textSize.height) / 2) withAttributes:textAttributes];
    }
    else if ([_dragType isEqualToString:UISearchFieldDragType])
    {
        var fieldRect = CGRectInset(bounds, 5, 12);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:fieldRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:fieldRect];
        var iconRect = CGRectMake(8, 14, 8, 8);
        [[CPColor grayColor] setStroke];
        var path = [CPBezierPath bezierPathWithOvalInRect:CGRectMake(iconRect.origin.x, iconRect.origin.y, 6, 6)];
        [path moveToPoint:CGPointMake(iconRect.origin.x + 5, iconRect.origin.y + 5)];
        [path lineToPoint:CGPointMake(iconRect.origin.x + 8, iconRect.origin.y + 8)];
        [path stroke];
    }
    else if ([_dragType isEqualToString:UISecureFieldDragType])
    {
        var fieldRect = CGRectInset(bounds, 5, 12);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:fieldRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:fieldRect];
        var dots = "....";
        var textAttributes = @{
            CPFontAttributeName: [CPFont systemFontOfSize:10],
            CPForegroundColorAttributeName: [CPColor blackColor]
        };
        [dots drawAtPoint:CGPointMake(10, 12) withAttributes:textAttributes];
    }
    else if ([_dragType isEqualToString:UITextViewDragType])
    {
        var viewRect = CGRectInset(bounds, 5, 5);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:viewRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:viewRect];
    }
    else if ([_dragType isEqualToString:UIScrollViewDragType])
    {
        var viewRect = CGRectInset(bounds, 5, 5);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:viewRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:viewRect];
        var scrollbarRect = CGRectMake(viewRect.origin.x + viewRect.size.width - 8, viewRect.origin.y, 8, viewRect.size.height);
        [[CPColor lightGrayColor] set];
        [CPBezierPath fillRect:scrollbarRect];
    }
    else if ([_dragType isEqualToString:UITableViewDragType])
    {
        var viewRect = CGRectInset(bounds, 5, 5);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:viewRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:viewRect];
        var headerRect = CGRectMake(viewRect.origin.x, viewRect.origin.y, viewRect.size.width, 10);
        [[CPColor lightGrayColor] set];
        [CPBezierPath fillRect:headerRect];
    }
    else if ([_dragType isEqualToString:UISplitViewDragType])
    {
        var viewRect = CGRectInset(bounds, 5, 5);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:viewRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:viewRect];
        var dividerRect = CGRectMake(viewRect.origin.x + viewRect.size.width / 2 - 1, viewRect.origin.y, 2, viewRect.size.height);
        [[CPColor grayColor] set];
        [CPBezierPath fillRect:dividerRect];
    }
    else if ([_dragType isEqualToString:UIImageViewDragType])
    {
        var viewRect = CGRectInset(bounds, 5, 5);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:viewRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:viewRect];
        var path = [CPBezierPath bezierPath];
        [path moveToPoint:CGPointMake(10, 10)];
        [path lineToPoint:CGPointMake(30, 30)];
        [path moveToPoint:CGPointMake(30, 10)];
        [path lineToPoint:CGPointMake(10, 30)];
        [path stroke];
    }
    else if ([_dragType isEqualToString:UIPopUpButtonDragType])
    {
        var buttonRect = CGRectInset(bounds, 8, 10);
        var path = [CPBezierPath bezierPathWithRoundedRect:buttonRect radius:5];
        [[CPColor whiteColor] set];
        [path fill];
        [[CPColor blackColor] set];
        [path stroke];
        var arrowPath = [CPBezierPath bezierPath];
        [arrowPath moveToPoint:CGPointMake(bounds.size.width - 15, 18)];
        [arrowPath lineToPoint:CGPointMake(bounds.size.width - 10, 22)];
        [arrowPath lineToPoint:CGPointMake(bounds.size.width - 5, 18)];
        [arrowPath stroke];
    }
    else if ([_dragType isEqualToString:UIComboBoxDragType])
    {
        var fieldRect = CGRectInset(bounds, 5, 12);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:fieldRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:fieldRect];
        var arrowPath = [CPBezierPath bezierPath];
        [arrowPath moveToPoint:CGPointMake(bounds.size.width - 15, 18)];
        [arrowPath lineToPoint:CGPointMake(bounds.size.width - 10, 22)];
        [arrowPath lineToPoint:CGPointMake(bounds.size.width - 5, 18)];
        [arrowPath stroke];
    }
    else if ([_dragType isEqualToString:UIStepperDragType])
    {
        var upRect = CGRectMake(10, 10, 20, 10);
        var downRect = CGRectMake(10, 20, 20, 10);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:upRect];
        [CPBezierPath fillRect:downRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:upRect];
        [CPBezierPath strokeRect:downRect];
    }
    else if ([_dragType isEqualToString:UIDatePickerDragType])
    {
        var fieldRect = CGRectInset(bounds, 5, 12);
        [[CPColor whiteColor] set];
        [CPBezierPath fillRect:fieldRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:fieldRect];
        var iconRect = CGRectMake(bounds.size.width - 15, 14, 8, 8);
        [[CPColor grayColor] set];
        [CPBezierPath fillRect:iconRect];
    }
    else if ([_dragType isEqualToString:UIProgressIndicatorDragType])
    {
        var barRect = CGRectInset(bounds, 5, 15);
        [[CPColor lightGrayColor] set];
        [CPBezierPath fillRect:barRect];
        var progressRect = CGRectMake(barRect.origin.x, barRect.origin.y, barRect.size.width / 2, barRect.size.height);
        [[CPColor blueColor] set];
        [CPBezierPath fillRect:progressRect];
    }
    else if ([_dragType isEqualToString:UIBoxDragType])
    {
        var boxRect = CGRectInset(bounds, 5, 5);
        [[CPColor lightGrayColor] set];
        [CPBezierPath fillRect:boxRect];
        [[CPColor blackColor] set];
        [CPBezierPath strokeRect:boxRect];
    }
    else
    {
        // Fallback to original text drawing
        var title = [[_dragType componentsSeparatedByString:@"DragType"] objectAtIndex:0];
        var textAttributes = @{
            CPFontAttributeName: [CPFont systemFontOfSize:10],
            CPForegroundColorAttributeName: [CPColor blackColor]
        };
        var titleSize = [title sizeWithAttributes:textAttributes];
        var titlePoint = CGPointMake(
                                     (bounds.size.width - titleSize.width) / 2.0,
                                     (bounds.size.height - titleSize.height) / 2.0
                                     );
        [title drawAtPoint:titlePoint withAttributes:textAttributes];
    }
}

@end

@implementation AppController : CPObject
{
    CPWindow _window;
    CPPanel _palette;
    UIBuilderController _builderController;
    UICanvasView _canvasView;
    InspectorController _inspectorController;
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{
    console.log("AppController applicationDidFinishLaunching: CPApp._delegate:", CPApp._delegate);
    // 1. Create the main window and canvas
    _window = [[CPWindow alloc] initWithContentRect:CGRectMakeZero() styleMask:CPBorderlessBridgeWindowMask];
    [_window setTitle:@"Cappuccino UI Builder"];
    [_window setAcceptsMouseMovedEvents:YES];

    _canvasView = [[UICanvasView alloc] initWithFrame:[[_window contentView] bounds]];
    [_canvasView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [[_window contentView] addSubview:_canvasView];
    console.log("AppController: _canvasView.window after addSubview:", [_canvasView window]);

    // 2. Create the controllers
    _builderController = [[UIBuilderController alloc] init];

    // 3. Wire everything together
    [_canvasView setDelegate:_builderController];

    // Bind the canvas to the controller's data model. This is the core of the architecture.
    [_canvasView bind:"dataObjects" toObject:_builderController withKeyPath:@"elementsController.arrangedObjects" options:nil];
    [_canvasView bind:"selectionIndexes" toObject:_builderController withKeyPath:@"elementsController.selectionIndexes" options:nil];
    [_canvasView bind:"connections" toObject:_builderController withKeyPath:@"connectionsController.arrangedObjects" options:nil];
    [_canvasView bind:"selectedConnections" toObject:_builderController withKeyPath:@"connectionsController.selectedObjects" options:nil];
    
    [self createPalette];
    [self createInspector];

    // 5. Create the main menu
    var mainMenuBar = [[CPMenu alloc] initWithTitle:@"MainMenu"];
    var editMenuItem = [[CPMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];


    var editMenu = [[CPMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[CPMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];

    [editMenuItem setSubmenu:editMenu];

    var fileMenuItem = [[CPMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    var fileMenu = [[CPMenu alloc] initWithTitle:@"File"];
    [fileMenu addItemWithTitle:@"Run" action:@selector(run:) keyEquivalent:@"r"];
    [fileMenuItem setSubmenu:fileMenu];
    [mainMenuBar addItem:fileMenuItem];

    [mainMenuBar addItem:editMenuItem];

    [CPApp setMainMenu:mainMenuBar];
    [CPMenu setMenuBarVisible:YES];

    [_window makeKeyAndOrderFront:self];
}

- (void)createPalette
{
    var screenWidth = window.innerWidth;
    var symbolSize = 40;
    var labelHeight = 20;
    var itemHeight = symbolSize + labelHeight;
    var itemWidth = 65; 
    var padding = 10;
    var itemsPerRow = 7;

    var paletteItems = [
        // Row 1: Windows & Containers
        [
            {dragType: UIWindowDragType, elementType: "window", label: "Window"},
            {dragType: UIBoxDragType, elementType: "box", label: "Box"},
            {dragType: UIScrollViewDragType, elementType: "scrollView", label: "Scroll View"},
            {dragType: UISplitViewDragType, elementType: "splitView", label: "Split View"},
            {dragType: UITableViewDragType, elementType: "tableView", label: "Table View"}
        ],
        // Row 2: Layout
        [
            {dragType: UIHBoxDragType, elementType: "hbox", label: "HBox"},
            {dragType: UIVBoxDragType, elementType: "vbox", label: "VBox"}
        ],
        // Row 3: Text & Fields
        [
            {dragType: UILabelDragType, elementType: "label", label: "Label"},
            {dragType: UITextFieldDragType, elementType: "textfield", label: "Text Field"},
            {dragType: UISearchFieldDragType, elementType: "searchField", label: "Search Field"},
            {dragType: UISecureFieldDragType, elementType: "secureField", label: "Secure Field"},
            {dragType: UITextViewDragType, elementType: "textView", label: "Text View"},
            {dragType: UIComboBoxDragType, elementType: "comboBox", label: "Combo Box"}
        ],
        // Row 4: Buttons & Controls
        [
            {dragType: UIButtonDragType, elementType: "button", label: "Button"},
            {dragType: UICheckBoxDragType, elementType: "checkBox", label: "Check Box"},
            {dragType: UIPopUpButtonDragType, elementType: "popUpButton", label: "Pop Up"},
            {dragType: UIStepperDragType, elementType: "stepper", label: "Stepper"},
            {dragType: UISliderDragType, elementType: "slider", label: "Slider"},
            {dragType: UIDatePickerDragType, elementType: "datePicker", label: "Date Picker"}
        ],
        // Row 5: Other
        [
            {dragType: UIImageViewDragType, elementType: "imageView", label: "Image View"},
            {dragType: UIProgressIndicatorDragType, elementType: "progresIndicator", label: "Progress"}
        ]
    ];

    var paletteWidth = padding + itemsPerRow * (itemWidth + padding);
    var paletteHeight = padding + [paletteItems count] * (itemHeight + padding) + 20;
    var paletteX = (screenWidth - paletteWidth) / 2;
    var paletteY = 50;

    _palette = [[CPPanel alloc] initWithContentRect:CGRectMake(paletteX, paletteY, paletteWidth, paletteHeight)
                                          styleMask:CPHUDBackgroundWindowMask | CPTitledWindowMask | CPClosableWindowMask];
    [_palette setTitle:@"Elements"];
    [_palette setFloatingPanel:YES];
    [_palette setAcceptsMouseMovedEvents:NO];

    var contentView = [_palette contentView];
    var contentViewHeight = [contentView bounds].size.height;

    for (var r = 0; r < [paletteItems count]; r++) {
        var rowItems = paletteItems[r];
        var xPos = padding;
        var yPos = contentViewHeight - (r + 1) * (itemHeight + padding);

        for (var i = 0; i < [rowItems count]; i++) {
            var item = rowItems[i];

            var container = [[CPView alloc] initWithFrame:CGRectMake(xPos, yPos, itemWidth, itemHeight)];

            var symbol = [[DraggableSymbolView alloc] initWithFrame:CGRectMake((itemWidth - symbolSize) / 2, labelHeight, symbolSize, symbolSize)];
            [symbol setDragType:item.dragType];
            [symbol setElementType:item.elementType];
            [container addSubview:symbol];

            var label = [[CPTextField alloc] initWithFrame:CGRectMake(0, 5, itemWidth, labelHeight)];
            [label setStringValue:item.label];
            [label setFont:[CPFont systemFontOfSize:10]];
            [label setTextColor:[CPColor whiteColor]];
            [label setAlignment:CPCenterTextAlignment];
            [label setBezeled:NO];
            [label setDrawsBackground:NO];
            [label setEditable:NO];
            [label setSelectable:NO];
            [container addSubview:label];

            [contentView addSubview:container];
            xPos += itemWidth + padding;
        }
    }

    [_palette orderFront:self];
}

- (void)createInspector
{
    var inspectorPanel = [[CPPanel alloc] initWithContentRect:CGRectMake(20, 200, 300, 150)
                                                  styleMask:CPTitledWindowMask | CPClosableWindowMask];
    [inspectorPanel setTitle:@"Inspector"];
    [inspectorPanel setFloatingPanel:YES];

    var contentView = [inspectorPanel contentView];

    _inspectorController = [[InspectorController alloc] init];
    [_inspectorController setBuilderController:_builderController];
    [_inspectorController setPanel:inspectorPanel];
    [_inspectorController setView:contentView];

    [_inspectorController awakeFromMarkup]; // Manually call this

    [inspectorPanel orderFront:self];
}

- (void)run:(id)sender
{
    console.log("Run: Starting native UI generation...");
    var canvasSubviews = [_canvasView subviews];
    var nativeElementMap = [CPMutableDictionary dictionary];

    // First pass: create all native elements and map them by their ID
    console.log("Run: Creating native elements and building map...");
    for (var i = 0; i < [canvasSubviews count]; i++)
    {
        var view = [canvasSubviews objectAtIndex:i];
        if ([view isKindOfClass:[UIElementView class]])
        {
            // This will now recursively build the map
            [view nativeUIElementWithMap:nativeElementMap];
        }
    }

    // Second pass: connect the native elements
    console.log("Run: Processing connections...");
    var connections = [[_builderController connectionsController] content];
    for (var i = 0; i < [connections count]; i++)
    {
        var connection = [connections objectAtIndex:i];
        var sourceID = [connection valueForKey:@"sourceID"];
        var targetID = [connection valueForKey:@"targetID"];
        var action = [connection valueForKey:@"action"];

        console.log(" - Connecting: " + sourceID + " -> " + targetID + " (Action: " + action + ")");

        var nativeSource = [nativeElementMap objectForKey:sourceID];
        var nativeTarget = [nativeElementMap objectForKey:targetID];

        if (nativeSource && nativeTarget && action)
        {
            console.log("   - Found native source and target. Applying connection.");
            [nativeSource setTarget:nativeTarget];
            [nativeSource setAction:CPSelectorFromString(action)];
        }
        else
        {
            console.log("   - WARNING: Could not find native source or target for connection.");
        }
    }

    // Third pass: show the windows
    console.log("Run: Showing windows...");
    for (var i = 0; i < [canvasSubviews count]; i++)
    {
        var view = [canvasSubviews objectAtIndex:i];
        if ([view isKindOfClass:[UIWindowView class]])
        {
            var elementID = [[view dataObject] valueForKey:@"id"];
            var nativeWindow = [nativeElementMap objectForKey:elementID];
            if (nativeWindow)
            {
                console.log(" - Showing window for ID: " + elementID);
                [nativeWindow makeKeyAndOrderFront:self];
            }
        }
    }
    console.log("Run: Finished.");
}

@end

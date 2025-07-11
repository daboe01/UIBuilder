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
}

- (void)setDragType:(CPString)aType
{
    _dragType = aType;
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
    // Simple drawing, replace with icons if you have them
    [[CPColor controlColor] set];
    [CPBezierPath fillRect:[self bounds]];
    [[CPColor controlShadowColor] set];
    [CPBezierPath strokeRect:[self bounds]];

    var title = [[_dragType componentsSeparatedByString:@"DragType"] objectAtIndex:0];

    var textAttributes = @{
        CPFontAttributeName: [CPFont systemFontOfSize:10],
        CPForegroundColorAttributeName: [CPColor blackColor]
    };

    var titleSize = [title sizeWithAttributes:textAttributes];
    var titlePoint = CGPointMake(
                                 ([self bounds].size.width - titleSize.width) / 2.0,
                                 ([self bounds].size.height - titleSize.height) / 2.0
                                 );

    [title drawAtPoint:titlePoint withAttributes:textAttributes];
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
    // 1. Create the main window and canvas
    _window = [[CPWindow alloc] initWithContentRect:CGRectMakeZero() styleMask:CPBorderlessBridgeWindowMask];
    [_window setTitle:@"Cappuccino UI Builder"];
    [_window setAcceptsMouseMovedEvents:YES];

    _canvasView = [[UICanvasView alloc] initWithFrame:[[_window contentView] bounds]];
    [_canvasView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [[_window contentView] addSubview:_canvasView];

    // 2. Create the controllers
    _builderController = [[UIBuilderController alloc] init];

    // 3. Wire everything together
    [_canvasView setDelegate:_builderController];

    // Bind the canvas to the controller's data model. This is the core of the architecture.
    [_canvasView bind:"dataObjects" toObject:_builderController withKeyPath:@"elementsController.arrangedObjects" options:nil];
    [_canvasView bind:"selectionIndexes" toObject:_builderController withKeyPath:@"elementsController.selectionIndexes" options:nil];
    
    [self createPalette];
    [self createInspector];

    // 5. Create the main menu
    var mainMenuBar = [[CPMenu alloc] initWithTitle:@"MainMenu"];
    var appMenuItem = [[CPMenuItem alloc] initWithTitle:@"UIBuilder" action:nil keyEquivalent:@""];
    var editMenuItem = [[CPMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];

    var appMenu = [[CPMenu alloc] initWithTitle:@"UIBuilder"];
    [appMenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];

    var editMenu = [[CPMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[CPMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];

    [appMenuItem setSubmenu:appMenu];
    [editMenuItem setSubmenu:editMenu];

    [mainMenuBar addItem:appMenuItem];
    [mainMenuBar addItem:editMenuItem];

    [CPApp setMainMenu:mainMenuBar];
    [CPMenu setMenuBarVisible:YES];

    [_window makeKeyAndOrderFront:self];
}

- (void)createPalette
{
    _palette = [[CPPanel alloc] initWithContentRect:CGRectMake(20, 500, 110, 220)
                                          styleMask:CPHUDBackgroundWindowMask | CPTitledWindowMask | CPClosableWindowMask];
    [_palette setTitle:@"Elements"];
    [_palette setFloatingPanel:YES];

    var yPos = 160;
    var types = [UIWindowDragType, UIButtonDragType, UISliderDragType, UITextFieldDragType];

    // Create draggable symbols for each type
    [_canvasView registerForDraggedTypes:types];

    for (var i=0; i < [types count]; i++) {
        var symbol = [[DraggableSymbolView alloc] initWithFrame:CGRectMake(10, yPos, 70, 40)];
        symbol._dragType = types[i];

        [[_palette contentView] addSubview:symbol];
        yPos -= 50;
    }

    [_palette orderFront:self];
}

- (void)createInspector
{
    var inspectorPanel = [[CPPanel alloc] initWithContentRect:CGRectMake(20, 200, 200, 150)
                                                  styleMask:CPHUDBackgroundWindowMask | CPTitledWindowMask | CPClosableWindowMask];
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

@end

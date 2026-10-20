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
@import "DataModelEditorController.j";
@import "UIBPalette.j";
@import "UIBNativeElements.j";
@import "UIBCodeGenerator.j";

var CGSizeZero = CGSizeMake(0, 0);

var UIBAutosaveKey = "UIBuilder.autosave.v1",
    UIBOwnerClassNameKey = "UIBuilder.ownerClassName";

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
    // The element type travels with the drag, so the canvas knows exactly what to create.
    [pasteboard setString:_elementType || @"" forType:_dragType];

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
    else if ([_dragType isEqualToString:UIHSpaceDragType])
    {
        var lineY = bounds.size.height / 2;
        var path = [CPBezierPath bezierPath];
        [path moveToPoint:CGPointMake(bounds.origin.x + 5, lineY)];
        [path lineToPoint:CGPointMake(bounds.origin.x + bounds.size.width - 5, lineY)];
        [[CPColor blackColor] set];
        [path stroke];
    }
    else if ([_dragType isEqualToString:UIVSpaceDragType])
    {
        var lineX = bounds.size.width / 2;
        var path = [CPBezierPath bezierPath];
        [path moveToPoint:CGPointMake(lineX, bounds.origin.y + 5)];
        [path lineToPoint:CGPointMake(lineX, bounds.origin.y + bounds.size.height - 5)];
        [[CPColor blackColor] set];
        [path stroke];
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
    CPPanel _inspectorPanel;
    DataModelEditorController _dataModelEditor;
    int _lastMarkupMode;
    CPArray _previewWindows;
    CPPanel _runLogPanel;
    CPTextView _runLogTextView;
    CPArray _runLogLines;
    CPString _lastAutosavedMarkup;
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{
    // 1. Create the main window and canvas
    _window = [[CPWindow alloc] initWithContentRect:CGRectMakeZero() styleMask:CPBorderlessBridgeWindowMask];
    [_window setTitle:UIBLocalized(@"Cappuccino UI Builder")];
    [_window setAcceptsMouseMovedEvents:YES];

    // The canvas scrolls: imported documents can have dozens of windows.
    var scrollView = [[CPScrollView alloc] initWithFrame:[[_window contentView] bounds]];
    [scrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setBackgroundColor:[CPColor colorWithCalibratedWhite:0.97 alpha:1.0]];
    [[_window contentView] addSubview:scrollView];

    _canvasView = [[UICanvasView alloc] initWithFrame:[[scrollView contentView] bounds]];
    [scrollView setDocumentView:_canvasView];

    var clipView = [scrollView contentView];
    [clipView setPostsFrameChangedNotifications:YES];
    [[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(_canvasClipViewDidResize:) name:CPViewFrameDidChangeNotification object:clipView];
    console.log("AppController: _canvasView.window after addSubview:", [_canvasView window]);

    // 2. Create the controllers
    _builderController = [[UIBuilderController alloc] init];

    // One undo manager for the whole document, whichever window is key.
    [_window setDelegate:self];
    [_builderController addObserver:self forKeyPath:@"documentEdited" options:CPKeyValueObservingOptionNew context:nil];

    // 3. Wire everything together
    [_canvasView setDelegate:_builderController];
    [_builderController setCanvasView:_canvasView];

    // Bind the canvas to the controller's data model. This is the core of the architecture.
    [_canvasView bind:"dataObjects" toObject:_builderController withKeyPath:@"elementsController.arrangedObjects" options:nil];
    [_canvasView bind:"selectionIndexes" toObject:_builderController withKeyPath:@"elementsController.selectionIndexes" options:nil];
    [_canvasView bind:"connections" toObject:_builderController withKeyPath:@"connectionsController.arrangedObjects" options:nil];
    [_canvasView bind:"selectedConnections" toObject:_builderController withKeyPath:@"connectionsController.selectedObjects" options:nil];
    
    [self createPalette];
    [self createInspector];

    // 4. An empty document (with its File's Owner), or the autosaved one
    [_builderController newDocument];
    [self _restoreAutosave];
    [self _startAutosave];
    [_canvasView updateDocumentSize];

    // 5. Create the main menu
    [self createMainMenu];
    [self _updateWindowTitle];

    [_window makeKeyAndOrderFront:self];
    [_window makeFirstResponder:_canvasView];
}

#pragma mark -
#pragma mark Autosave

// The whole document (interface and data model) is kept in the browser,
// so a reload or a crash does not lose work (see UIBAutosaveKey).
- (void)_restoreAutosave
{
    var markup = nil;
    try { markup = window.localStorage.getItem(UIBAutosaveKey); } catch (e) { }

    if (!markup)
        return;

    var error = [_builderController loadCappusanceMarkup:markup];
    if (error)
        console.warn("Autosave could not be restored:", error);

    _lastAutosavedMarkup = markup;
}

- (void)_autosave
{
    try
    {
        var markup = [_builderController cappusanceMarkupIncludingInterface:YES model:YES];
        if (markup !== _lastAutosavedMarkup)
        {
            window.localStorage.setItem(UIBAutosaveKey, markup);
            _lastAutosavedMarkup = markup;
        }
    }
    catch (e)
    {
        console.warn("Autosave failed:", e);
    }
}

- (void)_startAutosave
{
    window.setInterval(function() { [self _autosave]; }, 4000);
    window.addEventListener("beforeunload", function() { [self _autosave]; });
}

- (void)_canvasClipViewDidResize:(CPNotification)aNotification
{
    [_canvasView updateDocumentSize];
}

- (void)createMainMenu
{
    var mainMenuBar = [[CPMenu alloc] initWithTitle:UIBLocalized(@"MainMenu")];

    // File
    var fileMenuItem = [[CPMenuItem alloc] initWithTitle:UIBLocalized(@"File") action:nil keyEquivalent:@""];
    var fileMenu = [[CPMenu alloc] initWithTitle:UIBLocalized(@"File")];
    [fileMenu addItemWithTitle:UIBLocalized(@"New") action:@selector(newDocument:) keyEquivalent:@""];
    [fileMenu addItemWithTitle:UIBLocalized(@"Import Cappusance Markup…") action:@selector(load:) keyEquivalent:@"l"];
    [fileMenu addItemWithTitle:UIBLocalized(@"Save as Cappusance Markup…") action:@selector(save:) keyEquivalent:@"s"];
    [fileMenu addItem:[CPMenuItem separatorItem]];
    [fileMenu addItemWithTitle:UIBLocalized(@"Run") action:@selector(run:) keyEquivalent:@"r"];
    [fileMenu addItem:[CPMenuItem separatorItem]];
    [fileMenu addItemWithTitle:UIBLocalized(@"Generate File's Owner Code…") action:@selector(generateOwnerCode:) keyEquivalent:@""];
    [fileMenuItem setSubmenu:fileMenu];
    [mainMenuBar addItem:fileMenuItem];

    // Edit
    var editMenuItem = [[CPMenuItem alloc] initWithTitle:UIBLocalized(@"Edit") action:nil keyEquivalent:@""];
    var editMenu = [[CPMenu alloc] initWithTitle:UIBLocalized(@"Edit")];
    [editMenu addItemWithTitle:UIBLocalized(@"Undo") action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:UIBLocalized(@"Redo") action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[CPMenuItem separatorItem]];
    [editMenu addItemWithTitle:UIBLocalized(@"Cut") action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:UIBLocalized(@"Copy") action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:UIBLocalized(@"Paste") action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:UIBLocalized(@"Duplicate") action:@selector(duplicate:) keyEquivalent:@"d"];
    [editMenu addItemWithTitle:UIBLocalized(@"Delete") action:@selector(delete:) keyEquivalent:@""];
    [editMenu addItem:[CPMenuItem separatorItem]];
    [editMenu addItemWithTitle:UIBLocalized(@"Select All") action:@selector(selectAll:) keyEquivalent:@"a"];
    [editMenu addItemWithTitle:UIBLocalized(@"Select Parent") action:@selector(selectParent:) keyEquivalent:@""];
    [editMenuItem setSubmenu:editMenu];
    [mainMenuBar addItem:editMenuItem];

    // Arrange
    var arrangeMenuItem = [[CPMenuItem alloc] initWithTitle:UIBLocalized(@"Arrange") action:nil keyEquivalent:@""];
    var arrangeMenu = [[CPMenu alloc] initWithTitle:UIBLocalized(@"Arrange")];
    [arrangeMenu addItemWithTitle:UIBLocalized(@"Group in HBox") action:@selector(groupInHBox:) keyEquivalent:@"g"];
    [arrangeMenu addItemWithTitle:UIBLocalized(@"Group in VBox") action:@selector(groupInVBox:) keyEquivalent:@""];
    [arrangeMenu addItemWithTitle:UIBLocalized(@"Ungroup") action:@selector(ungroup:) keyEquivalent:@"G"];
    [arrangeMenu addItem:[CPMenuItem separatorItem]];
    [arrangeMenu addItemWithTitle:UIBLocalized(@"Move Earlier") action:@selector(moveEarlier:) keyEquivalent:@"["];
    [arrangeMenu addItemWithTitle:UIBLocalized(@"Move Later") action:@selector(moveLater:) keyEquivalent:@"]"];
    [arrangeMenuItem setSubmenu:arrangeMenu];
    [mainMenuBar addItem:arrangeMenuItem];

    // Data model
    var dataMenuItem = [[CPMenuItem alloc] initWithTitle:UIBLocalized(@"Data") action:nil keyEquivalent:@""];
    var dataMenu = [[CPMenu alloc] initWithTitle:UIBLocalized(@"Data")];
    [dataMenu addItemWithTitle:UIBLocalized(@"Data Model Editor…") action:@selector(showDataModelEditor:) keyEquivalent:@""];
    [dataMenu addItem:[CPMenuItem separatorItem]];
    [dataMenu addItemWithTitle:UIBLocalized(@"Import Data Model…") action:@selector(importDataModel:) keyEquivalent:@""];
    [dataMenu addItemWithTitle:UIBLocalized(@"Save Data Model…") action:@selector(saveDataModel:) keyEquivalent:@""];
    [dataMenuItem setSubmenu:dataMenu];
    [mainMenuBar addItem:dataMenuItem];

    // Window
    var windowMenuItem = [[CPMenuItem alloc] initWithTitle:UIBLocalized(@"Window") action:nil keyEquivalent:@""];
    var windowMenu = [[CPMenu alloc] initWithTitle:UIBLocalized(@"Window")];
    [windowMenu addItemWithTitle:UIBLocalized(@"Elements") action:@selector(showPalette:) keyEquivalent:@""];
    [windowMenu addItemWithTitle:UIBLocalized(@"Inspector") action:@selector(showInspector:) keyEquivalent:@""];
    [windowMenu addItemWithTitle:UIBLocalized(@"Data Model") action:@selector(showDataModelEditor:) keyEquivalent:@""];
    [windowMenuItem setSubmenu:windowMenu];
    [mainMenuBar addItem:windowMenuItem];

    [CPApp setMainMenu:mainMenuBar];
    [CPMenu setMenuBarVisible:YES];
}

#pragma mark -
#pragma mark Undo

// Every window of the app shares the document's undo manager.
- (CPUndoManager)windowWillReturnUndoManager:(CPWindow)aWindow
{
    return [_builderController undoManager];
}

- (void)undo:(id)sender
{
    [self _commitInspectorEditing];

    var undoManager = [_builderController undoManager];
    if ([undoManager canUndo])
        [undoManager undo];

    [_canvasView setNeedsDisplay:YES];
}

- (void)redo:(id)sender
{
    [self _commitInspectorEditing];

    var undoManager = [_builderController undoManager];
    if ([undoManager canRedo])
        [undoManager redo];

    [_canvasView setNeedsDisplay:YES];
}

// Ends a pending text edit in the inspector so it lands on the undo stack first.
- (void)_commitInspectorEditing
{
    if (_inspectorPanel && [_inspectorPanel isKeyWindow])
        [_inspectorPanel makeFirstResponder:nil];
}

- (BOOL)validateMenuItem:(CPMenuItem)aMenuItem
{
    var action = [aMenuItem action],
        undoManager = [_builderController undoManager];

    if (action == @selector(undo:))
    {
        [aMenuItem setTitle:[undoManager undoMenuItemTitle] || UIBLocalized(@"Undo")];
        return [undoManager canUndo];
    }

    if (action == @selector(redo:))
    {
        [aMenuItem setTitle:[undoManager redoMenuItemTitle] || UIBLocalized(@"Redo")];
        return [undoManager canRedo];
    }

    // Editing commands reach us when another window is key: route them to the canvas.
    if ([_canvasView respondsToSelector:action])
        return [_canvasView validateMenuItem:aMenuItem];

    return YES;
}

- (void)observeValueForKeyPath:(CPString)keyPath ofObject:(id)object change:(CPDictionary)change context:(id)context
{
    if (keyPath === @"documentEdited")
        [self _updateWindowTitle];
}

- (void)_updateWindowTitle
{
    var title = UIBLocalized(@"Cappuccino UI Builder");
    if ([_builderController isDocumentEdited])
        title += " — " + UIBLocalized(@"Edited");

    [_window setTitle:title];
    document.title = title;
}

// Editing commands from the menu bar while the palette or inspector is key.
- (void)cut:(id)sender          { [_canvasView cut:sender]; }
- (void)copy:(id)sender         { [_canvasView copy:sender]; }
- (void)paste:(id)sender        { [_canvasView paste:sender]; }
- (void)duplicate:(id)sender    { [_canvasView duplicate:sender]; }
- (void)delete:(id)sender       { [_canvasView delete:sender]; }
- (void)selectAll:(id)sender    { [_canvasView selectAll:sender]; }
- (void)selectParent:(id)sender { [_canvasView selectParent:sender]; }
- (void)groupInHBox:(id)sender  { [_canvasView groupInHBox:sender]; }
- (void)groupInVBox:(id)sender  { [_canvasView groupInVBox:sender]; }
- (void)ungroup:(id)sender      { [_canvasView ungroup:sender]; }
- (void)moveEarlier:(id)sender  { [_canvasView moveEarlier:sender]; }
- (void)moveLater:(id)sender    { [_canvasView moveLater:sender]; }

#pragma mark -
#pragma mark Document

- (BOOL)_confirmDiscardingChanges
{
    if (![_builderController isDocumentEdited])
        return YES;

    return window.confirm(UIBLocalized("The current interface has unsaved changes. Discard them?"));
}

- (void)newDocument:(id)sender
{
    if (![self _confirmDiscardingChanges])
        return;

    [_builderController newDocument];
    [_canvasView setNeedsDisplay:YES];
}

- (void)createPalette
{
    _palette = UIBCreatePalette();
    [_palette setDelegate:self];
    [_palette orderFront:self];
}

- (void)showPalette:(id)sender
{
    [_palette orderFront:self];
}

- (void)showInspector:(id)sender
{
    [_inspectorPanel orderFront:self];
}

- (void)showDataModelEditor:(id)sender
{
    if (!_dataModelEditor)
        _dataModelEditor = [[DataModelEditorController alloc] initWithBuilderController:_builderController];

    [_dataModelEditor showWindow:self];
}

- (void)createInspector
{
    var inspectorPanel = [[CPPanel alloc] initWithContentRect:CGRectMake(20, 40, 330, 580)
                                                  styleMask:CPTitledWindowMask | CPClosableWindowMask];
    [inspectorPanel setTitle:UIBLocalized(@"Inspector")];
    [inspectorPanel setFloatingPanel:YES];
    [inspectorPanel setDelegate:self];
    _inspectorPanel = inspectorPanel;

    var contentView = [inspectorPanel contentView];

    _inspectorController = [[InspectorController alloc] init];
    [_inspectorController setBuilderController:_builderController];
    [_inspectorController setPanel:inspectorPanel];
    [_inspectorController setView:contentView];

    [_inspectorController awakeFromMarkup]; // Manually call this

    [inspectorPanel orderFront:self];
}

#pragma mark -
#pragma mark File's Owner Code

- (CPTextField)_codeBarField:(CPString)aValue frame:(CGRect)aFrame
{
    var field = [[CPTextField alloc] initWithFrame:aFrame];
    [field setStringValue:aValue];
    [field setEditable:YES];
    [field setBezeled:YES];
    [field setTarget:self];
    [field setAction:@selector(regenerateOwnerCode:)];
    return field;
}

- (CPTextField)_codeBarLabel:(CPString)aString frame:(CGRect)aFrame
{
    var label = [[CPTextField alloc] initWithFrame:aFrame];
    [label setStringValue:aString];
    [label setFont:[CPFont boldSystemFontOfSize:12]];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    return label;
}

/*!
    Shows the Objective-J class of File's Owner: outlets, array controllers,
    properties used by bindings, and an action method per action. The code
    can be copied, downloaded, or merged into an existing class.
*/
- (void)generateOwnerCode:(id)sender
{
    var textView = nil,
        panel = [self _markupPanelWithTitle:UIBLocalized(@"File's Owner Code") textView:function(aTextView) { textView = aTextView; }],
        contentView = [panel contentView],
        bounds = [contentView bounds],
        savedName = nil;

    try { savedName = window.localStorage.getItem(UIBOwnerClassNameKey); } catch (e) { }

    var topBar = [[CPView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, 70)];
    [topBar setBackgroundColor:[CPColor colorWithCalibratedWhite:0.95 alpha:1.0]];
    [topBar setAutoresizingMask:CPViewWidthSizable];
    [contentView addSubview:topBar];

    [topBar addSubview:[self _codeBarLabel:UIBLocalized(@"Class:") frame:CGRectMake(10, 12, 50, 20)]];
    var classField = [self _codeBarField:savedName || @"AppController" frame:CGRectMake(60, 6, 200, 28)];
    [topBar addSubview:classField];

    [topBar addSubview:[self _codeBarLabel:UIBLocalized(@"Superclass:") frame:CGRectMake(272, 12, 80, 20)]];
    var superclassField = [self _codeBarField:@"CPObject" frame:CGRectMake(352, 6, 160, 28)];
    [topBar addSubview:superclassField];

    var mergeButton = [[CPButton alloc] initWithFrame:CGRectMake(bounds.size.width - 230, 8, 220, 24)];
    [mergeButton setTitle:UIBLocalized(@"Merge into Existing Class…")];
    [mergeButton setTarget:self];
    [mergeButton setAction:@selector(mergeOwnerCode:)];
    [mergeButton setAutoresizingMask:CPViewMinXMargin];
    [topBar addSubview:mergeButton];

    var summary = [[CPTextField alloc] initWithFrame:CGRectMake(10, 44, bounds.size.width - 20, 18)];
    [summary setFont:[CPFont systemFontOfSize:11]];
    [summary setTextColor:[CPColor grayColor]];
    [summary setBezeled:NO];
    [summary setDrawsBackground:NO];
    [summary setEditable:NO];
    [summary setAutoresizingMask:CPViewWidthSizable];
    [topBar addSubview:summary];

    var subviews = [contentView subviews];
    for (var i = 0; i < subviews.length; i++)
        if ([subviews[i] isKindOfClass:[CPScrollView class]])
            [subviews[i] setFrame:CGRectMake(0, 70, bounds.size.width, bounds.size.height - 114)];

    var copyButton = [self _panelButton:UIBLocalized(@"Copy to Clipboard") x:10 inPanel:panel action:@selector(copyMarkup:)],
        downloadButton = [self _panelButton:UIBLocalized(@"Download…") x:bounds.size.width - 150 inPanel:panel action:@selector(downloadMarkup:)];

    // Everything the actions need, kept on the class field.
    classField._uib = { textView: textView, classField: classField, superclassField: superclassField, summary: summary, buttons: [copyButton, downloadButton] };
    superclassField._uib = classField._uib;
    mergeButton._uib = classField._uib;

    [panel makeKeyAndOrderFront:self];
    [self regenerateOwnerCode:classField];
}

- (void)_showOwnerCode:(CPString)aSource context:(JSObject)aContext summary:(CPString)aSummary
{
    var className = String([aContext.classField stringValue] || "AppController").trim();

    [aContext.textView setString:aSource];
    [aContext.summary setStringValue:aSummary];

    for (var i = 0; i < aContext.buttons.length; i++)
    {
        aContext.buttons[i]._markup = aSource;
        aContext.buttons[i]._fileName = className + ".j";
    }
    [aContext.buttons[0] setTitle:UIBLocalized(@"Copy to Clipboard")];

    [[aContext.textView window] makeFirstResponder:aContext.textView];
    [aContext.textView setSelectedRange:CPMakeRange(0, [aSource length])];
}

- (void)regenerateOwnerCode:(id)sender
{
    var context = sender._uib,
        className = String([context.classField stringValue] || "").trim() || "AppController",
        superclass = String([context.superclassField stringValue] || "").trim() || "CPObject",
        description = [UIBCodeGenerator ownerInterfaceForController:_builderController];

    try { window.localStorage.setItem(UIBOwnerClassNameKey, className); } catch (e) { }

    [self _showOwnerCode:[UIBCodeGenerator ownerClassSourceForInterface:description className:className superclass:superclass] context:context
                 summary:UIBLocalizedFormat(@"%@ outlets, %@ properties for bindings, %@ actions", description.outlets.length, description.properties.length, description.actions.length)];
}

- (void)mergeOwnerCode:(id)sender
{
    var context = sender._uib,
        textView = nil,
        panel = [self _markupPanelWithTitle:UIBLocalized(@"Paste your existing class — missing outlets and actions are added") textView:function(aTextView) { textView = aTextView; }];

    var mergeButton = [self _panelButton:UIBLocalized(@"Merge") x:[[panel contentView] bounds].size.width - 150 inPanel:panel action:@selector(performOwnerCodeMerge:)];
    mergeButton._uib = context;
    mergeButton._sourceView = textView;

    var fileButton = [self _panelButton:UIBLocalized(@"Open File…") x:10 inPanel:panel action:@selector(chooseMarkupFile:)];
    fileButton._textView = textView;

    [panel makeKeyAndOrderFront:self];
    [panel makeFirstResponder:textView];
}

- (void)performOwnerCodeMerge:(id)sender
{
    var result = [UIBCodeGenerator mergeOwnerClassSource:[sender._sourceView string] withInterface:[UIBCodeGenerator ownerInterfaceForController:_builderController]];

    if (result.error)
    {
        var alert = [CPAlert alertWithMessageText:UIBLocalized(@"Could Not Merge") defaultButton:UIBLocalized(@"OK") alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", UIBLocalized(result.error)];
        [alert runModal];
        return;
    }

    var summary = (result.addedVariables.length || result.addedActions.length)
        ? UIBLocalizedFormat(@"Added %@ variables (%@) and %@ actions (%@).", result.addedVariables.length, result.addedVariables.join(", ") || "–", result.addedActions.length, result.addedActions.join(", ") || "–")
        : UIBLocalized(@"Nothing to add — the class already has all outlets and actions.");

    var className = /@implementation\s+(\w+)/.exec(result.source);
    if (className)
        [sender._uib.classField setStringValue:className[1]];

    [[sender window] close];
    [self _showOwnerCode:result.source context:sender._uib summary:summary];
}

#pragma mark -
#pragma mark Run (preview with native views)

- (void)_closePreview
{
    for (var i = 0; _previewWindows && i < _previewWindows.length; i++)
        [_previewWindows[i] orderOut:self];

    _previewWindows = [];
}

- (void)closePreview:(id)sender
{
    [self _closePreview];
    [_runLogPanel orderOut:self];
}

- (void)_appendRunLog:(CPString)aMessage
{
    var time = new Date().toTimeString().substring(0, 8);
    _runLogLines.push(time + "  " + aMessage);
    if (_runLogLines.length > 300)
        _runLogLines.shift();

    [_runLogTextView setString:_runLogLines.join("\n")];
    [_runLogTextView scrollRangeToVisible:CPMakeRange([[_runLogTextView string] length], 0)];
}

- (void)_showRunLog
{
    if (!_runLogPanel)
    {
        var width = 460, height = 230;
        _runLogPanel = [[CPPanel alloc] initWithContentRect:CGRectMake(window.innerWidth - width - 30, window.innerHeight - height - 40, width, height)
                                                  styleMask:CPHUDBackgroundWindowMask | CPTitledWindowMask | CPClosableWindowMask | CPResizableWindowMask];
        [_runLogPanel setTitle:UIBLocalized(@"Run Log")];
        [_runLogPanel setFloatingPanel:YES];

        var contentView = [_runLogPanel contentView],
            bounds = [contentView bounds],
            scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height - 38)];

        [scrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
        [scrollView setHasHorizontalScroller:NO];

        _runLogTextView = [[CPTextView alloc] initWithFrame:[[scrollView contentView] bounds]];
        [_runLogTextView setEditable:NO];
        [_runLogTextView setFont:[CPFont fontWithName:@"Menlo, Monaco, monospace" size:11]];
        [_runLogTextView setAutoresizingMask:CPViewWidthSizable];
        [scrollView setDocumentView:_runLogTextView];
        [contentView addSubview:scrollView];

        var closeButton = [[CPButton alloc] initWithFrame:CGRectMake(bounds.size.width - 150, bounds.size.height - 32, 140, 24)];
        [closeButton setTitle:UIBLocalized(@"Close Preview")];
        [closeButton setTarget:self];
        [closeButton setAction:@selector(closePreview:)];
        [closeButton setAutoresizingMask:CPViewMinXMargin | CPViewMinYMargin];
        [contentView addSubview:closeButton];
    }

    [_runLogPanel orderFront:self];
}

/*!
    Builds real Cappuccino views from the design and shows the visible
    windows. Actions sent to File's Owner (or to references outside the
    document) are shown in the run log.
*/
- (void)run:(id)sender
{
    [self _closePreview];

    _runLogLines = [];
    [UIBRunOwner resetWithLogger:function(aMessage) { [self _appendRunLog:aMessage]; }];
    [self _showRunLog];

    var map = [CPMutableDictionary dictionary],
        canvasSubviews = [_canvasView subviews],
        windowViews = [];

    // 1. Natives for every element
    for (var i = 0; i < canvasSubviews.length; i++)
    {
        var view = canvasSubviews[i];
        if ([view isKindOfClass:[UIWindowView class]])
        {
            var nativeWindow = [view nativeUIElementWithMap:map];
            if (nativeWindow)
            {
                windowViews.push(view);
                _previewWindows.push(nativeWindow);
            }
        }
    }

    // 2. Connections
    var connections = [_builderController allConnections],
        actionsToOwner = 0,
        applied = 0,
        ownerElement = [_builderController ownerElement],
        ownerID = ownerElement ? [ownerElement valueForKey:@"id"] : nil;

    var resolve = function(aConnection, aPrefix)
    {
        var elementID = [aConnection valueForKey:aPrefix + "ID"];
        if (elementID)
            return elementID === ownerID ? [UIBRunOwner ownerForReference:"#CPOwner"] : [map objectForKey:elementID];

        var reference = [aConnection valueForKey:aPrefix + "Ref"];
        return reference ? [UIBRunOwner ownerForReference:reference] : nil;
    };

    for (var i = 0; i < connections.length; i++)
    {
        var connection = connections[i],
            source = resolve(connection, "source"),
            target = resolve(connection, "target"),
            action = [connection valueForKey:@"action"],
            outlet = [connection valueForKey:@"outlet"];

        if (!source)
            continue;

        if (action)
        {
            if (!target || [target isKindOfClass:[UIBRunOwner class]])
            {
                target = target || [UIBRunOwner ownerForReference:"#CPOwner"];
                [UIBRunOwner selectorForAction:action];
                actionsToOwner++;
            }

            if ([source respondsToSelector:@selector(setTarget:)])
            {
                [source setTarget:target];
                [source setAction:CPSelectorFromString(action)];
                applied++;
            }
            continue;
        }

        if (!outlet || !target || [source isKindOfClass:[UIBRunOwner class]] || [target isKindOfClass:[UIBRunOwner class]])
            continue;

        var setter = CPSelectorFromString("set" + outlet.charAt(0).toUpperCase() + outlet.substring(1) + ":");
        if ([source respondsToSelector:setter])
        {
            [source performSelector:setter withObject:target];
            applied++;
        }
    }

    // 3. Show the visible windows (hidden ones can still be opened by actions)
    var shown = 0;
    for (var i = 0; i < windowViews.length; i++)
    {
        var data = [windowViews[i] dataObject],
            nativeWindow = [map objectForKey:[data valueForKey:@"id"]];

        if ([data valueForKey:@"visible"] === false)
            continue;

        var x = [data valueForKey:@"x"],
            y = [data valueForKey:@"y"];

        [nativeWindow setFrameOrigin:CGPointMake((x === nil || x === undefined) ? 80 + 30 * shown : x,
                                                 (y === nil || y === undefined) ? 80 + 30 * shown : y)];
        [nativeWindow makeKeyAndOrderFront:self];
        shown++;
    }

    [self _appendRunLog:UIBLocalizedFormat(@"Preview: %@ of %@ windows shown, %@ connections applied, %@ actions go to #CPOwner.",
                                           shown, windowViews.length, applied, actionsToOwner)];
    if (shown < windowViews.length)
        [self _appendRunLog:UIBLocalized(@"Windows with visible=\"NO\" are created but not shown.")];
    [self _appendRunLog:UIBLocalized(@"Bindings are not connected in the preview (there is no data store).")];
}

- (id)addNewElementOfType:(CPString)elementType atPoint:(CGPoint)aPoint inParent:(id)parent atIndex:(int)index
{
    return [_builderController addNewElementOfType:elementType atPoint:aPoint inParent:parent atIndex:index];
}

- (void)deleteElement:(UIElementView)elementView
{
    [_builderController deleteElement:[elementView dataObject]];
}

#pragma mark -
#pragma mark Cappusance Markup Panels

- (CPPanel)_markupPanelWithTitle:(CPString)aTitle textView:(Function)textViewRef
{
    var panel = [[CPPanel alloc] initWithContentRect:CGRectMake(0, 0, 720, 640) styleMask:CPTitledWindowMask | CPClosableWindowMask | CPResizableWindowMask];
    [panel setTitle:aTitle];
    [panel center];
    [panel setDelegate:self];

    // Same level as the floating inspector and element library (see DataModelEditorController).
    [panel setFloatingPanel:YES];

    var contentView = [panel contentView],
        bounds = [contentView bounds];

    var scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, bounds.size.height - 44)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    var textView = [[CPTextView alloc] initWithFrame:[[scrollView contentView] bounds]];
    [textView setFont:[CPFont fontWithName:@"Menlo, Monaco, monospace" size:12]];
    [textView setAutoresizingMask:CPViewWidthSizable];

    [scrollView setDocumentView:textView];
    [contentView addSubview:scrollView];

    textViewRef(textView);
    return panel;
}

- (CPButton)_panelButton:(CPString)aTitle x:(float)x inPanel:(CPPanel)aPanel action:(SEL)anAction
{
    var bounds = [[aPanel contentView] bounds],
        button = [[CPButton alloc] initWithFrame:CGRectMake(x, bounds.size.height - 34, 140, 24)];

    [button setTitle:aTitle];
    [button setTarget:self];
    [button setAction:anAction];
    [button setAutoresizingMask:CPViewMinYMargin | (x > bounds.size.width / 2 ? CPViewMinXMargin : CPViewMaxXMargin)];
    [[aPanel contentView] addSubview:button];
    return button;
}

/*!
    Shows the document as Cappusance markup, all of it selected, ready to be
    copied out with ⌘C (or with the Copy button).
*/
- (void)save:(id)sender
{
    var hasInterface = [_builderController hasInterface],
        hasModel = [_builderController hasDataModel],
        mode = hasModel ? (hasInterface ? 2 : 1) : 0;

    // The last choice wins, as long as it does not leave out the data model.
    if (_lastMarkupMode !== undefined && _lastMarkupMode !== nil && !(hasModel && _lastMarkupMode === 0))
        mode = _lastMarkupMode;

    [self _showMarkupForMode:mode];
}

- (void)saveDataModel:(id)sender
{
    [self _showMarkupForMode:1];
}

- (CPString)_markupForMode:(int)aMode
{
    if (aMode === 1)
        return [_builderController cappusanceMarkupIncludingInterface:NO model:YES];
    if (aMode === 2)
        return [_builderController cappusanceMarkupIncludingInterface:YES model:YES];
    return [_builderController cappusanceMarkupIncludingInterface:YES model:NO];
}

/*!
    Shows markup (0: interface, 1: data model, 2: both in one file), all of it
    selected, ready to be copied out with ⌘C.
*/
- (void)_showMarkupForMode:(int)aMode
{
    var textView = nil,
        panel = [self _markupPanelWithTitle:UIBLocalized(@"Cappusance Markup — everything is selected, press ⌘C to copy") textView:function(aTextView) { textView = aTextView; }],
        contentView = [panel contentView],
        bounds = [contentView bounds];

    // A bar at the top: what to write.
    var topBar = [[CPView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, 44)];
    [topBar setBackgroundColor:[CPColor colorWithCalibratedWhite:0.95 alpha:1.0]];
    [topBar setAutoresizingMask:CPViewWidthSizable];
    [contentView addSubview:topBar];

    var modeLabel = [[CPTextField alloc] initWithFrame:CGRectMake(10, 13, 60, 20)];
    [modeLabel setStringValue:UIBLocalized(@"Content:")];
    [modeLabel setFont:[CPFont boldSystemFontOfSize:12]];
    [modeLabel setBezeled:NO];
    [modeLabel setDrawsBackground:NO];
    [modeLabel setEditable:NO];
    [topBar addSubview:modeLabel];

    var modePopUp = [[CPPopUpButton alloc] initWithFrame:CGRectMake(70, 9, 240, 26) pullsDown:NO];
    [modePopUp addItemsWithTitles:["Interface (gui.gsmarkup)", "Data model (model.gsmarkup)", "Both in one file"].map(UIBLocalized)];
    [modePopUp selectItemAtIndex:aMode];
    [modePopUp setTarget:self];
    [modePopUp setAction:@selector(markupModeChanged:)];
    [topBar addSubview:modePopUp];

    var modeHint = [[CPTextField alloc] initWithFrame:CGRectMake(322, 14, bounds.size.width - 332, 18)];
    [modeHint setFont:[CPFont systemFontOfSize:11]];
    [modeHint setTextColor:[CPColor colorWithCalibratedRed:0.75 green:0.35 blue:0.0 alpha:1.0]];
    [modeHint setBezeled:NO];
    [modeHint setDrawsBackground:NO];
    [modeHint setEditable:NO];
    [modeHint setAutoresizingMask:CPViewWidthSizable];
    [topBar addSubview:modeHint];
    modePopUp._hint = modeHint;

    // Make room for the bar above the text.
    var subviews = [contentView subviews];
    for (var i = 0; i < subviews.length; i++)
        if ([subviews[i] isKindOfClass:[CPScrollView class]])
            [subviews[i] setFrame:CGRectMake(0, 44, bounds.size.width, bounds.size.height - 88)];

    var copyButton = [self _panelButton:UIBLocalized(@"Copy to Clipboard") x:10 inPanel:panel action:@selector(copyMarkup:)],
        downloadButton = [self _panelButton:UIBLocalized(@"Download…") x:bounds.size.width - 150 inPanel:panel action:@selector(downloadMarkup:)];

    modePopUp._textView = textView;
    modePopUp._buttons = [copyButton, downloadButton];

    [panel makeKeyAndOrderFront:self];
    [self markupModeChanged:modePopUp];

    // The user has the markup now; treat the document as saved.
    [_builderController setDocumentEdited:NO];
}

- (void)markupModeChanged:(id)sender
{
    var mode = [sender indexOfSelectedItem],
        markup = [self _markupForMode:mode],
        textView = sender._textView,
        hasModel = [_builderController hasDataModel],
        hasInterface = [_builderController hasInterface];

    _lastMarkupMode = mode;

    var hint = "";
    if (mode === 0 && hasModel)
        hint = "The data model is not included – choose “Data model” or “Both”.";
    else if (mode === 1 && hasInterface)
        hint = "The interface is not included.";
    else if (mode !== 0 && !hasModel)
        hint = "There is no data model yet (Data ▸ Data Model Editor).";
    [sender._hint setStringValue:UIBLocalized(hint)];

    [textView setString:markup];

    for (var i = 0; i < sender._buttons.length; i++)
    {
        sender._buttons[i]._markup = markup;
        sender._buttons[i]._fileName = (mode === 1) ? "model.gsmarkup" : "gui.gsmarkup";
    }

    [sender._buttons[0] setTitle:UIBLocalized(@"Copy to Clipboard")];
    [[textView window] makeFirstResponder:textView];
    [textView setSelectedRange:CPMakeRange(0, [markup length])];
}

- (void)copyMarkup:(id)sender
{
    var markup = sender._markup;

    if (typeof navigator !== "undefined" && navigator.clipboard && navigator.clipboard.writeText)
    {
        navigator.clipboard.writeText(markup).then(function()
        {
            [sender setTitle:UIBLocalized(@"Copied ✓")];
            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        }, function()
        {
            [sender setTitle:UIBLocalized(@"Use ⌘C instead")];
            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        });
    }
    else
    {
        var pasteboard = [CPPasteboard generalPasteboard];
        [pasteboard declareTypes:[CPStringPboardType] owner:nil];
        [pasteboard setString:markup forType:CPStringPboardType];
        [sender setTitle:UIBLocalized(@"Copied ✓")];
    }
}

- (void)downloadMarkup:(id)sender
{
    var blob = new Blob([sender._markup], { type: "application/xml" }),
        url = URL.createObjectURL(blob),
        link = document.createElement("a");

    link.href = url;
    link.download = sender._fileName || "interface.gsmarkup";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    window.setTimeout(function() { URL.revokeObjectURL(url); }, 1000);
}

/*!
    Import: paste Cappusance markup (or open a .gsmarkup file) and replace
    the current document with it.
*/
- (void)importDataModel:(id)sender
{
    [self _showImportPanelModelOnly:YES];
}

- (void)load:(id)sender
{
    if (![self _confirmDiscardingChanges])
        return;

    [self _showImportPanelModelOnly:NO];
}

- (void)_showImportPanelModelOnly:(BOOL)modelOnly
{
    var textView = nil,
        panel = [self _markupPanelWithTitle:UIBLocalized(@"Import Cappusance Markup — paste the markup below") textView:function(aTextView) { textView = aTextView; }];

    var fileButton = [self _panelButton:UIBLocalized(@"Open File…") x:10 inPanel:panel action:@selector(chooseMarkupFile:)];
    fileButton._textView = textView;

    var importButton = [self _panelButton:UIBLocalized(@"Import") x:[[panel contentView] bounds].size.width - 150 inPanel:panel action:@selector(performLoad:)];
    importButton._textView = textView;
    importButton._modelOnly = modelOnly;

    if (modelOnly)
        [panel setTitle:UIBLocalized(@"Import Data Model — paste model.gsmarkup (the interface is kept)")];
    [importButton setKeyEquivalent:CPCarriageReturnCharacter];
    [importButton setKeyEquivalentModifierMask:CPCommandKeyMask];

    [panel makeKeyAndOrderFront:self];
    [panel makeFirstResponder:textView];
}

- (void)chooseMarkupFile:(id)sender
{
    var textView = sender._textView,
        input = document.createElement("input");

    input.type = "file";
    input.accept = ".gsmarkup,.xml,.txt,text/xml,application/xml";
    input.style.display = "none";
    input.onchange = function()
    {
        var file = input.files && input.files[0];
        if (!file)
            return;

        var reader = new FileReader();
        reader.onload = function()
        {
            [textView setString:reader.result];
            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        };
        reader.readAsText(file);
        document.body.removeChild(input);
    };

    document.body.appendChild(input);
    input.click();
}

- (void)performLoad:(id)sender
{
    var markup = [sender._textView string];

    if (!markup || !String(markup).trim().length)
    {
        var alert = [CPAlert alertWithMessageText:UIBLocalized(@"Nothing to Import") defaultButton:UIBLocalized(@"OK") alternateButton:nil otherButton:nil informativeTextWithFormat:UIBLocalized(@"Paste Cappusance markup (a <gsmarkup> document) into the text view first.")];
        [alert runModal];
        return;
    }

    // A pure data model file (model.gsmarkup) only replaces the data model.
    var isModelOnly = !/<window[\s>]/.test(markup) && /<(arrayController|entities|sortDescriptor)[\s>]/.test(markup),
        error = (isModelOnly || sender._modelOnly) ? [_builderController importDataModelFromMarkup:markup] : [_builderController loadCappusanceMarkup:markup];

    if (!error && isModelOnly)
        [self showDataModelEditor:self];

    if (error)
    {
        var errorAlert = [CPAlert alertWithMessageText:UIBLocalized(@"Could Not Import") defaultButton:UIBLocalized(@"OK") alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", UIBLocalized(error)];
        [errorAlert runModal];
        return;
    }

    [[sender window] close];
    [_canvasView updateDocumentSize];
    [[[_canvasView enclosingScrollView] contentView] scrollToPoint:CGPointMake(0, 0)];
    [_canvasView setNeedsDisplay:YES];
    [_window makeFirstResponder:_canvasView];
}

@end

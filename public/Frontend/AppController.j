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
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{
    // 1. Create the main window and canvas
    _window = [[CPWindow alloc] initWithContentRect:CGRectMakeZero() styleMask:CPBorderlessBridgeWindowMask];
    [_window setTitle:@"Cappuccino UI Builder"];
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

    // 4. An empty document (with its File's Owner)
    [_builderController newDocument];
    [_canvasView updateDocumentSize];

    // 5. Create the main menu
    [self createMainMenu];
    [self _updateWindowTitle];

    [_window makeKeyAndOrderFront:self];
    [_window makeFirstResponder:_canvasView];
}

- (void)_canvasClipViewDidResize:(CPNotification)aNotification
{
    [_canvasView updateDocumentSize];
}

- (void)createMainMenu
{
    var mainMenuBar = [[CPMenu alloc] initWithTitle:@"MainMenu"];

    // File
    var fileMenuItem = [[CPMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    var fileMenu = [[CPMenu alloc] initWithTitle:@"File"];
    [fileMenu addItemWithTitle:@"New" action:@selector(newDocument:) keyEquivalent:@""];
    [fileMenu addItemWithTitle:@"Import Cappusance Markup…" action:@selector(load:) keyEquivalent:@"l"];
    [fileMenu addItemWithTitle:@"Save as Cappusance Markup…" action:@selector(save:) keyEquivalent:@"s"];
    [fileMenu addItem:[CPMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Run" action:@selector(run:) keyEquivalent:@"r"];
    [fileMenuItem setSubmenu:fileMenu];
    [mainMenuBar addItem:fileMenuItem];

    // Edit
    var editMenuItem = [[CPMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    var editMenu = [[CPMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:[CPMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Duplicate" action:@selector(duplicate:) keyEquivalent:@"d"];
    [editMenu addItemWithTitle:@"Delete" action:@selector(delete:) keyEquivalent:@""];
    [editMenu addItem:[CPMenuItem separatorItem]];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    [editMenu addItemWithTitle:@"Select Parent" action:@selector(selectParent:) keyEquivalent:@""];
    [editMenuItem setSubmenu:editMenu];
    [mainMenuBar addItem:editMenuItem];

    // Arrange
    var arrangeMenuItem = [[CPMenuItem alloc] initWithTitle:@"Arrange" action:nil keyEquivalent:@""];
    var arrangeMenu = [[CPMenu alloc] initWithTitle:@"Arrange"];
    [arrangeMenu addItemWithTitle:@"Group in HBox" action:@selector(groupInHBox:) keyEquivalent:@"g"];
    [arrangeMenu addItemWithTitle:@"Group in VBox" action:@selector(groupInVBox:) keyEquivalent:@""];
    [arrangeMenu addItemWithTitle:@"Ungroup" action:@selector(ungroup:) keyEquivalent:@"G"];
    [arrangeMenu addItem:[CPMenuItem separatorItem]];
    [arrangeMenu addItemWithTitle:@"Move Earlier" action:@selector(moveEarlier:) keyEquivalent:@"["];
    [arrangeMenu addItemWithTitle:@"Move Later" action:@selector(moveLater:) keyEquivalent:@"]"];
    [arrangeMenuItem setSubmenu:arrangeMenu];
    [mainMenuBar addItem:arrangeMenuItem];

    // Data model
    var dataMenuItem = [[CPMenuItem alloc] initWithTitle:@"Daten" action:nil keyEquivalent:@""];
    var dataMenu = [[CPMenu alloc] initWithTitle:@"Daten"];
    [dataMenu addItemWithTitle:@"Datenmodell-Editor…" action:@selector(showDataModelEditor:) keyEquivalent:@""];
    [dataMenu addItem:[CPMenuItem separatorItem]];
    [dataMenu addItemWithTitle:@"Datenmodell importieren…" action:@selector(importDataModel:) keyEquivalent:@""];
    [dataMenu addItemWithTitle:@"Datenmodell sichern…" action:@selector(saveDataModel:) keyEquivalent:@""];
    [dataMenuItem setSubmenu:dataMenu];
    [mainMenuBar addItem:dataMenuItem];

    // Window
    var windowMenuItem = [[CPMenuItem alloc] initWithTitle:@"Fenster" action:nil keyEquivalent:@""];
    var windowMenu = [[CPMenu alloc] initWithTitle:@"Fenster"];
    [windowMenu addItemWithTitle:@"Elemente" action:@selector(showPalette:) keyEquivalent:@""];
    [windowMenu addItemWithTitle:@"Inspector" action:@selector(showInspector:) keyEquivalent:@""];
    [windowMenu addItemWithTitle:@"Datenmodell" action:@selector(showDataModelEditor:) keyEquivalent:@""];
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
        [aMenuItem setTitle:[undoManager undoMenuItemTitle] || @"Undo"];
        return [undoManager canUndo];
    }

    if (action == @selector(redo:))
    {
        [aMenuItem setTitle:[undoManager redoMenuItemTitle] || @"Redo"];
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
    var title = @"Cappuccino UI Builder";
    if ([_builderController isDocumentEdited])
        title += @" — Edited";

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

    return window.confirm("The current interface has unsaved changes. Discard them?");
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
    [inspectorPanel setTitle:@"Inspector"];
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
            console.log("Run: Processing element: " + [[view dataObject] valueForKey:@"id"]);
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
    // Interface by default; only the data model if there is no interface.
    [self _showMarkupForMode:([_builderController hasInterface] || ![_builderController hasDataModel]) ? 0 : 1];
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
        panel = [self _markupPanelWithTitle:@"Cappusance Markup — alles markiert, ⌘C kopiert" textView:function(aTextView) { textView = aTextView; }],
        bounds = [[panel contentView] bounds];

    var modePopUp = [[CPPopUpButton alloc] initWithFrame:CGRectMake(160, bounds.size.height - 35, 220, 26) pullsDown:NO];
    [modePopUp addItemsWithTitles:["Oberfläche (gui)", "Datenmodell (model)", "Beides in einer Datei"]];
    [modePopUp selectItemAtIndex:aMode];
    [modePopUp setTarget:self];
    [modePopUp setAction:@selector(markupModeChanged:)];
    [modePopUp setAutoresizingMask:CPViewMinYMargin | CPViewMaxXMargin];
    [[panel contentView] addSubview:modePopUp];

    var copyButton = [self _panelButton:@"In Zwischenablage" x:10 inPanel:panel action:@selector(copyMarkup:)],
        downloadButton = [self _panelButton:@"Download…" x:bounds.size.width - 150 inPanel:panel action:@selector(downloadMarkup:)];

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
        textView = sender._textView;

    [textView setString:markup];

    for (var i = 0; i < sender._buttons.length; i++)
    {
        sender._buttons[i]._markup = markup;
        sender._buttons[i]._fileName = (mode === 1) ? "model.gsmarkup" : "gui.gsmarkup";
    }

    [sender._buttons[0] setTitle:@"In Zwischenablage"];
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
            [sender setTitle:@"Copied ✓"];
            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        }, function()
        {
            [sender setTitle:@"Use ⌘C instead"];
            [[CPRunLoop currentRunLoop] limitDateForMode:CPDefaultRunLoopMode];
        });
    }
    else
    {
        var pasteboard = [CPPasteboard generalPasteboard];
        [pasteboard declareTypes:[CPStringPboardType] owner:nil];
        [pasteboard setString:markup forType:CPStringPboardType];
        [sender setTitle:@"Copied ✓"];
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
        panel = [self _markupPanelWithTitle:@"Import Cappusance Markup — paste the markup below" textView:function(aTextView) { textView = aTextView; }];

    var fileButton = [self _panelButton:@"Open File…" x:10 inPanel:panel action:@selector(chooseMarkupFile:)];
    fileButton._textView = textView;

    var importButton = [self _panelButton:@"Importieren" x:[[panel contentView] bounds].size.width - 150 inPanel:panel action:@selector(performLoad:)];
    importButton._textView = textView;
    importButton._modelOnly = modelOnly;

    if (modelOnly)
        [panel setTitle:@"Datenmodell importieren — model.gsmarkup einfügen (die Oberfläche bleibt erhalten)"];
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
        var alert = [CPAlert alertWithMessageText:@"Nothing to Import" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Paste Cappusance markup (a <gsmarkup> document) into the text view first."];
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
        var errorAlert = [CPAlert alertWithMessageText:@"Could Not Import" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", error];
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

//
//  UIBPalette.j
//  The element library: a light panel with grouped, searchable tiles.
//  Drag a tile onto the canvas (or into a window, box, ...) to add the element.
//

@import <AppKit/CPView.j>
@import "UIBuilderConstants.j"

var UIBPaletteTileWidth = 76,
    UIBPaletteTileHeight = 66,
    UIBPaletteColumns = 4,
    UIBPalettePadding = 10;

var UIBPaletteSections = [
    { title: "Fenster & Container", items: [
        ["window", UIWindowDragType, "Fenster", "Ein Fenster (<window>)"],
        ["box", UIBoxDragType, "Box", "Rahmen mit Titel (<box>)"],
        ["tabView", UITabViewDragType, "Tab View", "Register mit Seiten (<tabView>)"],
        ["splitView", UISplitViewDragType, "Split View", "Geteilte Ansicht (<splitView>)"],
        ["scrollView", UIScrollViewDragType, "Scroll View", "Rollbarer Bereich (<scrollView>)"] ] },
    { title: "Layout", items: [
        ["vbox", UIVBoxDragType, "VBox", "Untereinander anordnen (<vbox>)"],
        ["hbox", UIHBoxDragType, "HBox", "Nebeneinander anordnen (<hbox>)"],
        ["hspace", UIHSpaceDragType, "HSpace", "Horizontaler Abstand (<hspace>)"],
        ["vspace", UIVSpaceDragType, "VSpace", "Vertikaler Abstand (<vspace>)"] ] },
    { title: "Text", items: [
        ["label", UILabelDragType, "Label", "Beschriftung (<label>)"],
        ["textField", UITextFieldDragType, "Textfeld", "Eingabefeld (<textField>)"],
        ["searchField", UISearchFieldDragType, "Suchfeld", "Suchfeld (<searchField>)"],
        ["secureField", UISecureFieldDragType, "Passwort", "Passwortfeld (<secureTextField>)"],
        ["comboBox", UIComboBoxDragType, "Combo Box", "Eingabe mit Liste (<comboBox>)"],
        ["textView", UITextViewDragType, "Text View", "Mehrzeiliger Text (<textView>)"] ] },
    { title: "Steuerelemente", items: [
        ["button", UIButtonDragType, "Button", "Schaltfläche (<button>)"],
        ["checkBox", UICheckBoxDragType, "Checkbox", "Ankreuzfeld (<switchButton>)"],
        ["popUpButton", UIPopUpButtonDragType, "Pop-Up", "Auswahlmenü (<popUpButton>)"],
        ["slider", UISliderDragType, "Slider", "Schieberegler (<slider>)"],
        ["stepper", UIStepperDragType, "Stepper", "Auf/Ab-Schalter (<stepper>)"],
        ["datePicker", UIDatePickerDragType, "Datum", "Datumsauswahl (<datePicker>)"],
        ["progresIndicator", UIProgressIndicatorDragType, "Fortschritt", "Fortschrittsanzeige (<progresIndicator>)"] ] },
    { title: "Daten & Sonstiges", items: [
        ["tableView", UITableViewDragType, "Tabelle", "Tabelle (<tableView>), mit Array Controller verbinden"],
        ["imageView", UIImageViewDragType, "Bild", "Bild (<imageView>)"],
        ["custom", UICustomViewDragType, "Eigenes", "Beliebiges Element (eigener Tag)"] ] }
];


@implementation UIBPaletteTile : CPView
{
    CPString _elementType;
    CPString _dragType;
    CPString _title;
    BOOL     _isPressed;
    BOOL     _isPlaceholder;
}

- (id)initWithElementType:(CPString)anElementType dragType:(CPString)aDragType title:(CPString)aTitle
{
    self = [super initWithFrame:CGRectMake(0, 0, UIBPaletteTileWidth, UIBPaletteTileHeight)];
    if (self)
    {
        _elementType = anElementType;
        _dragType = aDragType;
        _title = aTitle;
    }
    return self;
}

- (CPString)title       { return _title; }
- (CPString)elementType { return _elementType; }

- (BOOL)acceptsFirstMouse:(CPEvent)anEvent
{
    return YES;
}

- (void)drawRect:(CGRect)aRect
{
    var bounds = [self bounds],
        tile = CGRectMake(10, 2, bounds.size.width - 20, 42),
        path = UIBRoundedPath(tile, 8);

    UIBWithShadow(1, 2, UIBRGB(0, 0, 0, 0.10), function()
    {
        UIBFillStroke(path, _isPressed ? UIBTheme("accentSoft") : UIBTheme("tile"), nil);
    });
    UIBFillStroke(path, nil, _isPressed ? UIBTheme("accent") : UIBTheme("tileBorder"), 1);

    UIBDrawElementIcon(_elementType, CGRectMake(tile.origin.x + 6, tile.origin.y + 6, tile.size.width - 12, tile.size.height - 12));

    if (!_isPlaceholder)
        UIBDrawTextInRect(_title, CGRectMake(0, 46, bounds.size.width, 18), UIBFont(11), UIBTheme("text"), "center");
}

- (void)mouseDown:(CPEvent)anEvent
{
    _isPressed = YES;
    [self setNeedsDisplay:YES];

    var placeholder = [[UIBPaletteTile alloc] initWithElementType:_elementType dragType:_dragType title:_title];
    placeholder._isPlaceholder = YES;
    [placeholder setAlphaValue:0.85];

    var pasteboard = [CPPasteboard pasteboardWithName:CPDragPboard];
    [pasteboard declareTypes:[_dragType] owner:nil];
    // The element type travels with the drag, so the canvas knows exactly what to create.
    [pasteboard setString:_elementType forType:_dragType];

    [self dragView:placeholder at:CGPointMakeZero() offset:nil event:anEvent pasteboard:pasteboard source:self slideBack:YES];
}

- (void)draggedView:(CPView)aView endedAt:(CGPoint)aLocation operation:(CPDragOperation)anOperation
{
    _isPressed = NO;
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(CPEvent)anEvent
{
    _isPressed = NO;
    [self setNeedsDisplay:YES];
}

@end


@implementation UIBPaletteContentView : CPView
{
    CPArray _sections;   // [{ header, tiles }]
}

- (id)initWithFrame:(CGRect)aFrame
{
    self = [super initWithFrame:aFrame];
    if (self)
    {
        _sections = [];

        for (var s = 0; s < UIBPaletteSections.length; s++)
        {
            var section = UIBPaletteSections[s],
                header = [[CPTextField alloc] initWithFrame:CGRectMake(UIBPalettePadding, 0, 300, 16)];

            [header setStringValue:section.title.toUpperCase()];
            [header setFont:UIBFont(10, YES)];
            [header setTextColor:UIBTheme("secondaryText")];
            [header setBezeled:NO];
            [header setDrawsBackground:NO];
            [header setEditable:NO];
            [header setSelectable:NO];
            [self addSubview:header];

            var tiles = [];
            for (var i = 0; i < section.items.length; i++)
            {
                var item = section.items[i],
                    tile = [[UIBPaletteTile alloc] initWithElementType:item[0] dragType:item[1] title:item[2]];
                if ([tile respondsToSelector:@selector(setToolTip:)])
                    [tile setToolTip:item[3]];
                [self addSubview:tile];
                tiles.push(tile);
            }

            _sections.push({ header: header, tiles: tiles });
        }

        [self filterWithString:@""];
    }
    return self;
}

// Shows the tiles whose title or type contains aString; returns the needed height.
- (float)filterWithString:(CPString)aString
{
    var filter = String(aString || "").toLowerCase(),
        y = 4;

    for (var s = 0; s < _sections.length; s++)
    {
        var section = _sections[s],
            visible = section.tiles.filter(function(tile)
            {
                return !filter || [tile title].toLowerCase().indexOf(filter) >= 0 || [tile elementType].toLowerCase().indexOf(filter) >= 0;
            });

        [section.header setHidden:!visible.length];
        for (var i = 0; i < section.tiles.length; i++)
            [section.tiles[i] setHidden:visible.indexOf(section.tiles[i]) < 0];

        if (!visible.length)
            continue;

        [section.header setFrameOrigin:CGPointMake(UIBPalettePadding + 4, y)];
        y += 20;

        for (var i = 0; i < visible.length; i++)
        {
            var column = i % UIBPaletteColumns,
                row = Math.floor(i / UIBPaletteColumns);
            [visible[i] setFrameOrigin:CGPointMake(UIBPalettePadding + column * UIBPaletteTileWidth, y + row * UIBPaletteTileHeight)];
        }

        y += Math.ceil(visible.length / UIBPaletteColumns) * UIBPaletteTileHeight + 8;
    }

    [self setFrameSize:CGSizeMake([self frame].size.width, MAX(y, 40))];
    return y;
}

@end


@implementation UIBPaletteController : CPObject
{
    UIBPaletteContentView _contentView;
}

- (void)searchChanged:(id)sender
{
    [_contentView filterWithString:[sender stringValue]];
}

@end

var UIBSharedPaletteController = nil;

// Builds the element palette panel.
UIBCreatePalette = function()
{
    var width = UIBPalettePadding * 2 + UIBPaletteColumns * UIBPaletteTileWidth + 16,
        height = MIN(720, window.innerHeight - 80),
        screenWidth = window.innerWidth;

    var panel = [[CPPanel alloc] initWithContentRect:CGRectMake(MAX(360, screenWidth - width - 20), 40, width, height)
                                           styleMask:CPTitledWindowMask | CPClosableWindowMask | CPResizableWindowMask];
    [panel setTitle:@"Elemente"];
    [panel setFloatingPanel:YES];
    if ([panel respondsToSelector:@selector(setBecomesKeyOnlyIfNeeded:)])
        [panel setBecomesKeyOnlyIfNeeded:YES];

    var contentView = [panel contentView],
        bounds = [contentView bounds];

    [contentView setBackgroundColor:UIBRGB(246, 246, 248)];

    var search = [[CPSearchField alloc] initWithFrame:CGRectMake(10, 8, bounds.size.width - 20, 28)];
    [search setPlaceholderString:@"Element suchen"];
    [search setAutoresizingMask:CPViewWidthSizable];
    [search setSendsSearchStringImmediately:YES];
    [contentView addSubview:search];

    var scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(0, 42, bounds.size.width, bounds.size.height - 42)];
    [scrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [scrollView setHasHorizontalScroller:NO];
    [scrollView setAutohidesScrollers:YES];

    var tiles = [[UIBPaletteContentView alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width - 4, 100)];
    [scrollView setDocumentView:tiles];
    [contentView addSubview:scrollView];

    UIBSharedPaletteController = [[UIBPaletteController alloc] init];
    UIBSharedPaletteController._contentView = tiles;
    [search setTarget:UIBSharedPaletteController];
    [search setAction:@selector(searchChanged:)];

    return panel;
};

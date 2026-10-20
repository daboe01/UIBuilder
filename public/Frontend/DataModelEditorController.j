//
//  DataModelEditorController.j
//  Edits the data model of the document: entities (columns, relationships),
//  array controllers and sort descriptors. Every change goes through the
//  builder controller and can be undone.
//

@import <Foundation/CPObject.j>
@import "UIBuilderConstants.j"

@class UIBuilderController

var UIBCheckMark = "✓";

// A view that lays out its subviews with a function, from its real size.
@implementation UIBLayoutView : CPView
{
    Function _layoutHandler;
}

- (void)setLayoutHandler:(Function)aFunction
{
    _layoutHandler = aFunction;
    [self resizeSubviewsWithOldSize:[self frame].size];
}

- (void)resizeSubviewsWithOldSize:(CGSize)aSize
{
    if (_layoutHandler)
        _layoutHandler([self bounds].size);
    else
        [super resizeSubviewsWithOldSize:aSize];
}

@end

// Makes a table at least as large as the visible area of its scroll view and
// lets the last column use the remaining width. Called after every layout.
function UIBFitTable(aTable)
{
    var clipView = [aTable superview];
    if (!clipView)
        return;

    var visible = [clipView bounds].size,
        columns = [aTable tableColumns],
        total = 0;

    for (var i = 0; i < [columns count]; i++)
        total += [columns[i] width];

    [aTable setFrameSize:CGSizeMake(MAX(visible.width, total), MAX(visible.height, [aTable frame].size.height))];

    if ([aTable respondsToSelector:@selector(sizeLastColumnToFit)])
        [aTable sizeLastColumnToFit];
}

// A native +/− bar attached under a table.
function UIBNewButtonBar(aTarget, addAction, removeAction)
{
    var bar = [[CPButtonBar alloc] initWithFrame:CGRectMake(0, 0, 100, 26)],
        plus = [CPButtonBar plusButton],
        minus = [CPButtonBar minusButton];

    [plus setTarget:aTarget];
    [plus setAction:addAction];
    [minus setTarget:aTarget];
    [minus setAction:removeAction];

    if ([bar respondsToSelector:@selector(setHasResizeControl:)])
        [bar setHasResizeControl:NO];

    [bar setButtons:[plus, minus]];
    bar._uibPlus = plus;
    bar._uibMinus = minus;
    return bar;
}

function UIBSetButtonBarEnabled(aBar, canAdd, canRemove)
{
    [aBar._uibPlus setEnabled:!!canAdd];
    [aBar._uibMinus setEnabled:!!canRemove];
}

@implementation DataModelEditorController : CPObject
{
    UIBuilderController _builderController;
    CPPanel             _panel;
    CPTabView           _tabView;

    // Entities
    CPSearchField       _entitySearchField;
    CPTableView         _entitiesTable;
    CPTableView         _columnsTable;
    CPTableView         _relationshipsTable;
    CPTextField         _entityHeader;
    CPArray             _visibleEntities;

    // Array controllers
    CPSearchField       _controllerSearchField;
    CPTableView         _controllersTable;
    CPArray             _visibleControllers;
    CPButton            _insertTableButton;

    // Sort descriptors
    CPTableView         _sortDescriptorsTable;

    // +/− bars (enabled according to the selection)
    CPButtonBar         _entitiesBar;
    CPButtonBar         _columnsBar;
    CPButtonBar         _relationshipsBar;
    CPButtonBar         _controllersBar;
    CPButtonBar         _sortBar;
    CPButton            _addControllerButton;
}

- (id)initWithBuilderController:(UIBuilderController)aController
{
    self = [super init];
    if (self)
    {
        _builderController = aController;
        _visibleEntities = [];
        _visibleControllers = [];

        [[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(dataModelDidChange:) name:UIBDataModelDidChangeNotification object:aController];
    }
    return self;
}

#pragma mark -
#pragma mark Panel

- (void)showWindow:(id)sender
{
    if (!_panel)
        [self _buildPanel];

    [self reloadAll];
    [_panel makeKeyAndOrderFront:self];
}

- (CPUndoManager)windowWillReturnUndoManager:(CPWindow)aWindow
{
    return [_builderController undoManager];
}

- (CPTextField)_label:(CPString)aString frame:(CGRect)aFrame bold:(BOOL)isBold
{
    var label = [[CPTextField alloc] initWithFrame:aFrame];
    [label setStringValue:aString];
    [label setFont:isBold ? [CPFont boldSystemFontOfSize:12] : [CPFont systemFontOfSize:11]];
    [label setTextColor:isBold ? [CPColor colorWithCalibratedWhite:0.2 alpha:1.0] : [CPColor grayColor]];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    return label;
}

- (CPButton)_button:(CPString)aTitle frame:(CGRect)aFrame action:(SEL)anAction
{
    var button = [[CPButton alloc] initWithFrame:aFrame];
    [button setTitle:aTitle];
    [button setTarget:self];
    [button setAction:anAction];
    return button;
}

// columns: [[identifier, title, width, isBoolean], ...]
- (CPTableView)_tableInView:(CPView)aView frame:(CGRect)aFrame columns:(CPArray)columns autoresizingMask:(unsigned)aMask
{
    // Start with a real size: a table created with an empty frame draws its
    // rows but never receives clicks (hit testing uses the frame).
    if (CGRectIsEmpty(aFrame))
        aFrame = CGRectMake(0, 0, 400, 300);

    var scrollView = [[CPScrollView alloc] initWithFrame:aFrame];
    [scrollView setAutoresizingMask:aMask];
    [scrollView setHasHorizontalScroller:YES];
    [scrollView setAutohidesScrollers:YES];

    var table = [[CPTableView alloc] initWithFrame:[[scrollView contentView] bounds]];
    [table setUsesAlternatingRowBackgroundColors:YES];
    [table setAllowsMultipleSelection:YES];

    for (var i = 0; i < columns.length; i++)
    {
        var column = [[CPTableColumn alloc] initWithIdentifier:columns[i][0]];
        [[column headerView] setStringValue:UIBLocalized(columns[i][1])];
        [column setWidth:columns[i][2]];
        // Not editable on a single click (that selects the row); double-click edits.
        [column setEditable:NO];
        column._uibIsEditable = !columns[i][3] && columns[i][0] !== "other";
        column._uibIsBoolean = !!columns[i][3];
        [table addTableColumn:column];
    }

    [table setDataSource:self];
    [table setDelegate:self];
    [table setTarget:self];
    [table setDoubleAction:@selector(tableDoubleClicked:)];

    [scrollView setDocumentView:table];
    [aView addSubview:scrollView];
    UIBFitTable(table);
    return table;
}

- (UIBLayoutView)_newTabView
{
    var view = [[UIBLayoutView alloc] initWithFrame:CGRectMake(0, 0, 980, 590)];
    [view setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    return view;
}

- (void)_buildPanel
{
    _panel = [[CPPanel alloc] initWithContentRect:CGRectMake(0, 0, 1000, 640) styleMask:CPTitledWindowMask | CPClosableWindowMask | CPResizableWindowMask];
    [_panel setTitle:UIBLocalized(@"Data Model")];
    [_panel setDelegate:self];

    // Same window level as the inspector and the element library: Cappuccino
    // sends a click to the highest level under the mouse, so an ordinary
    // panel below a floating one would lose its clicks there.
    [_panel setFloatingPanel:YES];

    // Open next to the inspector, not on top of it.
    var panelFrame = [_panel frame];
    panelFrame.origin.x = MAX(370, (window.innerWidth - panelFrame.size.width) / 2);
    panelFrame.origin.y = 60;
    [_panel setFrame:panelFrame];

    _tabView = [[CPTabView alloc] initWithFrame:[[_panel contentView] bounds]];
    [_tabView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    var margin = 10,
        barHeight = 26,
        leftWidth = 280;

    // --- Entities ---
    var entitiesView = [self _newTabView];

    _entitySearchField = [[CPSearchField alloc] initWithFrame:CGRectMakeZero()];
    [_entitySearchField setPlaceholderString:UIBLocalized(@"Search entities")];
    [_entitySearchField setTarget:self];
    [_entitySearchField setAction:@selector(filterChanged:)];
    [_entitySearchField setSendsSearchStringImmediately:YES];
    [entitiesView addSubview:_entitySearchField];

    _entitiesTable = [self _tableInView:entitiesView frame:CGRectMakeZero() columns:[["name", "Entity", 160], ["store", "Store", 110]] autoresizingMask:0];
    var entitiesBar = UIBNewButtonBar(self, @selector(addEntity:), @selector(removeEntity:));
    [entitiesView addSubview:entitiesBar];
    _entitiesBar = entitiesBar;

    _entityHeader = [self _label:UIBLocalized(@"Columns") frame:CGRectMakeZero() bold:YES];
    [entitiesView addSubview:_entityHeader];

    var addController = [self _button:UIBLocalized(@"Create Array Controller") frame:CGRectMakeZero() action:@selector(addControllerForEntity:)];
    [entitiesView addSubview:addController];
    _addControllerButton = addController;

    _columnsTable = [self _tableInView:entitiesView frame:CGRectMakeZero()
                               columns:[["name", "Column", 220], ["primaryKey", "Primary Key", 110, YES], ["optimistic", "Optimistic", 90, YES], ["other", "Other Attributes", 250]]
                      autoresizingMask:0];
    var columnsBar = UIBNewButtonBar(self, @selector(addColumn:), @selector(removeColumn:));
    [entitiesView addSubview:columnsBar];
    _columnsBar = columnsBar;

    var hint = [self _label:UIBLocalized(@"Double-click a ✓ column to toggle it") frame:CGRectMakeZero() bold:NO];
    [hint setAlignment:CPRightTextAlignment];
    [entitiesView addSubview:hint];

    var relationshipsHeader = [self _label:UIBLocalized(@"Relationships") frame:CGRectMakeZero() bold:YES];
    [entitiesView addSubview:relationshipsHeader];

    _relationshipsTable = [self _tableInView:entitiesView frame:CGRectMakeZero()
                                     columns:[["name", "Name", 150], ["type", "Type", 80], ["target", "Target Entity", 170], ["bindingColumn", "bindingColumn", 130], ["targetColumn", "targetColumn", 130]]
                            autoresizingMask:0];
    var relationshipsBar = UIBNewButtonBar(self, @selector(addRelationship:), @selector(removeRelationship:));
    [entitiesView addSubview:relationshipsBar];
    _relationshipsBar = relationshipsBar;

    var entitiesTable = _entitiesTable, columnsTable = _columnsTable, relationshipsTable = _relationshipsTable,
        entitySearch = _entitySearchField, entityHeader = _entityHeader;

    [entitiesView setLayoutHandler:function(size)
    {
        var w = size.width, h = size.height;

        [entitySearch setFrame:CGRectMake(margin, margin, leftWidth, 28)];
        [[entitiesTable enclosingScrollView] setFrame:CGRectMake(margin, margin + 36, leftWidth, h - 2 * margin - 36 - barHeight)];
        UIBFitTable(entitiesTable);
        [entitiesBar setFrame:CGRectMake(margin, h - margin - barHeight, leftWidth, barHeight)];

        var x = margin + leftWidth + 16,
            rw = MAX(200, w - x - margin),
            top = margin + 36,
            available = h - top - margin,
            columnsHeight = Math.round(available * 0.55) - barHeight;

        [entityHeader setFrame:CGRectMake(x, margin + 6, rw - 230, 20)];
        [addController setFrame:CGRectMake(x + rw - 220, margin + 1, 220, 26)];

        [[columnsTable enclosingScrollView] setFrame:CGRectMake(x, top, rw, columnsHeight)];
        UIBFitTable(columnsTable);
        [columnsBar setFrame:CGRectMake(x, top + columnsHeight, rw, barHeight)];
        [hint setFrame:CGRectMake(x + 80, top + columnsHeight + 5, rw - 90, 18)];

        var relationshipsTop = top + columnsHeight + barHeight + 16;
        [relationshipsHeader setFrame:CGRectMake(x, relationshipsTop, 200, 20)];
        [[relationshipsTable enclosingScrollView] setFrame:CGRectMake(x, relationshipsTop + 24, rw, MAX(40, h - margin - barHeight - relationshipsTop - 24))];
        UIBFitTable(relationshipsTable);
        [relationshipsBar setFrame:CGRectMake(x, h - margin - barHeight, rw, barHeight)];
    }];

    // --- Array controllers ---
    var controllersView = [self _newTabView];

    _controllerSearchField = [[CPSearchField alloc] initWithFrame:CGRectMakeZero()];
    [_controllerSearchField setPlaceholderString:UIBLocalized(@"Search controllers or entities")];
    [_controllerSearchField setTarget:self];
    [_controllerSearchField setAction:@selector(filterChanged:)];
    [_controllerSearchField setSendsSearchStringImmediately:YES];
    [controllersView addSubview:_controllerSearchField];

    _insertTableButton = [self _button:UIBLocalized(@"Insert Table into Interface") frame:CGRectMakeZero() action:@selector(insertTable:)];
    [controllersView addSubview:_insertTableButton];

    _controllersTable = [self _tableInView:controllersView frame:CGRectMakeZero()
                                   columns:[["name", "id", 200], ["entity", "Entity", 170], ["ownerOutlet", "Outlet in #CPOwner", 170], ["sortDescriptor", "sortDescriptor", 120],
                                            ["valueBinding", "valueBinding (Master)", 220], ["autoFetch", "autoFetch", 70, YES], ["autoFetchSync", "autoFetchSync", 90, YES]]
                          autoresizingMask:0];
    var controllersBar = UIBNewButtonBar(self, @selector(addArrayController:), @selector(removeArrayController:));
    [controllersView addSubview:controllersBar];
    _controllersBar = controllersBar;

    var controllersTable = _controllersTable, controllerSearch = _controllerSearchField, insertButton = _insertTableButton;

    [controllersView setLayoutHandler:function(size)
    {
        var w = size.width, h = size.height;
        [controllerSearch setFrame:CGRectMake(margin, margin, 320, 28)];
        [insertButton setFrame:CGRectMake(w - margin - 270, margin + 1, 270, 26)];
        [[controllersTable enclosingScrollView] setFrame:CGRectMake(margin, margin + 36, w - 2 * margin, h - 2 * margin - 36 - barHeight)];
        UIBFitTable(controllersTable);
        [controllersBar setFrame:CGRectMake(margin, h - margin - barHeight, w - 2 * margin, barHeight)];
    }];

    // --- Sort descriptors ---
    var sortView = [self _newTabView];

    _sortDescriptorsTable = [self _tableInView:sortView frame:CGRectMakeZero()
                                       columns:[["name", "id", 260], ["key", "key", 260], ["ascending", "ascending", 100, YES], ["numeric", "numeric", 100, YES]]
                              autoresizingMask:0];
    var sortBar = UIBNewButtonBar(self, @selector(addSortDescriptor:), @selector(removeSortDescriptor:));
    [sortView addSubview:sortBar];
    _sortBar = sortBar;

    var sortTable = _sortDescriptorsTable;
    [sortView setLayoutHandler:function(size)
    {
        var w = size.width, h = size.height;
        [[sortTable enclosingScrollView] setFrame:CGRectMake(margin, margin, w - 2 * margin, h - 2 * margin - barHeight)];
        UIBFitTable(sortTable);
        [sortBar setFrame:CGRectMake(margin, h - margin - barHeight, w - 2 * margin, barHeight)];
    }];

    var tabs = [["entities", "Entities", entitiesView], ["controllers", "Array Controllers", controllersView], ["sort", "Sort Descriptors", sortView]];
    for (var i = 0; i < tabs.length; i++)
    {
        var item = [[CPTabViewItem alloc] initWithIdentifier:tabs[i][0]];
        [item setLabel:UIBLocalized(tabs[i][1])];
        [item setView:tabs[i][2]];
        [_tabView addTabViewItem:item];
    }

    [_panel setContentView:_tabView];
}

#pragma mark -
#pragma mark Reloading

- (void)dataModelDidChange:(CPNotification)aNotification
{
    if (_panel)
        [self reloadAll];
}

- (id)selectedEntity
{
    var row = [_entitiesTable selectedRow];
    return (row >= 0 && row < _visibleEntities.length) ? _visibleEntities[row] : nil;
}

- (CPArray)_selectedObjectsIn:(CPTableView)aTable from:(CPArray)anArray
{
    var result = [],
        indexes = [aTable selectedRowIndexes],
        index = [indexes firstIndex];

    while (index != CPNotFound)
    {
        if (index < anArray.length)
            result.push(anArray[index]);
        index = [indexes indexGreaterThanIndex:index];
    }
    return result;
}

- (void)_select:(CPArray)objects inTable:(CPTableView)aTable from:(CPArray)anArray
{
    var indexes = [CPIndexSet indexSet];
    for (var i = 0; i < objects.length; i++)
    {
        var index = anArray.indexOf(objects[i]);
        if (index >= 0)
            [indexes addIndex:index];
    }
    [aTable selectRowIndexes:indexes byExtendingSelection:NO];
}

- (void)reloadAll
{
    var selectedEntities = [self _selectedObjectsIn:_entitiesTable from:_visibleEntities],
        selectedControllers = [self _selectedObjectsIn:_controllersTable from:_visibleControllers],
        entityFilter = String([_entitySearchField stringValue] || "").toLowerCase(),
        controllerFilter = String([_controllerSearchField stringValue] || "").toLowerCase();

    _visibleEntities = [_builderController entities].filter(function(entity)
    {
        return !entityFilter || String([entity valueForKey:@"name"] || "").toLowerCase().indexOf(entityFilter) >= 0;
    });

    _visibleControllers = [_builderController arrayControllers].filter(function(controller)
    {
        if (!controllerFilter)
            return YES;
        var text = ([controller valueForKey:@"name"] || "") + " " + ([controller valueForKey:@"entity"] || "") + " " + ([controller valueForKey:@"ownerOutlet"] || "");
        return text.toLowerCase().indexOf(controllerFilter) >= 0;
    });

    [_entitiesTable reloadData];
    [self _select:selectedEntities inTable:_entitiesTable from:_visibleEntities];

    [_controllersTable reloadData];
    [self _select:selectedControllers inTable:_controllersTable from:_visibleControllers];

    [_sortDescriptorsTable reloadData];
    [self _reloadEntityDetails];
}

- (void)_reloadEntityDetails
{
    var entity = [self selectedEntity];
    [_entityHeader setStringValue:entity ? UIBLocalizedFormat(@"Columns of “%@”", [entity valueForKey:@"name"]) : UIBLocalized(@"Columns (no entity selected)")];
    [_columnsTable reloadData];
    [_relationshipsTable reloadData];
    [self _updateButtonStates];
}

// Detail tables can only be edited while their master row is selected;
// "−" needs a selected row.
- (void)_updateButtonStates
{
    var hasEntity = !![self selectedEntity];

    UIBSetButtonBarEnabled(_entitiesBar, YES, [_entitiesTable numberOfSelectedRows] > 0);
    UIBSetButtonBarEnabled(_columnsBar, hasEntity, hasEntity && [_columnsTable numberOfSelectedRows] > 0);
    UIBSetButtonBarEnabled(_relationshipsBar, hasEntity, hasEntity && [_relationshipsTable numberOfSelectedRows] > 0);
    UIBSetButtonBarEnabled(_controllersBar, YES, [_controllersTable numberOfSelectedRows] > 0);
    UIBSetButtonBarEnabled(_sortBar, YES, [_sortDescriptorsTable numberOfSelectedRows] > 0);

    [_addControllerButton setEnabled:hasEntity];
    [_insertTableButton setEnabled:[_controllersTable numberOfSelectedRows] === 1];
}

- (void)filterChanged:(id)sender
{
    [self reloadAll];
}

#pragma mark -
#pragma mark Actions

- (void)addEntity:(id)sender
{
    [_entitySearchField setStringValue:@""];
    var entity = [_builderController addModelObjectOfKind:@"entity"];
    [self reloadAll];
    [self _select:[entity] inTable:_entitiesTable from:_visibleEntities];
    [self _reloadEntityDetails];
    [self _editTable:_entitiesTable column:0 row:_visibleEntities.indexOf(entity)];
}

- (void)removeEntity:(id)sender
{
    [_builderController removeModelObjects:[self _selectedObjectsIn:_entitiesTable from:_visibleEntities]];
}

- (void)addControllerForEntity:(id)sender
{
    var entity = [self selectedEntity];
    if (!entity)
        return;

    var controller = [_builderController addModelObjectOfKind:@"arrayController"],
        name = [entity valueForKey:@"name"];

    [_builderController setModelValue:name forKey:@"entity" ofObject:controller];
    [_builderController setModelValue:name + "_controller" forKey:@"name" ofObject:controller];

    // camelCase outlet name: argos_worklist → argosWorklistController
    var outlet = name.replace(/_([a-z0-9])/g, function(m, c) { return c.toUpperCase(); }) + "Controller";
    [_builderController setModelValue:outlet forKey:@"ownerOutlet" ofObject:controller];

    [_tabView selectTabViewItemAtIndex:1];
    [_controllerSearchField setStringValue:@""];
    [self reloadAll];
    [self _select:[controller] inTable:_controllersTable from:_visibleControllers];
}

- (void)addArrayController:(id)sender
{
    [_controllerSearchField setStringValue:@""];
    var controller = [_builderController addModelObjectOfKind:@"arrayController"];
    [self reloadAll];
    [self _select:[controller] inTable:_controllersTable from:_visibleControllers];
    [self _editTable:_controllersTable column:0 row:_visibleControllers.indexOf(controller)];
}

- (void)removeArrayController:(id)sender
{
    [_builderController removeModelObjects:[self _selectedObjectsIn:_controllersTable from:_visibleControllers]];
}

- (void)addSortDescriptor:(id)sender
{
    var descriptor = [_builderController addModelObjectOfKind:@"sortDescriptor"],
        list = [_builderController sortDescriptors];
    [self reloadAll];
    [self _select:[descriptor] inTable:_sortDescriptorsTable from:list];
    [self _editTable:_sortDescriptorsTable column:0 row:list.indexOf(descriptor)];
}

- (void)removeSortDescriptor:(id)sender
{
    [_builderController removeModelObjects:[self _selectedObjectsIn:_sortDescriptorsTable from:[_builderController sortDescriptors]]];
}

- (void)_editItemsOfSelectedEntity:(CPString)aKey with:(Function)aFunction
{
    var entity = [self selectedEntity];
    if (!entity)
        return;

    var items = ([entity valueForKey:aKey] || []).map(UIBCopyModelItem);
    if (aFunction(items) === NO)
        return;

    [_builderController setModelItems:items forKey:aKey ofEntity:entity];
}

- (void)addColumn:(id)sender
{
    var newIndex = -1;
    [self _editItemsOfSelectedEntity:@"columns" with:function(items)
    {
        var name = "new_column", counter = 1;
        while (items.some(function(item) { return item.attributes.name === name; }))
            name = "new_column" + (++counter);
        items.push(UIBNewModelItem({ name: name }));
        newIndex = items.length - 1;
    }];

    if (newIndex >= 0)
    {
        [_columnsTable selectRowIndexes:[CPIndexSet indexSetWithIndex:newIndex] byExtendingSelection:NO];
        [self _editTable:_columnsTable column:0 row:newIndex];
    }
}

- (void)removeColumn:(id)sender
{
    var indexes = [_columnsTable selectedRowIndexes];
    [self _editItemsOfSelectedEntity:@"columns" with:function(items)
    {
        if (![indexes count])
            return NO;
        for (var i = items.length - 1; i >= 0; i--)
            if ([indexes containsIndex:i])
                items.splice(i, 1);
    }];
}

- (void)addRelationship:(id)sender
{
    var newIndex = -1;
    [self _editItemsOfSelectedEntity:@"relationships" with:function(items)
    {
        items.push(UIBNewModelItem({ type: "toMany", name: "new_relationship", bindingColumn: "id", targetColumn: "", target: "" }));
        newIndex = items.length - 1;
    }];

    if (newIndex >= 0)
    {
        [_relationshipsTable selectRowIndexes:[CPIndexSet indexSetWithIndex:newIndex] byExtendingSelection:NO];
        [self _editTable:_relationshipsTable column:0 row:newIndex];
    }
}

- (void)removeRelationship:(id)sender
{
    var indexes = [_relationshipsTable selectedRowIndexes];
    [self _editItemsOfSelectedEntity:@"relationships" with:function(items)
    {
        if (![indexes count])
            return NO;
        for (var i = items.length - 1; i >= 0; i--)
            if ([indexes containsIndex:i])
                items.splice(i, 1);
    }];
}

- (void)insertTable:(id)sender
{
    var selected = [self _selectedObjectsIn:_controllersTable from:_visibleControllers];
    if (selected.length !== 1)
        return;

    [_builderController insertTableForArrayController:selected[0]];
}

// Starts editing a cell: the column is editable only for this editing session.
- (void)_editTable:(CPTableView)aTable column:(int)aColumnIndex row:(int)aRow
{
    var column = [[aTable tableColumns] objectAtIndex:aColumnIndex];
    if (aRow < 0 || !column || !column._uibIsEditable)
        return;

    [aTable selectRowIndexes:[CPIndexSet indexSetWithIndex:aRow] byExtendingSelection:NO];
    [column setEditable:YES];
    [aTable editColumn:aColumnIndex row:aRow withEvent:nil select:YES];
    [column setEditable:NO];
}

// Double-click edits text cells and toggles ✓ columns (and relationship types).
- (void)tableDoubleClicked:(id)sender
{
    var row = [sender clickedRow],
        columnIndex = [sender clickedColumn];

    if (row < 0 || columnIndex < 0)
        return;

    var column = [[sender tableColumns] objectAtIndex:columnIndex],
        identifier = [column identifier];

    if (!column._uibIsBoolean && !(sender === _relationshipsTable && identifier === "type"))
    {
        [self _editTable:sender column:columnIndex row:row];
        return;
    }

    if (sender === _columnsTable || sender === _relationshipsTable)
    {
        var key = (sender === _columnsTable) ? @"columns" : @"relationships";
        [self _editItemsOfSelectedEntity:key with:function(items)
        {
            if (row >= items.length)
                return NO;

            var attributes = items[row].attributes;
            if (identifier === "type")
                attributes.type = (attributes.type === "toMany") ? "toOne" : "toMany";
            else if (/^(yes|true|1)$/i.test(attributes[identifier] || ""))
                delete attributes[identifier];
            else
            {
                attributes[identifier] = "YES";
                if (items[row].order.indexOf(identifier) < 0)
                    items[row].order.push(identifier);
            }
        }];
        return;
    }

    var object = [self _objectForTable:sender row:row];
    if (object)
        [_builderController setModelValue:![object valueForKey:identifier] forKey:identifier ofObject:object];
}

#pragma mark -
#pragma mark Table Data Source

- (id)_objectForTable:(CPTableView)aTable row:(int)aRow
{
    if (aTable === _entitiesTable)
        return _visibleEntities[aRow];
    if (aTable === _controllersTable)
        return _visibleControllers[aRow];
    if (aTable === _sortDescriptorsTable)
        return [_builderController sortDescriptors][aRow];
    return nil;
}

- (int)numberOfRowsInTableView:(CPTableView)aTable
{
    if (!_builderController)
        return 0;

    if (aTable === _entitiesTable)
        return _visibleEntities.length;
    if (aTable === _controllersTable)
        return _visibleControllers.length;
    if (aTable === _sortDescriptorsTable)
        return [_builderController sortDescriptors].length;

    var entity = [self selectedEntity];
    if (!entity)
        return 0;

    return ([entity valueForKey:(aTable === _columnsTable ? @"columns" : @"relationships")] || []).length;
}

- (id)tableView:(CPTableView)aTable objectValueForTableColumn:(CPTableColumn)aColumn row:(int)aRow
{
    var identifier = [aColumn identifier];

    if (aTable === _columnsTable || aTable === _relationshipsTable)
    {
        var entity = [self selectedEntity],
            item = ([entity valueForKey:(aTable === _columnsTable ? @"columns" : @"relationships")] || [])[aRow];

        if (!item)
            return nil;

        if (identifier === "other")
        {
            var parts = [];
            for (var name in item.attributes)
                if (item.attributes.hasOwnProperty(name) && name !== "name" && name !== "primaryKey" && name !== "optimistic")
                    parts.push(name + "=" + item.attributes[name]);
            return parts.join("  ");
        }

        if (aColumn._uibIsBoolean)
            return /^(yes|true|1)$/i.test(item.attributes[identifier] || "") ? UIBCheckMark : "";

        return item.attributes[identifier] || "";
    }

    var object = [self _objectForTable:aTable row:aRow];
    if (!object)
        return nil;

    var value = [object valueForKey:identifier];
    if (aColumn._uibIsBoolean)
        return value ? UIBCheckMark : "";

    return value === nil || value === undefined ? "" : String(value);
}

- (void)tableView:(CPTableView)aTable setObjectValue:(id)aValue forTableColumn:(CPTableColumn)aColumn row:(int)aRow
{
    var identifier = [aColumn identifier],
        value = String(aValue === nil || aValue === undefined ? "" : aValue).trim();

    if (aTable === _columnsTable || aTable === _relationshipsTable)
    {
        if (identifier === "other")
            return;

        var key = (aTable === _columnsTable) ? @"columns" : @"relationships";
        [self _editItemsOfSelectedEntity:key with:function(items)
        {
            var item = items[aRow];
            if (!item || (item.attributes[identifier] || "") === value)
                return NO;

            if (value.length)
            {
                item.attributes[identifier] = value;
                if (item.order.indexOf(identifier) < 0)
                    item.order.push(identifier);
            }
            else
                delete item.attributes[identifier];
        }];
        return;
    }

    var object = [self _objectForTable:aTable row:aRow];
    if (object)
        [_builderController setModelValue:value forKey:identifier ofObject:object];
}

- (BOOL)tableView:(CPTableView)aTable shouldEditTableColumn:(CPTableColumn)aColumn row:(int)aRow
{
    return !!aColumn._uibIsEditable && !(aTable === _relationshipsTable && [aColumn identifier] === "type");
}

- (void)tableViewSelectionDidChange:(CPNotification)aNotification
{
    var table = [aNotification object];

    if (table === _entitiesTable)
        [self _reloadEntityDetails];
    else
        [self _updateButtonStates];
}

@end

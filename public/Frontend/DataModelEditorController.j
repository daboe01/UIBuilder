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
        [[column headerView] setStringValue:columns[i][1]];
        [column setWidth:columns[i][2]];
        [column setEditable:!columns[i][3]];
        column._uibIsBoolean = !!columns[i][3];
        [table addTableColumn:column];
    }

    [table setDataSource:self];
    [table setDelegate:self];
    [table setTarget:self];
    [table setDoubleAction:@selector(tableDoubleClicked:)];

    [scrollView setDocumentView:table];
    [aView addSubview:scrollView];
    return table;
}

- (void)_buildPanel
{
    _panel = [[CPPanel alloc] initWithContentRect:CGRectMake(0, 0, 1000, 640) styleMask:CPTitledWindowMask | CPClosableWindowMask | CPResizableWindowMask];
    [_panel setTitle:@"Datenmodell"];
    [_panel setDelegate:self];
    [_panel center];

    _tabView = [[CPTabView alloc] initWithFrame:[[_panel contentView] bounds]];
    [_tabView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    var size = CGSizeMake(980, 590);

    // --- Entities ---
    var entitiesView = [[CPView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    [entitiesView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    _entitySearchField = [[CPSearchField alloc] initWithFrame:CGRectMake(8, 8, 270, 28)];
    [_entitySearchField setPlaceholderString:@"Entity suchen"];
    [_entitySearchField setTarget:self];
    [_entitySearchField setAction:@selector(filterChanged:)];
    [_entitySearchField setSendsSearchStringImmediately:YES];
    [entitiesView addSubview:_entitySearchField];

    _entitiesTable = [self _tableInView:entitiesView frame:CGRectMake(8, 42, 270, size.height - 82)
                                columns:[["name", "Entity", 150], ["store", "Store", 110]]
                       autoresizingMask:CPViewHeightSizable];

    var addEntity = [self _button:@"+" frame:CGRectMake(8, size.height - 34, 30, 24) action:@selector(addEntity:)],
        removeEntity = [self _button:@"−" frame:CGRectMake(42, size.height - 34, 30, 24) action:@selector(removeEntity:)];
    [addEntity setAutoresizingMask:CPViewMinYMargin];
    [removeEntity setAutoresizingMask:CPViewMinYMargin];
    [entitiesView addSubview:addEntity];
    [entitiesView addSubview:removeEntity];

    var addController = [self _button:@"Array Controller anlegen" frame:CGRectMake(80, size.height - 34, 198, 24) action:@selector(addControllerForEntity:)];
    [addController setAutoresizingMask:CPViewMinYMargin];
    [entitiesView addSubview:addController];

    var rightX = 294,
        rightWidth = size.width - rightX - 8,
        columnsHeight = Math.round((size.height - 120) * 0.6);

    _entityHeader = [self _label:@"Spalten" frame:CGRectMake(rightX, 12, rightWidth, 20) bold:YES];
    [_entityHeader setAutoresizingMask:CPViewWidthSizable];
    [entitiesView addSubview:_entityHeader];

    _columnsTable = [self _tableInView:entitiesView frame:CGRectMake(rightX, 36, rightWidth, columnsHeight)
                               columns:[["name", "Spalte", 220], ["primaryKey", "Primärschlüssel", 110, YES], ["optimistic", "Optimistic", 90, YES], ["other", "Weitere Attribute", 250]]
                      autoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    var y = 36 + columnsHeight + 6,
        addColumn = [self _button:@"+" frame:CGRectMake(rightX, y, 30, 24) action:@selector(addColumn:)],
        removeColumn = [self _button:@"−" frame:CGRectMake(rightX + 34, y, 30, 24) action:@selector(removeColumn:)],
        hint = [self _label:@"Doppelklick auf ✓-Spalten schaltet um." frame:CGRectMake(rightX + 74, y + 4, 300, 18) bold:NO];

    [addColumn setAutoresizingMask:CPViewMaxYMargin];
    [removeColumn setAutoresizingMask:CPViewMaxYMargin];
    [entitiesView addSubview:addColumn];
    [entitiesView addSubview:removeColumn];
    [entitiesView addSubview:hint];

    y += 34;
    [entitiesView addSubview:[self _label:@"Beziehungen" frame:CGRectMake(rightX, y, 200, 20) bold:YES]];
    y += 24;

    _relationshipsTable = [self _tableInView:entitiesView frame:CGRectMake(rightX, y, rightWidth, size.height - y - 40)
                                     columns:[["name", "Name", 150], ["type", "Typ", 80], ["target", "Ziel-Entity", 170], ["bindingColumn", "bindingColumn", 130], ["targetColumn", "targetColumn", 130]]
                            autoresizingMask:CPViewWidthSizable | CPViewMinYMargin];

    var addRelationship = [self _button:@"+" frame:CGRectMake(rightX, size.height - 34, 30, 24) action:@selector(addRelationship:)],
        removeRelationship = [self _button:@"−" frame:CGRectMake(rightX + 34, size.height - 34, 30, 24) action:@selector(removeRelationship:)];
    [addRelationship setAutoresizingMask:CPViewMinYMargin];
    [removeRelationship setAutoresizingMask:CPViewMinYMargin];
    [entitiesView addSubview:addRelationship];
    [entitiesView addSubview:removeRelationship];

    // --- Array controllers ---
    var controllersView = [[CPView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    [controllersView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    _controllerSearchField = [[CPSearchField alloc] initWithFrame:CGRectMake(8, 8, 300, 28)];
    [_controllerSearchField setPlaceholderString:@"Controller oder Entity suchen"];
    [_controllerSearchField setTarget:self];
    [_controllerSearchField setAction:@selector(filterChanged:)];
    [_controllerSearchField setSendsSearchStringImmediately:YES];
    [controllersView addSubview:_controllerSearchField];

    _controllersTable = [self _tableInView:controllersView frame:CGRectMake(8, 42, size.width - 16, size.height - 82)
                                   columns:[["name", "id", 200], ["entity", "Entity", 170], ["ownerOutlet", "Outlet in #CPOwner", 170], ["sortDescriptor", "sortDescriptor", 120],
                                            ["valueBinding", "valueBinding (Master)", 220], ["autoFetch", "autoFetch", 70, YES], ["autoFetchSync", "autoFetchSync", 90, YES]]
                          autoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    var addCtrl = [self _button:@"+" frame:CGRectMake(8, size.height - 34, 30, 24) action:@selector(addArrayController:)],
        removeCtrl = [self _button:@"−" frame:CGRectMake(42, size.height - 34, 30, 24) action:@selector(removeArrayController:)];
    [addCtrl setAutoresizingMask:CPViewMinYMargin];
    [removeCtrl setAutoresizingMask:CPViewMinYMargin];
    [controllersView addSubview:addCtrl];
    [controllersView addSubview:removeCtrl];

    _insertTableButton = [self _button:@"Tabelle in die Oberfläche einfügen" frame:CGRectMake(size.width - 268, size.height - 34, 260, 24) action:@selector(insertTable:)];
    [_insertTableButton setAutoresizingMask:CPViewMinYMargin | CPViewMinXMargin];
    [controllersView addSubview:_insertTableButton];

    // --- Sort descriptors ---
    var sortView = [[CPView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    [sortView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    _sortDescriptorsTable = [self _tableInView:sortView frame:CGRectMake(8, 8, size.width - 16, size.height - 48)
                                       columns:[["name", "id", 260], ["key", "key", 260], ["ascending", "ascending", 100, YES], ["numeric", "numeric", 100, YES]]
                              autoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    var addSort = [self _button:@"+" frame:CGRectMake(8, size.height - 34, 30, 24) action:@selector(addSortDescriptor:)],
        removeSort = [self _button:@"−" frame:CGRectMake(42, size.height - 34, 30, 24) action:@selector(removeSortDescriptor:)];
    [addSort setAutoresizingMask:CPViewMinYMargin];
    [removeSort setAutoresizingMask:CPViewMinYMargin];
    [sortView addSubview:addSort];
    [sortView addSubview:removeSort];

    var tabs = [["entities", "Entities", entitiesView], ["controllers", "Array Controller", controllersView], ["sort", "Sort Descriptors", sortView]];
    for (var i = 0; i < tabs.length; i++)
    {
        var item = [[CPTabViewItem alloc] initWithIdentifier:tabs[i][0]];
        [item setLabel:tabs[i][1]];
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
    [_entityHeader setStringValue:entity ? @"Spalten von „" + [entity valueForKey:@"name"] + "“" : @"Spalten (keine Entity ausgewählt)"];
    [_columnsTable reloadData];
    [_relationshipsTable reloadData];
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
    [_entitiesTable editColumn:0 row:_visibleEntities.indexOf(entity) withEvent:nil select:YES];
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
    [_controllersTable editColumn:0 row:_visibleControllers.indexOf(controller) withEvent:nil select:YES];
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
    [_sortDescriptorsTable editColumn:0 row:list.indexOf(descriptor) withEvent:nil select:YES];
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
        [_columnsTable editColumn:0 row:newIndex withEvent:nil select:YES];
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
        [_relationshipsTable editColumn:0 row:newIndex withEvent:nil select:YES];
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

// Double-click toggles ✓ columns (and relationship types).
- (void)tableDoubleClicked:(id)sender
{
    var row = [sender clickedRow],
        columnIndex = [sender clickedColumn];

    if (row < 0 || columnIndex < 0)
        return;

    var column = [[sender tableColumns] objectAtIndex:columnIndex],
        identifier = [column identifier];

    if (!column._uibIsBoolean && !(sender === _relationshipsTable && identifier === "type"))
        return;

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
    return !aColumn._uibIsBoolean && [aColumn identifier] !== "other" && !(aTable === _relationshipsTable && [aColumn identifier] === "type");
}

- (void)tableViewSelectionDidChange:(CPNotification)aNotification
{
    var table = [aNotification object];

    if (table === _entitiesTable)
        [self _reloadEntityDetails];
    else if (table === _controllersTable)
        [_insertTableButton setEnabled:[_controllersTable numberOfSelectedRows] === 1];
}

@end

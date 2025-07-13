@import <AppKit/CPViewController.j>

@class UIBuilderController;

@implementation InspectorController : CPViewController
{
    UIBuilderController _builderController @accessors(property=builderController);
    CPPanel             _panel @accessors(property=panel);
    CPTableView         _connectionsTableView;
}

- (void)awakeFromMarkup
{
    [_builderController addObserver:self forKeyPath:@"elementsController.selectionIndexes" options:CPKeyValueObservingOptionNew context:nil];

    // Create Tab View
    var tabView = [[CPTabView alloc] initWithFrame:[[_panel contentView] bounds]];
    [tabView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    // Properties Tab
    var propertiesView = [[CPView alloc] initWithFrame:CGRectMakeZero()];
    var propertiesTabItem = [[CPTabViewItem alloc] initWithIdentifier:@"properties"];
    [propertiesTabItem setLabel:@"Properties"];
    [propertiesTabItem setView:propertiesView];
    [tabView addTabViewItem:propertiesTabItem];

    // Connections Tab
    var connectionsView = [[CPView alloc] initWithFrame:CGRectMakeZero()];
    var connectionsTabItem = [[CPTabViewItem alloc] initWithIdentifier:@"connections"];
    [connectionsTabItem setLabel:@"Connections"];
    [connectionsTabItem setView:connectionsView];
    [tabView addTabViewItem:connectionsTabItem];

    // Connections TableView
    _connectionsTableView = [[CPTableView alloc] initWithFrame:[connectionsView bounds]];
    [_connectionsTableView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    var columns = [
        {identifier: "sourceID", title: "Source", width: 100},
        {identifier: "outlet", title: "Outlet", width: 80},
        {identifier: "targetID", title: "Target", width: 100},
        {identifier: "action", title: "Action", width: 120}
    ];

    for (var i = 0; i < [columns count]; i++) {
        var colInfo = columns[i];
        var column = [[CPTableColumn alloc] initWithIdentifier:colInfo.identifier];
        [[column headerView] setStringValue:colInfo.title];
        [column setWidth:colInfo.width];
        [_connectionsTableView addTableColumn:column];
    }

    [_connectionsTableView bind:@"content" toObject:[_builderController connectionsController] withKeyPath:@"arrangedObjects" options:nil];
    [_connectionsTableView bind:@"selectionIndexes" toObject:[_builderController connectionsController] withKeyPath:@"selectionIndexes" options:nil];
    [_connectionsTableView setDataSource:self];

    var scrollView = [[CPScrollView alloc] initWithFrame:[connectionsView bounds]];
    [scrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [scrollView setDocumentView:_connectionsTableView];
    [connectionsView addSubview:scrollView];

    // Replace panel's content view with the tab view
    [_panel setContentView:tabView];

    [self updateInspector];
}

- (id)tableView:(CPTableView)aTableView objectValueForTableColumn:(CPTableColumn)aTableColumn row:(int)aRow
{
    var connection = [[[_builderController connectionsController] arrangedObjects] objectAtIndex:aRow];
    var identifier = [aTableColumn identifier];
    
    return [connection valueForKey:identifier];
}

- (void)observeValueForKeyPath:(CPString)keyPath ofObject:(id)object change:(CPDictionary)change context:(id)context
{
    if (keyPath === @"elementsController.selectionIndexes")
    {
        [self updateInspector];

        var selectedObjects = [[_builderController elementsController] selectedObjects];
        var connectionsController = [_builderController connectionsController];

        if ([selectedObjects count] === 1)
        {
            var selectedID = [[selectedObjects objectAtIndex:0] valueForKey:@"id"];
            var predicate = [CPPredicate predicateWithFormat:@"sourceID == %@ OR targetID == %@", selectedID, selectedID];
            [connectionsController setFilterPredicate:predicate];
        }
        else
        {
            // If nothing or more than one thing is selected, show no connections.
            // A predicate that always returns false is a good way to do this.
            [connectionsController setFilterPredicate:[CPPredicate predicateWithFormat:@"FALSEPREDICATE"]];
        }
    }
}

- (void)updateInspector
{
    var selectedObjects = [[_builderController elementsController] selectedObjects];
    var propertiesView = [[[_panel contentView] tabViewItemAtIndex:0] view];

    // Clear existing views from properties tab
    var subviews = [propertiesView subviews];
    for (var i = [subviews count] - 1; i >= 0; i--) {
        [subviews[i] removeFromSuperview];
    }

    if ([selectedObjects count] === 1)
    {
        var selectedObject = selectedObjects[0];
        var elementType = [selectedObject valueForKey:@"type"];
        var viewClass = [UIBuilderController classForElementType:elementType];
        var properties = [viewClass persistentProperties];

        var yPos = 10;

        // Set panel title
        [_panel setTitle:elementType];

        for (var i = 0; i < [properties count]; i++)
        {
            var propertyName = properties[i];
            var value = [selectedObject valueForKey:propertyName];
            var propertyType = [[viewClass propertyTypes] valueForKey:propertyName];

            // Create Label
            var label = [[CPTextField alloc] initWithFrame:CGRectMake(10, yPos, 100, 20)];
            [label setStringValue:propertyName];
            [label setBezeled:NO];
            [label setDrawsBackground:NO];
            [label setEditable:NO];
            [propertiesView addSubview:label];
            [label setTextColor:[CPColor grayColor]];

            // Create Control based on property type
            if (propertyType === UIBBoolean) {
                var checkbox = [[CPCheckBox alloc] initWithFrame:CGRectMake(120, yPos, 100, 20)];
                [checkbox setTitle:@""];
                [checkbox bind:@"value" toObject:selectedObject withKeyPath:propertyName options:nil];
                [propertiesView addSubview:checkbox];
            } else if (propertyType === UIBString || propertyType === UIBNumber) {
                var textField = [[CPTextField alloc] initWithFrame:CGRectMake(120, yPos, 150, 25)];
                [textField bind:@"value" toObject:selectedObject withKeyPath:propertyName options:nil];
                [textField setBezeled:YES];
                [textField setEditable:YES];
                [propertiesView addSubview:textField];
            } else { // Fallback for unknown types
                var textField = [[CPTextField alloc] initWithFrame:CGRectMake(120, yPos, 150, 25)];
                [textField bind:@"value" toObject:selectedObject withKeyPath:propertyName options:nil];
                [textField setBezeled:YES];
                [textField setEditable:YES];
                [propertiesView addSubview:textField];
            }

            yPos += 30;
        }

        [[self panel] orderFront:self];
    }
    else
    {
        [[self panel] orderOut:self];
    }
}

- (void)dealloc
{
    [_builderController removeObserver:self forKeyPath:@"elementsController.selectionIndexes"];
    [super dealloc];
}

@end

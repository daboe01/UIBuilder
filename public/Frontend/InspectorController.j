@import <AppKit/CPViewController.j>

@class UIBuilderController;

@implementation CPEnumerationValueTransformer : CPValueTransformer
{
    CPArray _enumerationValues;
}

+ (Class)transformedValueClass { return [CPNumber class]; }
+ (BOOL)allowsReverseTransformation { return YES; }

- (id)initWithEnumerationValues:(CPArray)values
{
    self = [super init];
    if (self) {
        _enumerationValues = [values copy];
    }
    return self;
}

/**
 * Transforms a model value (like a number for textAlignment or a string for another enum)
 * into a numeric index for the CPPopUpButton's selectedTag.
 */
- (id)transformedValue:(id)value
{
    if (value === nil || value === null) return nil;

    // First, try to find the value in the enumeration array (for strings).
    var index = [_enumerationValues indexOfObject:value];
    if (index != CPNotFound) {
        return [CPNumber numberWithInt:index];
    }

    // Handle CPNumber instances
    if ([value isKindOfClass:[CPNumber class]])
    {
        return value;
    }

    return nil; // Return nil if no valid transformation can be made
}

/**
 * Transforms a numeric index from the CPPopUpButton's selectedTag back
 * into a value for the model.
 */
- (id)reverseTransformedValue:(id)value
{
    if (!typeof value === 'number' || ![value isKindOfClass:[CPNumber class]]) return nil;

    var index = [value intValue];
    if (index >= 0 && index < [_enumerationValues count]) {
        return _enumerationValues[index];
    }

    return nil;
}

@end

@implementation CPStringColorTransformer : CPValueTransformer
{
}

+ (Class)transformedValueClass
{
    return [CPColor class];
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)transformedValue:(id)value
{
    if (!value || ![value isKindOfClass:[CPString class]])
        return nil;

    return [CPColor colorWithHexString:[value substringFromIndex:1]];
}

- (id)reverseTransformedValue:(id)value
{
    if (!value || ![value isKindOfClass:[CPColor class]])
        return nil;

    return '#' + [value hexString];
}

@end

@implementation InspectorController : CPViewController
{
    UIBuilderController _builderController @accessors(property=builderController);
    CPPanel             _panel @accessors(property=panel);
    CPTableView         _connectionsTableView;
    id                  _inspectedObject;
    CPControl           _widthControl;
    CPControl           _heightControl;
}

- (void)awakeFromMarkup
{
    var frame = [_panel frame];
    frame.size.height = 550;
    [_panel setFrame:frame display:YES];

    [_builderController addObserver:self forKeyPath:@"elementsController.selectionIndexes" options:CPKeyValueObservingOptionNew context:nil];

    // Create Tab View
    var tabView = [[CPTabView alloc] initWithFrame:[[_panel contentView] bounds]];
    [tabView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [tabView setDelegate:self];

    // Properties Tab
    var propertiesView = [[CPView alloc] initWithFrame:CGRectMakeZero()];
    var propertiesTabItem = [[CPTabViewItem alloc] initWithIdentifier:@"properties"];
    [propertiesTabItem setLabel:@"Properties"];
    [propertiesTabItem setView:propertiesView];
    [tabView addTabViewItem:propertiesTabItem];

    // Layout Tab
    var layoutView = [[CPView alloc] initWithFrame:CGRectMakeZero()];
    var layoutTabItem = [[CPTabViewItem alloc] initWithIdentifier:@"layout"];
    [layoutTabItem setLabel:@"Layout"];
    [layoutTabItem setView:layoutView];
    [tabView addTabViewItem:layoutTabItem];

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
        {identifier: "outlet", title: "Outlet", width: 80},
        {identifier: "action", title: "Action", width: 120}
    ];

    // Keep a reference to the array controller
    var connectionsController = [_builderController connectionsController];

    for (var i = 0; i < [columns count]; i++) {
        var colInfo = columns[i];
        var column = [[CPTableColumn alloc] initWithIdentifier:colInfo.identifier];
        [[column headerView] setStringValue:colInfo.title];
        [column setWidth:colInfo.width];
        [_connectionsTableView addTableColumn:column];
        // Bind the value of each column to the corresponding key path on the arranged objects
        [column bind:CPValueBinding toObject:connectionsController withKeyPath:("arrangedObjects." + colInfo.identifier) options:nil];
    }

    // Bind the table's selection to the array controller's selection
    [_connectionsTableView bind:@"selectionIndexes" toObject:connectionsController withKeyPath:@"selectionIndexes" options:nil];

    var connectionsViewBounds = [connectionsView bounds];
    var buttonBarHeight = 28;
    var tableHeight = connectionsViewBounds.size.height - buttonBarHeight;

    var scrollViewFrame = CGRectMake(3, 3, connectionsViewBounds.size.width - 6, tableHeight - 6);
    var buttonBarFrame = CGRectMake(0, tableHeight, connectionsViewBounds.size.width, buttonBarHeight);

    var scrollView = [[CPScrollView alloc] initWithFrame:scrollViewFrame];
    [scrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [scrollView setDocumentView:_connectionsTableView];
    [connectionsView addSubview:scrollView];

    var buttonBar = [[CPView alloc] initWithFrame:buttonBarFrame];
    [buttonBar setAutoresizingMask:CPViewWidthSizable | CPViewMinYMargin]; // Stick to bottom
    [connectionsView addSubview:buttonBar];

    var deleteButton = [CPButtonBar minusButton];
    [deleteButton setAction:@selector(deleteSelectedConnection:)];
    [deleteButton setTarget:self];
    [buttonBar addSubview:deleteButton];

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
        [self _updateConnectionVisibility];
    }
    else if (keyPath === @"halign" || keyPath === @"valign")
    {
        [self _updateControlStates];
    }
}

- (void)_updateControlStates
{
    if (_inspectedObject)
    {
        if (_widthControl)
        {
            var halign = [_inspectedObject valueForKey:@"halign"];
            [_widthControl setEnabled:(halign === @"min")];
        }
        if (_heightControl)
        {
            var valign = [_inspectedObject valueForKey:@"valign"];
            [_heightControl setEnabled:(valign === @"min")];
        }
    }
}

- (void)_updateConnectionVisibility
{
    var tabView = [[self panel] contentView];
    if (![tabView isKindOfClass:[CPTabView class]])
        return;

    var selectedTabViewItem = [tabView selectedTabViewItem];
    var connectionsController = [_builderController connectionsController];
    var selectedObjects = [[_builderController elementsController] selectedObjects];

    // 1. Filter the connections based on the selected UI element.
    if ([selectedObjects count] === 1)
    {
        var selectedID = [[selectedObjects objectAtIndex:0] valueForKey:@"id"];
        var predicate = [CPPredicate predicateWithFormat:@"sourceID == %@ OR targetID == %@", selectedID, selectedID];
        [connectionsController setFilterPredicate:predicate];
    }
    else
    {
        [connectionsController setFilterPredicate:[CPPredicate predicateWithFormat:@"FALSEPREDICATE"]];
    }
}

- (void)tabView:(CPTabView)aTabView didSelectTabViewItem:(CPTabViewItem)aTabViewItem
{
    [self _updateConnectionVisibility];
}

- (void)deleteSelectedConnection:(id)sender
{
    var selectedObjects = [[_builderController connectionsController] selectedObjects];
    if ([selectedObjects count] > 0)
        [[_builderController connectionsController] removeObjects:selectedObjects];
}

- (void)updateInspector
{
    var selectedObjects = [[_builderController elementsController] selectedObjects];
    var propertiesView = [[[_panel contentView] tabViewItemAtIndex:UIBPropertyTabProperties] view];
    var layoutView = [[[_panel contentView] tabViewItemAtIndex:UIBPropertyTabLayout] view];

    // Cleanup previous observer
    if (_inspectedObject)
    {
        var elementType = [_inspectedObject valueForKey:@"type"];
        if (elementType)
        {
            var viewClass = [UIBuilderController classForElementType:elementType];
            if (viewClass)
            {
                var properties = [viewClass persistentProperties];
                if ([properties containsObject:@"halign"])
                    [_inspectedObject removeObserver:self forKeyPath:@"halign"];
                if ([properties containsObject:@"valign"])
                    [_inspectedObject removeObserver:self forKeyPath:@"valign"];
            }
        }
    }
    _inspectedObject = nil;
    _widthControl = nil;
    _heightControl = nil;

    // Clear existing views from properties tab
    var subviews = [propertiesView subviews];
    for (var i = [subviews count] - 1; i >= 0; i--) {
        var subview = subviews[i];
        if ([subview isKindOfClass:[CPControl class]]) {
            [subview unbind:@"value"];
            [subview unbind:@"selectedIndex"];
        }
        [subview removeFromSuperview];
    }

    // Clear existing views from layout tab
    subviews = [layoutView subviews];
    for (var i = [subviews count] - 1; i >= 0; i--) {
        var subview = subviews[i];
        if ([subview isKindOfClass:[CPControl class]]) {
            [subview unbind:@"value"];
            [subview unbind:@"selectedIndex"];
        }
        [subview removeFromSuperview];
    }

    if ([selectedObjects count] === 1)
    {
        _inspectedObject = selectedObjects[0];
        var elementType = [_inspectedObject valueForKey:@"type"];
        var viewClass = [UIBuilderController classForElementType:elementType];
        var properties = [viewClass persistentProperties];
        var propertyGroups = [viewClass propertyGroups];

        var yPosProperties = 10;
        var yPosLayout = 10;

        // Set panel title
        [_panel setTitle:elementType];

        for (var i = 0; i < [properties count]; i++)
        {
            var propertyName = properties[i];
            var value = [_inspectedObject valueForKey:propertyName];
            var propertyType = [[viewClass propertyTypes] valueForKey:propertyName];
            var propertyGroup = [propertyGroups valueForKey:propertyName];

            var currentView = (propertyGroup === UIBPropertyTabLayout) ? layoutView : propertiesView;
            var yPos = (propertyGroup === UIBPropertyTabLayout) ? yPosLayout : yPosProperties;

            // Create Label
            var label = [[CPTextField alloc] initWithFrame:CGRectMake(10, yPos + 3, 100, 20)];
            [label setStringValue:propertyName];
            [label setBezeled:NO];
            [label setDrawsBackground:NO];
            [label setEditable:NO];
            [currentView addSubview:label];
            [label setTextColor:[CPColor grayColor]];

            // Create Control based on property type
            var control = nil;
            if (propertyType === UIBBoolean) {
                var checkbox = [[CPCheckBox alloc] initWithFrame:CGRectMake(120, yPos, 100, 20)];
                [checkbox setTitle:@""];
                [checkbox bind:@"value" toObject:_inspectedObject withKeyPath:propertyName options:nil];
                control = checkbox;
            } else if (propertyType === UIBString || propertyType === UIBNumber) {
                var textField = [[CPTextField alloc] initWithFrame:CGRectMake(120, yPos, 150, 27)];
                [textField bind:@"value" toObject:_inspectedObject withKeyPath:propertyName options:nil];
                [textField setBezeled:YES];
                [textField setEditable:YES];
                control = textField;
            }
            else if (propertyType === UIBColor) {
                var colorWell = [[CPColorWell alloc] initWithFrame:CGRectMake(120, yPos, 50, 27)];
                [colorWell bind:@"value" toObject:_inspectedObject withKeyPath:propertyName options:@{CPValueTransformerBindingOption: [[CPStringColorTransformer alloc] init]}];
                control = colorWell;
            }
            else if (propertyType === UIBEnumeration)
            {
                var popUpButton = [[CPPopUpButton alloc] initWithFrame:CGRectMake(120, yPos, 150, 27)];
                var enumerations = [viewClass propertyEnumerations];
                var values = [enumerations objectForKey:propertyName];

                if (values)
                {
                    for (var j = 0; j < [values count]; j++)
                    {
                        [popUpButton addItemWithTitle:values[j]];
                        [[popUpButton lastItem] setTag:j];
                    }
                }
                [popUpButton bind:@"selectedIndex" toObject:_inspectedObject withKeyPath:propertyName options:@{CPValueTransformerBindingOption: [[CPEnumerationValueTransformer alloc] initWithEnumerationValues:values]}];
                control = popUpButton;

            } else { // Fallback for unknown types
                var textField = [[CPTextField alloc] initWithFrame:CGRectMake(120, yPos, 150, 25)];
                [textField bind:@"value" toObject:_inspectedObject withKeyPath:propertyName options:nil];
                [textField setBezeled:YES];
                [textField setEditable:YES];
                control = textField;
            }

            if (control)
            {
                [currentView addSubview:control];
                if (propertyName === @"width") _widthControl = control;
                if (propertyName === @"height") _heightControl = control;
            }

            if (propertyGroup === UIBPropertyTabLayout)
                yPosLayout += 30;
            else
                yPosProperties += 30;
        }

        // Add observers for dynamic enabling/disabling
        if ([properties containsObject:@"halign"])
            [_inspectedObject addObserver:self forKeyPath:@"halign" options:CPKeyValueObservingOptionNew context:nil];
        if ([properties containsObject:@"valign"])
            [_inspectedObject addObserver:self forKeyPath:@"valign" options:CPKeyValueObservingOptionNew context:nil];

        [self _updateControlStates];
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
    if (_inspectedObject)
    {
        var properties = [[_inspectedObject class] persistentProperties];
        if ([properties containsObject:@"halign"])
            [_inspectedObject removeObserver:self forKeyPath:@"halign"];
        if ([properties containsObject:@"valign"])
            [_inspectedObject removeObserver:self forKeyPath:@"valign"];
    }
    [super dealloc];
}

@end

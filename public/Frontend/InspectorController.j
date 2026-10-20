
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
 * Transforms a model value into the index of the matching menu item.
 */
- (id)transformedValue:(id)value
{
    if (value === nil || value === undefined) return nil;

    var index = [_enumerationValues indexOfObject:value];
    if (index != CPNotFound) {
        return [CPNumber numberWithInt:index];
    }

    return nil;
}

/**
 * Transforms the index of the selected menu item back into a model value.
 */
- (id)reverseTransformedValue:(id)value
{
    if (value === nil || value === undefined || isNaN(Number(value))) return nil;

    var index = Number(value);
    if (index >= 0 && index < [_enumerationValues count]) {
        return _enumerationValues[index];
    }

    return nil;
}

@end

// Shows numbers in text fields and turns typed text back into numbers, so
// geometry in the model never becomes a string.
@implementation UIBNumberValueTransformer : CPValueTransformer
{
}

+ (Class)transformedValueClass { return [CPString class]; }
+ (BOOL)allowsReverseTransformation { return YES; }

- (id)transformedValue:(id)value
{
    if (value === nil || value === undefined)
        return @"";

    var number = Number(value);
    return isNaN(number) ? String(value) : String(Math.round(number * 100) / 100);
}

- (id)reverseTransformedValue:(id)value
{
    var number = parseFloat(value);
    return isNaN(number) ? nil : number;
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
    if (!value || ![value isKindOfClass:[CPString class]] || value.charAt(0) !== "#")
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


var UIBInspectorWidth = 330,
    UIBInspectorHeight = 580,
    UIBInspectorLabelWidth = 112,
    UIBInspectorRowHeight = 30,
    UIBLayoutOnlyKeys = { "halign": YES, "valign": YES, "width": YES, "height": YES, "x": YES, "y": YES };

// Friendlier labels for data keys; everything else shows the markup attribute name.
var UIBKeyLabels = {
    "value": "Value",
    "identifier": "id",
    "horizontalTextAlign": "Text Align",
    "markupTag": "Tag",
    "isIndeterminate": "Indeterminate",
    "isEditable": "Editable",
    "minValue": "Minimum",
    "maxValue": "Maximum",
    "tabViewType": "Tab Style",
    "items": "Items",
    "columns": "Columns",
    "outlets": "Outlets",
    "actions": "Actions"
};

/*
    The inspector shows the selected element in four tabs:

    Properties   everything the builder models, plus the markup id
    Layout       alignment and size (fixed or from the content)
    Attributes   all other markup attributes (bindings, ...), editable
    Connections  target/action and outlets, including references to objects
                 outside the document such as #CPOwner.someController

    Every edit goes through the document's undo manager.
*/
@implementation InspectorController : CPViewController
{
    UIBuilderController _builderController @accessors(property=builderController);
    CPPanel             _panel @accessors(property=panel);

    CPTabView           _tabView;
    CPView              _propertiesView;
    CPScrollView        _propertiesScrollView;
    CPView              _layoutView;
    CPView              _attributesView;
    CPView              _connectionsView;

    id                  _inspectedObject;
    CPArray             _observedKeys;
    CPArray             _boundControls;

    CPControl           _widthControl;
    CPControl           _heightControl;
    CPCheckBox          _fixedWidthBox;
    CPCheckBox          _fixedHeightBox;

    CPTableView         _attributesTableView;
    CPArray             _attributeNames;

    CPTableView         _connectionsTableView;
    CPArray             _connectionRows;
    CPPopUpButton       _connectionKindPopUp;
    CPTextField         _connectionNameField;
    CPTextField         _connectionTargetField;
    CPButton            _connectionAddButton;
    CPButton            _connectionRemoveButton;
    CPTextField         _connectionsHint;

    CPArray             _bindingFields;
    CPTextField         _bindingMessage;
}

#pragma mark -
#pragma mark Setup

- (CPTextField)_labelWithString:(CPString)aString frame:(CGRect)aFrame
{
    var label = [[CPTextField alloc] initWithFrame:aFrame];
    [label setStringValue:aString];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setTextColor:[CPColor colorWithCalibratedWhite:0.35 alpha:1.0]];
    [label setFont:[CPFont systemFontOfSize:12]];
    [label setAlignment:CPRightTextAlignment];
    return label;
}

- (CPButton)_smallButtonWithTitle:(CPString)aTitle frame:(CGRect)aFrame action:(SEL)anAction
{
    var button = [[CPButton alloc] initWithFrame:aFrame];
    [button setTitle:aTitle];
    [button setTarget:self];
    [button setAction:anAction];
    return button;
}

- (CPView)_tabContentView
{
    var view = [[CPView alloc] initWithFrame:CGRectMake(0, 0, UIBInspectorWidth - 20, UIBInspectorHeight - 60)];
    [view setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    return view;
}

- (void)awakeFromMarkup
{
    var frame = [_panel frame];
    frame.size.width = UIBInspectorWidth;
    frame.size.height = UIBInspectorHeight;
    [_panel setFrame:frame display:YES];

    [_builderController addObserver:self forKeyPath:@"elementsController.selectionIndexes" options:CPKeyValueObservingOptionNew context:nil];
    [_builderController addObserver:self forKeyPath:@"connectionsController.arrangedObjects" options:CPKeyValueObservingOptionNew context:nil];

    _tabView = [[CPTabView alloc] initWithFrame:[[_panel contentView] bounds]];
    [_tabView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [_tabView setDelegate:self];

    // Properties (scrollable: some elements have many)
    var propertiesContainer = [self _tabContentView];
    _propertiesScrollView = [[CPScrollView alloc] initWithFrame:[propertiesContainer bounds]];
    [_propertiesScrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [_propertiesScrollView setHasHorizontalScroller:NO];
    [_propertiesScrollView setAutohidesScrollers:YES];
    _propertiesView = [[CPView alloc] initWithFrame:CGRectMake(0, 0, [propertiesContainer bounds].size.width - 16, 400)];
    [_propertiesView setAutoresizingMask:CPViewWidthSizable];
    [_propertiesScrollView setDocumentView:_propertiesView];
    [propertiesContainer addSubview:_propertiesScrollView];

    _layoutView = [self _tabContentView];
    _attributesView = [self _tabContentView];
    _connectionsView = [self _tabContentView];

    var tabs = [["properties", "Properties", propertiesContainer], ["layout", "Layout", _layoutView],
                ["attributes", "Attributes", _attributesView], ["connections", "Connections", _connectionsView]];

    for (var i = 0; i < tabs.length; i++)
    {
        var item = [[CPTabViewItem alloc] initWithIdentifier:tabs[i][0]];
        [item setLabel:tabs[i][1]];
        [item setView:tabs[i][2]];
        [_tabView addTabViewItem:item];
    }

    [self _buildAttributesTab];
    [self _buildConnectionsTab];

    [_panel setContentView:_tabView];

    [self updateInspector];
}

- (void)_buildAttributesTab
{
    var bounds = [_attributesView bounds];

    var hint = [self _labelWithString:@"Markup attributes the builder has no field for (bindings, autosaveName, …). Double-click to edit." frame:CGRectMake(8, 4, bounds.size.width - 16, 32)];
    [hint setAlignment:CPLeftTextAlignment];
    [hint setLineBreakMode:CPLineBreakByWordWrapping];
    [hint setFont:[CPFont systemFontOfSize:11]];
    [hint setAutoresizingMask:CPViewWidthSizable];
    [_attributesView addSubview:hint];

    var scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(4, 40, bounds.size.width - 8, bounds.size.height - 76)];
    [scrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [scrollView setHasHorizontalScroller:NO];

    _attributesTableView = [[CPTableView alloc] initWithFrame:[scrollView bounds]];
    [_attributesTableView setUsesAlternatingRowBackgroundColors:YES];

    var nameColumn = [[CPTableColumn alloc] initWithIdentifier:@"name"];
    [[nameColumn headerView] setStringValue:@"Attribute"];
    [nameColumn setWidth:110];
    [nameColumn setEditable:YES];
    [_attributesTableView addTableColumn:nameColumn];

    var valueColumn = [[CPTableColumn alloc] initWithIdentifier:@"value"];
    [[valueColumn headerView] setStringValue:@"Value"];
    [valueColumn setWidth:bounds.size.width - 140];
    [valueColumn setEditable:YES];
    [_attributesTableView addTableColumn:valueColumn];

    [_attributesTableView setDataSource:self];
    [_attributesTableView setDelegate:self];
    [scrollView setDocumentView:_attributesTableView];
    [_attributesView addSubview:scrollView];

    var addButton = [self _smallButtonWithTitle:@"+" frame:CGRectMake(4, bounds.size.height - 30, 30, 24) action:@selector(addMarkupAttribute:)];
    var removeButton = [self _smallButtonWithTitle:@"−" frame:CGRectMake(38, bounds.size.height - 30, 30, 24) action:@selector(removeMarkupAttribute:)];
    [addButton setAutoresizingMask:CPViewMinYMargin];
    [removeButton setAutoresizingMask:CPViewMinYMargin];
    [_attributesView addSubview:addButton];
    [_attributesView addSubview:removeButton];
}

- (void)_buildConnectionsTab
{
    var bounds = [_connectionsView bounds];

    var scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(4, 4, bounds.size.width - 8, bounds.size.height - 150)];
    [scrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [scrollView setHasHorizontalScroller:NO];

    _connectionsTableView = [[CPTableView alloc] initWithFrame:[scrollView bounds]];
    [_connectionsTableView setUsesAlternatingRowBackgroundColors:YES];

    var columns = [["kind", "Kind", 70], ["name", "Outlet / Action", 100], ["other", "Other End", bounds.size.width - 190]];
    for (var i = 0; i < columns.length; i++)
    {
        var column = [[CPTableColumn alloc] initWithIdentifier:columns[i][0]];
        [[column headerView] setStringValue:columns[i][1]];
        [column setWidth:columns[i][2]];
        [column setEditable:NO];
        [_connectionsTableView addTableColumn:column];
    }

    [_connectionsTableView setDataSource:self];
    [_connectionsTableView setDelegate:self];
    [_connectionsTableView setAllowsMultipleSelection:YES];
    [scrollView setDocumentView:_connectionsTableView];
    [_connectionsView addSubview:scrollView];

    var y = bounds.size.height - 140;

    _connectionRemoveButton = [self _smallButtonWithTitle:@"Remove" frame:CGRectMake(4, y, 80, 24) action:@selector(deleteSelectedConnection:)];
    [_connectionRemoveButton setAutoresizingMask:CPViewMinYMargin];
    [_connectionsView addSubview:_connectionRemoveButton];

    y += 34;
    var newLabel = [self _labelWithString:@"New connection from this element:" frame:CGRectMake(4, y, bounds.size.width - 8, 20)];
    [newLabel setAlignment:CPLeftTextAlignment];
    [newLabel setFont:[CPFont boldSystemFontOfSize:11]];
    [newLabel setAutoresizingMask:CPViewMinYMargin];
    [_connectionsView addSubview:newLabel];

    y += 22;
    _connectionKindPopUp = [[CPPopUpButton alloc] initWithFrame:CGRectMake(4, y, 90, 26) pullsDown:NO];
    [_connectionKindPopUp addItemsWithTitles:["Action", "Outlet"]];
    [_connectionKindPopUp setTarget:self];
    [_connectionKindPopUp setAction:@selector(connectionKindChanged:)];
    [_connectionKindPopUp setAutoresizingMask:CPViewMinYMargin];
    [_connectionsView addSubview:_connectionKindPopUp];

    _connectionNameField = [[CPTextField alloc] initWithFrame:CGRectMake(98, y, bounds.size.width - 102, 28)];
    [_connectionNameField setBezeled:YES];
    [_connectionNameField setEditable:YES];
    [_connectionNameField setPlaceholderString:@"doSomething:"];
    [_connectionNameField setAutoresizingMask:CPViewWidthSizable | CPViewMinYMargin];
    [_connectionsView addSubview:_connectionNameField];

    y += 32;
    var toLabel = [self _labelWithString:@"to" frame:CGRectMake(4, y + 4, 20, 20)];
    [toLabel setAutoresizingMask:CPViewMinYMargin];
    [_connectionsView addSubview:toLabel];

    _connectionTargetField = [[CPTextField alloc] initWithFrame:CGRectMake(28, y, bounds.size.width - 120, 28)];
    [_connectionTargetField setBezeled:YES];
    [_connectionTargetField setEditable:YES];
    [_connectionTargetField setStringValue:@"#CPOwner"];
    [_connectionTargetField setPlaceholderString:@"#CPOwner, #someID, #CPOwner.controller"];
    [_connectionTargetField setAutoresizingMask:CPViewWidthSizable | CPViewMinYMargin];
    [_connectionsView addSubview:_connectionTargetField];

    _connectionAddButton = [self _smallButtonWithTitle:@"Connect" frame:CGRectMake(bounds.size.width - 88, y + 2, 84, 24) action:@selector(addConnectionFromInspector:)];
    [_connectionAddButton setAutoresizingMask:CPViewMinXMargin | CPViewMinYMargin];
    [_connectionsView addSubview:_connectionAddButton];

    _connectionsHint = [self _labelWithString:@"" frame:CGRectMake(4, 10, bounds.size.width - 8, 40)];
    [_connectionsHint setAlignment:CPCenterTextAlignment];
    [_connectionsHint setAutoresizingMask:CPViewWidthSizable];
}

#pragma mark -
#pragma mark Observing

- (void)observeValueForKeyPath:(CPString)keyPath ofObject:(id)object change:(CPDictionary)change context:(id)context
{
    if (keyPath === @"elementsController.selectionIndexes")
    {
        [self updateInspector];
    }
    else if (keyPath === @"connectionsController.arrangedObjects")
    {
        [self _reloadConnections];
    }
    else if (object === _inspectedObject)
    {
        if (keyPath === @"extraAttributes")
        {
            [self _reloadAttributes];

            var extras = [_inspectedObject valueForKey:@"extraAttributes"] || {};
            for (var i = 0; _bindingFields && i < _bindingFields.length; i++)
                [_bindingFields[i] setStringValue:extras[_bindingFields[i]._uibBindingKey] || @""];
        }
        else if (keyPath === @"markupKeys")
            [self _updateControlStates];
        else if (keyPath === @"actions" || keyPath === @"outlets")
            [self _reloadConnections];

        var view = [[_builderController canvasView] viewForElementWithID:[_inspectedObject valueForKey:@"id"]];
        if (view)
            [view setNeedsDisplay:YES];
    }
}

- (void)_stopInspecting
{
    if (_inspectedObject && _observedKeys)
        for (var i = 0; i < _observedKeys.length; i++)
            [_inspectedObject removeObserver:self forKeyPath:_observedKeys[i]];

    for (var i = 0; _boundControls && i < _boundControls.length; i++)
        [_boundControls[i][0] unbind:_boundControls[i][1]];

    _boundControls = [];
    _bindingFields = [];
    _bindingMessage = nil;
    _observedKeys = nil;
    _inspectedObject = nil;
    _widthControl = nil;
    _heightControl = nil;
    _fixedWidthBox = nil;
    _fixedHeightBox = nil;

    var views = [_propertiesView, _layoutView];
    for (var v = 0; v < views.length; v++)
    {
        var subviews = [[views[v] subviews] copy];
        for (var i = 0; i < subviews.length; i++)
            [subviews[i] removeFromSuperview];
    }
}

#pragma mark -
#pragma mark Building the Property Rows

- (CPString)_propertyTypeForKey:(CPString)aKey viewClass:(Class)viewClass defaults:(JSObject)defaults
{
    if (aKey === "color")
        return UIBColor;

    if (UIBPropertyChoices[aKey])
        return UIBEnumeration;

    var declared = [[viewClass propertyTypes] objectForKey:aKey];
    if (declared && declared !== UIBEnumeration)
        return declared;

    if (typeof defaults[aKey] === "boolean")
        return UIBBoolean;

    if (typeof defaults[aKey] === "number" || UIBNumericKeys[aKey])
        return UIBNumber;

    return UIBString;
}

- (CPControl)_controlForKey:(CPString)aKey type:(CPString)aType frame:(CGRect)aFrame
{
    var control = nil,
        object = _inspectedObject;

    if (aType === UIBBoolean)
    {
        control = [[CPCheckBox alloc] initWithFrame:CGRectMake(aFrame.origin.x, aFrame.origin.y + 4, aFrame.size.width, 20)];
        [control setTitle:@""];
        [control bind:CPValueBinding toObject:object withKeyPath:aKey options:nil];
        _boundControls.push([control, CPValueBinding]);
    }
    else if (aType === UIBEnumeration)
    {
        var choices = (UIBPropertyChoices[aKey] || []).slice(),
            current = [object valueForKey:aKey];

        // Keep values from imported markup selectable even if they are unusual.
        if (current !== nil && current !== undefined && choices.indexOf(current) < 0)
            choices.push(current);

        control = [[CPPopUpButton alloc] initWithFrame:aFrame pullsDown:NO];
        [control addItemsWithTitles:choices];
        [control bind:@"selectedIndex" toObject:object withKeyPath:aKey options:@{ CPValueTransformerBindingOption: [[CPEnumerationValueTransformer alloc] initWithEnumerationValues:choices] }];
        _boundControls.push([control, @"selectedIndex"]);
    }
    else if (aType === UIBColor)
    {
        control = [[CPColorWell alloc] initWithFrame:CGRectMake(aFrame.origin.x, aFrame.origin.y, 50, aFrame.size.height)];
        [control bind:CPValueBinding toObject:object withKeyPath:aKey options:@{ CPValueTransformerBindingOption: [[CPStringColorTransformer alloc] init] }];
        _boundControls.push([control, CPValueBinding]);
    }
    else
    {
        // Text and number fields commit on Return / end of editing: one undo step per edit.
        control = [[CPTextField alloc] initWithFrame:aFrame];
        [control setBezeled:YES];
        [control setEditable:YES];

        var options = (aType === UIBNumber) ? @{ CPValueTransformerBindingOption: [[UIBNumberValueTransformer alloc] init] } : nil;
        [control bind:CPValueBinding toObject:object withKeyPath:aKey options:options];
        _boundControls.push([control, CPValueBinding]);

        if (aKey === "items" || aKey === "columns")
            [control setPlaceholderString:@"comma separated"];
        if (aKey === "actions")
            [control setPlaceholderString:@"save:, cancel:"];
        if (aKey === "outlets")
            [control setPlaceholderString:@"delegate, dataSource"];
    }

    [control setAutoresizingMask:CPViewWidthSizable];
    return control;
}

// Adds "label  [control]" and returns the control.
- (CPControl)_addRowForKey:(CPString)aKey label:(CPString)aLabel type:(CPString)aType inView:(CPView)aView y:(float)y
{
    var width = [aView bounds].size.width,
        label = [self _labelWithString:aLabel frame:CGRectMake(4, y + 5, UIBInspectorLabelWidth, 20)];

    [aView addSubview:label];

    var control = [self _controlForKey:aKey type:aType frame:CGRectMake(UIBInspectorLabelWidth + 10, y, width - UIBInspectorLabelWidth - 18, 28)];
    [aView addSubview:control];
    return control;
}

- (void)_addSectionTitle:(CPString)aTitle inView:(CPView)aView y:(float)y
{
    var label = [self _labelWithString:aTitle frame:CGRectMake(8, y, [aView bounds].size.width - 16, 18)];
    [label setAlignment:CPLeftTextAlignment];
    [label setFont:[CPFont boldSystemFontOfSize:11]];
    [label setTextColor:[CPColor grayColor]];
    [label setAutoresizingMask:CPViewWidthSizable];
    [aView addSubview:label];
}

- (CPString)_labelForKey:(CPString)aKey type:(CPString)elementType
{
    if (UIBKeyLabels[aKey])
        return UIBKeyLabels[aKey];

    // Show the markup attribute name.
    var map = UIBAttributeMapForType(elementType);
    for (var i = 0; i < map.length; i++)
        if (map[i][0] === aKey)
            return map[i][1];

    return aKey;
}

- (void)updateInspector
{
    [self _stopInspecting];

    var selectedObjects = [[_builderController elementsController] selectedObjects];

    if ([selectedObjects count] !== 1)
    {
        [_panel setTitle:@"Inspector"];
        var message = ([selectedObjects count] === 0) ? @"No Selection" : @"Multiple Selection (" + [selectedObjects count] + @")";
        [self _addMessage:message toView:_propertiesView];
        [self _addMessage:message toView:_layoutView];
        [self _reloadAttributes];
        [self _reloadConnections];
        return;
    }

    _inspectedObject = selectedObjects[0];

    var elementType = [_inspectedObject valueForKey:@"type"],
        viewClass = [UIBuilderController classForElementType:elementType],
        defaults = [CappusanceCodec defaultsForType:elementType],
        tag = [_inspectedObject valueForKey:@"markupTag"] || (UIBSchemaForType(elementType).tags[0] || elementType);

    [_panel setTitle:@"Inspector – <" + tag + ">"];

    // --- Properties ---
    var y = 8;

    if (elementType !== "owner")
    {
        [self _addRowForKey:@"identifier" label:@"id" type:UIBString inView:_propertiesView y:y];
        y += UIBInspectorRowHeight;
    }

    var keys = UIBEditableKeysForType(elementType);
    for (var i = 0; i < keys.length; i++)
    {
        var key = keys[i];
        if (UIBLayoutOnlyKeys[key] || key === "actions" || key === "outlets")
            continue;

        [self _addRowForKey:key label:[self _labelForKey:key type:elementType] type:[self _propertyTypeForKey:key viewClass:viewClass defaults:defaults] inView:_propertiesView y:y];
        y += UIBInspectorRowHeight;
    }

    // Bindings to the data model
    _bindingFields = [];
    var bindingKeys = UIBBindingKeysForType[elementType] || [];
    if (bindingKeys.length)
    {
        var extras = [_inspectedObject valueForKey:@"extraAttributes"] || {},
            width = [_propertiesView bounds].size.width;

        y += 8;
        [self _addSectionTitle:@"Bindings (Datenmodell)" inView:_propertiesView y:y];
        y += 22;

        for (var i = 0; i < bindingKeys.length; i++)
        {
            var bindingKey = bindingKeys[i];
            [_propertiesView addSubview:[self _labelWithString:bindingKey.replace("Binding", "") frame:CGRectMake(4, y + 5, UIBInspectorLabelWidth, 20)]];

            var combo = [[CPComboBox alloc] initWithFrame:CGRectMake(UIBInspectorLabelWidth + 10, y, width - UIBInspectorLabelWidth - 18, 28)];
            [combo addItemsWithObjectValues:[_builderController bindingSuggestionsForKey:bindingKey elementType:elementType]];
            [combo setCompletes:YES];
            [combo setNumberOfVisibleItems:14];
            [combo setStringValue:extras[bindingKey] || @""];
            [combo setPlaceholderString:@"#CPOwner.controller…"];
            [combo setTarget:self];
            [combo setAction:@selector(commitBinding:)];
            [combo setDelegate:self];
            [combo setAutoresizingMask:CPViewWidthSizable];
            combo._uibBindingKey = bindingKey;
            [_propertiesView addSubview:combo];
            _bindingFields.push(combo);
            y += UIBInspectorRowHeight;
        }

        if (elementType === "tableView")
        {
            var columnsButton = [[CPButton alloc] initWithFrame:CGRectMake(UIBInspectorLabelWidth + 10, y + 2, width - UIBInspectorLabelWidth - 18, 24)];
            [columnsButton setTitle:@"Spalten aus Entity übernehmen"];
            [columnsButton setTarget:self];
            [columnsButton setAction:@selector(takeColumnsFromEntity:)];
            [columnsButton setAutoresizingMask:CPViewWidthSizable];
            [_propertiesView addSubview:columnsButton];
            y += UIBInspectorRowHeight;
        }

        _bindingMessage = [self _labelWithString:([[_builderController arrayControllers] count] ? @"" : @"Noch kein Datenmodell – Daten ▸ Datenmodell-Editor") frame:CGRectMake(8, y, width - 16, 18)];
        [_bindingMessage setAlignment:CPLeftTextAlignment];
        [_bindingMessage setFont:[CPFont systemFontOfSize:10]];
        [_bindingMessage setAutoresizingMask:CPViewWidthSizable];
        [_propertiesView addSubview:_bindingMessage];
        y += 18;
    }

    // What control-dragging offers for this element.
    y += 8;
    [self _addSectionTitle:(elementType === "owner" ? @"Owner methods and outlets" : @"Offered when control-dragging") inView:_propertiesView y:y];
    y += 22;
    [self _addRowForKey:@"actions" label:@"Actions" type:UIBString inView:_propertiesView y:y];
    y += UIBInspectorRowHeight;
    [self _addRowForKey:@"outlets" label:@"Outlets" type:UIBString inView:_propertiesView y:y];
    y += UIBInspectorRowHeight;

    if ([_inspectedObject valueForKey:@"rawChildren"] && UIBSchemaForType(elementType).items)
    {
        var note = [self _labelWithString:@"Items keep their imported attributes as long as the list is unchanged." frame:CGRectMake(8, y + 4, [_propertiesView bounds].size.width - 16, 30)];
        [note setAlignment:CPLeftTextAlignment];
        [note setLineBreakMode:CPLineBreakByWordWrapping];
        [note setFont:[CPFont systemFontOfSize:10]];
        [note setAutoresizingMask:CPViewWidthSizable];
        [_propertiesView addSubview:note];
        y += 36;
    }

    [_propertiesView setFrameSize:CGSizeMake([[_propertiesScrollView contentView] bounds].size.width, MAX(y + 10, [[_propertiesScrollView contentView] bounds].size.height))];

    // --- Layout ---
    y = 8;

    if (elementType === "window")
    {
        [self _addSectionTitle:@"Position in the running app (empty: automatic)" inView:_layoutView y:y];
        y += 22;
        [self _addRowForKey:@"x" label:@"x" type:UIBNumber inView:_layoutView y:y];
        y += UIBInspectorRowHeight;
        [self _addRowForKey:@"y" label:@"y" type:UIBNumber inView:_layoutView y:y];
        y += UIBInspectorRowHeight + 8;
        _widthControl = [self _addRowForKey:@"width" label:@"width" type:UIBNumber inView:_layoutView y:y];
        y += UIBInspectorRowHeight;
        _heightControl = [self _addRowForKey:@"height" label:@"height" type:UIBNumber inView:_layoutView y:y];
        y += UIBInspectorRowHeight;
    }
    else if (elementType !== "owner" && !UIBSchemaForType(elementType).noLayout && ![_inspectedObject valueForKey:@"isRootVBox"])
    {
        [self _addRowForKey:@"halign" label:@"halign" type:UIBEnumeration inView:_layoutView y:y];
        y += UIBInspectorRowHeight;
        [self _addRowForKey:@"valign" label:@"valign" type:UIBEnumeration inView:_layoutView y:y];
        y += UIBInspectorRowHeight + 8;

        [self _addSectionTitle:@"Size (unchecked: determined by the content)" inView:_layoutView y:y];
        y += 22;

        _fixedWidthBox = [CPCheckBox checkBoxWithTitle:@"Fixed"];
        [_fixedWidthBox setFrameOrigin:CGPointMake(8, y + 4)];
        [_fixedWidthBox setTarget:self];
        [_fixedWidthBox setAction:@selector(toggleFixedSize:)];
        [_fixedWidthBox setTag:0];
        [_layoutView addSubview:_fixedWidthBox];
        _widthControl = [self _addRowForKey:@"width" label:@"width" type:UIBNumber inView:_layoutView y:y];
        y += UIBInspectorRowHeight;

        _fixedHeightBox = [CPCheckBox checkBoxWithTitle:@"Fixed"];
        [_fixedHeightBox setFrameOrigin:CGPointMake(8, y + 4)];
        [_fixedHeightBox setTarget:self];
        [_fixedHeightBox setAction:@selector(toggleFixedSize:)];
        [_fixedHeightBox setTag:1];
        [_layoutView addSubview:_fixedHeightBox];
        _heightControl = [self _addRowForKey:@"height" label:@"height" type:UIBNumber inView:_layoutView y:y];
        y += UIBInspectorRowHeight;
    }
    else
        [self _addMessage:@"This element fills its container." toView:_layoutView];

    // Observe everything shown, so undo/redo and canvas edits show up here.
    _observedKeys = ["identifier", "extraAttributes", "markupKeys", "actions", "outlets", "halign", "valign", "width", "height", "x", "y"].concat(keys);
    for (var i = 0; i < _observedKeys.length; i++)
        [_inspectedObject addObserver:self forKeyPath:_observedKeys[i] options:CPKeyValueObservingOptionNew context:nil];

    [self _updateControlStates];
    [self _reloadAttributes];
    [self _reloadConnections];
}

- (void)_addMessage:(CPString)aString toView:(CPView)aView
{
    var label = [[CPTextField alloc] initWithFrame:CGRectMake(10, 30, MAX(100, [aView bounds].size.width - 20), 24)];
    [label setStringValue:aString];
    [label setAlignment:CPCenterTextAlignment];
    [label setTextColor:[CPColor grayColor]];
    [label setFont:[CPFont systemFontOfSize:13]];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setAutoresizingMask:CPViewWidthSizable];
    [aView addSubview:label];
}

- (void)_updateControlStates
{
    if (!_inspectedObject)
        return;

    var markupKeys = [_inspectedObject valueForKey:@"markupKeys"] || [];

    if (_fixedWidthBox)
    {
        var fixedWidth = markupKeys.indexOf("width") >= 0;
        [_fixedWidthBox setState:fixedWidth ? CPOnState : CPOffState];
        [_widthControl setEnabled:fixedWidth];
    }

    if (_fixedHeightBox)
    {
        var fixedHeight = markupKeys.indexOf("height") >= 0;
        [_fixedHeightBox setState:fixedHeight ? CPOnState : CPOffState];
        [_heightControl setEnabled:fixedHeight];
    }
}

- (void)toggleFixedSize:(id)sender
{
    if (!_inspectedObject)
        return;

    [_builderController setExplicitSize:([sender state] === CPOnState) forKey:([sender tag] === 0 ? @"width" : @"height") ofElement:_inspectedObject];
    [self _updateControlStates];
}

#pragma mark -
#pragma mark Bindings

- (void)commitBinding:(id)sender
{
    if (!_inspectedObject || !sender._uibBindingKey)
        return;

    var key = sender._uibBindingKey,
        value = String([sender stringValue] || "").trim(),
        current = ([_inspectedObject valueForKey:@"extraAttributes"] || {})[key] || "";

    if (value !== current)
        [_builderController setMarkupAttribute:key value:(value.length ? value : nil) ofElement:_inspectedObject];
}

- (void)controlTextDidEndEditing:(CPNotification)aNotification
{
    var field = [aNotification object];
    if (field && field._uibBindingKey)
        [self commitBinding:field];
}

- (void)takeColumnsFromEntity:(id)sender
{
    if (!_inspectedObject)
        return;

    // Commit a binding that is still being typed.
    for (var i = 0; _bindingFields && i < _bindingFields.length; i++)
        [self commitBinding:_bindingFields[i]];

    var error = [_builderController takeTableColumnsFromEntityForElement:_inspectedObject];
    [_bindingMessage setStringValue:error || @"Spalten übernommen."];
}

#pragma mark -
#pragma mark Attributes Tab

- (void)_reloadAttributes
{
    var extras = _inspectedObject ? ([_inspectedObject valueForKey:@"extraAttributes"] || {}) : {};

    _attributeNames = [];
    for (var name in extras)
        if (extras.hasOwnProperty(name))
            _attributeNames.push(name);

    _attributeNames.sort();
    [_attributesTableView reloadData];
}

- (void)addMarkupAttribute:(id)sender
{
    if (!_inspectedObject)
        return;

    var extras = [_inspectedObject valueForKey:@"extraAttributes"] || {},
        name = "attribute",
        counter = 1;

    while (extras[name])
        name = "attribute" + (++counter);

    [_builderController setMarkupAttribute:name value:@"" ofElement:_inspectedObject];
    [self _reloadAttributes];

    var row = _attributeNames.indexOf(name);
    if (row >= 0)
    {
        [_attributesTableView selectRowIndexes:[CPIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [_attributesTableView editColumn:0 row:row withEvent:nil select:YES];
    }
}

- (void)removeMarkupAttribute:(id)sender
{
    var row = [_attributesTableView selectedRow];
    if (!_inspectedObject || row < 0 || row >= _attributeNames.length)
        return;

    [_builderController setMarkupAttribute:_attributeNames[row] value:nil ofElement:_inspectedObject];
}

#pragma mark -
#pragma mark Connections Tab

- (void)_reloadConnections
{
    _connectionRows = [];

    if (_inspectedObject)
    {
        var elementID = [_inspectedObject valueForKey:@"id"],
            connections = [_builderController connectionsInvolvingElement:_inspectedObject];

        for (var i = 0; i < connections.length; i++)
        {
            var connection = connections[i],
                isSource = [connection valueForKey:@"sourceID"] === elementID,
                action = [connection valueForKey:@"action"],
                kind = action ? "Action" : "Outlet";

            _connectionRows.push({
                connection: connection,
                kind: isSource ? kind + " ▸" : "◂ " + kind,
                name: action || [connection valueForKey:@"outlet"] || "",
                other: [_builderController describeEndpointOfConnection:connection prefix:(isSource ? @"target" : @"source")]
            });
        }
    }

    [_connectionsTableView reloadData];

    var canConnect = !!_inspectedObject && [_inspectedObject valueForKey:@"type"] !== "owner";
    [_connectionAddButton setEnabled:canConnect];
    [_connectionNameField setEnabled:canConnect];
    [_connectionTargetField setEnabled:canConnect];
    [_connectionKindPopUp setEnabled:canConnect];
    [_connectionRemoveButton setEnabled:_connectionRows.length > 0];
}

- (void)connectionKindChanged:(id)sender
{
    [_connectionNameField setPlaceholderString:([_connectionKindPopUp indexOfSelectedItem] === 0) ? @"doSomething:" : @"delegate"];
}

- (void)addConnectionFromInspector:(id)sender
{
    var name = String([_connectionNameField stringValue] || "").trim(),
        target = String([_connectionTargetField stringValue] || "").trim(),
        isAction = [_connectionKindPopUp indexOfSelectedItem] === 0;

    if (!_inspectedObject || !name.length)
        return;

    if (isAction)
        [_builderController addConnectionFromElement:_inspectedObject toReference:target outlet:@"target" action:name];
    else
        [_builderController addConnectionFromElement:_inspectedObject toReference:target outlet:name action:nil];

    [_connectionNameField setStringValue:@""];
}

- (void)deleteSelectedConnection:(id)sender
{
    var indexes = [_connectionsTableView selectedRowIndexes],
        connections = [],
        index = [indexes firstIndex];

    while (index != CPNotFound)
    {
        if (index < _connectionRows.length)
            connections.push(_connectionRows[index].connection);
        index = [indexes indexGreaterThanIndex:index];
    }

    // Through the builder controller, so the deletion can be undone.
    if (connections.length)
        [_builderController removeConnections:connections];
}

#pragma mark -
#pragma mark Table Data Source / Delegate

- (int)numberOfRowsInTableView:(CPTableView)aTableView
{
    if (aTableView === _attributesTableView)
        return _attributeNames ? _attributeNames.length : 0;

    return _connectionRows ? _connectionRows.length : 0;
}

- (id)tableView:(CPTableView)aTableView objectValueForTableColumn:(CPTableColumn)aTableColumn row:(int)aRow
{
    var identifier = [aTableColumn identifier];

    if (aTableView === _attributesTableView)
    {
        var name = _attributeNames[aRow];
        if (identifier === "name")
            return name;
        return ([_inspectedObject valueForKey:@"extraAttributes"] || {})[name];
    }

    var row = _connectionRows[aRow];
    return row ? row[identifier] : nil;
}

- (void)tableView:(CPTableView)aTableView setObjectValue:(id)aValue forTableColumn:(CPTableColumn)aTableColumn row:(int)aRow
{
    if (aTableView !== _attributesTableView || !_inspectedObject)
        return;

    var name = _attributeNames[aRow];

    if ([aTableColumn identifier] === "name")
        [_builderController renameMarkupAttribute:name to:aValue ofElement:_inspectedObject];
    else
        [_builderController setMarkupAttribute:name value:aValue ofElement:_inspectedObject];
}

- (BOOL)tableView:(CPTableView)aTableView shouldEditTableColumn:(CPTableColumn)aTableColumn row:(int)aRow
{
    return aTableView === _attributesTableView;
}

- (void)tableViewSelectionDidChange:(CPNotification)aNotification
{
    if ([aNotification object] !== _connectionsTableView)
        return;

    // Highlight the selected connections on the canvas.
    var selected = [],
        indexes = [_connectionsTableView selectedRowIndexes],
        index = [indexes firstIndex];

    while (index != CPNotFound)
    {
        if (index < _connectionRows.length)
            selected.push(_connectionRows[index].connection);
        index = [indexes indexGreaterThanIndex:index];
    }

    [[_builderController connectionsController] setSelectedObjects:selected];
    [[_builderController canvasView] setNeedsDisplay:YES];
}

- (void)tabView:(CPTabView)aTabView didSelectTabViewItem:(CPTabViewItem)aTabViewItem
{
    [self _reloadConnections];
}

- (CPUndoManager)undoManager
{
    return [_builderController undoManager];
}

- (void)dealloc
{
    [self _stopInspecting];
    [_builderController removeObserver:self forKeyPath:@"elementsController.selectionIndexes"];
    [_builderController removeObserver:self forKeyPath:@"connectionsController.arrangedObjects"];
    [super dealloc];
}

@end

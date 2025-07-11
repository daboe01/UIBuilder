@import <AppKit/CPViewController.j>

@class UIBuilderController;

@implementation InspectorController : CPViewController
{
    UIBuilderController _builderController @accessors(property=builderController);
    CPPanel             _panel @accessors(property=panel);
}

- (void)awakeFromMarkup
{
    [_builderController addObserver:self forKeyPath:@"elementsController.selectionIndexes" options:CPKeyValueObservingOptionNew context:nil];
    [self updateInspector];
}

- (void)observeValueForKeyPath:(CPString)keyPath ofObject:(id)object change:(CPDictionary)change context:(id)context
{
    if (keyPath === @"elementsController.selectionIndexes")
    {
        [self updateInspector];
    }
}

- (void)updateInspector
{
    var selectedObjects = [[_builderController elementsController] selectedObjects];

    // Clear existing views
    var subviews = [[_panel contentView] subviews];
    for (var i = [subviews count] - 1; i >= 0; i--) {
        [subviews[i] removeFromSuperview];
    }

    if ([selectedObjects count] === 1)
    {
        var selectedObject = selectedObjects[0];
        var elementType = [selectedObject valueForKey:@"type"];
        var viewClass = classForElementType(elementType);
        var properties = [viewClass persistentProperties];

        var yPos = 10;

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
            [[_panel contentView] addSubview:label];
            [label setTextColor:[CPColor grayColor]];

            // Create Control based on property type
            if (propertyType === UIBBoolean) {
                var checkbox = [[CPCheckBox alloc] initWithFrame:CGRectMake(120, yPos, 100, 20)];
                [checkbox setTitle:@""];
                [checkbox bind:@"value" toObject:selectedObject withKeyPath:propertyName options:nil];
                [[_panel contentView] addSubview:checkbox];
            } else if (propertyType === UIBString || propertyType === UIBNumber) {
                var textField = [[CPTextField alloc] initWithFrame:CGRectMake(120, yPos, 100, 25)];
                [textField bind:@"value" toObject:selectedObject withKeyPath:propertyName options:nil];
                [textField setBezeled:YES];
                [textField setEditable:YES];
                [[_panel contentView] addSubview:textField];
            } else { // Fallback for unknown types
                var textField = [[CPTextField alloc] initWithFrame:CGRectMake(120, yPos, 150, 25)];
                [textField bind:@"value" toObject:selectedObject withKeyPath:propertyName options:nil];
                [textField setBezeled:YES];
                [textField setEditable:YES];
                [[_panel contentView] addSubview:textField];
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

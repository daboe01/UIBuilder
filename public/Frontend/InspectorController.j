@import <AppKit/CPViewController.j>

@class UIBuilderController;

@implementation InspectorController : CPViewController
{
    UIBuilderController _builderController @accessors(property=builderController);
    CPTextField         _valueField @accessors(property=valueField);
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
    if ([selectedObjects count] === 1)
    {
        var selectedObject = selectedObjects[0];
        var value = [selectedObject valueForKey:@"value"];

        [[self panel] orderFront:self];
        [[self valueField] setHidden:NO];

        var value = [selectedObject valueForKey:@"value"];
        console.log("Selected object:", selectedObject);
        console.log("Value:", value);

        if (value == null || value == undefined) {
            [[self valueField] setObjectValue:@""];
        } else if (typeof value === 'number') {
            [[self valueField] setObjectValue:[CPString stringWithFormat:@"%@", value]];
        } else {
            [[self valueField] setObjectValue:[CPString stringWithFormat:@"%@", value]];
        }
    }
    else
    {
        [[self panel] orderOut:self];
    }
}

- (IBAction)takeValueFromTextField:(id)sender
{
    var selectedObjects = [[_builderController elementsController] selectedObjects];
    if ([selectedObjects count] !== 1)
        return;

    var selectedObject = selectedObjects[0];
    var type = [selectedObject valueForKey:@"type"];
    var newValue = [sender objectValue];

    if (type === @"slider")
    {
        var numericValue = parseFloat(newValue);
        if (!isNaN(numericValue))
        {
            numericValue = Math.max(0.0, Math.min(1.0, numericValue));
            [_builderController changeValueForSelectedObject:numericValue];
        }
    }
    else
    {
        [_builderController changeValueForSelectedObject:newValue];
    }
}

- (void)dealloc
{
    [_builderController removeObserver:self forKeyPath:@"elementsController.selectionIndexes"];
    [super dealloc];
}

@end
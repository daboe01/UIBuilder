@import "UITextFieldView.j"

@implementation UIComboBoxView : UITextFieldView

+ (void)initialize
{
    if (self === [UIComboBoxView class])
    {
        [UIElementView registerViewClass:self forElementType:@"comboBox"];
    }
}

+ (CPDictionary)defaultValues
{
    return @{
        "value": "ComboBox",
        "items": "Item 1, Item 2, Item 3",
        "isEditable": true,
        "outlets": "delegate, dataSource",
        "actions": "takeStringValueFrom:"
    };
}

+ (CPArray)persistentProperties
{
    return [super persistentProperties].concat(["items", "isEditable", "outlets", "actions"]);
}

- (void)drawSkeleton:(CGRect)rect
{
    [super drawSkeleton:rect];
    var bounds = [self bounds];
    // Draw dropdown arrow
    var path = [CPBezierPath bezierPath];
    [path moveToPoint:CGPointMake(bounds.size.width - 15, 10)];
    [path lineToPoint:CGPointMake(bounds.size.width - 10, 15)];
    [path lineToPoint:CGPointMake(bounds.size.width - 5, 10)];
    [path stroke];
}

@end

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

+ (CPDictionary)propertyTypes
{
    var types = [[super propertyTypes] copy];
    [types setObject:UIBString forKey:@"items"];
    [types setObject:UIBBoolean forKey:@"isEditable"];
    [types setObject:UIBString forKey:@"outlets"];
    [types setObject:UIBString forKey:@"actions"];
    return types;
}

+ (CPDictionary)propertyGroups
{
    var groups = [[super propertyGroups] copy];
    [groups setObject:UIBPropertyTabProperties forKey:@"items"];
    [groups setObject:UIBPropertyTabProperties forKey:@"isEditable"];
    [groups setObject:UIBPropertyTabConnections forKey:@"outlets"];
    [groups setObject:UIBPropertyTabConnections forKey:@"actions"];
    return groups;
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

@import "UITextFieldView.j"

@implementation UISearchFieldView : UITextFieldView

+ (void)initialize
{
    if (self === [UISearchFieldView class])
    {
        [UIElementView registerViewClass:self forElementType:@"searchField"];
    }
}

+ (CPDictionary)defaultValues
{
    return {
        value: "Search",
        recentsAutosaveName: ""
    };
}

- (void)drawSkeleton:(CGRect)rect
{
    [super drawSkeleton:rect];
    // Draw a search icon
    var bounds = [self bounds];
    var iconRect = CGRectMake(5, (bounds.size.height - 12) / 2, 12, 12);
    [[CPColor grayColor] setStroke];
    var path = [CPBezierPath bezierPathWithOvalInRect:CGRectMake(iconRect.origin.x, iconRect.origin.y, 8, 8)];
    [path moveToPoint:CGPointMake(iconRect.origin.x + 7, iconRect.origin.y + 7)];
    [path lineToPoint:CGPointMake(iconRect.origin.x + 11, iconRect.origin.y + 11)];
    [path stroke];
}

@end
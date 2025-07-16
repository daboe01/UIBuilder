@import "UITextFieldView.j"

@implementation UISecureFieldView : UITextFieldView

+ (void)initialize
{
    if (self === [UISecureFieldView class])
    {
        [UIElementView registerViewClass:self forElementType:@"secureField"];
    }
}

- (void)drawSkeleton:(CGRect)rect
{
    [super drawSkeleton:rect];
    // Draw dots instead of text
    var bounds = [self bounds];
    var dots = "";
    for (var i = 0; i < 10; i++) {
        dots += "●";
    }
    [dots drawAtPoint:CGPointMake(5, (bounds.size.height - 12) / 2) withAttributes:_stringAttributes];
}

@end
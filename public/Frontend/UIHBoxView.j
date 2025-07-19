@import "../Frameworks/GSAutoLayout/GSAutoLayoutHBox.j"
@class UIElementView;

@implementation UIHBoxView : UIElementView
{
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        _isContainer = YES;
        [self setView:[[GSAutoLayoutHBox alloc] initWithFrame:[self bounds]]];
    }
    return self;
}

@end

@class UIElementView
@import "../Frameworks/GSAutoLayout/GSAutoLayoutVBox.j"

@implementation UIVBoxView : UIElementView
{
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        _isContainer = YES;
        [self setView:[[GSAutoLayoutVBox alloc] initWithFrame:[self bounds]]];
    }
    return self;
}

@end

@import "../Frameworks/GSAutoLayout/GSAutoLayoutHBox.j"
@class UIElementView;

@implementation UIHBoxView : UIElementView
{
    GSAutoLayoutHBox _layoutView;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        _isContainer = YES;
        _layoutView = [[GSAutoLayoutHBox alloc] initWithFrame:[self bounds]];
        [_layoutView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
        [self addSubview:_layoutView];
    }
    return self;
}

- (CPView)layoutView
{
    return _layoutView;
}

@end

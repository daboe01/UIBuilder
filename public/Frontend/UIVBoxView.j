@class UIElementView
@import "../Frameworks/GSAutoLayout/GSAutoLayoutVBox.j"

@implementation UIVBoxView : UIElementView
{
    GSAutoLayoutVBox _layoutView;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        _isContainer = YES;
        _layoutView = [[GSAutoLayoutVBox alloc] initWithFrame:[self bounds]];
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

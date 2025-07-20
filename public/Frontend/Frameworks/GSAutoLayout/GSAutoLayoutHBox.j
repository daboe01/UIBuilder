/*
 * GSAutoLayoutHBox.j
 * Renaissance
 *
 * Created by You on November 16, 2011.
 * Copyright 2011, Your Company All rights reserved.
 */

@implementation GSAutoLayoutHBox : CPView
{
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        [self setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    }
    return self;
}

- (void)addSubview:(CPView)aView
{
    [super addSubview:aView];
    [self setNeedsLayout:YES];
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    var subviews = [self subviews];
    var count = [subviews count];
    if (count === 0) return;

    var bounds = [self bounds];
    console.log("GSAutoLayoutHBox layoutSubviews bounds: " + JSON.stringify(bounds));
    var itemWidth = bounds.size.width / count;
    var currentX = 0;

    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        var frame = CGRectMake(currentX, 0, itemWidth, bounds.size.height);
        console.log("  - Setting frame for " + [subview class] + " to " + JSON.stringify(frame));
        [subview setFrame:frame];
        currentX += itemWidth;
    }
}

@end

/*
 * GSAutoLayoutVBox.j
 * Renaissance
 *
 * Created by You on November 16, 2011.
 * Copyright 2011, Your Company All rights reserved.
 */

@implementation GSAutoLayoutVBox : CPView
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
    var itemHeight = bounds.size.height / count;
    var currentY = 0;

    for (var i = 0; i < count; i++)
    {
        var subview = subviews[i];
        [subview setFrame:CGRectMake(0, currentY, bounds.size.width, itemHeight)];
        currentY += itemHeight;
    }
}

@end

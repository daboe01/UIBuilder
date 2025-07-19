/*
 * GSAutoLayoutVBox.j
 * Renaissance
 *
 * Created by You on November 16, 2011.
 * Copyright 2011, Your Company All rights reserved.
 */

@import "GSAutoLayoutManager.j"

@implementation GSAutoLayoutVBox : CPView
{
    GSAutoLayoutManager _vManager;
    GSAutoLayoutManager _hManager;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        _vManager = [[GSAutoLayoutManager alloc] init];
        _hManager = [[GSAutoLayoutManager alloc] init];
        [self setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    }
    return self;
}

- (void)addSubview:(CPView)aView
{
    [super addSubview:aView];
    [_vManager addLine:@"line1"];
    [_vManager addSegment:[aView description] forLine:@"line1"];
    [self setNeedsLayout:YES];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [_vManager layout];
}

@end

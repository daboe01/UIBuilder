/*
 * GSAutoLayoutHBox.j
 * Renaissance
 *
 * Created by You on November 16, 2011.
 * Copyright 2011, Your Company All rights reserved.
 */

@import "GSAutoLayoutManager.j"

@implementation GSAutoLayoutHBox : CPView
{
    GSAutoLayoutManager _hManager;
    GSAutoLayoutManager _vManager;
}

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];
    if (self) {
        _hManager = [[GSAutoLayoutManager alloc] init];
        _vManager = [[GSAutoLayoutManager alloc] init];
        [self setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    }
    return self;
}

- (void)addSubview:(CPView)aView
{
    [super addSubview:aView];
    [_hManager addLine:@"line1"];
    [_hManager addSegment:[aView description] forLine:@"line1"];
    [self setNeedsLayout:YES];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [_hManager layout];
}

@end

/*
 * GSAutoLayoutManager.j
 * Renaissance
 *
 * Created by You on November 16, 2011.
 * Copyright 2011, Your Company All rights reserved.
 */

@import <Foundation/Foundation.j>

// Notifications
var GSAutoLayoutManagerChangedLayoutNotification = @"GSAutoLayoutManagerChangedLayoutNotification";

// Alignment constants
var GSAutoLayoutExpand = 0;
var GSAutoLayoutWeakExpand = 1;
var GSAutoLayoutAlignMin = 2;
var GSAutoLayoutAlignCenter = 3;
var GSAutoLayoutAlignMax = 4;

@implementation GSAutoLayoutManager : CPObject
{
    CPMutableDictionary _lines;
    CPMutableDictionary _lineParts;
    CPMutableDictionary _segments;
    CPMutableArray      _sortedLineParts;
    BOOL                _needsLayout;
}

- (id)init
{
    self = [super init];
    if (self) {
        _lines = [CPMutableDictionary dictionary];
        _lineParts = [CPMutableDictionary dictionary];
        _segments = [CPMutableDictionary dictionary];
        _sortedLineParts = [CPMutableArray array];
        _needsLayout = YES;
    }
    return self;
}

- (void)addLine:(CPString)aLine
{
    [_lines setObject:[CPMutableDictionary dictionary] forKey:aLine];
    _needsLayout = YES;
}

- (void)addSegment:(CPString)aSegment forLine:(CPString)aLine
{
    var line = [_lines objectForKey:aLine];
    if (line)
    {
        [line setObject:[CPMutableDictionary dictionary] forKey:aSegment];
        _needsLayout = YES;
    }
}

- (void)setProperties:(CPDictionary)properties forSegment:(CPString)aSegment inLine:(CPString)aLine
{
    var line = [_lines objectForKey:aLine];
    if (line)
    {
        var segment = [line objectForKey:aSegment];
        if (segment)
        {
            [segment addEntriesFromDictionary:properties];
            _needsLayout = YES;
        }
    }
}

- (void)layout
{
    // This is a placeholder for the actual layout logic.
    // A real implementation would be much more complex.
    console.log("GSAutoLayoutManager: Performing layout...");

    var linePartCount = [_sortedLineParts count];
    if (linePartCount === 0) return;

    var totalSize = 0;
    for (var i = 0; i < linePartCount; i++)
    {
        var linePart = _sortedLineParts[i];
        totalSize += [linePart floatValue];
    }

    var lineKeys = [_lines allKeys];
    for (var i = 0; i < [lineKeys count]; i++)
    {
        var lineKey = lineKeys[i];
        var line = [_lines objectForKey:lineKey];
        var segmentKeys = [line allKeys];
        var currentPos = 0;

        for (var j = 0; j < [segmentKeys count]; j++)
        {
            var segmentKey = segmentKeys[j];
            var segment = [line objectForKey:segmentKey];
            var segmentSize = [segment floatValue];

            [segment setObject:currentPos forKey:@"position"];
            currentPos += segmentSize;
        }
    }

    _needsLayout = NO;
    [[CPNotificationCenter defaultCenter] postNotificationName:GSAutoLayoutManagerChangedLayoutNotification object:self];
}

- (CPDictionary)layoutInfoForSegment:(CPString)aSegment inLine:(CPString)aLine
{
    var line = [_lines objectForKey:aLine];
    if (line)
    {
        return [line objectForKey:aSegment];
    }
    return nil;
}

@end

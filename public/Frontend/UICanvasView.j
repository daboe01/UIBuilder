//
//  UICanvasView.j
//  A full-window canvas for the UI Builder.
//
//  By Daniel Boehringer in 2025.
//  - It acts as a drag-and-drop destination for new UI elements from the palette.
//  - It correctly instantiates different UIElementView subclasses based on the data model.
//


@import "UIBuilderConstants.j";
@import "UIElementView.j";
@import "ConnectionView.j";

// Import all the new view classes
@import "UIWindowView.j";
@import "UIButtonView.j";
@import "UISliderView.j";
@import "UITextFieldView.j";
@import "UICheckBoxView.j";
@import "UILabelView.j";
@import "UISearchFieldView.j";
@import "UISecureFieldView.j";
@import "UITextViewView.j";
@import "UIScrollViewView.j";
@import "UITableViewView.j";
@import "UISplitViewView.j";
@import "UIImageViewView.j";
@import "UIPopUpButtonView.j";
@import "UIComboBoxView.j";
@import "UIStepperView.j";
@import "UIDatePickerView.j";
@import "UIProgressIndicatorView.j";
@import "UIBoxView.j";
@import "UIHBoxView.j";
@import "UIVBoxView.j";


function treshold(value, limit)
{
    return value > 0 ? Math.min(value, limit) : Math.max(value, -limit);
}

@implementation UICanvasView : CPView
{
    CPPoint         _dragPoint;
    BOOL            _didDrag;
    CPArray         _selection;
    CPView          _rubberband;
    CPPoint         _rubberbandStartPoint;

    UIHSpaceView    _draggedHSpace;
    BOOL            _isManipulatingHSpace;
    BOOL            _isRubbing;
    CGPoint         _rubberStart;
    CGPoint         _rubberEnd;
    UIHBoxView      _highlightedHBox;
    UIVBoxView      _highlightedVBox;
    ConnectionView  _connectionView;
    CPView          _insertionIndicatorView;
    id              _delegate;
    id              _connectionsContainer;
    CPString        _connectionsKeyPath;
    CPArray         _oldConnections;
    id              _selectedConnectionsContainer;
    CPString        _selectedConnectionsKeyPath;
    id              _dataObjectsContainer;
    CPString        _dataObjectsKeyPath;
    CPArray         _oldDataObjects;
    id              _selectionIndexesContainer;
    CPString        _selectionIndexesKeyPath;
    UIElementView   _connectionSource;
    UIElementView   _connectionTarget;
    BOOL            _connectionMade;

    // Drag cancellation state
    UIElementView   _draggedElement;
    CPArray         _originalFrames;
    BOOL            _isCancelingDrag;
}

- (BOOL)isCancelingDrag
{
    return _isCancelingDrag;
}

- (void)dragDidStart:(UIElementView)anElement
{
    _draggedElement = anElement;
    _isCancelingDrag = NO;

    if (![_draggedElement isConnecting])
    {
        var selectedViews = [self selectedSubViews];
        var frames = [CPMutableArray array];
        for (var i = 0; i < [selectedViews count]; i++)
        {
            var view = selectedViews[i];
            [frames addObject:{view: view, frame: [view frame]}];
        }
        _originalFrames = frames;
    }
}

- (void)dragDidEnd
{
    _draggedElement = nil;
    _originalFrames = nil;
    _isCancelingDrag = NO;
}

-(BOOL)acceptsFirstMouse:(CPEvent)aEvent
{
    return YES;
}

// KVO contexts
var _propertyObservationContext = 1091;
var _dataObjectsObservationContext = 1092;
var _selectionIndexesObservationContext = 1093;
var _connectionsObservationContext = 1094;
var _selectedConnectionsObservationContext = 1095;

- (id)initWithFrame:(CGRect)aRect
{
    self = [super initWithFrame:aRect];

    if (self)
    {
        // Register to accept drops from the palette
        [self registerForDraggedTypes:[
            UIWindowDragType,
            UIButtonDragType,
            UISliderDragType,
            UITextFieldDragType,
            UICheckBoxDragType,
            UILabelDragType,
            UISearchFieldDragType,
            UISecureFieldDragType,
            UITextViewDragType,
            UIScrollViewDragType,
            UITableViewDragType,
            UISplitViewDragType,
            UIImageViewDragType,
            UIPopUpButtonDragType,
            UIComboBoxDragType,
            UIStepperDragType,
            UIDatePickerDragType,
            UIProgressIndicatorDragType,
            UIBoxDragType,
            UIHBoxDragType,
            UIVBoxDragType,
            UIHSpaceDragType,
            UIVSpaceDragType
        ]];

        _connectionView = [[ConnectionView alloc] initWithFrame:[self bounds]];
        [_connectionView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
        [self addSubview:_connectionView];

        _insertionIndicatorView = [[CPView alloc] initWithFrame:CGRectMakeZero()];
        [_insertionIndicatorView setBackgroundColor:[[CPColor yellowColor] colorWithAlphaComponent:0.5]];
        [[_insertionIndicatorView layer] setBorderColor:[[CPColor yellowColor] CGColor]];
        [[_insertionIndicatorView layer] setBorderWidth:1.0];
        [_insertionIndicatorView setHidden:YES];
        [self addSubview:_insertionIndicatorView];
    }
    return self;
}

#pragma mark - Bindings & KVO (Largely from EFLaceView)

+ (void)initialize
{
    [UIElementView registerViewClass:self forElementType:@"canvas"];
    [self exposeBinding:"dataObjects"];
    [self exposeBinding:@"selectionIndexes"];
    [self exposeBinding:@"connections"];
    [self exposeBinding:@"selectedConnections"];
}

- (void)bind:(CPString)bindingName toObject:(id)observableObject withKeyPath:(CPString)observableKeyPath options:(CPDictionary)options
{
    if ([bindingName isEqualToString:@"dataObjects"])
    {
        _dataObjectsContainer = observableObject;
        _dataObjectsKeyPath = observableKeyPath;
        [_dataObjectsContainer addObserver:self forKeyPath:_dataObjectsKeyPath options:(CPKeyValueObservingOptionNew | CPKeyValueObservingOptionOld) context:_dataObjectsObservationContext];
        [self startObservingDataObjects:[self dataObjects]];
        _oldDataObjects = [[self dataObjects] copy] || @[];
    }
    else if ([bindingName isEqualToString:@"selectionIndexes"])
    {
        _selectionIndexesContainer = observableObject;
        _selectionIndexesKeyPath = observableKeyPath;
        [_selectionIndexesContainer addObserver:self forKeyPath:_selectionIndexesKeyPath options:CPKeyValueObservingOptionNew | CPKeyValueObservingOptionOld context:_selectionIndexesObservationContext];
    }
    else if ([bindingName isEqualToString:@"connections"])
    {
        _connectionsContainer = observableObject;
        _connectionsKeyPath = observableKeyPath;
        [_connectionsContainer addObserver:self forKeyPath:_connectionsKeyPath options:(CPKeyValueObservingOptionNew | CPKeyValueObservingOptionOld) context:_connectionsObservationContext];
        _oldConnections = [[self connections] copy] || @[];
    }
    else if ([bindingName isEqualToString:@"selectedConnections"])
    {
        _selectedConnectionsContainer = observableObject;
        _selectedConnectionsKeyPath = observableKeyPath;
        [_selectedConnectionsContainer addObserver:self forKeyPath:_selectedConnectionsKeyPath options:CPKeyValueObservingOptionNew | CPKeyValueObservingOptionOld context:_selectedConnectionsObservationContext];
    }
    else { [super bind:bindingName toObject:observableObject withKeyPath:observableKeyPath options:options]; }

    [self setNeedsDisplay:YES];
}

- (void)unbind:(CPString)bindingName
{
    if ([bindingName isEqualToString:@"dataObjects"]) {
        [self stopObservingDataObjects:[self dataObjects]];
        [_dataObjectsContainer removeObserver:self forKeyPath:_dataObjectsKeyPath];
        _dataObjectsContainer = nil; _dataObjectsKeyPath = nil;
    } else if ([bindingName isEqualToString:@"selectionIndexes"]) {
        [_selectionIndexesContainer removeObserver:self forKeyPath:_selectionIndexesKeyPath];
        _selectionIndexesContainer = nil; _selectionIndexesKeyPath = nil;
    } else if ([bindingName isEqualToString:@"connections"]) {
        [_connectionsContainer removeObserver:self forKeyPath:_connectionsKeyPath];
        _connectionsContainer = nil; _connectionsKeyPath = nil;
    } else if ([bindingName isEqualToString:@"selectedConnections"]) {
        [_selectedConnectionsContainer removeObserver:self forKeyPath:_selectedConnectionsKeyPath];
        _selectedConnectionsContainer = nil; _selectedConnectionsKeyPath = nil;
    } else { [super unbind:bindingName]; }
    [self setNeedsDisplay:YES];
}

- (CPArray)dataObjects
{
    var result = [_dataObjectsContainer valueForKeyPath:_dataObjectsKeyPath];
    return (result == [CPNull null]) ? @[] : result;
}

- (CPIndexSet)selectionIndexes
{
    return [_selectionIndexesContainer valueForKeyPath:_selectionIndexesKeyPath];
}

- (CPArray)connections
{
    var result = [_connectionsContainer valueForKeyPath:_connectionsKeyPath];
    return (result == [CPNull null]) ? @[] : result;
}

- (CPArray)selectedConnections
{
    var result = [_selectedConnectionsContainer valueForKeyPath:_selectedConnectionsKeyPath];
    return (result == [CPNull null]) ? @[] : result;
}

- (void)setSelectionIndexes:(CPIndexSet)indexes
{
    [_selectionIndexesContainer setValue:indexes forKeyPath:_selectionIndexesKeyPath];
}

- (void)startObservingDataObjects:(CPArray)dataObjects
{
    if (!dataObjects || dataObjects == [CPNull null] || [dataObjects count] === 0)
        return;

    console.log("UICanvasView: startObservingDataObjects with:", dataObjects);
    var canvasWindow = [self window];
    if (!canvasWindow) {
        console.error("FATAL: Canvas has no window. Cannot create views.");
        return;
    }

    var objectsToProcess = [dataObjects mutableCopy];
    var successfullyAdded;
    var lastCount = 0;

    while ([objectsToProcess count] > 0 && [objectsToProcess count] != lastCount) {
        lastCount = [objectsToProcess count];
        successfullyAdded = [CPMutableArray array];

        for (var i = 0; i < [objectsToProcess count]; i++) {
            var newDataObject = objectsToProcess[i];
            var parentID = [newDataObject valueForKey:@"parentID"];
            var parentView = nil;

            if (parentID) {
                parentView = [self viewForElementWithID:parentID];
            }

            if (!parentID || parentView) {
                var superview = parentView || self;
                console.log("-> Creating view for:", [newDataObject valueForKey:@"id"], "in superview:", superview);
                [self _createViewForDataObject:newDataObject superview:superview window:canvasWindow];
                [successfullyAdded addObject:newDataObject];
            }
        }

        [objectsToProcess removeObjectsInArray:successfullyAdded];
    }

    if ([objectsToProcess count] > 0) {
        for (var i = 0; i < [objectsToProcess count]; i++) {
            console.error("UICanvasView: Could not create view for object during initial load:", objectsToProcess[i], ". Parent view not found.");
        }
    }
}

- (void)_createViewForDataObject:(CPDictionary)dataObject superview:(CPView)superview window:(CPWindow)aWindow atIndex:(int)index
{
    console.log("START _createViewForDataObject id:", [dataObject valueForKey:@"id"], "superview:", [superview class], "atIndex:", index);
    
    var type = [dataObject valueForKey:@"type"];
    var viewClass = [[UIElementView classMap] objectForKey:type] || UIElementView;
    var newView = [[viewClass alloc] init];
    console.log("did create newView");

    [newView setIsNewlyCreated:YES];
    [CPTimer scheduledTimerWithTimeInterval:0.1 target:newView selector:@selector(setIsNewlyCreated:) userInfo:NO repeats:NO];

    if (!newView) {
        console.error("FATAL: Failed to init view for class", viewClass);
        return;
    }

    if (index >= 0 && [superview respondsToSelector:@selector(_insertSubview:atIndex:)])
        [superview _insertSubview:newView atIndex:index];
    else
        [superview addSubview:newView];
        
    [newView setDataObject:dataObject];

    // Bind common properties
    [newView bind:@"originX" toObject:dataObject withKeyPath:@"originX" options:nil];
    [newView bind:@"originY" toObject:dataObject withKeyPath:@"originY" options:nil];
    [newView bind:@"width" toObject:dataObject withKeyPath:@"width" options:nil];
    [newView bind:@"height" toObject:dataObject withKeyPath:@"height" options:nil];
    console.log("did create bindings");

    // The iterative KVO observer is now responsible for creating children.
    // This recursive logic is no longer needed and causes conflicts.
    
    console.log("END _createViewForDataObject id:", [dataObject valueForKey:@"id"]);
}

// Keep a simple version for external calls if needed, though the main logic uses the windowed one.
- (void)_createViewForDataObject:(CPDictionary)dataObject superview:(CPView)superview
{
    [self _createViewForDataObject:dataObject superview:superview window:[self window] atIndex:-1];
}


- (void)stopObservingDataObjects:(CPArray)dataObjects
{
    if (!dataObjects || dataObjects == [CPNull null]) return;
    console.log("UICanvasView: stopObservingDataObjects:", dataObjects);

    var viewsToRemove = [CPMutableArray array];
    [self _findViewsForDataObjects:dataObjects inView:self foundViews:viewsToRemove];
    
    for (var i = 0; i < [viewsToRemove count]; i++) {
        var viewToRemove = viewsToRemove[i];
        console.log("-> Removing view:", viewToRemove, "for dataObject:", [viewToRemove dataObject]);
        [self _removeViewAndChildren:viewToRemove];
    }
}

- (void)_removeViewAndChildren:(UIElementView)viewToRemove
{
    // Unbind everything before removing
    [viewToRemove unbind:@"value"];
    [viewToRemove unbind:@"originX"];
    [viewToRemove unbind:@"originY"];
    [viewToRemove unbind:@"width"];
    [viewToRemove unbind:@"height"];

    var subviews = [[viewToRemove subviews] copy];
    for (var i = 0; i < [subviews count]; i++)
    {
        [self _removeViewAndChildren:subviews[i]];
    }

    [viewToRemove removeFromSuperview];
}

- (void)observeValueForKeyPath:(CPString)keyPath ofObject:(id)object change:(CPDictionary)change context:(id)context
{
    if (context == _dataObjectsObservationContext)
    {
        console.log("UICanvasView: KVO _dataObjectsObservationContext triggered. Change:", change);
        var newDataObjects = [object valueForKeyPath:_dataObjectsKeyPath];
        var oldDataObjects = _oldDataObjects;

        var added = [newDataObjects mutableCopy];
        [added removeObjectsInArray:oldDataObjects];

        if ([added count] > 0)
        {
            var successfullyAdded;
            var lastCount = 0;

            while ([added count] > 0 && [added count] != lastCount) {
                lastCount = [added count];
                successfullyAdded = [CPMutableArray array];

                for (var i = 0; i < [added count]; i++) {
                    var newDataObject = added[i];
                    var parentID = [newDataObject valueForKey:@"parentID"];
                    var parentView = nil;

                    if (parentID) {
                        parentView = [self viewForElementWithID:parentID];
                    }

                    if (!parentID || parentView) {
                        var superview = parentView || self;
                        var index = -1;
                        if (parentView)
                        {
                            var parentData = [parentView dataObject];
                            var siblingData = [parentData valueForKey:@"children"];
                            index = [siblingData indexOfObject:newDataObject];
                        }
                        
                        console.log("-> Creating view for:", [newDataObject valueForKey:@"id"], "in superview:", superview);
                        [self _createViewForDataObject:newDataObject superview:superview window:[self window] atIndex:index];
                        [successfullyAdded addObject:newDataObject];
                    }
                }

                [added removeObjectsInArray:successfullyAdded];
            }

            if ([added count] > 0) {
                for (var i = 0; i < [added count]; i++) {
                    console.error("UICanvasView: Could not create view for object:", added[i], ". Parent view not found.");
                }
            }
        }

        var removed = [oldDataObjects mutableCopy];
        [removed removeObjectsInArray:newDataObjects];
        [self stopObservingDataObjects:removed];

        _oldDataObjects = [newDataObjects copy];
        [self setNeedsDisplay:YES];
    }
    else if (context == _selectionIndexesObservationContext)
    {
        var allDataObjects = [self dataObjects];
        var newIndexes = [change objectForKey:CPKeyValueChangeNewKey] || [CPIndexSet indexSet];
        var oldIndexes = [change objectForKey:CPKeyValueChangeOldKey] || [CPIndexSet indexSet];

        // Find views for newly selected objects and redraw them
        var newSelectedDataObjects = [allDataObjects objectsAtIndexes:newIndexes];
        var newlySelectedViews = [CPMutableArray array];
        [self _findViewsForDataObjects:newSelectedDataObjects inView:self foundViews:newlySelectedViews];
        [newlySelectedViews makeObjectsPerformSelector:@selector(setNeedsDisplay:) withObject:YES];

        // Find views for deselected objects and redraw them, but only if those objects still exist.
        var previouslySelectedViews = [CPMutableArray array];
        var oldSelectedDataObjects = [CPMutableArray array];
        var lastIndex = [oldIndexes lastIndex];

        if (lastIndex != CPNotFound && lastIndex < [allDataObjects count])
        {
             oldSelectedDataObjects = [allDataObjects objectsAtIndexes:oldIndexes];
        }
        else
        {
            // If the indexes are out of bounds, it likely means the objects were deleted.
            // We need to find the views that were associated with the old indexes another way.
            // This is a tricky state to recover from. For now, we will just redraw all views.
            // A more sophisticated solution might involve caching view-data relationships.
            [[self subviews] makeObjectsPerformSelector:@selector(setNeedsDisplay:) withObject:YES];
            return;
        }

        [self _findViewsForDataObjects:oldSelectedDataObjects inView:self foundViews:previouslySelectedViews];
        [previouslySelectedViews makeObjectsPerformSelector:@selector(setNeedsDisplay:) withObject:YES];
    }
    else if (context == _connectionsObservationContext)
    {
        var newConnections = [object valueForKeyPath:_connectionsKeyPath];
        var oldConnections = _oldConnections;

        // For now, simply redraw all connections. A more optimized approach would be to only redraw changed connections.
        [self setNeedsDisplay:YES];
        _oldConnections = [newConnections copy];
    }
    else if (context == _selectedConnectionsObservationContext)
    {
        [self setNeedsDisplay:YES];
    }
}

#pragma mark - Drawing & Mouse

- (void)drawRect:(CPRect)rect
{
    // === START: Infographic Drawing ===

    var bounds = [self bounds];

    // 1. Define text attributes for the infographic
    var titleFont = [CPFont fontWithName:@"Helvetica-Bold" size:36];
    var subtitleFont = [CPFont fontWithName:@"Helvetica" size:18];
    var featureFont = [CPFont fontWithName:@"Helvetica" size:14];
    var watermarkColor = [CPColor colorWithCalibratedWhite:0.85 alpha:1.0]; // A light gray for the watermark effect

    var titleAttributes = @{
        CPFontAttributeName: titleFont,
        CPForegroundColorAttributeName: watermarkColor
    };
    var subtitleAttributes = @{
        CPFontAttributeName: subtitleFont,
        CPForegroundColorAttributeName: watermarkColor
    };
    var featureAttributes = @{
        CPFontAttributeName: featureFont,
        CPForegroundColorAttributeName: watermarkColor
    };

    // 2. Prepare the text content
    var title = @"Cappuccino JS";
    var subtitle = @"Desktop-Quality Applications in the Browser";
    var features = [
        @"• Drag-and-Drop UI Creation",
        @"• Direct Manipulation: Move & Resize (Keyboard / Mouse)",
        @"• Undo/Redo & Keyboard Navigation",
        @"• Control-Draggin  -> Target-Action & Outlet Connections",
        @"• Context sensitive inspector panel",
        @"• Run the 'real thing' in a separate native window",
        @"• Source: https://github.com/daboe01/UIBuilder"

    ];

    // 3. Calculate positions and draw the text, centering it on the canvas
    var titleSize = [title sizeWithAttributes:titleAttributes];
    var subtitleSize = [subtitle sizeWithAttributes:subtitleAttributes];
    var totalHeight = titleSize.height + subtitleSize.height + ([features count] * 20) + 40; // Approximate total height
    var currentY = (bounds.size.height - totalHeight) / 2.0;

    // Draw Title
    var titlePoint = CGPointMake((bounds.size.width - titleSize.width) / 2.0, currentY);
    [title drawAtPoint:titlePoint withAttributes:titleAttributes];
    currentY += titleSize.height + 10;

    // Draw Subtitle
    var subtitlePoint = CGPointMake((bounds.size.width - subtitleSize.width) / 2.0, currentY);
    [subtitle drawAtPoint:subtitlePoint withAttributes:subtitleAttributes];
    currentY += subtitleSize.height + 30;

    // Draw Feature List
    for (var i = 0; i < [features count]; i++) {
        var feature = features[i];
        var featureSize = [feature sizeWithAttributes:featureAttributes];
        var featurePoint = CGPointMake((bounds.size.width - featureSize.width) / 2.0, currentY);
        [feature drawAtPoint:featurePoint withAttributes:featureAttributes];
        currentY += featureSize.height + 5;
    }

    // === END: Infographic Drawing ===

    // The background is drawn by the window. We only draw the rubber-band.
    if (_isRubbing)
    {
        var rubber = CGRectUnion(CGRectMake(_rubberStart.x, _rubberStart.y, 0.1, 0.1), CGRectMake(_rubberEnd.x, _rubberEnd.y, 0.1, 0.1));
        [[[[CPColor alternateSelectedControlColor] colorWithAlphaComponent:0.2] setFill]];
        [CPBezierPath fillRect:rubber];
        [[CPColor alternateSelectedControlColor] setStroke];
        [CPBezierPath setDefaultLineWidth:1.0];
        [CPBezierPath strokeRect:rubber];
    }

    // Draw existing connections that are selected in the connections controller.
    var selectedConnections = [self selectedConnections];

    if (selectedConnections && [selectedConnections count] > 0)
    {
        for (var i = 0; i < [selectedConnections count]; i++)
        {
            var connection = [selectedConnections objectAtIndex:i];
            var sourceID = [connection valueForKey:@"sourceID"];
            var targetID = [connection valueForKey:@"targetID"];
            var sourceView = [self viewForElementWithID:sourceID];
            var targetView = [self viewForElementWithID:targetID];

            if (sourceView && targetView)
            {
                var startPoint = [sourceView convertPoint:CGPointMake(CGRectGetMidX([sourceView bounds]), CGRectGetMidY([sourceView bounds])) toView:self];
                var endPoint;
                var connectionPoint = [connection valueForKey:@"atPoint"];

                if (connectionPoint) {
                    endPoint = CGPointMake(connectionPoint.x, connectionPoint.y);
                } else {
                    endPoint = [targetView convertPoint:CGPointMake(CGRectGetMidX([targetView bounds]), CGRectGetMidY([targetView bounds])) toView:self];
                }

                // Draw the link with a distinct color, like blue.
                [self drawLinkFrom:startPoint to:endPoint color:[CPColor blueColor]];
            }
        }
    }
}

- (void)drawLinkFrom:(CGPoint)startPoint to:(CGPoint)endPoint color:(CPColor)insideColor
{

    var dist = Math.sqrt(Math.pow(startPoint.x - endPoint.x, 2) + Math.pow(startPoint.y - endPoint.y, 2));

    // a lace is made of an outside gray line of width 5, and a inside insideColor(ed) line of width 3
    var p0 = CGPointMake(startPoint.x, startPoint.y);
    var p3 = CGPointMake(endPoint.x, endPoint.y);

    var p1 = CGPointMake(startPoint.x + treshold((endPoint.x - startPoint.x) / 2, 50), startPoint.y);
    var p2 = CGPointMake(endPoint.x -   treshold((endPoint.x - startPoint.x) / 2, 50), endPoint.y);

    // p0 and p1 are on the same horizontal line
    // distance between p0 and p1 is set with the treshold fuction
    // the same holds for p2 and p3

    var path = [CPBezierPath bezierPath];
    [path setLineWidth:0];
    [[CPColor grayColor] set];
    [path appendBezierPathWithOvalInRect:CGRectMake(startPoint.x-2.5,startPoint.y-2.5,5,5)];
    [path fill];

    path = [CPBezierPath bezierPath];
    [path setLineWidth:0];
    [insideColor set];
    [path appendBezierPathWithOvalInRect:CGRectMake(startPoint.x-1.5,startPoint.y-1.5,3,3)];
    [path fill];

    path = [CPBezierPath bezierPath];
    [path setLineWidth:0];
    [[CPColor grayColor] set];
    [path appendBezierPathWithOvalInRect:CGRectMake(endPoint.x-2.5,endPoint.y-2.5,5,5)];
    [path fill];

    path = [CPBezierPath bezierPath];
    [path setLineWidth:0];
    [insideColor set];
    [path appendBezierPathWithOvalInRect:CGRectMake(endPoint.x-1.5,endPoint.y-1.5,3,3)];
    [path fill];

    // if the line is rather short, draw a straight line. the curve would look rather odd in this case.
    if (dist < 40)
    {
        path = [CPBezierPath bezierPath];
        [path setLineWidth:5];
        [path moveToPoint:startPoint];
        [path lineToPoint:endPoint];
        [[CPColor grayColor] set];
        [path stroke];

        path = [CPBezierPath bezierPath];
        [path setLineWidth:3];
        [path moveToPoint:startPoint];
        [path lineToPoint:endPoint];
        [insideColor set];
        [path stroke];

        return;
    }

    path = [CPBezierPath bezierPath];
    [path setLineWidth:5];
    [path moveToPoint:p0];
    [path curveToPoint:p3 controlPoint1:p1 controlPoint2:p2];
    [[CPColor grayColor] set];
    [path stroke];

    path = [CPBezierPath bezierPath];
    [path setLineWidth:3];
    [path moveToPoint:p0];
    [path curveToPoint:p3 controlPoint1:p1 controlPoint2:p2];
    [insideColor set];
    [path stroke];
}

#pragma mark - View Lookup

// Private recursive helper method to search the entire view hierarchy.
- (UIElementView)_findViewForElementWithID:(CPString)elementID inView:(CPView)aView
{
    // Iterate through all subviews of the current view
    var subviews = [aView subviews];
    for (var i = 0; i < [subviews count]; i++)
    {
        var subview = subviews[i];

        // We are only interested in UIElementView subclasses
        if (![subview isKindOfClass:[UIElementView class]])
            continue;

        // 1. Check if the current subview is the one we are looking for.
        if ([[subview dataObject] valueForKey:@"id"] === elementID)
        {
            return subview; // Found it!
        }

        // 2. If not, and this subview has children, recurse into it.
        //    This is the key step to search inside containers like UIWindowView.
        if ([[subview subviews] count] > 0)
        {
            var foundView = [self _findViewForElementWithID:elementID inView:subview];
            if (foundView)
            {
                return foundView; // Found it in a nested hierarchy.
            }
        }
    }

    // If we've searched this entire branch and found nothing, return nil.
    return nil;
}

// Public method to start the search from the canvas itself.
- (UIElementView)viewForElementWithID:(CPString)elementID
{
    if (!elementID)
        return nil;

    // Start the recursive search from the top-level canvas view.
    return [self _findViewForElementWithID:elementID inView:self];
}

- (void)drawConnectionFrom:(CGPoint)startPoint to:(CGPoint)endPoint
{
    [_connectionView setStartPoint:startPoint];
    [_connectionView setEndPoint:endPoint];
    [_connectionView setHidden:NO]; // Ensure it's visible when drawing
    [self addSubview:_connectionView]; // Bring to front
    [_connectionView setNeedsDisplay:YES];
}

- (void)clearConnection
{
    [_connectionView setHidden:YES];
    [_connectionView setNeedsDisplay:YES]; // Request redraw to clear old line
}

- (UIElementView)viewAtPoint:(CGPoint)aPoint
{
    // Start the search from the top-level canvas view.
    return [self _findDeepestUIElementViewAtPoint:aPoint inView:self];
}

- (UIElementView)_findDeepestUIElementViewAtPoint:(CGPoint)aPoint inView:(CPView)currentView
{
    // Iterate backwards to check top-most views first
    for (var i = [[currentView subviews] count] - 1; i >= 0; i--)
    {
        var subview = [[currentView subviews] objectAtIndex:i];

        // We only care about UIElementView subclasses that are visible
        if (![subview isKindOfClass:[UIElementView class]] || [subview isHidden])
            continue;

        var localPoint = [currentView convertPoint:aPoint toView:subview];

        // If the point is inside the subview's bounds, it's a candidate.
        if (CGRectContainsPoint([subview bounds], localPoint))
        {
            // If this subview is a container, recursively search its children.
            // This is the crucial step to find the *deepest* view.
            if (subview._isContainer && [[subview subviews] count] > 0)
            {
                var deeperView = [self _findDeepestUIElementViewAtPoint:localPoint inView:subview];
                if (deeperView)
                {
                    return deeperView; // Found a more specific view inside.
                }
            }

            // If no deeper view was found, or if this isn't a container,
            // this is the deepest view at this point in the hierarchy.
            return subview;
        }
    }

    // If no subview at this level contains the point, check if the current view itself is a candidate
    if ([currentView isKindOfClass:[UIElementView class]] && CGRectContainsPoint([currentView bounds], aPoint)) {
        return currentView;
    }


    // If no subview at this level contains the point, return nil.
    return nil;
}

- (void)mouseDown:(CPEvent)theEvent
{
    if (_connectionSource)
    {
        [self menuDidEndTracking:nil];
        return;
    }
    // A click on the canvas background starts a rubber-band selection.
    [self deselectViews];
    _isRubbing = YES;
    _rubberStart = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    _rubberEnd = _rubberStart;

    [CPApp setTarget:self selector:@selector(_dragOpenSpaceWithEvent:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
}

- (void)_dragOpenSpaceWithEvent:(CPEvent)theEvent
{
    var mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    _rubberEnd = mouseLoc;
    var rubberRect = CGRectUnion(CGRectMake(_rubberStart.x, _rubberStart.y, 1, 1), CGRectMake(_rubberEnd.x, _rubberEnd.y, 1, 1));
    
    switch ([theEvent type])
    {
        case CPLeftMouseDragged:
            var indexesToSelect = [CPMutableIndexSet indexSet];
            var allDataObjects = [self dataObjects];
            for (var i = 0; i < [[self subviews] count]; i++) {
                var aView = [self subviews][i];
                if ([aView isKindOfClass:[UIElementView class]] && CGRectIntersectsRect([aView frame], rubberRect)) {
                    var dataIndex = [allDataObjects indexOfObject:[aView dataObject]];
                    if (dataIndex != CPNotFound) {
                        [indexesToSelect addIndex:dataIndex];
                    }
                }
            }
            [_selectionIndexesContainer setValue:indexesToSelect forKeyPath:_selectionIndexesKeyPath];
            [self setNeedsDisplay:YES];
            [CPApp setTarget:self selector:@selector(_dragOpenSpaceWithEvent:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
            break;
        
        case CPLeftMouseUp:
            _isRubbing = NO;
            [self setNeedsDisplay:YES];
            break;
    }
}

- (void)delete:(id)sender
{
    // Forward the delete action to the delegate/controller
    if (_delegate && [_delegate respondsToSelector:@selector(removeSelectedElements)]) {
        [_delegate removeSelectedElements];
    }
}

- (void)cut:(id)sender
{
    if (_delegate && [_delegate respondsToSelector:@selector(cut:)]) {
        [_delegate cut:sender];
    }
}

- (void)copy:(id)sender
{
    if (_delegate && [_delegate respondsToSelector:@selector(copy:)]) {
        [_delegate copy:sender];
    }
}

- (void)paste:(id)sender
{
    if (_delegate && [_delegate respondsToSelector:@selector(paste:)]) {
        [_delegate paste:sender];
    }
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];

    if ([self window])
    {
        [[self window] makeFirstResponder:self];
    }
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}


- (BOOL)validateMenuItem:(CPMenuItem)aMenuItem
{
    var action = [aMenuItem action];

    if (action == @selector(copy:) || action == @selector(cut:) || action == @selector(delete:))
    {
        return [[self selectionIndexes] count] > 0;
    }

    if (action == @selector(paste:))
    {
        return [[[CPPasteboard generalPasteboard] types] containsObject:UIBuilderElementPboardType];
    }

    if (action == @selector(createTargetActionConnection:) || action == @selector(createOutletConnection:))
    {
        return YES;
    }

    var undoManager = [[self window] undoManager];

    if (action == @selector(undo:))
    {
        return [undoManager canUndo];
    }

    if (action == @selector(redo:))
    {
        return [undoManager canRedo];
    }

    return [super validateMenuItem:aMenuItem];
}


- (void)keyDown:(CPEvent)theEvent
{
    var characters = [theEvent characters];
    var flags = [theEvent modifierFlags];
    var selectors = [CPKeyBinding selectorsForKey:characters modifierFlags:flags];
    var delegate = [self delegate];
    var handled = NO;

    if (selectors)
    {
        for (var i = 0; i < [selectors count]; i++)
        {
            var selectorName = selectors[i];
            if ([self respondsToSelector:selectorName])
            {
                [self performSelector:selectorName withObject:self];
                handled = YES;
                break;
            }
            else if (delegate && [delegate respondsToSelector:selectorName])
            {
                [delegate performSelector:selectorName withObject:self];
                handled = YES;
                break;
            }
        }
    }

    if (!handled)
        [super keyDown:theEvent];
}

- (void)cancelOperation:(id)sender
{
    if (_draggedElement)
    {
        _isCancelingDrag = YES;

        if ([_draggedElement isConnecting])
        {
            [self clearConnection];
            // Any view that was a drop target needs to be un-highlighted
            var subviews = [self subviews];
            for (var i = 0; i < [subviews count]; i++)
            {
                if ([subviews[i] isKindOfClass:[UIElementView class]])
                    [subviews[i] setAsDropTarget:NO];
            }
        }
        else if (_originalFrames)
        {
            // Restore frames for move/resize
            for (var i = 0; i < [_originalFrames count]; i++)
            {
                var info = _originalFrames[i];
                [info.view setFrame:info.frame];
            }
        }

        // Tell the element to stop its drag loop/state
        [_draggedElement mouseUp:nil];

        [self setNeedsDisplay:YES];
    }
}

#pragma mark - Drag and Drop Destination

- (CPDragOperation)draggingEntered:(CPDraggingInfo)sender
{
    console.log("draggingEntered:", [sender draggingPasteboard]);
    // We accept any of the registered types
    return CPDragOperationCopy;
}

- (CPDragOperation)draggingUpdated:(CPDraggingInfo)sender
{
    var dropPoint = [self convertPoint:[sender draggingLocation] fromView:nil];
    var viewAtDrop = [self viewAtPoint:dropPoint];
    
    // Always reset indicators
    [_insertionIndicatorView setHidden:YES];
    if (_highlightedHBox) {
        [_highlightedHBox setAsDropTarget:NO];
        _highlightedHBox = nil;
    }
    if (_highlightedVBox) {
        [_highlightedVBox setAsDropTarget:NO];
        _highlightedVBox = nil;
    }

    var targetVBox = nil;

    // 1. Find the parent VBox
    if (viewAtDrop) {
        var currentView = viewAtDrop;
        while(currentView && currentView != self) {
            if ([currentView isKindOfClass:[UIVBoxView class]]) {
                targetVBox = currentView;
                break;
            }
            currentView = [currentView superview];
        }
    }

    if (!targetVBox) {
        if (viewAtDrop && [viewAtDrop isKindOfClass:[UIWindowView class]]) {
            [viewAtDrop setAsDropTarget:YES];
            _highlightedVBox = viewAtDrop;
        }
        return CPDragOperationCopy;
    }

    // 2. We have a VBox. Now check for HBoxes inside it.
    var targetHBox = nil;
    var localPointInVBox = [self convertPoint:dropPoint toView:targetVBox];
    var vboxSubviews = [targetVBox subviews];
    var lastHBox = null;

    for (var i = 0; i < [vboxSubviews count]; i++) {
        var subview = vboxSubviews[i];
        if ([subview isKindOfClass:[UIHBoxView class]]) {
            lastHBox = subview;
            if (CGRectContainsPoint([subview frame], localPointInVBox)) {
                targetHBox = subview;
                break;
            }
        }
    }

    // 3. Apply highlighting logic
    if (targetHBox) {
        _highlightedHBox = targetHBox;
        [_highlightedHBox setAsDropTarget:YES];
    } else if (lastHBox && localPointInVBox.y > CGRectGetMaxY([lastHBox frame])) {
        // No HBox hit, but we are below the last one. Show insertion indicator.
        var indicatorFrameInVBox = CGRectMake(
            [lastHBox frame].origin.x,
            CGRectGetMaxY([lastHBox frame]),
            [lastHBox frame].size.width,
            20 // Height of the indicator
        );
        var indicatorFrameInCanvas = [targetVBox convertRect:indicatorFrameInVBox toView:self];
        [_insertionIndicatorView setFrame:indicatorFrameInCanvas];
        [_insertionIndicatorView setHidden:NO];
        [self addSubview:_insertionIndicatorView];
    }
    else {
        // No HBox hit, so highlight the VBox itself
        _highlightedVBox = targetVBox;
        [_highlightedVBox setAsDropTarget:YES];
    }
    
    return CPDragOperationCopy;
}

- (void)draggingExited:(CPDraggingInfo)sender
{
    if (_highlightedHBox) {
        [_highlightedHBox setAsDropTarget:NO];
        _highlightedHBox = nil;
    }
    if (_highlightedVBox) {
        [_highlightedVBox setAsDropTarget:NO];
        _highlightedVBox = nil;
    }
    [_insertionIndicatorView setHidden:YES];
}

- (BOOL)prepareForDragOperation:(CPDraggingInfo)sender
{
    return YES;
}

- (BOOL)performDragOperation:(CPDraggingInfo)sender
{
    if (_highlightedHBox) {
        [_highlightedHBox setAsDropTarget:NO];
        _highlightedHBox = nil;
    }
    if (_highlightedVBox) {
        [_highlightedVBox setAsDropTarget:NO];
        _highlightedVBox = nil;
    }
    [_insertionIndicatorView setHidden:YES];

    var dropPoint = [self convertPoint:[sender draggingLocation] fromView:nil];
    var pasteboard = [sender draggingPasteboard];
    var types = [pasteboard types];
    var elementType = nil;

    console.log("UICanvasView: performDragOperation at point:", dropPoint);

    // Find the first registered drag type on the pasteboard
    var registeredTypes = [self registeredDraggedTypes];
    for (var i = 0; i < [types count]; i++) {
        var type = types[i];
        if ([registeredTypes containsObject:type]) {
            var temp = [type stringByReplacingOccurrencesOfString:@"DragType" withString:@""];
            if ([temp hasPrefix:@"UI"])
                temp = [temp substringFromIndex:2];
            elementType = [temp lowercaseString];
            break;
        }
    }

    if (elementType && _delegate)
    {
        console.log("-> Determined element type:", elementType);
        var viewAtDropPoint = [self viewAtPoint:dropPoint];
        var containerView = nil;

        if (viewAtDropPoint) {
            if (viewAtDropPoint._isContainer) {
                containerView = viewAtDropPoint;
            } else {
                // Dropped on a non-container, find its containing view
                var parent = [viewAtDropPoint superview];
                while (parent && parent != self) {
                    if ([parent isKindOfClass:[UIElementView class]] && parent._isContainer) {
                        containerView = parent;
                        break;
                    }
                    parent = [parent superview];
                }
            }
        }

        var containerData = nil;
        if (containerView) {
            containerData = [containerView dataObject];
            console.log("-> Found container view:", containerView, "with data:", containerData);
        } else {
            console.log("-> No container view found at drop point.");
        }

        if (containerData)
        {
            var index = -1;
            var localPoint = [containerView convertPoint:dropPoint fromView:self];

            if ([containerView isKindOfClass:[UIHBoxView class]])
            {
                var subviews = [containerView subviews];
                for (var i = 0; i < [subviews count]; i++)
                {
                    var subview = subviews[i];
                    if (localPoint.x < CGRectGetMidX([subview frame]))
                    {
                        index = i;
                        break;
                    }
                }
            }
            else if ([containerView isKindOfClass:[UIVBoxView class]])
            {
                var subviews = [containerView subviews];
                for (var i = 0; i < [subviews count]; i++)
                {
                    var subview = subviews[i];
                    if (localPoint.y < CGRectGetMidY([subview frame]))
                    {
                        index = i;
                        break;
                    }
                }
            }

            console.log("--> Calling addNewElementOfType:atPoint:inParent:atIndex:", index);
            if ([_delegate respondsToSelector:@selector(addNewElementOfType:atPoint:inParent:atIndex:)])
            {
                [_delegate addNewElementOfType:elementType atPoint:dropPoint inParent:containerData atIndex:index];
                [containerView setNeedsLayout:YES];
                [self setNeedsDisplay:YES];
                return YES;
            }
        } else {
            // Dropped on the canvas background
            if (elementType === "window") {
                console.log("--> It's a window, calling addNewElementOfType:atPoint:inParent: with nil parent.");
                if ([_delegate respondsToSelector:@selector(addNewElementOfType:atPoint:inParent:)]) {
                    [_delegate addNewElementOfType:elementType atPoint:dropPoint inParent:nil];
                    [self setNeedsDisplay:YES];
                    return YES;
                }
            } else {
                console.log("--> Not a window, calling addNewElementOfType:inNewWindowAtPoint:");
                if ([_delegate respondsToSelector:@selector(addNewElementOfType:inNewWindowAtPoint:)]) {
                    [_delegate addNewElementOfType:elementType inNewWindowAtPoint:dropPoint];
                    [self setNeedsDisplay:YES];
                    return YES;
                }
            }
        }
    }

    console.log("-> performDragOperation failed or was not handled.");
    return NO;
}

- (void)concludeDragOperation:(CPDraggingInfo)sender
{
    // This is called after the drag is complete.
    // We don't need to do anything here, but the method must exist.
}

#pragma mark - Delegate & Selection Management

- (id)delegate { return _delegate; }
- (void)setDelegate:(id)newDelegate { _delegate = newDelegate; }

- (void)deselectViews
{
    [_selectionIndexesContainer setValue:nil forKeyPath:_selectionIndexesKeyPath];
}

- (void)selectView:(UIElementView)aView state:(BOOL)select
{
    var selection = [[self selectionIndexes] mutableCopy] || [CPMutableIndexSet indexSet];
    var dataObjectIndex = [[self dataObjects] indexOfObject:[aView dataObject]];

    

    if (dataObjectIndex != CPNotFound)
    {
        if (select)
            [selection addIndex:dataObjectIndex];

        else [selection removeIndex:dataObjectIndex];
    }
    
    [_selectionIndexesContainer setValue:selection forKeyPath:_selectionIndexesKeyPath];
}

- (CPArray)selectedSubViews
{
    var selectedDataObjects = [[self dataObjects] objectsAtIndexes:[self selectionIndexes]];
    var selectedViews = [CPMutableArray array];

    [self _findViewsForDataObjects:selectedDataObjects inView:self foundViews:selectedViews];

    return selectedViews;
}

- (BOOL)isViewSelected:(CPView)aView
{
    var selected = [self selectedSubViews];

    return [selected containsObject:aView];
}

- (void)_findViewsForDataObjects:(CPArray)dataObjects inView:(CPView)aView foundViews:(CPMutableArray)foundViews
{
    var subviews = [aView subviews];

    for (var i = 0; i < [subviews count]; i++)
    {
        var subview = subviews[i];

        // Skip the connection view and any other non-UIElementView instances
        if (![subview isKindOfClass:[UIElementView class]])
            continue;

        var contains = [dataObjects containsObject:[subview dataObject]];

        if (contains)
        {
            [foundViews addObject:subview];
        }

        // Recurse into subviews
        [self _findViewsForDataObjects:dataObjects inView:subview foundViews:foundViews];
    }
}

// These methods are called by the UIElementView children to notify the controller
- (void)elementDidMove:(UIElementView)anElement
{
    if (_delegate && [_delegate respondsToSelector:@selector(canvasView:didMoveElement:)]) {
        [_delegate canvasView:self didMoveElement:anElement];
    }
}

- (void)elementDidResize:(UIElementView)anElement
{
    if (_delegate && [_delegate respondsToSelector:@selector(canvasView:didResizeElement:)]) {
        [_delegate canvasView:self didResizeElement:anElement];
    }
}

- (void)elementDidConnect:(UIElementView)sourceElement to:(UIElementView)targetElement atPoint:(CGPoint)aPoint
{
    if (_delegate && [_delegate respondsToSelector:@selector(canvasView:didConnectElement:toElement:atPoint:)]) {
        [_delegate canvasView:self didConnectElement:sourceElement toElement:targetElement atPoint:aPoint];
    }
}

#pragma mark - Connection Menu

- (void)showConnectionMenuForSource:(UIElementView)sourceView target:(UIElementView)targetView at:(CGPoint)aPoint
{
    _connectionSource = sourceView;
    _connectionTarget = targetView;
    _connectionMade = NO;

    var menu = [[CPMenu alloc] initWithTitle:@"Connection Menu"];
    [menu setDelegate:self];

    // 1. Add Target's Actions
    var targetActions = [[_connectionTarget dataObject] valueForKey:@"actions"];
    if (targetActions && [targetActions length] > 0)
    {
        var actionsArray = [targetActions componentsSeparatedByString:@", "];
        for (var i = 0; i < [actionsArray count]; i++)
        {
            var actionName = actionsArray[i];
            var menuItem = [[CPMenuItem alloc] initWithTitle:actionName action:@selector(createTargetActionConnection:) keyEquivalent:@""];
            [menu addItem:menuItem];
        }
    }

    // 2. Add Separator
    if ([menu numberOfItems] > 0)
        [menu addItem:[CPMenuItem separatorItem]];

    // 3. Add Source's Outlets
    var sourceOutlets = [[_connectionSource dataObject] valueForKey:@"outlets"];
    if (sourceOutlets && [sourceOutlets length] > 0)
    {
        var outletsArray = [sourceOutlets componentsSeparatedByString:@", "];
        for (var i = 0; i < [outletsArray count]; i++)
        {
            var outletName = outletsArray[i];
            if (outletName === @"target") continue; // Skip 'target' outlet as requested
            var menuItem = [[CPMenuItem alloc] initWithTitle:outletName action:@selector(createOutletConnection:) keyEquivalent:@""];
            [menu addItem:menuItem];
        }
    }

    if ([menu numberOfItems] > 0)
    {
        [CPMenu popUpContextMenu:menu withEvent:[CPApp currentEvent] forView:self];
    }
    else
    {
        [self menuDidEndTracking:menu]; // No items, so clean up immediately
    }
}

- (void)createTargetActionConnection:(CPMenuItem)sender
{
    var actionName = [sender title];
    if (_delegate && [_delegate respondsToSelector:@selector(canvasView:didConnectElement:toElement:asTargetAction:)])
    {
        _connectionMade = YES;
        [self clearConnection];
        if (_connectionTarget)
            [_connectionTarget setAsDropTarget:NO];

        [_delegate canvasView:self didConnectElement:_connectionSource toElement:_connectionTarget asTargetAction:actionName];
    }
}

- (void)createOutletConnection:(CPMenuItem)sender
{
    var outletName = [sender title];
    if (_delegate && [_delegate respondsToSelector:@selector(canvasView:didConnectElement:toElement:asOutlet:)])
    {
        _connectionMade = YES;
        [self clearConnection];
        if (_connectionTarget)
            [_connectionTarget setAsDropTarget:NO];

        [_delegate canvasView:self didConnectElement:_connectionSource toElement:_connectionTarget asOutlet:outletName];
    }
}

- (void)menuDidEndTracking:(CPMenu)aMenu
{
    // This delegate method is called after a menu item is selected OR the menu is cancelled.
    if (!_connectionMade)
    {
        [self clearConnection];
        if (_connectionTarget)
            [_connectionTarget setAsDropTarget:NO];
    }

    // Reset state
    _connectionSource = nil;
    _connectionTarget = nil;
    _connectionMade = NO;

    [self setNeedsDisplay:YES];
}

@end

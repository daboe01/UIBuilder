//
//  UIBuilderConstants.j
//  Defines global constants for the UI Builder application.
//

UIBuilderElementPboardType = "UIBuilderElementPboardType";
UIWindowDragType = "UIWindowDragType";
UIButtonDragType = "UIButtonDragType";
UISliderDragType = "UISliderDragType";
UITextFieldDragType = "UITextFieldDragType";
UICheckBoxDragType = "UICheckBoxDragType";
UILabelDragType = "UILabelDragType";
UISearchFieldDragType = "UISearchFieldDragType";
UISecureFieldDragType = "UISecureFieldDragType";
UITextViewDragType = "UITextViewDragType";
UIScrollViewDragType = "UIScrollViewDragType";
UITableViewDragType = "UITableViewDragType";
UISplitViewDragType = "UISplitViewDragType";
UIImageViewDragType = "UIImageViewDragType";
UIPopUpButtonDragType = "UIPopUpButtonDragType";
UIComboBoxDragType = "UIComboBoxDragType";
UIStepperDragType = "UIStepperDragType";
UIDatePickerDragType = "UIDatePickerDragType";
UIProgressIndicatorDragType = "UIProgressIndicatorDragType";
UIBoxDragType = "UIBoxDragType";

UIHSpaceDragType = "UIHSpaceDragType";
UIVSpaceDragType = "UIVSpaceDragType";
UIHBoxDragType   = "UIHBoxDragType";
UIVBoxDragType   = "UIVBoxDragType";

// --- Property Types ---
UIBString = "UIBString";
UIBNumber = "UIBNumber";
UIBBoolean = "UIBBoolean";
UIBEnumeration = "UIBEnumeration";
UIBColor = "UIBColor";

// --- Inspector Tabs ---
UIBPropertyTabProperties = 0;
UIBPropertyTabLayout = 1;
UIBPropertyTabConnections = 2;


// --- Constants for Resizing ---
kUIElementHandleSize = 8.0;
kUIElementNoHandle = 0;
kUIElementTopLeftHandle = 1;
kUIElementTopMiddleHandle = 2;
kUIElementTopRightHandle = 3;
kUIElementMiddleLeftHandle = 4;
kUIElementMiddleRightHandle = 5;
kUIElementBottomLeftHandle = 6;
kUIElementBottomMiddleHandle = 7;
kUIElementBottomRightHandle = 8;

// --- Undo support ---
// The object that is told about every model change so it can register the
// inverse operation with the document's CPUndoManager (the UIBuilderController).
UIBModelUndoDelegate = nil;

// While > 0, model changes are not recorded for undo. Used for derived
// changes (layout passes) and for interactive drags, which register a single
// coalesced undo step when the mouse goes up.
UIBUndoSuppressionCount = 0;

// Keys that describe the structure of the element tree. Changes to these are
// handled by the structural undo primitives, never by per-key undo.
UIBStructuralKeys = { "id": true, "type": true, "parentID": true, "children": true, "isRootVBox": true };

// Geometry keys. These must always be numbers.
UIBNumericKeys = { "originX": true, "originY": true, "width": true, "height": true };

// Element types that only arrange other elements.
UIBLayoutElementTypes = { "hbox": true, "vbox": true, "hspace": true, "vspace": true };

// Runs aFunction without recording any model change for undo.
UIBPerformWithoutUndo = function(aFunction)
{
    UIBUndoSuppressionCount++;
    try
    {
        return aFunction();
    }
    finally
    {
        UIBUndoSuppressionCount--;
    }
};

UIBuilderDocumentPasteboardMarker = "de.pachbaylabs.uibuilder.elements";

// --- Cappusance ---
UITabViewDragType    = "UITabViewDragType";
UICustomViewDragType = "UICustomViewDragType";

// Numeric keys that may also be unset (e.g. a window's x/y position).
UIBClearableNumericKeys = { "x": true, "y": true };
UIBNumericKeys["x"] = true;
UIBNumericKeys["y"] = true;

// Internal bookkeeping keys that are never edited per key.
UIBStructuralKeys["isImported"] = true;
UIBStructuralKeys["syntheticRoot"] = true;
UIBStructuralKeys["rawChildren"] = true;
UIBStructuralKeys["rawItemsSignature"] = true;
UIBStructuralKeys["markupAttributeOrder"] = true;
UIBStructuralKeys["leadingComments"] = true;
UIBStructuralKeys["trailingComments"] = true;
UIBStructuralKeys["kind"] = true;

// Normalizes Renaissance alignment values to min / center / max / expand.
UIBAlignKind = function(aValue)
{
    switch (aValue)
    {
        case "expand":
        case "wexpand":
            return "expand";
        case "center":
            return "center";
        case "max":
        case "right":
        case "bottom":
            return "max";
        default:
            return "min";
    }
};

UIBHorizontalAlignValues = ["min", "center", "max", "expand", "wexpand", "left", "right"];
UIBVerticalAlignValues   = ["min", "center", "max", "expand", "wexpand", "top", "bottom"];

// The owner object of a Cappusance document ("#CPOwner").
UIBOwnerReference = "CPOwner";

// --- Data model ---
UIBDataModelDidChangeNotification = "UIBDataModelDidChangeNotification";

// Bindings the inspector offers per element type.
UIBBindingKeysForType = {
    "tableView":        ["valueBinding"],
    "popUpButton":      ["itemsBinding", "valueBinding", "enabledBinding"],
    "comboBox":         ["itemsBinding", "valueBinding", "enabledBinding"],
    "textField":        ["valueBinding", "enabledBinding"],
    "searchField":      ["valueBinding"],
    "secureField":      ["valueBinding", "enabledBinding"],
    "label":            ["valueBinding"],
    "checkBox":         ["valueBinding", "enabledBinding"],
    "slider":           ["valueBinding", "enabledBinding"],
    "stepper":          ["valueBinding", "enabledBinding"],
    "datePicker":       ["valueBinding", "enabledBinding"],
    "textView":         ["valueBinding"],
    "button":           ["enabledBinding"],
    "progresIndicator": ["valueBinding"]
};

// --- Localization ---
// Every user-visible string goes through this. The English text is the key;
// translations come from the "UIBuilder" strings table of the main bundle
// (CPLocalizedStringFromTable). Without a table, the English text is shown.
UIBLocalizationTable = "UIBuilder";

UIBLocalized = function(aString)
{
    if (aString === nil || aString === undefined || aString === "")
        return aString;

    try
    {
        if (typeof CPLocalizedStringFromTable === "function")
        {
            var localized = CPLocalizedStringFromTable(aString, UIBLocalizationTable, "");
            if (localized)
                return localized;
        }
    }
    catch (e)
    {
    }

    return aString;
};

// UIBLocalizedFormat("Columns of “%@”", name)
UIBLocalizedFormat = function(aFormat)
{
    var args = Array.prototype.slice.call(arguments, 1),
        result = UIBLocalized(aFormat),
        index = 0;

    return String(result).replace(/%@/g, function() { return String(args[index++]); });
};

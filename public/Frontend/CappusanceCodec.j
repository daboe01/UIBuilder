//
//  CappusanceCodec.j
//  Reads and writes Cappusance (Renaissance / GSMarkup for Cappuccino) markup.
//
//  The builder keeps one data object per markup element. Everything the
//  builder does not understand is preserved verbatim, so a document survives
//  an import/export round trip:
//
//    markupTag             the element's tag when it differs from the default
//                          (comboBoxCI, StringValueDatePicker, unknown tags, ...)
//    extraAttributes       attributes without a builder property (bindings, ...)
//    rawChildren           child XML the builder does not model (menu items,
//                          table columns with attributes, unknown children)
//    markupKeys            the data keys that are written back for imported
//                          elements (attributes that were present or that the
//                          user changed)
//    markupAttributeOrder  original attribute order, used when writing
//
//  Connections are imported from inline attributes (target/action, delegate,
//  dataSource, nextKeyView) and from <outlet>/<control>/<connector> entries.
//

@import <Foundation/CPObject.j>
@import "UIBuilderConstants.j"

var UIBCommonLayoutAttributes = [["halign", "halign"], ["valign", "valign"], ["width", "width"], ["height", "height"]],
    UIBInlineOutletAttributes = { "delegate": YES, "dataSource": YES, "nextKeyView": YES };

/*
    The schema maps builder element types to Cappusance tags.

    tags        accepted tags, the first one is written for new elements
    attributes  [dataKey, attributeName] pairs (layout attributes are added automatically)
    text        data key stored as the element's text content
    items       data key holding a comma separated list that is written as child items
    content     how child elements are stored: stack, root, tabs, tabItem
    always      keys written for elements created in the builder even if they equal the default
    defaults    builder defaults (override the view class defaults)
    noLayout    no halign/valign/width/height attributes
*/
UIBCappusanceSchema = {
    "window": {
        tags: ["window", "panel"],
        attributes: [["value", "title"], ["x", "x"], ["y", "y"], ["width", "width"], ["height", "height"],
                     ["closable", "closable"], ["resizable", "resizable"], ["miniaturizable", "miniaturizable"],
                     ["visible", "visible"], ["bridge", "bridge"], ["autosaveName", "autosaveName"]],
        content: "root",
        noLayout: YES,
        always: ["value", "width", "height", "x", "y"],
        defaults: { value: "Window", closable: YES, resizable: YES, miniaturizable: YES, visible: YES, bridge: NO, autosaveName: "" }
    },
    "vbox":   { tags: ["vbox"], attributes: [], content: "stack", always: ["halign", "valign"], defaults: { halign: "expand", valign: "expand" } },
    "hbox":   { tags: ["hbox"], attributes: [], content: "stack", always: ["halign", "valign"], defaults: { halign: "expand", valign: "min" } },
    "hspace": { tags: ["hspace"], attributes: [], fixedSizeKey: "width", always: ["halign"], defaults: { halign: "expand", valign: "min" } },
    "vspace": { tags: ["vspace"], attributes: [], fixedSizeKey: "height", always: ["valign"], defaults: { halign: "min", valign: "expand" } },
    "box": {
        tags: ["box"], attributes: [["title", "title"], ["hasBorder", "hasBorder"]], content: "stack",
        always: ["halign", "valign", "title"], defaults: { title: "Box", hasBorder: YES, halign: "expand", valign: "min" }
    },
    "label": {
        tags: ["label"], text: "value",
        attributes: [["horizontalTextAlign", "align"], ["color", "textColor"], ["selectable", "selectable"]],
        always: ["value", "halign", "valign"],
        defaults: { value: "Label", horizontalTextAlign: "left", color: "#000000", selectable: NO, halign: "min", valign: "min" }
    },
    "textField": {
        tags: ["textField"], text: "value",
        attributes: [["editable", "editable"], ["selectable", "selectable"], ["enabled", "enabled"], ["bezeled", "bezeled"]],
        always: ["value", "halign", "valign"],
        defaults: { value: "", editable: YES, selectable: YES, enabled: YES, bezeled: YES, halign: "expand", valign: "min" }
    },
    "searchField": { tags: ["searchField"], text: "value", attributes: [], always: ["value", "halign", "valign"], defaults: { value: "", halign: "expand", valign: "min" } },
    "secureField": { tags: ["secureTextField"], text: "value", attributes: [], always: ["value", "halign", "valign"], defaults: { value: "", halign: "expand", valign: "min" } },
    "button": {
        tags: ["button"], attributes: [["value", "title"], ["keyEquivalent", "keyEquivalent"], ["enabled", "enabled"]],
        always: ["value", "halign", "valign"], defaults: { value: "Button", keyEquivalent: "", enabled: YES, halign: "min", valign: "min" }
    },
    "checkBox": {
        tags: ["switchButton"], attributes: [["title", "title"], ["value", "selected"]],
        always: ["title", "halign", "valign"], defaults: { title: "", value: NO, halign: "min", valign: "min" }
    },
    "slider": {
        tags: ["slider"], attributes: [["value", "current"], ["minValue", "min"], ["maxValue", "max"], ["continuous", "continuous"]],
        always: ["halign", "valign"], defaults: { value: 50, minValue: 0, maxValue: 100, continuous: YES, halign: "expand", valign: "min" }
    },
    "popUpButton": {
        tags: ["popUpButton"], attributes: [["pullsDown", "pullsDown"]], items: { key: "items", tag: "popUpButtonItem", attribute: "title" },
        always: ["items", "halign", "valign"], defaults: { items: "Item 1, Item 2, Item 3", pullsDown: NO, halign: "min", valign: "min" }
    },
    "comboBox": {
        tags: ["comboBox", "comboBoxCI", "comboBoxTagValue"], attributes: [["completes", "completes"], ["isEditable", "editable"]],
        items: { key: "items", tag: "popUpButtonItem", attribute: "title" },
        always: ["halign", "valign"], defaults: { value: "", items: "", completes: NO, isEditable: YES, halign: "expand", valign: "min" }
    },
    "stepper": {
        tags: ["stepper"], attributes: [["minValue", "min"], ["maxValue", "max"], ["increment", "increment"]],
        always: ["halign", "valign"], defaults: { value: 0, minValue: 0, maxValue: 100, increment: 1, halign: "min", valign: "min" }
    },
    "datePicker": {
        tags: ["datePicker", "StringValueDatePicker", "stringValueDatePicker"], attributes: [["style", "style"]],
        always: ["halign", "valign"], defaults: { value: "", style: "textual", halign: "min", valign: "min" }
    },
    "progresIndicator": {
        tags: ["progresIndicator", "progressIndicator"], attributes: [["isIndeterminate", "indeterminate"]],
        always: ["halign", "valign"], defaults: { isIndeterminate: NO, halign: "min", valign: "min" }
    },
    "imageView": { tags: ["imageView"], attributes: [], always: ["halign", "valign"], defaults: { value: "", halign: "min", valign: "min" } },
    "textView": {
        tags: ["textView"], text: "value", attributes: [["editable", "editable"]],
        always: ["halign", "valign"], defaults: { value: "", editable: YES, halign: "expand", valign: "expand" }
    },
    "scrollView": {
        tags: ["scrollView"], attributes: [["hasHorizontalScroller", "hasHorizontalScroller"], ["hasVerticalScroller", "hasVerticalScroller"]],
        content: "root", always: ["halign", "valign"],
        defaults: { hasHorizontalScroller: YES, hasVerticalScroller: YES, halign: "expand", valign: "expand" }
    },
    "tableView": {
        tags: ["tableView"], attributes: [], items: { key: "columns", tag: "tableColumn", attribute: "title" },
        always: ["columns"], defaults: { columns: "Column 1, Column 2", halign: "expand", valign: "expand" }
    },
    "splitView": {
        tags: ["splitView"], attributes: [["vertical", "vertical"]], content: "root",
        always: ["halign", "valign"], defaults: { vertical: NO, halign: "expand", valign: "expand" }
    },
    "tabView": {
        tags: ["tabView"], attributes: [["tabViewType", "type"]], content: "tabs",
        always: ["halign", "valign"], defaults: { tabViewType: "topBezel", halign: "expand", valign: "expand" }
    },
    "tabViewItem": {
        tags: ["tabViewItem"], attributes: [["value", "title"]], content: "tabItem", noLayout: YES,
        always: ["value"], defaults: { value: "Tab", halign: "expand", valign: "expand" }
    },
    "custom": {
        tags: [], attributes: [], always: [], defaults: { markupTag: "view", halign: "min", valign: "min" }
    },
    "owner": {
        tags: [], attributes: [], always: [], noLayout: YES, defaults: { value: "File's Owner", actions: "", outlets: "" }
    }
};

// Choices offered by the inspector for some string properties.
UIBPropertyChoices = {
    "halign": UIBHorizontalAlignValues,
    "valign": UIBVerticalAlignValues,
    "horizontalTextAlign": ["left", "center", "right"],
    "style": ["textual", "graphical"],
    "tabViewType": ["topBezel", "bottomBezel", "noTabsBezel"]
};

UIBSchemaForType = function(aType)
{
    return UIBCappusanceSchema[aType] || UIBCappusanceSchema["custom"];
};

UIBTypeForTag = function(aTag)
{
    for (var type in UIBCappusanceSchema)
    {
        if (!UIBCappusanceSchema.hasOwnProperty(type))
            continue;

        if (UIBCappusanceSchema[type].tags.indexOf(aTag) >= 0)
            return type;
    }
    return nil;
};

// All [dataKey, attributeName] pairs of a type, including the layout attributes.
UIBAttributeMapForType = function(aType)
{
    var schema = UIBSchemaForType(aType),
        result = (schema.attributes || []).slice();

    if (!schema.noLayout)
    {
        for (var i = 0; i < UIBCommonLayoutAttributes.length; i++)
        {
            var pair = UIBCommonLayoutAttributes[i],
                exists = NO;

            for (var j = 0; j < result.length; j++)
                if (result[j][0] === pair[0])
                    exists = YES;

            if (!exists)
                result.push(pair);
        }
    }

    return result;
};

// Data keys the inspector shows for a type (in display order).
UIBEditableKeysForType = function(aType)
{
    if (aType === "owner")
        return ["value", "actions", "outlets"];

    var schema = UIBSchemaForType(aType),
        keys = [];

    if (aType === "custom")
        keys.push("markupTag");

    if (schema.text)
        keys.push(schema.text);

    var attributes = UIBAttributeMapForType(aType);
    for (var i = 0; i < attributes.length; i++)
        if (keys.indexOf(attributes[i][0]) < 0)
            keys.push(attributes[i][0]);

    if (schema.items && keys.indexOf(schema.items.key) < 0)
        keys.push(schema.items.key);

    return keys;
};

UIBSplitList = function(aString)
{
    if (aString === nil || aString === undefined)
        return [];

    return String(aString).split(",").map(function(s) { return s.trim(); }).filter(function(s) { return s.length > 0; });
};

UIBXMLEscapeText = function(aString)
{
    return String(aString).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
};

UIBXMLEscapeAttribute = function(aString)
{
    return UIBXMLEscapeText(aString).replace(/"/g, "&quot;");
};

/*
    The data model: sort descriptors and array controllers (top-level objects)
    and entities (the <entities> section). [dataKey, attributeName, default]
*/
UIBModelSchema = {
    "sortDescriptor": {
        tag: "sortDescriptor",
        attributes: [["name", "id", ""], ["key", "key", ""], ["ascending", "ascending", YES], ["numeric", "numeric", NO]]
    },
    "arrayController": {
        tag: "arrayController",
        attributes: [["name", "id", ""], ["entity", "entity", ""], ["sortDescriptor", "sortDescriptor", ""], ["valueBinding", "valueBinding", ""],
                     ["autoFetch", "autoFetch", NO], ["autoFetchSync", "autoFetchSync", NO]]
    },
    "entity": {
        tag: "entity",
        attributes: [["name", "id", ""], ["store", "store", "#CPOwner.store"]]
    }
};

var UIBModelCounter = 0;

UIBNewModelObject = function(aKind)
{
    var object = [CPConservativeDictionary dictionary],
        attributes = UIBModelSchema[aKind].attributes;

    [object setValue:aKind forKey:@"kind"];
    [object setValue:"model_" + (UIBModelCounter++) forKey:@"id"];
    [object setValue:{} forKey:@"extraAttributes"];
    [object setValue:[] forKey:@"markupKeys"];
    [object setValue:[] forKey:@"markupAttributeOrder"];

    for (var i = 0; i < attributes.length; i++)
        if (attributes[i][2] !== "")
            [object setValue:attributes[i][2] forKey:attributes[i][0]];

    if (aKind === "entity")
    {
        [object setValue:[] forKey:@"columns"];
        [object setValue:[] forKey:@"relationships"];
        [object setValue:[] forKey:@"rawChildren"];
    }

    return object;
};

// Columns and relationships are kept as their attributes (strings), in order.
UIBNewModelItem = function(someAttributes)
{
    var item = { attributes: {}, order: [] };
    for (var name in someAttributes)
        if (someAttributes.hasOwnProperty(name))
        {
            item.attributes[name] = someAttributes[name];
            item.order.push(name);
        }
    return item;
};

UIBCopyModelItem = function(anItem)
{
    return { attributes: JSON.parse(JSON.stringify(anItem.attributes)), order: anItem.order.slice() };
};

UIBModelItemMarkup = function(aTag, anItem)
{
    var names = anItem.order.slice();
    for (var name in anItem.attributes)
        if (anItem.attributes.hasOwnProperty(name) && names.indexOf(name) < 0)
            names.push(name);

    var parts = [];
    for (var i = 0; i < names.length; i++)
    {
        var value = anItem.attributes[names[i]];
        if (value !== nil && value !== undefined && value !== "")
            parts.push(names[i] + '="' + UIBXMLEscapeAttribute(value) + '"');
    }

    return "<" + aTag + (parts.length ? " " + parts.join(" ") : "") + "/>";
};


@implementation CappusanceCodec : CPObject
{
    id          _controller;

    // Import state
    JSObject    _elementsByIdentifier;
    JSObject    _modelByIdentifier;
    CPArray     _pendingConnections;

    // Writing style taken over from the imported document
    BOOL        _outletsUseHash;
}

- (id)initWithController:(id)aController
{
    self = [super init];
    if (self)
    {
        _controller = aController;
        _outletsUseHash = YES;
    }
    return self;
}

#pragma mark -
#pragma mark Defaults

// Builder defaults of a type: the view class defaults, overridden by the schema.
+ (JSObject)defaultsForType:(CPString)aType
{
    var viewClass = [[UIElementView classMap] objectForKey:aType] || UIElementView,
        result = {},
        defaults = [viewClass defaultValues];

    if (defaults)
    {
        if (defaults.isa && [defaults respondsToSelector:@selector(allKeys)])
        {
            var keys = [defaults allKeys];
            for (var i = 0; i < [keys count]; i++)
                result[keys[i]] = [defaults objectForKey:keys[i]];
        }
        else
        {
            for (var key in defaults)
                if (defaults.hasOwnProperty(key))
                    result[key] = defaults[key];
        }
    }

    var schemaDefaults = UIBSchemaForType(aType).defaults || {};
    for (var key in schemaDefaults)
        if (schemaDefaults.hasOwnProperty(key))
            result[key] = schemaDefaults[key];

    if (result.halign === undefined)
        result.halign = "min";
    if (result.valign === undefined)
        result.valign = "min";

    return result;
}

#pragma mark -
#pragma mark Import

- (id)_coerce:(CPString)aString forKey:(CPString)aKey defaults:(JSObject)defaults viewClass:(Class)viewClass
{
    var propertyType = [[viewClass propertyTypes] objectForKey:aKey],
        defaultValue = defaults[aKey];

    if (propertyType === UIBBoolean || typeof defaultValue === "boolean")
        return /^(yes|true|1)$/i.test(String(aString).trim());

    if (propertyType === UIBNumber || typeof defaultValue === "number" || UIBNumericKeys[aKey])
    {
        var number = parseFloat(aString);
        return isNaN(number) ? aString : number;
    }

    return aString;
}

- (CPString)_serializeNode:(id)aNode
{
    return (new XMLSerializer()).serializeToString(aNode);
}

- (CPString)_directTextOfNode:(id)aNode
{
    var text = "";
    for (var i = 0; i < aNode.childNodes.length; i++)
    {
        var child = aNode.childNodes[i];
        if (child.nodeType === 3 || child.nodeType === 4)
            text += child.nodeValue;
    }
    return text;
}

- (CPArray)_elementChildrenOfNode:(id)aNode
{
    var result = [];
    for (var i = 0; i < aNode.childNodes.length; i++)
        if (aNode.childNodes[i].nodeType === 1)
            result.push(aNode.childNodes[i]);
    return result;
}

- (void)_queueConnectionFrom:(id)source attribute:(CPString)attributeName value:(CPString)aValue
{
    _pendingConnections.push({ source: source, attribute: attributeName, value: aValue });
}

/*!
    Builds the data object for one markup element (and its subtree).
*/
- (id)_importNode:(id)aNode
{
    var tag = aNode.tagName,
        type = UIBTypeForTag(tag) || "custom",
        schema = UIBSchemaForType(type),
        viewClass = [[UIElementView classMap] objectForKey:type] || UIElementView,
        defaults = [CappusanceCodec defaultsForType:type],
        data = [_controller _newElementDataOfType:type],
        markupKeys = [],
        extras = {},
        order = [],
        attributeToKey = {},
        attributeMap = UIBAttributeMapForType(type);

    // Imported elements are built from the markup only.
    [data setValue:[] forKey:@"children"];
    [data setValue:YES forKey:@"isImported"];

    if (type === "custom" || tag !== schema.tags[0])
        [data setValue:tag forKey:@"markupTag"];

    for (var i = 0; i < attributeMap.length; i++)
        attributeToKey[attributeMap[i][1]] = attributeMap[i][0];

    // Attributes
    var actionValue = nil, targetValue = nil;

    for (var i = 0; i < aNode.attributes.length; i++)
    {
        var name = aNode.attributes[i].name,
            value = aNode.attributes[i].value;

        order.push(name);

        if (name === "id")
        {
            [data setValue:value forKey:@"identifier"];
            if (!_elementsByIdentifier[value])
                _elementsByIdentifier[value] = data;
        }
        else if (name === "action")
            actionValue = value;
        else if (name === "target")
            targetValue = value;
        else if (UIBInlineOutletAttributes[name] && String(value).charAt(0) === "#")
            [self _queueConnectionFrom:data attribute:name value:value];
        else if (attributeToKey[name])
        {
            var key = attributeToKey[name];
            [data setValue:[self _coerce:value forKey:key defaults:defaults viewClass:viewClass] forKey:key];
            markupKeys.push(key);
        }
        else
            extras[name] = value;
    }

    if (actionValue !== nil)
        _pendingConnections.push({ source: data, attribute: "action", value: targetValue, action: actionValue });
    else if (targetValue !== nil)
        [self _queueConnectionFrom:data attribute:"target" value:targetValue];

    // Text content
    if (schema.text)
    {
        var text = [self _directTextOfNode:aNode];
        if (text.replace(/\s/g, "").length > 0)
        {
            [data setValue:text forKey:schema.text];
            markupKeys.push(schema.text);
        }
        else
            [data setValue:"" forKey:schema.text];
    }

    // Children
    var childNodes = [self _elementChildrenOfNode:aNode];

    if (schema.items)
    {
        var titles = [], raw = [];
        for (var i = 0; i < childNodes.length; i++)
        {
            raw.push([self _serializeNode:childNodes[i]]);
            if (childNodes[i].tagName === schema.items.tag)
                titles.push(childNodes[i].getAttribute(schema.items.attribute) || childNodes[i].getAttribute("identifier") || "");
        }

        var signature = titles.join(", ");
        [data setValue:signature forKey:schema.items.key];
        if (raw.length)
        {
            [data setValue:raw forKey:@"rawChildren"];
            [data setValue:signature forKey:@"rawItemsSignature"];
        }
        markupKeys.push(schema.items.key);
    }
    else if (schema.content)
    {
        // Comments are kept with the element that follows them.
        var children = [],
            pendingComments = [];

        for (var i = 0; i < aNode.childNodes.length; i++)
        {
            var childNode = aNode.childNodes[i];

            if (childNode.nodeType === 8)
                pendingComments.push(childNode.nodeValue);
            else if (childNode.nodeType === 1)
            {
                var childData = [self _importNode:childNode];
                if (pendingComments.length)
                {
                    [childData setValue:pendingComments forKey:@"leadingComments"];
                    pendingComments = [];
                }
                children.push(childData);
            }
        }

        if (pendingComments.length)
            [data setValue:pendingComments forKey:@"trailingComments"];

        [self _attachImportedChildren:children toElement:data type:type];
    }
    else if (childNodes.length)
    {
        var raw = [];
        for (var i = 0; i < childNodes.length; i++)
            raw.push([self _serializeNode:childNodes[i]]);
        [data setValue:raw forKey:@"rawChildren"];
    }

    if (type === "custom")
    {
        var customText = [self _directTextOfNode:aNode];
        if (customText.replace(/\s/g, "").length > 0)
            extras["#text"] = customText;
    }

    // Layout attributes the markup did not specify fall back to the Renaissance-like defaults.
    if (markupKeys.indexOf("halign") < 0)
        [data setValue:defaults.halign forKey:@"halign"];
    if (markupKeys.indexOf("valign") < 0)
        [data setValue:defaults.valign forKey:@"valign"];

    [data setValue:extras forKey:@"extraAttributes"];
    [data setValue:markupKeys forKey:@"markupKeys"];
    [data setValue:order forKey:@"markupAttributeOrder"];

    return data;
}

- (void)_attachImportedChildren:(CPArray)children toElement:(id)data type:(CPString)type
{
    var list = [data valueForKey:@"children"];

    if (type === "window" || type === "scrollView" || type === "splitView")
    {
        var root;
        if (type === "window" && children.length === 1 && [children[0] valueForKey:@"type"] === "vbox")
        {
            root = children[0];
            [root setValue:YES forKey:@"isRootVBox"];
        }
        else
        {
            root = [_controller _newRootVBoxForContainer:data];
            [root setValue:YES forKey:@"syntheticRoot"];
            [root setValue:YES forKey:@"isImported"];
            [root setValue:[] forKey:@"markupKeys"];
            [root setValue:children forKey:@"children"];
            [root setValue:@"expand" forKey:@"halign"];
            [root setValue:@"expand" forKey:@"valign"];
        }

        list.push(root);
    }
    else
    {
        for (var i = 0; i < children.length; i++)
            list.push(children[i]);
    }
}

- (id)_resolveReference:(CPString)aReference owner:(id)ownerData
{
    if (aReference === nil || aReference === undefined || aReference === "")
        return { ref: "" };

    var name = String(aReference).replace(/^#/, "");

    if (name === UIBOwnerReference)
        return { element: ownerData };

    if (_elementsByIdentifier[name])
        return { element: _elementsByIdentifier[name] };

    return { ref: aReference };
}

- (id)_newConnectionFrom:(JSObject)source to:(JSObject)target outlet:(CPString)outlet action:(CPString)action
{
    var connection = [CPConservativeDictionary dictionary];

    if (source.element)
        [connection setValue:[source.element valueForKey:@"id"] forKey:@"sourceID"];
    else
        [connection setValue:source.ref forKey:@"sourceRef"];

    if (target.element)
        [connection setValue:[target.element valueForKey:@"id"] forKey:@"targetID"];
    else
        [connection setValue:target.ref forKey:@"targetRef"];

    if (outlet)
        [connection setValue:outlet forKey:@"outlet"];
    if (action)
        [connection setValue:action forKey:@"action"];

    return connection;
}

#pragma mark -
#pragma mark Data Model Import

- (id)_importModelNode:(id)aNode kind:(CPString)aKind
{
    var object = UIBNewModelObject(aKind),
        schema = UIBModelSchema[aKind],
        extras = {},
        order = [],
        markupKeys = [];

    for (var i = 0; i < aNode.attributes.length; i++)
    {
        var name = aNode.attributes[i].name,
            value = aNode.attributes[i].value,
            mapped = nil;

        order.push(name);

        for (var j = 0; j < schema.attributes.length; j++)
            if (schema.attributes[j][1] === name)
                mapped = schema.attributes[j];

        if (mapped)
        {
            [object setValue:(typeof mapped[2] === "boolean" ? /^(yes|true|1)$/i.test(value) : value) forKey:mapped[0]];
            markupKeys.push(mapped[0]);
        }
        else
            extras[name] = value;
    }

    [object setValue:extras forKey:@"extraAttributes"];
    [object setValue:order forKey:@"markupAttributeOrder"];
    [object setValue:markupKeys forKey:@"markupKeys"];

    if (aKind === "entity")
    {
        var columns = [], relationships = [], raw = [],
            children = [self _elementChildrenOfNode:aNode];

        for (var i = 0; i < children.length; i++)
        {
            var child = children[i],
                attributes = {};

            for (var j = 0; j < child.attributes.length; j++)
                attributes[child.attributes[j].name] = child.attributes[j].value;

            if (child.tagName === "column")
                columns.push(UIBNewModelItem(attributes));
            else if (child.tagName === "relationship")
                relationships.push(UIBNewModelItem(attributes));
            else
                raw.push([self _serializeNode:child]);
        }

        [object setValue:columns forKey:@"columns"];
        [object setValue:relationships forKey:@"relationships"];
        [object setValue:raw forKey:@"rawChildren"];
    }

    var identifier = [object valueForKey:@"name"];
    if (identifier && !_modelByIdentifier[identifier])
        _modelByIdentifier[identifier] = object;

    return object;
}

/*!
    Parses a Cappusance document.
    Returns { windows, order, connections, unknownConnectors, ownerActions, ownerOutlets }
    or { error }.
*/
- (JSObject)parseMarkup:(CPString)aString ownerData:(id)ownerData
{
    if (!aString || !String(aString).trim().length)
        return { error: "The markup is empty." };

    var xmlDoc = (new DOMParser()).parseFromString(String(aString).trim(), "application/xml"),
        parseError = xmlDoc.getElementsByTagName("parsererror");

    if (parseError.length > 0)
        return { error: parseError[0].textContent };

    if (!xmlDoc.documentElement || (xmlDoc.documentElement.tagName !== "gsmarkup" && xmlDoc.documentElement.tagName !== "cappusance"))
        return { error: "This is not a Cappusance/GSMarkup document (the root element must be <gsmarkup>)." };

    _elementsByIdentifier = {};
    _modelByIdentifier = {};
    _pendingConnections = [];

    var result = { windows: [], order: [], connections: [], unknownConnectors: [], ownerActions: [], ownerOutlets: [],
                   sortDescriptors: [], arrayControllers: [], entities: [], modelConnectors: [], hasModel: NO },
        objectsNode = xmlDoc.getElementsByTagName("objects")[0];

    if (objectsNode)
    {
        var nodes = [];
        for (var i = 0; i < objectsNode.childNodes.length; i++)
        {
            var node = objectsNode.childNodes[i];
            if (node.nodeType === 1)
                nodes.push(node);
            else if (node.nodeType === 8)
                result.order.push({ raw: "<!--" + node.nodeValue + "-->" });
        }

        for (var i = 0; i < nodes.length; i++)
        {
            var tag = nodes[i].tagName;

            if (tag === "window" || tag === "panel")
            {
                var windowData = [self _importNode:nodes[i]];
                result.windows.push(windowData);
                result.order.push({ element: windowData });
            }
            else if (tag === "sortDescriptor")
                result.sortDescriptors.push([self _importModelNode:nodes[i] kind:@"sortDescriptor"]);
            else if (tag === "arrayController")
                result.arrayControllers.push([self _importModelNode:nodes[i] kind:@"arrayController"]);
            else
                result.order.push({ raw: [self _serializeNode:nodes[i]] });
        }
    }

    var entitiesNode = xmlDoc.getElementsByTagName("entities")[0];
    if (entitiesNode)
    {
        var nodes = [self _elementChildrenOfNode:entitiesNode];
        for (var i = 0; i < nodes.length; i++)
            if (nodes[i].tagName === "entity")
                result.entities.push([self _importModelNode:nodes[i] kind:@"entity"]);
    }

    result.hasModel = result.sortDescriptors.length + result.arrayControllers.length + result.entities.length > 0;

    var addAction = function(name) { if (name && result.ownerActions.indexOf(name) < 0) result.ownerActions.push(name); },
        addOutlet = function(name) { if (name && result.ownerOutlets.indexOf(name) < 0) result.ownerOutlets.push(name); };

    // Inline connections
    for (var i = 0; i < _pendingConnections.length; i++)
    {
        var pending = _pendingConnections[i],
            source = { element: pending.source },
            target = [self _resolveReference:pending.value owner:ownerData];

        if (pending.attribute === "action")
        {
            result.connections.push([self _newConnectionFrom:source to:target outlet:@"target" action:pending.action]);
            if (target.element === ownerData)
                addAction(pending.action);
        }
        else
            result.connections.push([self _newConnectionFrom:source to:target outlet:pending.attribute action:nil]);
    }

    // <connectors>
    var connectorsNode = xmlDoc.getElementsByTagName("connectors")[0];
    if (connectorsNode)
    {
        var nodes = [self _elementChildrenOfNode:connectorsNode],
            withHash = 0,
            withoutHash = 0;

        // Write outlets the way the document does (source="CPOwner" or source="#CPOwner").
        for (var i = 0; i < nodes.length; i++)
            if (nodes[i].tagName === "outlet" && !_modelByIdentifier[String(nodes[i].getAttribute("target") || "").replace(/^#/, "")])
            {
                if (String(nodes[i].getAttribute("target") || "").charAt(0) === "#")
                    withHash++;
                else
                    withoutHash++;
            }

        if (withHash + withoutHash > 0)
            _outletsUseHash = withHash >= withoutHash;
        for (var i = 0; i < nodes.length; i++)
        {
            var node = nodes[i],
                tag = node.tagName,
                sourceName = String(node.getAttribute("source") || "").replace(/^#/, ""),
                targetName = String(node.getAttribute("target") || "").replace(/^#/, ""),
                sourceModel = _modelByIdentifier[sourceName],
                targetModel = _modelByIdentifier[targetName];

            // Connections into the data model: the owner's outlet to an array controller.
            if (sourceModel || targetModel)
            {
                var label = node.getAttribute("label") || node.getAttribute("key") || node.getAttribute("outlet");

                if (tag === "outlet" && sourceName === UIBOwnerReference && targetModel && [targetModel valueForKey:@"kind"] === "arrayController" && ![targetModel valueForKey:@"ownerOutlet"] && label)
                {
                    [targetModel setValue:label forKey:@"ownerOutlet"];
                    [targetModel setValue:i forKey:@"ownerOutletOrder"];
                }
                else
                    result.modelConnectors.push({ order: i, xml: [self _serializeNode:node] });
                continue;
            }

            var source = [self _resolveReference:node.getAttribute("source") owner:ownerData],
                target = [self _resolveReference:node.getAttribute("target") owner:ownerData];

            if (tag === "outlet")
            {
                var label = node.getAttribute("label") || node.getAttribute("key") || node.getAttribute("outlet");
                result.connections.push([self _newConnectionFrom:source to:target outlet:label action:nil]);
                if (source.element === ownerData)
                    addOutlet(label);
            }
            else if (tag === "control")
            {
                var action = node.getAttribute("action");
                result.connections.push([self _newConnectionFrom:source to:target outlet:@"target" action:action]);
                if (target.element === ownerData)
                    addAction(action);
            }
            else if (tag === "connector")
            {
                // Format written by earlier versions of the builder.
                result.connections.push([self _newConnectionFrom:source to:target outlet:node.getAttribute("outlet") action:node.getAttribute("action")]);
            }
            else
                result.unknownConnectors.push([self _serializeNode:node]);
        }
    }

    _pendingConnections = nil;
    _elementsByIdentifier = nil;
    _modelByIdentifier = nil;

    return result;
}

#pragma mark -
#pragma mark Export

- (CPString)_formatValue:(id)aValue forKey:(CPString)aKey defaults:(JSObject)defaults
{
    if (typeof aValue === "boolean" || typeof defaults[aKey] === "boolean")
        return aValue ? "YES" : "NO";

    if (typeof aValue === "number")
        return String(Math.round(aValue * 100) / 100);

    return String(aValue);
}

- (BOOL)_shouldExportKey:(CPString)aKey ofElement:(id)data schema:(JSObject)schema defaults:(JSObject)defaults
{
    var value = [data valueForKey:aKey],
        type = [data valueForKey:@"type"],
        isImportedElement = !![data valueForKey:@"isImported"];

    if (value === nil || value === undefined)
        return NO;

    // Windows created in the builder always carry title and size; x/y only if set.
    if (type === "window" && (aKey === "x" || aKey === "y"))
        return YES;

    if (type === "window" && !isImportedElement && (aKey === "width" || aKey === "height" || aKey === "value"))
        return YES;

    // Fixed-size spacers always carry their size.
    if (schema.fixedSizeKey === aKey)
    {
        var alignKey = (aKey === "width") ? @"halign" : @"valign";
        if (UIBAlignKind([data valueForKey:alignKey]) !== "expand")
            return YES;
    }

    var markupKeys = [data valueForKey:@"markupKeys"] || [];
    if (markupKeys.indexOf(aKey) >= 0)
        return YES;

    if ([data valueForKey:@"isImported"])
        return NO;

    if (aKey === "width" || aKey === "height")
        return NO;

    if ((schema.always || []).indexOf(aKey) >= 0)
        return value !== "";

    if (typeof defaults[aKey] === "boolean")
        return !!value !== defaults[aKey];

    return value != defaults[aKey];
}

- (CPString)_referenceForEndpoint:(id)aConnection prefix:(CPString)aPrefix identifiers:(JSObject)identifiers
{
    var elementID = [aConnection valueForKey:aPrefix + "ID"];

    if (elementID)
    {
        var element = [_controller elementWithID:elementID];
        if (!element)
            return nil;

        if ([element valueForKey:@"type"] === "owner")
            return "#" + UIBOwnerReference;

        return "#" + [self _identifierForElement:element identifiers:identifiers];
    }

    return [aConnection valueForKey:aPrefix + "Ref"];
}

// Elements that are referenced get an id attribute; one is created if needed.
- (CPString)_identifierForElement:(id)element identifiers:(JSObject)identifiers
{
    var identifier = [element valueForKey:@"identifier"];
    if (identifier)
        return identifier;

    var base = String([element valueForKey:@"markupTag"] || UIBSchemaForType([element valueForKey:@"type"]).tags[0] || "view").replace(/[^A-Za-z0-9_]/g, ""),
        counter = 1;

    while (identifiers[base + counter])
        counter++;

    identifier = base + counter;
    identifiers[identifier] = YES;

    UIBPerformWithoutUndo(function() { [element setValue:identifier forKey:@"identifier"]; });

    return identifier;
}

- (CPString)_itemsMarkupForElement:(id)data schema:(JSObject)schema indent:(CPString)indent
{
    var current = [data valueForKey:schema.items.key] || "",
        raw = [data valueForKey:@"rawChildren"];

    if (raw && raw.length && [data valueForKey:@"rawItemsSignature"] === current)
        return raw.map(function(line) { return indent + line; }).join("\n");

    var titles = UIBSplitList(current);
    return titles.map(function(title)
    {
        if (schema.items.tag === "tableColumn")
            return indent + '<tableColumn identifier="' + UIBXMLEscapeAttribute(title.replace(/\s+/g, "_")) + '" title="' + UIBXMLEscapeAttribute(title) + '"/>';

        return indent + '<' + schema.items.tag + ' ' + schema.items.attribute + '="' + UIBXMLEscapeAttribute(title) + '"/>';
    }).join("\n");
}

- (CPString)_markupForElement:(id)data level:(int)level inline:(JSObject)inlineAttributes identifiers:(JSObject)identifiers
{
    var type = [data valueForKey:@"type"];
    if (type === "owner")
        return nil;

    var schema = UIBSchemaForType(type),
        defaults = [CappusanceCodec defaultsForType:type],
        indent = new Array(level + 1).join("    "),
        tag = [data valueForKey:@"markupTag"] || schema.tags[0] || "view",
        attributes = {},
        names = [];

    var add = function(name, value)
    {
        if (value === nil || value === undefined)
            return;
        if (attributes[name] === undefined)
            names.push(name);
        attributes[name] = value;
    };

    if ([data valueForKey:@"identifier"])
        add("id", [data valueForKey:@"identifier"]);

    var isRoot = !![data valueForKey:@"isRootVBox"];

    var attributeMap = UIBAttributeMapForType(type),
        rootKeys = [data valueForKey:@"markupKeys"] || [];

    for (var i = 0; i < attributeMap.length; i++)
    {
        var key = attributeMap[i][0];

        // The root vbox of a window always fills it; only write what the markup had.
        if (isRoot ? rootKeys.indexOf(key) >= 0 : [self _shouldExportKey:key ofElement:data schema:schema defaults:defaults])
            add(attributeMap[i][1], [self _formatValue:[data valueForKey:key] forKey:key defaults:defaults]);
    }

    var extras = [data valueForKey:@"extraAttributes"] || {};
    for (var name in extras)
        if (extras.hasOwnProperty(name) && name !== "#text")
            add(name, extras[name]);

    var inlineForElement = inlineAttributes[[data valueForKey:@"id"]] || [];
    for (var i = 0; i < inlineForElement.length; i++)
        add(inlineForElement[i][0], inlineForElement[i][1]);

    // Keep the original attribute order where possible.
    var originalOrder = [data valueForKey:@"markupAttributeOrder"] || [];
    names.sort(function(a, b)
    {
        var ia = originalOrder.indexOf(a), ib = originalOrder.indexOf(b);
        if (a === "id" && ia < 0) ia = -2;
        if (b === "id" && ib < 0) ib = -2;
        if (ia < 0) ia = 10000 + names.indexOf(a);
        if (ib < 0) ib = 10000 + names.indexOf(b);
        return ia - ib;
    });

    var attributeString = names.map(function(name) { return " " + name + '="' + UIBXMLEscapeAttribute(attributes[name]) + '"'; }).join("");

    // Content
    var childIndent = indent + "    ",
        bodyLines = [],
        text = nil;

    if (schema.text)
    {
        var textValue = [data valueForKey:schema.text];
        if (textValue !== nil && textValue !== undefined && textValue !== "" && [self _shouldExportKey:schema.text ofElement:data schema:schema defaults:defaults])
            text = UIBXMLEscapeText(textValue);
    }

    if (extras["#text"])
        text = UIBXMLEscapeText(extras["#text"]);

    if (schema.items)
    {
        var itemsMarkup = [self _itemsMarkupForElement:data schema:schema indent:childIndent];
        if (itemsMarkup)
            bodyLines.push(itemsMarkup);
    }
    else if (schema.content)
    {
        var children = [self _exportedChildrenOfElement:data],
            childLevel = level + 1;

        if (schema.content === "tabItem" && children.length > 1)
        {
            // A tab view item holds exactly one view.
            bodyLines.push(childIndent + "<vbox>");
            childLevel++;
        }

        for (var i = 0; i < children.length; i++)
        {
            var childMarkup = [self _markupForElement:children[i] level:childLevel inline:inlineAttributes identifiers:identifiers];
            if (childMarkup)
                bodyLines.push(childMarkup);
        }

        if (schema.content === "tabItem" && children.length > 1)
            bodyLines.push(childIndent + "</vbox>");
    }
    else
    {
        var raw = [data valueForKey:@"rawChildren"];
        if (raw && raw.length)
            bodyLines.push(raw.map(function(line) { return childIndent + line; }).join("\n"));
    }

    var trailing = [data valueForKey:@"trailingComments"] || [];
    for (var i = 0; i < trailing.length; i++)
        bodyLines.push(childIndent + "<!--" + trailing[i] + "-->");

    var markup;
    if (bodyLines.length)
        markup = indent + "<" + tag + attributeString + ">" + (text || "") + "\n" + bodyLines.join("\n") + "\n" + indent + "</" + tag + ">";
    else if (text !== nil)
        markup = indent + "<" + tag + attributeString + ">" + text + "</" + tag + ">";
    else
        markup = indent + "<" + tag + attributeString + "/>";

    var leading = [data valueForKey:@"leadingComments"] || [];
    if (leading.length)
        markup = leading.map(function(comment) { return indent + "<!--" + comment + "-->"; }).join("\n") + "\n" + markup;

    return markup;
}

// The children written for an element: roots of windows/scroll/split views are unwrapped.
- (CPArray)_exportedChildrenOfElement:(id)data
{
    var type = [data valueForKey:@"type"],
        children = [data valueForKey:@"children"] || [];

    if (type === "window" || type === "scrollView" || type === "splitView")
    {
        var root = nil;
        for (var i = 0; i < children.length; i++)
            if ([children[i] valueForKey:@"isRootVBox"])
                root = children[i];

        if (!root)
            return children;

        if (type !== "window" || [root valueForKey:@"syntheticRoot"])
            return [root valueForKey:@"children"] || [];

        return [root];
    }

    return children;
}

/*!
    Writes the whole document. order is the import order of top-level objects
    ({element} or {raw}), so unknown top-level objects keep their place.
*/
- (CPString)exportDocumentWithWindows:(CPArray)windows order:(CPArray)order connections:(CPArray)connections unknownConnectors:(CPArray)unknownConnectors
{
    return [self exportDocumentWithWindows:windows order:order connections:connections unknownConnectors:unknownConnectors model:nil includeInterface:YES includeModel:NO];
}

/*!
    Writes the interface, the data model, or both. The data model alone is
    written in the layout of a separate model file (model.gsmarkup).
*/
- (CPString)exportDocumentWithWindows:(CPArray)windows order:(CPArray)order connections:(CPArray)connections unknownConnectors:(CPArray)unknownConnectors model:(JSObject)aModel includeInterface:(BOOL)includeInterface includeModel:(BOOL)includeModel
{
    if (!includeInterface)
        return [self exportDataModel:aModel standalone:YES];

    var identifiers = {},
        inlineAttributes = {},
        connectorLines = [],
        actionTaken = {};

    // Collect identifiers already in use.
    var collect = function(element)
    {
        if ([element valueForKey:@"identifier"])
            identifiers[[element valueForKey:@"identifier"]] = YES;
        var children = [element valueForKey:@"children"] || [];
        for (var i = 0; i < children.length; i++)
            collect(children[i]);
    };
    for (var i = 0; i < windows.length; i++)
        collect(windows[i]);

    // Connections: inline where Cappusance allows it, <outlet>/<control> otherwise.
    for (var i = 0; i < connections.length; i++)
    {
        var connection = connections[i],
            sourceID = [connection valueForKey:@"sourceID"],
            sourceElement = sourceID ? [_controller elementWithID:sourceID] : nil,
            isOwnerSource = sourceElement && [sourceElement valueForKey:@"type"] === "owner",
            outlet = [connection valueForKey:@"outlet"],
            action = [connection valueForKey:@"action"],
            targetRef = [self _referenceForEndpoint:connection prefix:@"target" identifiers:identifiers];

        if (sourceID && !sourceElement)
            continue; // dangling

        if (sourceElement && !isOwnerSource)
        {
            var list = inlineAttributes[sourceID] || (inlineAttributes[sourceID] = []);

            if (action && !actionTaken[sourceID])
            {
                actionTaken[sourceID] = YES;
                if (targetRef)
                    list.push(["target", targetRef]);
                list.push(["action", action]);
                continue;
            }

            if (!action && outlet && (UIBInlineOutletAttributes[outlet] || outlet === "target") && targetRef)
            {
                list.push([outlet, targetRef]);
                continue;
            }
        }

        var sourceRef = [self _referenceForEndpoint:connection prefix:@"source" identifiers:identifiers];
        if (!sourceRef || targetRef === nil)
            continue;

        if (!_outletsUseHash)
        {
            sourceRef = String(sourceRef).replace(/^#/, "");
            targetRef = String(targetRef).replace(/^#/, "");
        }

        if (action)
            connectorLines.push('        <control source="' + UIBXMLEscapeAttribute(sourceRef) + '" target="' + UIBXMLEscapeAttribute(targetRef) + '" action="' + UIBXMLEscapeAttribute(action) + '"/>');
        else if (outlet)
            connectorLines.push('        <outlet source="' + UIBXMLEscapeAttribute(sourceRef) + '" target="' + UIBXMLEscapeAttribute(targetRef) + '" label="' + UIBXMLEscapeAttribute(outlet) + '"/>');
    }

    for (var i = 0; i < unknownConnectors.length; i++)
        connectorLines.push("        " + unknownConnectors[i]);

    // Objects, in the original order; new windows at the end.
    var objectLines = [],
        written = [];

    for (var i = 0; i < order.length; i++)
    {
        var entry = order[i];
        if (entry.raw)
            objectLines.push("        " + entry.raw);
        else if (windows.indexOf(entry.element) >= 0)
        {
            objectLines.push([self _markupForElement:entry.element level:2 inline:inlineAttributes identifiers:identifiers]);
            written.push(entry.element);
        }
    }

    for (var i = 0; i < windows.length; i++)
        if (written.indexOf(windows[i]) < 0)
            objectLines.push([self _markupForElement:windows[i] level:2 inline:inlineAttributes identifiers:identifiers]);

    var entitiesLines = [];

    if (includeModel && aModel)
    {
        var modelObjects = [self _modelObjectLines:aModel indent:"        "];
        if (modelObjects.length)
            objectLines.unshift(modelObjects.join("\n"));

        entitiesLines = [self _entitiesLines:aModel.entities indent:"    "];
        connectorLines = [self _modelConnectorLines:aModel indent:"        "].concat(connectorLines);
    }

    var lines = [
        '<?xml version="1.0"?>',
        '<!DOCTYPE gsmarkup>',
        '<gsmarkup>',
        '',
        '    <objects>',
        objectLines.join("\n\n"),
        '    </objects>',
        ''
    ];

    if (entitiesLines.length)
        lines = lines.concat(entitiesLines, ['']);

    return lines.concat([
        '    <connectors>',
        connectorLines.join("\n"),
        '    </connectors>',
        '</gsmarkup>',
        ''
    ]).join("\n");
}

#pragma mark -
#pragma mark Data Model Export

- (CPString)_modelObjectMarkup:(id)anObject
{
    var kind = [anObject valueForKey:@"kind"],
        schema = UIBModelSchema[kind],
        attributes = {},
        names = [],
        markupKeys = [anObject valueForKey:@"markupKeys"] || [];

    var add = function(name, value)
    {
        if (attributes[name] === undefined)
            names.push(name);
        attributes[name] = value;
    };

    for (var i = 0; i < schema.attributes.length; i++)
    {
        var key = schema.attributes[i][0],
            attribute = schema.attributes[i][1],
            defaultValue = schema.attributes[i][2],
            value = [anObject valueForKey:key];

        if (value === nil || value === undefined || value === "")
            continue;

        if (typeof defaultValue === "boolean")
        {
            if (markupKeys.indexOf(key) >= 0 || !!value !== defaultValue)
                add(attribute, value ? "YES" : "NO");
        }
        else
            add(attribute, String(value));
    }

    var extras = [anObject valueForKey:@"extraAttributes"] || {};
    for (var name in extras)
        if (extras.hasOwnProperty(name))
            add(name, extras[name]);

    var order = [anObject valueForKey:@"markupAttributeOrder"] || [];
    names.sort(function(a, b)
    {
        var ia = order.indexOf(a), ib = order.indexOf(b);
        if (ia < 0) ia = 1000 + names.indexOf(a);
        if (ib < 0) ib = 1000 + names.indexOf(b);
        return ia - ib;
    });

    return "<" + schema.tag + names.map(function(n) { return " " + n + '="' + UIBXMLEscapeAttribute(attributes[n]) + '"'; }).join("") + (kind === "entity" ? ">" : "/>");
}

- (CPArray)_modelObjectLines:(JSObject)aModel indent:(CPString)indent
{
    var lines = [],
        sortDescriptors = aModel.sortDescriptors || [],
        controllers = aModel.arrayControllers || [];

    for (var i = 0; i < sortDescriptors.length; i++)
        lines.push(indent + [self _modelObjectMarkup:sortDescriptors[i]]);

    if (sortDescriptors.length && controllers.length)
        lines.push("");

    for (var i = 0; i < controllers.length; i++)
        lines.push(indent + [self _modelObjectMarkup:controllers[i]]);

    return lines;
}

- (CPArray)_entitiesLines:(CPArray)entities indent:(CPString)indent
{
    if (!entities || !entities.length)
        return [];

    var lines = [indent + "<entities>"],
        inner = indent + "    ",
        innermost = inner + "    ";

    for (var i = 0; i < entities.length; i++)
    {
        var entity = entities[i];
        lines.push(inner + [self _modelObjectMarkup:entity]);

        var columns = [entity valueForKey:@"columns"] || [];
        for (var j = 0; j < columns.length; j++)
            lines.push(innermost + UIBModelItemMarkup("column", columns[j]));

        var relationships = [entity valueForKey:@"relationships"] || [];
        if (relationships.length && columns.length)
            lines.push("");
        for (var j = 0; j < relationships.length; j++)
            lines.push(innermost + UIBModelItemMarkup("relationship", relationships[j]));

        var raw = [entity valueForKey:@"rawChildren"] || [];
        for (var j = 0; j < raw.length; j++)
            lines.push(innermost + raw[j]);

        lines.push(inner + "</entity>");
    }

    lines.push(indent + "</entities>");
    return lines;
}

// Owner outlets to array controllers (in their original order, new ones last).
- (CPArray)_modelConnectorLines:(JSObject)aModel indent:(CPString)indent
{
    var entries = [],
        controllers = aModel.arrayControllers || [];

    for (var i = 0; i < controllers.length; i++)
    {
        var outlet = [controllers[i] valueForKey:@"ownerOutlet"],
            name = [controllers[i] valueForKey:@"name"],
            order = [controllers[i] valueForKey:@"ownerOutletOrder"];

        if (outlet && name)
            entries.push({ order: (typeof order === "number") ? order : 100000 + i,
                           xml: '<outlet source="#CPOwner" target="' + UIBXMLEscapeAttribute(name) + '" label="' + UIBXMLEscapeAttribute(outlet) + '"/>' });
    }

    var raw = aModel.connectors || [];
    for (var i = 0; i < raw.length; i++)
        entries.push(typeof raw[i] === "string" ? { order: 200000 + i, xml: raw[i] } : raw[i]);

    entries.sort(function(a, b) { return a.order - b.order; });
    return entries.map(function(entry) { return indent + entry.xml; });
}

/*!
    The data model as its own document, laid out like a typical model.gsmarkup.
*/
- (CPString)exportDataModel:(JSObject)aModel standalone:(BOOL)standalone
{
    aModel = aModel || {};

    return [
        '<?xml version="1.0"?>',
        '<!DOCTYPE gsmarkup>',
        '<gsmarkup>',
        '',
        '    <objects>'
    ].concat([self _modelObjectLines:aModel indent:"        "], [
        '    </objects>',
        '',
        ''
    ], [self _entitiesLines:aModel.entities indent:""], [
        '',
        '<connectors>'
    ], [self _modelConnectorLines:aModel indent:"    "], [
        '</connectors>',
        '</gsmarkup>',
        ''
    ]).join("\n");
}

@end

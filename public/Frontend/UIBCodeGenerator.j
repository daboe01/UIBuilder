//
//  UIBCodeGenerator.j
//  Generates the Objective-J class of File's Owner (#CPOwner) from the
//  document: outlets, array controllers, bound properties and action stubs.
//  Can also merge the missing pieces into an existing class source.
//

@import <Foundation/CPObject.j>
@import "UIBuilderConstants.j"

var UIBOwnerClassesByType = {
    "window": "CPWindow", "vbox": "CPView", "hbox": "CPView", "hspace": "CPView", "vspace": "CPView",
    "box": "CPBox", "label": "CPTextField", "textField": "CPTextField", "searchField": "CPSearchField",
    "secureField": "CPSecureTextField", "comboBox": "CPComboBox", "textView": "CPTextView", "button": "CPButton",
    "checkBox": "CPButton", "slider": "CPSlider", "stepper": "CPStepper", "popUpButton": "CPPopUpButton",
    "datePicker": "CPDatePicker", "progresIndicator": "CPProgressIndicator", "imageView": "CPImageView",
    "scrollView": "CPScrollView", "tableView": "CPTableView", "splitView": "CPSplitView", "tabView": "CPTabView",
    "tabViewItem": "CPTabViewItem"
};

// Cappusance tags with a known Cappuccino class.
var UIBOwnerClassesByTag = {
    "panel": "CPPanel", "ButtonBar": "CPButtonBar", "buttonBar": "CPButtonBar", "collectionView": "CPCollectionView",
    "segmentedControl": "CPSegmentedControl", "levelIndicator": "CPLevelIndicator", "outlineView": "CPOutlineView",
    "matrix": "CPMatrix", "colorWell": "CPColorWell"
};

// The class an outlet to this element should be declared with.
UIBOwnerClassForElement = function(anElement)
{
    if (!anElement)
        return "id";

    var type = [anElement valueForKey:@"type"],
        tag = [anElement valueForKey:@"markupTag"];

    if (tag && UIBOwnerClassesByTag[tag])
        return UIBOwnerClassesByTag[tag];

    // Your own classes are written with a capital letter (PromptOutlineView, UploadDropButton).
    if (type === "custom")
        return (tag && /^[A-Z]/.test(tag)) ? tag : "CPView";

    if (tag && /^[A-Z]/.test(tag) && !/^CP/.test(tag))
        return tag;

    return UIBOwnerClassesByType[type] || "id";
};

// "CPButton “Save” #save_btn"
UIBDescribeElement = function(anElement)
{
    if (!anElement)
        return "?";

    var type = [anElement valueForKey:@"type"],
        tag = [anElement valueForKey:@"markupTag"] || (UIBSchemaForType(type).tags || [])[0] || type,
        identifier = [anElement valueForKey:@"identifier"],
        title = [anElement valueForKey:@"type"] === "checkBox" ? [anElement valueForKey:@"title"] : [anElement valueForKey:@"value"];

    var text = "<" + tag + ">";
    if (typeof title === "string" && title.trim().length)
        text += " “" + title.trim() + "”";
    if (identifier)
        text += " #" + identifier;
    return text;
};

/*!
    Collects what the owner class needs:
    { outlets: [{ name, type, note }], properties: [{ name, type, note }],
      actions: [{ selector, senders: [] }], delegations: [], dataSourceOf: [] }
*/
UIBCollectOwnerInterface = function(aController)
{
    var owner = [aController ownerElement],
        ownerID = owner ? [owner valueForKey:@"id"] : nil,
        result = { outlets: [], properties: [], actions: [], delegations: [], dataSourceOf: [] },
        names = {};

    var addOutlet = function(name, type, note)
    {
        if (!name || names[name])
            return;
        names[name] = YES;
        result.outlets.push({ name: name, type: type || "id", note: note || "" });
    };

    var addProperty = function(name, type, note)
    {
        if (!name || names[name] || !/^[A-Za-z_]\w*$/.test(name))
            return;
        names[name] = YES;
        result.properties.push({ name: name, type: type || "id", note: note || "" });
    };

    var actionsBySelector = {};
    var addAction = function(selector, sender)
    {
        selector = String(selector || "").trim();
        if (!selector)
            return;

        var action = actionsBySelector[selector];
        if (!action)
        {
            action = actionsBySelector[selector] = { selector: selector, senders: [] };
            result.actions.push(action);
        }
        if (sender && action.senders.indexOf(sender) < 0)
            action.senders.push(sender);
    };

    var connections = [aController allConnections],
        ownerActionSources = {};

    // 1. Connections
    for (var i = 0; i < connections.length; i++)
    {
        var connection = connections[i],
            sourceID = [connection valueForKey:@"sourceID"],
            targetID = [connection valueForKey:@"targetID"],
            targetRef = [connection valueForKey:@"targetRef"],
            outlet = [connection valueForKey:@"outlet"],
            action = [connection valueForKey:@"action"],
            source = sourceID ? [aController elementWithID:sourceID] : nil,
            target = targetID ? [aController elementWithID:targetID] : nil;

        if (sourceID && sourceID === ownerID && outlet && !action)
        {
            if (target)
                addOutlet(outlet, UIBOwnerClassForElement(target), UIBDescribeElement(target));
            else
                addOutlet(outlet, "id", (targetRef || "?") + " (not in this document)");
        }
        else if (action && targetID && targetID === ownerID)
        {
            addAction(action, UIBDescribeElement(source));
            ownerActionSources[sourceID] = YES;
        }
        else if (!action && outlet === "target" && targetID && targetID === ownerID)
        {
            // target="#CPOwner" with extra actions (plusButtonAction, doubleAction, …)
            ownerActionSources[sourceID] = YES;
        }
        else if (!action && outlet && targetID && targetID === ownerID && source)
        {
            if (outlet === "dataSource" && [source valueForKey:@"type"] === "tableView")
                result.dataSourceOf.push(UIBDescribeElement(source));
            result.delegations.push(outlet + " of " + UIBDescribeElement(source));
        }
    }

    // 2. Array controllers of the data model the owner has outlets to
    var controllers = [aController arrayControllers] || [];
    for (var i = 0; i < controllers.length; i++)
    {
        var ownerOutlet = [controllers[i] valueForKey:@"ownerOutlet"];
        if (ownerOutlet)
            addOutlet(ownerOutlet, "CPArrayController", "#" + [controllers[i] valueForKey:@"name"] + ", entity " + ([controllers[i] valueForKey:@"entity"] || "?"));
    }

    // 3. Outlets and actions declared on File's Owner but not connected
    if (owner)
    {
        UIBSplitList([owner valueForKey:@"outlets"]).forEach(function(name) { addOutlet(name, "id", "declared on File's Owner"); });
        UIBSplitList([owner valueForKey:@"actions"]).forEach(function(selector) { addAction(selector, nil); });
    }

    // 4. Attributes that refer to the owner: bindings (#CPOwner.searchTerm),
    //    targets (#CPOwner.listController), extra actions (doubleAction, plusButtonAction)
    var elements = [aController allElements] || [];
    for (var i = 0; i < elements.length; i++)
    {
        var element = elements[i],
            extras = [element valueForKey:@"extraAttributes"] || {},
            targetsOwner = ownerActionSources[[element valueForKey:@"id"]] || /^#?CPOwner$/.test(extras.target || "");

        for (var name in extras)
        {
            if (!extras.hasOwnProperty(name))
                continue;

            var value = String(extras[name]);

            if (/Action$/.test(name) && targetsOwner && /^[A-Za-z_][\w:]*$/.test(value))
                addAction(value, UIBDescribeElement(element) + " (" + name + ")");

            var match = /^#CPOwner\.([A-Za-z_]\w*)/.exec(value);
            if (match)
            {
                var first = match[1],
                    type = /Controller$/.test(first) ? "CPArrayController" : "id";
                addProperty(first, type, name + " of " + UIBDescribeElement(element));
            }
        }

        // Menu items and other preserved child markup: <popUpButtonItem target="#CPOwner" action="…"/>
        var raw = [element valueForKey:@"rawChildren"] || [];
        for (var j = 0; j < raw.length; j++)
        {
            var itemPattern = /<(\w+)\b([^>]*)>/g, itemMatch;
            while ((itemMatch = itemPattern.exec(raw[j])) !== null)
            {
                var attributes = itemMatch[2],
                    itemTarget = /\btarget="([^"]*)"/.exec(attributes),
                    itemAction = /\baction="([^"]*)"/.exec(attributes),
                    itemTitle = /\btitle="([^"]*)"/.exec(attributes);

                if (itemAction && itemTarget && /^#?CPOwner$/.test(itemTarget[1]))
                    addAction(itemAction[1], UIBDescribeElement(element) + (itemTitle ? " item “" + itemTitle[1] + "”" : ""));

                var bindingPattern = /\b(\w+)="#CPOwner\.([A-Za-z_]\w*)/g, bindingMatch;
                while ((bindingMatch = bindingPattern.exec(attributes)) !== null)
                    addProperty(bindingMatch[2], /Controller$/.test(bindingMatch[2]) ? "CPArrayController" : "id", bindingMatch[1] + " of " + UIBDescribeElement(element));
            }
        }
    }

    return result;
};

function UIBPad(aString, aLength)
{
    aString = String(aString);
    while (aString.length < aLength)
        aString += " ";
    return aString;
}

// "- (@action)save:(id)sender" or "- (@action)reloadData"
function UIBActionSignature(aSelector)
{
    var parts = aSelector.split(":");

    if (parts.length === 1)
        return "- (@action)" + aSelector;

    var pieces = [];
    for (var i = 0; i < parts.length - 1; i++)
        pieces.push(parts[i] + ":(id)" + (i === 0 ? "sender" : "argument" + i));

    return "- (@action)" + pieces.join(" ");
}

function UIBIvarLines(anInterface)
{
    var lines = [],
        width = 0;

    anInterface.outlets.concat(anInterface.properties).forEach(function(entry) { width = MAX(width, entry.type.length); });
    width = MIN(width + 1, 24);

    var outlets = anInterface.outlets.filter(function(o) { return o.type !== "CPArrayController" || o.note.indexOf("entity") < 0; }),
        controllers = anInterface.outlets.filter(function(o) { return o.type === "CPArrayController" && o.note.indexOf("entity") >= 0; });

    var nameWidth = 0;
    anInterface.outlets.concat(anInterface.properties).forEach(function(entry) { nameWidth = MAX(nameWidth, entry.name.length + 1); });
    nameWidth = MIN(nameWidth + 12, 44);

    if (outlets.length)
    {
        lines.push("    // Outlets (set by the markup)");
        outlets.forEach(function(o) { lines.push(UIBPad("    @outlet " + UIBPad(o.type, width) + " " + o.name + ";", nameWidth + width) + (o.note ? "  // " + o.note : "")); });
    }

    if (controllers.length)
    {
        if (lines.length) lines.push("");
        lines.push("    // Array controllers (data model)");
        controllers.forEach(function(o) { lines.push(UIBPad("    @outlet " + UIBPad(o.type, width) + " " + o.name + ";", nameWidth + width) + "  // " + o.note); });
    }

    if (anInterface.properties.length)
    {
        if (lines.length) lines.push("");
        lines.push("    // Properties used by bindings and targets (#CPOwner.…)");
        anInterface.properties.forEach(function(p) { lines.push(UIBPad("    " + UIBPad(p.type, width + 8) + " " + p.name + " @accessors;", nameWidth + width) + "  // " + p.note); });
    }

    return lines;
}

function UIBActionLines(anAction)
{
    var lines = [];
    if (anAction.senders.length)
        lines.push("// Sent by " + anAction.senders.slice(0, 4).join(", ") + (anAction.senders.length > 4 ? " and " + (anAction.senders.length - 4) + " more" : ""));
    lines.push(UIBActionSignature(anAction.selector));
    lines.push("{");
    lines.push("    CPLog.debug(\"" + anAction.selector + " from %@\", " + (anAction.selector.indexOf(":") >= 0 ? "sender" : "nil") + ");");
    lines.push("}");
    return lines;
}

function UIBDataSourceLines(anInterface)
{
    if (!anInterface.dataSourceOf.length)
        return [];

    return [
        "#pragma mark - Table data source (" + anInterface.dataSourceOf.join(", ") + ")",
        "",
        "- (int)numberOfRowsInTableView:(CPTableView)aTableView",
        "{",
        "    return 0;",
        "}",
        "",
        "- (id)tableView:(CPTableView)aTableView objectValueForTableColumn:(CPTableColumn)aTableColumn row:(int)aRow",
        "{",
        "    return nil;",
        "}",
        ""
    ];
}

/*!
    The complete source of a new owner class.
*/
UIBGenerateOwnerClass = function(anInterface, aClassName, aSuperclass)
{
    var className = aClassName || "AppController",
        superclass = aSuperclass || "CPObject",
        lines = [
            "/*",
            " * " + className + ".j",
            " * File's Owner (#CPOwner) of the interface markup.",
            " * Generated by EspressoUI Builder: outlets are set and actions are sent",
            " * by the markup loader; fill in the method bodies.",
            " */",
            "",
            "@import <Foundation/CPObject.j>",
            "@import <AppKit/AppKit.j>",
            "",
            "@implementation " + className + " : " + superclass,
            "{"
        ];

    lines = lines.concat(UIBIvarLines(anInterface));
    lines.push("}");
    lines.push("");

    if (anInterface.delegations.length)
    {
        lines.push("// This object is also: " + anInterface.delegations.join("; "));
        lines.push("");
    }

    if (anInterface.actions.length)
    {
        lines.push("#pragma mark - Actions");
        lines.push("");
        anInterface.actions.forEach(function(action)
        {
            lines = lines.concat(UIBActionLines(action));
            lines.push("");
        });
    }

    lines = lines.concat(UIBDataSourceLines(anInterface));
    lines.push("@end");
    lines.push("");

    return lines.join("\n");
};

/*!
    Adds missing outlets, properties and action methods to an existing class
    source. Returns { source, addedVariables, addedActions } or { error }.
*/
UIBMergeOwnerClass = function(aSource, anInterface)
{
    var source = String(aSource || ""),
        header = /@implementation\s+(\w+)(\s*:\s*\w+)?[^\n{]*\n?\s*\{/.exec(source);

    if (!header)
        return { error: "No “@implementation … {” with an instance variable block was found." };

    var blockStart = header.index + header[0].length,
        blockEnd = source.indexOf("}", blockStart);

    if (blockEnd < 0)
        return { error: "The instance variable block is not closed." };

    var ivarBlock = source.substring(blockStart, blockEnd),
        missing = {
            outlets: anInterface.outlets.filter(function(o) { return !new RegExp("\\b" + o.name + "\\b").test(ivarBlock); }),
            properties: anInterface.properties.filter(function(p) { return !new RegExp("\\b" + p.name + "\\b").test(ivarBlock); }),
            actions: [], delegations: [], dataSourceOf: []
        };

    var ivarLines = UIBIvarLines(missing),
        addedVariables = missing.outlets.concat(missing.properties).map(function(entry) { return entry.name; });

    if (ivarLines.length)
    {
        var insertion = "\n    // Added by EspressoUI Builder\n" + ivarLines.join("\n") + "\n";
        source = source.substring(0, blockEnd).replace(/\s*$/, "\n") + insertion + source.substring(blockEnd);
    }

    var addedActions = [],
        methodLines = [];

    anInterface.actions.forEach(function(action)
    {
        var firstPart = action.selector.split(":")[0],
            pattern = new RegExp("[-+]\\s*\\([^)]*\\)\\s*" + firstPart + "\\s*(:|\\{|$)", "m");

        if (!pattern.test(source))
        {
            addedActions.push(action.selector);
            methodLines = methodLines.concat(UIBActionLines(action), [""]);
        }
    });

    if (methodLines.length)
    {
        var endIndex = source.lastIndexOf("@end");
        if (endIndex < 0)
            return { error: "No “@end” was found." };

        source = source.substring(0, endIndex) + "#pragma mark - Actions added by EspressoUI Builder\n\n" + methodLines.join("\n") + source.substring(endIndex);
    }

    return { source: source, addedVariables: addedVariables, addedActions: addedActions };
};


// Entry points for the rest of the app.
@implementation UIBCodeGenerator : CPObject

+ (JSObject)ownerInterfaceForController:(id)aController
{
    return UIBCollectOwnerInterface(aController);
}

+ (CPString)ownerClassSourceForInterface:(JSObject)anInterface className:(CPString)aClassName superclass:(CPString)aSuperclass
{
    return UIBGenerateOwnerClass(anInterface, aClassName, aSuperclass);
}

+ (JSObject)mergeOwnerClassSource:(CPString)aSource withInterface:(JSObject)anInterface
{
    return UIBMergeOwnerClass(aSource, anInterface);
}

@end

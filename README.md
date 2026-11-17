
# EspressoUI Builder ☕️

**A visual interface builder for Cappuccino, written in Cappuccino.**
Design windows with Cappusance's box layout, wire up outlets and actions, define your data model, try the result with real Cappuccino views, and get clean Cappusance markup (`.gsmarkup`) plus the matching Objective-J controller class out of it.

<img width="1171" height="838" alt="Bildschirmfoto 2026-11-17 um 19 51 34" src="https://github.com/user-attachments/assets/88613bce-7f35-4c55-a840-9b0e929aeeaa" />

---

## Why

Cappusance (GSMarkup for Cappuccino) describes interfaces as nested `<vbox>`/`<hbox>` layouts with bindings and connections. That is great to read and to diff, but hard to *see*. EspressoUI gives you an Interface-Builder-style canvas for exactly that markup:

- **Markup in, markup out.** Paste an existing `gui.gsmarkup` and `model.gsmarkup`, edit them visually, and copy them back. Anything the builder does not model (custom tags, bindings, menus, comments) is preserved verbatim.
- **Layout first.** The canvas uses the same box layout rules as the running app (`halign`/`valign` with `min`, `center`, `max`, `expand`), so what you see is what Cappusance will lay out.
- **From design to code.** Run the design with native views, then generate the File's Owner class with its outlets and action stubs.
- **Pure Cappuccino.** No external UI libraries; the builder is itself a Cappuccino application.

## A typical workflow

1. **Import** your `gui.gsmarkup` and `model.gsmarkup` (or start from scratch).
2. **Design** on the canvas: drag elements from the library, arrange them in boxes, set properties in the inspector.
3. **Connect** controls to File's Owner by control-dragging, and bind them to array controllers from the data model.
4. **Run** to try the interface with real Cappuccino views; the run log shows which actions arrive at File's Owner.
5. **Save** the markup back into your project and **generate** (or update) the File's Owner class.

## Features

### Canvas
- Scrollable canvas for any number of windows, with selection, rubber-band multi-selection, moving and resizing.
- Drop elements into windows, boxes, tab views, split views and scroll views; rows are created automatically in vertical boxes.
- Drag inside a box to position an element: the builder inserts and adjusts `hspace`/`vspace` for you.
- Cut, copy, paste, duplicate, group in HBox/VBox, ungroup, reorder.
- **Unlimited undo/redo for everything**: creating, deleting, moving, resizing, property edits, connections and data model changes, with descriptive menu titles ("Undo Move", "Redo Paste").

### Element library
A searchable palette, grouped into:

| Group | Elements |
|---|---|
| Windows & containers | Window, Box, Tab View, Split View, Scroll View |
| Layout | VBox, HBox, HSpace, VSpace |
| Text | Label, Text Field, Search Field, Secure Field, Combo Box, Text View |
| Controls | Button, Check Box, Pop-Up Button, Slider, Stepper, Date Picker, Progress Indicator |
| Data & other | Table View, Image View, Custom (any tag) |

Unknown tags from imported markup (`ButtonBar`, `collectionView`, your own classes, …) appear as custom elements and are written back unchanged.

### Inspector
A HUD panel with four tabs:
- **Properties:** every attribute the builder understands, plus the markup `id`, and the element's **bindings** with suggestions from your data model (`#CPOwner.worklistController`, `….selection.name`, `….arrangedObjects.name`, `….selection.@count`).
- **Layout:** alignment and size; sizes can be fixed or left to the content, just like in the markup.
- **Attributes:** an editable table for all other attributes (`autosaveName`, `font`, …). Double-click a cell to edit it.
- **Connections:** list, add and remove target/action and outlet connections, including references outside the document such as `#CPOwner.someController`.

### Connections and File's Owner
`#CPOwner` is shown on the canvas as **File's Owner**. Control-drag between elements, or to and from the File's Owner, to create outlets and target/action connections. On export they are written inline (`target`/`action`, `delegate`, `dataSource`, `nextKeyView`) or as `<outlet>`/`<control>` connectors.

### Data model editor
**Data ▸ Data Model Editor** edits what usually lives in `model.gsmarkup`:
- **Entities** with columns (primary key, optimistic) and relationships (`toOne`/`toMany`, binding and target columns).
- **Array controllers** with entity, sort descriptor, master–detail `valueBinding`, `autoFetch`/`autoFetchSync` and the File's Owner outlet.
- **Sort descriptors.**

Click to select, double-click to edit a cell or toggle a ✓ column. One click creates an array controller for an entity, or inserts a ready-bound table (scroll view + table view with the entity's columns) into your interface. Renaming an entity or sort descriptor updates the array controllers that use it.

### Run
**File ▸ Run** builds real Cappuccino views from the design and shows them in windows inside the page:
- Every element has a native counterpart: `CPWindow`, `CPBox`, `CPTabView`, `CPSplitView`, `CPScrollView` + `CPTableView`, `CPTextField`, `CPSearchField`, `CPComboBox`, `CPPopUpButton`, `CPSlider`, `CPStepper`, `CPDatePicker`, `CPProgressIndicator`, `CPImageView`, …
- Boxes keep their layout when you resize a preview window.
- Imported Cappusance tags such as `ButtonBar`, `segmentedControl`, `levelIndicator` and `collectionView` become their Cappuccino classes; your own view classes are instantiated if they are loaded.
- Connections between elements are applied. Actions sent to File's Owner (or to references like `#CPOwner.listController`) go to a stand-in and appear in the **run log**, so you can check the wiring without your controller code.
- Windows with `visible="NO"` are created but not shown; actions such as `makeKeyAndOrderFront:` can still open them.

Bindings are not connected in the preview, as there is no data store behind it.

### File's Owner code
**File ▸ Generate File's Owner Code…** writes the Objective-J class of `#CPOwner`:
- `@outlet` instance variables, typed from the connected elements (`CPTableView`, `CPPopUpButton`, your own classes, …) and commented with what they point to.
- Outlets to the array controllers of the data model.
- `@accessors` properties for everything the markup binds to (`valueBinding="#CPOwner.selectedModel"` → `selectedModel`).
- One `- (@action)…:(id)sender` stub per action, collected from connections, menu items and attributes such as `doubleAction` and `plusButtonAction`, with a comment listing who sends it.
- Table data source stubs when File's Owner is a table's `dataSource`.

**Merge into Existing Class…** adds only what is missing to your current class source and leaves existing variables and methods alone.

### Import, export and autosave
- **Import** a GUI file, a model file, or a combined file. A model file replaces only the data model, so you can load `gui.gsmarkup` and `model.gsmarkup` one after the other.
- **Save** shows the markup fully selected (⌘C copies it) or downloads it, as interface only, data model only, or both in one file. The data model is included by default whenever there is one.
- The writer keeps the original attribute order, comments and outlet style, so re-exported files produce small, readable diffs.
- The current document is **autosaved in the browser** and restored on the next start.

### Localization
The UI is in English. All user-visible strings go through `CPLocalizedStringFromTable` (table `UIBuilder`); a template with every key is in `Resources/en.lproj/UIBuilder.strings`.

## Getting started

EspressoUI is a regular Cappuccino application in `public/Frontend`.

1. Make the Cappuccino frameworks available as `public/Frontend/Frameworks` (for example as a symlink created by `capp`).
2. Serve the `public` directory with any local web server and open `Frontend/index.html`.

> `public/Frontend/Frameworks` is usually a symlink; add it to `.gitignore` (without a trailing slash).

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| ⌘Z / ⇧⌘Z | Undo / Redo |
| ⌘X, ⌘C, ⌘V | Cut, Copy, Paste |
| ⌘D | Duplicate |
| ⌫ | Delete |
| ⌘A | Select All |
| ⌘G / ⇧⌘G | Group in HBox / Ungroup |
| ⌘[ / ⌘] | Move earlier / later in its box |
| Arrow keys (⇧ for 10 px) | Move selection |
| Esc | Cancel a drag, or clear the selection |
| ⌘L / ⌘S | Import / Save markup |
| ⌘R | Run |

## Project structure

| File | Purpose |
|---|---|
| `AppController.j` | Application setup, menus, import/export and code windows, Run, autosave |
| `UIBuilderController.j` | Document model, undo primitives, data model, bindings support |
| `CappusanceCodec.j` | Reading and writing Cappusance markup (round-trip safe) |
| `UICanvasView.j` | The canvas: selection, drag and drop, connections |
| `UIElementView.j` | Base class of all elements; box layout engine |
| `UI*View.j` | One class per element type |
| `UIBSkeletons.j` | The look of all elements on the canvas and of the palette icons |
| `UIBNativeElements.j` | Native Cappuccino views for **Run**, and the File's Owner stand-in |
| `UIBCodeGenerator.j` | Generating and merging the File's Owner class |
| `UIBPalette.j` | The element library |
| `InspectorController.j` | The inspector |
| `DataModelEditorController.j` | The data model editor |
| `UIBuilderConstants.j` | Shared constants, undo and localization helpers |

## Roadmap

### ✅ Foundation
- [x] Canvas with selection, rubber-band selection, move and resize
- [x] Drag and drop from the element library, containers and box layout
- [x] Undo/redo for every change
- [x] Cut, copy, paste, duplicate, group, ungroup

### ✅ Inspector
- [x] Properties, layout, attributes, connections and bindings
- [x] Live editing with immediate canvas updates
- [x] Fixed or content-driven sizes
- [ ] Dedicated editors for more element-specific properties (today many are edited as plain attributes)

### ✅ Persistence and data
- [x] Import and export Cappusance markup, round-trip safe
- [x] Separate or combined GUI and data model files
- [x] Data model editor (entities, array controllers, sort descriptors)
- [x] Bindings with suggestions from the data model
- [x] Connections to File's Owner
- [x] Autosave in the browser

### ✅ From design to code
- [x] Native counterparts for all elements in **Run**, with a run log for actions
- [x] Generate the File's Owner class (outlets, properties, action stubs) and merge it into existing code

### 🔜 Next
- [ ] Save to and open from project files on a server
- [ ] Bindings in **Run**, with sample data from the data model
- [ ] Delegate method stubs beyond the table data source
- [ ] German translation of the builder UI

## License

© 2025-2026 Daniel Boehringer. All rights reserved.

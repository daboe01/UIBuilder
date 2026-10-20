<img width="1328" height="834" alt="Bildschirmfoto 2026-10-20 um 19 10 06" src="https://github.com/user-attachments/assets/77daa818-e19e-44cd-a819-c36125ab49c9" />

# EspressoUI Builder ☕️

**A visual interface builder for Cappuccino, written in Cappuccino.**
Design windows with Cappusance's box layout, wire up outlets and actions, define your data model, and get clean Cappusance markup (`.gsmarkup`) out of it, the same markup you would write by hand.

---

## Why

Cappusance (GSMarkup for Cappuccino) describes interfaces as nested `<vbox>`/`<hbox>` layouts with bindings and connections. That is great to read and to diff, but hard to *see*. EspressoUI gives you an Interface-Builder-style canvas for exactly that markup:

- **Markup in, markup out.** Paste an existing `gui.gsmarkup` and `model.gsmarkup`, edit them visually, and copy them back. Anything the builder does not model (custom tags, bindings, menus, comments) is preserved verbatim.
- **Layout first.** The canvas uses the same box layout rules as the running app (`halign`/`valign` with `min`, `center`, `max`, `expand`), so what you see is what Cappusance will lay out.
- **Pure Cappuccino.** No external UI libraries; the builder is itself a Cappuccino application.

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
- **Properties:** every attribute the builder understands, plus the markup `id`.
- **Layout:** alignment and size; sizes can be fixed or left to the content, just like in the markup.
- **Attributes:** an editable table for all other attributes (bindings, `autosaveName`, …).
- **Connections:** list, add and remove target/action and outlet connections, including references outside the document such as `#CPOwner.someController`.
- **Bindings:** combo boxes that suggest key paths from your data model (`#CPOwner.worklistController`, `….selection.name`, `….arrangedObjects.name`, `….selection.@count`).

### Connections and File's Owner
`#CPOwner` is shown on the canvas as **File's Owner**. Control-drag between elements, or to and from the File's Owner, to create outlets and target/action connections. On export they are written inline (`target`/`action`, `delegate`, `dataSource`, `nextKeyView`) or as `<outlet>`/`<control>` connectors.

### Data model editor
Edit what usually lives in `model.gsmarkup`:
- **Entities** with columns (primary key, optimistic) and relationships (`toOne`/`toMany`, binding and target columns).
- **Array controllers** with entity, sort descriptor, master–detail `valueBinding`, `autoFetch`/`autoFetchSync` and the File's Owner outlet.
- **Sort descriptors.**

One click creates an array controller for an entity, or inserts a ready-bound table (scroll view + table view with the entity's columns) into your interface.

### Import, export and autosave
- **Import** a GUI file, a model file, or a combined file. A model file replaces only the data model, so you can load `gui.gsmarkup` and `model.gsmarkup` one after the other.
- **Save** shows the markup fully selected (⌘C copies it) or downloads it, as interface only, data model only, or both in one file.
- The writer keeps the original attribute order, comments and outlet style, so re-exported files produce small, readable diffs.
- The current document is **autosaved in the browser** and restored on the next start.

### Run
**File ▸ Run** builds real Cappuccino views from the design and opens them in native windows, with connections applied. This is a quick preview; not every element has a native counterpart yet.

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
| `AppController.j` | Application setup, menus, import/export windows, autosave |
| `UIBuilderController.j` | Document model, undo primitives, data model, bindings support |
| `CappusanceCodec.j` | Reading and writing Cappusance markup (round-trip safe) |
| `UICanvasView.j` | The canvas: selection, drag and drop, connections |
| `UIElementView.j` | Base class of all elements; box layout engine |
| `UI*View.j` | One class per element type |
| `UIBSkeletons.j` | The look of all elements on the canvas and of the palette icons |
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
- [x] Properties, layout, attributes and connections
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

### 🔜 Next
- [ ] Save to and open from project files on a server
- [x] Generate Objective-J outlet and action stubs for the File's Owner class
- [x] Native counterparts for all elements in **Run**
- [ ] German translation of the builder UI

## License

© 2025 Daniel Boehringer. All rights reserved.

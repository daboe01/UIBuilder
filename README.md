# EspressoUI Builder ☕️

> The Visual UI Builder for Cappusances's Powerful Auto-Layout System

## About The Project


**EspressoUI Builder** is a WYSIWYG interface builder, built *in* Cappuccino, *for* Cappuccino. Inspired by modern tools like Xcode's Interface Builder, Espresso provides a visual, drag-and-drop canvas to graphically construct your application's UI. Its primary focus is to give you a hands-on, intuitive way to harness the full power of Cappusances's auto-layout engine.

Our vision is to bridge the gap between visual design and clean, maintainable code, enabling you to build beautiful and responsive Cappuccino apps faster than ever before.

### Vision & Philosophy

EspressoUI is guided by a simple yet powerful philosophy:

*   **Native-Like Experience:** The builder itself should feel like a fluid, responsive desktop application, showcasing the power of the Cappuccino framework.
*   **Pure Cappuccino:** No external UI library dependencies. This project is a testament to what can be achieved with Cappuccino alone.
*   **Layout First:** Place the emphasis on building robust, responsive interfaces using a visual representation of Cappusance's layout primitives.

---

## 🚀 Current Features

EspressoUI is well underway, with a robust set of features that already streamline UI development.

*   **Full-Window Canvas:** A limitless, scrollable canvas for designing your application windows and views. Standard features like element selection, multi-selection (rubber-banding), and visual resizing are all implemented.

*   **Extensive Component Palette:** A floating palette provides a rich library of standard Cappuccino controls, neatly organized and ready to be dragged onto the canvas.
    *   **Containers:** `Window`, `Box`, `Scroll View`, `Split View`, `Table View`
    *   **Auto-Layout:** `HBox`, `VBox`, `HSpace`, `VSpace`
    *   **Text & Fields:** `Label`, `Text Field`, `Search Field`, `Secure Field`, `Text View`, `Combo Box`
    *   **Buttons & Controls:** `Button`, `Check Box`, `Pop Up Button`, `Stepper`, `Slider`, `Date Picker`
    *   **Visuals:** `Image View`, `Progress Indicator`

*   **Visual Auto-Layout Engine:** This is the core of EspressoUI.
    *   Drag and drop layout primitives like `HBox` and `VBox` onto the canvas to create horizontal or vertical stacks.
    *   Drop other UI elements *inside* these boxes to have them automatically arrange themselves according to the layout rules.
    *   Visually create flexible and rigid spacing to build complex, responsive designs that adapt gracefully.

*   **Contextual Inspector:** An inspector panel that displays the properties of the currently selected UI element(s).

*   **Live Application Preview:** With a single click ("Run"), EspressoUI will:
    1.  Instantiate real, native Cappuccino UI elements from your visual design.
    2.  Build the complete view hierarchy, correctly nesting views within their containers.
    3.  Connect targets and actions between elements.
    4.  Launch the final, interactive UI in a new window, exactly as a user would see it.

---

## 🎯 The Roadmap: A Bright Future

This is just the beginning. Our roadmap is focused on making Espresso an indispensable tool for every Cappuccino developer.

### ✔️ Phase 1: The Foundation (Complete)
- [x] Core drawing engine for skeleton UI elements.
- [x] Data model managed by `CPArrayController` for robust state management.
- [x] Canvas with selection, multi-selection, and rubber-banding.
- [x] Drag-and-drop instantiation from the component palette.
- [x] Visual manipulation (move, resize).
- [x] Container logic for dropping elements into parent views.
- [x] Visual support for the **Auto-Layout** engine (`HBox`, `VBox`, etc.).
- [x] **Advanced Undo/Redo:** Full undo stack support for all actions (creation, deletion, moves, property changes).


### ⚙️ Phase 2: The Inspector Deep-Dive (Mostly complete)
- [x] Context-aware **Property Inspector Panel** to view element properties.
- [x] **Live Property Editing:** Change an element's title, color, or state in the inspector and see it update instantly on the canvas.
- [x] **Geometry & Sizing:** Precise numeric input for an element's position and size.
- [ ] **Full support for all properties:** Currently only a few properties of a few views are implemented to demonstrate the concepts.

### 💾 Phase 3: Persistency (In progres)
- [X] **Data serialisation:** Save and load your visual UI designs from gsmarkup text.
- [ ] **Project Persistency:** Save and load your visual UI designs to and from a file (`.xib` or `.cib` equivalent).
- [ ] **Outlet & Action Generation:** Visually connect elements to "File's Owner" to automatically generate Objective-J outlet and action stubs in your controller files.

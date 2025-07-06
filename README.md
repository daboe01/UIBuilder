# EspressoUI Builder ☕️

> The WYSIWYG Interface Builder for the Modern Cappuccino Application.



## About The Project

Building rich, native-like user interfaces is at the heart of the Cappuccino framework. However, crafting complex layouts directly in Objective-J code can be a slow and iterative process. **Espresso UI Builder** is here to change that.

Born out of the desire for a modern, web-based equivalent of Xcode's Interface Builder, Espresso is a visual design tool built *in* Cappuccino, *for* Cappuccino. It allows developers and designers to drag, drop, and visually compose application interfaces in real-time, dramatically accelerating the development workflow.

Our vision is to provide a seamless bridge between visual design and clean, maintainable code, empowering you to build beautiful Cappuccino apps faster than ever before.

### Vision & Philosophy

EspressoUI is guided by a simple yet powerful philosophy:

*   **Native-Like Experience:** The builder itself should feel like a fluid, responsive desktop application, showcasing the power of the Cappuccino framework.
*   **Pure Cappuccino:** No external UI library dependencies. This project is a testament to what can be achieved with Cappuccino alone.

---

## Current Features

EspressoUI is in its exciting early stages, with a solid foundation already in place.

*   **Full-Window Canvas:** A limitless, scrollable canvas for designing your application windows.
*   **Floating Component Palette:** A simple, intuitive palette with symbols for common UI elements.
*   **Drag & Drop Instantiation:** Drag elements like windows, buttons, sliders, and text fields from the palette directly onto the canvas.
*   **Visual Manipulation:**
    *   Move elements freely around the canvas.
    *   Resize elements with intuitive "dimple" handles on selection.
*   **Container Logic:** Drag and drop elements into container views (like a `CPWindow`), with visual hints for valid drop targets.

---

## 🚀 The Roadmap: A Bright Future

This is just the beginning. Our roadmap is ambitious, aiming to make Espresso an indispensable tool for every Cappuccino developer.

### 🎯 Phase 1: The Foundation (Complete)
- [x] Core drawing engine for skeleton UI elements.
- [x] Data model managed by `CPArrayController`.
- [x] Canvas with selection, multi-selection, and rubber-banding.
- [x] Basic drag-and-drop from a component palette.
- [ ] Move, resize, and container-drop functionality.

### 🔬 Phase 2: The Inspector & Properties
- [ ] **Property Inspector Panel:** A context-aware panel to view and edit the properties of selected elements.
- [ ] **Live Property Editing:** Change an element's title, color, or state and see it update instantly on the canvas.
- [ ] **Geometry & Sizing:** Precise numeric input for an element's position (x, y) and size (width, height).
- [ ] **Binding Support:** Visually bind element properties (like a slider's value) to controller keys.

### ⚙️ Phase 3: Persistency & Integration
- [ ] **Outlet & Action Generation:** Visually connect elements to file's owner to automatically generate outlet and action stubs.
- [ ] **Live Preview Mode:** Toggle between design mode and a "live" interactive preview of your UI.
- [ ] **Persistency:** Database backend?

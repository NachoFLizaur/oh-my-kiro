---
name: frontend-ux
description: Frontend UI/UX patterns, accessibility guidelines, and responsive design. Load when working on user interfaces, frontend components, CSS/styling, accessibility, or user experience improvements.
---

# Frontend/UX Skill

Patterns and guidelines for building accessible, responsive, and performant user interfaces. Framework-agnostic where possible, with notes for React, Vue, and Svelte where patterns diverge.

---

## Component Design Patterns

### Composition Over Inheritance

Build UIs from small, focused components that compose together. Each component should have a single responsibility.

**Props design**:
- Keep prop interfaces narrow — pass only what the component needs
- Use children/slots for flexible content injection instead of deeply nested config objects
- Separate data props from behavior props (callbacks)
- Provide sensible defaults so components work with minimal configuration

**State management**:
- Keep state as close to where it's used as possible (colocation)
- Lift state up only when two sibling components need to share it
- Distinguish between UI state (open/closed, selected tab) and domain state (user data, API responses)
- UI state belongs in the component; domain state belongs in a store or context
- Avoid prop drilling beyond 2 levels — use context, stores, or composition instead

**Component boundaries**:
- If a component file exceeds ~200 lines, look for extraction opportunities
- If a component accepts more than 5-6 props, consider splitting it
- Container components handle data fetching and state; presentational components handle rendering
- Keep side effects (API calls, subscriptions) at the boundary, not deep in the tree

### Naming Conventions

- Components: `PascalCase` (`UserProfile`, `SearchBar`)
- Props/events: `camelCase` (`onClick`, `isDisabled`, `userName`)
- CSS classes: `kebab-case` or follow the project's chosen methodology
- Boolean props: prefix with `is`, `has`, `should`, `can` (`isOpen`, `hasError`)
- Event handlers: prefix with `on` for props, `handle` for internal functions (`onClick` prop, `handleClick` function)

---

## Accessibility (WCAG 2.1)

Accessibility is non-negotiable. Every UI component must be usable by people with disabilities.

### Semantic HTML First

Use the correct HTML element before reaching for ARIA:

| Need | Use | Not |
|------|-----|-----|
| Navigation | `<nav>` | `<div class="nav">` |
| Button action | `<button>` | `<div onClick>` or `<a href="#">` |
| Link to page | `<a href="...">` | `<button>` or `<span onClick>` |
| Form input label | `<label for="...">` | `<span>` next to input |
| Page sections | `<main>`, `<aside>`, `<header>`, `<footer>` | Generic `<div>` wrappers |
| Lists | `<ul>`, `<ol>` | `<div>` with visual bullets |
| Headings | `<h1>`-`<h6>` in order | `<div class="heading">` |
| Table data | `<table>`, `<th>`, `<td>` | `<div>` grid layouts for tabular data |

### ARIA Guidelines

ARIA supplements HTML semantics — it does not replace them.

**Rules of ARIA**:
1. If you can use a native HTML element with built-in semantics, do that instead
2. Do not change native semantics unless absolutely necessary
3. All interactive ARIA controls must be keyboard operable
4. Do not use `role="presentation"` or `aria-hidden="true"` on focusable elements
5. All interactive elements must have an accessible name

**Common ARIA patterns**:

```html
<!-- Accessible icon button -->
<button aria-label="Close dialog">
  <svg>...</svg>
</button>

<!-- Live region for dynamic content -->
<div aria-live="polite" aria-atomic="true">
  3 results found
</div>

<!-- Accessible loading state -->
<div aria-busy="true" aria-live="polite">
  Loading...
</div>

<!-- Accessible dialog -->
<div role="dialog" aria-modal="true" aria-labelledby="dialog-title">
  <h2 id="dialog-title">Confirm deletion</h2>
  ...
</div>

<!-- Accessible tabs -->
<div role="tablist" aria-label="Settings">
  <button role="tab" aria-selected="true" aria-controls="panel-1">General</button>
  <button role="tab" aria-selected="false" aria-controls="panel-2">Security</button>
</div>
<div role="tabpanel" id="panel-1">...</div>
```

### Keyboard Navigation

Every interactive element must be reachable and operable via keyboard:

| Key | Expected behavior |
|-----|-------------------|
| `Tab` | Move focus to next interactive element |
| `Shift+Tab` | Move focus to previous interactive element |
| `Enter`/`Space` | Activate buttons, select options |
| `Escape` | Close modals, dropdowns, popovers |
| `Arrow keys` | Navigate within composite widgets (tabs, menus, listboxes) |
| `Home`/`End` | Jump to first/last item in a list |

**Focus management**:
- Trap focus inside modals and dialogs (focus must not escape to background content)
- Return focus to the trigger element when a modal closes
- Use `tabindex="0"` to make non-interactive elements focusable when needed
- Use `tabindex="-1"` for programmatic focus (e.g., error messages, section headings)
- Never use `tabindex` values greater than 0
- Visible focus indicators are required — never remove `outline` without providing an alternative

### Color and Contrast

- **WCAG AA**: Minimum contrast ratio of 4.5:1 for normal text, 3:1 for large text (18px+ or 14px+ bold)
- **WCAG AAA**: 7:1 for normal text, 4.5:1 for large text
- Never convey information through color alone — pair with icons, text, or patterns
- Test with color blindness simulators (protanopia, deuteranopia, tritanopia)

### Screen Reader Considerations

- Provide `alt` text for all meaningful images; use `alt=""` for decorative images
- Use `aria-describedby` for supplementary descriptions
- Hide decorative or redundant content with `aria-hidden="true"` (only on non-focusable elements)
- Test with at least one screen reader (VoiceOver on macOS, NVDA on Windows)

---

## Responsive Design

### Mobile-First Approach

Write base styles for the smallest viewport, then layer on complexity for larger screens:

```css
/* Base: mobile */
.card {
  padding: 1rem;
  display: flex;
  flex-direction: column;
}

/* Tablet and up */
@media (min-width: 768px) {
  .card {
    flex-direction: row;
    padding: 1.5rem;
  }
}

/* Desktop and up */
@media (min-width: 1024px) {
  .card {
    max-width: 960px;
    margin: 0 auto;
  }
}
```

### Breakpoint Strategy

Use content-driven breakpoints rather than device-specific ones. Common reference points:

| Name | Width | Typical use |
|------|-------|-------------|
| `sm` | 640px | Large phones, landscape |
| `md` | 768px | Tablets |
| `lg` | 1024px | Small desktops, landscape tablets |
| `xl` | 1280px | Desktops |
| `2xl` | 1536px | Large desktops |

Adjust breakpoints to where your content actually breaks, not to match device catalogs.

### Fluid Layouts

- Use relative units (`rem`, `em`, `%`, `vw`, `vh`) over fixed `px` for sizing
- Use `clamp()` for fluid typography: `font-size: clamp(1rem, 2.5vw, 2rem);`
- Use CSS Grid and Flexbox for layout — avoid fixed-width containers
- Set `max-width` on content containers to maintain readable line lengths (45-75 characters)
- Use `min()` and `max()` for responsive spacing without media queries

### Touch Targets

- Minimum touch target size: 44x44px (WCAG) / 48x48px (Material Design recommendation)
- Provide adequate spacing between touch targets to prevent mis-taps
- Increase padding rather than element size where possible

---

## Performance

### Lazy Loading

- Lazy-load images below the fold: `<img loading="lazy" ...>`
- Lazy-load routes/pages — load code for a page only when the user navigates to it
- Defer non-critical JavaScript with `<script defer>` or dynamic `import()`
- Use intersection observers for triggering animations or loading content on scroll

### Code Splitting

- Split by route — each page loads only its own code
- Split large dependencies — heavy libraries (chart libraries, editors) should be separate chunks
- Avoid splitting too aggressively — each chunk has HTTP overhead; aim for chunks between 20-100KB gzipped
- Preload critical chunks: `<link rel="preload" as="script" href="...">`

### Image Optimization

- Use modern formats: WebP or AVIF with fallbacks
- Provide responsive images with `srcset` and `sizes`:
  ```html
  <img
    src="photo-800.webp"
    srcset="photo-400.webp 400w, photo-800.webp 800w, photo-1200.webp 1200w"
    sizes="(max-width: 600px) 100vw, 800px"
    alt="Description"
    loading="lazy"
  />
  ```
- Set explicit `width` and `height` attributes to prevent layout shift
- Use CSS `aspect-ratio` for responsive media containers

### Rendering Performance

- Avoid layout thrashing — batch DOM reads and writes separately
- Use `transform` and `opacity` for animations (GPU-accelerated, avoid triggering layout)
- Debounce expensive event handlers (scroll, resize, input)
- Use `will-change` sparingly and only on elements that will actually animate
- Virtualize long lists (render only visible items) — critical for lists over ~100 items

### Core Web Vitals

Keep these metrics in mind during development:

| Metric | Target | What it measures |
|--------|--------|------------------|
| LCP (Largest Contentful Paint) | < 2.5s | Loading performance |
| INP (Interaction to Next Paint) | < 200ms | Responsiveness |
| CLS (Cumulative Layout Shift) | < 0.1 | Visual stability |

---

## CSS Patterns

### Methodology Options

Choose one methodology per project and apply it consistently:

**BEM (Block Element Modifier)**:
```css
.card { }
.card__title { }
.card__title--highlighted { }
```
Best for: traditional CSS, large teams, explicit naming.

**CSS Modules**:
```css
/* Card.module.css */
.title { }
.highlighted { }
```
Best for: component-scoped styles, avoiding global conflicts.

**Utility-First (Tailwind-style)**:
```html
<div class="flex items-center gap-4 p-4 rounded-lg shadow-md">
```
Best for: rapid prototyping, design system consistency, small teams.

### Layout Patterns

**CSS Grid for 2D layouts**:
```css
.dashboard {
  display: grid;
  grid-template-columns: 250px 1fr;
  grid-template-rows: auto 1fr auto;
  gap: 1rem;
  min-height: 100vh;
}
```

**Flexbox for 1D alignment**:
```css
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
}
```

### Design Tokens

Use CSS custom properties for consistent theming:

```css
:root {
  /* Spacing scale */
  --space-xs: 0.25rem;
  --space-sm: 0.5rem;
  --space-md: 1rem;
  --space-lg: 1.5rem;
  --space-xl: 2rem;

  /* Typography */
  --font-sans: system-ui, -apple-system, sans-serif;
  --font-mono: 'Fira Code', ui-monospace, monospace;
  --text-sm: 0.875rem;
  --text-base: 1rem;
  --text-lg: 1.125rem;

  /* Colors — semantic names, not visual */
  --color-surface: #ffffff;
  --color-text-primary: #1a1a1a;
  --color-text-secondary: #6b7280;
  --color-border: #e5e7eb;
  --color-accent: #2563eb;
  --color-error: #dc2626;
  --color-success: #16a34a;
}
```

### Dark Mode

Support dark mode via `prefers-color-scheme` and/or a manual toggle:

```css
@media (prefers-color-scheme: dark) {
  :root {
    --color-surface: #1a1a1a;
    --color-text-primary: #f3f4f6;
    --color-text-secondary: #9ca3af;
    --color-border: #374151;
  }
}
```

Store the user's preference in `localStorage` and apply a `data-theme` attribute for manual overrides.

---

## Form UX

### Validation

- Validate on blur for individual fields, on submit for the full form
- Show inline error messages directly below the field they relate to
- Use `aria-invalid="true"` and `aria-describedby` to link error messages to inputs:
  ```html
  <input id="email" aria-invalid="true" aria-describedby="email-error" />
  <span id="email-error" role="alert">Please enter a valid email address</span>
  ```
- Preserve user input on validation failure — never clear fields
- Disable the submit button only while a submission is in progress, not for validation

### Error Messages

- Be specific: "Email must include an @ symbol" not "Invalid input"
- Be constructive: tell the user how to fix it, not just what's wrong
- Use consistent placement and styling across all forms
- Announce errors to screen readers with `role="alert"` or `aria-live="assertive"`

### Progressive Disclosure

- Show only essential fields initially; reveal advanced options on demand
- Use multi-step forms (wizards) for complex flows — show progress and allow back-navigation
- Group related fields with `<fieldset>` and `<legend>`
- Provide smart defaults to reduce required input

### Input Patterns

- Use the correct `type` attribute: `email`, `tel`, `url`, `number`, `date`, `search`
- Set `inputmode` for mobile keyboards: `numeric`, `decimal`, `tel`, `email`, `url`
- Use `autocomplete` attributes for common fields: `name`, `email`, `address-line1`, `cc-number`
- Provide placeholder text as a hint, not as a label (placeholders disappear on focus)
- Mark required fields clearly — use both visual indicators and `aria-required="true"`

---

## Common UI Anti-Patterns

Avoid these patterns that degrade user experience:

### Layout and Visual

- **Layout shift on load**: Always reserve space for async content (images, ads, embeds) with explicit dimensions or `aspect-ratio`
- **Infinite scroll without escape**: Provide a way to reach the footer, use "Load more" buttons as an alternative, or implement virtual scrolling
- **Scroll hijacking**: Never override native scroll behavior for aesthetic reasons
- **Z-index wars**: Use a defined stacking context system (e.g., `--z-dropdown: 100`, `--z-modal: 200`, `--z-toast: 300`)

### Interaction

- **Disabled buttons without explanation**: If a button is disabled, explain why (tooltip or adjacent text)
- **Destructive actions without confirmation**: Always confirm irreversible actions (delete, overwrite)
- **Mystery icons**: Icon-only buttons must have `aria-label` and ideally a tooltip
- **Click targets too small**: Ensure all interactive elements meet minimum touch target sizes

### Feedback

- **Silent failures**: Always show feedback for user actions — success, error, or loading state
- **No loading states**: Show skeleton screens, spinners, or progress bars during async operations
- **Toast overload**: Don't stack multiple toasts; batch related notifications; auto-dismiss non-critical ones

### Data and Forms

- **Losing user input**: Warn before navigating away from unsaved changes (`beforeunload` event)
- **Pagination without URL state**: Reflect page, filters, and sort in the URL so users can share and bookmark
- **Resetting scroll position**: Preserve scroll position on back-navigation and after in-page updates

### Performance

- **Blocking the main thread**: Move heavy computation to Web Workers; never run synchronous loops over large datasets in the UI thread
- **Unoptimized re-renders**: Memoize expensive computations; avoid creating new objects/arrays in render functions
- **Loading everything upfront**: Lazy-load below-the-fold content, heavy libraries, and non-critical features

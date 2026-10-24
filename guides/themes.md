# Themes

LiveFlow includes a theme system with 36 built-in themes and support for custom
themes. Themes control the colors of the canvas background, nodes, edges, handles,
text, and all UI overlays.

## Built-In Themes

LiveFlow ships with 36 themes:

**12 hand-crafted themes** with fine-tuned colors:

`light`, `dark`, `ocean`, `forest`, `sunset`, `synthwave`, `nord`, `autumn`,
`cyberpunk`, `pastel`, `dracula`, `coffee`

**24 auto-generated themes** mapped from daisyUI color palettes:

`acid`, `black`, `luxury`, `retro`, `lofi`, `valentine`, `lemonade`, `garden`,
`aqua`, `corporate`, `bumblebee`, `silk`, `dim`, `abyss`, `night`, `caramellatte`,
`emerald`, `cupcake`, `cmyk`, `business`, `winter`, `halloween`, `fantasy`,
`wireframe`

## Setting a Theme

Pass the theme name in the `opts` map of the Flow component:

```elixir
<.live_component
  module={LiveFlow.Components.Flow}
  id="my-flow"
  flow={@flow}
  opts={%{theme: "dark"}}
/>
```

This renders the `data-lf-theme="dark"` attribute on the flow container, which
activates the corresponding CSS theme.

### Dynamic Theme Switching

Store the theme in an assign and let the user change it:

```elixir
@impl true
def mount(_params, _session, socket) do
  {:ok, assign(socket, flow: create_flow(), theme: nil)}
end

@impl true
def render(assigns) do
  ~H"""
  <div class="h-screen flex flex-col">
    <div class="p-4">
      <form phx-change="change_theme">
        <select name="theme" class="select select-sm">
          <option value="">Auto</option>
          <option :for={t <- ~w(light dark ocean forest synthwave dracula)} value={t}>
            {t}
          </option>
        </select>
      </form>
    </div>
    <div class="flex-1">
      <.live_component
        module={LiveFlow.Components.Flow}
        id="my-flow"
        flow={@flow}
        opts={%{theme: @theme}}
      />
    </div>
  </div>
  """
end

@impl true
def handle_event("change_theme", %{"theme" => ""}, socket) do
  {:noreply, assign(socket, theme: nil)}
end

def handle_event("change_theme", %{"theme" => theme}, socket) do
  {:noreply, assign(socket, theme: theme)}
end
```

When `theme` is `nil`, LiveFlow uses the default theme (light) or inherits from
the app-level dark mode via `[data-theme="dark"]`.

## Tailwind v4 Plugin Setup

LiveFlow provides a Tailwind CSS v4 plugin that registers themes using the
`@plugin` directive. This generates CSS custom properties scoped to each theme.

### Registering Themes

In your CSS file, import the themes you want (paths are relative to
`assets/css/app.css`):

```css
/* assets/css/app.css */
@import "../../deps/live_flow/assets/css/live_flow.css";

/* Register specific themes */
@plugin "../../deps/live_flow/assets/js/live_flow/liveflow-theme" { name: "light"; default: true; }
@plugin "../../deps/live_flow/assets/js/live_flow/liveflow-theme" { name: "dark"; prefersdark: true; }
@plugin "../../deps/live_flow/assets/js/live_flow/liveflow-theme" { name: "ocean"; }
@plugin "../../deps/live_flow/assets/js/live_flow/liveflow-theme" { name: "synthwave"; }
```

Only registered themes are generated, so register every theme you pass as `theme:`.

### Plugin Options

| Option | Description |
|--------|-------------|
| `name` | Theme name (required). Must match a built-in theme or define custom variables. |
| `default` | Set `true` to make this the default theme (uses low-specificity `:where()` selector). |
| `prefersdark` | Set `true` to also apply this theme to every flow under `@media (prefers-color-scheme: dark)`. |

### How It Works

The plugin generates scoped CSS like:

```css
/* default: true -- also usable by name */
:where(.lf-container), .lf-container[data-lf-theme="light"] {
  --lf-background: #f8f8f8;
  --lf-node-bg: #ffffff;
  /* ... */
}

/* Named theme */
.lf-container[data-lf-theme="dark"] {
  --lf-background: #1a1a1a;
  --lf-node-bg: #2d2d2d;
  /* ... */
}

/* prefersdark: true */
@media (prefers-color-scheme: dark) {
  .lf-container {
    --lf-background: #1a1a1a;
    /* ... */
  }
}
```

## CSS Custom Properties

LiveFlow themes are built on CSS custom properties. Every theme sets all of them;
the defaults live in `live_flow.css`.

### Canvas

| Variable | Description |
|----------|-------------|
| `--lf-background` | Canvas background color |
| `--lf-background-dots-color` | Dots pattern color (`background: :dots`) |
| `--lf-background-lines-color` | Lines pattern color (`background: :lines`) |
| `--lf-background-cross-color` | Cross pattern color (`background: :cross`) |

### Nodes

| Variable | Description |
|----------|-------------|
| `--lf-node-bg` | Node background color |
| `--lf-node-border` | Node border color |
| `--lf-node-border-radius` | Node border radius |
| `--lf-node-shadow` / `--lf-node-shadow-hover` | Node box shadow, and on hover |
| `--lf-node-selected-border` | Border color of selected nodes |
| `--lf-node-selected-shadow` | Ring around selected nodes |

### Edges

| Variable | Description |
|----------|-------------|
| `--lf-edge-stroke` | Edge color (default markers follow it) |
| `--lf-edge-stroke-width` | Edge width |
| `--lf-edge-stroke-selected` | Color of selected edges (and reconnect handles) |
| `--lf-edge-stroke-animated` | Color of animated edges |

### Handles

| Variable | Description |
|----------|-------------|
| `--lf-handle-size` | Handle diameter |
| `--lf-handle-bg` | Handle fill color |
| `--lf-handle-border` / `--lf-handle-border-width` | Handle border |
| `--lf-handle-hover-bg` | Handle fill on hover and while connecting |

### Text and Surfaces

| Variable | Description |
|----------|-------------|
| `--lf-text-primary` | Primary text color |
| `--lf-text-secondary` | Secondary text color |
| `--lf-text-muted` | Muted text color |
| `--lf-surface-secondary` | Secondary surface (panels, headers) |
| `--lf-border-secondary` | Secondary border color |

### UI Controls

| Variable | Description |
|----------|-------------|
| `--lf-controls-bg` / `--lf-controls-border` | Controls panel background and border |
| `--lf-controls-color` / `--lf-controls-button-hover` | Controls icon color and button hover background |
| `--lf-minimap-bg` / `--lf-minimap-border` | Minimap background and border |
| `--lf-minimap-node-bg` | Minimap node color (unless `minimap_node_color` is set) |
| `--lf-minimap-viewport-border` | Minimap viewport outline |
| `--lf-delete-hover-bg` / `--lf-delete-hover-color` / `--lf-delete-hover-border` | Delete buttons on hover |

### Interaction

| Variable | Description |
|----------|-------------|
| `--lf-selection-bg` | Selection box fill color |
| `--lf-selection-border` | Selection box border color |
| `--lf-helper-line-color` | Alignment guide line color (`helper_lines: true`) |

## Creating Custom Themes

### Method 1: Override via the Plugin

Pass custom variable values to the plugin. With a new name you get a new theme
(variables you don't set keep the `live_flow.css` defaults); with a built-in name
your values override that theme:

```css
@plugin "../../deps/live_flow/assets/js/live_flow/liveflow-theme" {
  name: "my-brand";
  --lf-background: #0a1929;
  --lf-node-bg: #0d2137;
  --lf-node-border: #1e3a5f;
  --lf-node-selected-border: #00bcd4;
  --lf-edge-stroke: #4fc3f7;
  --lf-text-primary: #e0e0e0;
}
```

### Method 2: Pure CSS

Define variables directly in CSS, scoped to the theme attribute:

```css
.lf-container[data-lf-theme="my-theme"] {
  --lf-background: #1a1a2e;
  --lf-node-bg: #16213e;
  --lf-node-border: #0f3460;
  --lf-node-selected-border: #e94560;
  --lf-node-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  --lf-node-border-radius: 12px;
  --lf-edge-stroke: #533483;
  --lf-edge-stroke-selected: #e94560;
  --lf-handle-bg: #e94560;
  --lf-handle-border: #0f3460;
  --lf-text-primary: #eaeaea;
  --lf-text-muted: #a0a0a0;
  --lf-background-dots-color: rgba(255, 255, 255, 0.08);
  --lf-controls-bg: #16213e;
  --lf-controls-border: #0f3460;
  --lf-minimap-bg: #16213e;
  --lf-selection-bg: rgba(233, 69, 96, 0.1);
  --lf-selection-border: #e94560;
}
```

Then use it:

```elixir
opts={%{theme: "my-theme"}}
```

## Dark Mode Integration

When no explicit LiveFlow theme is set (`theme: nil`), the flow uses the default
theme. LiveFlow provides automatic dark mode support that responds to your
application-level theme:

```css
/* Built into live_flow.css */
[data-theme="dark"] .lf-container:not([data-lf-theme]),
.dark .lf-container:not([data-lf-theme]) {
  --lf-background: #1a1a1a;
  --lf-node-bg: #2d2d2d;
  /* ... dark variables ... */
}
```

This means if your Phoenix app uses `data-theme="dark"` (common with daisyUI) or a
`dark` class on an ancestor such as `<html>`, flows without an explicit theme switch
to dark mode automatically.

You can also use the `prefersdark` plugin option to respond to the system-level
dark mode preference:

```css
@plugin "../../deps/live_flow/assets/js/live_flow/liveflow-theme" { name: "dark"; prefersdark: true; }
```

## Tips

- **Plugin vs CSS**: Use the Tailwind plugin for consistent integration with
  your build pipeline. Use pure CSS for quick prototyping or when not using Tailwind.
- **Specificity**: The plugin uses `:where(.lf-container)` for the default theme
  (low specificity) and `.lf-container[data-lf-theme="name"]` for named themes.
  Your custom CSS with the same or higher specificity will override.
- **CSS fallbacks**: LiveFlow's base stylesheet (`live_flow.css`) includes fallback
  values in `@layer base`. The plugin themes override these because `addBase()`
  outputs to `@layer base` with higher source order. The rest of the library CSS
  lives in `@layer components`, so your own unlayered CSS and Tailwind utilities
  override it without `!important`.
- **Custom nodes**: Use `var(--lf-text-primary)` and other variables in your custom
  node components for automatic theme support (see [Custom Nodes](custom-nodes.md)).

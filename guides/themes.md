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

In your CSS file, import the themes you want:

```css
/* assets/css/app.css */
@import "live_flow/live_flow.css";

/* Register specific themes */
@plugin "../js/live_flow/liveflow-theme" { name: "light"; default: true; }
@plugin "../js/live_flow/liveflow-theme" { name: "dark"; prefersdark: true; }
@plugin "../js/live_flow/liveflow-theme" { name: "ocean"; }
@plugin "../js/live_flow/liveflow-theme" { name: "synthwave"; }
```

### Plugin Options

| Option | Description |
|--------|-------------|
| `name` | Theme name (required). Must match a built-in theme or define custom variables. |
| `default` | Set `true` to make this the default theme (uses low-specificity `:where()` selector). |
| `prefersdark` | Set `true` to activate under `@media (prefers-color-scheme: dark)`. |

### How It Works

The plugin generates scoped CSS like:

```css
/* default: true */
:where(.lf-container) {
  --lf-background: #ffffff;
  --lf-node-bg: #ffffff;
  /* ... */
}

/* Named theme */
.lf-container[data-lf-theme="dark"] {
  --lf-background: #1a1a2e;
  --lf-node-bg: #16213e;
  /* ... */
}

/* prefersdark: true */
@media (prefers-color-scheme: dark) {
  .lf-container:not([data-lf-theme]) {
    --lf-background: #1a1a2e;
    /* ... */
  }
}
```

## CSS Custom Properties

LiveFlow themes are built on CSS custom properties. Here are the key variables:

### Canvas

| Variable | Description |
|----------|-------------|
| `--lf-background` | Canvas background color |
| `--lf-dots-color` | Background pattern dot/line color |

### Nodes

| Variable | Description |
|----------|-------------|
| `--lf-node-bg` | Node background color |
| `--lf-node-border` | Node border color |
| `--lf-node-border-selected` | Node border color when selected |
| `--lf-node-shadow` | Node box shadow |
| `--lf-node-border-radius` | Node border radius |

### Edges

| Variable | Description |
|----------|-------------|
| `--lf-edge-stroke` | Edge line color |
| `--lf-edge-stroke-selected` | Edge color when selected |
| `--lf-edge-label-bg` | Edge label background |
| `--lf-edge-label-color` | Edge label text color |

### Handles

| Variable | Description |
|----------|-------------|
| `--lf-handle-bg` | Handle fill color |
| `--lf-handle-border` | Handle border color |

### Text

| Variable | Description |
|----------|-------------|
| `--lf-text-primary` | Primary text color |
| `--lf-text-muted` | Secondary/muted text color |

### UI Controls

| Variable | Description |
|----------|-------------|
| `--lf-controls-bg` | Controls panel background |
| `--lf-controls-border` | Controls panel border |
| `--lf-minimap-bg` | Minimap background |
| `--lf-minimap-mask` | Minimap mask overlay color |

### Interaction

| Variable | Description |
|----------|-------------|
| `--lf-selection-bg` | Selection box fill color |
| `--lf-selection-border` | Selection box border color |
| `--lf-accent` | General accent/highlight color |
| `--lf-helper-line-color` | Alignment guide line color |

## Creating Custom Themes

### Method 1: Override via the Plugin

Pass custom variable values alongside a built-in theme name:

```css
@plugin "../js/live_flow/liveflow-theme" {
  name: "my-brand";
  --lf-background: #0a1929;
  --lf-node-bg: #0d2137;
  --lf-node-border: #1e3a5f;
  --lf-edge-stroke: #4fc3f7;
  --lf-text-primary: #e0e0e0;
  --lf-accent: #00bcd4;
}
```

### Method 2: Pure CSS

Define variables directly in CSS, scoped to the theme attribute:

```css
.lf-container[data-lf-theme="my-theme"] {
  --lf-background: #1a1a2e;
  --lf-node-bg: #16213e;
  --lf-node-border: #0f3460;
  --lf-node-border-selected: #e94560;
  --lf-node-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  --lf-node-border-radius: 12px;
  --lf-edge-stroke: #533483;
  --lf-edge-stroke-selected: #e94560;
  --lf-handle-bg: #e94560;
  --lf-handle-border: #0f3460;
  --lf-text-primary: #eaeaea;
  --lf-text-muted: #a0a0a0;
  --lf-dots-color: rgba(255, 255, 255, 0.08);
  --lf-controls-bg: #16213e;
  --lf-controls-border: #0f3460;
  --lf-minimap-bg: #16213e;
  --lf-selection-bg: rgba(233, 69, 96, 0.1);
  --lf-selection-border: #e94560;
  --lf-accent: #e94560;
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
/* App-level dark mode activates LiveFlow dark theme */
[data-theme="dark"] .lf-container:not([data-lf-theme]) {
  --lf-background: #1a1a2e;
  --lf-node-bg: #16213e;
  /* ... dark variables ... */
}
```

This means if your Phoenix app uses `data-theme="dark"` on the `<html>` or `<body>`
element (common with daisyUI), LiveFlow automatically switches to dark mode without
needing an explicit theme assignment.

You can also use the `prefersdark` plugin option to respond to the system-level
dark mode preference:

```css
@plugin "../js/live_flow/liveflow-theme" { name: "dark"; prefersdark: true; }
```

## Tips

- **Plugin vs CSS**: Use the Tailwind plugin for consistent integration with
  your build pipeline. Use pure CSS for quick prototyping or when not using Tailwind.
- **Specificity**: The plugin uses `:where(.lf-container)` for the default theme
  (low specificity) and `.lf-container[data-lf-theme="name"]` for named themes.
  Your custom CSS with the same or higher specificity will override.
- **CSS fallbacks**: LiveFlow's base stylesheet (`live_flow.css`) includes fallback
  values in `@layer base`. The plugin themes override these because `addBase()`
  outputs to `@layer base` with higher source order.
- **Custom nodes**: Use `var(--lf-text-primary)` and other variables in your custom
  node components for automatic theme support (see [Custom Nodes](custom-nodes.md)).

# Saving, Import & Export

A flow is plain Elixir data (`LiveFlow.State`), so you can save it anywhere. LiveFlow
adds a JSON serializer, file import/download helpers, image export in the browser
(SVG and PNG, pixel-perfect) and SVG rendering on the server.

## JSON

`LiveFlow.Serializer` converts a flow to JSON-compatible maps and back:

```elixir
json = LiveFlow.Serializer.to_json(flow)          # pretty-printed JSON string
{:ok, flow} = LiveFlow.Serializer.from_json(json) # or {:error, reason}

map = LiveFlow.Serializer.export(flow)            # map with string keys, for a jsonb column
{:ok, flow} = LiveFlow.Serializer.import(map)
```

The format is versioned (`"version" => 1`) and contains the nodes, the edges and the
viewport. What is kept:

- **Nodes**: id, type, position, data, handles, `parent_id`, `extent: :parent`, style,
  class, `z_index`, `hidden`, `draggable`, `connectable`, `selectable`, `deletable`,
  `resizable`, `drag_handle`, and `width`/`height` for resizable nodes (the others are
  measured again in the browser).
- **Edges**: id, source, target, handles, type, label, markers, style, animation and
  the other edge options, and data.
- **Viewport**: x, y, zoom.

Selection, dragging state and measurements are transient and not saved.

### Types After a Round Trip

JSON has no atoms, so a few values change shape when loaded back:

- `type` fields become atoms again only if the atom already exists (any node or edge
  type your code mentions does); unknown types fall back to `:default` / `:bezier`.
- Top-level keys of `data` become atoms when the atom exists, otherwise they stay
  strings. Nested map keys stay strings.
- Atom **values** are saved as strings: `data: %{color: :violet}` comes back as
  `%{color: "violet"}`.

Write renderers that accept both (or convert on load) if you store atoms in `data`.

### Saving to a Database

Store `LiveFlow.Serializer.export/1` in a `:map` field and load it with
`LiveFlow.Serializer.import/1`:

```elixir
def handle_event("save", _params, socket) do
  {:ok, _diagram} = Diagrams.update(socket.assigns.diagram, %{graph: Serializer.export(socket.assigns.flow)})
  {:noreply, put_flash(socket, :info, "Saved")}
end

def mount(%{"id" => id}, _session, socket) do
  diagram = Diagrams.get!(id)
  {:ok, flow} = Serializer.import(diagram.graph)
  {:ok, assign(socket, diagram: diagram, flow: flow)}
end
```

The showcase page `/examples/interaction/save-and-restore` keeps the JSON in
`localStorage` instead, through a colocated hook.

### Downloading and Importing Files

`setupDownloadHandler()` (called once in `app.js`) listens for `lf:download_file`
events and downloads their content:

```elixir
def handle_event("export_json", _params, socket) do
  {:noreply,
   push_event(socket, "lf:download_file", %{
     content: LiveFlow.Serializer.to_json(socket.assigns.flow),
     filename: "flow.json",
     type: "application/json"
   })}
end
```

`FileImportHook` reads a file picked in an `<input type="file">` and pushes its text as
`import_json`. Register it as `FileImport` in your `LiveSocket` hooks (see
[Getting Started](getting-started.md)):

```heex
<input id="flow-import" type="file" accept=".json" phx-hook="FileImport" />
```

```elixir
def handle_event("import_json", %{"content" => content}, socket) do
  case LiveFlow.Serializer.from_json(content) do
    {:ok, flow} ->
      send_update(LiveFlow.Components.Flow, id: "my-flow", fit_view: true)
      {:noreply, assign(socket, flow: flow)}

    {:error, reason} ->
      {:noreply, put_flash(socket, :error, "Import failed: #{reason}")}
  end
end
```

## SVG and PNG in the Browser

The browser export clones the rendered flow with its computed styles inlined, so the
image looks like the screen: Tailwind classes, theme variables, icons (CSS masks),
markers, edge labels and the background pattern included. The PNG rasterizes that
same SVG.

Trigger it from a button with `Phoenix.LiveView.JS.dispatch/2` (a download needs the
user's click, so this runs entirely in the browser):

```heex
<button phx-click={JS.dispatch("lf:export-svg", to: "#my-flow", detail: %{filename: "diagram.svg"})}>
  SVG
</button>
<button phx-click={JS.dispatch("lf:export-png", to: "#my-flow", detail: %{scale: 3, padding: 20})}>
  PNG
</button>
```

| `detail` key | Default | Description |
|--------------|---------|-------------|
| `filename` | `"flow.svg"` / `"flow.png"` | Name of the downloaded file |
| `padding` | `40` | Space around the content, in flow units |
| `scale` | `2` | PNG only: pixel ratio of the image |

From the server, push `lf:export_svg` / `lf:export_png` with the same keys (plus
`flow_id` when the page has several flows). Browsers may block a download that doesn't
follow a click, so prefer `JS.dispatch` for buttons.

### What Is Exported

The image covers every rendered node and the full extent of the edges, whatever the
current viewport. Editor chrome is left out: node delete buttons, resizers, edge
toolbars and buttons, reconnect handles, panels, controls and the minimap. Add
`data-lf-export-ignore` to exclude your own elements:

```heex
<span class="badge" data-lf-export-ignore>Draft</span>
```

Limitations:

- Web fonts and external images are not embedded: the SVG uses the font names, and
  images from other origins may be missing in the PNG.
- If the browser refuses to rasterize the styled SVG (a tainted canvas), the PNG
  falls back to a simpler rendering: boxes with labels, edges and markers.
- With `virtualization: true`, only rendered nodes are exported.

### From JavaScript

The functions behind the events are exported by `live_flow`:

```javascript
import {exportSVG, exportPNG, buildExportSvg} from "live_flow"

const container = document.getElementById("my-flow")
const svgString = exportSVG(container, {padding: 20})          // string, or null
const pngBlob = await exportPNG(container, 2, {padding: 20})   // Blob (scale, options)
const {svg, bounds} = buildExportSvg(container, {background: false}) // SVG element
```

`buildExportSvg` also accepts `scale` and `native: true` (plain SVG shapes instead of
the styled HTML clones).

## SVG on the Server

`LiveFlow.Export.to_svg/2` renders a flow as an SVG string in pure Elixir, without a
browser: useful for thumbnails, emails, PDFs or background jobs.

```elixir
svg = LiveFlow.Export.to_svg(flow, theme: :dark, padding: 24)
File.write!("flow.svg", svg)
```

| Option | Default | Description |
|--------|---------|-------------|
| `:padding` | `40` | Space around the content |
| `:theme` | `:light` | `:light`, `:dark`, or a map overriding `:background`, `:node_bg`, `:node_border`, `:text`, `:edge`, `:selected`, `:label_bg` |
| `:background` | `true` | Draw the background |
| `:font_family` | `"system-ui, sans-serif"` | Font of the labels |

Nodes are drawn as rounded boxes with their label (`data.label`, `data.title` or the
id); edges use the same path algorithms as the browser, with their markers (in the
edge color), labels and stroke width. Custom node content is not rendered: use the
browser export for pixel-perfect images. See `/examples/misc/server-side-image-creation`
in the showcase app.

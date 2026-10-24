# LiveFlow showcase

A Phoenix 1.8 / LiveView 1.2 app that demonstrates every feature of
[LiveFlow](../README.md). It uses the library from the parent directory
(`{:live_flow, path: ".."}`), so changes to the library are recompiled and
reloaded while the server runs.

## Running

```bash
mix setup        # deps, database (PostgreSQL) and assets
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000).

## Pages

| Path | What it shows |
|------|---------------|
| `/` | Overview and the list of changes synced from xyflow |
| `/examples` | Every React Flow example (including Pro) rebuilt with LiveFlow — registry in `lib/flow_example_web/examples.ex`, pages in `lib/flow_example_web/live/examples/` |
| `/playground` | Full editor: history, clipboard, ELK auto-layout, JSON/SVG/PNG export, import, themes |
| `/interaction` | Panning, selection, auto-pan, keyboard and connection options, toggled live |
| `/edges` | Edge types, `step_position`, border radius, markers, reconnection, floating edges |
| `/resizing` | `NodeResizer`, aspect ratio, max size, `node_extent`, resize start/end changes |
| `/custom-nodes` | Form fields in nodes, drag handles, typed handles, interactive nodes |
| `/large` | Thousands of nodes with server-side virtualization |

## How it is wired

- `assets/package.json` keeps esbuild from inheriting the library's
  `package.json` (`"type": "module"`), which turned vendored CommonJS files
  such as `topbar.js` into ES modules and broke the build.
- `config/config.exs` aliases `live_flow` to `../../assets/js/live_flow/index.js`
  (Hex users resolve it from `deps/live_flow` through `NODE_PATH`).
- `assets/css/app.css` imports the library stylesheet and the theme plugin
  from the parent directory.
- `config/dev.exs` adds `:live_flow` to `reloadable_apps` and
  `config/runtime.exs` watches `../lib` for live reload.
- `FlowExampleWeb.FlowEvents` implements the standard `lf:*` event handling
  shared by every page.
- Examples are registered in `FlowExampleWeb.Examples`; routes, navigation and
  the gallery are generated from it. Example pages use `Layouts.example` and
  can ship their own CSS with `<style :type={FlowExampleWeb.ColocatedCSS}>`.

### macOS 27 note

If `mix tailwind` exits with status 137 (`SIGKILL (Code Signature Invalid)`),
re-sign the downloaded binary:

```bash
codesign --force --sign - _build/tailwind-macos-arm64-*
```

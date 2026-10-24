defmodule LiveFlow.Components.Flow do
  @moduledoc """
  Main Flow LiveComponent for LiveFlow.

  This is the primary component that renders the entire flow diagram,
  including nodes, edges, background, and overlays.

  ## Usage

      <.live_component
        module={LiveFlow.Components.Flow}
        id="my-flow"
        flow={@flow}
        opts={%{minimap: true, controls: true}}
        node_types={%{custom: MyApp.CustomNode}}
      />

  ## Attributes

    * `:id` - Unique ID for the component (required)
    * `:flow` - `LiveFlow.State` struct (required)
    * `:opts` - Configuration options map
    * `:node_types` - Map of node type atoms to renderers (function component or LiveComponent module)
    * `:node_renderer` - Fallback function component for nodes not matched by `node_types`
    * `:on_nodes_change` - Callback for node changes
    * `:on_edges_change` - Callback for edge changes
    * `:on_connect` - Callback when connection is made
    * `:on_selection_change` - Callback for selection changes
    * `:class` - Extra CSS classes for the `.lf-container` element

  ## Panels

  The `:panel` slot renders your own UI inside the flow container (React
  Flow's `<Panel>`), positioned with `position` (`:top_left`, `:top_center`,
  `:top_right`, `:center_left`, `:center_right`, `:bottom_left`,
  `:bottom_center`, `:bottom_right`). Panels inherit the flow theme, don't
  start pans or zooms, and are left out of exports. Events inside them go to
  the parent LiveView.

      <.live_component module={LiveFlow.Components.Flow} id="flow" flow={@flow}>
        <:panel position={:top_right}>
          <button phx-click="add_node">Add node</button>
        </:panel>
      </.live_component>

  ## Options

  ### Viewport

    * `:min_zoom` / `:max_zoom` - Zoom limits (default: `0.1` / `4.0`)
    * `:pan_on_drag` - Pan by dragging the pane. `true` pans with the left and
      middle mouse buttons, a list selects the buttons (`[0, 1, 2]`), `false`
      disables it (default: `true`)
    * `:pan_on_scroll` - Scrolling pans instead of zooming (default: `false`)
    * `:pan_on_scroll_speed` - Pan speed for `pan_on_scroll` (default: `0.5`)
    * `:pan_on_scroll_mode` - `:free`, `:vertical` or `:horizontal` (default: `:free`)
    * `:zoom_on_scroll` - Zoom with the scroll wheel (default: `true`)
    * `:zoom_on_pinch` - Zoom with trackpad pinch / ctrl+wheel (default: `true`)
    * `:zoom_on_double_click` - Zoom in on pane double click, Shift zooms out (default: `true`)
    * `:prevent_scrolling` - Keep wheel events from scrolling the page (default: `true`)
    * `:pan_activation_key` - Hold to pan with the left button from anywhere,
      e.g. `"Space"` or `"Control"` (default: `"Space"`)
    * `:fit_view_on_init` - Fit view to content on mount (default: `false`)
    * `:fit_view_options` - `%{padding: 0.1, duration: 200, min_zoom: .., max_zoom: .., nodes: [ids], include_hidden_nodes: false}`

  ### Nodes & edges

    * `:nodes_draggable` / `:nodes_connectable` / `:elements_selectable` (default: `true`)
    * `:node_drag_threshold` - Pixels the pointer must move before a drag starts (default: `1`)
    * `:node_extent` - Constrain node drag/resize to `{{min_x, min_y}, {max_x, max_y}}` (default: `nil`)
    * `:snap_to_grid` / `:snap_grid` - Snap positions to a grid (default: `false` / `{15, 15}`)
    * `:elevate_nodes_on_select` - Render selected nodes on top (default: `true`)
    * `:elevate_edges_on_select` - Render selected edges on top (default: `true`)
    * `:z_index_mode` - `:basic` applies the elevation options, `:manual` only
      uses each element's `z_index` (default: `:basic`)

  ### Connections

    * `:connection_mode` - `:strict` only connects source to target handles,
      `:loose` also allows source to source (default: `:strict`)
    * `:connection_line_type` - Preview line path: `:bezier`, `:straight`,
      `:step` or `:smoothstep` (default: `:bezier`)
    * `:connection_radius` - Snap to the closest handle within this many pixels (default: `20`)
    * `:connect_on_click` - Click a handle, then another one, to connect them
      (handy on touch devices) (default: `true`)
    * `:multi_connection` - Dragging from a selected node draws a connection
      line from every selected node (default: `false`)
    * `:connection_line_style` - Inline style map for the connection preview
      line, e.g. `%{stroke: "#ff0072", "stroke-width": 3}` (default: `nil`)
    * `:connection_line_class` - Extra CSS class for the connection preview line

  ### Selection & keyboard

    * `:selection_on_drag` - Dragging the pane draws a selection box (default: `false`)
    * `:selection_mode` - `:partial` selects nodes touched by the box, `:full`
      only nodes fully inside (default: `:partial`)
    * `:selection_key` - Hold to draw a selection box (default: `"Shift"`)
    * `:multi_selection_key` - Hold to add/remove elements to/from the selection
      (default: `["Meta", "Control", "Shift"]`)
    * `:delete_key_code` - Key(s) deleting the selection (default: `["Backspace", "Delete"]`)
    * `:disable_keyboard_a11y` - Disable moving selected nodes with the arrow keys (default: `false`)

    Key options accept a key, a combination of any length (`"Meta+Shift+s"`),
    a list of them, or `nil` to disable the binding.

  ### Opt-in events

  These events are only pushed to the parent LiveView when enabled, so apps
  that don't handle them keep working.

    * `:context_menu` - Push `lf:node_context_menu`, `lf:edge_context_menu`
      and `lf:pane_context_menu` (`%{"id", "x", "y", "position"}`, `x`/`y`
      relative to the container) instead of the browser menu (default: `false`)
    * `:pane_click_events` - Push `lf:pane_click` (`%{"position"}`) when the
      pane is clicked without dragging (default: `false`)
    * `:connection_events` - Push `lf:connect_start` when a connection starts (default: `false`)

  Always available: `lf:drop` (`%{"data", "position"}`) when an element with
  `application/liveflow` drag data is dropped on the flow, and
  `lf:connect_cancel` (`%{"node_id", "handle_id", "handle_type", "position",
  "reason"}`) when a connection is released on the pane or an invalid handle.

  ### Auto-pan

    * `:auto_pan_on_node_drag` / `:auto_pan_on_connect` / `:auto_pan_on_selection` -
      Pan the viewport when dragging close to its edge (default: `true`)
    * `:auto_pan_speed` - Pixels per frame (default: `15`)

  ### Overlays

    * `:background` - Background pattern: `:dots`, `:lines`, `:cross` or `nil`
    * `:background_gap` - Pattern gap, number or `{x, y}` (default: `20`)
    * `:background_size` - Dot radius / cross size (default: `1`, cross: `6`)
    * `:background_offset` - Pattern offset, number or `{x, y}` (default: `0`)
    * `:background_line_width` - Line width for `:lines` and `:cross` (default: `1`)
    * `:minimap` - Show minimap (default: `false`)
    * `:minimap_pannable` - Click/drag the minimap to move the viewport (default: `false`)
    * `:minimap_zoomable` - Scroll over the minimap to zoom (default: `false`)
    * `:minimap_node_color` - Color of the minimap nodes: a CSS color or a
      function receiving the node and returning one (React Flow's `nodeColor`).
      Minimap nodes also carry `data-node-id` / `data-node-type` for CSS.
    * `:controls` - Show zoom controls (default: `false`)
    * `:theme` - LiveFlow theme name (default: nil, uses default theme or inherits from app)
    * `:cursors` - Enable built-in remote cursor rendering for collaboration (default: `false`)
    * `:helper_lines` - Show alignment guide lines when dragging nodes (default: `false`)
    * `:virtualization` - Server-side viewport culling for large flows (default: `false`)

  ## Fit view

  Push a fit view from the parent LiveView with `send_update/2`:

      send_update(LiveFlow.Components.Flow, id: "my-flow", fit_view: true)
      send_update(LiveFlow.Components.Flow, id: "my-flow", fit_view: %{nodes: ["a", "b"], padding: 0.2})

  Bounds are computed on the server (`LiveFlow.State.bounds/2`), so nodes
  culled by virtualization are included.
  """

  use Phoenix.LiveComponent

  alias Phoenix.LiveView.JS
  alias LiveFlow.{State, Viewport}
  alias LiveFlow.Components.{NodeWrapper, Edge, Marker}
  alias LiveFlow.Changes.{NodeChange, EdgeChange}
  alias LiveFlow.Viewport.Culling

  @default_opts %{
    pan_on_drag: true,
    pan_on_scroll: false,
    pan_on_scroll_speed: 0.5,
    pan_on_scroll_mode: :free,
    zoom_on_scroll: true,
    zoom_on_pinch: true,
    zoom_on_double_click: true,
    prevent_scrolling: true,
    pan_activation_key: "Space",
    min_zoom: 0.1,
    max_zoom: 4.0,
    snap_to_grid: false,
    snap_grid: {15, 15},
    fit_view_on_init: false,
    fit_view_options: %{},
    background: nil,
    background_gap: 20,
    background_size: nil,
    background_offset: 0,
    background_line_width: 1,
    minimap: false,
    minimap_pannable: false,
    minimap_zoomable: false,
    minimap_node_color: nil,
    controls: false,
    connect_on_click: true,
    multi_connection: false,
    connection_line_style: nil,
    connection_line_class: nil,
    context_menu: false,
    pane_click_events: false,
    connection_events: false,
    connection_mode: :strict,
    connection_line_type: :bezier,
    connection_radius: 20,
    nodes_draggable: true,
    nodes_connectable: true,
    elements_selectable: true,
    node_drag_threshold: 1,
    node_extent: nil,
    selection_on_drag: false,
    selection_mode: :partial,
    selection_key: "Shift",
    multi_selection_key: ["Meta", "Control", "Shift"],
    delete_key_code: ["Backspace", "Delete"],
    disable_keyboard_a11y: false,
    auto_pan_on_node_drag: true,
    auto_pan_on_connect: true,
    auto_pan_on_selection: true,
    auto_pan_speed: 15,
    elevate_nodes_on_select: true,
    elevate_edges_on_select: true,
    z_index_mode: :basic,
    theme: nil,
    cursors: false,
    helper_lines: false,
    virtualization: false
  }

  @impl true
  def mount(socket) do
    {:ok, assign(socket, container_width: nil, container_height: nil)}
  end

  @impl true
  def update(assigns, socket) do
    # Only recompute opts when :opts is explicitly passed (avoids resetting
    # to defaults on partial send_update calls)
    socket =
      socket
      |> assign(assigns)
      |> then(fn s ->
        if Map.has_key?(assigns, :opts) do
          assign(s, :opts, Map.merge(@default_opts, assigns.opts))
        else
          assign_new(s, :opts, fn -> @default_opts end)
        end
      end)
      |> assign_new(:class, fn -> nil end)
      |> assign_new(:panel, fn -> [] end)
      |> assign_new(:node_types, fn -> %{} end)
      |> assign_new(:node_renderer, fn -> nil end)
      |> assign_new(:edge_types, fn -> %{} end)
      |> assign_new(:edge_label_renderer, fn -> nil end)
      |> assign_new(:edge_toolbar, fn -> nil end)
      |> assign_new(:on_nodes_change, fn -> nil end)
      |> assign_new(:on_edges_change, fn -> nil end)
      |> assign_new(:on_connect, fn -> nil end)
      |> assign_new(:on_selection_change, fn -> nil end)

    # Handle fit_view: true | %{...} from send_update
    socket =
      case Map.get(assigns, :fit_view) do
        nil -> socket
        false -> socket
        true -> push_fit_view(socket, %{})
        options when is_map(options) -> push_fit_view(socket, options)
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    opts = assigns.opts
    flow = assigns.flow

    # Child nodes store relative positions: draw with absolute ones
    abs_nodes = State.absolute_nodes(flow)

    # Sort nodes by z-index for rendering order (parents before children)
    sorted_nodes = sort_nodes(abs_nodes, flow, opts)

    # Edges are only drawn when both nodes exist and are visible
    sorted_edges =
      flow.edges
      |> sort_edges(flow.selected_edges, opts)
      |> Enum.filter(&renderable_edge?(&1, abs_nodes))

    # Apply viewport culling if virtualization is enabled and flow is large enough
    # Skip culling for small flows (< 200 nodes) to avoid unnecessary overhead
    {sorted_nodes, sorted_edges} =
      if opts[:virtualization] && assigns.container_width && assigns.container_height &&
           map_size(flow.nodes) >= 200 do
        {visible_nodes, visible_ids} =
          Culling.cull_nodes(
            sorted_nodes,
            flow.viewport,
            assigns.container_width,
            assigns.container_height
          )

        visible_edges = Culling.cull_edges(sorted_edges, visible_ids)
        {visible_nodes, visible_edges}
      else
        {sorted_nodes, sorted_edges}
      end

    # Collect unique marker definitions from all edges
    markers = Marker.collect_markers(Map.values(flow.edges))

    assigns =
      assigns
      |> assign(:abs_nodes, abs_nodes)
      |> assign(:sorted_nodes, sorted_nodes)
      |> assign(:sorted_edges, sorted_edges)
      |> assign(:markers, markers)
      |> assign(:viewport_style, Viewport.transform_style(flow.viewport))
      |> assign(:background_config, background_config(opts))
      |> assign(:client_config, Jason.encode!(client_config(opts, flow.viewport)))

    ~H"""
    <div
      id={@id}
      class={["lf-container", @class]}
      tabindex="0"
      phx-hook="LiveFlow"
      phx-target={@myself}
      data-lf-theme={@opts[:theme]}
      data-config={@client_config}
    >
      <%!-- Helper lines overlay (phx-update=ignore so LV won't remove dynamic SVG) --%>
      <div
        :if={@opts.helper_lines}
        id={"#{@id}-helper-lines"}
        phx-update="ignore"
        data-helper-lines-container
        class="lf-helper-lines-overlay"
      >
      </div>

      <%!-- Background layer --%>
      <.background
        :if={@background_config}
        id={"#{@id}-background"}
        config={@background_config}
        viewport={@flow.viewport}
      />

      <%!-- Viewport transform wrapper --%>
      <div class="lf-viewport" style={"transform: #{@viewport_style}"}>
        <%!-- SVG edge layer --%>
        <svg class="lf-edges" data-edge-layer>
          <Marker.marker_defs markers={@markers} />

          <%!-- Render edges --%>
          <Edge.edge
            :for={edge <- @sorted_edges}
            edge={edge}
            source_node={@abs_nodes[edge.source]}
            target_node={@abs_nodes[edge.target]}
            edge_types={@edge_types}
            edge_label_renderer={@edge_label_renderer}
            edge_toolbar={@edge_toolbar}
          />
        </svg>

        <%!-- HTML node layer --%>
        <div class="lf-nodes" data-node-layer>
          <.live_component
            :for={{node, z} <- Enum.with_index(@sorted_nodes)}
            :if={not node.hidden}
            module={NodeWrapper}
            id={"lf-node-#{node.id}"}
            node={node}
            z={z}
            node_types={@node_types}
            node_renderer={@node_renderer}
          />
        </div>
      </div>

      <%!-- Client-side interaction UI: selection box, connection preview, shortcuts panel --%>
      <div
        id={"#{@id}-interaction"}
        class="lf-interaction-layer"
        phx-update="ignore"
        data-interaction-layer
      >
      </div>

      <%!-- Panels: app UI rendered inside the flow (React Flow's <Panel>) --%>
      <div
        :for={panel <- @panel}
        class={["lf-panel nopan nowheel", "lf-panel-#{panel[:position] || :top_left}", panel[:class]]}
        data-lf-export-ignore
      >
        {render_slot(panel)}
      </div>

      <%!-- Controls panel --%>
      <.controls :if={@opts.controls} target={@myself} flow_id={@id} />

      <%!-- Minimap --%>
      <.minimap
        :if={@opts.minimap}
        flow={@flow}
        nodes={@abs_nodes}
        container_width={@container_width}
        container_height={@container_height}
        pannable={@opts.minimap_pannable}
        node_color={@opts.minimap_node_color}
      />

      <%!-- Remote cursor overlay (collaboration) --%>
      <div
        :if={@opts[:cursors]}
        id={"#{@id}-cursors"}
        class="lf-cursor-overlay"
        phx-update="ignore"
      >
      </div>
    </div>
    """
  end

  # Event handlers

  @impl true
  def handle_event("lf:node_change", %{"changes" => changes}, socket) do
    flow = NodeChange.apply_changes(socket.assigns.flow, changes)

    notify_callback(socket.assigns.on_nodes_change, changes)

    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:edge_change", %{"changes" => changes}, socket) do
    flow = EdgeChange.apply_changes(socket.assigns.flow, changes)

    notify_callback(socket.assigns.on_edges_change, changes)

    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:viewport_change", params, socket) do
    flow = State.update_viewport(socket.assigns.flow, params)

    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:selection_change", %{"nodes" => node_ids, "edges" => edge_ids}, socket) do
    flow =
      socket.assigns.flow
      |> State.select_nodes(node_ids)

    flow =
      Enum.reduce(edge_ids, flow, fn id, acc ->
        State.select_edge(acc, id, multi: true)
      end)

    notify_callback(socket.assigns.on_selection_change, %{nodes: node_ids, edges: edge_ids})

    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:delete_selected", _params, socket) do
    flow = State.delete_selected(socket.assigns.flow)

    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:fit_view", _params, socket) do
    {:noreply, push_fit_view(socket, %{})}
  end

  @impl true
  def handle_event("lf:container_resize", %{"width" => w, "height" => h}, socket) do
    {:noreply, assign(socket, container_width: w, container_height: h)}
  end

  # Zoom buttons are handled client-side (JS.dispatch) so they always start
  # from the current client viewport; these remain for server-driven zooms.
  @impl true
  def handle_event("lf:zoom_in", _params, socket) do
    {:noreply, push_event(socket, "lf:zoom_in", %{duration: 200})}
  end

  @impl true
  def handle_event("lf:zoom_out", _params, socket) do
    {:noreply, push_event(socket, "lf:zoom_out", %{duration: 200})}
  end

  # Component functions

  attr :id, :string, required: true
  attr :config, :map, required: true
  attr :viewport, Viewport, required: true

  # SVG pattern background. Same math as xyflow's <Background /> (including
  # the 12.11.3 offset fix); the hook keeps it in sync during client-side
  # pan/zoom (see updateBackground in flow_hook.js).
  defp background(assigns) do
    %{config: config, viewport: %Viewport{x: x, y: y, zoom: zoom}} = assigns
    [gap_x, gap_y] = config.gap
    [offset_x, offset_y] = config.offset

    scaled_gap_x = if gap_x * zoom == 0, do: 1, else: gap_x * zoom
    scaled_gap_y = if gap_y * zoom == 0, do: 1, else: gap_y * zoom
    scaled_size = config.size * zoom

    {dim_x, dim_y} =
      if config.variant == :cross,
        do: {scaled_size, scaled_size},
        else: {scaled_gap_x, scaled_gap_y}

    assigns =
      assign(assigns,
        pattern_id: "#{assigns.id}-pattern",
        x: :math.fmod(x / 1, scaled_gap_x),
        y: :math.fmod(y / 1, scaled_gap_y),
        width: scaled_gap_x,
        height: scaled_gap_y,
        transform: "translate(-#{offset_x * zoom + dim_x / 2},-#{offset_y * zoom + dim_y / 2})",
        radius: scaled_size / 2,
        path: "M#{dim_x / 2} 0 V#{dim_y} M0 #{dim_y / 2} H#{dim_x}"
      )

    ~H"""
    <svg id={@id} class="lf-background" data-background={@config.variant}>
      <pattern
        id={@pattern_id}
        x={@x}
        y={@y}
        width={@width}
        height={@height}
        patternUnits="userSpaceOnUse"
        patternTransform={@transform}
      >
        <circle
          :if={@config.variant == :dots}
          cx={@radius}
          cy={@radius}
          r={@radius}
          class="lf-background-pattern dots"
        />
        <path
          :if={@config.variant != :dots}
          d={@path}
          stroke-width={@config.lineWidth}
          class={"lf-background-pattern #{@config.variant}"}
        />
      </pattern>
      <rect x="0" y="0" width="100%" height="100%" fill={"url(##{@pattern_id})"} />
    </svg>
    """
  end

  attr :target, :any, required: true
  attr :flow_id, :string, required: true

  defp controls(assigns) do
    ~H"""
    <div class="lf-controls nopan">
      <button
        type="button"
        class="lf-controls-button"
        phx-click={JS.dispatch("lf:zoom-in", to: "##{@flow_id}")}
        title="Zoom In"
        aria-label="Zoom in"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" /><line
            x1="11"
            y1="8"
            x2="11"
            y2="14"
          /><line x1="8" y1="11" x2="14" y2="11" />
        </svg>
      </button>
      <button
        type="button"
        class="lf-controls-button"
        phx-click={JS.dispatch("lf:zoom-out", to: "##{@flow_id}")}
        title="Zoom Out"
        aria-label="Zoom out"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" /><line
            x1="8"
            y1="11"
            x2="14"
            y2="11"
          />
        </svg>
      </button>
      <button
        type="button"
        class="lf-controls-button"
        phx-click="lf:fit_view"
        phx-target={@target}
        title="Fit View"
        aria-label="Fit view"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="M15 3h6v6M9 21H3v-6M21 3l-7 7M3 21l7-7" />
        </svg>
      </button>
    </div>
    """
  end

  # Inner minimap area (CSS size 200x150 minus padding)
  @minimap_width 180
  @minimap_height 130
  @minimap_padding 10

  attr :flow, State, required: true
  attr :nodes, :map, required: true
  attr :container_width, :any, default: nil
  attr :container_height, :any, default: nil
  attr :pannable, :boolean, default: false
  attr :node_color, :any, default: nil

  defp minimap(assigns) do
    %{flow: flow} = assigns
    vp = flow.viewport

    # Visible area of the flow, once the container size is known
    view_rect =
      if assigns.container_width && assigns.container_height do
        %{
          x: -vp.x / vp.zoom,
          y: -vp.y / vp.zoom,
          width: assigns.container_width / vp.zoom,
          height: assigns.container_height / vp.zoom
        }
      end

    # Hidden nodes are ignored; with no visible node the minimap shows the
    # viewport only instead of zooming out to the origin
    bounds = union_rects(State.bounds(flow), view_rect)

    {scale, offset_x, offset_y} =
      if bounds do
        scale =
          min(@minimap_width / max(bounds.width, 1), @minimap_height / max(bounds.height, 1))

        {scale,
         -bounds.x * scale + @minimap_padding + (@minimap_width - bounds.width * scale) / 2,
         -bounds.y * scale + @minimap_padding + (@minimap_height - bounds.height * scale) / 2}
      else
        {1, @minimap_padding, @minimap_padding}
      end

    viewport_style =
      if view_rect do
        "left: #{view_rect.x * scale + offset_x}px; top: #{view_rect.y * scale + offset_y}px; " <>
          "width: #{view_rect.width * scale}px; height: #{view_rect.height * scale}px"
      else
        "display: none"
      end

    assigns =
      assigns
      |> assign(:nodes, assigns.nodes |> Map.values() |> Enum.reject(& &1.hidden))
      |> assign(:scale, scale)
      |> assign(:offset_x, offset_x)
      |> assign(:offset_y, offset_y)
      |> assign(
        :nodes_style,
        "transform: translate(#{offset_x}px, #{offset_y}px) scale(#{scale})"
      )
      |> assign(:viewport_style, viewport_style)

    ~H"""
    <div
      class="lf-minimap nowheel"
      data-minimap
      data-pannable={@pannable && "true"}
      data-scale={@scale}
      data-offset-x={@offset_x}
      data-offset-y={@offset_y}
    >
      <div class="lf-minimap-nodes" style={@nodes_style}>
        <div
          :for={node <- @nodes}
          class="lf-minimap-node"
          data-node-id={node.id}
          data-node-type={node.type}
          data-selected={to_string(node.selected)}
          style={"left: #{node.position.x}px; top: #{node.position.y}px; width: #{node.width || 100}px; height: #{node.height || 40}px#{minimap_color(@node_color, node)}"}
        >
        </div>
      </div>
      <div class="lf-minimap-viewport" style={@viewport_style}></div>
    </div>
    """
  end

  # Private helpers

  defp minimap_color(nil, _node), do: ""
  defp minimap_color(fun, node) when is_function(fun, 1), do: color_style(fun.(node))
  defp minimap_color(color, _node), do: color_style(color)

  defp color_style(nil), do: ""
  defp color_style(color), do: "; background: #{color}"

  defp push_fit_view(socket, options) do
    options = Map.merge(socket.assigns.opts[:fit_view_options] || %{}, normalize_map(options))
    flow = socket.assigns.flow

    bounds =
      State.bounds(flow,
        nodes: options[:nodes],
        include_hidden: options[:include_hidden_nodes] || false
      )

    payload =
      %{
        flow_id: socket.assigns.id,
        padding: Map.get(options, :padding, 0.1),
        duration: Map.get(options, :duration, 200),
        bounds: bounds
      }
      |> put_present(:min_zoom, options[:min_zoom])
      |> put_present(:max_zoom, options[:max_zoom])

    if bounds, do: push_event(socket, "lf:fit_view", payload), else: socket
  end

  # Sorted by the effective z-index of every ancestor, from the root down:
  # parents render before their children, and elevating a selected/dragged
  # node elevates its whole subtree.
  defp sort_nodes(abs_nodes, %State{} = flow, opts) do
    elevate? = opts.z_index_mode != :manual and opts.elevate_nodes_on_select

    effective_z = fn node ->
      selected = if elevate? and MapSet.member?(flow.selected_nodes, node.id), do: 1000, else: 0
      dragging = if node.dragging, do: 2000, else: 0
      node.z_index + selected + dragging
    end

    abs_nodes
    |> Map.values()
    |> Enum.sort_by(fn node -> z_chain(flow.nodes, node, effective_z, [], 0) end)
  end

  defp z_chain(_nodes, node, effective_z, acc, depth) when depth > 100,
    do: [effective_z.(node) | acc]

  defp z_chain(nodes, node, effective_z, acc, depth) do
    acc = [effective_z.(node) | acc]

    case node.parent_id && Map.get(nodes, node.parent_id) do
      nil -> acc
      parent -> z_chain(nodes, parent, effective_z, acc, depth + 1)
    end
  end

  defp sort_edges(edges, selected_edges, opts) do
    elevate? = opts.z_index_mode != :manual and opts.elevate_edges_on_select

    edges
    |> Map.values()
    |> Enum.sort_by(fn edge ->
      selected = if elevate? and MapSet.member?(selected_edges, edge.id), do: 1000, else: 0
      edge.z_index + selected
    end)
  end

  # Edges pointing to missing or hidden nodes are not rendered (a missing
  # node used to crash the component)
  defp renderable_edge?(edge, nodes) do
    source = Map.get(nodes, edge.source)
    target = Map.get(nodes, edge.target)

    not edge.hidden and source != nil and target != nil and not source.hidden and
      not target.hidden
  end

  # Configuration consumed by the LiveFlow hook (data-config attribute).
  # Encoded as JSON so `false` values survive (HEEx drops false attributes).
  defp client_config(opts, %Viewport{} = viewport) do
    {grid_x, grid_y} = opts.snap_grid

    %{
      viewport: %{x: viewport.x, y: viewport.y, zoom: viewport.zoom},
      minZoom: opts.min_zoom,
      maxZoom: opts.max_zoom,
      panOnDrag: opts.pan_on_drag,
      panOnScroll: opts.pan_on_scroll,
      panOnScrollSpeed: opts.pan_on_scroll_speed,
      panOnScrollMode: opts.pan_on_scroll_mode,
      zoomOnScroll: opts.zoom_on_scroll,
      zoomOnPinch: opts.zoom_on_pinch,
      zoomOnDoubleClick: opts.zoom_on_double_click,
      preventScrolling: opts.prevent_scrolling,
      panActivationKey: opts.pan_activation_key,
      snapToGrid: opts.snap_to_grid,
      snapGrid: [grid_x, grid_y],
      nodesDraggable: opts.nodes_draggable,
      nodesConnectable: opts.nodes_connectable,
      elementsSelectable: opts.elements_selectable,
      nodeDragThreshold: opts.node_drag_threshold,
      nodeExtent: extent_to_list(opts.node_extent),
      selectionOnDrag: opts.selection_on_drag,
      selectionMode: opts.selection_mode,
      selectionKey: opts.selection_key,
      multiSelectionKey: opts.multi_selection_key,
      deleteKeyCode: opts.delete_key_code,
      disableKeyboardA11y: opts.disable_keyboard_a11y,
      autoPanOnNodeDrag: opts.auto_pan_on_node_drag,
      autoPanOnConnect: opts.auto_pan_on_connect,
      autoPanOnSelection: opts.auto_pan_on_selection,
      autoPanSpeed: opts.auto_pan_speed,
      connectionMode: opts.connection_mode,
      connectionLineType: opts.connection_line_type,
      connectionRadius: opts.connection_radius,
      fitViewOnInit: opts.fit_view_on_init,
      fitViewOptions: fit_view_client_options(opts.fit_view_options),
      cursors: opts.cursors,
      helperLines: opts.helper_lines,
      virtualization: opts.virtualization,
      background: background_config(opts),
      minimapPannable: opts.minimap_pannable,
      minimapZoomable: opts.minimap_zoomable,
      connectOnClick: opts.connect_on_click,
      multiConnection: opts.multi_connection,
      connectionLineStyle: style_string(opts.connection_line_style),
      connectionLineClass: opts.connection_line_class,
      contextMenu: opts.context_menu,
      paneClickEvents: opts.pane_click_events,
      connectionEvents: opts.connection_events
    }
  end

  defp style_string(nil), do: nil
  defp style_string(style) when is_binary(style), do: style

  defp style_string(style) when is_map(style) do
    Enum.map_join(style, "; ", fn {k, v} -> "#{k}: #{v}" end)
  end

  defp fit_view_client_options(options) do
    options = normalize_map(options)

    %{}
    |> put_present(:padding, options[:padding])
    |> put_present(:duration, options[:duration])
    |> put_present(:nodes, options[:nodes])
    |> put_present(:minZoom, options[:min_zoom])
    |> put_present(:maxZoom, options[:max_zoom])
  end

  defp background_config(%{background: variant} = opts) when variant in [:dots, :lines, :cross] do
    %{
      variant: variant,
      gap: to_pair(opts.background_gap),
      size: opts.background_size || if(variant == :cross, do: 6, else: 1),
      offset: to_pair(opts.background_offset),
      lineWidth: opts.background_line_width
    }
  end

  defp background_config(_opts), do: nil

  defp to_pair({x, y}), do: [x, y]
  defp to_pair([x, y]), do: [x, y]
  defp to_pair(value) when is_number(value), do: [value, value]

  defp extent_to_list(nil), do: nil
  defp extent_to_list({{x1, y1}, {x2, y2}}), do: [[x1, y1], [x2, y2]]
  defp extent_to_list([[_, _], [_, _]] = extent), do: extent

  defp union_rects(nil, nil), do: nil
  defp union_rects(a, nil), do: a
  defp union_rects(nil, b), do: b

  defp union_rects(a, b) do
    x = min(a.x, b.x)
    y = min(a.y, b.y)

    %{
      x: x,
      y: y,
      width: max(a.x + a.width, b.x + b.width) - x,
      height: max(a.y + a.height, b.y + b.height) - y
    }
  end

  defp normalize_map(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
      pair -> pair
    end)
  end

  defp normalize_map(_), do: %{}

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)

  defp notify_callback(nil, _data), do: :ok
  defp notify_callback(callback, data) when is_function(callback, 1), do: callback.(data)
  defp notify_callback(_callback, _data), do: :ok
end

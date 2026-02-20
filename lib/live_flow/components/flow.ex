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

  ## Options

    * `:pan_on_drag` - Enable panning by dragging canvas (default: true)
    * `:zoom_on_scroll` - Enable zooming with scroll wheel (default: true)
    * `:min_zoom` - Minimum zoom level (default: 0.1)
    * `:max_zoom` - Maximum zoom level (default: 4.0)
    * `:snap_to_grid` - Snap node positions to grid (default: false)
    * `:snap_grid` - Grid size {x, y} (default: {15, 15})
    * `:fit_view_on_init` - Fit view to content on mount (default: false)
    * `:background` - Background pattern (:dots, :lines, :cross, nil)
    * `:minimap` - Show minimap (default: false)
    * `:controls` - Show zoom controls (default: false)
    * `:theme` - LiveFlow theme name (default: nil, uses default theme or inherits from app)
    * `:cursors` - Enable built-in remote cursor rendering for collaboration (default: false)
    * `:helper_lines` - Show alignment guide lines when dragging nodes (default: false)
  """

  use Phoenix.LiveComponent

  alias LiveFlow.{State, Viewport}
  alias LiveFlow.Components.{NodeWrapper, Edge, Marker}
  alias LiveFlow.Changes.{NodeChange, EdgeChange}

  @default_opts %{
    pan_on_drag: true,
    zoom_on_scroll: true,
    min_zoom: 0.1,
    max_zoom: 4.0,
    snap_to_grid: false,
    snap_grid: {15, 15},
    fit_view_on_init: false,
    background: nil,
    minimap: false,
    controls: false,
    connection_mode: :loose,
    nodes_draggable: true,
    nodes_connectable: true,
    elements_selectable: true,
    delete_key_code: "Backspace",
    theme: nil,
    cursors: false,
    helper_lines: false
  }

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       connecting: nil,
       selection_box: nil
     )}
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
      |> assign_new(:node_types, fn -> %{} end)
      |> assign_new(:node_renderer, fn -> nil end)
      |> assign_new(:on_nodes_change, fn -> nil end)
      |> assign_new(:on_edges_change, fn -> nil end)
      |> assign_new(:on_connect, fn -> nil end)
      |> assign_new(:on_selection_change, fn -> nil end)

    # Handle fit_view: true from send_update
    socket =
      if Map.get(assigns, :fit_view) do
        push_event(socket, "lf:fit_view", %{padding: 0.1, duration: 200})
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    opts = assigns.opts
    flow = assigns.flow

    # Sort nodes by z-index for rendering order
    sorted_nodes = sort_nodes(flow.nodes, flow.selected_nodes)

    # Sort edges (selected edges on top)
    sorted_edges = sort_edges(flow.edges, flow.selected_edges)

    # Collect unique marker definitions from all edges
    markers = Marker.collect_markers(Map.values(flow.edges))

    assigns =
      assigns
      |> assign(:sorted_nodes, sorted_nodes)
      |> assign(:sorted_edges, sorted_edges)
      |> assign(:markers, markers)
      |> assign(:viewport_style, Viewport.transform_style(flow.viewport))
      |> assign(:snap_grid_x, elem(opts.snap_grid, 0))
      |> assign(:snap_grid_y, elem(opts.snap_grid, 1))

    ~H"""
    <div
      id={@id}
      class="lf-container"
      phx-hook="LiveFlow"
      phx-target={@myself}
      data-lf-theme={@opts[:theme]}
      data-cursors={@opts[:cursors]}
      data-min-zoom={@opts.min_zoom}
      data-max-zoom={@opts.max_zoom}
      data-pan-on-drag={@opts.pan_on_drag}
      data-zoom-on-scroll={@opts.zoom_on_scroll}
      data-snap-to-grid={@opts.snap_to_grid}
      data-snap-grid-x={@snap_grid_x}
      data-snap-grid-y={@snap_grid_y}
      data-nodes-draggable={@opts.nodes_draggable}
      data-nodes-connectable={@opts.nodes_connectable}
      data-elements-selectable={@opts.elements_selectable}
      data-fit-view-on-init={@opts.fit_view_on_init}
      data-helper-lines={@opts.helper_lines}
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
      <.background :if={@opts.background} pattern={@opts.background} viewport={@flow.viewport} />

      <%!-- Viewport transform wrapper --%>
      <div class="lf-viewport" style={"transform: #{@viewport_style}"}>
        <%!-- SVG edge layer --%>
        <svg class="lf-edges" data-edge-layer>
          <Marker.marker_defs markers={@markers} />

          <%!-- Render edges --%>
          <Edge.edge
            :for={edge <- @sorted_edges}
            :if={not edge.hidden}
            edge={edge}
            source_node={@flow.nodes[edge.source]}
            target_node={@flow.nodes[edge.target]}
          />

          <%!-- Connection in progress --%>
          <Edge.connection_line
            :if={@connecting}
            from_x={@connecting.from_x}
            from_y={@connecting.from_y}
            to_x={@connecting.to_x}
            to_y={@connecting.to_y}
            from_position={@connecting.from_position}
          />
        </svg>

        <%!-- HTML node layer --%>
        <div class="lf-nodes" data-node-layer>
          <.live_component
            :for={node <- @sorted_nodes}
            :if={not node.hidden}
            module={NodeWrapper}
            id={"lf-node-#{node.id}"}
            node={node}
            node_types={@node_types}
            node_renderer={@node_renderer}
          />
        </div>
      </div>

      <%!-- Selection box overlay --%>
      <.selection_box :if={@selection_box} box={@selection_box} />

      <%!-- Controls panel --%>
      <.controls :if={@opts.controls} target={@myself} />

      <%!-- Minimap --%>
      <.minimap :if={@opts.minimap} flow={@flow} />

      <%!-- Remote cursor overlay (collaboration) --%>
      <div :if={@opts[:cursors]} id={"#{@id}-cursors"} class="lf-cursor-overlay" phx-update="ignore"></div>
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
  def handle_event("lf:connect_start", params, socket) do
    connecting = %{
      node_id: params["node_id"],
      handle_id: params["handle_id"],
      handle_type: params["handle_type"],
      from_x: params["from_x"] || 0,
      from_y: params["from_y"] || 0,
      to_x: params["to_x"] || 0,
      to_y: params["to_y"] || 0,
      from_position: String.to_atom(params["from_position"] || "right")
    }

    {:noreply, assign(socket, connecting: connecting)}
  end

  # Preview line is now drawn client-side in JS; this handler kept for compatibility
  @impl true
  def handle_event("lf:connect_move", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("lf:connect_end", _params, socket) do
    # Edge creation is handled by the parent LiveView.
    # This handler only clears the connecting state.
    {:noreply, assign(socket, connecting: nil)}
  end

  @impl true
  def handle_event("lf:connect_cancel", _params, socket) do
    {:noreply, assign(socket, connecting: nil)}
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
  def handle_event("lf:selection_box_start", params, socket) do
    box = %{
      start_x: params["x"],
      start_y: params["y"],
      x: params["x"],
      y: params["y"],
      width: 0,
      height: 0
    }

    {:noreply, assign(socket, selection_box: box)}
  end

  @impl true
  def handle_event("lf:selection_box_move", params, socket) do
    if socket.assigns.selection_box do
      box = socket.assigns.selection_box
      x = min(box.start_x, params["x"])
      y = min(box.start_y, params["y"])
      width = abs(params["x"] - box.start_x)
      height = abs(params["y"] - box.start_y)

      box = %{box | x: x, y: y, width: width, height: height}

      {:noreply, assign(socket, selection_box: box)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:selection_box_end", _params, socket) do
    {:noreply, assign(socket, selection_box: nil)}
  end

  @impl true
  def handle_event("lf:delete_selected", _params, socket) do
    flow = State.delete_selected(socket.assigns.flow)

    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:fit_view", _params, socket) do
    socket = push_event(socket, "lf:fit_view", %{padding: 0.1, duration: 200})
    {:noreply, socket}
  end

  @impl true
  def handle_event("lf:zoom_in", _params, socket) do
    socket =
      push_event(socket, "lf:zoom_to", %{
        zoom: socket.assigns.flow.viewport.zoom * 1.2,
        duration: 200
      })

    {:noreply, socket}
  end

  @impl true
  def handle_event("lf:zoom_out", _params, socket) do
    socket =
      push_event(socket, "lf:zoom_to", %{
        zoom: socket.assigns.flow.viewport.zoom / 1.2,
        duration: 200
      })

    {:noreply, socket}
  end

  # Component functions

  attr :pattern, :atom, required: true
  attr :viewport, Viewport, required: true

  defp background(assigns) do
    ~H"""
    <div class={["lf-background", "lf-background-#{@pattern}"]} style={background_style(@viewport)}>
    </div>
    """
  end

  defp background_style(%Viewport{x: x, y: y, zoom: z}) do
    size = 20 * z
    "background-size: #{size}px #{size}px; background-position: #{x}px #{y}px"
  end

  attr :box, :map, required: true

  defp selection_box(assigns) do
    ~H"""
    <div
      class="lf-selection-box"
      style={"left: #{@box.x}px; top: #{@box.y}px; width: #{@box.width}px; height: #{@box.height}px"}
    >
    </div>
    """
  end

  attr :target, :any, required: true

  defp controls(assigns) do
    ~H"""
    <div class="lf-controls">
      <button class="lf-controls-button" phx-click="lf:zoom_in" phx-target={@target} title="Zoom In">
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
      <button class="lf-controls-button" phx-click="lf:zoom_out" phx-target={@target} title="Zoom Out">
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
      <button class="lf-controls-button" phx-click="lf:fit_view" phx-target={@target} title="Fit View">
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

  attr :flow, State, required: true

  defp minimap(assigns) do
    # Calculate minimap scale
    bounds = State.bounds(assigns.flow)

    {scale, nodes_style} =
      if bounds do
        scale = min(180 / max(bounds.width, 1), 130 / max(bounds.height, 1))
        offset_x = -bounds.x * scale + 10
        offset_y = -bounds.y * scale + 10
        {scale, "transform: translate(#{offset_x}px, #{offset_y}px) scale(#{scale})"}
      else
        {1, ""}
      end

    vp = assigns.flow.viewport

    viewport_style =
      if bounds do
        # Viewport rectangle in minimap coordinates
        vp_x = -vp.x / vp.zoom * scale + 10 - bounds.x * scale
        vp_y = -vp.y / vp.zoom * scale + 10 - bounds.y * scale
        # Assuming 800px container
        vp_w = 800 / vp.zoom * scale
        # Assuming 600px container
        vp_h = 600 / vp.zoom * scale
        "left: #{vp_x}px; top: #{vp_y}px; width: #{vp_w}px; height: #{vp_h}px"
      else
        ""
      end

    assigns =
      assigns
      |> assign(:nodes_style, nodes_style)
      |> assign(:viewport_style, viewport_style)
      |> assign(:scale, scale)

    ~H"""
    <div class="lf-minimap">
      <div class="lf-minimap-nodes" style={@nodes_style}>
        <div
          :for={{_id, node} <- @flow.nodes}
          class="lf-minimap-node"
          data-selected={node.selected}
          style={"left: #{node.position.x}px; top: #{node.position.y}px; width: #{node.width || 100}px; height: #{node.height || 40}px"}
        >
        </div>
      </div>
      <div class="lf-minimap-viewport" style={@viewport_style}></div>
    </div>
    """
  end

  # Private helpers

  defp sort_nodes(nodes, selected_nodes) do
    nodes
    |> Map.values()
    |> Enum.sort_by(fn node ->
      base = node.z_index
      selected = if MapSet.member?(selected_nodes, node.id), do: 1000, else: 0
      dragging = if node.dragging, do: 2000, else: 0
      base + selected + dragging
    end)
  end

  defp sort_edges(edges, selected_edges) do
    edges
    |> Map.values()
    |> Enum.sort_by(fn edge ->
      base = edge.z_index
      selected = if MapSet.member?(selected_edges, edge.id), do: 1000, else: 0
      base + selected
    end)
  end

  defp notify_callback(nil, _data), do: :ok
  defp notify_callback(callback, data) when is_function(callback, 1), do: callback.(data)
  defp notify_callback(_callback, _data), do: :ok
end

defmodule FlowExampleWeb.Examples.Nodes.ShapesLive do
  @moduledoc """
  Shapes: flow chart shapes as custom nodes.

  A `:shape` node renders an SVG path computed for the node size, stretched
  to the node box (`viewBox` + `preserveAspectRatio="none"`) so it follows
  the size live while the node is resized. Every side has a handle and the
  flow uses `connection_mode: :loose`, so any two handles connect.

  New shapes are dragged from the sidebar palette (HTML5 drag & drop, the
  flow pushes `lf:drop`); the color picker recolors the selected shapes.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}
  alias LiveFlow.Components.NodeResizer

  @shapes [
    {"circle", "Circle"},
    {"round-rectangle", "Rounded"},
    {"rectangle", "Rectangle"},
    {"hexagon", "Hexagon"},
    {"diamond", "Diamond"},
    {"arrow-rectangle", "Arrow"},
    {"cylinder", "Cylinder"},
    {"triangle", "Triangle"},
    {"parallelogram", "Parallelogram"},
    {"plus", "Plus"}
  ]
  @shape_ids Enum.map(@shapes, &elem(&1, 0))

  @colors ~w(#cf4c2c #ea9c41 #ebc347 #438d57 #3f8ae2 #803dec)

  @edge_opts [
    type: :smoothstep,
    marker_end: %{type: :arrow_closed},
    style: %{"stroke-width" => 2}
  ]

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(shapes: @shapes, colors: @colors, color: "#3f8ae2", counter: 1)
     |> assign(:edge_opts, @edge_opts)
     |> assign(:color_form, color_form("#3f8ae2"))
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :selected, selected_shapes(assigns.flow))

    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #shapes-flow .lf-node[data-node-type="shape"],
      #shapes-flow .lf-node[data-node-type="shape"]:hover {
        background: transparent;
        border: none;
        border-radius: 0;
        box-shadow: none;
      }

      #shapes-flow .lf-node[data-node-type="shape"] .lf-node-content {
        position: relative;
        width: 100%;
        height: 100%;
        min-width: 0;
        padding: 0;
      }

      #shapes-flow .shape-svg path {
        transition: fill 200ms ease, stroke 200ms ease;
      }

      #shapes-flow .lf-node[data-node-type="shape"]:hover .shape-svg {
        filter: drop-shadow(0 3px 6px rgb(0 0 0 / 0.12));
      }

      #shapes-flow .lf-node[data-node-type="shape"][data-selected="true"] .shape-svg {
        filter: drop-shadow(0 0 1px var(--lf-node-selected-border)) drop-shadow(0 4px 10px rgb(0 0 0 / 0.18));
      }

      /* Handles appear on hover, selection and while connecting */
      #shapes-flow .lf-node[data-node-type="shape"] .lf-handle {
        opacity: 0;
        transition: opacity 150ms ease;
      }

      #shapes-flow .lf-node[data-node-type="shape"]:hover .lf-handle,
      #shapes-flow .lf-node[data-node-type="shape"][data-selected="true"] .lf-handle,
      #shapes-flow .lf-handle[data-connecting],
      #shapes-flow .lf-handle[data-connecting-source] {
        opacity: 1;
      }

      #shapes-flow .shape-label .fieldset {
        width: 100%;
        margin: 0;
        padding: 0;
      }

      #shapes-flow .shape-label input::placeholder {
        color: inherit;
        opacity: 0.55;
      }

      #shapes-canvas::after {
        content: "";
        position: absolute;
        inset: 10px;
        border: 2px dashed color-mix(in oklab, var(--color-primary) 55%, transparent);
        border-radius: 14px;
        background: color-mix(in oklab, var(--color-primary) 4%, transparent);
        opacity: 0;
        pointer-events: none;
        transition: opacity 150ms ease;
      }

      #shapes-canvas[data-drop-active]::after {
        opacity: 1;
      }

      #shape-color-form .color-input::-webkit-color-swatch-wrapper {
        padding: 0;
      }

      #shape-color-form .color-input::-webkit-color-swatch {
        border: none;
        border-radius: 6px;
      }

      #shape-color-form .color-input::-moz-color-swatch {
        border: none;
        border-radius: 6px;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <div id="shapes-canvas" class="relative h-full w-full">
        <.live_component
          module={LiveFlow.Components.Flow}
          id="shapes-flow"
          flow={@flow}
          node_types={%{shape: &shape_node/1}}
          opts={
            %{
              background: :dots,
              controls: true,
              minimap: true,
              minimap_pannable: true,
              minimap_zoomable: true,
              fit_view_on_init: true,
              fit_view_options: %{padding: 0.15},
              connection_mode: :loose,
              connection_line_type: :smoothstep
            }
          }
        />
      </div>

      <:sidebar>
        <.option_group title="Shapes">
          <div id="shape-palette" phx-hook=".ShapePalette" class="grid grid-cols-5 gap-1.5">
            <div
              :for={{shape, label} <- @shapes}
              id={"palette-#{shape}"}
              draggable="true"
              data-shape={shape}
              title={"Drag a #{String.downcase(label)} onto the canvas"}
              class="group flex cursor-grab flex-col items-center gap-1 rounded-lg border border-base-300 bg-base-100 px-1 pt-2 pb-1 shadow-xs transition-all duration-150 select-none hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-md active:cursor-grabbing data-dragging:scale-95 data-dragging:opacity-50"
            >
              <svg viewBox="0 0 40 30" class="h-6 w-8 overflow-visible">
                <path
                  d={shape_path(shape, 40, 30)}
                  fill={@color}
                  fill-opacity="0.85"
                  stroke={@color}
                  stroke-width="1.5"
                  stroke-linejoin="round"
                  class="transition-[fill,stroke] duration-200"
                />
              </svg>
              <span class="w-full truncate text-center text-[9px] text-base-content/55 group-hover:text-base-content/80">
                {label}
              </span>
            </div>
          </div>
          <.hint>
            Drag a shape onto the canvas. Select a shape to resize it, type in it to change its
            label, and connect any two sides.
          </.hint>
          <script :type={Phoenix.LiveView.ColocatedHook} name=".ShapePalette">
            // Native HTML5 drag & drop: the LiveFlow hook accepts drops carrying
            // "application/liveflow" data and pushes lf:drop with it.
            export default {
              mounted() {
                this.canvas = document.getElementById("shapes-canvas")

                this.el.addEventListener("dragstart", event => {
                  const item = event.target.closest("[data-shape]")
                  if (!item) return
                  event.dataTransfer.setData("application/liveflow", JSON.stringify({shape: item.dataset.shape}))
                  event.dataTransfer.effectAllowed = "move"
                  item.dataset.dragging = ""
                  if (this.canvas) this.canvas.dataset.dropActive = ""
                })

                this.el.addEventListener("dragend", event => {
                  const item = event.target.closest("[data-shape]")
                  if (item) delete item.dataset.dragging
                  if (this.canvas) delete this.canvas.dataset.dropActive
                })
              }
            }
          </script>
        </.option_group>

        <.option_group title="Color">
          <div class="flex flex-wrap gap-2">
            <button
              :for={color <- @colors}
              id={"color-#{String.trim_leading(color, "#")}"}
              type="button"
              phx-click="set_color"
              phx-value-color={color}
              title={color}
              class={[
                "size-7 rounded-full shadow-xs transition-transform duration-150 hover:scale-110 active:scale-95",
                color == @color && "ring-2 ring-primary ring-offset-2 ring-offset-base-100"
              ]}
              style={"background: #{color}"}
            />
          </div>
          <.form for={@color_form} id="shape-color-form" phx-change="pick_color" class="mt-3">
            <.input
              field={@color_form[:color]}
              type="color"
              label="Custom color"
              class="color-input h-9 w-full cursor-pointer rounded-lg border border-base-300 bg-base-100 p-1 transition-colors hover:border-base-content/30"
            />
          </.form>
          <p id="selected-shapes" class="text-xs text-base-content/55">
            <%= if @selected == [] do %>
              Select shapes to recolor them. New shapes use this color.
            <% else %>
              Recoloring
              <span class="font-semibold text-base-content/80">
                {length(@selected)} selected {if(length(@selected) == 1, do: "shape", else: "shapes")}
              </span>
            <% end %>
          </p>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            The <code>:shape</code>
            node draws an SVG path computed for its size, with <code>preserveAspectRatio="none"</code>: while
            <code>NodeResizer</code>
            resizes it, the path stretches with the box, and it's recomputed when the resize ends.
          </.hint>
          <.hint>
            Every side has a source handle; <code>connection_mode: :loose</code>
            lets source handles connect to each other. New edges get <code>@edge_opts</code>
            (smoothstep + closed arrow).
          </.hint>
          <.hint>
            Palette items set <code>application/liveflow</code>
            drag data; the flow pushes <code>lf:drop</code>
            with it and the drop position in flow coordinates.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp shape_node(assigns) do
    %{width: width, height: height, data: data} = assigns.node
    {default_w, default_h} = default_size(data.shape)

    assigns =
      assign(assigns,
        w: width || default_w,
        h: height || default_h,
        ink: ink_for(data.color)
      )

    ~H"""
    <NodeResizer.node_resizer
      node_id={@node.id}
      is_visible={@node.selected}
      min_width={60}
      min_height={40}
      color={@node.data.color}
    />
    <svg
      class="shape-svg pointer-events-none absolute inset-0 h-full w-full overflow-visible"
      viewBox={"0 0 #{num(@w)} #{num(@h)}"}
      preserveAspectRatio="none"
    >
      <path
        d={shape_path(@node.data.shape, @w, @h)}
        fill={@node.data.color}
        fill-opacity="0.85"
        stroke={@node.data.color}
        stroke-width="2"
        stroke-linejoin="round"
        vector-effect="non-scaling-stroke"
      />
    </svg>
    <form
      id={"shape-label-#{@node.id}"}
      phx-change="update_label"
      phx-submit="update_label"
      class={[
        "shape-label absolute inset-0 flex items-center justify-center px-[14%]",
        @node.data.shape == "triangle" && "pt-[28%]"
      ]}
    >
      <input type="hidden" name="node_id" value={@node.id} />
      <.input
        id={"shape-label-input-#{@node.id}"}
        type="text"
        name="label"
        value={@node.data.label}
        placeholder={@node.data.shape}
        autocomplete="off"
        maxlength="40"
        phx-debounce="150"
        class="nodrag w-full bg-transparent text-center text-[13px] font-semibold outline-none"
        style={"color: #{@ink}"}
      />
    </form>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event(
        "lf:drop",
        %{"data" => %{"shape" => shape}, "position" => %{"x" => x, "y" => y}} = params,
        socket
      )
      when shape in @shape_ids and is_number(x) and is_number(y) do
    n = socket.assigns.counter
    {w, h} = default_size(shape)
    node = shape_node_struct("shape-#{n}", shape, socket.assigns.color, "", x - w / 2, y - h / 2)

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(flow: State.add_node(socket.assigns.flow, node), counter: n + 1)
     |> FlowEvents.log("lf:drop", params)}
  end

  def handle_event("lf:drop", params, socket) do
    {:noreply, FlowEvents.log(socket, "lf:drop", Map.put(params, "ignored", true))}
  end

  def handle_event("update_label", %{"node_id" => id, "label" => label}, socket)
      when is_binary(id) and is_binary(label) do
    flow =
      State.update_node(socket.assigns.flow, id, fn node ->
        %{node | data: %{node.data | label: String.slice(label, 0, 40)}}
      end)

    {:noreply, assign(socket, :flow, flow)}
  end

  def handle_event("set_color", %{"color" => color}, socket) do
    {:noreply, set_color(socket, color)}
  end

  def handle_event("pick_color", %{"shape" => %{"color" => color}}, socket) do
    {:noreply, set_color(socket, color)}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # The color ends up in attributes: only #rrggbb is accepted
  defp set_color(socket, color) do
    if is_binary(color) and color =~ ~r/\A#[0-9a-fA-F]{6}\z/ do
      color = String.downcase(color)
      ids = selected_shapes(socket.assigns.flow)

      flow =
        Enum.reduce(ids, socket.assigns.flow, fn id, flow ->
          State.update_node(flow, id, fn node -> %{node | data: %{node.data | color: color}} end)
        end)

      socket =
        if ids == [],
          do: socket,
          else: socket |> FlowEvents.snapshot() |> FlowEvents.log("set_color", %{"nodes" => ids})

      assign(socket, flow: flow, color: color, color_form: color_form(color))
    else
      socket
    end
  end

  defp selected_shapes(flow) do
    flow.selected_nodes
    |> Enum.filter(&match?(%Node{type: :shape}, State.get_node(flow, &1)))
    |> Enum.sort()
  end

  defp color_form(color), do: to_form(%{"color" => color}, as: :shape)

  # ===== Shapes =====

  defp default_size("circle"), do: {110, 110}
  defp default_size("diamond"), do: {150, 110}
  defp default_size("triangle"), do: {130, 110}
  defp default_size("plus"), do: {110, 110}
  defp default_size("cylinder"), do: {120, 120}
  defp default_size(_shape), do: {160, 90}

  # SVG path of a shape inside a `w` x `h` box (2px inset for the stroke)
  defp shape_path(shape, w, h) do
    p = 2
    {x0, y0, x1, y1} = {p, p, w - p, h - p}
    {iw, ih} = {x1 - x0, y1 - y0}
    {cx, cy} = {w / 2, h / 2}

    case shape do
      "circle" ->
        {rx, ry} = {iw / 2, ih / 2}
        # Two half ellipses: left to right through the bottom, back through the top
        "M #{num(x0)} #{num(cy)} " <>
          arc(rx, ry, 1, 0, x1, cy) <> " " <> arc(rx, ry, 1, 0, x0, cy) <> " Z"

      "round-rectangle" ->
        r = min(min(iw, ih) * 0.22, 18)

        # Clockwise quarter arcs at the corners
        "M #{num(x0 + r)} #{num(y0)} H #{num(x1 - r)} " <>
          arc(r, r, 0, 1, x1, y0 + r) <>
          " V #{num(y1 - r)} " <>
          arc(r, r, 0, 1, x1 - r, y1) <>
          " H #{num(x0 + r)} " <>
          arc(r, r, 0, 1, x0, y1 - r) <>
          " V #{num(y0 + r)} " <> arc(r, r, 0, 1, x0 + r, y0) <> " Z"

      "rectangle" ->
        polygon([{x0, y0}, {x1, y0}, {x1, y1}, {x0, y1}])

      "hexagon" ->
        s = min(iw * 0.22, ih / 2)
        polygon([{x0, cy}, {x0 + s, y0}, {x1 - s, y0}, {x1, cy}, {x1 - s, y1}, {x0 + s, y1}])

      "diamond" ->
        polygon([{cx, y0}, {x1, cy}, {cx, y1}, {x0, cy}])

      "arrow-rectangle" ->
        s = min(iw * 0.2, ih / 2)
        polygon([{x0, y0}, {x1 - s, y0}, {x1, cy}, {x1 - s, y1}, {x0, y1}, {x0 + s, cy}])

      "cylinder" ->
        {rx, ry} = {iw / 2, min(ih * 0.14, 16)}
        top = y0 + ry
        bottom = y1 - ry

        # Body (sides, front of the bottom, back of the top) + front of the top
        "M #{num(x0)} #{num(top)} V #{num(bottom)} " <>
          arc(rx, ry, 0, 0, x1, bottom) <>
          " V #{num(top)} " <>
          arc(rx, ry, 0, 0, x0, top) <>
          " Z M #{num(x0)} #{num(top)} " <> arc(rx, ry, 0, 0, x1, top)

      "triangle" ->
        polygon([{cx, y0}, {x1, y1}, {x0, y1}])

      "parallelogram" ->
        s = min(iw * 0.22, ih)
        polygon([{x0 + s, y0}, {x1, y0}, {x1 - s, y1}, {x0, y1}])

      "plus" ->
        {tw, th} = {iw / 3, ih / 3}

        polygon([
          {x0 + tw, y0},
          {x1 - tw, y0},
          {x1 - tw, y0 + th},
          {x1, y0 + th},
          {x1, y1 - th},
          {x1 - tw, y1 - th},
          {x1 - tw, y1},
          {x0 + tw, y1},
          {x0 + tw, y1 - th},
          {x0, y1 - th},
          {x0, y0 + th},
          {x0 + tw, y0 + th}
        ])

      _rectangle ->
        polygon([{x0, y0}, {x1, y0}, {x1, y1}, {x0, y1}])
    end
  end

  defp polygon([{x, y} | rest]) do
    "M #{num(x)} #{num(y)} " <>
      Enum.map_join(rest, " ", fn {x, y} -> "L #{num(x)} #{num(y)}" end) <> " Z"
  end

  # Elliptical arc to (x, y). In screen coordinates sweep 1 is clockwise.
  defp arc(rx, ry, large_arc, sweep, x, y) do
    "A #{num(rx)} #{num(ry)} 0 #{large_arc} #{sweep} #{num(x)} #{num(y)}"
  end

  defp num(value) when is_integer(value), do: Integer.to_string(value)
  defp num(value), do: :erlang.float_to_binary(value * 1.0, [:compact, decimals: 2])

  # Dark text on light fills, white text on dark ones (WCAG relative luminance)
  defp ink_for("#" <> hex) do
    [r, g, b] =
      for <<channel::binary-size(2) <- hex>> do
        value = String.to_integer(channel, 16) / 255
        if value <= 0.03928, do: value / 12.92, else: :math.pow((value + 0.055) / 1.055, 2.4)
      end

    if 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.45, do: "#1a192b", else: "#ffffff"
  end

  # ===== Initial graph =====

  defp shape_node_struct(id, shape, color, label, x, y) do
    {w, h} = default_size(shape)

    Node.new(id, %{x: x, y: y}, %{shape: shape, color: color, label: label},
      type: :shape,
      resizable: true,
      width: w,
      height: h,
      handles: for(side <- [:top, :right, :bottom, :left], do: Handle.source(side, id: "#{side}"))
    )
  end

  defp build_flow do
    nodes = [
      shape_node_struct("start", "circle", "#3f8ae2", "Start", 25, 0),
      shape_node_struct("input", "parallelogram", "#803dec", "Read order", 0, 170),
      shape_node_struct("valid", "diamond", "#ea9c41", "Valid?", 5, 330),
      shape_node_struct("process", "round-rectangle", "#438d57", "Process", 0, 520),
      shape_node_struct("save", "cylinder", "#3f8ae2", "Orders DB", 20, 680),
      shape_node_struct("error", "hexagon", "#cf4c2c", "Show error", 300, 340),
      shape_node_struct("retry", "arrow-rectangle", "#ebc347", "Retry", 300, 170)
    ]

    edge = fn id, source, source_handle, target, target_handle, opts ->
      Edge.new(
        id,
        source,
        target,
        @edge_opts ++ [source_handle: source_handle, target_handle: target_handle] ++ opts
      )
    end

    edges = [
      edge.("e-start-input", "start", "bottom", "input", "top", []),
      edge.("e-input-valid", "input", "bottom", "valid", "top", []),
      edge.("e-valid-process", "valid", "bottom", "process", "top", label: "yes"),
      edge.("e-valid-error", "valid", "right", "error", "left", label: "no"),
      edge.("e-error-retry", "error", "top", "retry", "bottom", []),
      edge.("e-retry-input", "retry", "left", "input", "right", animated: true),
      edge.("e-process-save", "process", "bottom", "save", "top", [])
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

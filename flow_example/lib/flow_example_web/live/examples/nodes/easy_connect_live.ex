defmodule FlowExampleWeb.Examples.Nodes.EasyConnectLive do
  @moduledoc """
  Easy Connect: the whole node acts as a handle.

  Each node has a source and a target handle stretched over the whole node
  (Handle `style:`). The source handle sits on top, so a connection starts
  from anywhere on the node; while a connection is in progress the target
  handles are raised above it, so it ends anywhere on another node. Nodes are
  dragged from a small tab (`drag_handle`) and connected with floating edges.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}

  # Stretch a handle over the whole node (overrides the side placement)
  @cover %{
    "inset" => "0",
    "width" => "100%",
    "height" => "100%",
    "transform" => "none",
    "border" => "none",
    "border-radius" => "inherit",
    "background" => "transparent"
  }

  @edge_opts [
    type: :straight,
    source_floating: true,
    target_floating: true,
    marker_end: %{type: :arrow_closed, width: 18, height: 18}
  ]

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     # Used by FlowEvents when it creates the edge on lf:connect_end
     |> assign(:edge_opts, @edge_opts)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #easy-connect .lf-node[data-node-type="easy"] {
        --ec-accent: var(--lf-node-selected-border);
        --ec-pink: #ff0072;
        width: 150px;
        height: 80px;
        border: 2px solid color-mix(in oklab, var(--ec-accent) 55%, var(--lf-node-border));
        border-radius: 12px;
        background: color-mix(in oklab, var(--ec-accent) 10%, var(--lf-node-bg));
        transition: background-color 150ms ease, border-color 150ms ease, box-shadow 150ms ease;
      }

      #easy-connect .lf-node[data-node-type="easy"] .lf-node-content {
        display: grid;
        height: 100%;
        min-width: 0;
        padding: 0;
        place-items: center;
      }

      /* The source handle covers the node: connections start anywhere */
      #easy-connect .lf-handle[data-handle-type="source"] {
        z-index: 11;
        cursor: crosshair;
      }

      #easy-connect .lf-handle[data-handle-type="target"] {
        z-index: 10;
      }

      /* While connecting, the target handles are raised above the source
         handles so that dropping anywhere on a node connects to it. */
      #easy-connect:has(.lf-connection-preview) .lf-handle[data-handle-type="target"] {
        z-index: 12;
      }

      /* The drag tab sits above both handles */
      #easy-connect .ec-drag-handle {
        position: absolute;
        top: -11px;
        left: 50%;
        z-index: 20;
        display: grid;
        place-items: center;
        width: 40px;
        height: 20px;
        translate: -50% 0;
        border: 2px solid color-mix(in oklab, var(--ec-accent) 55%, var(--lf-node-border));
        border-radius: 6px;
        background: var(--lf-node-bg);
        color: var(--lf-text-secondary);
        cursor: grab;
        transition: background-color 150ms ease, color 150ms ease;
      }

      #easy-connect .ec-drag-handle:hover {
        background: var(--ec-accent);
        color: white;
      }

      #easy-connect .ec-label-drop {
        display: none;
      }

      /* Connection in progress: every other node becomes a drop zone */
      #easy-connect:has(.lf-connection-preview) .lf-node[data-node-type="easy"]:not(.is-connecting-from) {
        border-style: dashed;
        border-color: color-mix(in oklab, var(--ec-pink) 55%, var(--lf-node-border));
        background: color-mix(in oklab, var(--ec-pink) 8%, var(--lf-node-bg));
      }

      #easy-connect:has(.lf-connection-preview) .lf-node:not(.is-connecting-from) .ec-label-idle {
        display: none;
      }

      #easy-connect:has(.lf-connection-preview) .lf-node:not(.is-connecting-from) .ec-label-drop {
        display: inline;
      }

      /* The node under the pointer is a valid target */
      #easy-connect .lf-node[data-node-type="easy"]:has(.lf-handle[data-connecting="valid"]) {
        border-color: var(--ec-pink);
        background: color-mix(in oklab, var(--ec-pink) 20%, var(--lf-node-bg));
        box-shadow: 0 0 0 4px color-mix(in oklab, var(--ec-pink) 18%, transparent);
      }

      #easy-connect .lf-connection-line {
        stroke: var(--lf-node-selected-border);
        stroke-dasharray: 6 4;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="easy-connect"
        flow={@flow}
        node_types={%{easy: &easy_node/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.3},
            connection_line_type: :straight,
            connect_on_click: false,
            connection_events: true
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Press anywhere on a node and drag to another node to connect them. Move a node with the
            small tab on its top border.
          </.hint>
          <.hint>
            Each node has a source and a target handle stretched over the whole node with <code phx-no-curly-interpolation>Handle.source(:right, style: %{"inset" => "0", ...})</code>. The source is on
            top by default; while a connection is in progress
            (<code>#easy-connect:has(.lf-connection-preview)</code>) CSS raises the targets above it.
          </.hint>
          <.hint>
            Nodes use <code>drag_handle: ".ec-drag-handle"</code>
            and edges are straight <b>floating edges</b>
            (<code>source_floating</code>/<code>target_floating</code>) that attach to the closest
            side.
          </.hint>
          <.hint>
            With <code>connection_events: true</code>
            the LiveView receives <code>lf:connect_start</code>
            and marks the node the line comes from, so the others read "Drop here".
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

  defp easy_node(assigns) do
    ~H"""
    <span class="ec-drag-handle" title="Drag to move">
      <.icon name="hero-ellipsis-horizontal-mini" class="size-4" />
    </span>
    <span
      class="pointer-events-none text-center text-[12px] font-semibold"
      style="color: var(--lf-text-primary)"
    >
      <span class="ec-label-idle">Drag to connect</span>
      <span class="ec-label-drop">Drop here</span>
    </span>
    """
  end

  @impl true
  def handle_event("lf:connect_start", %{"node_id" => node_id} = params, socket) do
    {:noreply,
     socket
     |> update(:flow, &mark_connecting(&1, node_id))
     |> FlowEvents.log("lf:connect_start", params)}
  end

  def handle_event(event, params, socket)
      when event in ["lf:connect_end", "lf:connect_cancel"] do
    socket = update(socket, :flow, &mark_connecting(&1, nil))
    FlowEvents.handle_event(event, params, socket)
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp mark_connecting(flow, node_id) do
    nodes =
      Map.new(flow.nodes, fn {id, node} ->
        {id, %{node | class: if(id == node_id, do: "is-connecting-from")}}
      end)

    %{flow | nodes: nodes}
  end

  defp easy(id, x, y) do
    Node.new(id, %{x: x, y: y}, %{},
      type: :easy,
      width: 150,
      height: 80,
      drag_handle: ".ec-drag-handle",
      handles: [
        Handle.source(:right, style: @cover),
        Handle.target(:left, style: @cover)
      ]
    )
  end

  defp build_flow do
    nodes = [
      easy("1", 0, 0),
      easy("2", 320, 0),
      easy("3", 40, 260),
      easy("4", 300, 300)
    ]

    State.new(nodes: nodes, edges: [Edge.new("e1-2", "1", "2", @edge_opts)])
  end
end

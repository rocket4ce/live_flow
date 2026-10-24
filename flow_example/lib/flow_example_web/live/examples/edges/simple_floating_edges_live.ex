defmodule FlowExampleWeb.Examples.Edges.SimpleFloatingEdgesLive do
  @moduledoc """
  Simple Floating Edges: edges connect to the closest available side.

  Every node has a handle on each side (`"top"`, `"right"`, `"bottom"`,
  `"left"`, all source handles with `connection_mode: :loose`). The server
  picks, for every edge, the pair of sides facing each other and rewrites the
  edge's `source_handle` / `target_handle`: live on `lf:drag_move` (using the
  dragged absolute positions) and after every drop.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}

  @sides ~w(top right bottom left)
  @default_width 100
  @default_height 40

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)
    params = %{"type" => "bezier"}

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> FlowEvents.assign_flow(build_flow())
     |> assign(:form, to_form(params, as: :edges))
     |> assign(:edge_opts, edge_opts("bezier"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #simple-floating-flow .lf-handle {
        width: 8px;
        height: 8px;
        opacity: 0.45;
        transition: opacity 0.15s ease, transform 0.15s ease, background 0.15s ease;
      }
      #simple-floating-flow .lf-node:hover .lf-handle,
      #simple-floating-flow .lf-handle[data-connecting] {
        opacity: 1;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="simple-floating-flow"
        flow={@flow}
        node_types={%{side: &side_node/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.2},
            connection_mode: :loose,
            connection_line_type: :straight
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Drag a node around the hub: its edge jumps to the pair of sides facing each other,
            while you drag.
          </.hint>
          <.hint>
            Each node has four handles: <code>Handle.source(:top, id: "top")</code>, … With
            <code>connection_mode: :loose</code>
            any handle can connect to any other, so the same handles work as sources and targets.
          </.hint>
          <.hint>
            On every <code>lf:drag_move</code>
            (absolute positions of the dragged nodes, every 50ms) and after each drop, the server
            compares the node centers and rewrites <code>source_handle</code>
            / <code>target_handle</code>. The client redraws the edge with the new handles.
          </.hint>
        </.option_group>

        <.form for={@form} id="floating-form" phx-change="set_type">
          <.option_group title="Edge path">
            <.input
              field={@form[:type]}
              type="select"
              class={select_class()}
              options={[
                {"Bezier", "bezier"},
                {"Straight", "straight"},
                {"Smoothstep", "smoothstep"},
                {"Step", "step"}
              ]}
            />
          </.option_group>
        </.form>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp side_node(assigns) do
    ~H"""
    <div class="flex w-24 items-center justify-center gap-1.5">
      <.icon :if={@node.data[:icon]} name={@node.data.icon} class="size-4 text-primary" />
      <span class="text-xs font-semibold" style="color: var(--lf-text-primary)">
        {@node.data.label}
      </span>
    </div>
    """
  end

  @impl true
  def handle_event("set_type", %{"edges" => %{"type" => type} = params}, socket)
      when type in ~w(bezier straight smoothstep step) do
    opts = edge_opts(type)
    flow = socket.assigns.flow
    edges = Map.new(flow.edges, fn {id, edge} -> {id, struct(edge, opts)} end)

    {:noreply,
     socket
     |> assign(:flow, %{flow | edges: edges})
     |> assign(:edge_opts, opts)
     |> assign(:form, to_form(params, as: :edges))}
  end

  # Live update while dragging: the positions are absolute (no parents here)
  def handle_event("lf:drag_move", %{"changes" => changes}, socket) do
    overrides =
      for %{"id" => id, "position" => %{"x" => x, "y" => y}} <- changes, into: %{} do
        {id, %{x: x, y: y}}
      end

    {:noreply, update(socket, :flow, &float_edges(&1, overrides))}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    {:noreply, socket} = FlowEvents.handle_event(event, params, socket)
    {:noreply, update(socket, :flow, &float_edges/1)}
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # Rewrites the handles of every edge so it uses the sides facing each other.
  # `overrides` maps node ids to positions that win over the stored ones.
  defp float_edges(%State{} = flow, overrides \\ %{}) do
    edges =
      Map.new(flow.edges, fn {id, edge} ->
        with %Node{} = source <- flow.nodes[edge.source],
             %Node{} = target <- flow.nodes[edge.target] do
          source_center = center(source, overrides)
          target_center = center(target, overrides)

          {id,
           %{
             edge
             | source_handle: facing_side(source_center, target_center),
               target_handle: facing_side(target_center, source_center)
           }}
        else
          _ -> {id, edge}
        end
      end)

    %{flow | edges: edges}
  end

  # Same rule as React Flow's simple floating edges: the axis with the larger
  # distance between the centers decides between left/right and top/bottom
  defp facing_side(%{x: x1, y: y1}, %{x: x2, y: y2}) do
    dx = x2 - x1
    dy = y2 - y1

    cond do
      abs(dx) > abs(dy) and dx > 0 -> "right"
      abs(dx) > abs(dy) -> "left"
      dy > 0 -> "bottom"
      true -> "top"
    end
  end

  defp center(%Node{} = node, overrides) do
    %{x: x, y: y} = Map.get(overrides, node.id, node.position)
    %{x: x + (node.width || @default_width) / 2, y: y + (node.height || @default_height) / 2}
  end

  defp edge_opts(type) do
    [
      type: String.to_existing_atom(type),
      marker_end: %{type: :arrow_closed}
    ]
  end

  defp build_flow do
    handles = Enum.map(@sides, &Handle.source(String.to_existing_atom(&1), id: &1))

    node = fn id, x, y, label, icon ->
      Node.new(id, %{x: x, y: y}, %{label: label, icon: icon}, type: :side, handles: handles)
    end

    ring =
      [
        {"api", "API", "hero-server"},
        {"web", "Web", "hero-globe-alt"},
        {"mobile", "Mobile", "hero-device-phone-mobile"},
        {"queue", "Queue", "hero-queue-list"},
        {"db", "Database", "hero-circle-stack"},
        {"cache", "Cache", "hero-bolt"}
      ]
      |> Enum.with_index()
      |> Enum.map(fn {{id, label, icon}, i} ->
        angle = i * :math.pi() / 3 - :math.pi() / 2
        x = round(320 + 280 * :math.cos(angle))
        y = round(200 + 220 * :math.sin(angle))
        node.(id, x, y, label, icon)
      end)

    nodes = [node.("hub", 320, 200, "Hub", "hero-cpu-chip") | ring]

    edges =
      Enum.map(ring, &Edge.new("hub-#{&1.id}", "hub", &1.id, edge_opts("bezier"))) ++
        [
          Edge.new("web-mobile", "web", "mobile", edge_opts("bezier")),
          Edge.new("db-cache", "db", "cache", edge_opts("bezier"))
        ]

    [nodes: nodes, edges: edges]
    |> State.new()
    |> float_edges()
  end
end

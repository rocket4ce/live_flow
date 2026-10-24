defmodule FlowExampleWeb.Examples.Nodes.IntersectionsLive do
  @moduledoc """
  Intersections: detect when a dragged node overlaps other nodes.

  While dragging, the hook pushes `lf:drag_move` with the absolute positions
  of the moving nodes (every 50ms). The LiveView builds their rects and asks
  `LiveFlow.State.intersecting_nodes/3` which nodes they touch.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Node, State}

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, overlapping: [])
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #intersections .lf-node {
        transition: background-color 150ms ease, border-color 150ms ease, box-shadow 150ms ease;
      }

      #intersections .lf-node-content {
        display: grid;
        height: 100%;
        min-width: 0;
        padding: 4px 8px;
        place-items: center;
      }

      #intersections .lf-node.highlight {
        --lf-node-bg: #ff0072;
        --lf-text-primary: #fff;
        border-color: #ff0072;
        box-shadow: 0 0 0 4px rgb(255 0 114 / 0.2);
      }

      #intersections .lf-node.highlight .lf-default-node-label {
        color: #fff;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="intersections"
        flow={@flow}
        opts={%{background: :dots, controls: true, fit_view_on_init: true}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Drag a node over the others: the nodes it overlaps light up.
          </.hint>
          <.hint>
            <code>lf:drag_move</code>
            carries the absolute position of every moving node. The LiveView turns it into a rect
            (position + measured size) and calls <code>State.intersecting_nodes(flow, rect, partial: true)</code>.
          </.hint>
          <.hint>
            Overlapping nodes get <code>class: "highlight"</code>; the classes are cleared when
            <code>lf:node_change</code>
            reports the end of the drag (<code>dragging: false</code>).
          </.hint>
        </.option_group>
        <.option_group title="Overlapping">
          <p :if={@overlapping == []} id="overlapping-none" class="text-sm text-base-content/50">
            Nothing overlaps.
          </p>
          <div :if={@overlapping != []} id="overlapping-list" class="flex flex-wrap gap-1.5">
            <span
              :for={label <- @overlapping}
              class="rounded-md bg-[#ff0072]/15 px-2 py-0.5 text-xs font-medium text-[#d6005f]"
            >
              {label}
            </span>
          </div>
        </.option_group>
        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  @impl true
  def handle_event("lf:drag_move", %{"changes" => changes}, socket) do
    flow = socket.assigns.flow

    dragged =
      for %{"id" => id, "position" => %{"x" => x, "y" => y}} <- changes,
          %{} = rect <- [State.node_rect(flow, id)],
          do: {id, %{rect | x: x, y: y}}

    dragged_ids = MapSet.new(dragged, &elem(&1, 0))

    hits =
      dragged
      |> Enum.flat_map(fn {_id, rect} -> State.intersecting_nodes(flow, rect, partial: true) end)
      |> Enum.reject(&MapSet.member?(dragged_ids, &1.id))
      |> MapSet.new(& &1.id)

    {:noreply, highlight(socket, hits)}
  end

  def handle_event("lf:node_change", %{"changes" => changes} = params, socket) do
    {:noreply, socket} = FlowEvents.handle_event("lf:node_change", params, socket)

    if Enum.any?(changes, &match?(%{"type" => "position", "dragging" => false}, &1)),
      do: {:noreply, highlight(socket, MapSet.new())},
      else: {:noreply, socket}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # Only nodes whose class changes are re-rendered
  defp highlight(socket, hit_ids) do
    flow = socket.assigns.flow

    nodes =
      Map.new(flow.nodes, fn {id, node} ->
        {id, %{node | class: if(MapSet.member?(hit_ids, id), do: "highlight")}}
      end)

    overlapping =
      nodes
      |> Map.values()
      |> Enum.filter(&(&1.class == "highlight"))
      |> Enum.map(& &1.data.label)
      |> Enum.sort()

    assign(socket, flow: %{flow | nodes: nodes}, overlapping: overlapping)
  end

  defp build_flow do
    node = fn id, x, y, label, {w, h} ->
      Node.new(id, %{x: x, y: y}, %{label: label},
        width: w,
        height: h,
        connectable: false,
        style: %{"width" => "#{w}px", "height" => "#{h}px"}
      )
    end

    nodes = [
      node.("1", 0, 0, "Node 1", {200, 100}),
      node.("2", 0, 150, "Node 2", {150, 40}),
      node.("3", 250, 0, "Node 3", {150, 40}),
      node.("4", 350, 150, "Node 4", {60, 60}),
      node.("5", 250, 260, "Node 5", {150, 80})
    ]

    State.new(nodes: nodes)
  end
end

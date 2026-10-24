defmodule FlowExampleWeb.Examples.Edges.EdgeIntersectionLive do
  @moduledoc """
  Edge Intersection: detect which edges cross a node while it's dragged.

  While dragging, the hook pushes `lf:drag_move` with the absolute positions
  of the moving nodes (every 50ms). The LiveView takes the nodes from
  `LiveFlow.State.absolute_nodes/1`, moves the dragged ones to their new
  position, gets the end points of every straight edge from
  `LiveFlow.Paths.Geometry.edge_path/3` and tests each segment against the
  dragged node's rectangle (Liang–Barsky clipping). Crossed edges get a CSS
  class until the drag ends.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Node, State}
  alias LiveFlow.Paths.Geometry

  @size {130, 44}

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, hits: MapSet.new(), probing: [])
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #edge-intersection-flow .lf-node {
        transition:
          border-color 150ms ease,
          box-shadow 150ms ease;
      }
      #edge-intersection-flow .lf-node-content {
        display: grid;
        height: 100%;
        min-width: 0;
        padding: 0 10px;
        place-items: center;
      }
      #edge-intersection-flow .lf-node.probe {
        border: 1.5px dashed var(--lf-node-selected-border);
      }
      #edge-intersection-flow .lf-node.is-probing {
        border-color: #ff0072;
        box-shadow: 0 0 0 4px rgb(255 0 114 / 0.18);
      }
      #edge-intersection-flow .lf-edge-group.is-hit .lf-edge {
        stroke: #ff0072;
        stroke-width: 3.5;
        stroke-dasharray: 8 5;
        animation: ei-dash 0.5s linear infinite;
      }
      @keyframes ei-dash {
        to {
          stroke-dashoffset: -13;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="edge-intersection-flow"
        flow={@flow}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.2}
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Drag a node (try <b>Drag me</b>) across the network: the edges it crosses light up.
          </.hint>
          <.hint>
            <code>lf:drag_move</code>
            carries the absolute positions of the moving nodes. The LiveView moves them in <code>State.absolute_nodes(flow)</code>, takes each edge's end points from
            <code>Geometry.edge_path(edge, source, target)</code>
            and clips the segment against the node's rectangle.
          </.hint>
          <.hint>
            Crossed edges get <code>class: "is-hit"</code>; the classes are cleared when
            <code>lf:node_change</code>
            reports the end of the drag. Edges attached to the dragged node are ignored.
          </.hint>
        </.option_group>
        <.option_group title="Crossed edges">
          <p :if={MapSet.size(@hits) == 0} id="hits-none" class="text-sm text-base-content/50">
            No edge crosses the dragged node.
          </p>
          <ul :if={MapSet.size(@hits) > 0} id="hits-list" class="flex flex-wrap gap-1.5">
            <li
              :for={id <- Enum.sort(@hits)}
              id={"hit-#{id}"}
              class="rounded-md bg-[#ff0072]/15 px-2 py-0.5 text-xs font-medium text-[#d6005f]"
            >
              {edge_title(@flow, id)}
            </li>
          </ul>
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

    moving =
      for %{"id" => id, "position" => %{"x" => x, "y" => y}} <- changes,
          Map.has_key?(flow.nodes, id),
          into: %{},
          do: {id, %{x: x, y: y}}

    # Absolute nodes, with the dragged ones at their client-side position
    nodes =
      flow
      |> State.absolute_nodes()
      |> Map.new(fn {id, node} ->
        case moving do
          %{^id => position} -> {id, %{node | position: position}}
          _ -> {id, node}
        end
      end)

    rects = for {id, _} <- moving, do: rect(nodes[id])

    hits =
      for {id, %Edge{} = edge} <- flow.edges,
          not Map.has_key?(moving, edge.source),
          not Map.has_key?(moving, edge.target),
          %{source: from, target: to} <- [
            Geometry.edge_path(edge, nodes[edge.source], nodes[edge.target])
          ],
          Enum.any?(rects, &segment_hits_rect?(from, to, &1)),
          into: MapSet.new(),
          do: id

    {:noreply, highlight(socket, hits, Map.keys(moving))}
  end

  def handle_event("lf:node_change", %{"changes" => changes} = params, socket) do
    {:noreply, socket} = FlowEvents.handle_event("lf:node_change", params, socket)

    if Enum.any?(changes, &match?(%{"type" => "position", "dragging" => false}, &1)),
      do: {:noreply, highlight(socket, MapSet.new(), [])},
      else: {:noreply, socket}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # Only re-renders when the set of crossed edges changes
  defp highlight(socket, hits, moving_ids) do
    probing = if MapSet.size(hits) > 0, do: Enum.sort(moving_ids), else: []

    if hits == socket.assigns.hits and probing == socket.assigns.probing do
      socket
    else
      flow = socket.assigns.flow

      edges =
        Map.new(flow.edges, fn {id, edge} ->
          {id, %{edge | class: if(MapSet.member?(hits, id), do: "is-hit")}}
        end)

      nodes =
        Map.new(flow.nodes, fn {id, node} ->
          {id, %{node | class: node_class(node, id in probing)}}
        end)

      assign(socket, flow: %{flow | edges: edges, nodes: nodes}, hits: hits, probing: probing)
    end
  end

  defp node_class(%Node{data: %{probe: true}}, true), do: "probe is-probing"
  defp node_class(%Node{data: %{probe: true}}, false), do: "probe"
  defp node_class(_node, true), do: "is-probing"
  defp node_class(_node, false), do: nil

  defp rect(%Node{position: %{x: x, y: y}} = node) do
    {w, h} = @size
    %{x: x, y: y, width: node.width || w, height: node.height || h}
  end

  # Liang–Barsky: clip the segment against the rectangle, it intersects the
  # rectangle when a part of it survives
  defp segment_hits_rect?(%{x: x1, y: y1}, %{x: x2, y: y2}, %{x: rx, y: ry} = rect) do
    dx = x2 - x1
    dy = y2 - y1

    [
      {-dx, x1 - rx},
      {dx, rx + rect.width - x1},
      {-dy, y1 - ry},
      {dy, ry + rect.height - y1}
    ]
    |> Enum.reduce_while({0.0, 1.0}, fn
      {p, q}, acc when p == 0 ->
        if q < 0, do: {:halt, :outside}, else: {:cont, acc}

      {p, q}, {t0, t1} when p < 0 ->
        r = q / p
        if r > t1, do: {:halt, :outside}, else: {:cont, {max(t0, r), t1}}

      {p, q}, {t0, t1} ->
        r = q / p
        if r < t0, do: {:halt, :outside}, else: {:cont, {t0, min(t1, r)}}
    end)
    |> case do
      :outside -> false
      {t0, t1} -> t0 <= t1
    end
  end

  defp edge_title(flow, id) do
    case State.get_edge(flow, id) do
      %Edge{source: s, target: t} -> "#{label(flow, s)} — #{label(flow, t)}"
      nil -> id
    end
  end

  defp label(flow, id) do
    case State.get_node(flow, id) do
      %Node{data: data} -> data[:label] || id
      nil -> id
    end
  end

  defp build_flow do
    {w, h} = @size

    node = fn id, x, y, label, extra ->
      Node.new(id, %{x: x, y: y}, Map.merge(%{label: label}, extra),
        width: w,
        height: h,
        connectable: false,
        class: if(extra[:probe], do: "probe"),
        style: %{"width" => "#{w}px", "height" => "#{h}px"}
      )
    end

    nodes = [
      node.("1", 0, 0, "Node 1", %{}),
      node.("2", 420, -20, "Node 2", %{}),
      node.("3", 540, 280, "Node 3", %{}),
      node.("4", 200, 420, "Node 4", %{}),
      node.("5", -140, 240, "Node 5", %{}),
      node.("probe", 760, 120, "Drag me", %{probe: true})
    ]

    edge = fn source, target ->
      Edge.new("e#{source}-#{target}", source, target,
        type: :straight,
        source_floating: true,
        target_floating: true,
        marker_end: %{type: :none}
      )
    end

    edges = [
      edge.("1", "2"),
      edge.("2", "3"),
      edge.("3", "4"),
      edge.("4", "5"),
      edge.("5", "1"),
      edge.("1", "3"),
      edge.("2", "4"),
      edge.("2", "5")
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

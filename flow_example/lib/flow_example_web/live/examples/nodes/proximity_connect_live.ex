defmodule FlowExampleWeb.Examples.Nodes.ProximityConnectLive do
  @moduledoc """
  Proximity Connect: drag a node close to another one to connect them.

  While dragging, `lf:drag_move` carries the absolute positions of the moving
  nodes (every 50ms). The LiveView looks for the closest other node whose
  center is less than 150px away and shows a dashed temporary edge from the
  left node to the right one. When the drag ends (`lf:node_change` with
  `dragging: false`) the closest pair is computed again from the final
  positions and the temporary edge becomes a real edge.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Node, State}

  @min_distance 150
  @temp_id "proximity-temp"

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, proximity: nil)
     |> assign(:min_distance, @min_distance)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #proximity-connect .lf-node {
        transition: box-shadow 150ms ease, border-color 150ms ease;
      }

      #proximity-connect .lf-node.proximity-near {
        border-color: var(--lf-node-selected-border);
        box-shadow: 0 0 0 5px color-mix(in oklab, var(--lf-node-selected-border) 20%, transparent);
      }

      #proximity-connect .lf-edge-group.temp {
        pointer-events: none;
      }

      #proximity-connect .lf-edge-group.temp .lf-edge {
        stroke: var(--lf-node-selected-border);
        stroke-width: 2;
        stroke-dasharray: 6 5;
        animation: proximity-dash 600ms linear infinite;
      }

      @keyframes proximity-dash {
        to {
          stroke-dashoffset: -11;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action
          id="clear-edges"
          icon="hero-scissors"
          phx-click="clear_edges"
          disabled={map_size(@flow.edges) == 0}
        >
          Clear edges
        </.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="proximity-connect"
        flow={@flow}
        node_types={%{dot: &dot_node/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.3}
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Drag a node towards another one. When their centers are closer than
            <b>{@min_distance}px</b>
            a dashed edge previews the connection (from the left node to the right one). Drop the
            node to create it.
          </.hint>
          <.hint>
            <code>lf:drag_move</code>
            sends the absolute position of the moving nodes every 50ms. The LiveView compares the
            node centers and adds (or replaces) a temporary edge with <code>class: "temp"</code>.
          </.hint>
          <.hint>
            On <code>lf:node_change</code>
            with <code>dragging: false</code>
            the temporary edge is removed and a real one is added with <code>State.add_edge/2</code>, unless the nodes are already connected.
          </.hint>
        </.option_group>

        <.option_group title="Closest node">
          <div
            :if={@proximity}
            id="proximity-status"
            class="flex items-center justify-between gap-3 rounded-lg border border-primary/30 bg-primary/5 px-3 py-2"
          >
            <span class="flex items-center gap-1.5 text-sm font-medium">
              {label(@flow, @proximity.source)}
              <.icon name="hero-arrow-long-right-mini" class="size-4 text-primary" />
              {label(@flow, @proximity.target)}
            </span>
            <span class="rounded bg-base-100 px-1.5 font-mono text-xs text-base-content/70">
              {@proximity.distance}px
            </span>
          </div>
          <p :if={!@proximity} id="proximity-none" class="text-sm text-base-content/50">
            Nothing within {@min_distance}px.
          </p>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp dot_node(assigns) do
    ~H"""
    <div class="flex w-32 items-center gap-2.5">
      <span
        class="grid size-7 shrink-0 place-items-center rounded-full"
        style={"background: color-mix(in oklab, #{@node.data.color} 16%, transparent); color: #{@node.data.color}"}
      >
        <span class="size-2.5 rounded-full" style={"background: #{@node.data.color}"}></span>
      </span>
      <p class="truncate text-[13px] font-semibold" style="color: var(--lf-text-primary)">
        {@node.data.label}
      </p>
    </div>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("lf:drag_move", %{"changes" => changes}, socket) when is_list(changes) do
    flow = socket.assigns.flow

    moving =
      for %{"id" => id, "position" => %{"x" => x, "y" => y}} <- changes,
          is_number(x) and is_number(y),
          %{} = rect <- [State.node_rect(flow, id)],
          do: {id, center(%{rect | x: x, y: y})}

    {:noreply, show_proximity(socket, closest_pair(flow, moving))}
  end

  def handle_event("lf:node_change", %{"changes" => changes} = params, socket) do
    {:noreply, socket} = FlowEvents.handle_event("lf:node_change", params, socket)

    dropped =
      for %{"type" => "position", "id" => id, "dragging" => false} <- changes, do: id

    # Only drags that showed a temporary edge connect (keyboard nudges also
    # send dragging: false)
    if dropped != [] and socket.assigns.proximity do
      {:noreply, connect_on_drop(socket, dropped)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("clear_edges", _params, socket) do
    flow = socket.assigns.flow

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, State.remove_edges(flow, Map.keys(flow.edges)))
     |> FlowEvents.log("clear_edges", %{})}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Proximity =====

  # The closest {moving node, other node} pair under @min_distance, as
  # %{source, target, near, distance} with the left node as source.
  defp closest_pair(_flow, []), do: nil

  defp closest_pair(flow, moving) do
    moving_ids = MapSet.new(moving, &elem(&1, 0))

    others =
      for {id, node} <- flow.nodes,
          not node.hidden and not MapSet.member?(moving_ids, id),
          do: {id, center(State.node_rect(flow, node))}

    pairs =
      for {moving_id, {mx, my}} <- moving,
          {other_id, {ox, oy}} <- others,
          distance = :math.sqrt((mx - ox) ** 2 + (my - oy) ** 2),
          distance < @min_distance,
          do: {distance, moving_id, mx, other_id, ox}

    case pairs do
      [] ->
        nil

      pairs ->
        {distance, moving_id, mx, other_id, ox} = Enum.min_by(pairs, &elem(&1, 0))

        {source, target} =
          if mx <= ox, do: {moving_id, other_id}, else: {other_id, moving_id}

        %{source: source, target: target, near: other_id, distance: round(distance)}
    end
  end

  defp center(%{x: x, y: y, width: w, height: h}), do: {x + w / 2, y + h / 2}

  defp show_proximity(socket, proximity) do
    previous = socket.assigns.proximity

    if same_pair?(previous, proximity) do
      # Only the distance changed: don't touch the flow
      assign(socket, :proximity, proximity)
    else
      flow = State.remove_edge(socket.assigns.flow, @temp_id)

      flow =
        if proximity && not connected?(flow, proximity.source, proximity.target),
          do: State.add_edge(flow, temp_edge(proximity)),
          else: flow

      assign(socket,
        flow: highlight(flow, proximity && proximity.near),
        proximity: proximity
      )
    end
  end

  defp same_pair?(nil, nil), do: true

  defp same_pair?(%{} = a, %{} = b),
    do: {a.source, a.target, a.near} == {b.source, b.target, b.near}

  defp same_pair?(_a, _b), do: false

  defp connect_on_drop(socket, dropped) do
    flow =
      socket.assigns.flow
      |> State.remove_edge(@temp_id)
      |> highlight(nil)

    moving =
      for id <- dropped, %{} = rect <- [State.node_rect(flow, id)], do: {id, center(rect)}

    case closest_pair(flow, moving) do
      %{source: source, target: target} = pair ->
        if connected?(flow, source, target) do
          assign(socket, flow: flow, proximity: nil)
        else
          edge =
            Edge.new("e-#{source}-#{target}", source, target, marker_end: %{type: :arrow_closed})

          socket
          |> assign(flow: State.add_edge(flow, edge), proximity: nil)
          |> FlowEvents.log("proximity_connect", Map.take(pair, [:source, :target, :distance]))
        end

      nil ->
        assign(socket, flow: flow, proximity: nil)
    end
  end

  defp connected?(flow, a, b) do
    State.edge_exists?(flow, a, b) or State.edge_exists?(flow, b, a)
  end

  defp temp_edge(%{source: source, target: target}) do
    Edge.new(@temp_id, source, target,
      class: "temp",
      selectable: false,
      deletable: false,
      marker_end: %{type: :none}
    )
  end

  # Only the nodes whose class changes are re-rendered
  defp highlight(flow, near_id) do
    nodes =
      Map.new(flow.nodes, fn {id, node} ->
        {id, %{node | class: if(id == near_id, do: "proximity-near")}}
      end)

    %{flow | nodes: nodes}
  end

  defp label(flow, id) do
    case State.get_node(flow, id) do
      %Node{data: %{label: label}} -> label
      _ -> id
    end
  end

  # ===== Initial graph =====

  defp build_flow do
    nodes =
      for {id, x, y, color} <- [
            {"1", 0, 0, "#0ea5e9"},
            {"2", 340, -40, "#8b5cf6"},
            {"3", 60, 200, "#10b981"},
            {"4", 420, 180, "#f59e0b"},
            {"5", 760, 40, "#f43f5e"},
            {"6", 720, 260, "#64748b"}
          ] do
        Node.new(id, %{x: x, y: y}, %{label: "Node #{id}", color: color}, type: :dot)
      end

    edges = [Edge.new("e-1-2", "1", "2", marker_end: %{type: :arrow_closed})]

    State.new(nodes: nodes, edges: edges)
  end
end

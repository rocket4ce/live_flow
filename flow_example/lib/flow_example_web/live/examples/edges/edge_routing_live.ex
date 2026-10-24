defmodule FlowExampleWeb.Examples.Edges.EdgeRoutingLive do
  @moduledoc """
  Edge Routing: orthogonal edges routed around the nodes.

  The React Flow original uses libavoid (WASM). Here the router is plain
  Elixir: the node rectangles (expanded by a margin) and the edge ports build
  a sparse orthogonal visibility grid, A* (cost = length + bend penalty) finds
  a path that avoids every node, and a custom edge renderer draws it with
  rounded corners. Routes are stored in `edge.data.route` and recomputed on
  `lf:drag_move` (live, with the dragged absolute positions) and whenever the
  geometry changes.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, Handle, Node, State}
  alias LiveFlow.Paths.Geometry

  @default_width 100
  @default_height 40
  @max_expansions 30_000
  @settings %{"margin" => "20", "radius" => "10", "bend" => "60"}

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)
    settings = parse_settings(@settings)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(settings: settings, form: to_form(@settings, as: :routing), stats: nil)
     |> FlowEvents.assign_flow(build_flow())
     |> assign(:edge_opts, type: :routed, marker_end: %{type: :arrow_closed})
     |> reroute()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #edge-routing-flow .routed-edge .lf-edge {
        stroke-linejoin: round;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="edge-routing-flow"
        flow={@flow}
        node_types={FlowNodes.types()}
        edge_types={%{routed: &routed_edge/1}}
        opts={
          %{
            background: :lines,
            background_gap: 32,
            controls: true,
            minimap: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.15},
            connection_line_type: :step
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Drag the nodes: every edge is re-routed around all of them while you drag (from the
            <code>lf:drag_move</code>
            positions) and again after the drop. Connect two handles to route a new edge.
          </.hint>
          <.hint>
            The router lives in this LiveView: node rectangles expanded by the margin, plus the
            ports, give the x / y lines of a sparse orthogonal grid. A* searches it with <i>cost = length + bends × penalty</i>; the result goes to
            <code>edge.data.route</code>
            and a custom edge type draws it with rounded corners.
          </.hint>
          <.hint>
            The original example uses libavoid (C++ compiled to WASM), which also nudges parallel
            segments apart; this simpler router lets them overlap.
          </.hint>
        </.option_group>

        <.form for={@form} id="routing-form" phx-change="update_settings">
          <.option_group title="Router">
            <.range field={@form[:margin]} label="Node margin" min="4" max="48" />
            <.range field={@form[:radius]} label="Corner radius" min="0" max="24" />
            <.range field={@form[:bend]} label="Bend penalty" min="0" max="200" step="10" />
          </.option_group>
        </.form>

        <.option_group :if={@stats} title="Last routing">
          <div class="grid grid-cols-2 gap-2">
            <div class="rounded-lg bg-base-200/70 px-3 py-2">
              <p class="text-[11px] text-base-content/50">Edges</p>
              <p id="routed-count" class="font-mono text-lg font-semibold">{@stats.edges}</p>
            </div>
            <div class="rounded-lg bg-base-200/70 px-3 py-2">
              <p class="text-[11px] text-base-content/50">Time</p>
              <p id="routing-time" class="font-mono text-lg font-semibold">
                {:erlang.float_to_binary(@stats.ms, decimals: 1)} ms
              </p>
            </div>
          </div>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  defp routed_edge(assigns) do
    route = Map.get(assigns.edge.data, :route)
    radius = Map.get(assigns.edge.data, :radius, 10)
    assigns = assign(assigns, :d, if(route, do: rounded_path(route, radius), else: assigns.path))

    ~H"""
    <g class="routed-edge" data-edge-id={@edge.id}>
      <path class="lf-edge-interaction" d={@d} data-edge-id={@edge.id} />
      <path
        class="lf-edge"
        d={@d}
        data-edge-id={@edge.id}
        data-selected={to_string(@edge.selected)}
        data-animated={to_string(@edge.animated)}
        marker-end={@marker_end_id}
      />
    </g>
    """
  end

  @impl true
  def handle_event("update_settings", %{"routing" => params}, socket) do
    params = Map.merge(@settings, params)

    {:noreply,
     socket
     |> assign(settings: parse_settings(params), form: to_form(params, as: :routing))
     |> reroute()}
  end

  # Live re-routing while dragging (absolute positions of the moving nodes)
  def handle_event("lf:drag_move", %{"changes" => changes}, socket) do
    overrides =
      for %{"id" => id, "position" => %{"x" => x, "y" => y}} <- changes, into: %{} do
        {id, %{x: x, y: y}}
      end

    {:noreply, reroute(socket, overrides)}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    before = geometry(socket.assigns.flow)
    {:noreply, socket} = FlowEvents.handle_event(event, params, socket)

    # Undo/redo restore routes computed with the settings of that time
    if geometry(socket.assigns.flow) == before and event not in ~w(lf:undo lf:redo),
      do: {:noreply, socket},
      else: {:noreply, reroute(socket)}
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp reroute(socket, overrides \\ %{}) do
    {micros, flow} =
      :timer.tc(fn -> route_edges(socket.assigns.flow, socket.assigns.settings, overrides) end)

    assign(socket,
      flow: flow,
      stats: %{ms: micros / 1000, edges: map_size(flow.edges)}
    )
  end

  # What routing depends on: node boxes and edge endpoints
  defp geometry(%State{} = flow) do
    nodes =
      Map.new(flow.nodes, fn {id, n} -> {id, {n.position, n.width, n.height, n.hidden}} end)

    edges =
      Map.new(flow.edges, fn {id, e} ->
        {id, {e.source, e.target, e.source_handle, e.target_handle}}
      end)

    {nodes, edges}
  end

  defp parse_settings(params) do
    int = fn key -> params |> Map.fetch!(key) |> to_string() |> Integer.parse() |> elem(0) end
    %{margin: max(int.("margin"), 1), radius: int.("radius"), bend: int.("bend")}
  end

  # ===== Router =====

  @doc """
  Routes every edge of `flow` around all visible nodes and stores the points
  in `edge.data.route`. `overrides` maps node ids to absolute positions that
  win over the stored ones (nodes being dragged).
  """
  def route_edges(%State{} = flow, settings, overrides \\ %{}) do
    nodes =
      flow
      |> State.absolute_nodes()
      |> Map.reject(fn {_id, node} -> node.hidden end)
      |> Map.new(fn {id, node} ->
        case overrides do
          %{^id => %{x: x, y: y}} -> {id, %{node | position: %{x: x, y: y}}}
          _ -> {id, node}
        end
      end)

    obstacles = nodes |> Map.values() |> Enum.map(&expand(rect(&1), settings.margin))

    edges =
      Map.new(flow.edges, fn {id, edge} ->
        route =
          case {nodes[edge.source], nodes[edge.target]} do
            {%Node{} = source, %Node{} = target} ->
              route_edge(edge, source, target, obstacles, settings)

            _ ->
              nil
          end

        {id, %{edge | data: Map.merge(edge.data, %{route: route, radius: settings.radius})}}
      end)

    %{flow | edges: edges}
  end

  defp route_edge(%Edge{} = edge, source, target, obstacles, settings) do
    {s, s_side} = Geometry.handle_point(source, target, edge.source_handle, :source, false)
    {t, t_side} = Geometry.handle_point(target, source, edge.target_handle, :target, false)

    s = to_point(s)
    t = to_point(t)
    s_out = step(s, step_vector(direction(s_side)), settings.margin)
    t_out = step(t, step_vector(direction(t_side)), settings.margin)

    # Ports squeezed inside another node's margin: ignore that obstacle
    obstacles = Enum.reject(obstacles, &(inside?(&1, s_out) or inside?(&1, t_out)))

    middle =
      case astar(
             s_out,
             direction(s_side),
             t_out,
             opposite(direction(t_side)),
             obstacles,
             settings
           ) do
        {:ok, points} -> points
        :error -> fallback(s_out, t_out, s_side)
      end

    simplify([s | middle] ++ [t])
  end

  defp fallback({sx, sy} = s_out, {tx, ty} = t_out, side) when side in [:left, :right] do
    mid = (sx + tx) / 2
    [s_out, {mid, sy}, {mid, ty}, t_out]
  end

  defp fallback({sx, sy} = s_out, {tx, ty} = t_out, _side) do
    mid = (sy + ty) / 2
    [s_out, {sx, mid}, {tx, mid}, t_out]
  end

  # A* over the sparse grid. States are {ix, iy, direction}; reaching the
  # target port also costs a bend when arriving in the wrong direction.
  defp astar({sx, sy}, s_dir, {tx, ty}, t_dir, obstacles, settings) do
    xs = grid_lines(obstacles, 0, 2, [sx, tx])
    ys = grid_lines(obstacles, 1, 3, [sy, ty])
    xi = xs |> Tuple.to_list() |> Enum.with_index() |> Map.new()
    yi = ys |> Tuple.to_list() |> Enum.with_index() |> Map.new()

    grid = %{
      xs: xs,
      ys: ys,
      goal: {Map.fetch!(xi, tx), Map.fetch!(yi, ty)},
      t_dir: t_dir,
      target: {tx, ty},
      obstacles: obstacles,
      bend: settings.bend
    }

    start = {Map.fetch!(xi, sx), Map.fetch!(yi, sy), s_dir}
    h = heuristic(grid, start)

    search(
      :gb_sets.singleton({h, 0, start}),
      %{start => 0},
      %{},
      grid,
      1,
      0
    )
  end

  defp search(open, g_score, parents, grid, counter, expansions) do
    cond do
      :gb_sets.is_empty(open) or expansions > @max_expansions ->
        :error

      true ->
        {{f, _, state}, open} = :gb_sets.take_smallest(open)

        cond do
          state == :goal ->
            {:ok, reconstruct(parents, Map.fetch!(parents, :goal), grid, [])}

          f > Map.fetch!(g_score, state) + heuristic(grid, state) + 1.0e-6 ->
            # Stale queue entry
            search(open, g_score, parents, grid, counter, expansions)

          true ->
            g = Map.fetch!(g_score, state)

            {open, g_score, parents, counter} =
              state
              |> successors(g, grid)
              |> Enum.reduce({open, g_score, parents, counter}, fn {next, cost},
                                                                   {open, gs, ps, c} ->
                if cost < Map.get(gs, next, :infinity) do
                  f = cost + heuristic(grid, next)

                  {:gb_sets.add({f, c, next}, open), Map.put(gs, next, cost),
                   Map.put(ps, next, state), c + 1}
                else
                  {open, gs, ps, c}
                end
              end)

            search(open, g_score, parents, grid, counter, expansions + 1)
        end
    end
  end

  defp successors({ix, iy, dir} = _state, g, grid) do
    moves =
      for next_dir <- [:right, :left, :down, :up],
          next_dir != opposite(dir),
          {nx, ny} = advance(ix, iy, next_dir),
          nx >= 0 and ny >= 0 and nx < tuple_size(grid.xs) and ny < tuple_size(grid.ys),
          a = {elem(grid.xs, ix), elem(grid.ys, iy)},
          b = {elem(grid.xs, nx), elem(grid.ys, ny)},
          clear?(a, b, grid.obstacles) do
        cost = g + distance(a, b) + if(next_dir == dir, do: 0, else: grid.bend)
        {{nx, ny, next_dir}, cost}
      end

    # The virtual goal: leave the target port in the entry direction
    if {ix, iy} == grid.goal do
      [{:goal, g + if(dir == grid.t_dir, do: 0, else: grid.bend)} | moves]
    else
      moves
    end
  end

  defp heuristic(_grid, :goal), do: 0

  defp heuristic(grid, {ix, iy, _dir}) do
    {tx, ty} = grid.target
    abs(elem(grid.xs, ix) - tx) + abs(elem(grid.ys, iy) - ty)
  end

  defp reconstruct(parents, {ix, iy, _} = state, grid, acc) do
    acc = [{elem(grid.xs, ix), elem(grid.ys, iy)} | acc]

    case Map.fetch(parents, state) do
      {:ok, parent} -> reconstruct(parents, parent, grid, acc)
      :error -> acc
    end
  end

  # Sorted, unique grid lines: obstacle borders, ports and the middle of
  # every gap (so routes can run down the center of channels)
  defp grid_lines(obstacles, low, high, ports) do
    base =
      obstacles
      |> Enum.flat_map(&[elem(&1, low), elem(&1, high)])
      |> Kernel.++(ports)
      |> Enum.uniq()
      |> Enum.sort()

    middles =
      base
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> (a + b) / 2 end)

    (base ++ middles) |> Enum.uniq() |> Enum.sort() |> List.to_tuple()
  end

  # Grid neighbors are consecutive lines, so a segment crosses an obstacle
  # exactly when its middle point is strictly inside it
  defp clear?({ax, ay}, {bx, by}, obstacles) do
    mid = {(ax + bx) / 2, (ay + by) / 2}
    not Enum.any?(obstacles, &inside?(&1, mid))
  end

  defp inside?({x1, y1, x2, y2}, {x, y}) do
    x > x1 + 1.0e-6 and x < x2 - 1.0e-6 and y > y1 + 1.0e-6 and y < y2 - 1.0e-6
  end

  defp rect(%Node{position: %{x: x, y: y}} = node) do
    x = x / 1
    y = y / 1
    {x, y, x + (node.width || @default_width), y + (node.height || @default_height)}
  end

  defp expand({x1, y1, x2, y2}, m), do: {x1 - m, y1 - m, x2 + m, y2 + m}

  defp to_point(%{x: x, y: y}), do: {x / 1, y / 1}

  defp step({x, y}, {dx, dy}, m), do: {x + dx * m, y + dy * m}

  defp direction(:right), do: :right
  defp direction(:left), do: :left
  defp direction(:top), do: :up
  defp direction(:bottom), do: :down

  defp step_vector(:right), do: {1, 0}
  defp step_vector(:left), do: {-1, 0}
  defp step_vector(:up), do: {0, -1}
  defp step_vector(:down), do: {0, 1}

  defp advance(ix, iy, dir) do
    {dx, dy} = step_vector(dir)
    {ix + dx, iy + dy}
  end

  defp opposite(:right), do: :left
  defp opposite(:left), do: :right
  defp opposite(:up), do: :down
  defp opposite(:down), do: :up

  defp distance({ax, ay}, {bx, by}), do: abs(ax - bx) + abs(ay - by)

  # Drops duplicate and collinear points
  defp simplify(points) do
    points
    |> Enum.dedup()
    |> Enum.reduce([], fn
      point, [b, a | rest] = acc ->
        if collinear?(a, b, point), do: [point, a | rest], else: [point | acc]

      point, acc ->
        [point | acc]
    end)
    |> Enum.reverse()
  end

  defp collinear?({ax, ay}, {bx, by}, {cx, cy}) do
    (ax == bx and bx == cx) or (ay == by and by == cy)
  end

  # Polyline with quadratic corners of `radius` (clamped to half the segments)
  defp rounded_path([{x0, y0} | _] = points, radius) do
    corners =
      points
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.map(fn [{ax, ay}, {bx, by}, {cx, cy}] ->
        r = Enum.min([radius, distance({ax, ay}, {bx, by}) / 2, distance({bx, by}, {cx, cy}) / 2])
        {ux, uy} = unit({bx - ax, by - ay})
        {vx, vy} = unit({cx - bx, cy - by})

        if r <= 0 do
          "L #{fmt(bx)} #{fmt(by)}"
        else
          "L #{fmt(bx - ux * r)} #{fmt(by - uy * r)} Q #{fmt(bx)} #{fmt(by)} " <>
            "#{fmt(bx + vx * r)} #{fmt(by + vy * r)}"
        end
      end)

    {xn, yn} = List.last(points)
    Enum.join(["M #{fmt(x0)} #{fmt(y0)}" | corners] ++ ["L #{fmt(xn)} #{fmt(yn)}"], " ")
  end

  defp unit({dx, dy}) do
    length = :math.sqrt(dx * dx + dy * dy)
    if length == 0, do: {0, 0}, else: {dx / length, dy / length}
  end

  defp fmt(value), do: :erlang.float_to_binary(value / 1, decimals: 1)

  defp build_flow do
    card = fn id, x, y, title, subtitle, icon, color, opts ->
      Samples.card(id, x, y, title, subtitle, icon, color, [width: 224, height: 58] ++ opts)
    end

    nodes = [
      card.("web", 0, 40, "Web app", "browser", "hero-globe-alt", :sky, inputs: false),
      card.("mobile", 0, 330, "Mobile app", "iOS & Android", "hero-device-phone-mobile", :sky,
        inputs: false
      ),
      card.("auth", 380, -80, "Auth", "OAuth provider", "hero-key", :amber, []),
      card.("gateway", 380, 185, "API gateway", "rate limits", "hero-server-stack", :violet, []),
      card.("queue", 380, 450, "Queue", "background jobs", "hero-queue-list", :slate, []),
      card.("orders", 780, 40, "Orders", "service", "hero-shopping-cart", :emerald, []),
      card.("billing", 780, 330, "Billing", "service", "hero-credit-card", :emerald, []),
      card.("db", 1180, 185, "Database", "PostgreSQL", "hero-circle-stack", :rose,
        outputs: false,
        handles: [Handle.target(:left), Handle.target(:bottom, id: "bottom")]
      )
    ]

    edge = fn source, target, opts ->
      Edge.new(
        "#{source}-#{target}",
        source,
        target,
        [type: :routed, marker_end: %{type: :arrow_closed}] ++ opts
      )
    end

    edges = [
      edge.("web", "gateway", []),
      edge.("mobile", "gateway", []),
      edge.("gateway", "orders", []),
      edge.("gateway", "billing", []),
      edge.("orders", "db", []),
      edge.("billing", "db", []),
      edge.("web", "billing", animated: true),
      edge.("auth", "queue", []),
      edge.("queue", "db", target_handle: "bottom")
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

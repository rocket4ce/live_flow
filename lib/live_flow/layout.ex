defmodule LiveFlow.Layout do
  @moduledoc """
  Layout helpers.

  * Server-side layouts written in Elixir: `tree/2` (layered, like dagre or
    d3-hierarchy), `force/2` (force-directed, like d3-force) and
    `resolve_collisions/2`. They return `%{node_id => %{x: x, y: y}}`, which
    can be applied with `apply_positions/2` or animated with
    `LiveFlow.animate_positions/5`.
  * `prepare_layout_data/2` / `prepare_tree_layout_data/2` send data to the
    client-side engines (ELK and the JS tree layout). ELK is optional and not
    bundled: add it with `mix live_flow.gen.elk`.

  Layouts work on top-level nodes by default (child nodes keep their
  position relative to their parent). Pass `nodes: ids` to restrict them.
  """

  alias LiveFlow.{Node, State}

  @default_width 150
  @default_height 50

  @doc """
  Prepares serializable layout data from the current flow state.

  Returns a map with `nodes` (list of id/width/height maps) and
  `edges` (list of id/source/target maps) suitable for sending
  to the client-side ELK layout engine via `push_event`. The app must
  register ELK first (`mix live_flow.gen.elk`).

  ## Options (string keys, e.g. straight from event params)

    * `"direction"` - `"DOWN"`, `"RIGHT"`, `"UP"` or `"LEFT"` (default: `"DOWN"`)
    * `"options"` - Extra ELK layout options, e.g. `%{"elk.algorithm" => "mrtree"}`
    * `"flow_id"` - Only the flow with this DOM id runs the layout

  ## Examples

      push_event(socket, "lf:layout_data", Layout.prepare_layout_data(flow, %{"direction" => "RIGHT"}))
  """
  @spec prepare_layout_data(State.t(), map()) :: map()
  def prepare_layout_data(%State{} = flow, opts \\ %{}) do
    nodes =
      flow.nodes
      |> Map.values()
      |> Enum.map(fn node ->
        %{
          id: node.id,
          width: node.width || @default_width,
          height: node.height || @default_height,
          # Handles are sent as ELK ports (fixed side) to reduce crossings
          ports:
            Enum.map(node.handles, fn handle ->
              %{id: LiveFlow.Handle.effective_id(handle), side: port_side(handle.position)}
            end)
        }
      end)

    edges =
      flow.edges
      |> Map.values()
      |> Enum.map(fn edge ->
        %{
          id: edge.id,
          source: edge.source,
          target: edge.target,
          source_handle: edge.source_handle,
          target_handle: edge.target_handle
        }
      end)

    %{
      nodes: nodes,
      edges: edges,
      direction: Map.get(opts, "direction", "DOWN"),
      options: Map.get(opts, "options", %{}),
      flow_id: Map.get(opts, "flow_id")
    }
  end

  defp port_side(:top), do: "NORTH"
  defp port_side(:bottom), do: "SOUTH"
  defp port_side(:left), do: "WEST"
  defp port_side(:right), do: "EAST"

  @doc """
  Prepares serializable layout data for the client-side tree layout algorithm.

  Similar to `prepare_layout_data/2` but outputs options compatible with
  the pure JS tree layout engine (direction: TB/LR, nodeSpacing, levelSpacing).
  Push it as `lf:tree_layout_data`; no ELK needed.

  ## Options (string keys)

    * `"direction"` - `"TB"` or `"LR"` (default: `"TB"`)
    * `"flow_id"` - Only the flow with this DOM id runs the layout
  """
  @spec prepare_tree_layout_data(State.t(), map()) :: map()
  def prepare_tree_layout_data(%State{} = flow, opts \\ %{}) do
    nodes =
      flow.nodes
      |> Map.values()
      |> Enum.map(fn node ->
        %{
          id: node.id,
          width: node.width || @default_width,
          height: node.height || @default_height
        }
      end)

    edges =
      flow.edges
      |> Map.values()
      |> Enum.map(fn edge ->
        %{
          id: edge.id,
          source: edge.source,
          target: edge.target
        }
      end)

    %{
      nodes: nodes,
      edges: edges,
      options: %{
        direction: Map.get(opts, "direction", "TB"),
        nodeSpacing: 80,
        levelSpacing: 120
      },
      flow_id: Map.get(opts, "flow_id")
    }
  end

  # ===========================================================================
  # Server-side layouts
  # ===========================================================================

  @doc """
  Applies a `%{id => %{x, y}}` map (or list of `{id, position}`) to the flow.
  """
  @spec apply_positions(State.t(), map() | list()) :: State.t()
  def apply_positions(%State{} = flow, positions) do
    Enum.reduce(positions, flow, fn {id, %{x: x, y: y}}, acc ->
      State.update_node(acc, id, fn node -> %{node | position: %{x: x * 1.0, y: y * 1.0}} end)
    end)
  end

  @doc """
  Layered layout for trees and DAGs (similar to dagre / d3-hierarchy).

  Nodes are ranked by their longest path from a root, ordered inside each
  rank to reduce crossings, and placed close to the center of their parents.

  ## Options

    * `:direction` - `:tb` (top to bottom) or `:lr` (left to right) (default: `:tb`)
    * `:node_spacing` - Space between nodes of the same rank (default: `40`)
    * `:rank_spacing` - Space between ranks (default: `80`)
    * `:nodes` - Only lay out these node IDs (default: top-level nodes)
    * `:origin` - `{x, y}` of the top-left corner (default: `{0, 0}`)
  """
  @spec tree(State.t(), keyword()) :: %{String.t() => %{x: float(), y: float()}}
  def tree(%State{} = flow, opts \\ []) do
    direction = Keyword.get(opts, :direction, :tb)
    node_spacing = Keyword.get(opts, :node_spacing, 40)
    rank_spacing = Keyword.get(opts, :rank_spacing, 80)
    {origin_x, origin_y} = Keyword.get(opts, :origin, {0, 0})

    nodes = layout_nodes(flow, opts)
    ids = Enum.map(nodes, & &1.id)
    id_set = MapSet.new(ids)
    by_id = Map.new(nodes, &{&1.id, &1})

    edges =
      flow.edges
      |> Map.values()
      |> Enum.filter(&(MapSet.member?(id_set, &1.source) and MapSet.member?(id_set, &1.target)))
      |> Enum.reject(&(&1.source == &1.target))

    parents = Enum.group_by(edges, & &1.target, & &1.source)
    children = Enum.group_by(edges, & &1.source, & &1.target)

    ranks = rank_nodes(ids, parents, children)
    layers = ranks |> Enum.group_by(fn {_id, rank} -> rank end, fn {id, _} -> id end)
    max_rank = layers |> Map.keys() |> Enum.max(fn -> 0 end)

    # Initial order: order of appearance, then barycenter sweeps
    layers =
      Map.new(layers, fn {rank, layer_ids} ->
        {rank, Enum.sort_by(layer_ids, &Enum.find_index(ids, fn id -> id == &1 end))}
      end)

    layers = order_layers(layers, max_rank, parents, children)

    # Size along the "breadth" (across ranks) and "depth" (rank) axes
    {breadth, depth} =
      case direction do
        :lr -> {&node_height/1, &node_width/1}
        _ -> {&node_width/1, &node_height/1}
      end

    # Rank offsets
    {rank_offsets, _} =
      Enum.map_reduce(0..max_rank, 0, fn rank, offset ->
        size =
          layers |> Map.get(rank, []) |> Enum.map(&depth.(by_id[&1])) |> Enum.max(fn -> 0 end)

        {{rank, offset}, offset + size + rank_spacing}
      end)

    rank_offsets = Map.new(rank_offsets)

    # Breadth coordinates (centers): top-down placement under the parents,
    # then a bottom-up pass to center parents over their children
    centers =
      Enum.reduce(0..max_rank, %{}, fn rank, acc ->
        place_layer(Map.get(layers, rank, []), acc, parents, by_id, breadth, node_spacing)
      end)

    centers =
      Enum.reduce(max_rank..0//-1, centers, fn rank, acc ->
        place_layer(Map.get(layers, rank, []), acc, children, by_id, breadth, node_spacing)
      end)

    min_center =
      centers
      |> Enum.map(fn {id, c} -> c - breadth.(by_id[id]) / 2 end)
      |> Enum.min(fn -> 0 end)

    Map.new(ranks, fn {id, rank} ->
      node = by_id[id]
      b = centers[id] - breadth.(node) / 2 - min_center
      d = rank_offsets[rank]

      case direction do
        :lr ->
          {id, %{x: Float.round(origin_x + d * 1.0, 2), y: Float.round(origin_y + b * 1.0, 2)}}

        _ ->
          {id, %{x: Float.round(origin_x + b * 1.0, 2), y: Float.round(origin_y + d * 1.0, 2)}}
      end
    end)
  end

  # Longest path ranking: back edges (cycles) found with a DFS are ignored,
  # then ranks are assigned in topological order (Kahn)
  defp rank_nodes(ids, _parents, children) do
    back = back_edges(ids, children)

    dag_children =
      Map.new(children, fn {source, targets} ->
        {source, Enum.reject(targets, &MapSet.member?(back, {source, &1}))}
      end)

    indegree =
      Enum.reduce(dag_children, Map.new(ids, &{&1, 0}), fn {_source, targets}, acc ->
        Enum.reduce(targets, acc, fn target, acc -> Map.update!(acc, target, &(&1 + 1)) end)
      end)

    roots = Enum.filter(ids, &(indegree[&1] == 0))
    ranks = kahn(roots, indegree, dag_children, Map.new(roots, &{&1, 0}))
    Enum.reduce(ids, ranks, fn id, acc -> Map.put_new(acc, id, 0) end)
  end

  defp back_edges(ids, children) do
    {_state, back} =
      Enum.reduce(ids, {%{}, MapSet.new()}, fn id, {state, back} ->
        if Map.has_key?(state, id), do: {state, back}, else: dfs(id, children, state, back)
      end)

    back
  end

  defp dfs(id, children, state, back) do
    state = Map.put(state, id, :active)

    {state, back} =
      children
      |> Map.get(id, [])
      |> Enum.reduce({state, back}, fn child, {state, back} ->
        case Map.get(state, child) do
          :active -> {state, MapSet.put(back, {id, child})}
          :done -> {state, back}
          nil -> dfs(child, children, state, back)
        end
      end)

    {Map.put(state, id, :done), back}
  end

  defp kahn([], _indegree, _children, ranks), do: ranks

  defp kahn([id | rest], indegree, children, ranks) do
    rank = Map.fetch!(ranks, id)

    {indegree, ranks, queue} =
      children
      |> Map.get(id, [])
      |> Enum.reduce({indegree, ranks, rest}, fn child, {indegree, ranks, queue} ->
        indegree = Map.update!(indegree, child, &(&1 - 1))
        ranks = Map.update(ranks, child, rank + 1, &max(&1, rank + 1))
        queue = if indegree[child] == 0, do: queue ++ [child], else: queue
        {indegree, ranks, queue}
      end)

    kahn(queue, indegree, children, ranks)
  end

  defp order_layers(layers, max_rank, parents, children) do
    Enum.reduce(1..4, layers, fn _, acc ->
      acc = Enum.reduce(1..max(max_rank, 1)//1, acc, &barycenter(&2, &1, &1 - 1, parents))
      Enum.reduce((max_rank - 1)..0//-1, acc, &barycenter(&2, &1, &1 + 1, children))
    end)
  end

  defp barycenter(layers, rank, neighbor_rank, neighbors) do
    case {Map.get(layers, rank), Map.get(layers, neighbor_rank)} do
      {nil, _} ->
        layers

      {_, nil} ->
        layers

      {layer, neighbor_layer} ->
        index = neighbor_layer |> Enum.with_index() |> Map.new()

        sorted =
          layer
          |> Enum.with_index()
          |> Enum.sort_by(fn {id, i} ->
            positions =
              neighbors
              |> Map.get(id, [])
              |> Enum.map(&Map.get(index, &1))
              |> Enum.reject(&is_nil/1)

            if positions == [], do: i, else: Enum.sum(positions) / length(positions)
          end)
          |> Enum.map(&elem(&1, 0))

        Map.put(layers, rank, sorted)
    end
  end

  # Places a layer: each node wants to sit at the mean center of its
  # neighbors; overlaps are resolved left to right keeping the layer order.
  defp place_layer([], centers, _neighbors, _by_id, _breadth, _spacing), do: centers

  defp place_layer(layer, centers, neighbors, by_id, breadth, spacing) do
    hints =
      Enum.map(layer, fn id ->
        placed =
          neighbors
          |> Map.get(id, [])
          |> Enum.map(&Map.get(centers, &1))
          |> Enum.reject(&is_nil/1)

        cond do
          placed != [] -> Enum.sum(placed) / length(placed)
          Map.has_key?(centers, id) -> centers[id]
          true -> nil
        end
      end)

    # Sequential placement when nothing hints a position yet
    desired =
      if Enum.all?(hints, &is_nil/1) do
        {list, _} =
          Enum.map_reduce(layer, 0, fn id, x ->
            w = breadth.(by_id[id])
            {x + w / 2, x + w + spacing}
          end)

        list
      else
        fallback = hints |> Enum.reject(&is_nil/1) |> then(&(Enum.sum(&1) / length(&1)))
        Enum.map(hints, &(&1 || fallback))
      end

    # Resolve overlaps keeping the order: adjacent blocks that overlap are
    # merged and each block sits at the mean of its members' desired centers
    # (pool adjacent violators: least squares with minimum spacing)
    widths = Enum.map(layer, &breadth.(by_id[&1]))

    layer
    |> Enum.zip(widths)
    |> Enum.zip(desired)
    |> Enum.reduce([], fn {{id, width}, want}, blocks ->
      merge_blocks([%{members: [{id, 0.0, width, want}], ref: want} | blocks], spacing)
    end)
    |> Enum.reduce(centers, fn block, acc ->
      Enum.reduce(block.members, acc, fn {id, offset, _w, _want}, acc ->
        Map.put(acc, id, block.ref + offset)
      end)
    end)
  end

  # Blocks are kept in reverse order (newest first)
  defp merge_blocks([current, previous | rest] = blocks, spacing) do
    {_, prev_offset, prev_width, _} = List.last(previous.members)
    [{_, _, cur_width, _} | _] = current.members
    prev_right = previous.ref + prev_offset + prev_width / 2
    cur_left = current.ref - cur_width / 2

    if prev_right + spacing > cur_left do
      shift = prev_offset + prev_width / 2 + spacing + cur_width / 2

      members =
        previous.members ++
          Enum.map(current.members, fn {id, offset, w, want} -> {id, offset + shift, w, want} end)

      ref =
        Enum.sum(Enum.map(members, fn {_, offset, _, want} -> want - offset end)) /
          length(members)

      merge_blocks([%{members: members, ref: ref} | rest], spacing)
    else
      blocks
    end
  end

  defp merge_blocks(blocks, _spacing), do: blocks

  @doc """
  Force-directed layout (Fruchterman-Reingold), similar to d3-force.

  Starts from the current positions and is deterministic.

  ## Options

    * `:iterations` - Simulation steps (default: `300`)
    * `:distance` - Ideal edge length (default: `200`)
    * `:fixed` - Node IDs that keep their position (default: `[]`)
    * `:nodes` - Only lay out these node IDs (default: top-level nodes)
  """
  @spec force(State.t(), keyword()) :: %{String.t() => %{x: float(), y: float()}}
  def force(%State{} = flow, opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 300)
    k = Keyword.get(opts, :distance, 200) * 1.0
    fixed = MapSet.new(Keyword.get(opts, :fixed, []))

    nodes = layout_nodes(flow, opts)
    ids = MapSet.new(nodes, & &1.id)

    edges =
      flow.edges
      |> Map.values()
      |> Enum.filter(&(MapSet.member?(ids, &1.source) and MapSet.member?(ids, &1.target)))
      |> Enum.reject(&(&1.source == &1.target))

    sizes = Map.new(nodes, &{&1.id, {node_width(&1), node_height(&1)}})

    # Centers; nodes stacked on the same point get a small deterministic offset
    centers =
      nodes
      |> Enum.with_index()
      |> Map.new(fn {node, i} ->
        {w, h} = sizes[node.id]
        jitter = :math.sin(i * 12.9898) * 0.5
        {node.id, {node.position.x + w / 2 + jitter, node.position.y + h / 2 + jitter}}
      end)

    temperature = k
    initial_centroid = centroid(centers)

    centers =
      Enum.reduce(1..iterations//1, {centers, temperature}, fn _, {centers, temp} ->
        disp = Map.new(centers, fn {id, _} -> {id, {0.0, 0.0}} end)
        list = Map.to_list(centers)

        # Repulsion between every pair (stronger when the boxes overlap)
        disp =
          for {{a, {ax, ay}}, i} <- Enum.with_index(list),
              {b, {bx, by}} <- Enum.drop(list, i + 1),
              reduce: disp do
            acc ->
              {dx, dy, dist} = delta(ax, ay, bx, by)
              {aw, ah} = sizes[a]
              {bw, bh} = sizes[b]
              min_dist = (max(aw, ah) + max(bw, bh)) / 2
              force = k * k / dist * if(dist < min_dist, do: 4.0, else: 1.0)
              fx = dx / dist * force
              fy = dy / dist * force

              acc
              |> Map.update!(a, fn {x, y} -> {x + fx, y + fy} end)
              |> Map.update!(b, fn {x, y} -> {x - fx, y - fy} end)
          end

        # Attraction along edges
        disp =
          Enum.reduce(edges, disp, fn edge, acc ->
            {sx, sy} = centers[edge.source]
            {tx, ty} = centers[edge.target]
            {dx, dy, dist} = delta(sx, sy, tx, ty)
            force = dist * dist / k
            fx = dx / dist * force
            fy = dy / dist * force

            acc
            |> Map.update!(edge.source, fn {x, y} -> {x - fx, y - fy} end)
            |> Map.update!(edge.target, fn {x, y} -> {x + fx, y + fy} end)
          end)

        centers =
          Map.new(centers, fn {id, {x, y}} ->
            if MapSet.member?(fixed, id) do
              {id, {x, y}}
            else
              {dx, dy} = disp[id]
              len = max(:math.sqrt(dx * dx + dy * dy), 0.01)
              step = min(len, temp)
              {id, {x + dx / len * step, y + dy / len * step}}
            end
          end)

        {centers, max(temp * 0.97, 1.0)}
      end)
      |> elem(0)

    # Keep the graph where it was (forces don't preserve the centroid)
    {shift_x, shift_y} =
      if MapSet.size(fixed) > 0 do
        {0.0, 0.0}
      else
        {ix, iy} = initial_centroid
        {cx, cy} = centroid(centers)
        {ix - cx, iy - cy}
      end

    Map.new(centers, fn {id, {x, y}} ->
      {w, h} = sizes[id]
      {id, %{x: Float.round(x - w / 2 + shift_x, 2), y: Float.round(y - h / 2 + shift_y, 2)}}
    end)
  end

  defp centroid(centers) when map_size(centers) == 0, do: {0.0, 0.0}

  defp centroid(centers) do
    {sx, sy} =
      Enum.reduce(centers, {0.0, 0.0}, fn {_id, {x, y}}, {ax, ay} -> {ax + x, ay + y} end)

    {sx / map_size(centers), sy / map_size(centers)}
  end

  defp delta(ax, ay, bx, by) do
    dx = ax - bx
    dy = ay - by
    {dx, dy, max(:math.sqrt(dx * dx + dy * dy), 0.01)}
  end

  @doc """
  Moves overlapping nodes apart (siblings only: child nodes are compared
  with the other children of the same parent).

  Returns the new positions of the nodes that moved.

  ## Options

    * `:margin` - Minimum gap between nodes (default: `10`)
    * `:max_iterations` - (default: `50`)
    * `:fixed` - Node IDs that never move, e.g. the node just dropped (default: `[]`)
  """
  @spec resolve_collisions(State.t(), keyword()) :: %{String.t() => %{x: float(), y: float()}}
  def resolve_collisions(%State{} = flow, opts \\ []) do
    margin = Keyword.get(opts, :margin, 10)
    max_iterations = Keyword.get(opts, :max_iterations, 50)
    fixed = MapSet.new(Keyword.get(opts, :fixed, []))

    flow.nodes
    |> Map.values()
    |> Enum.reject(& &1.hidden)
    |> Enum.group_by(& &1.parent_id)
    |> Enum.reduce(%{}, fn {_parent, siblings}, acc ->
      boxes =
        Map.new(siblings, fn n ->
          {n.id, {n.position.x * 1.0, n.position.y * 1.0, node_width(n), node_height(n)}}
        end)

      resolved = collide(boxes, fixed, margin, max_iterations)

      Enum.reduce(resolved, acc, fn {id, {x, y, _, _}}, acc ->
        {ox, oy, _, _} = boxes[id]

        if {x, y} == {ox, oy},
          do: acc,
          else: Map.put(acc, id, %{x: Float.round(x, 2), y: Float.round(y, 2)})
      end)
    end)
  end

  defp collide(boxes, _fixed, _margin, 0), do: boxes

  defp collide(boxes, fixed, margin, iterations) do
    ids = boxes |> Map.keys() |> Enum.sort()

    {boxes, moved?} =
      for {a, i} <- Enum.with_index(ids), b <- Enum.drop(ids, i + 1), reduce: {boxes, false} do
        {acc, moved} ->
          {ax, ay, aw, ah} = acc[a]
          {bx, by, bw, bh} = acc[b]

          overlap_x = min(ax + aw, bx + bw) - max(ax, bx) + margin
          overlap_y = min(ay + ah, by + bh) - max(ay, by) + margin

          if overlap_x > 0 and overlap_y > 0 do
            {a_share, b_share} =
              case {MapSet.member?(fixed, a), MapSet.member?(fixed, b)} do
                {true, true} -> {0.0, 0.0}
                {true, false} -> {0.0, 1.0}
                {false, true} -> {1.0, 0.0}
                _ -> {0.5, 0.5}
              end

            # Push apart along the axis with the smallest overlap
            acc =
              if overlap_x < overlap_y do
                dir = if ax + aw / 2 < bx + bw / 2, do: -1, else: 1

                acc
                |> Map.put(a, {ax + dir * overlap_x * a_share, ay, aw, ah})
                |> Map.put(b, {bx - dir * overlap_x * b_share, by, bw, bh})
              else
                dir = if ay + ah / 2 < by + bh / 2, do: -1, else: 1

                acc
                |> Map.put(a, {ax, ay + dir * overlap_y * a_share, aw, ah})
                |> Map.put(b, {bx, by - dir * overlap_y * b_share, bw, bh})
              end

            {acc, moved or a_share + b_share > 0}
          else
            {acc, moved}
          end
      end

    if moved?, do: collide(boxes, fixed, margin, iterations - 1), else: boxes
  end

  defp layout_nodes(%State{} = flow, opts) do
    case Keyword.get(opts, :nodes) do
      nil -> flow.nodes |> Map.values() |> Enum.filter(&(is_nil(&1.parent_id) and not &1.hidden))
      ids -> ids |> Enum.map(&Map.get(flow.nodes, &1)) |> Enum.reject(&is_nil/1)
    end
    |> Enum.sort_by(& &1.id)
  end

  defp node_width(%Node{width: w}), do: (w || @default_width) * 1.0
  defp node_height(%Node{height: h}), do: (h || @default_height) * 1.0
end

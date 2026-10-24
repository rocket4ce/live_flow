defmodule LiveFlow.State do
  @moduledoc """
  Main state container for LiveFlow.

  The state holds all nodes, edges, viewport information, and selection state.
  It provides CRUD operations for nodes and edges, as well as selection management.

  ## Fields

    * `:nodes` - Map of node ID to `LiveFlow.Node` structs
    * `:edges` - Map of edge ID to `LiveFlow.Edge` structs
    * `:viewport` - Current `LiveFlow.Viewport` state
    * `:selected_nodes` - Set of selected node IDs
    * `:selected_edges` - Set of selected edge IDs

  ## Examples

      iex> state = LiveFlow.State.new()
      iex> node = LiveFlow.Node.new("1", %{x: 0, y: 0}, %{label: "Start"})
      iex> state = LiveFlow.State.add_node(state, node)
      iex> Map.keys(state.nodes)
      ["1"]
  """

  alias LiveFlow.{Node, Edge, Viewport}

  @type t :: %__MODULE__{
          nodes: %{String.t() => Node.t()},
          edges: %{String.t() => Edge.t()},
          viewport: Viewport.t(),
          selected_nodes: MapSet.t(String.t()),
          selected_edges: MapSet.t(String.t())
        }

  defstruct nodes: %{},
            edges: %{},
            viewport: %Viewport{},
            selected_nodes: MapSet.new(),
            selected_edges: MapSet.new()

  @doc """
  Creates a new empty state.

  ## Options

    * `:nodes` - Initial nodes (list or map)
    * `:edges` - Initial edges (list or map)
    * `:viewport` - Initial viewport

  ## Examples

      iex> LiveFlow.State.new()
      %LiveFlow.State{nodes: %{}, edges: %{}}

      iex> nodes = [LiveFlow.Node.new("1", %{x: 0, y: 0}, %{})]
      iex> state = LiveFlow.State.new(nodes: nodes)
      iex> Map.keys(state.nodes)
      ["1"]
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    nodes = normalize_nodes(Keyword.get(opts, :nodes, []))
    edges = normalize_edges(Keyword.get(opts, :edges, []))
    viewport = Keyword.get(opts, :viewport) || %Viewport{}

    %__MODULE__{
      nodes: nodes,
      edges: edges,
      viewport: viewport,
      selected_nodes: MapSet.new(),
      selected_edges: MapSet.new()
    }
  end

  # Node operations

  @doc """
  Adds a node to the state.
  """
  @spec add_node(t(), Node.t()) :: t()
  def add_node(%__MODULE__{nodes: nodes} = state, %Node{id: id} = node) do
    %{state | nodes: Map.put(nodes, id, node)}
  end

  @doc """
  Adds multiple nodes to the state.
  """
  @spec add_nodes(t(), [Node.t()]) :: t()
  def add_nodes(%__MODULE__{} = state, nodes) when is_list(nodes) do
    Enum.reduce(nodes, state, &add_node(&2, &1))
  end

  @doc """
  Gets a node by ID.
  """
  @spec get_node(t(), String.t()) :: Node.t() | nil
  def get_node(%__MODULE__{nodes: nodes}, id) do
    Map.get(nodes, id)
  end

  @doc """
  Updates a node by ID with the given attributes or function.

  When passed a keyword list, updates the node with those attributes.
  When passed a function, applies the function to the node.
  """
  @spec update_node(t(), String.t(), keyword() | (Node.t() -> Node.t())) :: t()
  def update_node(%__MODULE__{nodes: nodes} = state, id, fun) when is_function(fun, 1) do
    case Map.get(nodes, id) do
      nil -> state
      node -> %{state | nodes: Map.put(nodes, id, fun.(node))}
    end
  end

  def update_node(%__MODULE__{nodes: nodes} = state, id, attrs) do
    case Map.get(nodes, id) do
      nil -> state
      node -> %{state | nodes: Map.put(nodes, id, Node.update(node, attrs))}
    end
  end

  @doc """
  Removes a node by ID, together with its child nodes (sub-flows) and every
  edge connected to any of them.
  """
  @spec remove_node(t(), String.t()) :: t()
  def remove_node(%__MODULE__{nodes: nodes, edges: edges} = state, id) do
    ids = MapSet.new([id | descendant_ids(state, id)])

    edges = Map.reject(edges, fn {_eid, edge} -> ids_connected?(edge, ids) end)

    %{
      state
      | nodes: Map.drop(nodes, MapSet.to_list(ids)),
        edges: edges,
        selected_nodes: MapSet.difference(state.selected_nodes, ids),
        selected_edges: MapSet.intersection(state.selected_edges, MapSet.new(Map.keys(edges)))
    }
  end

  @doc """
  Removes multiple nodes by ID.
  """
  @spec remove_nodes(t(), [String.t()]) :: t()
  def remove_nodes(%__MODULE__{} = state, ids) when is_list(ids) do
    Enum.reduce(ids, state, &remove_node(&2, &1))
  end

  # Hierarchy (sub-flows)

  @doc """
  Returns the direct children of a node (nodes whose `parent_id` is `id`).
  """
  @spec children(t(), String.t()) :: [Node.t()]
  def children(%__MODULE__{nodes: nodes}, id) do
    nodes |> Map.values() |> Enum.filter(&(&1.parent_id == id))
  end

  @doc """
  Returns the IDs of all descendants of a node (children, grandchildren, ...).
  """
  @spec descendant_ids(t(), String.t()) :: [String.t()]
  def descendant_ids(%__MODULE__{} = state, id) do
    children_by_parent = Enum.group_by(Map.values(state.nodes), & &1.parent_id, & &1.id)
    collect_descendants(children_by_parent, [id], MapSet.new([id]), [])
  end

  defp collect_descendants(_index, [], _seen, acc), do: Enum.reverse(acc)

  defp collect_descendants(index, [id | rest], seen, acc) do
    children = index |> Map.get(id, []) |> Enum.reject(&MapSet.member?(seen, &1))
    seen = Enum.reduce(children, seen, &MapSet.put(&2, &1))
    collect_descendants(index, rest ++ children, seen, Enum.reverse(children) ++ acc)
  end

  @doc """
  Position of a node in flow coordinates. Child nodes store their position
  relative to their parent; this adds up the positions of all ancestors.
  """
  @spec absolute_position(t(), Node.t() | String.t()) :: %{x: number(), y: number()} | nil
  def absolute_position(%__MODULE__{} = state, id) when is_binary(id) do
    case Map.get(state.nodes, id) do
      nil -> nil
      node -> absolute_position(state, node)
    end
  end

  def absolute_position(%__MODULE__{nodes: nodes}, %Node{} = node) do
    do_absolute_position(nodes, node, node.position, MapSet.new([node.id]))
  end

  defp do_absolute_position(nodes, %Node{parent_id: parent_id}, acc, seen) do
    case parent_id && Map.get(nodes, parent_id) do
      %Node{} = parent ->
        if MapSet.member?(seen, parent.id) do
          acc
        else
          do_absolute_position(
            nodes,
            parent,
            %{x: acc.x + parent.position.x, y: acc.y + parent.position.y},
            MapSet.put(seen, parent.id)
          )
        end

      _ ->
        acc
    end
  end

  @doc """
  Nodes ready to be drawn: `position` is replaced by the absolute position,
  and nodes inside a hidden parent are hidden too.
  """
  @spec absolute_nodes(t()) :: %{String.t() => Node.t()}
  def absolute_nodes(%__MODULE__{nodes: nodes} = state) do
    if Enum.any?(nodes, fn {_id, node} -> node.parent_id end) do
      Map.new(nodes, fn {id, node} ->
        {id,
         %{node | position: absolute_position(state, node), hidden: hidden_in_tree?(nodes, node)}}
      end)
    else
      nodes
    end
  end

  defp hidden_in_tree?(nodes, node, depth \\ 0)
  defp hidden_in_tree?(_nodes, %Node{hidden: true}, _depth), do: true
  defp hidden_in_tree?(_nodes, _node, depth) when depth > 100, do: false

  defp hidden_in_tree?(nodes, %Node{parent_id: parent_id}, depth) do
    case parent_id && Map.get(nodes, parent_id) do
      %Node{} = parent -> hidden_in_tree?(nodes, parent, depth + 1)
      _ -> false
    end
  end

  @doc """
  Number of ancestors of a node (0 for top-level nodes).
  """
  @spec depth(t(), Node.t()) :: non_neg_integer()
  def depth(%__MODULE__{nodes: nodes}, %Node{} = node), do: do_depth(nodes, node, 0)

  defp do_depth(_nodes, _node, depth) when depth > 100, do: depth

  defp do_depth(nodes, %Node{parent_id: parent_id}, depth) do
    case parent_id && Map.get(nodes, parent_id) do
      %Node{} = parent -> do_depth(nodes, parent, depth + 1)
      _ -> depth
    end
  end

  @doc """
  Moves a node into `parent_id` (or out of any parent with `nil`), keeping its
  absolute position on screen.
  """
  @spec set_parent(t(), String.t(), String.t() | nil, keyword()) :: t()
  def set_parent(%__MODULE__{} = state, id, parent_id, opts \\ []) do
    with %Node{} = node <- get_node(state, id),
         false <- parent_id == id,
         false <- parent_id != nil and id in [parent_id | ancestor_ids(state, parent_id)] do
      abs = absolute_position(state, node)

      position =
        case parent_id && absolute_position(state, parent_id) do
          nil -> abs
          parent_abs -> %{x: abs.x - parent_abs.x, y: abs.y - parent_abs.y}
        end

      extent = Keyword.get(opts, :extent, if(parent_id, do: node.extent))

      update_node(state, id, fn node ->
        %{node | parent_id: parent_id, position: position, extent: extent}
      end)
    else
      _ -> state
    end
  end

  defp ancestor_ids(state, id, acc \\ []) do
    case get_node(state, id) do
      %Node{parent_id: nil} ->
        acc

      %Node{parent_id: parent_id} ->
        if parent_id in acc, do: acc, else: ancestor_ids(state, parent_id, [parent_id | acc])

      nil ->
        acc
    end
  end

  # Graph helpers (xyflow's getIncomers / getOutgoers / getConnectedEdges / getIntersectingNodes)

  @doc """
  Nodes with an edge pointing to `id`.
  """
  @spec incomers(t(), String.t()) :: [Node.t()]
  def incomers(%__MODULE__{edges: edges, nodes: nodes}, id) do
    edges
    |> Map.values()
    |> Enum.filter(&(&1.target == id))
    |> Enum.map(&Map.get(nodes, &1.source))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.id)
  end

  @doc """
  Nodes `id` has an edge to.
  """
  @spec outgoers(t(), String.t()) :: [Node.t()]
  def outgoers(%__MODULE__{edges: edges, nodes: nodes}, id) do
    edges
    |> Map.values()
    |> Enum.filter(&(&1.source == id))
    |> Enum.map(&Map.get(nodes, &1.target))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.id)
  end

  @doc """
  Edges connected to any of the given node IDs.
  """
  @spec connected_edges(t(), [String.t()]) :: [Edge.t()]
  def connected_edges(%__MODULE__{edges: edges}, ids) do
    ids = MapSet.new(ids)
    edges |> Map.values() |> Enum.filter(&ids_connected?(&1, ids))
  end

  @doc """
  Rectangle of a node in flow coordinates (absolute position and size).
  Unmeasured nodes count as `100 x 40`.
  """
  @spec node_rect(t(), Node.t() | String.t()) :: map() | nil
  def node_rect(%__MODULE__{} = state, id) when is_binary(id) do
    case get_node(state, id) do
      nil -> nil
      node -> node_rect(state, node)
    end
  end

  def node_rect(%__MODULE__{} = state, %Node{} = node) do
    %{x: x, y: y} = absolute_position(state, node)
    %{x: x, y: y, width: node.width || 100, height: node.height || 40}
  end

  @doc """
  Nodes intersecting a node (by ID) or a rect `%{x, y, width, height}`.

  ## Options

    * `:partial` - Count partial overlaps (default: `true`). With `false`
      only nodes fully inside the rect are returned.
  """
  @spec intersecting_nodes(t(), String.t() | map(), keyword()) :: [Node.t()]
  def intersecting_nodes(%__MODULE__{} = state, id_or_rect, opts \\ []) do
    partial = Keyword.get(opts, :partial, true)

    {rect, exclude} =
      case id_or_rect do
        id when is_binary(id) -> {node_rect(state, id), [id | descendant_ids(state, id)]}
        %{} = rect -> {rect, []}
      end

    if rect do
      state.nodes
      |> Map.values()
      |> Enum.reject(&(&1.id in exclude or &1.hidden))
      |> Enum.filter(fn node ->
        other = node_rect(state, node)
        if partial, do: rects_overlap?(rect, other), else: rect_inside?(other, rect)
      end)
    else
      []
    end
  end

  defp rects_overlap?(a, b) do
    a.x < b.x + b.width and b.x < a.x + a.width and a.y < b.y + b.height and b.y < a.y + a.height
  end

  defp rect_inside?(inner, outer) do
    inner.x >= outer.x and inner.y >= outer.y and inner.x + inner.width <= outer.x + outer.width and
      inner.y + inner.height <= outer.y + outer.height
  end

  defp ids_connected?(%Edge{source: source, target: target}, ids) do
    MapSet.member?(ids, source) or MapSet.member?(ids, target)
  end

  @doc """
  Gets all nodes as a list.
  """
  @spec nodes_list(t()) :: [Node.t()]
  def nodes_list(%__MODULE__{nodes: nodes}) do
    Map.values(nodes)
  end

  # Edge operations

  @doc """
  Adds an edge to the state.
  """
  @spec add_edge(t(), Edge.t()) :: t()
  def add_edge(%__MODULE__{edges: edges} = state, %Edge{id: id} = edge) do
    %{state | edges: Map.put(edges, id, edge)}
  end

  @doc """
  Adds multiple edges to the state.
  """
  @spec add_edges(t(), [Edge.t()]) :: t()
  def add_edges(%__MODULE__{} = state, edges) when is_list(edges) do
    Enum.reduce(edges, state, &add_edge(&2, &1))
  end

  @doc """
  Gets an edge by ID.
  """
  @spec get_edge(t(), String.t()) :: Edge.t() | nil
  def get_edge(%__MODULE__{edges: edges}, id) do
    Map.get(edges, id)
  end

  @doc """
  Updates an edge by ID with the given attributes.
  """
  @spec update_edge(t(), String.t(), keyword()) :: t()
  def update_edge(%__MODULE__{edges: edges} = state, id, attrs) do
    case Map.get(edges, id) do
      nil -> state
      edge -> %{state | edges: Map.put(edges, id, Edge.update(edge, attrs))}
    end
  end

  @doc """
  Removes an edge by ID.
  """
  @spec remove_edge(t(), String.t()) :: t()
  def remove_edge(%__MODULE__{edges: edges, selected_edges: sel} = state, id) do
    %{state | edges: Map.delete(edges, id), selected_edges: MapSet.delete(sel, id)}
  end

  @doc """
  Removes multiple edges by ID.
  """
  @spec remove_edges(t(), [String.t()]) :: t()
  def remove_edges(%__MODULE__{} = state, ids) when is_list(ids) do
    Enum.reduce(ids, state, &remove_edge(&2, &1))
  end

  @doc """
  Reconnects one end of an edge to another node/handle.

  Accepts the params of the `lf:reconnect_edge` event pushed when the user
  drags an edge endpoint (`"edge_id"`, `"end"`, `"node_id"`, `"handle_id"`).

  ## Options

    * `:replace_id` - Give the edge a new ID (default: `false`)
    * `:edge_id` - ID (or function receiving the updated edge) used when
      `:replace_id` is `true`. Defaults to a unique `"e-<integer>"` ID.

  ## Examples

      def handle_event("lf:reconnect_edge", params, socket) do
        {:noreply, assign(socket, flow: State.reconnect_edge(socket.assigns.flow, params))}
      end
  """
  @spec reconnect_edge(t(), map(), keyword()) :: t()
  def reconnect_edge(%__MODULE__{edges: edges} = state, %{} = params, opts \\ []) do
    edge_id = params["edge_id"] || params[:edge_id]
    node_id = params["node_id"] || params[:node_id]
    handle_id = params["handle_id"] || params[:handle_id]
    end_ = to_string(params["end"] || params[:end])

    with %Edge{} = edge <- Map.get(edges, edge_id),
         true <- Map.has_key?(state.nodes, node_id) do
      updated =
        case end_ do
          "source" -> %{edge | source: node_id, source_handle: handle_id}
          "target" -> %{edge | target: node_id, target_handle: handle_id}
        end

      if Keyword.get(opts, :replace_id, false) do
        new_id =
          LiveFlow.Validation.Connection.build_edge_id(Keyword.get(opts, :edge_id), updated)

        state
        |> remove_edge(edge_id)
        |> add_edge(%{updated | id: new_id, selected: false})
      else
        %{state | edges: Map.put(edges, edge_id, updated)}
      end
    else
      _ -> state
    end
  end

  @doc """
  Gets all edges connected to a node.
  """
  @spec edges_for_node(t(), String.t()) :: [Edge.t()]
  def edges_for_node(%__MODULE__{edges: edges}, node_id) do
    edges
    |> Map.values()
    |> Enum.filter(&Edge.connects_to?(&1, node_id))
  end

  @doc """
  Gets all edges as a list.
  """
  @spec edges_list(t()) :: [Edge.t()]
  def edges_list(%__MODULE__{edges: edges}) do
    Map.values(edges)
  end

  @doc """
  Checks if an edge already exists between two nodes.
  """
  @spec edge_exists?(t(), String.t(), String.t(), String.t() | nil, String.t() | nil) :: boolean()
  def edge_exists?(
        %__MODULE__{edges: edges},
        source,
        target,
        source_handle \\ nil,
        target_handle \\ nil
      ) do
    # Edges without handle ids use the node's default handle, whose id is
    # "source" / "target" on the client
    edges
    |> Map.values()
    |> Enum.any?(fn edge ->
      edge.source == source and
        edge.target == target and
        (is_nil(source_handle) or Edge.effective_source_handle(edge) == source_handle) and
        (is_nil(target_handle) or Edge.effective_target_handle(edge) == target_handle)
    end)
  end

  # Selection operations

  @doc """
  Selects a node by ID.

  ## Options

    * `:multi` - If true, adds to selection. If false, replaces selection (default: `false`)
  """
  @spec select_node(t(), String.t(), keyword()) :: t()
  def select_node(%__MODULE__{nodes: nodes, selected_nodes: sel} = state, id, opts \\ []) do
    if Map.has_key?(nodes, id) do
      multi = Keyword.get(opts, :multi, false)

      new_sel =
        if multi do
          MapSet.put(sel, id)
        else
          MapSet.new([id])
        end

      # Update node selected state
      nodes =
        nodes
        |> Enum.map(fn {nid, node} ->
          {nid, %{node | selected: MapSet.member?(new_sel, nid)}}
        end)
        |> Map.new()

      %{state | nodes: nodes, selected_nodes: new_sel}
    else
      state
    end
  end

  @doc """
  Selects multiple nodes by ID.
  """
  @spec select_nodes(t(), [String.t()]) :: t()
  def select_nodes(%__MODULE__{nodes: nodes} = state, ids) do
    valid_ids = Enum.filter(ids, &Map.has_key?(nodes, &1))
    new_sel = MapSet.new(valid_ids)

    nodes =
      nodes
      |> Enum.map(fn {nid, node} ->
        {nid, %{node | selected: MapSet.member?(new_sel, nid)}}
      end)
      |> Map.new()

    %{state | nodes: nodes, selected_nodes: new_sel}
  end

  @doc """
  Deselects a node by ID.
  """
  @spec deselect_node(t(), String.t()) :: t()
  def deselect_node(%__MODULE__{nodes: nodes, selected_nodes: sel} = state, id) do
    nodes = Map.update(nodes, id, nil, &%{&1 | selected: false})
    nodes = Map.reject(nodes, fn {_k, v} -> is_nil(v) end)

    %{state | nodes: nodes, selected_nodes: MapSet.delete(sel, id)}
  end

  @doc """
  Selects an edge by ID.
  """
  @spec select_edge(t(), String.t(), keyword()) :: t()
  def select_edge(%__MODULE__{edges: edges, selected_edges: sel} = state, id, opts \\ []) do
    if Map.has_key?(edges, id) do
      multi = Keyword.get(opts, :multi, false)

      new_sel =
        if multi do
          MapSet.put(sel, id)
        else
          MapSet.new([id])
        end

      edges =
        edges
        |> Enum.map(fn {eid, edge} ->
          {eid, %{edge | selected: MapSet.member?(new_sel, eid)}}
        end)
        |> Map.new()

      %{state | edges: edges, selected_edges: new_sel}
    else
      state
    end
  end

  @doc """
  Clears all selection (nodes and edges).
  """
  @spec clear_selection(t()) :: t()
  def clear_selection(%__MODULE__{nodes: nodes, edges: edges} = state) do
    nodes =
      nodes
      |> Enum.map(fn {id, node} -> {id, %{node | selected: false}} end)
      |> Map.new()

    edges =
      edges
      |> Enum.map(fn {id, edge} -> {id, %{edge | selected: false}} end)
      |> Map.new()

    %{
      state
      | nodes: nodes,
        edges: edges,
        selected_nodes: MapSet.new(),
        selected_edges: MapSet.new()
    }
  end

  @doc """
  Selects all nodes and edges.
  """
  @spec select_all(t()) :: t()
  def select_all(%__MODULE__{nodes: nodes, edges: edges} = state) do
    nodes =
      nodes
      |> Enum.map(fn {id, node} -> {id, %{node | selected: true}} end)
      |> Map.new()

    edges =
      edges
      |> Enum.map(fn {id, edge} -> {id, %{edge | selected: true}} end)
      |> Map.new()

    %{
      state
      | nodes: nodes,
        edges: edges,
        selected_nodes: MapSet.new(Map.keys(nodes)),
        selected_edges: MapSet.new(Map.keys(edges))
    }
  end

  @doc """
  Gets all selected nodes.
  """
  @spec selected_nodes_list(t()) :: [Node.t()]
  def selected_nodes_list(%__MODULE__{nodes: nodes, selected_nodes: sel}) do
    sel
    |> MapSet.to_list()
    |> Enum.map(&Map.get(nodes, &1))
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Gets all selected edges.
  """
  @spec selected_edges_list(t()) :: [Edge.t()]
  def selected_edges_list(%__MODULE__{edges: edges, selected_edges: sel}) do
    sel
    |> MapSet.to_list()
    |> Enum.map(&Map.get(edges, &1))
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Deletes all selected nodes and edges (skipping those with `deletable: false`).
  """
  @spec delete_selected(t()) :: t()
  def delete_selected(%__MODULE__{selected_nodes: sel_nodes, selected_edges: sel_edges} = state) do
    nodes = Enum.filter(sel_nodes, &match?(%Node{deletable: true}, Map.get(state.nodes, &1)))
    edges = Enum.filter(sel_edges, &match?(%Edge{deletable: true}, Map.get(state.edges, &1)))

    state
    |> remove_nodes(nodes)
    |> remove_edges(edges)
  end

  # Viewport operations

  @doc """
  Sets the viewport.
  """
  @spec set_viewport(t(), Viewport.t()) :: t()
  def set_viewport(%__MODULE__{} = state, %Viewport{} = viewport) do
    %{state | viewport: viewport}
  end

  @doc """
  Updates the viewport with the given values.
  """
  @spec update_viewport(t(), map()) :: t()
  def update_viewport(%__MODULE__{viewport: vp} = state, %{} = attrs) do
    new_vp = %Viewport{
      x: Map.get(attrs, :x, Map.get(attrs, "x", vp.x)) * 1.0,
      y: Map.get(attrs, :y, Map.get(attrs, "y", vp.y)) * 1.0,
      zoom: Map.get(attrs, :zoom, Map.get(attrs, "zoom", vp.zoom)) * 1.0
    }

    %{state | viewport: new_vp}
  end

  @doc """
  Calculates the bounding box of the nodes in flow coordinates.

  Each node contributes its position plus its width/height (measured or
  explicitly set). Nodes without dimensions count as a point.

  ## Options

    * `:nodes` - Only include these node IDs. Unknown IDs are ignored, so they
      never stretch the bounds to the origin.
    * `:include_hidden` - Include hidden nodes (default: `false`)

  Returns `nil` when no node matches.

  ## Examples

      iex> state = LiveFlow.State.new(nodes: [
      ...>   LiveFlow.Node.new("a", %{x: 0, y: 0}, %{}, width: 100, height: 50),
      ...>   LiveFlow.Node.new("b", %{x: 200, y: 100}, %{}, width: 50, height: 50)
      ...> ])
      iex> LiveFlow.State.bounds(state)
      %{x: 0.0, y: 0.0, width: 250.0, height: 150.0}
      iex> LiveFlow.State.bounds(state, nodes: ["b", "missing"])
      %{x: 200.0, y: 100.0, width: 50.0, height: 50.0}
  """
  @spec bounds(t(), keyword()) ::
          %{x: number(), y: number(), width: number(), height: number()} | nil
  def bounds(%__MODULE__{nodes: nodes} = state, opts \\ []) do
    include_hidden = Keyword.get(opts, :include_hidden, false)

    nodes =
      case Keyword.get(opts, :nodes) do
        nil -> Map.values(nodes)
        ids -> ids |> Enum.map(&Map.get(nodes, &1)) |> Enum.reject(&is_nil/1)
      end

    absolute = absolute_nodes(state)

    nodes
    |> Enum.map(&Map.get(absolute, &1.id, &1))
    |> Enum.filter(&(include_hidden or not &1.hidden))
    |> Enum.map(fn %Node{position: %{x: x, y: y}} = node ->
      {x, y, x + (node.width || 0), y + (node.height || 0)}
    end)
    |> case do
      [] ->
        nil

      [first | rest] ->
        {x1, y1, x2, y2} =
          Enum.reduce(rest, first, fn {ax, ay, ax2, ay2}, {bx, by, bx2, by2} ->
            {min(ax, bx), min(ay, by), max(ax2, bx2), max(ay2, by2)}
          end)

        %{x: x1, y: y1, width: x2 - x1, height: y2 - y1}
    end
  end

  # Private helpers

  defp normalize_nodes(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(fn node -> {node.id, node} end)
    |> Map.new()
  end

  defp normalize_nodes(nodes) when is_map(nodes), do: nodes

  defp normalize_edges(edges) when is_list(edges) do
    edges
    |> Enum.map(fn edge -> {edge.id, edge} end)
    |> Map.new()
  end

  defp normalize_edges(edges) when is_map(edges), do: edges
end

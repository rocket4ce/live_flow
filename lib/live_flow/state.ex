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
  Removes a node by ID. Also removes all edges connected to this node.
  """
  @spec remove_node(t(), String.t()) :: t()
  def remove_node(%__MODULE__{nodes: nodes, edges: edges, selected_nodes: sel} = state, id) do
    # Remove edges connected to this node
    edges =
      edges
      |> Map.reject(fn {_eid, edge} -> Edge.connects_to?(edge, id) end)

    %{state | nodes: Map.delete(nodes, id), edges: edges, selected_nodes: MapSet.delete(sel, id)}
  end

  @doc """
  Removes multiple nodes by ID.
  """
  @spec remove_nodes(t(), [String.t()]) :: t()
  def remove_nodes(%__MODULE__{} = state, ids) when is_list(ids) do
    Enum.reduce(ids, state, &remove_node(&2, &1))
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
    edges
    |> Map.values()
    |> Enum.any?(fn edge ->
      edge.source == source and
        edge.target == target and
        (is_nil(source_handle) or edge.source_handle == source_handle) and
        (is_nil(target_handle) or edge.target_handle == target_handle)
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
  Deletes all selected nodes and edges.
  """
  @spec delete_selected(t()) :: t()
  def delete_selected(%__MODULE__{selected_nodes: sel_nodes, selected_edges: sel_edges} = state) do
    state
    |> remove_nodes(MapSet.to_list(sel_nodes))
    |> remove_edges(MapSet.to_list(sel_edges))
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
  Calculates bounds of all nodes.
  """
  @spec bounds(t()) :: map() | nil
  def bounds(%__MODULE__{nodes: nodes}) when map_size(nodes) == 0, do: nil

  def bounds(%__MODULE__{nodes: nodes}) do
    measured_nodes =
      nodes
      |> Map.values()
      |> Enum.filter(& &1.measured)

    if Enum.empty?(measured_nodes) do
      # Use position only if no nodes are measured
      positions = nodes |> Map.values() |> Enum.map(& &1.position)

      xs = Enum.map(positions, & &1.x)
      ys = Enum.map(positions, & &1.y)

      %{
        x: Enum.min(xs),
        y: Enum.min(ys),
        width: Enum.max(xs) - Enum.min(xs),
        height: Enum.max(ys) - Enum.min(ys)
      }
    else
      bounds = Enum.map(measured_nodes, &Node.bounds/1)

      %{
        x: bounds |> Enum.map(& &1.x) |> Enum.min(),
        y: bounds |> Enum.map(& &1.y) |> Enum.min(),
        width:
          (bounds |> Enum.map(& &1.x2) |> Enum.max()) - (bounds |> Enum.map(& &1.x) |> Enum.min()),
        height:
          (bounds |> Enum.map(& &1.y2) |> Enum.max()) - (bounds |> Enum.map(& &1.y) |> Enum.min())
      }
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

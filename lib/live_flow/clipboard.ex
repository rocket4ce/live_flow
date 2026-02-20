defmodule LiveFlow.Clipboard do
  @moduledoc """
  Copy/paste clipboard for LiveFlow.

  Stores copied nodes and edges for paste operations. Handles ID remapping,
  position offsetting, and edge reconnection on paste.

  ## Usage

      # Initialize in mount
      clipboard = LiveFlow.Clipboard.new()

      # Copy selected nodes/edges
      clipboard = LiveFlow.Clipboard.copy(clipboard, flow)

      # Cut (copy + delete)
      {clipboard, flow} = LiveFlow.Clipboard.cut(clipboard, flow)

      # Paste
      case LiveFlow.Clipboard.paste(clipboard, flow) do
        {:ok, flow, clipboard} -> ...
        :empty -> ...
      end

  ## Notes

    * Only edges where both source and target are in the selection are copied
    * Pasted nodes get new unique IDs and an incremental position offset
    * Pasted items are auto-selected for immediate repositioning
    * Each successive paste increases the offset (+50px per paste)
  """

  alias LiveFlow.State

  @type t :: %__MODULE__{
          nodes: [LiveFlow.Node.t()],
          edges: [LiveFlow.Edge.t()],
          paste_count: non_neg_integer()
        }

  defstruct nodes: [], edges: [], paste_count: 0

  @paste_offset 50

  @doc "Creates a new empty clipboard."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Copies the currently selected nodes and internal edges to the clipboard.

  Only edges where both source and target nodes are in the selection are included.
  Resets the paste count to 0.
  """
  @spec copy(t(), State.t()) :: t()
  def copy(%__MODULE__{} = _clipboard, flow) do
    nodes = State.selected_nodes_list(flow)
    node_ids = MapSet.new(nodes, & &1.id)

    edges =
      State.selected_edges_list(flow)
      |> Enum.filter(fn edge ->
        MapSet.member?(node_ids, edge.source) and MapSet.member?(node_ids, edge.target)
      end)

    # Also include non-selected internal edges between selected nodes
    all_internal_edges =
      flow.edges
      |> Map.values()
      |> Enum.filter(fn edge ->
        MapSet.member?(node_ids, edge.source) and MapSet.member?(node_ids, edge.target)
      end)

    # Merge: use all internal edges (deduplicated by id)
    merged_edges =
      (edges ++ all_internal_edges)
      |> Enum.uniq_by(& &1.id)

    %__MODULE__{nodes: nodes, edges: merged_edges, paste_count: 0}
  end

  @doc """
  Cuts the currently selected nodes and edges.

  Copies the selection to the clipboard, then deletes it from the flow.
  Returns `{clipboard, updated_flow}`.
  """
  @spec cut(t(), State.t()) :: {t(), State.t()}
  def cut(%__MODULE__{} = clipboard, flow) do
    clipboard = copy(clipboard, flow)
    flow = State.delete_selected(flow)
    {clipboard, flow}
  end

  @doc """
  Pastes clipboard contents into the flow with new IDs and offset positions.

  Each successive paste increases the position offset by #{@paste_offset}px.
  Pasted nodes and edges are auto-selected.
  Returns `{:ok, updated_flow, updated_clipboard}` or `:empty`.
  """
  @spec paste(t(), State.t()) :: {:ok, State.t(), t()} | :empty
  def paste(%__MODULE__{nodes: []}, _flow), do: :empty

  def paste(%__MODULE__{} = clipboard, flow) do
    paste_count = clipboard.paste_count + 1
    offset = @paste_offset * paste_count

    # Build old_id → new_id mapping for nodes
    id_map =
      Map.new(clipboard.nodes, fn node ->
        {node.id, "#{node.id}-copy-#{System.unique_integer([:positive])}"}
      end)

    # Clone nodes with new IDs and offset positions
    new_nodes =
      Enum.map(clipboard.nodes, fn node ->
        %{node |
          id: id_map[node.id],
          position: %{x: node.position.x + offset, y: node.position.y + offset},
          selected: false,
          dragging: false,
          measured: false,
          width: nil,
          height: nil
        }
      end)

    # Clone edges with remapped source/target IDs
    new_edges =
      Enum.map(clipboard.edges, fn edge ->
        %{edge |
          id: "#{edge.id}-copy-#{System.unique_integer([:positive])}",
          source: id_map[edge.source],
          target: id_map[edge.target],
          selected: false
        }
      end)

    # Add to flow and select pasted items
    flow =
      flow
      |> State.add_nodes(new_nodes)
      |> State.add_edges(new_edges)
      |> select_items(new_nodes, new_edges)

    {:ok, flow, %{clipboard | paste_count: paste_count}}
  end

  @doc "Returns true if the clipboard is empty."
  @spec empty?(t()) :: boolean()
  def empty?(%__MODULE__{nodes: []}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc "Returns the number of nodes in the clipboard."
  @spec node_count(t()) :: non_neg_integer()
  def node_count(%__MODULE__{nodes: nodes}), do: length(nodes)

  # Select the pasted nodes/edges (deselect everything else)
  defp select_items(flow, new_nodes, new_edges) do
    node_ids = MapSet.new(new_nodes, & &1.id)
    edge_ids = MapSet.new(new_edges, & &1.id)

    nodes =
      Map.new(flow.nodes, fn {id, node} ->
        {id, %{node | selected: MapSet.member?(node_ids, id)}}
      end)

    edges =
      Map.new(flow.edges, fn {id, edge} ->
        {id, %{edge | selected: MapSet.member?(edge_ids, id)}}
      end)

    %{flow |
      nodes: nodes,
      edges: edges,
      selected_nodes: node_ids,
      selected_edges: edge_ids
    }
  end
end

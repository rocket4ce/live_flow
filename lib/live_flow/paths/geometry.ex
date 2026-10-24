defmodule LiveFlow.Paths.Geometry do
  @moduledoc """
  Edge geometry: handle coordinates (fixed or floating) and the path of an
  edge between two nodes. Shared by `LiveFlow.Components.Edge` and
  `LiveFlow.Export`.

  Nodes must carry absolute positions (see `LiveFlow.State.absolute_nodes/1`).
  """

  alias LiveFlow.{Edge, Handle, Node}
  alias LiveFlow.Paths.Path

  @default_width 100
  @default_height 40

  @doc """
  Computes the path of an edge. Returns `%{path, label_x, label_y, source, target}`
  where `source`/`target` are `%{x, y, position}`, or `nil` without nodes.
  """
  @spec edge_path(Edge.t(), Node.t() | nil, Node.t() | nil) :: map() | nil
  def edge_path(_edge, nil, _target), do: nil
  def edge_path(_edge, _source, nil), do: nil

  def edge_path(%Edge{} = edge, %Node{} = source_node, %Node{} = target_node) do
    {source_pos, source_position} =
      handle_point(source_node, target_node, edge.source_handle, :source, edge.source_floating)

    {target_pos, target_position} =
      handle_point(target_node, source_node, edge.target_handle, :target, edge.target_floating)

    path_type = Map.get(edge.path_options, :base_type, base_path_type(edge.type))

    result =
      Path.calculate(
        Path.module_for_type(path_type),
        Map.put(source_pos, :position, source_position),
        Map.put(target_pos, :position, target_position),
        edge.path_options |> Map.delete(:base_type) |> Map.to_list()
      )

    Map.merge(result, %{
      path_type: path_type,
      source: Map.put(source_pos, :position, source_position),
      target: Map.put(target_pos, :position, target_position)
    })
  end

  @doc """
  Built-in types are their own path type; custom types default to bezier.
  """
  def base_path_type(type) when type in [:bezier, :straight, :step, :smoothstep], do: type
  def base_path_type(_custom_type), do: :bezier

  @doc """
  Coordinates and side of an edge endpoint on `node`.
  """
  @spec handle_point(Node.t(), Node.t(), String.t() | nil, :source | :target, boolean()) ::
          {%{x: number(), y: number()}, atom()}
  def handle_point(%Node{} = node, other_node, handle_id, type, floating) do
    if floating do
      floating_point(node, other_node)
    else
      handle = find_handle(node.handles, handle_id, type)
      position = if handle, do: handle.position, else: default_position(type)
      {side_point(node, position, handle && handle.offset), position}
    end
  end

  @doc """
  Center of a side of the node box.
  """
  def side_center(%Node{} = node, position), do: side_point(node, position, nil)

  @doc """
  Point on a side of the node box; `offset` goes from `0.0` (top/left) to
  `1.0` (bottom/right), `nil` meaning the center.
  """
  def side_point(%Node{position: pos, width: w, height: h}, position, offset) do
    w = w || @default_width
    h = h || @default_height
    t = offset || 0.5

    case position do
      :top -> %{x: pos.x + w * t, y: pos.y}
      :bottom -> %{x: pos.x + w * t, y: pos.y + h}
      :left -> %{x: pos.x, y: pos.y + h * t}
      :right -> %{x: pos.x + w, y: pos.y + h * t}
    end
  end

  @doc """
  Nearest point on the node border facing the other node's center.
  """
  def floating_point(%Node{} = node, %Node{} = other_node) do
    nw = node.width || @default_width
    nh = node.height || @default_height
    ow = other_node.width || @default_width
    oh = other_node.height || @default_height

    ncx = node.position.x + nw / 2
    ncy = node.position.y + nh / 2
    dx = other_node.position.x + ow / 2 - ncx
    dy = other_node.position.y + oh / 2 - ncy

    if abs(dx) < 0.001 and abs(dy) < 0.001 do
      {%{x: node.position.x + nw, y: ncy}, :right}
    else
      candidates = [
        {if(dx > 0, do: nw / 2 / dx, else: :infinity), :right},
        {if(dx < 0, do: -nw / 2 / dx, else: :infinity), :left},
        {if(dy > 0, do: nh / 2 / dy, else: :infinity), :bottom},
        {if(dy < 0, do: -nh / 2 / dy, else: :infinity), :top}
      ]

      {t, side} =
        candidates
        |> Enum.reject(fn {t, _} -> t == :infinity end)
        |> Enum.min_by(fn {t, _} -> t end, fn -> {1.0, :right} end)

      ix = max(node.position.x, min(ncx + dx * t, node.position.x + nw))
      iy = max(node.position.y, min(ncy + dy * t, node.position.y + nh))
      {%{x: ix, y: iy}, side}
    end
  end

  defp find_handle(handles, nil, type), do: Enum.find(handles, &(&1.type == type))

  defp find_handle(handles, handle_id, _type),
    do: Enum.find(handles, &(Handle.effective_id(&1) == handle_id))

  defp default_position(:source), do: :right
  defp default_position(:target), do: :left
end

defmodule LiveFlow.Serializer do
  @moduledoc """
  Serializes and deserializes LiveFlow state to/from JSON.

  Converts `LiveFlow.State` structs (with nested `Node`, `Edge`, `Handle`,
  `Viewport` structs) to plain maps suitable for `Jason.encode!/1`, and
  back again.

  ## Usage

      # Export to JSON string
      json = LiveFlow.Serializer.to_json(flow)

      # Import from JSON string
      {:ok, flow} = LiveFlow.Serializer.from_json(json)

      # Export to map (for embedding in larger structures)
      map = LiveFlow.Serializer.export(flow)

      # Import from map
      {:ok, flow} = LiveFlow.Serializer.import(map)

  ## Format

  The JSON format uses string keys and string representations of atoms.
  Transient state (selected, dragging, measured, width, height) is excluded
  from export. On import, these fields get their default values.
  """

  alias LiveFlow.{State, Node, Edge, Handle, Viewport}

  @version 1

  @doc """
  Exports a flow state to a JSON-compatible map.

  Excludes transient UI state (selection, dragging, measurements).
  """
  @spec export(State.t()) :: map()
  def export(%State{} = flow) do
    %{
      "version" => @version,
      "nodes" => flow.nodes |> Map.values() |> Enum.sort_by(& &1.id) |> Enum.map(&serialize_node/1),
      "edges" => flow.edges |> Map.values() |> Enum.sort_by(& &1.id) |> Enum.map(&serialize_edge/1),
      "viewport" => serialize_viewport(flow.viewport)
    }
  end

  @doc "Exports a flow state to a pretty-printed JSON string."
  @spec to_json(State.t()) :: String.t()
  def to_json(%State{} = flow) do
    flow |> export() |> Jason.encode!(pretty: true)
  end

  @doc """
  Imports a flow state from a JSON-compatible map.

  Returns `{:ok, state}` or `{:error, reason}`.
  """
  @spec import(map()) :: {:ok, State.t()} | {:error, String.t()}
  def import(data) when is_map(data) do
    nodes = (data["nodes"] || []) |> Enum.map(&deserialize_node/1)
    edges = (data["edges"] || []) |> Enum.map(&deserialize_edge/1)
    viewport = deserialize_viewport(data["viewport"])

    {:ok, State.new(nodes: nodes, edges: edges, viewport: viewport)}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Imports from a JSON string.

  Returns `{:ok, state}` or `{:error, reason}`.
  """
  @spec from_json(String.t()) :: {:ok, State.t()} | {:error, String.t()}
  def from_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, data} -> __MODULE__.import(data)
      {:error, reason} -> {:error, "Invalid JSON: #{inspect(reason)}"}
    end
  end

  # === Node Serialization ===

  defp serialize_node(%Node{} = node) do
    %{
      "id" => node.id,
      "type" => Atom.to_string(node.type),
      "position" => %{"x" => node.position.x, "y" => node.position.y},
      "data" => serialize_map(node.data),
      "handles" => Enum.map(node.handles, &serialize_handle/1)
    }
    |> put_if("parent_id", node.parent_id)
    |> put_if("style", node.style, %{})
    |> put_if("class", node.class)
    |> put_unless("draggable", node.draggable, true)
    |> put_unless("connectable", node.connectable, true)
    |> put_unless("selectable", node.selectable, true)
    |> put_unless("deletable", node.deletable, true)
    |> put_unless("hidden", node.hidden, false)
    |> put_unless("z_index", node.z_index, 0)
  end

  # === Edge Serialization ===

  defp serialize_edge(%Edge{} = edge) do
    %{
      "id" => edge.id,
      "source" => edge.source,
      "target" => edge.target,
      "type" => Atom.to_string(edge.type)
    }
    |> put_if("source_handle", edge.source_handle)
    |> put_if("target_handle", edge.target_handle)
    |> put_if("label", edge.label)
    |> put_if("marker_start", serialize_marker(edge.marker_start))
    |> put_if_changed("marker_end", serialize_marker(edge.marker_end), serialize_marker(%{type: :arrow}))
    |> put_if("style", edge.style, %{})
    |> put_if("class", edge.class)
    |> put_if("data", serialize_map(edge.data), %{})
    |> put_unless("animated", edge.animated, false)
    |> put_unless("selectable", edge.selectable, true)
    |> put_unless("deletable", edge.deletable, true)
    |> put_unless("hidden", edge.hidden, false)
    |> put_unless("z_index", edge.z_index, 0)
    |> put_unless("label_position", edge.label_position, 0.5)
    |> put_if("label_style", serialize_map(edge.label_style), %{})
    |> put_if("path_options", serialize_map(edge.path_options), %{})
  end

  # === Handle Serialization ===

  defp serialize_handle(%Handle{} = handle) do
    %{
      "type" => Atom.to_string(handle.type),
      "position" => Atom.to_string(handle.position)
    }
    |> put_if("id", handle.id)
    |> put_if("connect_type", handle.connect_type && Atom.to_string(handle.connect_type))
    |> put_if("style", handle.style, %{})
    |> put_if("class", handle.class)
    |> put_unless("connectable", handle.connectable, true)
  end

  # === Viewport Serialization ===

  defp serialize_viewport(%Viewport{} = vp) do
    %{"x" => vp.x, "y" => vp.y, "zoom" => vp.zoom}
  end

  # === Marker Serialization ===

  defp serialize_marker(nil), do: nil

  defp serialize_marker(marker) when is_map(marker) do
    Map.new(marker, fn
      {k, v} when is_atom(k) and is_atom(v) -> {Atom.to_string(k), Atom.to_string(v)}
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {to_string(k), v}
    end)
  end

  # === Generic Map Serialization ===

  defp serialize_map(data) when is_map(data) and map_size(data) == 0, do: %{}

  defp serialize_map(data) when is_map(data) do
    Map.new(data, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), serialize_value(v)}
      {k, v} -> {to_string(k), serialize_value(v)}
    end)
  end

  defp serialize_map(data), do: data

  defp serialize_value(v) when is_atom(v) and not is_nil(v) and not is_boolean(v),
    do: Atom.to_string(v)

  defp serialize_value(v) when is_map(v), do: serialize_map(v)
  defp serialize_value(v) when is_list(v), do: Enum.map(v, &serialize_value/1)
  defp serialize_value(v), do: v

  # === Deserialization ===

  defp deserialize_node(data) do
    handles = (data["handles"] || []) |> Enum.map(&deserialize_handle/1)

    opts =
      [
        type: safe_to_atom(data["type"], :default),
        handles: handles,
        draggable: Map.get(data, "draggable", true),
        connectable: Map.get(data, "connectable", true),
        selectable: Map.get(data, "selectable", true),
        deletable: Map.get(data, "deletable", true),
        parent_id: data["parent_id"],
        style: data["style"] || %{},
        class: data["class"],
        z_index: Map.get(data, "z_index", 0)
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    Node.new(
      data["id"],
      data["position"],
      deserialize_node_data(data["data"] || %{}),
      opts
    )
  end

  defp deserialize_edge(data) do
    opts =
      [
        type: safe_to_atom(data["type"], :bezier),
        source_handle: data["source_handle"],
        target_handle: data["target_handle"],
        label: data["label"],
        animated: Map.get(data, "animated", false),
        selectable: Map.get(data, "selectable", true),
        deletable: Map.get(data, "deletable", true),
        marker_start: deserialize_marker(data["marker_start"]),
        marker_end: deserialize_marker(data["marker_end"]),
        style: data["style"] || %{},
        class: data["class"],
        data: data["data"] || %{},
        z_index: Map.get(data, "z_index", 0),
        label_position: Map.get(data, "label_position", 0.5),
        label_style: data["label_style"] || %{},
        path_options: data["path_options"] || %{}
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    Edge.new(data["id"], data["source"], data["target"], opts)
  end

  defp deserialize_handle(data) do
    type = safe_to_atom(data["type"], :source)
    position = safe_to_atom(data["position"], :bottom)

    opts =
      [
        id: data["id"],
        connectable: Map.get(data, "connectable", true),
        connect_type: data["connect_type"] && safe_to_atom(data["connect_type"], nil),
        style: data["style"] || %{},
        class: data["class"]
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    Handle.new(type, position, opts)
  end

  defp deserialize_viewport(nil), do: %Viewport{}

  defp deserialize_viewport(data) do
    Viewport.new(
      x: Map.get(data, "x", 0),
      y: Map.get(data, "y", 0),
      zoom: Map.get(data, "zoom", 1.0)
    )
  end

  defp deserialize_marker(nil), do: nil

  defp deserialize_marker(data) when is_map(data) do
    Map.new(data, fn
      {"type", v} -> {:type, safe_to_atom(v, :arrow)}
      {"color", v} -> {:color, v}
      {k, v} -> {k, v}
    end)
  end

  defp deserialize_node_data(data) when is_map(data) do
    Map.new(data, fn {k, v} -> {try_existing_atom(k), v} end)
  end

  # Convert string to existing atom safely (prevents atom table exhaustion)
  defp safe_to_atom(nil, default), do: default

  defp safe_to_atom(str, default) when is_binary(str) do
    String.to_existing_atom(str)
  rescue
    ArgumentError -> default
  end

  defp safe_to_atom(val, _default) when is_atom(val), do: val

  defp try_existing_atom(str) when is_binary(str) do
    String.to_existing_atom(str)
  rescue
    ArgumentError -> str
  end

  # === Map Builder Helpers ===

  # Put if value is not nil
  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)

  # Put if value is not nil and not equal to default
  defp put_if(map, _key, nil, _default), do: map
  defp put_if(map, _key, value, default) when value == default, do: map
  defp put_if(map, key, value, _default), do: Map.put(map, key, value)

  # Put if value differs from another (for marker_end comparison)
  defp put_if_changed(map, _key, value, value), do: map
  defp put_if_changed(map, _key, nil, _default), do: map
  defp put_if_changed(map, key, value, _default), do: Map.put(map, key, value)

  # Put unless value equals default (for boolean/number fields)
  defp put_unless(map, _key, value, value), do: map
  defp put_unless(map, key, value, _default), do: Map.put(map, key, value)
end

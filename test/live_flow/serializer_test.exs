defmodule LiveFlow.SerializerTest do
  use ExUnit.Case, async: true

  alias LiveFlow.{Serializer, State, Node, Edge, Handle, Viewport}

  defp make_node(id, x \\ 0, y \\ 0, opts \\ []) do
    Node.new(id, %{x: x, y: y}, Keyword.get(opts, :data, %{label: id}), opts)
  end

  defp make_edge(id, source, target, opts) do
    Edge.new(id, source, target, opts)
  end

  defp make_edge(id, source, target) do
    Edge.new(id, source, target)
  end

  defp build_flow do
    h1 = Handle.new(:source, :bottom, id: "out")
    h2 = Handle.new(:target, :top, id: "in")

    nodes = [
      make_node("n1", 0, 0, handles: [h1], data: %{label: "Start"}),
      make_node("n2", 200, 100, handles: [h2], type: :output, data: %{label: "End"})
    ]

    edges = [
      make_edge("e1", "n1", "n2",
        source_handle: "out",
        target_handle: "in",
        label: "connects",
        type: :straight
      )
    ]

    State.new(
      nodes: nodes,
      edges: edges,
      viewport: Viewport.new(x: 50, y: 25, zoom: 1.5)
    )
  end

  describe "export/1" do
    test "exports state to a map" do
      flow = build_flow()
      exported = Serializer.export(flow)

      assert exported["version"] == 1
      assert is_list(exported["nodes"])
      assert is_list(exported["edges"])
      assert is_map(exported["viewport"])
    end

    test "converts atom types to strings" do
      flow = build_flow()
      exported = Serializer.export(flow)

      node = Enum.find(exported["nodes"], &(&1["id"] == "n2"))
      assert node["type"] == "output"

      edge = hd(exported["edges"])
      assert edge["type"] == "straight"
    end

    test "serializes handles" do
      flow = build_flow()
      exported = Serializer.export(flow)

      node = Enum.find(exported["nodes"], &(&1["id"] == "n1"))
      assert length(node["handles"]) == 1

      handle = hd(node["handles"])
      assert handle["type"] == "source"
      assert handle["position"] == "bottom"
      assert handle["id"] == "out"
    end

    test "excludes transient state" do
      n = make_node("n1") |> Node.set_dimensions(200, 100) |> Node.select()
      flow = State.new(nodes: [n])
      exported = Serializer.export(flow)
      node = hd(exported["nodes"])

      refute Map.has_key?(node, "selected")
      refute Map.has_key?(node, "dragging")
      refute Map.has_key?(node, "measured")
      refute Map.has_key?(node, "width")
      refute Map.has_key?(node, "height")
    end

    test "serializes viewport" do
      flow = build_flow()
      exported = Serializer.export(flow)

      assert exported["viewport"]["x"] == 50.0
      assert exported["viewport"]["y"] == 25.0
      assert exported["viewport"]["zoom"] == 1.5
    end

    test "serializes edge with source/target handles" do
      flow = build_flow()
      exported = Serializer.export(flow)
      edge = hd(exported["edges"])

      assert edge["source_handle"] == "out"
      assert edge["target_handle"] == "in"
      assert edge["label"] == "connects"
    end

    test "converts atom keys in data to strings" do
      flow = build_flow()
      exported = Serializer.export(flow)
      node = Enum.find(exported["nodes"], &(&1["id"] == "n1"))

      assert node["data"]["label"] == "Start"
    end

    test "serializes markers" do
      edge = make_edge("e1", "a", "b",
        marker_start: %{type: :arrow_closed, color: "red"},
        marker_end: %{type: :arrow}
      )

      flow = State.new(edges: [edge])
      exported = Serializer.export(flow)
      e = hd(exported["edges"])

      assert e["marker_start"]["type"] == "arrow_closed"
      assert e["marker_start"]["color"] == "red"
    end
  end

  describe "import/1" do
    test "imports from exported map" do
      flow = build_flow()
      exported = Serializer.export(flow)
      {:ok, imported} = Serializer.import(exported)

      assert map_size(imported.nodes) == 2
      assert map_size(imported.edges) == 1
      assert imported.viewport.x == 50.0
    end

    test "restores atom types" do
      flow = build_flow()
      exported = Serializer.export(flow)
      {:ok, imported} = Serializer.import(exported)

      assert imported.nodes["n2"].type == :output
      assert imported.edges["e1"].type == :straight
    end

    test "restores handles" do
      flow = build_flow()
      exported = Serializer.export(flow)
      {:ok, imported} = Serializer.import(exported)

      n1 = imported.nodes["n1"]
      assert length(n1.handles) == 1

      handle = hd(n1.handles)
      assert handle.type == :source
      assert handle.position == :bottom
      assert handle.id == "out"
    end

    test "transient state gets defaults" do
      flow = build_flow()
      exported = Serializer.export(flow)
      {:ok, imported} = Serializer.import(exported)

      node = imported.nodes["n1"]
      assert node.selected == false
      assert node.dragging == false
      assert node.measured == false
      assert node.width == nil
      assert node.height == nil
    end

    test "restores data keys as existing atoms" do
      flow = build_flow()
      exported = Serializer.export(flow)
      {:ok, imported} = Serializer.import(exported)

      # :label is an existing atom, so it should be restored
      assert Map.has_key?(imported.nodes["n1"].data, :label)
      assert imported.nodes["n1"].data[:label] == "Start"
    end

    test "safe from atom table exhaustion (unknown atoms stay as strings)" do
      data = %{
        "nodes" => [
          %{
            "id" => "n1",
            "type" => "zzz_nonexistent_type_xyz_12345",
            "position" => %{"x" => 0, "y" => 0},
            "data" => %{"zzz_nonexistent_key_xyz_12345" => "value"},
            "handles" => []
          }
        ],
        "edges" => [],
        "viewport" => %{"x" => 0, "y" => 0, "zoom" => 1.0}
      }

      {:ok, imported} = Serializer.import(data)

      # Unknown type falls back to default
      assert imported.nodes["n1"].type == :default

      # Unknown data key stays as string
      assert Map.has_key?(imported.nodes["n1"].data, "zzz_nonexistent_key_xyz_12345")
    end

    test "restores markers" do
      edge = make_edge("e1", "a", "b",
        marker_start: %{type: :arrow_closed},
        marker_end: %{type: :arrow}
      )

      flow = State.new(nodes: [make_node("a"), make_node("b")], edges: [edge])
      exported = Serializer.export(flow)
      {:ok, imported} = Serializer.import(exported)

      assert imported.edges["e1"].marker_start.type == :arrow_closed
    end

    test "handles missing optional fields gracefully" do
      data = %{
        "nodes" => [
          %{
            "id" => "n1",
            "type" => "default",
            "position" => %{"x" => 10, "y" => 20},
            "data" => %{},
            "handles" => []
          }
        ],
        "edges" => []
      }

      {:ok, imported} = Serializer.import(data)

      assert map_size(imported.nodes) == 1
      assert imported.viewport.zoom == 1.0
    end
  end

  describe "to_json/1 and from_json/1" do
    test "roundtrip preserves data" do
      flow = build_flow()
      json = Serializer.to_json(flow)
      {:ok, imported} = Serializer.from_json(json)

      assert map_size(imported.nodes) == 2
      assert map_size(imported.edges) == 1
      assert imported.nodes["n1"].data[:label] == "Start"
      assert imported.edges["e1"].label == "connects"
      assert imported.viewport.zoom == 1.5
    end

    test "to_json produces valid JSON" do
      flow = build_flow()
      json = Serializer.to_json(flow)

      assert {:ok, _} = Jason.decode(json)
    end

    test "from_json returns error for invalid JSON" do
      assert {:error, msg} = Serializer.from_json("not json at all")
      assert String.contains?(msg, "Invalid JSON")
    end
  end

  describe "export/import roundtrip" do
    test "full roundtrip preserves structure" do
      flow = build_flow()
      exported = Serializer.export(flow)
      {:ok, imported} = Serializer.import(exported)

      # Node count
      assert map_size(imported.nodes) == map_size(flow.nodes)
      # Edge count
      assert map_size(imported.edges) == map_size(flow.edges)

      # Node types
      assert imported.nodes["n1"].type == flow.nodes["n1"].type
      assert imported.nodes["n2"].type == flow.nodes["n2"].type

      # Edge types
      assert imported.edges["e1"].type == flow.edges["e1"].type

      # Viewport
      assert imported.viewport.x == flow.viewport.x
      assert imported.viewport.y == flow.viewport.y
      assert imported.viewport.zoom == flow.viewport.zoom
    end

    test "roundtrip with handle connect_type" do
      h = Handle.new(:source, :bottom, id: "out", connect_type: :data)
      n = Node.new("n1", %{x: 0, y: 0}, %{}, handles: [h])
      flow = State.new(nodes: [n])

      exported = Serializer.export(flow)
      {:ok, imported} = Serializer.import(exported)

      handle = hd(imported.nodes["n1"].handles)
      assert handle.connect_type == :data
    end
  end
end

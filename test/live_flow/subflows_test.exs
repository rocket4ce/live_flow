defmodule LiveFlow.SubflowsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias LiveFlow.{Edge, Node, State}

  defp node(id, x, y, opts \\ []) do
    Node.new(id, %{x: x, y: y}, %{label: id}, Keyword.merge([width: 100, height: 40], opts))
  end

  setup do
    flow =
      State.new(
        nodes: [
          node("group", 100, 100, width: 400, height: 300),
          node("child", 20, 30, parent_id: "group", extent: :parent),
          node("grandchild", 5, 5, parent_id: "child"),
          node("outside", 700, 0)
        ],
        edges: [
          Edge.new("e1", "child", "outside"),
          Edge.new("e2", "outside", "group")
        ]
      )

    %{flow: flow}
  end

  describe "hierarchy" do
    test "absolute positions add up the ancestors", %{flow: flow} do
      assert State.absolute_position(flow, "child") == %{x: 120.0, y: 130.0}
      assert State.absolute_position(flow, "grandchild") == %{x: 125.0, y: 135.0}
      assert State.absolute_position(flow, "outside") == %{x: 700.0, y: 0.0}
    end

    test "descendants and children", %{flow: flow} do
      assert State.descendant_ids(flow, "group") == ["child", "grandchild"]
      assert Enum.map(State.children(flow, "group"), & &1.id) == ["child"]
      assert State.depth(flow, State.get_node(flow, "grandchild")) == 2
    end

    test "removing a parent removes its subtree and their edges", %{flow: flow} do
      flow = State.remove_node(flow, "group")
      assert Map.keys(flow.nodes) == ["outside"]
      assert flow.edges == %{}
    end

    test "hidden parents hide their children when rendering", %{flow: flow} do
      flow = State.update_node(flow, "group", hidden: true)
      nodes = State.absolute_nodes(flow)
      assert nodes["grandchild"].hidden
      refute nodes["outside"].hidden
    end

    test "set_parent keeps the absolute position", %{flow: flow} do
      flow = State.set_parent(flow, "outside", "group")
      assert State.get_node(flow, "outside").position == %{x: 600.0, y: -100.0}
      assert State.absolute_position(flow, "outside") == %{x: 700.0, y: 0.0}

      flow = State.set_parent(flow, "outside", nil)
      assert State.get_node(flow, "outside").position == %{x: 700.0, y: 0.0}
    end

    test "set_parent refuses cycles", %{flow: flow} do
      assert State.set_parent(flow, "group", "grandchild") == flow
    end

    test "bounds use absolute positions", %{flow: flow} do
      assert State.bounds(flow, nodes: ["grandchild"]) == %{
               x: 125.0,
               y: 135.0,
               width: 100,
               height: 40
             }
    end
  end

  describe "graph helpers" do
    test "incomers, outgoers and connected edges", %{flow: flow} do
      assert Enum.map(State.outgoers(flow, "child"), & &1.id) == ["outside"]
      assert Enum.map(State.incomers(flow, "group"), & &1.id) == ["outside"]

      assert flow |> State.connected_edges(["outside"]) |> Enum.map(& &1.id) |> Enum.sort() == [
               "e1",
               "e2"
             ]
    end

    test "intersecting nodes", %{flow: flow} do
      ids =
        flow
        |> State.intersecting_nodes(%{x: 110, y: 120, width: 30, height: 30})
        |> Enum.map(& &1.id)

      assert Enum.sort(ids) == ["child", "grandchild", "group"]

      # a node never intersects its own subtree
      assert flow |> State.intersecting_nodes("group") |> Enum.map(& &1.id) == []

      ids =
        flow
        |> State.intersecting_nodes(%{x: 0, y: 0, width: 600, height: 600}, partial: false)
        |> Enum.map(& &1.id)

      assert Enum.sort(ids) == ["child", "grandchild", "group"]
    end
  end

  describe "rendering" do
    test "children are rendered at absolute positions after their parent", %{flow: flow} do
      html = render_component(LiveFlow.Components.Flow, id: "f", flow: flow, opts: %{})

      assert html =~ ~r/data-node-id="child"[^>]*data-parent-id="group"[^>]*data-extent="parent"/s
      assert html =~ ~r/data-node-id="grandchild".*?left: 125.0px; top: 135.0px/s

      order =
        Regex.scan(~r/class="lf-node[^"]*"\s+data-node-id="([^"]+)"/, html)
        |> Enum.map(&List.last/1)

      assert Enum.find_index(order, &(&1 == "group")) < Enum.find_index(order, &(&1 == "child"))

      assert Enum.find_index(order, &(&1 == "child")) <
               Enum.find_index(order, &(&1 == "grandchild"))
    end
  end
end

defmodule LiveFlow.LayoutExportTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  import Kernel, except: [node: 1]
  alias LiveFlow.{Edge, Layout, Node, State}

  defp node(id, x \\ 0, y \\ 0),
    do: Node.new(id, %{x: x, y: y}, %{label: id}, width: 100, height: 40)

  defp tree_flow do
    State.new(
      nodes: Enum.map(~w(root a b a1 a2), &node/1),
      edges: [
        Edge.new("1", "root", "a"),
        Edge.new("2", "root", "b"),
        Edge.new("3", "a", "a1"),
        Edge.new("4", "a", "a2")
      ]
    )
  end

  describe "tree/2" do
    test "ranks nodes top to bottom and centers parents over children" do
      positions = Layout.tree(tree_flow(), node_spacing: 40, rank_spacing: 80)

      assert positions["root"].y == 0.0
      assert positions["a"].y == 120.0
      assert positions["a1"].y == 240.0
      # a is centered over a1 and a2
      assert_in_delta positions["a"].x, (positions["a1"].x + positions["a2"].x) / 2, 0.01
      # siblings don't overlap
      assert positions["a2"].x - positions["a1"].x >= 140
    end

    test "left to right" do
      positions = Layout.tree(tree_flow(), direction: :lr)
      assert positions["root"].x == 0.0
      assert positions["a"].x > positions["root"].x
    end

    test "cycles don't hang" do
      flow =
        State.new(
          nodes: Enum.map(~w(a b c), &node/1),
          edges: [Edge.new("1", "a", "b"), Edge.new("2", "b", "c"), Edge.new("3", "c", "a")]
        )

      assert map_size(Layout.tree(flow)) == 3
    end
  end

  test "force/2 separates overlapping nodes" do
    flow =
      State.new(
        nodes: [node("a"), node("b", 5, 5), node("c", 10, 0)],
        edges: [Edge.new("1", "a", "b")]
      )

    positions = Layout.force(flow, iterations: 120)

    for {x, y} <- [{"a", "b"}, {"a", "c"}, {"b", "c"}] do
      dist =
        :math.sqrt(
          :math.pow(positions[x].x - positions[y].x, 2) +
            :math.pow(positions[x].y - positions[y].y, 2)
        )

      assert dist > 60
    end
  end

  test "resolve_collisions/2 moves nodes apart and keeps fixed ones" do
    flow = State.new(nodes: [node("a"), node("b", 20, 10), node("far", 500, 500)])
    positions = Layout.resolve_collisions(flow, fixed: ["a"], margin: 10)

    refute Map.has_key?(positions, "a")
    refute Map.has_key?(positions, "far")
    moved = Layout.apply_positions(flow, positions)
    assert State.intersecting_nodes(moved, "a") == []
  end

  test "Export.to_svg/2 renders nodes, edges and escaped labels" do
    flow =
      State.new(
        nodes: [
          Node.new("a", %{x: 0, y: 0}, %{label: "A & B"}, width: 120, height: 40),
          node("b", 300, 100)
        ],
        edges: [
          Edge.new("e", "a", "b",
            label: "go",
            type: :smoothstep,
            marker_end: %{type: :arrow_closed}
          )
        ]
      )

    svg = LiveFlow.Export.to_svg(flow, theme: :dark)

    assert svg =~ ~s(<svg xmlns="http://www.w3.org/2000/svg")
    assert svg =~ "A &amp; B"
    assert svg =~ ~r|marker-end="url\(#lf-export-arrow_closed-[0-9a-f]+\)"|
    assert svg =~ "#1a1a1a"
    assert svg =~ ">go</text>"
  end

  test "NodeToolbar renders while the node is selected" do
    node = %{node("a") | selected: true}

    html =
      render_component(&LiveFlow.Components.NodeToolbar.node_toolbar/1,
        node: node,
        position: :bottom,
        inner_block: [%{inner_block: fn _, _ -> "Actions" end}]
      )

    assert html =~ ~s(data-position="bottom")
    assert html =~ "nodrag"
    assert html =~ "Actions"

    assert render_component(&LiveFlow.Components.NodeToolbar.node_toolbar/1,
             node: node("b"),
             inner_block: [%{inner_block: fn _, _ -> "x" end}]
           ) == ""
  end

  test "new client options" do
    html =
      render_component(LiveFlow.Components.Flow,
        id: "f",
        flow: State.new(),
        opts: %{
          context_menu: true,
          multi_connection: true,
          connection_line_style: %{stroke: "red"}
        }
      )

    [_, json] = Regex.run(~r/data-config="([^"]*)"/, html)
    config = json |> String.replace("&quot;", "\"") |> Jason.decode!()

    assert config["contextMenu"] == true
    assert config["multiConnection"] == true
    assert config["connectOnClick"] == true
    assert config["connectionLineStyle"] == "stroke: red"
  end
end

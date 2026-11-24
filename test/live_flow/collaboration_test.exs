defmodule LiveFlow.CollaborationTest do
  use ExUnit.Case, async: true

  alias LiveFlow.{Collaboration, Edge, Node, State}
  alias LiveFlow.Collaboration.User

  doctest LiveFlow.Collaboration.User

  defp flow do
    State.new(
      nodes: [
        Node.new("a", %{x: 0, y: 0}, %{label: "A"}),
        Node.new("b", %{x: 200, y: 0}, %{label: "B"}),
        Node.new("c", %{x: 400, y: 0}, %{label: "C"})
      ],
      edges: [Edge.new("a-b", "a", "b")]
    )
  end

  describe "apply_remote_change/2" do
    test "applies node changes but keeps the local selection" do
      flow = State.select_node(flow(), "c")

      flow =
        Collaboration.apply_remote_change(
          flow,
          {:node_changes,
           [
             %{"type" => "position", "id" => "a", "position" => %{"x" => 10, "y" => 20}},
             %{"type" => "resize", "id" => "b", "width" => 300, "height" => 120},
             %{"type" => "select", "id" => "a", "selected" => true}
           ]}
        )

      assert State.get_node(flow, "a").position == %{x: 10, y: 20}
      assert {State.get_node(flow, "b").width, State.get_node(flow, "b").height} == {300, 120}
      assert MapSet.to_list(flow.selected_nodes) == ["c"]
    end

    test "adds, updates and removes nodes" do
      flow =
        flow()
        |> Collaboration.apply_remote_change({:node_add, Node.new("d", %{x: 0, y: 100}, %{})})
        |> Collaboration.apply_remote_change({:node_update, "a", [data: %{label: "A2"}]})
        |> Collaboration.apply_remote_change({:node_remove, "c"})

      assert State.get_node(flow, "d")
      assert State.get_node(flow, "a").data == %{label: "A2"}
      refute State.get_node(flow, "c")
    end

    test "updates and reconnects edges" do
      flow =
        flow()
        |> Collaboration.apply_remote_change({:edge_update, "a-b", [label: "next"]})
        |> Collaboration.apply_remote_change(
          {:edge_reconnect, %{"edge_id" => "a-b", "end" => "target", "node_id" => "c"}}
        )

      edge = State.get_edge(flow, "a-b")
      assert {edge.label, edge.target} == {"next", "c"}
    end

    test "ignores unknown changes" do
      assert Collaboration.apply_remote_change(flow(), {:unknown, 1}) == flow()
    end
  end

  describe "display colors" do
    test "a plain CSS color is kept as-is" do
      colors = [
        "#ef4444",
        "#fff",
        "#ef4444cc",
        "red",
        "rgb(255, 0, 0)",
        "hsl(120 50% 40%)",
        "oklch(60% 0.25 292)",
        "color-mix(in srgb, red 50%, blue)",
        "var(--lf-primary)"
      ]

      for color <- colors do
        assert User.new("u1", color: color).color == color
      end
    end

    test "a color carrying extra CSS falls back to the palette" do
      palette_color = User.new("u1").color

      for color <- [
            "red; position: fixed; inset: 0",
            "#fff\" onload=\"alert(1)",
            "url(javascript:alert(1))",
            "URL(https://evil.example/pixel.png)",
            "red/* */;background:url(x)",
            String.duplicate("a", 65),
            "",
            nil,
            123
          ] do
        assert User.new("u1", color: color).color == palette_color
      end
    end

    test "safe_color/2 replaces anything that is not a color" do
      assert User.safe_color("#22c55e") == "#22c55e"
      assert User.safe_color("  #22c55e  ") == "#22c55e"
      assert User.safe_color("var(--lf-primary, #fff)") == "var(--lf-primary, #fff)"

      assert User.safe_color("color-mix(in srgb, red 50%, blue)") ==
               "color-mix(in srgb, red 50%, blue)"

      assert User.safe_color("red;position:fixed") == "#888888"
      assert User.safe_color(nil) == "#888888"
      assert User.safe_color(nil, "#000") == "#000"
    end

    test "a name is kept verbatim — it is rendered as text, never as markup" do
      name = "<img src=x onerror=\"alert(1)\">"

      assert User.new("u1", name: name).name == name
    end
  end
end

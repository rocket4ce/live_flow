defmodule LiveFlow.Components.FlowTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias LiveFlow.{Edge, Node, State}
  alias LiveFlow.Components.Flow

  defp flow(nodes, edges \\ []) do
    State.new(nodes: nodes, edges: edges)
  end

  defp config(html) do
    [_, json] = Regex.run(~r/data-config="([^"]*)"/, html)
    json |> String.replace("&quot;", "\"") |> Jason.decode!()
  end

  defp render_flow(flow, opts \\ %{}) do
    render_component(Flow, id: "flow", flow: flow, opts: opts)
  end

  describe "client configuration" do
    test "false options reach the client (HEEx drops false attributes)" do
      html =
        render_flow(flow([]), %{pan_on_drag: false, nodes_draggable: false, zoom_on_scroll: false})

      config = config(html)

      assert config["panOnDrag"] == false
      assert config["nodesDraggable"] == false
      assert config["zoomOnScroll"] == false
    end

    test "includes the new xyflow options with their defaults" do
      config = render_flow(flow([])) |> config()

      assert config["autoPanOnSelection"] == true
      assert config["panActivationKey"] == "Space"
      assert config["deleteKeyCode"] == ["Backspace", "Delete"]
      assert config["connectionMode"] == "strict"
      assert config["viewport"] == %{"x" => 0.0, "y" => 0.0, "zoom" => 1.0}
    end

    test "node_extent and snap grid are serialized as lists" do
      config =
        render_flow(flow([]), %{node_extent: {{0, 0}, {500, 400}}, snap_grid: {20, 10}})
        |> config()

      assert config["nodeExtent"] == [[0, 0], [500, 400]]
      assert config["snapGrid"] == [20, 10]
    end
  end

  describe "rendering" do
    test "per-node boolean flags are rendered as strings" do
      html = render_flow(flow([Node.new("a", %{x: 0, y: 0}, %{}, draggable: false)]))

      assert html =~ ~s(data-draggable="false")
      assert html =~ ~s(data-selectable="true")
    end

    test "edges whose nodes are missing or hidden are skipped instead of crashing" do
      nodes = [
        Node.new("a", %{x: 0, y: 0}, %{}),
        Node.new("b", %{x: 200, y: 0}, %{}),
        Node.new("hidden", %{x: 400, y: 0}, %{}, hidden: true)
      ]

      edges = [
        Edge.new("ok", "a", "b"),
        Edge.new("dangling", "a", "missing"),
        Edge.new("to-hidden", "a", "hidden")
      ]

      html = render_flow(flow(nodes, edges))

      assert html =~ ~s(data-edge-id="ok")
      refute html =~ ~s(data-edge-id="dangling")
      refute html =~ ~s(data-edge-id="to-hidden")
    end

    test "edges expose their path type and options to the client" do
      nodes = [Node.new("a", %{x: 0, y: 0}, %{}), Node.new("b", %{x: 200, y: 0}, %{})]
      edge = Edge.new("e", "a", "b", type: :smoothstep, path_options: %{border_radius: 12})

      html = render_flow(flow(nodes, [edge]))

      assert html =~ ~s(data-path-type="smoothstep")
      assert html =~ "border_radius"
    end

    test "renders the SVG background pattern centered on the grid" do
      html = render_flow(flow([]), %{background: :dots})

      assert html =~ ~s(data-background="dots")
      # xyflow 12.11.3: gap 20 at zoom 1 => translate(-10,-10)
      assert html =~ ~s|patternTransform="translate(-10.0,-10.0)"|
    end

    test "renders the interaction layer ignored by LiveView patches" do
      html = render_flow(flow([]))
      assert html =~ ~s(id="flow-interaction")
      assert html =~ ~s(data-interaction-layer)
    end

    test "minimap skips hidden nodes" do
      nodes = [
        Node.new("a", %{x: 0, y: 0}, %{}),
        Node.new("b", %{x: 500, y: 500}, %{}, hidden: true)
      ]

      html = render_flow(flow(nodes), %{minimap: true})
      assert length(Regex.scan(~r/class="lf-minimap-node"/, html)) == 1
    end
  end

  test "minimap node colors come from minimap_node_color" do
    nodes = [Node.new("a", %{x: 0, y: 0}, %{color: "red"}), Node.new("b", %{x: 200, y: 0}, %{})]
    html = render_flow(flow(nodes), %{minimap: true, minimap_node_color: & &1.data[:color]})

    assert html =~ ~r/data-node-id="a"[^>]*background: red/
    refute html =~ ~r/data-node-id="b"[^>]*background:/
  end
end

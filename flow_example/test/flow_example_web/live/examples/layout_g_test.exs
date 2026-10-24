defmodule FlowExampleWeb.Examples.LayoutGTest do
  use FlowExampleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp node_count(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(".lf-node[data-node-id]")
    |> Enum.count()
  end

  describe "Tree layout (dagre)" do
    test "switching direction moves the handles and animates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/layout/dagre")

      assert has_element?(
               view,
               "#dagre-flow .lf-node[data-node-id=ceo] [data-handle-position=bottom]"
             )

      view |> element("button", "Horizontal") |> render_click()

      assert has_element?(
               view,
               "#dagre-flow .lf-node[data-node-id=ceo] [data-handle-position=right]"
             )

      assert_push_event(view, "lf:animate_positions", %{
        flow_id: "dagre-flow",
        positions: positions
      })

      assert length(positions) == 14
      assert_push_event(view, "lf:fit_view", %{flow_id: "dagre-flow"})
    end
  end

  describe "Elkjs" do
    test "pushes layout data with ELK options", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/layout/elkjs")
      assert_push_event(view, "lf:layout_data", %{direction: "DOWN"})

      view
      |> form("#elk-options", elk: %{algorithm: "mrtree", direction: "RIGHT", spacing: "80"})
      |> render_change()

      assert_push_event(view, "lf:layout_data", %{
        direction: "RIGHT",
        options: %{"elk.algorithm" => "mrtree"}
      })
    end
  end

  describe "Elkjs multiple handles" do
    test "sends handles as ports, or not", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/layout/elkjs-multiple-handles")
      assert_push_event(view, "lf:layout_data", %{nodes: nodes})
      assert Enum.find(nodes, &(&1.id == "split")).ports |> length() == 5

      view |> form("#elk-handles-options", elk: %{ports: "false"}) |> render_change()
      assert_push_event(view, "lf:layout_data", %{nodes: nodes})
      assert Enum.all?(nodes, &(&1.ports == []))
    end

    test "handles sit at their offsets", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/layout/elkjs-multiple-handles")

      assert has_element?(
               view,
               ~s(.lf-node[data-node-id=join] [data-handle-id=a][data-handle-offset="0.25"])
             )
    end
  end

  test "Horizontal flow renders left to right", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/examples/layout/horizontal")

    assert has_element?(
             view,
             "#horizontal-flow .lf-node[data-node-id=build] [data-handle-position=left]"
           )

    assert has_element?(view, "#horizontal-flow g[data-edge-id=build-unit]")
  end

  describe "Expand and collapse" do
    test "toggling shows and hides a subtree", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/layout/expand-collapse")
      refute has_element?(view, ".lf-node[data-node-id=eng-web]")

      view |> element(~s(button[phx-value-id="cto"])) |> render_click()
      assert has_element?(view, ".lf-node[data-node-id=eng-web]")
      assert_push_event(view, "lf:animate_positions", %{flow_id: "expand-collapse-flow"})

      view |> element(~s(button[phx-value-id="ceo"])) |> render_click()
      refute has_element?(view, ".lf-node[data-node-id=cto]")
    end
  end

  describe "Auto layout" do
    test "structural changes re-layout the graph", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/layout/auto-layout")
      before = node_count(view)

      view |> element("button", "Add random node") |> render_click()
      assert node_count(view) == before + 1
      assert_push_event(view, "lf:animate_positions", %{flow_id: "auto-layout-flow"})

      render_hook(view, "lf:selection_change", %{"nodes" => ["ceo"], "edges" => []})
      view |> element("button", "Add child") |> render_click()
      assert node_count(view) == before + 2
    end
  end

  describe "Force layout" do
    test "adding a node and ending a drag re-run the simulation", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/layout/force-layout")
      before = node_count(view)

      view |> element("button", "Add node") |> render_click()
      assert node_count(view) == before + 1
      assert_push_event(view, "lf:animate_positions", %{})

      position = %{"type" => "position", "id" => "a", "position" => %{"x" => 0, "y" => 0}}
      render_hook(view, "lf:node_change", %{"changes" => [Map.put(position, "dragging", true)]})
      render_hook(view, "lf:node_change", %{"changes" => [Map.put(position, "dragging", false)]})
      assert_push_event(view, "lf:animate_positions", %{positions: positions})
      assert Enum.any?(positions, &(&1.id == "a"))
    end
  end

  describe "Dynamic layouting" do
    test "placeholders turn into steps and nodes add children", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/layout/dynamic-layouting")
      assert has_element?(view, ".lf-node[data-node-type=placeholder]")

      [placeholder] =
        view
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query(".lf-node[data-node-type=placeholder]")
        |> LazyHTML.attribute("data-node-id")

      send(view.pid, {:lf_node_click, placeholder})
      html = render(view)
      assert html =~ ~s(data-node-id="#{placeholder}" data-node-type="step")
      # root and the new step each have a placeholder
      assert view
             |> render()
             |> LazyHTML.from_fragment()
             |> LazyHTML.query(".lf-node[data-node-type=placeholder]")
             |> Enum.count() == 2

      send(view.pid, {:lf_node_click, "root"})

      assert view
             |> render()
             |> LazyHTML.from_fragment()
             |> LazyHTML.query(".lf-node[data-node-type=step]")
             |> Enum.count() == 3
    end

    test "inserting on an edge adds a step in between", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/layout/dynamic-layouting")
      send(view.pid, {:lf_node_click, "root"})
      render(view)

      [edge_id] =
        view
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("g[data-source=root]:not([data-target^=ph-])")
        |> LazyHTML.attribute("data-edge-id")

      render_hook(view, "lf:insert_on_edge", %{"edge_id" => edge_id})
      refute has_element?(view, ~s(g[data-edge-id="#{edge_id}"]))

      assert view
             |> render()
             |> LazyHTML.from_fragment()
             |> LazyHTML.query(".lf-node[data-node-type=step]")
             |> Enum.count() == 3
    end
  end

  describe "Node collisions" do
    test "a drop resolves the overlaps around the dropped node", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/layout/node-collisions")

      change = %{"type" => "position", "id" => "n1", "position" => %{"x" => 0, "y" => 0}}
      render_hook(view, "lf:node_change", %{"changes" => [Map.put(change, "dragging", true)]})
      render_hook(view, "lf:node_change", %{"changes" => [Map.put(change, "dragging", false)]})

      assert_push_event(view, "lf:animate_positions", %{positions: positions})
      refute Enum.any?(positions, &(&1.id == "n1"))
      assert positions != []
    end
  end
end

defmodule FlowExampleWeb.Examples.NodesBTest do
  use FlowExampleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp count(view, selector) do
    view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query(selector) |> Enum.count()
  end

  defp position_change(id, x, y, dragging) do
    %{
      "type" => "position",
      "id" => id,
      "position" => %{"x" => x, "y" => y},
      "dragging" => dragging
    }
  end

  defp drag_move(view, id, x, y) do
    render_hook(view, "lf:drag_move", %{"changes" => [position_change(id, x, y, true)]})
  end

  defp drop(view, id, x, y) do
    render_hook(view, "lf:node_change", %{"changes" => [position_change(id, x, y, false)]})
  end

  defp select_nodes(view, ids) do
    render_hook(view, "lf:selection_change", %{"nodes" => ids, "edges" => []})
  end

  describe "pages" do
    for {path, flow_id} <- [
          {"/examples/nodes/proximity-connect", "#proximity-connect"},
          {"/examples/nodes/rotatable-node", "#rotatable-node"},
          {"/examples/nodes/node-position-animation", "#node-position-animation"},
          {"/examples/nodes/update-node", "#update-node"},
          {"/examples/nodes/shapes", "#shapes-flow"},
          {"/examples/overview/feature-overview", "#feature-overview"}
        ] do
      test "#{path} renders its flow", %{conn: conn} do
        {:ok, view, _html} = live(conn, unquote(path))
        assert has_element?(view, unquote(flow_id) <> "[phx-hook=LiveFlow]")
        assert has_element?(view, unquote(flow_id) <> " .lf-node")
      end
    end
  end

  describe "proximity connect" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/proximity-connect")
      %{view: view}
    end

    test "a close node gets a temporary edge that becomes real on drop", %{view: view} do
      render_hook(view, "lf:node_change", %{
        "changes" => [position_change("3", 60, 200, true)]
      })

      drag_move(view, "3", 330, 180)

      assert has_element?(
               view,
               ~s|#proximity-connect g.temp[data-edge-id="proximity-temp"][data-source="3"][data-target="4"]|
             )

      assert has_element?(view, ~s|.lf-node.proximity-near[data-node-id="4"]|)
      assert has_element?(view, "#proximity-status")

      drop(view, "3", 330, 180)

      refute has_element?(view, ~s|g[data-edge-id="proximity-temp"]|)
      refute has_element?(view, ".lf-node.proximity-near")
      assert has_element?(view, ~s|g[data-edge-id="e-3-4"][data-source="3"][data-target="4"]|)
      assert has_element?(view, "#proximity-none")
    end

    test "the edge goes from the left node to the right one", %{view: view} do
      drag_move(view, "4", 0, 200)

      assert has_element?(
               view,
               ~s|g[data-edge-id="proximity-temp"][data-source="4"][data-target="3"]|
             )

      drop(view, "4", 0, 200)
      assert has_element?(view, ~s|g[data-edge-id="e-4-3"][data-source="4"][data-target="3"]|)
    end

    test "moving away removes the temporary edge and dropping connects nothing", %{view: view} do
      drag_move(view, "3", 330, 180)
      assert has_element?(view, ~s|g[data-edge-id="proximity-temp"]|)

      drag_move(view, "3", 60, 420)
      refute has_element?(view, ~s|g[data-edge-id="proximity-temp"]|)

      drop(view, "3", 60, 420)
      assert count(view, "#proximity-connect g[data-edge-id]") == 1
    end

    test "connected nodes are not connected twice", %{view: view} do
      drag_move(view, "2", 100, 0)
      refute has_element?(view, ~s|g[data-edge-id="proximity-temp"]|)

      drop(view, "2", 100, 0)
      assert count(view, "#proximity-connect g[data-edge-id]") == 1
    end

    test "position changes without a drag (keyboard nudges) don't connect", %{view: view} do
      drop(view, "3", 330, 180)
      refute has_element?(view, ~s|g[data-edge-id="e-3-4"]|)
    end

    test "clear edges removes every edge", %{view: view} do
      view |> element("#clear-edges") |> render_click()
      assert count(view, "#proximity-connect g[data-edge-id]") == 0
    end
  end

  describe "rotatable node" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/rotatable-node")
      %{view: view}
    end

    test "rotate_node stores the normalized angle in the node data", %{view: view} do
      render_hook(view, "rotate_node", %{"node_id" => "1", "rotation" => 90})

      assert has_element?(
               view,
               ~s|#rotatable-1[data-rotation="90"][style*="rotate(90deg)"]|
             )

      render_hook(view, "rotate_node", %{"node_id" => "1", "rotation" => -30.4})
      assert has_element?(view, ~s|#rotatable-1[data-rotation="330"]|)
      assert has_element?(view, "#rotation-row-1", "330°")
    end

    test "the rotation is undoable", %{view: view} do
      render_hook(view, "rotate_node", %{"node_id" => "2", "rotation" => 45})
      assert has_element?(view, ~s|#rotatable-2[data-rotation="45"]|)

      render_hook(view, "lf:undo", %{})
      assert has_element?(view, ~s|#rotatable-2[data-rotation="0"]|)
    end

    test "the knob and the resizer follow the node flags", %{view: view} do
      refute has_element?(view, "#rotate-knob-2")
      view |> element("#toggle-rotatable-2") |> render_click()
      assert has_element?(view, "#rotate-knob-2.nodrag.nopan")

      select_nodes(view, ["1"])
      refute has_element?(view, ~s|.lf-node[data-node-id="1"] .lf-node-resizer|)

      select_nodes(view, ["3"])
      assert has_element?(view, ~s|.lf-node[data-node-id="3"] .lf-node-resizer|)
    end

    test "the snap option is exposed to the hook and reset clears rotations", %{view: view} do
      assert has_element?(view, ~s|#rotatable-canvas[data-rotation-snap="0"]|)

      view |> form("#rotation-options", rotation: %{snap: "true"}) |> render_change()
      assert has_element?(view, ~s|#rotatable-canvas[data-rotation-snap="15"]|)

      view |> element("#reset-rotation") |> render_click()
      assert has_element?(view, ~s|#rotatable-1[data-rotation="0"]|)
      assert has_element?(view, ~s|#rotatable-3[data-rotation="0"]|)
    end
  end

  describe "node position animation" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/node-position-animation")
      %{view: view}
    end

    test "a layout button animates every node and fits the view", %{view: view} do
      view |> element("#layout-circle") |> render_click()

      assert_push_event(view, "lf:animate_positions", %{
        flow_id: "node-position-animation",
        duration: 800,
        positions: positions
      })

      assert length(positions) == 12
      assert_push_event(view, "lf:fit_view", %{flow_id: "node-position-animation"})
      assert has_element?(view, "#layout-circle.text-primary")
    end

    test "the duration slider sets the animation duration", %{view: view} do
      view |> form("#animation-options", animation: %{duration: "300"}) |> render_change()
      view |> element("#layout-grid") |> render_click()

      assert_push_event(view, "lf:animate_positions", %{duration: 300, positions: positions})

      gateway = Enum.find(positions, &(&1.id == "gateway"))
      assert {gateway.x, gateway.y} == {0, 0}
    end

    test "every layout pushes positions and the final change is applied", %{view: view} do
      for layout <- ~w(tree-lr force random tree-tb) do
        view |> element("#layout-#{layout}") |> render_click()
        assert_push_event(view, "lf:animate_positions", %{positions: [_ | _]})
      end

      drop(view, "gateway", 1234, 567)
      assert has_element?(view, ~s|.lf-node[data-node-id="gateway"][style*="left: 1234"]|)
    end
  end

  describe "updating nodes" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/update-node")
      %{view: view}
    end

    test "label and background apply immediately", %{view: view} do
      view
      |> form("#update-node-form", node: %{label: "Hello", bg: "#1A192B", hidden: "false"})
      |> render_change()

      assert has_element?(
               view,
               ~s|#update-node .lf-node[data-node-id="1"][style*="background: #1a192b"]|,
               "Hello"
             )

      # Dark background: light text
      assert has_element?(
               view,
               ~s|.lf-node[data-node-id="1"][style*="--lf-text-primary: #ffffff"]|
             )

      assert has_element?(view, "#update-code", ~s|label: "Hello"|)
    end

    test "invalid colors are ignored and presets apply", %{view: view} do
      view
      |> form("#update-node-form", node: %{label: "Node 1", bg: "red", hidden: "false"})
      |> render_change()

      assert has_element?(view, ~s|.lf-node[data-node-id="1"][style*="background: #eeeeee"]|)

      view |> element("#preset-ff0072") |> render_click()
      assert has_element?(view, ~s|.lf-node[data-node-id="1"][style*="background: #ff0072"]|)
    end

    test "hiding the node also hides its edges", %{view: view} do
      view
      |> form("#update-node-form", node: %{label: "Node 1", bg: "#eeeeee", hidden: "true"})
      |> render_change()

      refute has_element?(view, ~s|.lf-node[data-node-id="1"]|)
      refute has_element?(view, ~s|g[data-edge-id="e1-2"]|)
      assert has_element?(view, ~s|g[data-edge-id="e2-3"]|)
      assert has_element?(view, "#update-code", "hidden: true")

      view
      |> form("#update-node-form", node: %{label: "Node 1", bg: "#eeeeee", hidden: "false"})
      |> render_change()

      assert has_element?(view, ~s|.lf-node[data-node-id="1"]|)
    end
  end

  describe "shapes" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/shapes")
      %{view: view}
    end

    test "every shape has a palette item with its path", %{view: view} do
      for shape <-
            ~w(circle round-rectangle rectangle hexagon diamond arrow-rectangle cylinder triangle parallelogram plus) do
        assert has_element?(view, ~s|#palette-#{shape}[draggable="true"] path[d^="M "]|)
      end
    end

    test "dropping a palette item adds a shape centered on the drop point", %{view: view} do
      render_hook(view, "lf:drop", %{
        "data" => %{"shape" => "hexagon"},
        "position" => %{"x" => 500, "y" => 300}
      })

      assert has_element?(
               view,
               ~s|#shapes-flow .lf-node[data-node-id="shape-1"][data-node-type="shape"][style*="left: 420"][style*="top: 255"]|
             )

      assert has_element?(
               view,
               ~s|.lf-node[data-node-id="shape-1"] svg[preserveAspectRatio="none"] path|
             )

      assert count(view, ~s|.lf-node[data-node-id="shape-1"] .lf-handle|) == 4
    end

    test "unknown shapes are ignored", %{view: view} do
      before = count(view, "#shapes-flow .lf-node")

      render_hook(view, "lf:drop", %{
        "data" => %{"shape" => "star"},
        "position" => %{"x" => 0, "y" => 0}
      })

      assert count(view, "#shapes-flow .lf-node") == before
    end

    test "the color picker recolors the selected shapes", %{view: view} do
      select_nodes(view, ["start", "save"])
      assert has_element?(view, "#selected-shapes", "2 selected shapes")

      view |> element("#color-cf4c2c") |> render_click()
      assert has_element?(view, ~s|.lf-node[data-node-id="start"] svg path[fill="#cf4c2c"]|)
      assert has_element?(view, ~s|.lf-node[data-node-id="save"] svg path[fill="#cf4c2c"]|)
      refute has_element?(view, ~s|.lf-node[data-node-id="valid"] svg path[fill="#cf4c2c"]|)

      view |> form("#shape-color-form", shape: %{color: "#123456"}) |> render_change()
      assert has_element?(view, ~s|.lf-node[data-node-id="start"] svg path[fill="#123456"]|)
    end

    test "the label is editable inside the node", %{view: view} do
      view |> form("#shape-label-start", %{label: "Begin"}) |> render_change()
      assert has_element?(view, ~s|#shape-label-input-start[value="Begin"]|)
    end

    test "loose connection mode connects two source handles", %{view: view} do
      render_hook(view, "lf:connect_end", %{
        "source" => "error",
        "source_handle" => "bottom",
        "target" => "save",
        "target_handle" => "right"
      })

      assert has_element?(
               view,
               ~s|g[data-source="error"][data-target="save"][data-target-handle="right"][data-path-type="smoothstep"]|
             )
    end
  end

  describe "feature overview" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/overview/feature-overview")
      %{view: view}
    end

    test "shows every edge path type, minimap and controls", %{view: view} do
      for type <- ~w(bezier straight step smoothstep) do
        assert has_element?(view, ~s|#feature-overview g[data-edge-id][data-path-type="#{type}"]|)
      end

      assert has_element?(view, ~s|#feature-overview .lf-edge[data-animated="true"]|)
      assert has_element?(view, "#feature-overview .lf-minimap")
      assert has_element?(view, ~s|.lf-node[data-node-id="annotation-1"][data-draggable="false"]|)
    end

    test "the toolbar buttons change the node emoji", %{view: view} do
      assert has_element?(view, "#toolbar-toolbar")
      view |> element(~s|button[phx-value-emoji="🔥"]|) |> render_click()
      assert has_element?(view, "#emoji-value-toolbar", "🔥")
    end

    test "the text input node labels its edge", %{view: view} do
      view |> form("#text-form-text", %{text: "Hello edge"}) |> render_change()
      assert has_element?(view, ~s|g[data-edge-id="e-text-output"] .lf-edge-label|, "Hello edge")

      view |> form("#text-form-text", %{text: ""}) |> render_change()
      refute has_element?(view, ~s|g[data-edge-id="e-text-output"] .lf-edge-label|)
    end

    test "the resizable node shows its resizer when selected", %{view: view} do
      refute has_element?(view, ~s|.lf-node[data-node-id="resizer"] .lf-node-resizer|)
      select_nodes(view, ["resizer"])
      assert has_element?(view, ~s|.lf-node[data-node-id="resizer"] .lf-node-resizer|)
    end
  end
end

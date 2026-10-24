defmodule FlowExampleWeb.Examples.WhiteboardWTest do
  use FlowExampleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FlowExampleWeb.Examples.Whiteboard.FreehandDrawLive

  @base "/examples/whiteboard"

  describe "pages" do
    for {slug, flow_id, overlay_id, tool} <- [
          {"eraser", "eraser-flow", "eraser-overlay", "eraser"},
          {"lasso-selection", "lasso-flow", "lasso-overlay", "lasso"},
          {"rectangle", "rectangle-flow", "rectangle-overlay", "rectangle"},
          {"freehand-draw", "freehand-flow", "freehand-overlay", "draw"}
        ] do
      test "#{slug} renders its flow and switches tools", %{conn: conn} do
        {:ok, view, _html} = live(conn, "#{@base}/#{unquote(slug)}")
        flow = "#" <> unquote(flow_id)
        overlay = "#" <> unquote(overlay_id)

        assert has_element?(view, flow <> "[phx-hook=LiveFlow]")
        assert has_element?(view, flow <> " .lf-node")

        assert has_element?(
                 view,
                 overlay <>
                   "[phx-update=ignore][data-flow-id=#{unquote(flow_id)}][data-tool=#{unquote(tool)}]"
               )

        assert has_element?(view, "#tool-#{unquote(tool)}[aria-pressed=true]")

        view |> element("#tool-select") |> render_click()
        assert has_element?(view, overlay <> "[data-tool=select]")
        assert has_element?(view, "#tool-select[aria-pressed=true]")

        # Unknown tools pushed by the hook are ignored
        render_hook(view, "set_tool", %{"tool" => "laser"})
        assert has_element?(view, overlay <> "[data-tool=select]")

        # Keyboard shortcuts are pushed by the hook
        render_hook(view, "set_tool", %{"tool" => unquote(tool)})
        assert has_element?(view, overlay <> "[data-tool=#{unquote(tool)}]")
      end
    end
  end

  describe "eraser" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/eraser")
      %{view: view}
    end

    test "erases the touched nodes, their connected edges and the touched edges", %{view: view} do
      render_hook(view, "erase", %{"nodes" => ["validate"], "edges" => ["e-route-notify"]})

      refute has_element?(view, ~s|#eraser-flow .lf-node[data-node-id="validate"]|)
      refute has_element?(view, ~s|#eraser-flow g[data-edge-id="e-trigger-validate"]|)
      refute has_element?(view, ~s|#eraser-flow g[data-edge-id="e-validate-route"]|)
      refute has_element?(view, ~s|#eraser-flow g[data-edge-id="e-route-notify"]|)

      assert has_element?(view, ~s|#eraser-flow .lf-node[data-node-id="route"]|)
      assert has_element?(view, ~s|#eraser-flow g[data-edge-id="e-route-archive"]|)

      assert has_element?(view, "#erased-nodes [data-value='1']")
      assert has_element?(view, "#erased-edges [data-value='3']")
    end

    test "locked nodes and unknown ids are ignored", %{view: view} do
      render_hook(view, "erase", %{"nodes" => ["trigger", "nope", 42], "edges" => ["missing"]})

      assert has_element?(view, ~s|#eraser-flow .lf-node[data-node-id="trigger"].eraser-locked|)
      assert has_element?(view, "#erased-nodes [data-value='0']")
      assert has_element?(view, "#erased-edges [data-value='0']")
    end

    test "undo brings erased elements back, reset restores the board", %{view: view} do
      render_hook(view, "erase", %{"nodes" => ["enrich"], "edges" => []})
      refute has_element?(view, ~s|#eraser-flow .lf-node[data-node-id="enrich"]|)

      view |> element("#eraser-undo") |> render_click()
      assert has_element?(view, ~s|#eraser-flow .lf-node[data-node-id="enrich"]|)
      assert has_element?(view, ~s|#eraser-flow g[data-edge-id="e-trigger-enrich"]|)

      render_hook(view, "erase", %{"nodes" => ["notify", "archive"], "edges" => []})
      refute has_element?(view, ~s|#eraser-flow .lf-node[data-node-id="notify"]|)

      view |> element("#eraser-reset") |> render_click()
      assert has_element?(view, ~s|#eraser-flow .lf-node[data-node-id="notify"]|)
      assert has_element?(view, ~s|#eraser-flow .lf-node[data-node-id="archive"]|)
      assert has_element?(view, "#erased-nodes [data-value='0']")
    end
  end

  describe "lasso selection" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/lasso-selection")
      %{view: view}
    end

    test "the partial switch sets the overlay mode", %{view: view} do
      assert has_element?(view, "#lasso-overlay[data-partial=true]")

      view |> form("#lasso-options", %{"lasso" => %{"partial" => "false"}}) |> render_change()
      assert has_element?(view, "#lasso-overlay[data-partial=false]")

      view |> form("#lasso-options", %{"lasso" => %{"partial" => "true"}}) |> render_change()
      assert has_element?(view, "#lasso-overlay[data-partial=true]")
    end

    test "the selection set by the hook is rendered and listed", %{view: view} do
      assert has_element?(view, "#lasso-selection-empty")

      render_hook(view, "lf:selection_change", %{
        "nodes" => ["validate", "enrich"],
        "edges" => ["e-trigger-validate"]
      })

      assert has_element?(view, "#lasso-selected-validate", "Validate")
      assert has_element?(view, "#lasso-selected-enrich", "Enrich")
      refute has_element?(view, "#lasso-selection-empty")

      assert has_element?(
               view,
               ~s|#lasso-flow .lf-node[data-node-id="validate"][data-selected="true"]|
             )

      assert has_element?(
               view,
               ~s|#lasso-flow .lf-node[data-node-id="route"][data-selected="false"]|
             )
    end
  end

  describe "rectangle" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/rectangle")
      %{view: view}
    end

    test "a drawn rect becomes a selected, resizable node and the tool goes back to select", %{
      view: view
    } do
      render_hook(view, "add_rectangle", %{"x" => 40, "y" => 400, "width" => 200, "height" => 120})

      rect = ~s|#rectangle-flow .lf-node[data-node-id="rect-4"]|

      assert has_element?(
               view,
               rect <>
                 ~s|[data-node-type="rectangle"][data-resizable="true"][data-selected="true"]| <>
                 ~s|[style*="left: 40"][style*="top: 400"][style*="width: 200"][style*="height: 120"]| <>
                 ~s|[style*="--rect: #0ea5e9"]|
             )

      assert has_element?(view, rect <> " .lf-node-resizer")
      assert has_element?(view, "#rectangle-overlay[data-tool=select]")

      assert has_element?(
               view,
               ~s|#rectangle-flow .lf-node[data-node-id="rect-1"][data-selected="false"]|
             )
    end

    test "uses the chosen color and can keep the tool active", %{view: view} do
      view |> element("#rectangle-color-rose") |> render_click()
      assert has_element?(view, ~s|#rectangle-overlay[data-color="#f43f5e"]|)

      view
      |> form("#rectangle-options", %{"options" => %{"keep_tool" => "true"}})
      |> render_change()

      render_hook(view, "add_rectangle", %{"x" => 0, "y" => 0, "width" => 4, "height" => 300.5})

      # Clamped to the minimum size
      assert has_element?(
               view,
               ~s|#rectangle-flow .lf-node[data-node-id="rect-4"][style*="width: 10px"][style*="--rect: #f43f5e"][data-selected="false"]|
             )

      assert has_element?(view, "#rectangle-overlay[data-tool=rectangle]")
    end

    test "recolors the selected rectangles", %{view: view} do
      render_hook(view, "lf:selection_change", %{"nodes" => ["rect-1"], "edges" => []})
      view |> element("#rectangle-color-violet") |> render_click()

      assert has_element?(
               view,
               ~s|#rectangle-flow .lf-node[data-node-id="rect-1"][style*="--rect: #8b5cf6"]|
             )

      assert has_element?(
               view,
               ~s|#rectangle-flow .lf-node[data-node-id="rect-2"][style*="--rect: #f59e0b"]|
             )
    end

    test "invalid rects are ignored", %{view: view} do
      render_hook(view, "add_rectangle", %{"x" => "0", "y" => 0, "width" => 10, "height" => 10})
      render_hook(view, "add_rectangle", %{"x" => 0, "y" => 0, "width" => -5, "height" => 10})

      refute has_element?(view, ~s|#rectangle-flow .lf-node[data-node-id="rect-4"]|)
    end
  end

  describe "freehand draw" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/freehand-draw")
      %{view: view}
    end

    test "renders the pre-drawn strokes as freehand nodes", %{view: view} do
      assert has_element?(
               view,
               ~s|#freehand-flow .lf-node[data-node-id="stroke-1"][data-node-type="freehand"]|
             )

      assert has_element?(
               view,
               ~s|#freehand-flow .lf-node[data-node-id="stroke-1"] svg[preserveAspectRatio="none"] path.freehand-ink[vector-effect="non-scaling-stroke"]|
             )
    end

    test "a stroke is simplified into a node sized to its bounding box", %{view: view} do
      # 21 collinear points: the simplification keeps both ends
      points = for i <- 0..20, do: [100 + i * 5, 300]
      render_hook(view, "add_stroke", %{"points" => points, "zoom" => 1})

      stroke = ~s|#freehand-flow .lf-node[data-node-id="stroke-3"]|

      # Width 4 → 4px of padding around the box
      assert has_element?(
               view,
               stroke <>
                 ~s|[data-node-type="freehand"][data-resizable="true"]| <>
                 ~s|[style*="left: 96"][style*="top: 296"][style*="width: 108"][style*="height: 8"]|
             )

      assert has_element?(view, stroke <> ~s| svg[viewBox="0 0 108.0 8.0"]|)
      assert has_element?(view, stroke <> ~s| path.freehand-ink[d="M4.0 4.0L104.0 4.0"]|)
      assert has_element?(view, "#last-stroke", "21")
    end

    test "uses the pen color and width", %{view: view} do
      view |> element("#pen-color-rose") |> render_click()
      view |> form("#pen-form", %{"pen" => %{"width" => "8"}}) |> render_change()

      assert has_element?(view, ~s|#freehand-overlay[data-color="#f43f5e"][data-width="8"]|)

      render_hook(view, "add_stroke", %{"points" => [[0, 0], [30, 40], [60, 0]]})

      assert has_element?(
               view,
               ~s|#freehand-flow .lf-node[data-node-id="stroke-3"] path.freehand-ink[stroke-width="8"][style*="#f43f5e"]|
             )
    end

    test "clear drawings removes every stroke, undo brings them back", %{view: view} do
      view |> element("#freehand-clear") |> render_click()

      refute has_element?(view, ~s|#freehand-flow .lf-node[data-node-type="freehand"]|)
      assert has_element?(view, ~s|#freehand-flow .lf-node[data-node-id="idea"]|)

      view |> element("#freehand-undo") |> render_click()
      assert has_element?(view, ~s|#freehand-flow .lf-node[data-node-id="stroke-1"]|)
      assert has_element?(view, ~s|#freehand-flow .lf-node[data-node-id="stroke-2"]|)
    end

    test "invalid points are ignored", %{view: view} do
      render_hook(view, "add_stroke", %{"points" => [["a", 1], [1], "x"]})
      render_hook(view, "add_stroke", %{"points" => "nope"})

      refute has_element?(view, ~s|#freehand-flow .lf-node[data-node-id="stroke-3"]|)
    end
  end

  describe "freehand geometry" do
    test "simplify keeps the corners and drops the noise" do
      points = [{0.0, 0.0}, {10.0, 0.2}, {20.0, -0.1}, {30.0, 15.0}, {40.0, 0.1}, {50.0, 0.0}]

      assert FreehandDrawLive.simplify(points, 1.0) == [
               {0.0, 0.0},
               {20.0, -0.1},
               {30.0, 15.0},
               {40.0, 0.1},
               {50.0, 0.0}
             ]

      assert FreehandDrawLive.simplify([{0.0, 0.0}, {5.0, 0.1}, {10.0, 0.0}], 1.0) == [
               {0.0, 0.0},
               {10.0, 0.0}
             ]
    end

    test "smooth_path uses quadratic curves through the midpoints" do
      assert FreehandDrawLive.smooth_path([{0, 0}, {10, 0}, {20, 10}]) ==
               "M0.0 0.0Q10.0 0.0 15.0 5.0L20.0 10.0"

      assert FreehandDrawLive.smooth_path([{3, 4}]) == "M3.0 4.0L3.0 4.0"
    end
  end
end

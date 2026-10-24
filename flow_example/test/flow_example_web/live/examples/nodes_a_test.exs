defmodule FlowExampleWeb.Examples.NodesATest do
  use FlowExampleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp count(view, selector) do
    view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query(selector) |> Enum.count()
  end

  defp select_nodes(view, ids) do
    render_hook(view, "lf:selection_change", %{"nodes" => ids, "edges" => []})
  end

  defp drop(view, node_id, handle_type, x, y, reason \\ "pane") do
    render_hook(view, "lf:connect_cancel", %{
      "node_id" => node_id,
      "handle_id" => handle_type,
      "handle_type" => handle_type,
      "position" => %{"x" => x, "y" => y},
      "reason" => reason
    })
  end

  defp connect_handles(view, source, target) do
    render_hook(view, "lf:connect_end", %{
      "source" => source,
      "target" => target,
      "source_handle" => "out",
      "target_handle" => "in"
    })
  end

  defp drag(view, id, x, y, dragging) do
    change = %{"type" => "position", "id" => id, "position" => %{"x" => x, "y" => y}}

    if dragging do
      render_hook(view, "lf:drag_move", %{"changes" => [Map.put(change, "dragging", true)]})
    else
      render_hook(view, "lf:node_change", %{"changes" => [Map.put(change, "dragging", false)]})
    end
  end

  describe "pages" do
    for {slug, flow_id} <- [
          {"add-node-on-edge-drop", "#add-node-on-edge-drop"},
          {"connection-limit", "#connection-limit"},
          {"custom-node", "#custom-node-flow"},
          {"delete-middle-node", "#delete-middle-node"},
          {"drag-handle", "#drag-handle"},
          {"easy-connect", "#easy-connect"},
          {"intersections", "#intersections"},
          {"node-toolbar", "#node-toolbar"}
        ] do
      test "#{slug} renders its flow", %{conn: conn} do
        {:ok, view, _html} = live(conn, "/examples/nodes/#{unquote(slug)}")
        assert has_element?(view, unquote(flow_id) <> "[phx-hook=LiveFlow]")
        assert has_element?(view, unquote(flow_id) <> " .lf-node")
      end
    end
  end

  describe "add node on edge drop" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/add-node-on-edge-drop")
      %{view: view}
    end

    test "a line released on the pane adds a connected node centered on the drop point", %{
      view: view
    } do
      drop(view, "0", "source", 200, 300)

      assert has_element?(
               view,
               ~s|#add-node-on-edge-drop .lf-node[data-node-id="1"][style*="left: 125"][style*="top: 300"]|
             )

      assert has_element?(view, ~s|g[data-source="0"][data-target="1"]|)
    end

    test "a line from a target handle creates the new node upstream", %{view: view} do
      drop(view, "0", "source", 200, 300)
      drop(view, "1", "target", 400, 600)

      assert has_element?(view, ~s|.lf-node[data-node-id="2"][style*="top: 560"]|)
      assert has_element?(view, ~s|g[data-source="2"][data-target="1"]|)
    end

    test "invalid and aborted connections add nothing", %{view: view} do
      drop(view, "0", "source", 200, 300, "invalid")
      drop(view, "0", "source", 200, 300, "abort")

      assert count(view, ".lf-node") == 1
    end
  end

  describe "connection limit" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/connection-limit")
      %{view: view}
    end

    test "a full handle is not connectable and rejects connections", %{view: view} do
      assert has_element?(
               view,
               ~s|.lf-node[data-node-id="single"] .lf-handle[data-handle-connectable="false"]|
             )

      assert has_element?(view, "#limit-count-single", "1/1")

      connect_handles(view, "c", "single")
      refute has_element?(view, ~s|g[data-source="c"][data-target="single"]|)
    end

    test "the handle is disabled once the limit is reached", %{view: view} do
      assert has_element?(
               view,
               ~s|.lf-node[data-node-id="double"] .lf-handle[data-handle-connectable="true"]|
             )

      connect_handles(view, "c", "double")

      assert has_element?(view, ~s|g[data-source="c"][data-target="double"]|)
      assert has_element?(view, "#limit-count-double", "2/2")

      assert has_element?(
               view,
               ~s|.lf-node[data-node-id="double"] .lf-handle[data-handle-connectable="false"]|
             )

      connect_handles(view, "a", "double")
      refute has_element?(view, ~s|g[data-source="a"][data-target="double"]|)
    end

    test "deleting an edge frees the handle", %{view: view} do
      render_hook(view, "lf:edge_change", %{
        "changes" => [%{"type" => "remove", "id" => "a-single"}]
      })

      assert has_element?(view, "#limit-count-single", "0/1")

      assert has_element?(
               view,
               ~s|.lf-node[data-node-id="single"] .lf-handle[data-handle-connectable="true"]|
             )

      connect_handles(view, "c", "single")
      assert has_element?(view, ~s|g[data-source="c"][data-target="single"]|)
    end
  end

  describe "custom node" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/custom-node")
      %{view: view}
    end

    test "the color input changes the node data and the background", %{view: view} do
      assert has_element?(view, ~s|#custom-node-canvas[style*="--cn-bg: #c9f1dd"]|)

      view |> form("#color-form", %{color: "#1a192b"}) |> render_change()

      assert has_element?(view, "#selector-color", "#1a192b")
      assert has_element?(view, ~s|#custom-node-canvas[style*="--cn-bg: #1a192b"]|)
      # light strokes on a dark background
      assert has_element?(view, ~s|#custom-node-canvas[style*="--cn-ink: #ffffff"]|)
    end

    test "presets apply and invalid colors are ignored", %{view: view} do
      view |> element("#swatch-ff0072") |> render_click()
      assert has_element?(view, "#selector-color", "#ff0072")

      render_hook(view, "change_color", %{"color" => "red; background: url(x)"})
      assert has_element?(view, "#selector-color", "#ff0072")
    end

    test "two outputs leave from the right side of the selector", %{view: view} do
      assert has_element?(view, ~s|g[data-source="selector"][data-source-handle="a"]|)
      assert has_element?(view, ~s|g[data-source="selector"][data-source-handle="b"]|)
    end
  end

  describe "delete middle node" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/delete-middle-node")
      %{view: view}
    end

    test "deleting the selection reconnects incomers to outgoers", %{view: view} do
      select_nodes(view, ["3"])
      render_hook(view, "lf:delete_selected", %{})

      refute has_element?(view, ~s|.lf-node[data-node-id="3"]|)
      assert has_element?(view, ~s|g[data-source="1"][data-target="4"]|)
      assert has_element?(view, ~s|g[data-source="2"][data-target="4"]|)
      assert has_element?(view, ~s|g[data-source="4"][data-target="5"]|)
    end

    test "deleting a chain at once connects what surrounds it", %{view: view} do
      select_nodes(view, ["3", "4"])
      render_hook(view, "lf:delete_selected", %{})

      assert has_element?(view, ~s|g[data-source="1"][data-target="5"]|)
      assert has_element?(view, ~s|g[data-source="2"][data-target="5"]|)
      assert count(view, "g[data-edge-id]") == 2
    end

    test "node remove changes are bridged and duplicates skipped", %{view: view} do
      render_hook(view, "lf:connect_end", %{
        "source" => "1",
        "target" => "4",
        "source_handle" => "source",
        "target_handle" => "target"
      })

      render_hook(view, "lf:node_change", %{"changes" => [%{"type" => "remove", "id" => "3"}]})

      refute has_element?(view, ~s|.lf-node[data-node-id="3"]|)
      assert count(view, ~s|g[data-source="1"][data-target="4"]|) == 1
      assert has_element?(view, ~s|g[data-source="2"][data-target="4"]|)
    end
  end

  describe "drag handle" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/drag-handle")
      %{view: view}
    end

    test "nodes declare their drag handle", %{view: view} do
      assert has_element?(
               view,
               ~s|.lf-node[data-node-id="grip"][data-drag-handle=".drag-handle"]|
             )

      assert has_element?(view, ~s|.lf-node[data-node-id="grip"] .drag-handle|)
      assert has_element?(view, ~s|.lf-node[data-node-id="note"] .drag-handle|)
      refute has_element?(view, ~s|.lf-node[data-node-id="source"][data-drag-handle]|)
    end

    test "controls inside the node keep working", %{view: view} do
      view |> form("#level-form-note", %{level: "85"}) |> render_change()
      assert has_element?(view, "#level-value-note", "85%")
    end
  end

  describe "easy connect" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/easy-connect")
      %{view: view}
    end

    test "handles cover the whole node and nodes drag from their tab", %{view: view} do
      assert has_element?(
               view,
               ~s|.lf-node[data-node-id="1"] .lf-handle[data-handle-type="source"][style*="inset: 0"]|
             )

      assert has_element?(
               view,
               ~s|.lf-node[data-node-id="1"] .lf-handle[data-handle-type="target"][style*="inset: 0"]|
             )

      assert has_element?(
               view,
               ~s|.lf-node[data-node-id="1"][data-drag-handle=".ec-drag-handle"]|
             )

      assert has_element?(view, ~s|.lf-node[data-node-id="1"] .ec-drag-handle|)
    end

    test "connecting marks the source node and creates a floating edge", %{view: view} do
      render_hook(view, "lf:connect_start", %{
        "node_id" => "1",
        "handle_id" => "source",
        "handle_type" => "source"
      })

      assert has_element?(view, ~s|.lf-node[data-node-id="1"].is-connecting-from|)

      render_hook(view, "lf:connect_end", %{
        "source" => "1",
        "target" => "3",
        "source_handle" => "source",
        "target_handle" => "target"
      })

      refute has_element?(view, ".lf-node.is-connecting-from")

      assert has_element?(
               view,
               ~s|g[data-source="1"][data-target="3"][data-source-floating="true"][data-target-floating="true"]|
             )
    end

    test "a cancelled connection clears the mark", %{view: view} do
      render_hook(view, "lf:connect_start", %{
        "node_id" => "2",
        "handle_id" => "source",
        "handle_type" => "source"
      })

      render_hook(view, "lf:connect_cancel", %{
        "node_id" => "2",
        "handle_id" => "source",
        "handle_type" => "source",
        "position" => %{"x" => 0, "y" => 0},
        "reason" => "pane"
      })

      refute has_element?(view, ".lf-node.is-connecting-from")
    end
  end

  describe "intersections" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/intersections")
      %{view: view}
    end

    test "nodes overlapped by the dragged node are highlighted", %{view: view} do
      refute has_element?(view, ".lf-node.highlight")

      drag(view, "2", 10, 20, true)

      assert has_element?(view, ~s|.lf-node[data-node-id="1"].highlight|)
      refute has_element?(view, ~s|.lf-node[data-node-id="2"].highlight|)
      refute has_element?(view, ~s|.lf-node[data-node-id="3"].highlight|)
      assert has_element?(view, "#overlapping-list", "Node 1")

      drag(view, "2", 1000, 1000, true)
      refute has_element?(view, ".lf-node.highlight")
    end

    test "highlights are cleared when the drag ends", %{view: view} do
      drag(view, "2", 10, 20, true)
      assert has_element?(view, ".lf-node.highlight")

      drag(view, "2", 10, 20, false)
      refute has_element?(view, ".lf-node.highlight")
      assert has_element?(view, "#overlapping-none")
    end
  end

  describe "node toolbar" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/nodes/node-toolbar")
      %{view: view}
    end

    test "the toolbar shows while the node is selected", %{view: view} do
      refute has_element?(view, ".lf-node-toolbar")

      select_nodes(view, ["1"])
      assert has_element?(view, ~s|#toolbar-1[data-position="top"][data-align="center"]|)
      refute has_element?(view, "#toolbar-2")
    end

    test "position and align come from the sidebar", %{view: view} do
      select_nodes(view, ["1"])

      view |> element("#toolbar-position-left") |> render_click()
      view |> element("#toolbar-align-end") |> render_click()

      assert has_element?(view, ~s|#toolbar-1[data-position="left"][data-align="end"]|)
    end

    test "always visible shows every toolbar", %{view: view} do
      view
      |> form("#toolbar-visibility-form", %{toolbar: %{always_visible: "true"}})
      |> render_change()

      assert has_element?(view, "#toolbar-1")
      assert has_element?(view, "#toolbar-2")
      assert has_element?(view, "#toolbar-3")
    end

    test "toolbar buttons change, duplicate and delete the node", %{view: view} do
      select_nodes(view, ["1"])

      view |> element("#toolbar-1-color") |> render_click()
      assert has_element?(view, ~s|.lf-node[data-node-id="1"]|, "violet")

      view |> element("#toolbar-1-duplicate") |> render_click()
      assert has_element?(view, ~s|.lf-node[data-node-id="n4"]|, "Node 4")

      view |> element("#toolbar-1-delete") |> render_click()
      refute has_element?(view, ~s|.lf-node[data-node-id="1"]|)
      refute has_element?(view, ~s|g[data-source="1"]|)
    end
  end
end

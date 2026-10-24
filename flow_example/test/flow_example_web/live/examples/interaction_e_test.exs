defmodule FlowExampleWeb.Examples.InteractionETest do
  use FlowExampleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @base "/examples/interaction"

  defp node_count(view) do
    view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query(".lf-node") |> Enum.count()
  end

  defp open_node_menu(view, id, selection \\ []) do
    render_hook(view, "lf:node_context_menu", %{
      "id" => id,
      "x" => 120,
      "y" => 90,
      "position" => %{"x" => 10, "y" => 20},
      "selection" => selection
    })
  end

  describe "pages" do
    for {slug, flow_id} <- [
          {"computing-flows", "computing-flows"},
          {"connection-events", "connection-events"},
          {"context-menu", "context-menu-flow"},
          {"contextual-zoom", "contextual-zoom"},
          {"drag-and-drop", "drag-and-drop"},
          {"prevent-cycles", "prevent-cycles"},
          {"save-and-restore", "save-and-restore"}
        ] do
      test "#{slug} renders its flow", %{conn: conn} do
        {:ok, view, _html} = live(conn, "#{@base}/#{unquote(slug)}")
        assert has_element?(view, "##{unquote(flow_id)}[phx-hook=LiveFlow]")
      end
    end
  end

  describe "computing flows" do
    test "values flow through the graph", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/computing-flows")

      assert has_element?(view, "#value-upper", "HELLO")
      assert has_element?(view, "#result-result-upper", "HELLO")
      assert has_element?(view, "#result-result-text-2", "world")

      view |> form("#text-form-text-1", %{"text" => "live flow"}) |> render_change()

      assert has_element?(view, "#value-upper", "LIVE FLOW")
      assert has_element?(view, "#result-result-upper", "LIVE FLOW")
      assert has_element?(view, "#output-upper", "LIVE FLOW")
    end

    test "values are recomputed when edges change", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/computing-flows")

      render_hook(view, "lf:edge_change", %{
        "changes" => [%{"type" => "remove", "id" => "e-text-1-upper"}]
      })

      refute has_element?(view, "#value-upper", "HELLO")
      assert has_element?(view, "#value-upper", "connect a text node")

      # Text B now feeds the uppercase node
      render_hook(view, "lf:connect_end", %{
        "source" => "text-2",
        "target" => "upper",
        "source_handle" => nil,
        "target_handle" => nil
      })

      assert has_element?(view, "#value-upper", "WORLD")
      assert has_element?(view, "#result-result-upper", "WORLD")
    end

    test "the uppercase node accepts a single input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/computing-flows")

      render_hook(view, "lf:connect_end", %{"source" => "text-2", "target" => "upper"})

      refute has_element?(view, "g[data-source=text-2][data-target=upper]")
      assert has_element?(view, "#value-upper", "HELLO")
    end

    test "adds text nodes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/computing-flows")

      view |> element("#add-text-node") |> render_click()

      assert has_element?(view, "#text-form-text-3")
    end
  end

  describe "connection events" do
    test "groups the events of each attempt", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/connection-events")
      assert has_element?(view, "#attempts-empty")

      render_hook(view, "lf:connect_start", %{
        "node_id" => "1",
        "handle_id" => nil,
        "handle_type" => "source"
      })

      assert has_element?(view, "#attempt-1[data-status=pending]")

      render_hook(view, "lf:connect_end", %{
        "source" => "1",
        "target" => "4",
        "source_handle" => nil,
        "target_handle" => nil
      })

      assert has_element?(view, "#attempt-1[data-status=connected]")
      assert has_element?(view, "#attempt-1-step-0", "lf:connect_start")
      assert has_element?(view, "#attempt-1-step-1", "lf:connect_end")
      assert has_element?(view, "g[data-source='1'][data-target='4']")

      render_hook(view, "lf:connect_start", %{
        "node_id" => "3",
        "handle_id" => "b",
        "handle_type" => "source"
      })

      render_hook(view, "lf:connect_cancel", %{
        "node_id" => "3",
        "handle_id" => "b",
        "handle_type" => "source",
        "position" => %{"x" => 412.4, "y" => 380.2},
        "reason" => "pane"
      })

      assert has_element?(view, "#attempt-2[data-status=cancelled]")
      assert has_element?(view, "#attempt-2-step-1", "reason: pane")
      assert has_element?(view, "#attempt-2-step-1", "(412, 380)")

      render_hook(view, "lf:reconnect_edge", %{
        "edge_id" => "e2-4",
        "end" => "target",
        "node_id" => "3",
        "handle_id" => nil
      })

      assert has_element?(view, "#attempt-3[data-status=reconnected]")
      assert has_element?(view, "g[data-edge-id=e2-4][data-target='3']")

      view |> element("#clear-timeline") |> render_click()

      refute has_element?(view, "#attempt-1")
      assert has_element?(view, "#attempts-empty")
    end

    test "rejected connections are marked", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/connection-events")

      render_hook(view, "lf:connect_start", %{"node_id" => "1", "handle_type" => "source"})
      render_hook(view, "lf:connect_end", %{"source" => "1", "target" => "2"})

      assert has_element?(view, "#attempt-1[data-status=rejected]")
      assert has_element?(view, "#attempt-1-step-1", "already exists")
    end
  end

  describe "context menu" do
    test "node menu duplicates, recolors and deletes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/context-menu")
      refute has_element?(view, "#context-menu")

      open_node_menu(view, "2")
      assert has_element?(view, "#context-menu[data-x='120'][data-y='90']")

      view |> element("#menu-duplicate") |> render_click()
      refute has_element?(view, "#context-menu")
      assert has_element?(view, ".lf-node[data-node-id='5']", "Node 2 copy")

      open_node_menu(view, "2")
      view |> element("#menu-color-rose") |> render_click()
      assert has_element?(view, ".lf-node[data-node-id='2'] [data-color=rose]")

      open_node_menu(view, "2")
      view |> element("#menu-delete") |> render_click()
      refute has_element?(view, ".lf-node[data-node-id='2']")
    end

    test "acts on the whole selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/context-menu")

      open_node_menu(view, "2", ["2", "3"])
      assert has_element?(view, "#context-menu", "2 nodes")

      view |> element("#menu-delete") |> render_click()
      refute has_element?(view, ".lf-node[data-node-id='2']")
      refute has_element?(view, ".lf-node[data-node-id='3']")
    end

    test "edge and pane menus", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/context-menu")

      render_hook(view, "lf:edge_context_menu", %{
        "id" => "e1-2",
        "x" => 50,
        "y" => 60,
        "position" => %{"x" => 0, "y" => 0}
      })

      view |> element("#menu-delete-edge") |> render_click()
      refute has_element?(view, "g[data-edge-id=e1-2]")

      render_hook(view, "lf:pane_context_menu", %{
        "x" => 300,
        "y" => 200,
        "position" => %{"x" => 640, "y" => 380}
      })

      view |> element("#menu-add-node") |> render_click()
      assert view |> element(".lf-node[data-node-id='5']") |> render() =~ "left: 640.0px"
    end

    test "closes on pane click and Escape", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/context-menu")

      open_node_menu(view, "1")
      render_hook(view, "lf:pane_click", %{"position" => %{"x" => 0, "y" => 0}})
      refute has_element?(view, "#context-menu")

      open_node_menu(view, "1")
      view |> element("#context-menu") |> render_keydown(%{"key" => "Escape"})
      refute has_element?(view, "#context-menu")
    end
  end

  describe "contextual zoom" do
    test "nodes show details only when zoomed in", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/contextual-zoom")
      assert has_element?(view, "#service-gateway[data-detail=full]")

      render_hook(view, "lf:viewport_change", %{"x" => 0, "y" => 0, "zoom" => 0.5})

      assert has_element?(view, "#service-gateway[data-detail=compact]")
      assert has_element?(view, "#zoom-value", "0.50")
      assert has_element?(view, "#zoom-status[data-detailed=false]")

      render_hook(view, "lf:viewport_change", %{"x" => 0, "y" => 0, "zoom" => 1.2})
      assert has_element?(view, "#service-gateway[data-detail=full]")
    end

    test "the threshold is configurable", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/contextual-zoom")
      render_hook(view, "lf:viewport_change", %{"x" => 0, "y" => 0, "zoom" => 0.7})
      assert has_element?(view, "#service-db[data-detail=compact]")

      view |> form("#zoom-options", zoom: %{threshold: "0.6"}) |> render_change()
      assert has_element?(view, "#service-db[data-detail=full]")
    end

    test "zoom buttons push lf:zoom_to", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/contextual-zoom")
      view |> element("#zoom-out-button") |> render_click()
      assert_push_event(view, "lf:zoom_to", %{zoom: 0.5})
    end
  end

  describe "drag and drop" do
    test "dropping a palette item creates a centered node", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/drag-and-drop")
      assert has_element?(view, "#palette-action[draggable=true]")

      render_hook(view, "lf:drop", %{
        "data" => %{"type" => "action"},
        "position" => %{"x" => 400, "y" => 192}
      })

      html = view |> element(".lf-node[data-node-id=action-1]") |> render()
      assert html =~ "left: 288.0px"
      assert html =~ "top: 160.0px"
    end

    test "unknown payloads are ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/drag-and-drop")
      before = node_count(view)

      render_hook(view, "lf:drop", %{
        "data" => %{"type" => "rm -rf"},
        "position" => %{"x" => 0, "y" => 0}
      })

      render_hook(view, "lf:drop", %{"data" => "plain text", "position" => %{"x" => 0, "y" => 0}})

      assert node_count(view) == before
    end
  end

  describe "prevent cycles" do
    test "rejects connections that close a cycle", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/prevent-cycles")

      render_hook(view, "lf:connect_end", %{"source" => "5", "target" => "1"})

      refute has_element?(view, "g[data-source='5'][data-target='1']")
      assert has_element?(view, "#cycle-notice", "cycle")
      assert has_element?(view, "#cycle-attempt-1[data-result=rejected]")
      # The path that would close the loop is highlighted
      assert has_element?(view, "g[data-edge-id=e4-5].cycle-edge")
      assert has_element?(view, ".lf-node.cycle-node[data-node-id='1']")
    end

    test "accepts connections without cycles", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/prevent-cycles")

      render_hook(view, "lf:connect_end", %{"source" => "5", "target" => "6"})

      assert has_element?(view, "g[data-source='5'][data-target='6']")
      assert has_element?(view, "#connection-accepted")
      assert has_element?(view, "#cycle-attempt-1[data-result=ok]")

      # 6 now depends on 1, so 6 -> 1 is a cycle too
      render_hook(view, "lf:connect_end", %{"source" => "6", "target" => "1"})
      refute has_element?(view, "g[data-source='6'][data-target='1']")
      assert has_element?(view, "#cycle-notice")
    end
  end

  describe "save and restore" do
    test "saves to the hook and restores the saved flow", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/save-and-restore")
      assert has_element?(view, "#flow-storage[phx-hook]")
      assert has_element?(view, "#no-save")

      view |> element("#save-button") |> render_click()
      assert_push_event(view, "flow-storage:save", %{json: json, saved_at: _})
      assert has_element?(view, "#last-save", "4 nodes")

      view |> element("#add-node-button") |> render_click()
      assert has_element?(view, ".lf-node[data-node-id='5']")

      view |> element("#restore-button") |> render_click()
      assert_push_event(view, "flow-storage:load", %{})

      render_hook(view, "restore_flow", %{"json" => json, "saved_at" => "2026-01-01T00:00:00Z"})

      refute has_element?(view, ".lf-node[data-node-id='5']")
      assert has_element?(view, ".lf-node[data-node-id='4']")
      assert has_element?(view, "#storage-status[data-kind=ok]")
      assert_push_event(view, "lf:set_viewport", %{zoom: _})
    end

    test "restoring without a save", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/save-and-restore")

      render_hook(view, "restore_flow", %{})

      assert has_element?(view, "#storage-status[data-kind=error]", "Nothing saved")
    end

    test "shows a save from a previous visit", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@base}/save-and-restore")
      json = LiveFlow.Serializer.to_json(LiveFlow.State.new())

      render_hook(view, "storage_info", %{"json" => json, "saved_at" => "2026-10-20T09:15:00Z"})

      assert has_element?(view, "#last-save", "09:15:00")
      assert has_element?(view, "#last-save", "previous visit")
    end
  end
end

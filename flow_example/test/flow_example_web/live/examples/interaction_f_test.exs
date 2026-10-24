defmodule FlowExampleWeb.Examples.InteractionFTest do
  use FlowExampleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FlowExample.FlowStore
  alias FlowExampleWeb.Examples.Interaction.CollaborativeLive

  @interaction "/examples/interaction"
  @grouping "/examples/grouping"

  defp node_count(view) do
    view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query(".lf-node") |> Enum.count()
  end

  defp text(view, selector) do
    view |> element(selector) |> render() |> LazyHTML.from_fragment() |> LazyHTML.text()
  end

  defp config(view, flow_id) do
    [json] =
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("##{flow_id}")
      |> LazyHTML.attribute("data-config")

    Jason.decode!(json)
  end

  defp connect_nodes(view, source, target, opts \\ []) do
    render_hook(view, "lf:connect_end", %{
      "source" => source,
      "source_handle" => Keyword.get(opts, :source_handle, "source"),
      "target" => target,
      "target_handle" => Keyword.get(opts, :target_handle, "target")
    })
  end

  defp move(view, id, x, y, dragging) do
    render_hook(view, "lf:node_change", %{
      "changes" => [
        %{
          "type" => "position",
          "id" => id,
          "position" => %{"x" => x, "y" => y},
          "dragging" => dragging
        }
      ]
    })
  end

  defp drag(view, id, {x0, y0}, {x1, y1}) do
    move(view, id, x0, y0, true)
    move(view, id, x1, y1, false)
  end

  describe "pages" do
    for {path, flow_id} <- [
          {"#{@interaction}/touch-device", "touch-flow"},
          {"#{@interaction}/validation", "validation-flow"},
          {"#{@interaction}/helper-lines", "helper-lines-flow"},
          {"#{@interaction}/copy-paste", "copy-paste-flow"},
          {"#{@interaction}/undo-redo", "undo-redo-flow"},
          {"#{@interaction}/collaborative", "collab-flow"},
          {"#{@grouping}/selection-grouping", "selection-grouping-flow"},
          {"#{@grouping}/parent-child-relation", "parent-child-flow"}
        ] do
      test "#{path} renders its flow", %{conn: conn} do
        {:ok, view, _html} = live(conn, unquote(path))
        assert has_element?(view, "##{unquote(flow_id)}[phx-hook=LiveFlow]")
      end
    end
  end

  describe "touch device" do
    test "a tap connection shows a hint until it ends", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@interaction}/touch-device")
      refute has_element?(view, "#touch-hint")

      render_hook(view, "lf:connect_start", %{
        "node_id" => "sensor",
        "handle_id" => "source",
        "handle_type" => "source"
      })

      assert has_element?(view, "#touch-hint", "Sensor")

      connect_nodes(view, "sensor", "alert")
      refute has_element?(view, "#touch-hint")
      assert has_element?(view, "#touch-flow g[data-source=sensor][data-target=alert]")

      render_hook(view, "lf:connect_start", %{
        "node_id" => "alert",
        "handle_id" => "source",
        "handle_type" => "source"
      })

      render_hook(view, "lf:connect_cancel", %{
        "node_id" => "alert",
        "handle_id" => "source",
        "handle_type" => "source",
        "position" => %{"x" => 0, "y" => 0},
        "reason" => "pane"
      })

      refute has_element?(view, "#touch-hint")
    end

    test "options toggle connect_on_click and the handle size", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@interaction}/touch-device")
      assert config(view, "touch-flow")["connectOnClick"] == true
      assert has_element?(view, "#touch-canvas[data-handle-size=large]")

      view
      |> form("#touch-options", touch: %{connect_on_click: "false", handle_size: "huge"})
      |> render_change()

      assert config(view, "touch-flow")["connectOnClick"] == false
      assert has_element?(view, "#touch-canvas[data-handle-size=huge]")
    end
  end

  describe "validation" do
    test "the server only accepts Input → B", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@interaction}/validation")

      connect_nodes(view, "input", "A")
      refute has_element?(view, "g[data-source=input][data-target=A]")
      assert has_element?(view, "#validation-attempts li[data-result=rejected][data-by=server]")
      assert has_element?(view, ".lf-node.validation-rejected[data-node-id=A]")

      connect_nodes(view, "input", "B")
      assert has_element?(view, "g[data-source=input][data-target=B]")
      assert has_element?(view, "#validation-attempts li[data-result=ok]", "Input → B")
    end

    test "typed handles are checked on both sides", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@interaction}/validation")

      # The browser refused the drop on the text handle of the formatter
      render_hook(view, "lf:connect_cancel", %{
        "node_id" => "number",
        "handle_id" => "source",
        "handle_type" => "source",
        "position" => %{"x" => 881, "y" => 103},
        "reason" => "invalid"
      })

      assert has_element?(
               view,
               "#validation-attempts li[data-by=client]",
               "Type mismatch: number → text"
             )

      # A mismatched connect_end is refused by the server as well
      connect_nodes(view, "number", "format", target_handle: "label")
      refute has_element?(view, "g[data-source=number][data-target-handle=label]")

      connect_nodes(view, "text", "format", target_handle: "label")
      assert has_element?(view, "g[data-source=text][data-target-handle=label]")

      # Untyped handles accept anything
      connect_nodes(view, "number", "logger")
      assert has_element?(view, "g[data-source=number][data-target=logger]")
    end
  end

  describe "helper lines" do
    test "toggling helper lines remounts the flow and snapping updates the config", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@interaction}/helper-lines")
      assert config(view, "helper-lines-flow")["helperLines"] == true
      assert config(view, "helper-lines-flow")["snapToGrid"] == false

      view |> form("#helper-lines-options", helper: %{helper_lines: "false"}) |> render_change()
      refute has_element?(view, "#helper-lines-flow")
      assert config(view, "helper-lines-flow-off")["helperLines"] == false

      view
      |> form("#helper-lines-options", helper: %{helper_lines: "true", snap_to_grid: "true"})
      |> render_change()

      config = config(view, "helper-lines-flow")
      assert config["helperLines"] == true
      assert config["snapToGrid"] == true
      assert config["snapGrid"] == [20, 20]
      assert has_element?(view, "#helper-lines-flow-background[data-background=lines]")
    end

    test "nodes can be added and moved", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@interaction}/helper-lines")
      count = node_count(view)

      view |> element("#add-box") |> render_click()
      assert node_count(view) == count + 1

      drag(view, "small", {48, 150}, {60, 300})
      assert has_element?(view, ~s|.lf-node[data-node-id=small][style*="top: 300.0px"]|)
    end
  end

  describe "copy and paste" do
    test "header buttons copy, paste and cut the selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@interaction}/copy-paste")
      assert node_count(view) == 4
      assert has_element?(view, "#paste-btn[disabled]")

      view |> element("#copy-btn") |> render_click()
      assert text(view, "#clipboard-count") =~ "2"
      assert text(view, "#clipboard-edges") =~ "0"

      view |> element("#paste-btn") |> render_click()
      assert node_count(view) == 6
      # The pasted nodes are selected
      assert text(view, "#selection-count") =~ "2"

      render_hook(view, "lf:cut", %{})
      assert node_count(view) == 4
      assert text(view, "#clipboard-count") =~ "2"
    end

    test "keyboard events copy the edges between copied nodes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@interaction}/copy-paste")

      render_hook(view, "lf:selection_change", %{"nodes" => ["source", "check"], "edges" => []})
      render_hook(view, "lf:copy", %{})
      assert text(view, "#clipboard-edges") =~ "1"

      render_hook(view, "lf:paste", %{})
      assert node_count(view) == 6

      render_hook(view, "lf:duplicate", %{})
      assert node_count(view) == 8
    end
  end

  describe "undo and redo" do
    test "adding a node can be undone and redone", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@interaction}/undo-redo")
      assert has_element?(view, "#undo-btn[disabled]")

      view |> element("#add-node") |> render_click()
      assert node_count(view) == 5
      assert text(view, "#undo-count") =~ "1"
      assert has_element?(view, "#history-timeline [id^=undo-entry]", "Add Transform 1")

      view |> element("#undo-btn") |> render_click()
      assert node_count(view) == 4
      assert text(view, "#undo-count") =~ "0"
      assert text(view, "#redo-count") =~ "1"
      assert has_element?(view, "#history-timeline [id^=redo-entry]", "Add Transform 1")

      view |> element("#redo-btn") |> render_click()
      assert node_count(view) == 5
      assert text(view, "#redo-count") =~ "0"
    end

    test "moves, connections and deletions are labeled and undone", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@interaction}/undo-redo")

      drag(view, "ship", {600, 120}, {700, 300})
      assert has_element?(view, "[id^=undo-entry]", "Move Ship")

      connect_nodes(view, "stock", "ship")
      assert has_element?(view, "g[data-source=stock][data-target=ship]")
      assert has_element?(view, "[id^=undo-entry]", "Connect Reserve stock → Ship")

      render_hook(view, "lf:selection_change", %{"nodes" => ["pay"], "edges" => []})
      render_hook(view, "lf:delete_selected", %{})
      refute has_element?(view, ".lf-node[data-node-id=pay]")
      assert text(view, "#undo-count") =~ "3"

      render_hook(view, "lf:undo", %{})
      assert has_element?(view, ".lf-node[data-node-id=pay]")

      render_hook(view, "lf:undo", %{})
      refute has_element?(view, "g[data-source=stock][data-target=ship]")

      render_hook(view, "lf:undo", %{})
      assert has_element?(view, ~s|.lf-node[data-node-id=ship][style*="left: 600.0px"]|)
      assert text(view, "#redo-count") =~ "3"
    end
  end

  describe "collaborative" do
    setup %{conn: conn} do
      {:ok, alice, _html} = live(conn, "#{@interaction}/collaborative")
      {:ok, bob, _html} = live(conn, "#{@interaction}/collaborative")
      # The room is shared by every test: start from the default board
      alice |> element("#reset-flow") |> render_click()
      %{alice: alice, bob: bob}
    end

    test "changes made in one tab appear in the other", %{alice: alice, bob: bob} do
      refute has_element?(bob, "g[data-source=idea][data-target=launch]")

      connect_nodes(alice, "idea", "launch")
      assert has_element?(bob, "g[data-source=idea][data-target=launch]")

      move(alice, "launch", 760, 333, false)
      assert has_element?(bob, ~s|.lf-node[data-node-id=launch][style*="top: 333.0px"]|)

      count = node_count(bob)
      alice |> element("#add-note") |> render_click()
      assert node_count(bob) == count + 1

      render_hook(alice, "lf:selection_change", %{"nodes" => ["research"], "edges" => []})
      render_hook(alice, "lf:delete_selected", %{})
      refute has_element?(bob, ".lf-node[data-node-id=research]")
      refute has_element?(alice, ".lf-node[data-node-id=research]")

      # The shared store has every change, so a new tab starts from it
      flow = FlowStore.get("showcase", &CollaborativeLive.default_flow/0)
      assert Enum.any?(flow.edges, fn {_id, e} -> e.source == "idea" and e.target == "launch" end)
      refute Map.has_key?(flow.nodes, "research")
      assert flow.nodes["launch"].position.y == 333.0
    end

    test "a reset is shared and the selection stays local", %{alice: alice, bob: bob} do
      render_hook(alice, "lf:selection_change", %{"nodes" => ["idea"], "edges" => []})
      assert has_element?(alice, ".lf-node[data-node-id=idea][data-selected=true]")
      refute has_element?(bob, ".lf-node[data-node-id=idea][data-selected=true]")

      connect_nodes(bob, "design", "launch")
      assert has_element?(alice, "g[data-source=design][data-target=launch]")

      alice |> element("#reset-flow") |> render_click()
      refute has_element?(bob, "g[data-source=design][data-target=launch]")
    end

    test "drags and cursors are relayed, presence lists both users", %{alice: alice, bob: bob} do
      changes = [
        %{
          "type" => "position",
          "id" => "idea",
          "position" => %{"x" => 10, "y" => 20},
          "dragging" => true
        }
      ]

      render_hook(alice, "lf:drag_move", %{"changes" => changes})
      assert_push_event(bob, "lf:remote_drag", %{changes: ^changes})

      alice_name = text(alice, "#current-user") |> String.trim()
      render_hook(alice, "lf:cursor_move", %{"x" => 120, "y" => 80})
      assert_push_event(bob, "lf:remote_cursor", %{x: 120, y: 80, name: ^alice_name})

      assert has_element?(bob, "#presence-list", alice_name)
    end
  end

  describe "selection grouping" do
    test "groups the selection and ungroups it again", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@grouping}/selection-grouping")
      assert has_element?(view, "#group-btn[disabled]")

      render_hook(view, "lf:selection_change", %{"nodes" => ["A", "B", "C"], "edges" => []})
      refute has_element?(view, "#group-btn[disabled]")
      assert has_element?(view, "#toolbar-group-btn", "Group 3 nodes")

      view |> element("#group-btn") |> render_click()

      assert has_element?(view, ".lf-node[data-node-id=group-1][data-node-type=group]")

      for id <- ~w(A B C) do
        assert has_element?(view, ".lf-node[data-node-id=#{id}][data-parent-id=group-1]")
      end

      # Same place on screen (rendered with absolute positions)
      assert has_element?(view, ~s|.lf-node[data-node-id=B][style*="left: 220.0px"]|)
      assert has_element?(view, "#ungroup-btn")

      view |> element("#ungroup-btn") |> render_click()
      refute has_element?(view, ".lf-node[data-node-id=group-1]")
      refute has_element?(view, ".lf-node[data-node-id=A][data-parent-id]")
      assert has_element?(view, ~s|.lf-node[data-node-id=B][style*="left: 220.0px"]|)
    end

    test "a group grows back to fit its children after a resize", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@grouping}/selection-grouping")
      render_hook(view, "lf:selection_change", %{"nodes" => ["D", "E"], "edges" => []})
      view |> element("#group-btn") |> render_click()

      render_hook(view, "lf:node_change", %{
        "changes" => [
          %{
            "type" => "resize",
            "id" => "group-1",
            "width" => 80,
            "height" => 60,
            "resizing" => true
          },
          %{
            "type" => "resize",
            "id" => "group-1",
            "width" => 80,
            "height" => 60,
            "resizing" => false
          }
        ]
      })

      refute has_element?(view, ~s|.lf-node[data-node-id=group-1][style*="width: 80px"]|)
      assert has_element?(view, "#event-log", "fit_group")
    end
  end

  describe "parent child relation" do
    test "dropping a node on a group attaches it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@grouping}/parent-child-relation")

      render_hook(view, "lf:drag_move", %{
        "changes" => [
          %{
            "type" => "position",
            "id" => "n4",
            "position" => %{"x" => 460, "y" => 120},
            "dragging" => true
          }
        ]
      })

      assert has_element?(view, ".lf-node.drop-target[data-node-id=group-b]", "Drop to attach")

      drag(view, "n4", {-220, 120}, {460, 120})
      refute has_element?(view, ".drop-target")
      assert has_element?(view, ".lf-node[data-node-id=n4][data-parent-id=group-b]")
      assert has_element?(view, "#relation-group-b", "Node 4")
      refute has_element?(view, "#relation-loose", "Node 4")
    end

    test "dragging a child out of its group detaches it", %{conn: conn} do
      {:ok, view, _html} = live(conn, "#{@grouping}/parent-child-relation")
      assert has_element?(view, ".lf-node[data-node-id=n1][data-parent-id=group-a]")

      # Moving inside its own group doesn't highlight anything
      render_hook(view, "lf:drag_move", %{
        "changes" => [
          %{
            "type" => "position",
            "id" => "n1",
            "position" => %{"x" => 60, "y" => 90},
            "dragging" => true
          }
        ]
      })

      refute has_element?(view, ".drop-target")
      refute has_element?(view, ".drop-leave")

      render_hook(view, "lf:drag_move", %{
        "changes" => [
          %{
            "type" => "position",
            "id" => "n1",
            "position" => %{"x" => -400, "y" => 400},
            "dragging" => true
          }
        ]
      })

      assert has_element?(view, ".lf-node.drop-leave[data-node-id=group-a]", "Drop to detach")

      # Positions of child nodes are relative to their parent (group A is at 0,0)
      drag(view, "n1", {30, 60}, {-400, 400})
      refute has_element?(view, ".lf-node[data-node-id=n1][data-parent-id]")
      assert has_element?(view, ~s|.lf-node[data-node-id=n1][style*="left: -400.0px"]|)
      assert has_element?(view, "#relation-loose", "Node 1")
    end
  end
end

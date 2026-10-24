defmodule FlowExampleWeb.Examples.EdgesCTest do
  use FlowExampleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp count(view, selector) do
    view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query(selector) |> Enum.count()
  end

  defp attribute(view, selector, name) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> LazyHTML.attribute(name)
  end

  defp connect_nodes(view, source, target, source_handle \\ "source", target_handle \\ "target") do
    render_hook(view, "lf:connect_end", %{
      "source" => source,
      "target" => target,
      "source_handle" => source_handle,
      "target_handle" => target_handle
    })
  end

  defp select_edges(view, ids) do
    render_hook(view, "lf:selection_change", %{"nodes" => [], "edges" => ids})
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
    # {slug, flow id, starts with edges?}
    for {slug, flow_id, edges?} <- [
          {"animating-edges", "#animating-edges-flow", true},
          {"custom-connectionline", "#custom-connection-line-flow", false},
          {"custom-edges", "#custom-edges-flow", true},
          {"delete-edge-on-drop", "#delete-edge-on-drop-flow", true},
          {"edge-label-renderer", "#edge-label-renderer-flow", true},
          {"edge-intersection", "#edge-intersection-flow", true},
          {"edge-toolbar", "#edge-toolbar-flow", true},
          {"floating-edges", "#floating-edges-flow", true}
        ] do
      test "#{slug} renders its flow", %{conn: conn} do
        {:ok, view, _html} = live(conn, "/examples/edges/#{unquote(slug)}")
        assert has_element?(view, unquote(flow_id) <> "[phx-hook=LiveFlow]")
        assert has_element?(view, unquote(flow_id) <> " .lf-node")
        assert has_element?(view, unquote(flow_id) <> " g[data-edge-id]") == unquote(edges?)
      end
    end
  end

  describe "animating edges" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/animating-edges")
      %{view: view}
    end

    test "motion follows the edge's own path through mpath", %{view: view} do
      assert has_element?(
               view,
               ~s|g[data-edge-id="comet"][data-source="sensor"] path#animating-edges-flow-path-comet.lf-edge|
             )

      assert has_element?(
               view,
               ~s|g[data-edge-id="comet"] mpath[href="#animating-edges-flow-path-comet"]|
             )

      assert has_element?(view, ~s|g[data-edge-id="comet"] circle.ae-comet-head|)
      assert count(view, ~s|g[data-edge-id="packets"] rect.ae-packet|) == 3
      assert has_element?(view, ~s|g[data-edge-id="plane"] .ae-plane-icon|)

      assert has_element?(
               view,
               ~s|g[data-edge-id="flow"][data-path-type="smoothstep"] path.ae-flow-overlay|
             )
    end

    test "speed changes the animation durations", %{view: view} do
      assert has_element?(view, ~s|g[data-edge-id="comet"] [dur="2.4s"]|)

      view |> element("#speed-fast") |> render_click()

      assert has_element?(view, ~s|g[data-edge-id="comet"] [dur="1.2s"]|)
      assert has_element?(view, ~s|.ae-flow-overlay[style*="animation-duration: 0.45s"]|)
    end

    test "new connections use the selected animated type", %{view: view} do
      view |> form("#new-edge-type-form", %{new_edge: %{type: "plane"}}) |> render_change()
      connect_nodes(view, "sensor", "queue")

      assert has_element?(view, ~s|g[data-source="sensor"][data-target="queue"] .ae-plane-bg|)
    end
  end

  describe "custom connection line" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/custom-connectionline")
      %{view: view}
    end

    test "the line type, style and class go to the flow config", %{view: view} do
      flow = "#custom-connection-line-flow"
      assert has_element?(view, flow <> ~s|[data-config*='"connectionLineClass":"ccl-dot"']|)
      assert has_element?(view, flow <> ~s|[data-config*='"connectionLineType":"bezier"']|)
      assert has_element?(view, "#ccl-dot-marker")

      view |> element("#line-type-step") |> render_click()
      view |> element("#preset-bold") |> render_click()

      assert has_element?(view, flow <> ~s|[data-config*='"connectionLineType":"step"']|)

      assert has_element?(
               view,
               flow <> ~s|[data-config*='"connectionLineStyle":"stroke: #ff0072']|
             )

      assert has_element?(view, flow <> ~s|[data-config*='"connectionLineClass":null']|)
      assert has_element?(view, "#ccl-code", "connection_line_type: :step")
    end

    test "new edges use the line type", %{view: view} do
      view |> element("#line-type-smoothstep") |> render_click()
      connect_nodes(view, "source", "b")

      assert has_element?(
               view,
               ~s|g[data-source="source"][data-target="b"][data-path-type="smoothstep"]|
             )
    end

    test "the snap radius is configurable", %{view: view} do
      view |> form("#radius-form", %{behavior: %{radius: "55"}}) |> render_change()

      assert has_element?(
               view,
               ~s|#custom-connection-line-flow[data-config*='"connectionRadius":55']|
             )
    end
  end

  describe "custom edges" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/custom-edges")
      %{view: view}
    end

    test "special paths: self loop arc and bidirectional curves", %{view: view} do
      assert has_element?(
               view,
               ~s|g[data-edge-id="retry"][data-special-path="loop"][data-ce-source="worker"][data-ce-target="worker"]|
             )

      refute has_element?(view, ~s|g[data-edge-id="retry"][data-source]|)
      assert attribute(view, ~s|g[data-edge-id="retry"] path.lf-edge|, "d") |> hd() =~ " A "

      assert count(view, ~s|g[data-special-path="bidirectional"]|) == 2
      [request] = attribute(view, ~s|g[data-edge-id="request"] path.lf-edge|, "d")
      assert request =~ " Q "
      assert has_element?(view, ~s|g[data-edge-id="response"]|, "response")
    end

    test "the button edge deletes itself", %{view: view} do
      assert has_element?(
               view,
               ~s|g[data-edge-id="enqueue"][data-source="api"][data-path-type="bezier"]|
             )

      view |> element("#delete-edge-enqueue") |> render_click()
      refute has_element?(view, ~s|g[data-edge-id="enqueue"]|)
    end

    test "the labeled edge renders HTML and new connections get a button", %{view: view} do
      assert has_element?(
               view,
               ~s|g[data-edge-id="complete"][data-path-type="smoothstep"] #rich-label-complete|,
               "~120 ms"
             )

      connect_nodes(view, "api", "done", "out", "in")
      assert has_element?(view, ~s|g[data-source="api"][data-target="done"] .ce-delete-btn|)
    end
  end

  describe "delete edge on drop" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/delete-edge-on-drop")
      %{view: view}
    end

    test "edges are reconnectable", %{view: view} do
      assert has_element?(
               view,
               ~s|.lf-edge-reconnect-handle[data-edge-id="a-t1"][data-reconnect-end="target"]|
             )

      render_hook(view, "lf:reconnect_edge", %{
        "edge_id" => "a-t1",
        "end" => "target",
        "node_id" => "t3",
        "handle_id" => "target"
      })

      assert has_element?(view, ~s|g[data-edge-id="a-t1"][data-source="a"][data-target="t3"]|)
    end

    test "dropping an end on the pane deletes the edge, it can be restored", %{view: view} do
      render_hook(view, "lf:delete_reconnect_edge", %{
        "edge_id" => "a-t1",
        "end" => "target",
        "position" => %{"x" => 300, "y" => 100}
      })

      refute has_element?(view, ~s|g[data-edge-id="a-t1"]|)
      assert has_element?(view, "#deleted-a-t1", "Source A → Target 1")

      assert has_element?(
               view,
               ~s|.lf-node[data-node-type="poof"][style*="left: 252"][style*="top: 86"]|
             )

      view |> element("#restore-a-t1") |> render_click()

      assert has_element?(view, ~s|g[data-edge-id="a-t1"][data-target="t1"]|)
      refute has_element?(view, "#deleted-a-t1")
    end

    test "the drop marker goes away", %{view: view} do
      render_hook(view, "lf:delete_reconnect_edge", %{
        "edge_id" => "b-t3",
        "end" => "source",
        "position" => %{"x" => 0, "y" => 0}
      })

      [id] = attribute(view, ~s|.lf-node[data-node-type="poof"]|, "data-node-id")
      send(view.pid, {:remove_poof, id})

      refute has_element?(view, ~s|.lf-node[data-node-type="poof"]|)
    end

    test "new connections are reconnectable", %{view: view} do
      connect_nodes(view, "b", "t1")

      assert has_element?(
               view,
               ~s|g[data-source="b"][data-target="t1"] .lf-edge-reconnect-handle|
             )
    end
  end

  describe "edge label renderer" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/edge-label-renderer")
      %{view: view}
    end

    test "labels are rendered as HTML by the renderers", %{view: view} do
      assert has_element?(
               view,
               ~s|g[data-edge-id="web-api"] foreignObject.lf-edge-label-custom #label-web-api|,
               "32 ms"
             )

      assert has_element?(view, ~s|#label-api-auth|, "req/s")
      # per-edge override
      assert has_element?(
               view,
               ~s|g[data-edge-id="billing-ledger"] #label-billing-ledger.elr-alert|
             )
    end

    test "buttons inside a label work", %{view: view} do
      assert has_element?(view, "#approvals-count", "2")

      view |> element("#approve-api-billing") |> render_click()

      assert has_element?(view, "#approvals-count", "3")
      assert has_element?(view, "#label-api-billing", "3")
    end

    test "the start/end edge has labels at both ends", %{view: view} do
      assert has_element?(
               view,
               ~s|g[data-edge-id="auth-events"][data-endpoint-labels][data-source-side="right"][data-target-side="left"]|
             )

      assert has_element?(view, "#endpoint-start-auth-events", "publish")
      assert has_element?(view, "#endpoint-end-auth-events", "deliver")

      assert has_element?(
               view,
               ~s|g[data-edge-id="auth-events"] > foreignObject #label-auth-events|
             )
    end
  end

  describe "edge intersection" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/edge-intersection")
      %{view: view}
    end

    test "edges crossed by the dragged node are highlighted", %{view: view} do
      refute has_element?(view, "g.is-hit")

      drag(view, "probe", 200, -10, true)

      assert has_element?(view, ~s|g.is-hit[data-edge-id="e1-2"]|)
      assert count(view, "g.is-hit") == 1
      assert has_element?(view, ~s|.lf-node[data-node-id="probe"].is-probing|)
      assert has_element?(view, "#hit-e1-2", "Node 1 — Node 2")

      drag(view, "probe", 1000, 1000, true)
      refute has_element?(view, "g.is-hit")
      refute has_element?(view, ".lf-node.is-probing")
    end

    test "edges attached to the dragged node are ignored", %{view: view} do
      # Node 2 sits on its own edges' ends; over the 1-3 edge midpoint it crosses only that one
      drag(view, "2", 240, 130, true)

      assert has_element?(view, ~s|g.is-hit[data-edge-id="e1-3"]|)
      refute has_element?(view, ~s|g.is-hit[data-source="2"]|)
      refute has_element?(view, ~s|g.is-hit[data-target="2"]|)
    end

    test "highlights are cleared when the drag ends", %{view: view} do
      drag(view, "probe", 200, -10, true)
      assert has_element?(view, "g.is-hit")

      drag(view, "probe", 200, -10, false)
      refute has_element?(view, "g.is-hit")
      assert has_element?(view, "#hits-none")
      assert has_element?(view, ~s|.lf-node[data-node-id="probe"].probe|)
    end
  end

  describe "edge toolbar" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/edge-toolbar")
      %{view: view}
    end

    test "the toolbar shows on the selected edge", %{view: view} do
      assert has_element?(view, "#edge-toolbar-e-validate-route")
      assert count(view, "[role=toolbar]") == 1

      select_edges(view, ["e-route-notify"])

      assert has_element?(view, "#edge-toolbar-e-route-notify")
      refute has_element?(view, "#edge-toolbar-e-validate-route")
      assert has_element?(view, "#selected-edge", "e-route-notify")

      select_edges(view, [])
      refute has_element?(view, "[role=toolbar]")
      assert has_element?(view, "#selected-none")
    end

    test "buttons change color, animation and type", %{view: view} do
      edge = ~s|g[data-edge-id="e-validate-route"]|

      view |> element("#edge-toolbar-e-validate-route-color") |> render_click()
      assert has_element?(view, edge <> ~s| path.lf-edge[style*="stroke: #ff0072"]|)
      assert has_element?(view, "#selected-color", "#ff0072")

      view |> element("#edge-toolbar-e-validate-route-animate") |> render_click()
      assert has_element?(view, edge <> ~s| path.lf-edge[data-animated="true"]|)

      view |> element("#edge-toolbar-e-validate-route-type") |> render_click()
      assert has_element?(view, edge <> ~s|[data-path-type="smoothstep"]|)
      assert has_element?(view, "#selected-type", ":smoothstep")
    end

    test "delete removes the edge", %{view: view} do
      view |> element("#edge-toolbar-e-validate-route-delete") |> render_click()
      refute has_element?(view, ~s|g[data-edge-id="e-validate-route"]|)
    end
  end

  describe "floating edges" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/floating-edges")
      %{view: view}
    end

    test "every edge floats on both ends", %{view: view} do
      assert count(view, ~s|g[data-source-floating="true"][data-target-floating="true"]|) == 8
    end

    test "new connections float too", %{view: view} do
      connect_nodes(view, "phoenix", "liveview")

      assert has_element?(
               view,
               ~s|g[data-source="phoenix"][data-target="liveview"][data-source-floating="true"][data-target-floating="true"]|
             )
    end

    test "settings change the path type and the floating ends", %{view: view} do
      view
      |> form("#floating-form", %{
        floating: %{path_type: "straight", source_floating: "false", target_floating: "true"}
      })
      |> render_change()

      assert count(view, ~s|g[data-path-type="straight"]|) == 8
      refute has_element?(view, "g[data-source-floating]")
      assert count(view, ~s|g[data-target-floating="true"]|) == 8

      connect_nodes(view, "nx", "req")

      assert has_element?(
               view,
               ~s|g[data-source="nx"][data-target="req"][data-path-type="straight"][data-target-floating="true"]|
             )

      refute has_element?(view, ~s|g[data-source="nx"][data-target="req"][data-source-floating]|)
    end
  end
end

defmodule FlowExampleWeb.Examples.EdgesDTest do
  use FlowExampleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias FlowExampleWeb.Examples.Edges.EdgeRoutingLive
  alias LiveFlow.{Edge, Node, State}

  defp text(view, selector) do
    view |> element(selector) |> render() |> LazyHTML.from_fragment() |> LazyHTML.text()
  end

  defp attribute(view, selector, name) do
    view
    |> render()
    |> LazyHTML.from_document()
    |> LazyHTML.query(selector)
    |> LazyHTML.attribute(name)
  end

  describe "pages" do
    for {path, flow_id} <- [
          {"/examples/edges/markers", "#markers-flow"},
          {"/examples/edges/multi-connection-line", "#multi-connection-flow"},
          {"/examples/edges/reconnect-edge", "#reconnect-flow"},
          {"/examples/edges/simple-floating-edges", "#simple-floating-flow"},
          {"/examples/edges/temporary-edges", "#temporary-edges-flow"},
          {"/examples/edges/editable-edge", "#editable-edge-flow"},
          {"/examples/edges/edge-routing", "#edge-routing-flow"}
        ] do
      test "#{path} renders its flow", %{conn: conn} do
        {:ok, view, _html} = live(conn, unquote(path))
        assert has_element?(view, unquote(flow_id) <> "[phx-hook=LiveFlow]")
      end
    end
  end

  describe "markers" do
    test "renders a marker definition for every type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/markers")

      for type <- ~w(arrow arrow_closed circle circle_filled diamond diamond_filled) do
        assert has_element?(view, "#markers-flow marker#lf-#{type}")
      end

      assert has_element?(view, "path.lf-edge[data-edge-id=both-ends][marker-start]")
      refute has_element?(view, "path.lf-edge[data-edge-id=no-marker][marker-end]")
    end

    test "the playground form restyles the playground edge", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/markers")

      view
      |> form("#marker-form",
        playground: %{
          marker_start: "none",
          marker_end: "diamond",
          color: "#22c55e",
          size: "20",
          stroke_width: "2"
        }
      )
      |> render_change()

      id =
        LiveFlow.Components.Marker.marker_id(%{
          type: :diamond,
          color: "#22c55e",
          width: 20,
          height: 20,
          stroke_width: 2
        })

      assert has_element?(view, "marker##{id}")

      assert has_element?(
               view,
               ~s|path.lf-edge[data-edge-id=playground][marker-end="url(##{id})"]|
             )

      refute has_element?(view, "path.lf-edge[data-edge-id=playground][marker-start]")
      assert text(view, "#marker-code") =~ "type: :diamond"
    end
  end

  describe "multi connection line" do
    test "one lf:connect_end per selected node creates one edge each", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/multi-connection-line")
      assert text(view, "#selected-count") =~ "2"

      for source <- ["sensor-a", "sensor-b"] do
        render_hook(view, "lf:connect_end", %{
          "source" => source,
          "source_handle" => "source",
          "target" => "aggregator",
          "target_handle" => "target"
        })
      end

      assert has_element?(view, "g[data-source=sensor-a][data-target=aggregator]")
      assert has_element?(view, "g[data-source=sensor-b][data-target=aggregator]")
      assert text(view, "#edge-count") =~ "2"

      view |> element("#select-sources") |> render_click()
      assert text(view, "#selected-count") =~ "4"

      view |> element("#clear-edges") |> render_click()
      refute has_element?(view, "g[data-target=aggregator]")
    end
  end

  describe "reconnect edge" do
    test "reconnects an edge and keeps it when dropped on the pane", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/reconnect-edge")

      render_hook(view, "lf:reconnect_edge", %{
        "edge_id" => "a-c",
        "end" => "target",
        "node_id" => "d",
        "handle_id" => "target"
      })

      assert has_element?(view, "g[data-edge-id=a-c][data-target=d]")
      assert text(view, "#reconnect-count") =~ "1"

      render_hook(view, "lf:delete_reconnect_edge", %{"edge_id" => "a-c"})
      assert has_element?(view, "g[data-edge-id=a-c][data-target=d]")
      assert text(view, "#kept-count") =~ "1"
    end

    test "refuses the end an edge doesn't allow", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/reconnect-edge")

      render_hook(view, "lf:reconnect_edge", %{
        "edge_id" => "b-c",
        "end" => "source",
        "node_id" => "a",
        "handle_id" => "source"
      })

      assert has_element?(view, "g[data-edge-id=b-c][data-source=b]")
    end
  end

  describe "simple floating edges" do
    test "edges use the sides facing each other, live while dragging", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/simple-floating-edges")

      assert has_element?(
               view,
               "g[data-edge-id=hub-api][data-source-handle=top][data-target-handle=bottom]"
             )

      render_hook(view, "lf:drag_move", %{
        "changes" => [
          %{
            "type" => "position",
            "id" => "api",
            "position" => %{"x" => 900, "y" => 200},
            "dragging" => true
          }
        ]
      })

      assert has_element?(
               view,
               "g[data-edge-id=hub-api][data-source-handle=right][data-target-handle=left]"
             )

      render_hook(view, "lf:node_change", %{
        "changes" => [
          %{
            "type" => "position",
            "id" => "api",
            "position" => %{"x" => 320, "y" => 700},
            "dragging" => false
          }
        ]
      })

      assert has_element?(
               view,
               "g[data-edge-id=hub-api][data-source-handle=bottom][data-target-handle=top]"
             )
    end

    test "the edge path type can be changed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/simple-floating-edges")
      view |> form("#floating-form", edges: %{type: "smoothstep"}) |> render_change()
      assert has_element?(view, "g[data-edge-id=hub-api][data-path-type=smoothstep]")
    end
  end

  describe "temporary edges" do
    test "a connection released on the pane becomes a temporary edge", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/temporary-edges")
      assert text(view, "#temporary-count") =~ "1"

      render_hook(view, "lf:connect_cancel", %{
        "node_id" => "process",
        "handle_id" => "source",
        "handle_type" => "source",
        "position" => %{"x" => 700, "y" => -40},
        "reason" => "pane"
      })

      assert text(view, "#temporary-count") =~ "2"

      [edge_id] = attribute(view, "g.temporary-edge[data-source=process]", "data-edge-id")
      [ghost_id] = attribute(view, "g[data-edge-id=#{edge_id}]", "data-target")
      assert has_element?(view, ".lf-node[data-node-id=#{ghost_id}][data-node-type=ghost]")

      # Dropped on the pane again: nothing changes
      render_hook(view, "lf:delete_reconnect_edge", %{"edge_id" => edge_id})
      assert has_element?(view, "g.temporary-edge[data-edge-id=#{edge_id}]")

      # Dropped on a real handle: regular edge, ghost removed
      render_hook(view, "lf:reconnect_edge", %{
        "edge_id" => edge_id,
        "end" => "target",
        "node_id" => "done",
        "handle_id" => "target"
      })

      assert has_element?(view, "g[data-edge-id=#{edge_id}][data-target=done]")
      refute has_element?(view, "g.temporary-edge[data-edge-id=#{edge_id}]")
      refute has_element?(view, ".lf-node[data-node-id=#{ghost_id}]")
      assert text(view, "#temporary-count") =~ "1"
    end

    test "other cancel reasons don't create anything", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/temporary-edges")

      render_hook(view, "lf:connect_cancel", %{
        "node_id" => "process",
        "handle_id" => "source",
        "handle_type" => "source",
        "position" => %{"x" => 700, "y" => -40},
        "reason" => "abort"
      })

      assert text(view, "#temporary-count") =~ "1"
    end

    test "clearing removes temporary edges and their ghosts", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/temporary-edges")
      view |> element("#clear-temporary") |> render_click()
      refute has_element?(view, ".lf-node[data-node-type=ghost]")
      refute has_element?(view, "g.temporary-edge")
    end
  end

  describe "editable edge" do
    test "control points can be inserted, moved and removed", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/editable-edge")
      assert has_element?(view, "#editable-edge-controller[phx-hook]")

      points = "circle.editable-point[data-edge-id=input-output]"
      assert length(attribute(view, points, "data-index")) == 3

      render_hook(view, "insert_point", %{
        "edge_id" => "input-output",
        "index" => 1,
        "x" => 410,
        "y" => 420
      })

      assert attribute(view, points, "cx") == ["300", "410", "520", "740"]

      render_hook(view, "move_point", %{
        "edge_id" => "input-output",
        "index" => 0,
        "x" => 250,
        "y" => 380
      })

      assert has_element?(view, "#{points}[data-index='0'][cx='250'][cy='380']")

      render_hook(view, "remove_point", %{"edge_id" => "input-output", "index" => 1})
      assert attribute(view, points, "cx") == ["250", "520", "740"]
    end

    test "the algorithm switches between curves and straight segments", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/editable-edge")
      [d] = attribute(view, "path.lf-edge[data-edge-id=input-output]", "d")
      assert d =~ " C "

      view |> form("#editable-form", editable: %{algorithm: "linear"}) |> render_change()

      assert has_element?(
               view,
               "g.editable-edge[data-edge-id=input-output][data-algorithm=linear]"
             )

      [d] = attribute(view, "path.lf-edge[data-edge-id=input-output]", "d")
      refute d =~ " C "
      assert d =~ " L "
    end
  end

  describe "edge routing" do
    test "routes are recomputed while dragging", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/edges/edge-routing")
      assert has_element?(view, "g.routed-edge[data-edge-id=web-billing]")
      assert text(view, "#routed-count") =~ "9"

      selector = "path.lf-edge[data-edge-id=web-billing]"
      [before] = attribute(view, selector, "d")

      render_hook(view, "lf:drag_move", %{
        "changes" => [
          %{
            "type" => "position",
            "id" => "gateway",
            "position" => %{"x" => 300, "y" => 40},
            "dragging" => true
          }
        ]
      })

      [moved] = attribute(view, selector, "d")
      refute moved == before

      view |> form("#routing-form", routing: %{radius: "0"}) |> render_change()
      [square] = attribute(view, selector, "d")
      refute square =~ "Q"
    end

    test "the router avoids every node with orthogonal segments" do
      nodes = [
        Node.new("a", %{x: 0, y: 100}, %{}, width: 120, height: 40),
        Node.new("wall", %{x: 220, y: 0}, %{}, width: 80, height: 260),
        Node.new("b", %{x: 420, y: 110}, %{}, width: 120, height: 40)
      ]

      flow = State.new(nodes: nodes, edges: [Edge.new("a-b", "a", "b", type: :routed)])

      %Edge{data: %{route: route}} =
        flow
        |> EdgeRoutingLive.route_edges(%{margin: 20, radius: 10, bend: 60})
        |> State.get_edge("a-b")

      assert List.first(route) == {120.0, 120.0}
      assert List.last(route) == {420.0, 130.0}

      segments = Enum.chunk_every(route, 2, 1, :discard)
      assert Enum.all?(segments, fn [{ax, ay}, {bx, by}] -> ax == bx or ay == by end)

      # Sample every segment: no point is inside the wall
      for [{ax, ay}, {bx, by}] <- segments, t <- Enum.map(0..20, &(&1 / 20)) do
        x = ax + (bx - ax) * t
        y = ay + (by - ay) * t
        refute x > 220 and x < 300 and y > 0 and y < 260
      end
    end
  end
end

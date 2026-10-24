defmodule FlowExampleWeb.ShowcaseLiveTest do
  use FlowExampleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  defp config(view, selector) do
    view
    |> element(selector)
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.attribute("data-config")
    |> List.first()
    |> Jason.decode!()
  end

  describe "pages" do
    for {path, flow_id} <- [
          {"/", "#hero-flow"},
          {"/playground", "#playground-flow"},
          {"/interaction", "#interaction-flow"},
          {"/edges", "#edges-flow"},
          {"/resizing", "#resizing-flow"},
          {"/custom-nodes", "#custom-flow"},
          {"/large", "#large-flow"}
        ] do
      test "#{path} renders its flow", %{conn: conn} do
        {:ok, view, _html} = live(conn, unquote(path))
        assert has_element?(view, unquote(flow_id) <> "[phx-hook=LiveFlow]")
      end
    end
  end

  describe "interaction" do
    test "options are forwarded to the client config", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/interaction")

      view
      |> form("#interaction-options",
        opts: %{selection_on_drag: "true", pan_activation_key: "Control"}
      )
      |> render_change()

      config = config(view, "#interaction-flow")
      assert config["selectionOnDrag"] == true
      assert config["panActivationKey"] == "Control"
    end

    test "node extent draws the extent area", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/interaction")
      refute has_element?(view, ".lf-node[data-node-id=extent]")

      view |> form("#interaction-options", opts: %{node_extent: "true"}) |> render_change()

      assert has_element?(view, ".lf-node[data-node-id=extent]")
      assert config(view, "#interaction-flow")["nodeExtent"] == [[-60, -80], [1160, 420]]
    end
  end

  describe "flow events" do
    test "a valid connection creates an edge", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/interaction")
      refute has_element?(view, "g[data-source=trigger][data-target=archive]")

      render_hook(view, "lf:connect_end", %{
        "source" => "trigger",
        "target" => "archive",
        "source_handle" => nil,
        "target_handle" => nil
      })

      assert has_element?(view, "g[data-source=trigger][data-target=archive]")
    end

    test "reconnecting moves the edge end", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/edges")

      render_hook(view, "lf:reconnect_edge", %{
        "edge_id" => "hub-east",
        "end" => "target",
        "node_id" => "south",
        "handle_id" => nil
      })

      assert has_element?(view, "g[data-edge-id=hub-east][data-target=south]")
    end

    test "delete and undo", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/playground")

      render_hook(view, "lf:selection_change", %{"nodes" => ["archive"], "edges" => []})
      render_hook(view, "lf:delete_selected", %{})
      refute has_element?(view, ".lf-node[data-node-id=archive]")

      render_hook(view, "lf:undo", %{})
      assert has_element?(view, ".lf-node[data-node-id=archive]")
    end
  end

  describe "custom nodes" do
    test "function component nodes re-render when their data changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/custom-nodes")

      view |> element(".lf-node[data-node-id=counter] button") |> render_click()
      view |> element(".lf-node[data-node-id=counter] button") |> render_click()

      assert view |> element(".lf-node[data-node-id=counter] .font-mono") |> render() =~ "2"
    end
  end

  describe "edges" do
    test "path options are applied to every edge", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/edges")

      view |> form("#edge-options", opts: %{step_position: "0.2"}) |> render_change()

      html = view |> element("g[data-edge-id=hub-east]") |> render()
      assert html =~ "&quot;step_position&quot;:0.2"
    end
  end

  describe "playground" do
    test "adds nodes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/playground")

      before =
        view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query(".lf-node") |> Enum.count()

      view |> element("button", "Add node") |> render_click()

      after_add =
        view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query(".lf-node") |> Enum.count()

      assert after_add == before + 1
    end
  end
end

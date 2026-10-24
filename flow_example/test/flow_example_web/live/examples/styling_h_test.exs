defmodule FlowExampleWeb.Examples.StylingHTest do
  use FlowExampleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Base Style" do
    test "renders default nodes without a theme", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/styling/base-style")

      assert has_element?(view, "#base-style-flow[phx-hook=LiveFlow]")
      refute has_element?(view, "#base-style-flow[data-lf-theme]")
      assert has_element?(view, "#base-style-flow .lf-node[data-node-id='1'] .lf-default-node")
      assert has_element?(view, "#base-style-flow g[data-edge-id=e1-2]")
      refute has_element?(view, "#base-style-canvas[data-custom]")
    end

    test "overrides variables on the wrapper", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/styling/base-style")

      view
      |> form("#base-style-overrides",
        override: %{enabled: "true", accent: "#10b981", radius: "12"}
      )
      |> render_change()

      assert has_element?(view, "#base-style-canvas[data-custom]")
      assert has_element?(view, "#base-style-canvas[style*='--lf-node-border-radius: 12px']")
      assert has_element?(view, "#base-style-canvas[style*='--lf-node-selected-border: #10b981']")
    end
  end

  describe "Dark Mode" do
    test "switches between light, dark and system", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/styling/dark-mode")
      assert has_element?(view, "#dark-mode-flow[phx-hook=LiveFlow][data-lf-theme=light]")

      view |> form("#color-mode-form", color: %{mode: "dark"}) |> render_change()
      assert has_element?(view, "#dark-mode-flow[data-lf-theme=dark]")

      # System leaves the theme unset: the flow follows the site theme
      view |> form("#color-mode-form", color: %{mode: "system"}) |> render_change()
      refute has_element?(view, "#dark-mode-flow[data-lf-theme]")
      assert has_element?(view, "#dark-mode-theme", "nil")
    end

    test "picks one of the extra flow themes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/styling/dark-mode")

      view |> element("#theme-ocean") |> render_click()
      assert has_element?(view, "#dark-mode-flow[data-lf-theme=ocean]")
    end
  end

  describe "Tailwind" do
    test "renders Tailwind-styled nodes, handles and edges", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/styling/tailwind")

      assert has_element?(view, "#tailwind-flow[phx-hook=LiveFlow]")
      assert has_element?(view, "#tailwind-flow .lf-node[data-node-type=custom]", "Jane Doe")

      assert has_element?(
               view,
               "#tailwind-flow .lf-handle[data-handle-position=top][class*='w-16']"
             )

      assert has_element?(view, "#tailwind-flow g[data-edge-id=e1-2][class*='--lf-edge-stroke']")
    end

    test "new edges and people get the same classes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/styling/tailwind")

      render_hook(view, "lf:connect_end", %{
        "source" => "2",
        "target" => "3",
        "source_handle" => nil,
        "target_handle" => nil
      })

      assert has_element?(view, "g[data-source='2'][data-target='3'][class*='--lf-edge-stroke']")

      view |> element("#add-person") |> render_click()
      assert has_element?(view, "#tailwind-flow .lf-node[data-node-id^=person-]", "Omar Haddad")
      assert has_element?(view, "g[data-source='1'][data-target^=person-]")
    end
  end

  describe "Turbo Flow" do
    test "renders turbo nodes and gradient edges on a dark canvas", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/styling/turbo-flow")

      assert has_element?(view, "#turbo-flow[phx-hook=LiveFlow][data-lf-theme=dark]")
      assert has_element?(view, "#turbo-flow .lf-node[data-node-type=turbo] .turbo-wrapper")
      assert has_element?(view, "#turbo-flow g.turbo-edge[data-edge-id=e1-2][data-source='1']")
      assert has_element?(view, "#turbo-flow #turbo-gradient-e1-2")
    end

    test "connections create turbo edges", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/styling/turbo-flow")

      render_hook(view, "lf:connect_end", %{
        "source" => "1",
        "target" => "6",
        "source_handle" => nil,
        "target_handle" => nil
      })

      assert has_element?(view, "#turbo-flow g.turbo-edge[data-source='1'][data-target='6']")
    end
  end

  describe "Download Image" do
    test "export buttons dispatch the export events", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/misc/download-image")

      assert has_element?(view, "#download-image-flow[phx-hook=LiveFlow]")
      assert has_element?(view, "#download-png[phx-click*='lf:export-png']")
      assert has_element?(view, "#download-svg[phx-click*='lf:export-svg']")
      assert has_element?(view, "#download-image-flow [data-lf-export-ignore]")
    end

    test "appearance options and server-triggered export", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/misc/download-image")

      view
      |> form("#image-options", image: %{theme: "dark", background: "lines"})
      |> render_change()

      assert has_element?(view, "#download-image-flow[data-lf-theme=dark]")

      view |> element("#export-from-server") |> render_click()
      assert_push_event(view, "lf:export_png", %{})
    end
  end

  describe "Server Side Image Creation" do
    defp preview_svg(view) do
      "data:image/svg+xml;base64," <> data =
        view
        |> element("#server-svg-preview")
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.attribute("src")
        |> List.first()

      Base.decode64!(data)
    end

    defp node_boxes(svg), do: length(String.split(svg, ~s(rx="8"))) - 1

    test "renders a server-side SVG preview of the flow", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/misc/server-side-image-creation")

      assert has_element?(view, "#server-image-flow[phx-hook=LiveFlow]")
      svg = preview_svg(view)
      assert svg =~ "<svg"
      assert svg =~ "Idea"
      assert node_boxes(svg) == 5
    end

    test "the preview follows flow changes and options", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/misc/server-side-image-creation")

      view |> element("#add-node") |> render_click()
      assert node_boxes(preview_svg(view)) == 6

      render_hook(view, "lf:node_change", %{
        "changes" => [%{"type" => "remove", "id" => "ship"}]
      })

      svg = preview_svg(view)
      assert node_boxes(svg) == 5
      refute svg =~ ">Ship<"

      view |> form("#server-image-options", export: %{theme: "dark"}) |> render_change()
      assert preview_svg(view) =~ ~s(fill="#1a1a1a")
    end

    test "downloads the SVG", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/examples/misc/server-side-image-creation")

      view |> element("#download-server-svg") |> render_click()

      assert_push_event(view, "lf:download_file", %{
        filename: "flow.svg",
        type: "image/svg+xml",
        content: "<svg" <> _
      })
    end
  end
end

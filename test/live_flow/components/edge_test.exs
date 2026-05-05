defmodule LiveFlow.Components.EdgeTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

  alias LiveFlow.{Components, Edge, Handle, Node}

  # Helper: extract the M x,y start coordinate and the final x,y
  # coordinate from the SVG `d` attribute of the rendered edge path.
  # HTML ordering is not guaranteed, so find the path with `class`
  # containing "lf-edge" but NOT "lf-edge-interaction".
  defp path_endpoints(html) do
    d =
      Regex.scan(~r/<path\s+([^>]+)>/, html)
      |> Enum.map(fn [_, attrs] -> attrs end)
      |> Enum.find(fn attrs ->
        String.contains?(attrs, ~s(class="lf-edge")) and
          not String.contains?(attrs, "lf-edge-interaction")
      end)
      |> then(fn attrs ->
        [_, d] = Regex.run(~r/d="([^"]+)"/, attrs)
        d
      end)

    [_, sx, sy] = Regex.run(~r/\AM\s*([\d.eE+-]+)[,\s]+([\d.eE+-]+)/, d)

    coords = Regex.scan(~r/([-]?[\d.]+)[,\s]+([-]?[\d.]+)/, d)
    [last_sx, last_sy] = coords |> List.last() |> Enum.drop(1)

    %{
      start: {parse_float(sx), parse_float(sy)},
      finish: {parse_float(last_sx), parse_float(last_sy)}
    }
  end

  defp parse_float(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error -> raise "can't parse float #{inspect(s)}"
    end
  end

  describe "handle style.left offset (spread source handles on bottom)" do
    test "source handle at style.left=25% starts the edge at 25% of node width" do
      source_handle = %Handle{
        id: "true",
        type: :source,
        position: :bottom,
        style: %{"left" => "25%"}
      }

      target_handle = %Handle{id: "in", type: :target, position: :top, style: %{}}

      source_node = %Node{
        id: "src",
        position: %{x: 0, y: 0},
        width: 200,
        height: 40,
        handles: [source_handle]
      }

      target_node = %Node{
        id: "tgt",
        position: %{x: 0, y: 200},
        width: 200,
        height: 40,
        handles: [target_handle]
      }

      edge = Edge.new("e1", "src", "tgt", source_handle: "true")

      html =
        render_component(&Components.Edge.edge/1,
          edge: edge,
          source_node: source_node,
          target_node: target_node
        )

      %{start: {sx, _sy}} = path_endpoints(html)
      # 25% of 200px width = 50px from node.x (0) → sx should be 50.
      assert_in_delta sx, 50.0, 0.01
    end

    test "source handle at style.left=75% starts the edge at 75% of node width" do
      source_handle = %Handle{
        id: "false",
        type: :source,
        position: :bottom,
        style: %{"left" => "75%"}
      }

      target_handle = %Handle{id: "in", type: :target, position: :top, style: %{}}

      source_node = %Node{
        id: "src",
        position: %{x: 100, y: 0},
        width: 200,
        height: 40,
        handles: [source_handle]
      }

      target_node = %Node{
        id: "tgt",
        position: %{x: 100, y: 200},
        width: 200,
        height: 40,
        handles: [target_handle]
      }

      edge = Edge.new("e1", "src", "tgt", source_handle: "false")

      html =
        render_component(&Components.Edge.edge/1,
          edge: edge,
          source_node: source_node,
          target_node: target_node
        )

      %{start: {sx, _sy}} = path_endpoints(html)
      # 75% of 200 width = 150, plus node.x offset 100 → sx should be 250.
      assert_in_delta sx, 250.0, 0.01
    end

    test "handle without style falls back to centred position on its side" do
      source_handle = %Handle{id: "out", type: :source, position: :bottom, style: %{}}
      target_handle = %Handle{id: "in", type: :target, position: :top, style: %{}}

      source_node = %Node{
        id: "src",
        position: %{x: 0, y: 0},
        width: 200,
        height: 40,
        handles: [source_handle]
      }

      target_node = %Node{
        id: "tgt",
        position: %{x: 0, y: 200},
        width: 200,
        height: 40,
        handles: [target_handle]
      }

      edge = Edge.new("e1", "src", "tgt", source_handle: "out")

      html =
        render_component(&Components.Edge.edge/1,
          edge: edge,
          source_node: source_node,
          target_node: target_node
        )

      %{start: {sx, _sy}} = path_endpoints(html)
      # Centre of 200px-wide node = 100px.
      assert_in_delta sx, 100.0, 0.01
    end

    test "invalid percentage in style.left is ignored" do
      source_handle = %Handle{
        id: "out",
        type: :source,
        position: :bottom,
        style: %{"left" => "garbage"}
      }

      target_handle = %Handle{id: "in", type: :target, position: :top, style: %{}}

      source_node = %Node{
        id: "src",
        position: %{x: 0, y: 0},
        width: 200,
        height: 40,
        handles: [source_handle]
      }

      target_node = %Node{
        id: "tgt",
        position: %{x: 0, y: 200},
        width: 200,
        height: 40,
        handles: [target_handle]
      }

      edge = Edge.new("e1", "src", "tgt", source_handle: "out")

      html =
        render_component(&Components.Edge.edge/1,
          edge: edge,
          source_node: source_node,
          target_node: target_node
        )

      %{start: {sx, _sy}} = path_endpoints(html)
      # Falls back to centre on parse failure.
      assert_in_delta sx, 100.0, 0.01
    end
  end

  describe "handle style.top offset (spread handles on left/right side)" do
    test "source handle on :right with style.top=20% starts edge at 20% of node height" do
      source_handle = %Handle{
        id: "branch-a",
        type: :source,
        position: :right,
        style: %{"top" => "20%"}
      }

      target_handle = %Handle{id: "in", type: :target, position: :left, style: %{}}

      source_node = %Node{
        id: "src",
        position: %{x: 0, y: 0},
        width: 200,
        height: 100,
        handles: [source_handle]
      }

      target_node = %Node{
        id: "tgt",
        position: %{x: 400, y: 0},
        width: 200,
        height: 100,
        handles: [target_handle]
      }

      edge = Edge.new("e1", "src", "tgt", source_handle: "branch-a")

      html =
        render_component(&Components.Edge.edge/1,
          edge: edge,
          source_node: source_node,
          target_node: target_node
        )

      %{start: {_sx, sy}} = path_endpoints(html)
      # 20% of 100px height = 20px from node.y (0).
      assert_in_delta sy, 20.0, 0.01
    end
  end
end

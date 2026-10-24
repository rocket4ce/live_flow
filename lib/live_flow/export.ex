defmodule LiveFlow.Export do
  @moduledoc """
  Server-side SVG rendering of a flow, without a browser.

  Useful to generate thumbnails, previews or downloads from a LiveView or a
  background job. Nodes are drawn as rounded boxes with their label
  (`data.label`, `data.title` or the node id); edges use the same path
  algorithms as the client. Custom node content (function components) is not
  rendered: use the client-side `exportSVG`/`exportPNG` for pixel-perfect
  output.

  ## Examples

      svg = LiveFlow.Export.to_svg(flow, theme: :dark)
      File.write!("flow.svg", svg)
  """

  alias LiveFlow.{Edge, Node, State}
  alias LiveFlow.Paths.Geometry

  @themes %{
    light: %{
      background: "#f8f8f8",
      node_bg: "#ffffff",
      node_border: "#e2e2e2",
      text: "#333333",
      edge: "#b1b1b7",
      selected: "#3b82f6",
      label_bg: "#ffffff"
    },
    dark: %{
      background: "#1a1a1a",
      node_bg: "#2d2d2d",
      node_border: "#404040",
      text: "#e5e5e5",
      edge: "#707070",
      selected: "#60a5fa",
      label_bg: "#2d2d2d"
    }
  }

  @doc """
  Renders the flow as an SVG document.

  ## Options

    * `:padding` - Space around the content (default: `40`)
    * `:theme` - `:light` or `:dark`, or a map overriding the colors
      (`:background`, `:node_bg`, `:node_border`, `:text`, `:edge`,
      `:selected`, `:label_bg`) (default: `:light`)
    * `:background` - Draw the background (default: `true`)
    * `:font_family` - (default: `"system-ui, sans-serif"`)
  """
  @spec to_svg(State.t(), keyword()) :: String.t()
  def to_svg(%State{} = flow, opts \\ []) do
    padding = Keyword.get(opts, :padding, 40)
    colors = colors(Keyword.get(opts, :theme, :light))
    font = Keyword.get(opts, :font_family, "system-ui, sans-serif")

    nodes = State.absolute_nodes(flow)
    visible = nodes |> Map.values() |> Enum.reject(& &1.hidden)

    bounds = State.bounds(flow) || %{x: 0, y: 0, width: 200, height: 100}
    x = bounds.x - padding
    y = bounds.y - padding
    width = bounds.width + padding * 2
    height = bounds.height + padding * 2

    edges =
      flow.edges
      |> Map.values()
      |> Enum.reject(& &1.hidden)
      |> Enum.map(&{&1, Geometry.edge_path(&1, nodes[&1.source], nodes[&1.target])})
      |> Enum.reject(fn {edge, geometry} ->
        is_nil(geometry) or nodes[edge.source].hidden or nodes[edge.target].hidden
      end)

    [
      ~s(<svg xmlns="http://www.w3.org/2000/svg" width="#{num(width)}" height="#{num(height)}" ),
      ~s(viewBox="#{num(x)} #{num(y)} #{num(width)} #{num(height)}" font-family="#{escape(font)}">),
      markers(edges, colors),
      if(Keyword.get(opts, :background, true),
        do:
          ~s(<rect x="#{num(x)}" y="#{num(y)}" width="#{num(width)}" height="#{num(height)}" fill="#{colors.background}"/>),
        else: ""
      ),
      Enum.map(edges, fn {edge, geometry} -> edge_svg(edge, geometry, colors) end),
      visible |> Enum.sort_by(&State.depth(flow, &1)) |> Enum.map(&node_svg(&1, colors)),
      Enum.map(edges, fn {edge, geometry} -> label_svg(edge, geometry, colors) end),
      "</svg>"
    ]
    |> IO.iodata_to_binary()
  end

  defp colors(theme) when is_atom(theme), do: Map.get(@themes, theme, @themes.light)
  defp colors(%{} = overrides), do: Map.merge(@themes.light, overrides)

  # One marker definition per (type, color) used by the edges
  defp markers(edges, colors) do
    defs =
      edges
      |> Enum.flat_map(fn {edge, _} -> [edge.marker_start, edge.marker_end] end)
      |> Enum.filter(&match?(%{}, &1))
      |> Enum.reject(&(Map.get(&1, :type) == :none))
      |> Enum.map(&{marker_type(&1), Map.get(&1, :color) || colors.edge})
      |> Enum.uniq()
      |> Enum.map(fn {type, color} -> marker_def(type, color) end)

    ["<defs>", defs, "</defs>"]
  end

  defp marker_type(%{type: type}) when type in [:arrow_closed, :circle, :circle_filled], do: type
  defp marker_type(_), do: :arrow

  defp marker_id(marker, colors) do
    color = Map.get(marker, :color) || colors.edge

    "lf-export-#{marker_type(marker)}-#{color |> :erlang.md5() |> Base.encode16(case: :lower) |> binary_part(0, 8)}"
  end

  defp marker_def(type, color) do
    id = marker_id(%{type: type, color: color}, %{edge: color})
    color = escape(color)

    shape =
      case type do
        :arrow ->
          ~s(<polyline points="2,2 10,6 2,10" fill="none" stroke="#{color}" stroke-width="1.5"/>)

        :arrow_closed ->
          ~s(<path d="M2,2 L10,6 L2,10 Z" fill="#{color}"/>)

        :circle ->
          ~s(<circle cx="6" cy="6" r="4" fill="none" stroke="#{color}" stroke-width="1.5"/>)

        :circle_filled ->
          ~s(<circle cx="6" cy="6" r="4" fill="#{color}"/>)
      end

    ~s(<marker id="#{id}" markerWidth="12" markerHeight="12" refX="10" refY="6" orient="auto-start-reverse">#{shape}</marker>)
  end

  defp edge_svg(%Edge{} = edge, geometry, colors) do
    style = edge.style || %{}
    stroke = Map.get(style, :stroke) || Map.get(style, "stroke") || colors.edge
    stroke = if edge.selected, do: colors.selected, else: stroke
    width = Map.get(style, :"stroke-width") || Map.get(style, "stroke-width") || 1.5

    marker = fn attr, marker ->
      case marker do
        %{type: :none} -> ""
        %{} = m -> ~s| #{attr}="url(##{marker_id(m, colors)})"|
        _ -> ""
      end
    end

    dash = if edge.animated, do: ~s( stroke-dasharray="5"), else: ""

    ~s(<path d="#{geometry.path}" fill="none" stroke="#{escape(stroke)}" stroke-width="#{escape(width)}") <>
      dash <>
      marker.("marker-start", edge.marker_start) <> marker.("marker-end", edge.marker_end) <> "/>"
  end

  defp label_svg(%Edge{label: nil}, _geometry, _colors), do: ""

  defp label_svg(%Edge{label: label}, geometry, colors) do
    text = to_string(label)
    w = String.length(text) * 7 + 16

    ~s(<g><rect x="#{num(geometry.label_x - w / 2)}" y="#{num(geometry.label_y - 11)}" width="#{w}" height="22" rx="4" ) <>
      ~s(fill="#{colors.label_bg}" stroke="#{colors.node_border}"/>) <>
      ~s(<text x="#{num(geometry.label_x)}" y="#{num(geometry.label_y)}" text-anchor="middle" dominant-baseline="central" ) <>
      ~s(font-size="12" font-weight="600" fill="#{colors.text}">#{escape(text)}</text></g>)
  end

  defp node_svg(%Node{} = node, colors) do
    w = node.width || 100
    h = node.height || 40
    %{x: x, y: y} = node.position
    border = if node.selected, do: colors.selected, else: colors.node_border
    fill = Map.get(node.style, :background) || Map.get(node.style, "background") || colors.node_bg

    ~s(<g><rect x="#{num(x)}" y="#{num(y)}" width="#{num(w)}" height="#{num(h)}" rx="8" fill="#{escape(fill)}" ) <>
      ~s(stroke="#{border}" stroke-width="1"/>) <>
      ~s(<text x="#{num(x + w / 2)}" y="#{num(y + h / 2)}" text-anchor="middle" dominant-baseline="central" ) <>
      ~s(font-size="14" font-weight="500" fill="#{colors.text}">#{escape(label(node))}</text></g>)
  end

  defp label(%Node{data: data, id: id}) do
    data = data || %{}
    to_string(data[:label] || data["label"] || data[:title] || data["title"] || id)
  end

  defp num(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 2)
  defp num(n), do: to_string(n)

  defp escape(text) do
    text
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end

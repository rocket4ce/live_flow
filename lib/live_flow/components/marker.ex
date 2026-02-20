defmodule LiveFlow.Components.Marker do
  @moduledoc """
  Dynamic SVG marker definitions for LiveFlow edges.

  Generates unique `<marker>` elements based on edge marker configurations,
  supporting custom colors, sizes, and shapes (arrow, circle, diamond).
  """

  use Phoenix.Component

  @default_size 12
  @default_stroke_width 1

  @doc """
  Collects all unique marker configurations from a list of edges.
  Returns a list of `{marker_id, marker_config}` tuples.
  """
  def collect_markers(edges) do
    edges
    |> Enum.flat_map(fn edge ->
      [edge.marker_start, edge.marker_end]
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&(&1[:type] == :none))
    end)
    |> Enum.uniq_by(&marker_id/1)
    |> Enum.map(fn marker -> {marker_id(marker), marker} end)
  end

  @doc """
  Generates a deterministic marker ID from a marker configuration.
  Identical configs produce the same ID so they share one SVG `<marker>` def.
  """
  def marker_id(nil), do: nil
  def marker_id(%{type: :none}), do: nil

  def marker_id(%{} = marker) do
    type = Map.get(marker, :type, :arrow)
    color = Map.get(marker, :color)
    width = Map.get(marker, :width)
    height = Map.get(marker, :height)
    stroke_width = Map.get(marker, :stroke_width)

    parts = ["lf", to_string(type)]

    parts =
      if color, do: parts ++ [String.replace(color, "#", "")], else: parts

    parts =
      if width, do: parts ++ [to_string(width)], else: parts

    parts =
      if height, do: parts ++ [to_string(height)], else: parts

    parts =
      if stroke_width, do: parts ++ ["sw#{stroke_width}"], else: parts

    Enum.join(parts, "-")
  end

  @doc """
  Returns the SVG `url(#id)` reference for a marker, or nil.
  """
  def marker_url(nil), do: nil
  def marker_url(%{type: :none}), do: nil
  def marker_url(%{} = marker), do: "url(##{marker_id(marker)})"

  @doc """
  Renders all collected marker definitions inside an SVG `<defs>` block.
  """
  attr :markers, :list, required: true

  def marker_defs(assigns) do
    ~H"""
    <defs>
      <.marker_def :for={{id, marker} <- @markers} id={id} marker={marker} />
    </defs>
    """
  end

  # --- Private: individual marker definition ---

  attr :id, :string, required: true
  attr :marker, :map, required: true

  defp marker_def(assigns) do
    marker = assigns.marker
    color = Map.get(marker, :color) || "currentColor"
    width = Map.get(marker, :width) || @default_size
    height = Map.get(marker, :height) || @default_size
    stroke_w = Map.get(marker, :stroke_width) || @default_stroke_width
    type = Map.get(marker, :type, :arrow)

    assigns =
      assigns
      |> assign(:type, type)
      |> assign(:color, color)
      |> assign(:w, width)
      |> assign(:h, height)
      |> assign(:stroke_w, stroke_w)
      |> assign(:ref_x, ref_x(type, width))
      |> assign(:ref_y, height / 2)

    ~H"""
    <marker
      id={@id}
      markerWidth={@w}
      markerHeight={@h}
      refX={@ref_x}
      refY={@ref_y}
      orient="auto"
    >
      <.marker_shape type={@type} color={@color} w={@w} h={@h} stroke_w={@stroke_w} />
    </marker>
    """
  end

  # --- Shape renderers ---

  attr :type, :atom, required: true
  attr :color, :string, required: true
  attr :w, :float, required: true
  attr :h, :float, required: true
  attr :stroke_w, :float, required: true

  defp marker_shape(%{type: :arrow} = assigns) do
    ~H"""
    <polyline
      points={arrow_points(@w, @h)}
      fill="none"
      stroke={@color}
      stroke-width={@stroke_w}
    />
    """
  end

  defp marker_shape(%{type: :arrow_closed} = assigns) do
    ~H"""
    <path
      d={arrow_closed_path(@w, @h)}
      fill={@color}
      stroke={@color}
      stroke-width={@stroke_w}
    />
    """
  end

  defp marker_shape(%{type: :circle} = assigns) do
    r = min(assigns.w, assigns.h) / 2 - assigns.stroke_w
    assigns = assign(assigns, :r, r)

    ~H"""
    <circle cx={@w / 2} cy={@h / 2} r={@r} fill="none" stroke={@color} stroke-width={@stroke_w} />
    """
  end

  defp marker_shape(%{type: :circle_filled} = assigns) do
    r = min(assigns.w, assigns.h) / 2 - assigns.stroke_w
    assigns = assign(assigns, :r, r)

    ~H"""
    <circle cx={@w / 2} cy={@h / 2} r={@r} fill={@color} stroke={@color} stroke-width={@stroke_w} />
    """
  end

  defp marker_shape(%{type: :diamond} = assigns) do
    ~H"""
    <polygon points={diamond_points(@w, @h)} fill="none" stroke={@color} stroke-width={@stroke_w} />
    """
  end

  defp marker_shape(%{type: :diamond_filled} = assigns) do
    ~H"""
    <polygon points={diamond_points(@w, @h)} fill={@color} stroke={@color} stroke-width={@stroke_w} />
    """
  end

  # Fallback: unknown type renders as arrow_closed
  defp marker_shape(assigns) do
    ~H"""
    <path
      d={arrow_closed_path(@w, @h)}
      fill={@color}
      stroke={@color}
      stroke-width={@stroke_w}
    />
    """
  end

  # --- Geometry helpers ---

  defp arrow_points(w, h) do
    x1 = w * 0.15
    y1 = h * 0.15
    x2 = w * 0.85
    y2 = h * 0.5
    y3 = h * 0.85
    "#{fmt(x1)},#{fmt(y1)} #{fmt(x2)},#{fmt(y2)} #{fmt(x1)},#{fmt(y3)}"
  end

  defp arrow_closed_path(w, h) do
    x1 = w * 0.15
    y1 = h * 0.15
    x2 = w * 0.85
    y2 = h * 0.5
    y3 = h * 0.85
    "M#{fmt(x1)},#{fmt(y1)} L#{fmt(x2)},#{fmt(y2)} L#{fmt(x1)},#{fmt(y3)} Z"
  end

  defp diamond_points(w, h) do
    cx = w / 2
    cy = h / 2
    "#{fmt(cx)},0 #{fmt(w)},#{fmt(cy)} #{fmt(cx)},#{fmt(h)} 0,#{fmt(cy)}"
  end

  defp ref_x(:circle, w), do: w / 2
  defp ref_x(:circle_filled, w), do: w / 2
  defp ref_x(:diamond, w), do: w
  defp ref_x(:diamond_filled, w), do: w
  defp ref_x(_type, w), do: w * 0.85

  defp fmt(num) when is_float(num), do: :erlang.float_to_binary(num, decimals: 1)
  defp fmt(num), do: to_string(num)
end

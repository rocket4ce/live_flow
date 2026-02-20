defmodule LiveFlow.Paths.Bezier do
  @moduledoc """
  Bezier curve path calculation for edges.

  Creates smooth curved paths using cubic Bezier curves. The curvature
  is determined by the distance between points and the handle positions.
  """

  @behaviour LiveFlow.Paths.Path

  @default_curvature 0.25

  @impl true
  def calculate(source, target, opts \\ []) do
    curvature = Keyword.get(opts, :curvature, @default_curvature)

    sx = source.x
    sy = source.y
    tx = target.x
    ty = target.y
    source_pos = source.position
    target_pos = target.position

    # Calculate control point offsets
    {c1x, c1y} = control_point(sx, sy, source_pos, curvature, sx, sy, tx, ty)
    {c2x, c2y} = control_point(tx, ty, target_pos, curvature, tx, ty, sx, sy)

    # Generate SVG path
    path =
      "M #{format(sx)},#{format(sy)} C #{format(c1x)},#{format(c1y)} #{format(c2x)},#{format(c2y)} #{format(tx)},#{format(ty)}"

    # Calculate label position at t=0.5
    {label_x, label_y} = bezier_point(0.5, sx, sy, c1x, c1y, c2x, c2y, tx, ty)

    %{
      path: path,
      label_x: label_x,
      label_y: label_y
    }
  end

  @doc """
  Calculates the path between two points with explicit positions.
  """
  @spec path(number(), number(), atom(), number(), number(), atom(), keyword()) :: map()
  def path(source_x, source_y, source_position, target_x, target_y, target_position, opts \\ []) do
    calculate(
      %{x: source_x, y: source_y, position: source_position},
      %{x: target_x, y: target_y, position: target_position},
      opts
    )
  end

  # Calculate control point based on handle position
  defp control_point(x, y, position, curvature, _sx, _sy, tx, ty) do
    dx = abs(tx - x)
    dy = abs(ty - y)
    offset = max(dx, dy) * curvature
    min_offset = 50

    actual_offset = max(offset, min_offset)

    case position do
      :left -> {x - actual_offset, y}
      :right -> {x + actual_offset, y}
      :top -> {x, y - actual_offset}
      :bottom -> {x, y + actual_offset}
    end
  end

  # Calculate point on cubic Bezier curve at parameter t
  defp bezier_point(t, x0, y0, x1, y1, x2, y2, x3, y3) do
    mt = 1 - t
    mt2 = mt * mt
    mt3 = mt2 * mt
    t2 = t * t
    t3 = t2 * t

    x = mt3 * x0 + 3 * mt2 * t * x1 + 3 * mt * t2 * x2 + t3 * x3
    y = mt3 * y0 + 3 * mt2 * t * y1 + 3 * mt * t2 * y2 + t3 * y3

    {x, y}
  end

  defp format(num) when is_float(num), do: :erlang.float_to_binary(num, decimals: 2)
  defp format(num), do: to_string(num)
end

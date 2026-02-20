defmodule LiveFlow.Paths.Smoothstep do
  @moduledoc """
  Smoothstep path calculation for edges.

  Creates orthogonal paths with rounded corners, similar to step paths
  but with smooth curved transitions at corners.
  """

  @behaviour LiveFlow.Paths.Path

  @default_offset 20
  @default_border_radius 5

  @impl true
  def calculate(source, target, opts \\ []) do
    offset = Keyword.get(opts, :offset, @default_offset)
    border_radius = Keyword.get(opts, :border_radius, @default_border_radius)

    sx = source.x
    sy = source.y
    tx = target.x
    ty = target.y
    source_pos = source.position
    target_pos = target.position

    points = calculate_points(sx, sy, tx, ty, source_pos, target_pos, offset)

    path = build_smooth_path(points, border_radius)

    # Label at middle segment
    mid_idx = div(length(points), 2)
    {label_x, label_y} = Enum.at(points, mid_idx)

    %{
      path: path,
      label_x: label_x,
      label_y: label_y
    }
  end

  @doc """
  Calculates a smoothstep path between two points with explicit positions.
  """
  @spec path(number(), number(), atom(), number(), number(), atom(), keyword()) :: map()
  def path(source_x, source_y, source_position, target_x, target_y, target_position, opts \\ []) do
    calculate(
      %{x: source_x, y: source_y, position: source_position},
      %{x: target_x, y: target_y, position: target_position},
      opts
    )
  end

  # Same point calculation as Step
  defp calculate_points(sx, sy, tx, ty, source_pos, target_pos, offset) do
    case {source_pos, target_pos} do
      {:right, :left} when tx > sx + offset * 2 ->
        mid_x = (sx + tx) / 2
        [{sx, sy}, {mid_x, sy}, {mid_x, ty}, {tx, ty}]

      {:right, :left} ->
        mid_y = (sy + ty) / 2

        [
          {sx, sy},
          {sx + offset, sy},
          {sx + offset, mid_y},
          {tx - offset, mid_y},
          {tx - offset, ty},
          {tx, ty}
        ]

      {:left, :right} when sx > tx + offset * 2 ->
        mid_x = (sx + tx) / 2
        [{sx, sy}, {mid_x, sy}, {mid_x, ty}, {tx, ty}]

      {:left, :right} ->
        mid_y = (sy + ty) / 2

        [
          {sx, sy},
          {sx - offset, sy},
          {sx - offset, mid_y},
          {tx + offset, mid_y},
          {tx + offset, ty},
          {tx, ty}
        ]

      {:bottom, :top} when ty > sy + offset * 2 ->
        mid_y = (sy + ty) / 2
        [{sx, sy}, {sx, mid_y}, {tx, mid_y}, {tx, ty}]

      {:bottom, :top} ->
        mid_x = (sx + tx) / 2

        [
          {sx, sy},
          {sx, sy + offset},
          {mid_x, sy + offset},
          {mid_x, ty - offset},
          {tx, ty - offset},
          {tx, ty}
        ]

      {:top, :bottom} when sy > ty + offset * 2 ->
        mid_y = (sy + ty) / 2
        [{sx, sy}, {sx, mid_y}, {tx, mid_y}, {tx, ty}]

      {:top, :bottom} ->
        mid_x = (sx + tx) / 2

        [
          {sx, sy},
          {sx, sy - offset},
          {mid_x, sy - offset},
          {mid_x, ty + offset},
          {tx, ty + offset},
          {tx, ty}
        ]

      {:right, :right} ->
        max_x = max(sx, tx) + offset
        [{sx, sy}, {max_x, sy}, {max_x, ty}, {tx, ty}]

      {:left, :left} ->
        min_x = min(sx, tx) - offset
        [{sx, sy}, {min_x, sy}, {min_x, ty}, {tx, ty}]

      {:top, :top} ->
        min_y = min(sy, ty) - offset
        [{sx, sy}, {sx, min_y}, {tx, min_y}, {tx, ty}]

      {:bottom, :bottom} ->
        max_y = max(sy, ty) + offset
        [{sx, sy}, {sx, max_y}, {tx, max_y}, {tx, ty}]

      {:right, :top} ->
        [{sx, sy}, {tx, sy}, {tx, ty}]

      {:right, :bottom} ->
        [{sx, sy}, {tx, sy}, {tx, ty}]

      {:left, :top} ->
        [{sx, sy}, {tx, sy}, {tx, ty}]

      {:left, :bottom} ->
        [{sx, sy}, {tx, sy}, {tx, ty}]

      {:top, :right} ->
        [{sx, sy}, {sx, ty}, {tx, ty}]

      {:top, :left} ->
        [{sx, sy}, {sx, ty}, {tx, ty}]

      {:bottom, :right} ->
        [{sx, sy}, {sx, ty}, {tx, ty}]

      {:bottom, :left} ->
        [{sx, sy}, {sx, ty}, {tx, ty}]

      _ ->
        [{sx, sy}, {tx, ty}]
    end
  end

  defp build_smooth_path(points, _radius) when length(points) < 3 do
    [{x1, y1}, {x2, y2}] = points
    "M #{format(x1)},#{format(y1)} L #{format(x2)},#{format(y2)}"
  end

  defp build_smooth_path(points, radius) do
    [{x0, y0} | rest] = points

    initial_path = "M #{format(x0)},#{format(y0)}"

    # Track both path segments and the last coordinate we processed
    {path_segments, _last_point} =
      rest
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce({[initial_path], {x0, y0}}, fn [{cx, cy}, {nx, ny}], {segments, {px, py}} ->
        {corner_path, endpoint} = rounded_corner_with_endpoint(px, py, cx, cy, nx, ny, radius)
        {segments ++ [corner_path], endpoint}
      end)

    # Add final line to last point
    {lx, ly} = List.last(rest)
    path_segments = path_segments ++ ["L #{format(lx)},#{format(ly)}"]

    Enum.join(path_segments, " ")
  end

  defp rounded_corner_with_endpoint(px, py, cx, cy, nx, ny, radius) do
    # Vector from corner to previous point
    v1x = px - cx
    v1y = py - cy
    len1 = :math.sqrt(v1x * v1x + v1y * v1y)

    # Vector from corner to next point
    v2x = nx - cx
    v2y = ny - cy
    len2 = :math.sqrt(v2x * v2x + v2y * v2y)

    # Limit radius by available length
    actual_radius = min(radius, min(len1, len2) / 2)

    if actual_radius < 1 do
      # Too small for curve, just line to corner
      {"L #{format(cx)},#{format(cy)}", {cx, cy}}
    else
      # Normalize vectors
      n1x = v1x / len1
      n1y = v1y / len1
      n2x = v2x / len2
      n2y = v2y / len2

      # Start and end points of the curve
      start_x = cx + n1x * actual_radius
      start_y = cy + n1y * actual_radius
      end_x = cx + n2x * actual_radius
      end_y = cy + n2y * actual_radius

      # Use quadratic bezier for smooth corner
      path =
        "L #{format(start_x)},#{format(start_y)} Q #{format(cx)},#{format(cy)} #{format(end_x)},#{format(end_y)}"

      {path, {end_x, end_y}}
    end
  end

  defp format(num) when is_float(num), do: :erlang.float_to_binary(num, decimals: 2)
  defp format(num), do: to_string(num)
end

defmodule LiveFlow.Paths.Step do
  @moduledoc """
  Step/orthogonal path calculation for edges.

  Creates paths with 90-degree angles, routing horizontally and vertically
  between source and target points.
  """

  @behaviour LiveFlow.Paths.Path

  @default_offset 20

  @impl true
  def calculate(source, target, opts \\ []) do
    offset = Keyword.get(opts, :offset, @default_offset)

    sx = source.x
    sy = source.y
    tx = target.x
    ty = target.y
    source_pos = source.position
    target_pos = target.position

    points = calculate_points(sx, sy, tx, ty, source_pos, target_pos, offset)

    path = build_step_path(points)

    # Label at middle point
    mid_idx = div(length(points), 2)
    {label_x, label_y} = Enum.at(points, mid_idx)

    %{
      path: path,
      label_x: label_x,
      label_y: label_y
    }
  end

  @doc """
  Calculates a step path between two points with explicit positions.
  """
  @spec path(number(), number(), atom(), number(), number(), atom(), keyword()) :: map()
  def path(source_x, source_y, source_position, target_x, target_y, target_position, opts \\ []) do
    calculate(
      %{x: source_x, y: source_y, position: source_position},
      %{x: target_x, y: target_y, position: target_position},
      opts
    )
  end

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

      # Same side connections
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

      # Cross directions
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

      # Fallback
      _ ->
        [{sx, sy}, {tx, ty}]
    end
  end

  defp build_step_path(points) do
    [{x0, y0} | rest] = points

    start = "M #{format(x0)},#{format(y0)}"

    lines =
      rest
      |> Enum.map(fn {x, y} -> "L #{format(x)},#{format(y)}" end)
      |> Enum.join(" ")

    "#{start} #{lines}"
  end

  defp format(num) when is_float(num), do: :erlang.float_to_binary(num, decimals: 2)
  defp format(num), do: to_string(num)
end

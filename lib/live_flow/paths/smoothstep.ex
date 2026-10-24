defmodule LiveFlow.Paths.Smoothstep do
  @moduledoc """
  Smoothstep path calculation for edges.

  Creates orthogonal paths with rounded corners. This is a port of
  `getSmoothStepPath` from xyflow, including the `step_position` option
  and the collinear-point cleanup that keeps every bend rounded.

  The JavaScript client mirrors this algorithm in `assets/js/live_flow/utils/paths.js`
  so edges keep their shape while nodes are dragged or resized.

  ## Options

    * `:border_radius` - Corner radius (default: `5`)
    * `:offset` - Distance the path travels out of a handle before turning (default: `20`)
    * `:step_position` - Where the bend happens between source (`0.0`) and
      target (`1.0`) (default: `0.5`)
    * `:center_x` / `:center_y` - Force the bend through a specific coordinate
  """

  @behaviour LiveFlow.Paths.Path

  @default_offset 20
  @default_border_radius 5
  @default_step_position 0.5

  @impl true
  def calculate(source, target, opts \\ []) do
    offset = Keyword.get(opts, :offset, @default_offset)
    border_radius = Keyword.get(opts, :border_radius, @default_border_radius)
    step_position = Keyword.get(opts, :step_position, @default_step_position)
    center = {Keyword.get(opts, :center_x), Keyword.get(opts, :center_y)}

    {points, label_x, label_y} =
      points(
        {source.x, source.y},
        source.position || :bottom,
        {target.x, target.y},
        target.position || :top,
        center,
        offset,
        step_position
      )

    %{
      path: build_path(points, border_radius),
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

  @doc false
  # Returns `{path_points, label_x, label_y}`. Shared with `LiveFlow.Paths.Step`.
  def points(source, source_pos, target, target_pos, {center_x, center_y}, offset, step_position) do
    source_dir = direction(source_pos)
    target_dir = direction(target_pos)
    source_gapped = add(source, scale(source_dir, offset))
    target_gapped = add(target, scale(target_dir, offset))

    dir = main_direction(source_gapped, source_pos, target_gapped)
    axis = if elem(dir, 0) != 0, do: 0, else: 1
    curr_dir = elem(dir, axis)

    {mid_points, label_x, label_y, source_gap_offset, target_gap_offset} =
      if elem(source_dir, axis) * elem(target_dir, axis) == -1 do
        # Opposite handle positions (default case)
        {sgx, sgy} = source_gapped
        {tgx, tgy} = target_gapped

        {cx, cy} =
          if axis == 0 do
            {center_x || sgx + (tgx - sgx) * step_position, center_y || (sgy + tgy) / 2}
          else
            {center_x || (sgx + tgx) / 2, center_y || sgy + (tgy - sgy) * step_position}
          end

        vertical_split = [{cx, sgy}, {cx, tgy}]
        horizontal_split = [{sgx, cy}, {tgx, cy}]

        mid =
          case {elem(source_dir, axis) == curr_dir, axis} do
            {true, 0} -> vertical_split
            {true, 1} -> horizontal_split
            {false, 0} -> horizontal_split
            {false, 1} -> vertical_split
          end

        {mid, cx, cy, {0, 0}, {0, 0}}
      else
        same_or_mixed_points(
          source,
          source_pos,
          source_dir,
          source_gapped,
          target,
          target_pos,
          target_dir,
          target_gapped,
          axis,
          curr_dir,
          offset
        )
      end

    gapped_source = add(source_gapped, source_gap_offset)
    gapped_target = add(target_gapped, target_gap_offset)

    path_points =
      ([source, gapped_source] ++ mid_points ++ [gapped_target, target])
      |> Enum.reduce([], fn
        point, [b, a | rest] = acc ->
          # Drop b if the path runs straight through it, otherwise it would
          # shrink the bend of the next corner
          if between?(a, b, point), do: [point, a | rest], else: [point | acc]

        point, acc ->
          [point | acc]
      end)
      |> Enum.reverse()

    {path_points, label_x, label_y}
  end

  defp same_or_mixed_points(
         source,
         source_pos,
         source_dir,
         source_gapped,
         target,
         target_pos,
         target_dir,
         target_gapped,
         axis,
         curr_dir,
         offset
       ) do
    {sgx, sgy} = source_gapped
    {tgx, tgy} = target_gapped

    # source_target takes x from source and y from target, target_source the opposite
    source_target = [{sgx, tgy}]
    target_source = [{tgx, sgy}]

    points =
      if axis == 0 do
        if elem(source_dir, 0) == curr_dir, do: target_source, else: source_target
      else
        if elem(source_dir, 1) == curr_dir, do: source_target, else: target_source
      end

    # Same handle positions (e.g. right -> right) closer than the offset would
    # overlap the gapped points, so push one of them back
    {source_gap_offset, target_gap_offset} =
      if source_pos == target_pos do
        diff = abs(elem(source, axis) - elem(target, axis))

        if diff <= offset do
          gap_offset = min(offset - 1, offset - diff)

          if elem(source_dir, axis) == curr_dir do
            sign = if elem(source_gapped, axis) > elem(source, axis), do: -1, else: 1
            {put_elem({0, 0}, axis, sign * gap_offset), {0, 0}}
          else
            sign = if elem(target_gapped, axis) > elem(target, axis), do: -1, else: 1
            {{0, 0}, put_elem({0, 0}, axis, sign * gap_offset)}
          end
        else
          {{0, 0}, {0, 0}}
        end
      else
        {{0, 0}, {0, 0}}
      end

    # Mixed handle positions like right -> bottom
    points =
      if source_pos != target_pos do
        opp = 1 - axis
        same_dir? = elem(source_dir, axis) == elem(target_dir, opp)
        source_gt? = elem(source_gapped, opp) > elem(target_gapped, opp)
        source_lt? = elem(source_gapped, opp) < elem(target_gapped, opp)

        flip? =
          (elem(source_dir, axis) == 1 and
             ((not same_dir? and source_gt?) or (same_dir? and source_lt?))) or
            (elem(source_dir, axis) != 1 and
               ((not same_dir? and source_lt?) or (same_dir? and source_gt?)))

        if flip?, do: if(axis == 0, do: source_target, else: target_source), else: points
      else
        points
      end

    {sgpx, sgpy} = add(source_gapped, source_gap_offset)
    {tgpx, tgpy} = add(target_gapped, target_gap_offset)
    [{p0x, p0y}] = points
    max_x_distance = max(abs(sgpx - p0x), abs(tgpx - p0x))
    max_y_distance = max(abs(sgpy - p0y), abs(tgpy - p0y))

    # Place the label on the longest segment of the edge
    {label_x, label_y} =
      if max_x_distance >= max_y_distance do
        {(sgpx + tgpx) / 2, p0y}
      else
        {p0x, (sgpy + tgpy) / 2}
      end

    {points, label_x, label_y, source_gap_offset, target_gap_offset}
  end

  @doc false
  def build_path(points, border_radius) do
    [{x0, y0} | _] = points
    {lx, ly} = List.last(points)

    bends =
      points
      |> Enum.chunk_every(3, 1, :discard)
      |> Enum.map(fn [a, b, c] -> bend(a, b, c, border_radius) end)

    IO.iodata_to_binary(["M#{format(x0)} #{format(y0)}", bends, "L#{format(lx)} #{format(ly)}"])
  end

  defp bend({ax, ay} = a, {x, y} = b, {cx, cy} = c, size) do
    bend_size = min(min(distance(a, b) / 2, distance(b, c) / 2), size)

    cond do
      bend_size <= 0 or (ax == x and x == cx) or (ay == y and y == cy) ->
        "L#{format(x)} #{format(y)}"

      # First segment is horizontal
      ay == y ->
        x_dir = if ax < cx, do: -1, else: 1
        y_dir = if ay < cy, do: 1, else: -1

        "L #{format(x + bend_size * x_dir)},#{format(y)}Q #{format(x)},#{format(y)} #{format(x)},#{format(y + bend_size * y_dir)}"

      true ->
        x_dir = if ax < cx, do: 1, else: -1
        y_dir = if ay < cy, do: -1, else: 1

        "L #{format(x)},#{format(y + bend_size * y_dir)}Q #{format(x)},#{format(y)} #{format(x + bend_size * x_dir)},#{format(y)}"
    end
  end

  # Checks if b lies on the straight segment from a to c, including b == c
  defp between?({ax, ay}, {bx, by}, {cx, cy}) do
    (ax == bx and bx == cx and (by - ay) * (cy - by) >= 0) or
      (ay == by and by == cy and (bx - ax) * (cx - bx) >= 0)
  end

  defp main_direction({sx, _sy}, source_pos, {tx, _ty}) when source_pos in [:left, :right] do
    if sx < tx, do: {1, 0}, else: {-1, 0}
  end

  defp main_direction({_sx, sy}, _source_pos, {_tx, ty}) do
    if sy < ty, do: {0, 1}, else: {0, -1}
  end

  defp direction(:left), do: {-1, 0}
  defp direction(:right), do: {1, 0}
  defp direction(:top), do: {0, -1}
  defp direction(:bottom), do: {0, 1}

  defp add({ax, ay}, {bx, by}), do: {ax + bx, ay + by}
  defp scale({x, y}, factor), do: {x * factor, y * factor}

  defp distance({ax, ay}, {bx, by}), do: :math.sqrt((bx - ax) ** 2 + (by - ay) ** 2)

  defp format(num) when is_float(num) do
    if num == Float.round(num), do: Integer.to_string(trunc(num)), else: float_to_string(num)
  end

  defp format(num), do: to_string(num)

  defp float_to_string(num) do
    num
    |> :erlang.float_to_binary(decimals: 2)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end
end

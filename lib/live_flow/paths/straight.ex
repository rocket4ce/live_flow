defmodule LiveFlow.Paths.Straight do
  @moduledoc """
  Straight line path calculation for edges.

  Creates simple direct lines between source and target points.
  """

  @behaviour LiveFlow.Paths.Path

  @impl true
  def calculate(source, target, _opts \\ []) do
    sx = source.x
    sy = source.y
    tx = target.x
    ty = target.y

    # Simple line path
    path = "M #{format(sx)},#{format(sy)} L #{format(tx)},#{format(ty)}"

    # Label at midpoint
    label_x = (sx + tx) / 2
    label_y = (sy + ty) / 2

    %{
      path: path,
      label_x: label_x,
      label_y: label_y
    }
  end

  @doc """
  Calculates a straight path between two points.
  """
  @spec path(number(), number(), number(), number()) :: map()
  def path(source_x, source_y, target_x, target_y) do
    calculate(
      %{x: source_x, y: source_y, position: :right},
      %{x: target_x, y: target_y, position: :left},
      []
    )
  end

  defp format(num) when is_float(num), do: :erlang.float_to_binary(num, decimals: 2)
  defp format(num), do: to_string(num)
end

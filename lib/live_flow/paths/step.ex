defmodule LiveFlow.Paths.Step do
  @moduledoc """
  Step/orthogonal path calculation for edges.

  Creates paths with 90-degree angles. It shares the routing algorithm with
  `LiveFlow.Paths.Smoothstep` (a port of xyflow's `getSmoothStepPath`) using
  a border radius of `0`, exactly like xyflow's step edge.

  ## Options

    * `:offset` - Distance the path travels out of a handle before turning (default: `20`)
    * `:step_position` - Where the bend happens between source (`0.0`) and
      target (`1.0`) (default: `0.5`)
    * `:center_x` / `:center_y` - Force the bend through a specific coordinate
  """

  @behaviour LiveFlow.Paths.Path

  alias LiveFlow.Paths.Smoothstep

  @impl true
  def calculate(source, target, opts \\ []) do
    Smoothstep.calculate(source, target, Keyword.put(opts, :border_radius, 0))
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
end

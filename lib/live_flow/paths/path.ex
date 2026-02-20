defmodule LiveFlow.Paths.Path do
  @moduledoc """
  Behaviour for edge path calculations.

  Path modules calculate SVG path strings for rendering edges between nodes.
  Each path type (bezier, straight, step, smoothstep) implements this behaviour.

  ## Path Result

  The `calculate/2` function returns a map with:
    * `:path` - SVG path string (e.g., "M0,0 C50,0 50,100 100,100")
    * `:label_x` - X coordinate for edge label
    * `:label_y` - Y coordinate for edge label

  ## Implementing a Custom Path

      defmodule MyApp.CustomPath do
        @behaviour LiveFlow.Paths.Path

        @impl true
        def calculate(source, target, opts) do
          # Custom path calculation
          %{
            path: "M ...",
            label_x: ...,
            label_y: ...
          }
        end
      end
  """

  @typedoc """
  Source/target point with position information.

  * `:x` - X coordinate
  * `:y` - Y coordinate
  * `:position` - Handle position (:top, :bottom, :left, :right)
  """
  @type point :: %{
          x: number(),
          y: number(),
          position: :top | :bottom | :left | :right
        }

  @typedoc """
  Path calculation result.
  """
  @type result :: %{
          path: String.t(),
          label_x: number(),
          label_y: number()
        }

  @doc """
  Calculates the SVG path between source and target points.

  ## Options

  Options are path-type specific. Common options include:
    * `:curvature` - Curve intensity (0.0 to 1.0)
    * `:offset` - Distance from node before turning
    * `:border_radius` - Corner rounding for step paths
  """
  @callback calculate(source :: point(), target :: point(), opts :: keyword()) :: result()

  @doc """
  Calculates a path using the specified path module.
  """
  @spec calculate(module(), point(), point(), keyword()) :: result()
  def calculate(module, source, target, opts \\ []) do
    module.calculate(source, target, opts)
  end

  @doc """
  Gets the path module for an edge type.
  """
  @spec module_for_type(atom()) :: module()
  def module_for_type(:bezier), do: LiveFlow.Paths.Bezier
  def module_for_type(:straight), do: LiveFlow.Paths.Straight
  def module_for_type(:step), do: LiveFlow.Paths.Step
  def module_for_type(:smoothstep), do: LiveFlow.Paths.Smoothstep
  def module_for_type(_), do: LiveFlow.Paths.Bezier
end

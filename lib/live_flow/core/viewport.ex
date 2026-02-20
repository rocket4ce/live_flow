defmodule LiveFlow.Viewport do
  @moduledoc """
  Viewport data structure for LiveFlow.

  The viewport represents the current pan/zoom state of the flow canvas.
  It tracks the translation (x, y) and zoom level to transform flow
  coordinates to screen coordinates.

  ## Fields

    * `:x` - Horizontal pan offset
    * `:y` - Vertical pan offset
    * `:zoom` - Zoom level (1.0 = 100%)

  ## Coordinate Transformation

  To convert from flow space to screen space:
      screen_x = flow_x * zoom + viewport.x
      screen_y = flow_y * zoom + viewport.y

  To convert from screen space to flow space:
      flow_x = (screen_x - viewport.x) / zoom
      flow_y = (screen_y - viewport.y) / zoom

  ## Examples

      iex> vp = LiveFlow.Viewport.new()
      %LiveFlow.Viewport{x: 0.0, y: 0.0, zoom: 1.0}

      iex> LiveFlow.Viewport.pan(vp, 100, 50)
      %LiveFlow.Viewport{x: 100.0, y: 50.0, zoom: 1.0}
  """

  @type t :: %__MODULE__{
          x: float(),
          y: float(),
          zoom: float()
        }

  defstruct x: 0.0, y: 0.0, zoom: 1.0

  @default_min_zoom 0.1
  @default_max_zoom 4.0

  @doc """
  Creates a new viewport with optional initial values.

  ## Options

    * `:x` - Initial x pan (default: `0.0`)
    * `:y` - Initial y pan (default: `0.0`)
    * `:zoom` - Initial zoom level (default: `1.0`)

  ## Examples

      iex> LiveFlow.Viewport.new()
      %LiveFlow.Viewport{x: 0.0, y: 0.0, zoom: 1.0}

      iex> LiveFlow.Viewport.new(x: 100, y: 50, zoom: 1.5)
      %LiveFlow.Viewport{x: 100.0, y: 50.0, zoom: 1.5}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      x: Keyword.get(opts, :x, 0) * 1.0,
      y: Keyword.get(opts, :y, 0) * 1.0,
      zoom: Keyword.get(opts, :zoom, 1.0) * 1.0
    }
  end

  @doc """
  Sets the viewport position and zoom.
  """
  @spec set(t(), number(), number(), number()) :: t()
  def set(%__MODULE__{}, x, y, zoom) do
    %__MODULE__{x: x * 1.0, y: y * 1.0, zoom: zoom * 1.0}
  end

  @doc """
  Pans the viewport by the given delta.
  """
  @spec pan(t(), number(), number()) :: t()
  def pan(%__MODULE__{x: x, y: y} = vp, dx, dy) do
    %{vp | x: x + dx, y: y + dy}
  end

  @doc """
  Sets the viewport pan position.
  """
  @spec pan_to(t(), number(), number()) :: t()
  def pan_to(%__MODULE__{} = vp, x, y) do
    %{vp | x: x * 1.0, y: y * 1.0}
  end

  @doc """
  Zooms the viewport by a factor.

  ## Options

    * `:center` - Point to zoom towards `{x, y}` in screen coordinates
    * `:min_zoom` - Minimum zoom level (default: `0.1`)
    * `:max_zoom` - Maximum zoom level (default: `4.0`)

  ## Examples

      iex> vp = LiveFlow.Viewport.new()
      iex> LiveFlow.Viewport.zoom_by(vp, 1.5)
      %LiveFlow.Viewport{x: 0.0, y: 0.0, zoom: 1.5}
  """
  @spec zoom_by(t(), number(), keyword()) :: t()
  def zoom_by(%__MODULE__{} = vp, factor, opts \\ []) do
    min_zoom = Keyword.get(opts, :min_zoom, @default_min_zoom)
    max_zoom = Keyword.get(opts, :max_zoom, @default_max_zoom)
    center = Keyword.get(opts, :center)

    new_zoom = clamp(vp.zoom * factor, min_zoom, max_zoom)

    case center do
      nil ->
        %{vp | zoom: new_zoom}

      {cx, cy} ->
        # Zoom towards center point
        scale = new_zoom / vp.zoom
        new_x = cx - (cx - vp.x) * scale
        new_y = cy - (cy - vp.y) * scale
        %{vp | x: new_x, y: new_y, zoom: new_zoom}
    end
  end

  @doc """
  Sets the zoom level directly.

  ## Options

    * `:center` - Point to zoom towards `{x, y}` in screen coordinates
    * `:min_zoom` - Minimum zoom level (default: `0.1`)
    * `:max_zoom` - Maximum zoom level (default: `4.0`)
  """
  @spec zoom_to(t(), number(), keyword()) :: t()
  def zoom_to(%__MODULE__{} = vp, zoom, opts \\ []) do
    min_zoom = Keyword.get(opts, :min_zoom, @default_min_zoom)
    max_zoom = Keyword.get(opts, :max_zoom, @default_max_zoom)
    center = Keyword.get(opts, :center)

    new_zoom = clamp(zoom * 1.0, min_zoom, max_zoom)

    case center do
      nil ->
        %{vp | zoom: new_zoom}

      {cx, cy} ->
        scale = new_zoom / vp.zoom
        new_x = cx - (cx - vp.x) * scale
        new_y = cy - (cy - vp.y) * scale
        %{vp | x: new_x, y: new_y, zoom: new_zoom}
    end
  end

  @doc """
  Converts screen coordinates to flow coordinates.

  ## Examples

      iex> vp = LiveFlow.Viewport.new(x: 100, y: 50, zoom: 2.0)
      iex> LiveFlow.Viewport.screen_to_flow(vp, 200, 150)
      {50.0, 50.0}
  """
  @spec screen_to_flow(t(), number(), number()) :: {float(), float()}
  def screen_to_flow(%__MODULE__{x: vx, y: vy, zoom: z}, screen_x, screen_y) do
    {(screen_x - vx) / z, (screen_y - vy) / z}
  end

  @doc """
  Converts flow coordinates to screen coordinates.

  ## Examples

      iex> vp = LiveFlow.Viewport.new(x: 100, y: 50, zoom: 2.0)
      iex> LiveFlow.Viewport.flow_to_screen(vp, 50, 50)
      {200.0, 150.0}
  """
  @spec flow_to_screen(t(), number(), number()) :: {float(), float()}
  def flow_to_screen(%__MODULE__{x: vx, y: vy, zoom: z}, flow_x, flow_y) do
    {flow_x * z + vx, flow_y * z + vy}
  end

  @doc """
  Gets the CSS transform string for the viewport.

  ## Examples

      iex> vp = LiveFlow.Viewport.new(x: 100, y: 50, zoom: 1.5)
      iex> LiveFlow.Viewport.transform_style(vp)
      "translate(100.0px, 50.0px) scale(1.5)"
  """
  @spec transform_style(t()) :: String.t()
  def transform_style(%__MODULE__{x: x, y: y, zoom: z}) do
    "translate(#{x}px, #{y}px) scale(#{z})"
  end

  @doc """
  Calculates viewport to fit given bounds with optional padding.

  ## Options

    * `:padding` - Padding ratio (default: `0.1` = 10%)
    * `:min_zoom` - Minimum zoom level (default: `0.1`)
    * `:max_zoom` - Maximum zoom level (default: `4.0`)

  ## Examples

      iex> bounds = %{x: 0, y: 0, width: 400, height: 300}
      iex> LiveFlow.Viewport.fit_bounds(%{width: 800, height: 600}, bounds)
      %LiveFlow.Viewport{x: 80.0, y: 60.0, zoom: 1.6}
  """
  @spec fit_bounds(map(), map(), keyword()) :: t()
  def fit_bounds(container, bounds, opts \\ []) do
    padding = Keyword.get(opts, :padding, 0.1)
    min_zoom = Keyword.get(opts, :min_zoom, @default_min_zoom)
    max_zoom = Keyword.get(opts, :max_zoom, @default_max_zoom)

    container_width = container.width * (1 - padding * 2)
    container_height = container.height * (1 - padding * 2)

    bounds_width = max(bounds.width, 1)
    bounds_height = max(bounds.height, 1)

    zoom =
      min(container_width / bounds_width, container_height / bounds_height)
      |> clamp(min_zoom, max_zoom)

    # Center the bounds in the container
    center_x = bounds.x + bounds_width / 2
    center_y = bounds.y + bounds_height / 2

    x = container.width / 2 - center_x * zoom
    y = container.height / 2 - center_y * zoom

    %__MODULE__{x: x, y: y, zoom: zoom}
  end

  defp clamp(value, min, max) do
    value
    |> max(min)
    |> min(max)
  end
end

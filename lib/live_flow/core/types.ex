defmodule LiveFlow.Types do
  @moduledoc """
  Type definitions for LiveFlow.

  This module contains all the base types used throughout the LiveFlow library.
  """

  @typedoc "Unique identifier for nodes and edges"
  @type id :: String.t()

  @typedoc "Position of a handle on a node"
  @type position :: :top | :bottom | :left | :right

  @typedoc "Type of handle (source emits connections, target receives)"
  @type handle_type :: :source | :target

  @typedoc "Type of edge path rendering"
  @type edge_type :: :bezier | :straight | :step | :smoothstep | atom()

  @typedoc "Node type identifier"
  @type node_type :: :default | :input | :output | atom()

  @typedoc "2D coordinate point"
  @type coordinate :: %{x: number(), y: number()}

  @typedoc "Dimensions of an element"
  @type dimensions :: %{width: number(), height: number()}

  @typedoc "Bounding box with min/max coordinates"
  @type bounds :: %{min: coordinate(), max: coordinate()}

  @typedoc "Rectangle with position and dimensions"
  @type rect :: %{x: number(), y: number(), width: number(), height: number()}

  @typedoc "Extent constraint for node movement"
  @type extent :: :parent | bounds() | nil

  @typedoc "Connection mode for edges"
  @type connection_mode :: :strict | :loose

  @typedoc "Background pattern type"
  @type background_pattern :: :dots | :lines | :cross | nil

  @typedoc "Marker type for edge endpoints"
  @type marker_type ::
          :arrow
          | :arrow_closed
          | :circle
          | :circle_filled
          | :diamond
          | :diamond_filled
          | :none
          | atom()

  @typedoc "Edge marker configuration"
  @type edge_marker :: %{
          optional(:type) => marker_type(),
          optional(:color) => String.t(),
          optional(:width) => number(),
          optional(:height) => number(),
          optional(:stroke_width) => number()
        }

  @doc """
  Returns the opposite position.

  ## Examples

      iex> LiveFlow.Types.opposite_position(:top)
      :bottom

      iex> LiveFlow.Types.opposite_position(:left)
      :right
  """
  @spec opposite_position(position()) :: position()
  def opposite_position(:top), do: :bottom
  def opposite_position(:bottom), do: :top
  def opposite_position(:left), do: :right
  def opposite_position(:right), do: :left

  @doc """
  Checks if a position is horizontal (left or right).
  """
  @spec horizontal?(position()) :: boolean()
  def horizontal?(:left), do: true
  def horizontal?(:right), do: true
  def horizontal?(_), do: false

  @doc """
  Checks if a position is vertical (top or bottom).
  """
  @spec vertical?(position()) :: boolean()
  def vertical?(:top), do: true
  def vertical?(:bottom), do: true
  def vertical?(_), do: false
end

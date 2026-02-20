defmodule LiveFlow.Handle do
  @moduledoc """
  Handle data structure for LiveFlow.

  A handle is a connection point on a node that allows edges to be
  connected. Handles can be either source (output) or target (input).

  ## Fields

    * `:id` - Optional unique identifier within the node
    * `:type` - Handle type: `:source` or `:target`
    * `:position` - Position on the node: `:top`, `:bottom`, `:left`, `:right`
    * `:connectable` - Whether this handle accepts connections
    * `:connect_type` - Optional type constraint atom (e.g., `:data`, `:control`)
    * `:style` - Custom inline styles
    * `:class` - Custom CSS classes

  ## Examples

      iex> LiveFlow.Handle.new(:source, :bottom)
      %LiveFlow.Handle{type: :source, position: :bottom}

      iex> LiveFlow.Handle.new(:target, :top, id: "input-1")
      %LiveFlow.Handle{id: "input-1", type: :target, position: :top}
  """

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: :source | :target,
          position: :top | :bottom | :left | :right,
          connectable: boolean(),
          connect_type: atom() | nil,
          style: map(),
          class: String.t() | nil
        }

  defstruct [
    :id,
    :class,
    :connect_type,
    type: :source,
    position: :bottom,
    connectable: true,
    style: %{}
  ]

  @doc """
  Creates a new handle with the given type and position.

  ## Options

    * `:id` - Handle ID (default: `nil`, will use type as identifier)
    * `:connectable` - Whether connectable (default: `true`)
    * `:connect_type` - Type constraint atom for validation (default: `nil`)
    * `:style` - Custom inline styles
    * `:class` - Custom CSS classes

  ## Examples

      iex> LiveFlow.Handle.new(:source, :right)
      %LiveFlow.Handle{type: :source, position: :right}

      iex> LiveFlow.Handle.new(:target, :left, id: "in", connectable: false)
      %LiveFlow.Handle{id: "in", type: :target, position: :left, connectable: false}
  """
  @spec new(:source | :target, :top | :bottom | :left | :right, keyword()) :: t()
  def new(type, position, opts \\ []) when type in [:source, :target] do
    %__MODULE__{
      id: Keyword.get(opts, :id),
      type: type,
      position: position,
      connectable: Keyword.get(opts, :connectable, true),
      connect_type: Keyword.get(opts, :connect_type),
      style: Keyword.get(opts, :style, %{}),
      class: Keyword.get(opts, :class)
    }
  end

  @doc """
  Creates a source handle (output).
  """
  @spec source(:top | :bottom | :left | :right, keyword()) :: t()
  def source(position, opts \\ []) do
    new(:source, position, opts)
  end

  @doc """
  Creates a target handle (input).
  """
  @spec target(:top | :bottom | :left | :right, keyword()) :: t()
  def target(position, opts \\ []) do
    new(:target, position, opts)
  end

  @doc """
  Returns the effective ID for the handle.

  If no ID is set, returns the type as a string.
  """
  @spec effective_id(t()) :: String.t()
  def effective_id(%__MODULE__{id: nil, type: type}), do: Atom.to_string(type)
  def effective_id(%__MODULE__{id: id}), do: id

  @doc """
  Checks if the handle is a source (output).
  """
  @spec source?(t()) :: boolean()
  def source?(%__MODULE__{type: :source}), do: true
  def source?(_), do: false

  @doc """
  Checks if the handle is a target (input).
  """
  @spec target?(t()) :: boolean()
  def target?(%__MODULE__{type: :target}), do: true
  def target?(_), do: false
end

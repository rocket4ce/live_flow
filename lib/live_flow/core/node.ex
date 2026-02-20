defmodule LiveFlow.Node do
  @moduledoc """
  Node data structure for LiveFlow.

  A node represents a visual element in the flow diagram that can be
  positioned, connected via handles, and interacted with.

  ## Fields

    * `:id` - Unique identifier for the node (required)
    * `:type` - Node type atom, used for custom rendering (default: `:default`)
    * `:position` - Position in flow coordinates `%{x: number, y: number}`
    * `:data` - Custom data map passed to the node renderer
    * `:width` - Measured width (set by JS after render)
    * `:height` - Measured height (set by JS after render)
    * `:selected` - Whether the node is currently selected
    * `:draggable` - Whether the node can be dragged
    * `:connectable` - Whether handles can create connections
    * `:selectable` - Whether the node can be selected
    * `:deletable` - Whether the node can be deleted
    * `:hidden` - Whether the node is visible
    * `:dragging` - Whether the node is currently being dragged
    * `:resizing` - Whether the node is currently being resized
    * `:parent_id` - ID of parent node for grouping
    * `:extent` - Movement constraint (`:parent` or bounds map)
    * `:style` - Custom inline styles map
    * `:class` - Custom CSS classes
    * `:z_index` - Stacking order
    * `:handles` - List of `LiveFlow.Handle` structs
    * `:measured` - Whether dimensions have been measured

  ## Examples

      iex> LiveFlow.Node.new("node-1", %{x: 100, y: 100}, %{label: "Start"})
      %LiveFlow.Node{id: "node-1", position: %{x: 100, y: 100}, data: %{label: "Start"}}

      iex> LiveFlow.Node.new("node-2", %{x: 200, y: 150}, %{}, type: :input)
      %LiveFlow.Node{id: "node-2", type: :input, position: %{x: 200, y: 150}}
  """

  alias LiveFlow.Handle

  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          position: %{x: number(), y: number()},
          data: map(),
          width: number() | nil,
          height: number() | nil,
          selected: boolean(),
          draggable: boolean(),
          connectable: boolean(),
          selectable: boolean(),
          deletable: boolean(),
          hidden: boolean(),
          dragging: boolean(),
          resizing: boolean(),
          parent_id: String.t() | nil,
          extent: :parent | map() | nil,
          style: map(),
          class: String.t() | nil,
          z_index: integer(),
          handles: [Handle.t()],
          measured: boolean()
        }

  defstruct [
    :id,
    :width,
    :height,
    :parent_id,
    :class,
    type: :default,
    position: %{x: 0.0, y: 0.0},
    data: %{},
    selected: false,
    draggable: true,
    connectable: true,
    selectable: true,
    deletable: true,
    hidden: false,
    dragging: false,
    resizing: false,
    extent: nil,
    style: %{},
    z_index: 0,
    handles: [],
    measured: false
  ]

  @doc """
  Creates a new node with the given id, position, and data.

  ## Options

    * `:type` - Node type (default: `:default`)
    * `:draggable` - Whether draggable (default: `true`)
    * `:connectable` - Whether connectable (default: `true`)
    * `:selectable` - Whether selectable (default: `true`)
    * `:deletable` - Whether deletable (default: `true`)
    * `:parent_id` - Parent node ID for grouping
    * `:extent` - Movement constraint
    * `:style` - Custom inline styles
    * `:class` - Custom CSS classes
    * `:z_index` - Stacking order (default: `0`)
    * `:handles` - List of handles (default: `[]`)

  ## Examples

      iex> LiveFlow.Node.new("1", %{x: 0, y: 0}, %{label: "Hello"})
      %LiveFlow.Node{id: "1", position: %{x: 0, y: 0}, data: %{label: "Hello"}}

      iex> LiveFlow.Node.new("2", %{x: 100, y: 100}, %{}, type: :input, draggable: false)
      %LiveFlow.Node{id: "2", type: :input, position: %{x: 100, y: 100}, draggable: false}
  """
  @spec new(String.t(), map(), map(), keyword()) :: t()
  def new(id, position, data \\ %{}, opts \\ []) do
    %__MODULE__{
      id: id,
      position: normalize_position(position),
      data: data,
      type: Keyword.get(opts, :type, :default),
      draggable: Keyword.get(opts, :draggable, true),
      connectable: Keyword.get(opts, :connectable, true),
      selectable: Keyword.get(opts, :selectable, true),
      deletable: Keyword.get(opts, :deletable, true),
      parent_id: Keyword.get(opts, :parent_id),
      extent: Keyword.get(opts, :extent),
      style: Keyword.get(opts, :style, %{}),
      class: Keyword.get(opts, :class),
      z_index: Keyword.get(opts, :z_index, 0),
      handles: Keyword.get(opts, :handles, [])
    }
  end

  @doc """
  Updates a node with the given attributes.

  ## Examples

      iex> node = LiveFlow.Node.new("1", %{x: 0, y: 0}, %{})
      iex> LiveFlow.Node.update(node, position: %{x: 100, y: 100})
      %LiveFlow.Node{id: "1", position: %{x: 100.0, y: 100.0}}
  """
  @spec update(t(), keyword()) :: t()
  def update(%__MODULE__{} = node, attrs) do
    attrs =
      if Keyword.has_key?(attrs, :position) do
        Keyword.update!(attrs, :position, &normalize_position/1)
      else
        attrs
      end

    struct(node, attrs)
  end

  @doc """
  Moves a node to a new position.

  ## Examples

      iex> node = LiveFlow.Node.new("1", %{x: 0, y: 0}, %{})
      iex> LiveFlow.Node.move(node, %{x: 50, y: 50})
      %LiveFlow.Node{id: "1", position: %{x: 50.0, y: 50.0}}
  """
  @spec move(t(), map()) :: t()
  def move(%__MODULE__{} = node, position) do
    %{node | position: normalize_position(position)}
  end

  @doc """
  Moves a node by a delta offset.

  ## Examples

      iex> node = LiveFlow.Node.new("1", %{x: 100, y: 100}, %{})
      iex> LiveFlow.Node.move_by(node, 10, -20)
      %LiveFlow.Node{id: "1", position: %{x: 110.0, y: 80.0}}
  """
  @spec move_by(t(), number(), number()) :: t()
  def move_by(%__MODULE__{position: pos} = node, dx, dy) do
    %{node | position: %{x: pos.x + dx, y: pos.y + dy}}
  end

  @doc """
  Sets the node's selected state.
  """
  @spec select(t(), boolean()) :: t()
  def select(%__MODULE__{} = node, selected \\ true) do
    %{node | selected: selected}
  end

  @doc """
  Sets the node's dimensions after measurement.
  """
  @spec set_dimensions(t(), number(), number()) :: t()
  def set_dimensions(%__MODULE__{} = node, width, height) do
    %{node | width: width, height: height, measured: true}
  end

  @doc """
  Sets the node's dragging state.
  """
  @spec set_dragging(t(), boolean()) :: t()
  def set_dragging(%__MODULE__{} = node, dragging) do
    %{node | dragging: dragging}
  end

  @doc """
  Adds a handle to the node.
  """
  @spec add_handle(t(), Handle.t()) :: t()
  def add_handle(%__MODULE__{handles: handles} = node, %Handle{} = handle) do
    %{node | handles: handles ++ [handle]}
  end

  @doc """
  Gets the bounding box of the node.

  Returns `nil` if the node hasn't been measured yet.
  """
  @spec bounds(t()) :: map() | nil
  def bounds(%__MODULE__{measured: false}), do: nil

  def bounds(%__MODULE__{position: pos, width: w, height: h}) do
    %{
      x: pos.x,
      y: pos.y,
      width: w,
      height: h,
      x2: pos.x + w,
      y2: pos.y + h
    }
  end

  @doc """
  Gets the center point of the node.

  Returns `nil` if the node hasn't been measured yet.
  """
  @spec center(t()) :: map() | nil
  def center(%__MODULE__{measured: false}), do: nil

  def center(%__MODULE__{position: pos, width: w, height: h}) do
    %{x: pos.x + w / 2, y: pos.y + h / 2}
  end

  @doc """
  Checks if a point is inside the node's bounds.
  """
  @spec contains_point?(t(), number(), number()) :: boolean()
  def contains_point?(%__MODULE__{measured: false}, _x, _y), do: false

  def contains_point?(%__MODULE__{} = node, x, y) do
    case bounds(node) do
      nil ->
        false

      b ->
        x >= b.x && x <= b.x2 && y >= b.y && y <= b.y2
    end
  end

  # Normalize position to ensure float values
  defp normalize_position(%{x: x, y: y}) do
    %{x: x / 1.0, y: y / 1.0}
  end

  defp normalize_position(%{"x" => x, "y" => y}) do
    %{x: x / 1.0, y: y / 1.0}
  end
end

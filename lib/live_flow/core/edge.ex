defmodule LiveFlow.Edge do
  @moduledoc """
  Edge data structure for LiveFlow.

  An edge represents a connection between two nodes, from a source
  node's handle to a target node's handle.

  ## Fields

    * `:id` - Unique identifier for the edge (required)
    * `:source` - Source node ID (required)
    * `:target` - Target node ID (required)
    * `:source_handle` - Source handle ID (optional)
    * `:target_handle` - Target handle ID (optional)
    * `:type` - Edge type: `:bezier`, `:straight`, `:step`, `:smoothstep`
    * `:animated` - Whether to show animation on the edge
    * `:selected` - Whether the edge is currently selected
    * `:selectable` - Whether the edge can be selected
    * `:deletable` - Whether the edge can be deleted
    * `:hidden` - Whether the edge is visible
    * `:data` - Custom data map
    * `:label` - Edge label text
    * `:label_position` - Position of label along edge (0.0 to 1.0)
    * `:label_style` - Custom styles for label
    * `:marker_start` - Marker at start of edge
    * `:marker_end` - Marker at end of edge
    * `:style` - Custom inline styles
    * `:class` - Custom CSS classes
    * `:z_index` - Stacking order
    * `:interaction_width` - Clickable width for selection
    * `:path_options` - Additional options for path calculation

  ## Examples

      iex> LiveFlow.Edge.new("e1", "node-1", "node-2")
      %LiveFlow.Edge{id: "e1", source: "node-1", target: "node-2"}

      iex> LiveFlow.Edge.new("e2", "a", "b", type: :straight, animated: true)
      %LiveFlow.Edge{id: "e2", source: "a", target: "b", type: :straight, animated: true}
  """

  @type t :: %__MODULE__{
          id: String.t(),
          source: String.t(),
          target: String.t(),
          source_handle: String.t() | nil,
          target_handle: String.t() | nil,
          type: atom(),
          animated: boolean(),
          selected: boolean(),
          selectable: boolean(),
          deletable: boolean(),
          hidden: boolean(),
          data: map(),
          label: String.t() | nil,
          label_position: float(),
          label_style: map(),
          marker_start: map() | nil,
          marker_end: map() | nil,
          style: map(),
          class: String.t() | nil,
          z_index: integer(),
          interaction_width: integer(),
          path_options: map()
        }

  defstruct [
    :id,
    :source,
    :target,
    :source_handle,
    :target_handle,
    :label,
    :marker_start,
    :class,
    type: :bezier,
    animated: false,
    selected: false,
    selectable: true,
    deletable: true,
    hidden: false,
    data: %{},
    label_position: 0.5,
    label_style: %{},
    marker_end: %{type: :arrow},
    style: %{},
    z_index: 0,
    interaction_width: 20,
    path_options: %{}
  ]

  @doc """
  Creates a new edge between source and target nodes.

  ## Options

    * `:source_handle` - Source handle ID
    * `:target_handle` - Target handle ID
    * `:type` - Edge type (default: `:bezier`)
    * `:animated` - Whether animated (default: `false`)
    * `:selectable` - Whether selectable (default: `true`)
    * `:deletable` - Whether deletable (default: `true`)
    * `:label` - Edge label text
    * `:marker_end` - End marker config (default: `%{type: :arrow}`)
    * `:marker_start` - Start marker config
    * `:style` - Custom inline styles
    * `:class` - Custom CSS classes
    * `:z_index` - Stacking order
    * `:data` - Custom data map

  ## Examples

      iex> LiveFlow.Edge.new("1", "a", "b")
      %LiveFlow.Edge{id: "1", source: "a", target: "b"}

      iex> LiveFlow.Edge.new("2", "a", "b", source_handle: "out", target_handle: "in")
      %LiveFlow.Edge{id: "2", source: "a", target: "b", source_handle: "out", target_handle: "in"}
  """
  @spec new(String.t(), String.t(), String.t(), keyword()) :: t()
  def new(id, source, target, opts \\ []) do
    %__MODULE__{
      id: id,
      source: source,
      target: target,
      source_handle: Keyword.get(opts, :source_handle),
      target_handle: Keyword.get(opts, :target_handle),
      type: Keyword.get(opts, :type, :bezier),
      animated: Keyword.get(opts, :animated, false),
      selectable: Keyword.get(opts, :selectable, true),
      deletable: Keyword.get(opts, :deletable, true),
      label: Keyword.get(opts, :label),
      label_position: Keyword.get(opts, :label_position, 0.5),
      label_style: Keyword.get(opts, :label_style, %{}),
      marker_start: Keyword.get(opts, :marker_start),
      marker_end: Keyword.get(opts, :marker_end, %{type: :arrow}),
      style: Keyword.get(opts, :style, %{}),
      class: Keyword.get(opts, :class),
      z_index: Keyword.get(opts, :z_index, 0),
      data: Keyword.get(opts, :data, %{}),
      path_options: Keyword.get(opts, :path_options, %{})
    }
  end

  @doc """
  Updates an edge with the given attributes.
  """
  @spec update(t(), keyword()) :: t()
  def update(%__MODULE__{} = edge, attrs) do
    struct(edge, attrs)
  end

  @doc """
  Sets the edge's selected state.
  """
  @spec select(t(), boolean()) :: t()
  def select(%__MODULE__{} = edge, selected \\ true) do
    %{edge | selected: selected}
  end

  @doc """
  Sets the edge's animated state.
  """
  @spec animate(t(), boolean()) :: t()
  def animate(%__MODULE__{} = edge, animated \\ true) do
    %{edge | animated: animated}
  end

  @doc """
  Sets the edge label.
  """
  @spec set_label(t(), String.t() | nil) :: t()
  def set_label(%__MODULE__{} = edge, label) do
    %{edge | label: label}
  end

  @doc """
  Checks if two edges connect the same nodes (ignoring direction).
  """
  @spec connects_same_nodes?(t(), t()) :: boolean()
  def connects_same_nodes?(%__MODULE__{} = e1, %__MODULE__{} = e2) do
    (e1.source == e2.source and e1.target == e2.target) or
      (e1.source == e2.target and e1.target == e2.source)
  end

  @doc """
  Checks if an edge connects to a specific node (either as source or target).
  """
  @spec connects_to?(t(), String.t()) :: boolean()
  def connects_to?(%__MODULE__{source: source, target: target}, node_id) do
    source == node_id or target == node_id
  end

  @doc """
  Gets the effective source handle ID.
  """
  @spec effective_source_handle(t()) :: String.t()
  def effective_source_handle(%__MODULE__{source_handle: nil}), do: "source"
  def effective_source_handle(%__MODULE__{source_handle: h}), do: h

  @doc """
  Gets the effective target handle ID.
  """
  @spec effective_target_handle(t()) :: String.t()
  def effective_target_handle(%__MODULE__{target_handle: nil}), do: "target"
  def effective_target_handle(%__MODULE__{target_handle: h}), do: h
end

defmodule LiveFlow.Components.NodeToolbar do
  @moduledoc """
  A toolbar attached to a node (React Flow's `<NodeToolbar />`).

  Render it inside a custom node. It is shown while the node is selected
  (or when `is_visible` says so) and positioned outside the node box.
  Clicks on its buttons don't start a drag.

  ## Examples

      def my_node(assigns) do
        ~H\"\"\"
        <LiveFlow.Components.NodeToolbar.node_toolbar node={@node} position={:top}>
          <button phx-click="duplicate" phx-value-id={@node.id}>Duplicate</button>
          <button phx-click="delete" phx-value-id={@node.id}>Delete</button>
        </LiveFlow.Components.NodeToolbar.node_toolbar>
        <div>{@node.data.label}</div>
        \"\"\"
      end
  """

  use Phoenix.Component

  @doc """
  Renders the toolbar.

  ## Attributes

    * `:node` - The node (required)
    * `:is_visible` - Force visibility; defaults to `node.selected`
    * `:position` - `:top`, `:bottom`, `:left` or `:right` (default: `:top`)
    * `:align` - `:start`, `:center` or `:end` (default: `:center`)
    * `:offset` - Gap between node and toolbar in pixels (default: `10`)
  """
  attr :node, :map, required: true
  attr :is_visible, :boolean, default: nil
  attr :position, :atom, default: :top, values: [:top, :bottom, :left, :right]
  attr :align, :atom, default: :center, values: [:start, :center, :end]
  attr :offset, :integer, default: 10
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def node_toolbar(assigns) do
    visible = if is_nil(assigns.is_visible), do: assigns.node.selected, else: assigns.is_visible
    assigns = assign(assigns, :visible, visible)

    ~H"""
    <div
      :if={@visible}
      class={["lf-node-toolbar nodrag nopan", @class]}
      data-position={@position}
      data-align={@align}
      style={"--lf-node-toolbar-offset: #{@offset}px"}
      data-lf-export-ignore
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end

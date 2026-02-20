defmodule LiveFlow.Components.Handle do
  @moduledoc """
  Handle function component for LiveFlow.

  Handles are connection points on nodes that allow edges to be created.
  They render as small circles positioned on the edges of nodes.
  """

  use Phoenix.Component

  @doc """
  Renders a handle on a node.

  ## Attributes

    * `:handle` - The `LiveFlow.Handle` struct (required)
    * `:node_id` - ID of the parent node (required)
    * `:class` - Additional CSS classes

  ## Examples

      <.handle handle={handle} node_id="node-1" />
  """
  attr :handle, LiveFlow.Handle, required: true
  attr :node_id, :string, required: true
  attr :class, :string, default: nil

  def handle(assigns) do
    handle = assigns.handle
    handle_id = LiveFlow.Handle.effective_id(handle)

    assigns =
      assigns
      |> assign(:handle_id, handle_id)
      |> assign(:position, handle.position)
      |> assign(:type, handle.type)
      |> assign(:connectable, handle.connectable)

    ~H"""
    <div
      class={[
        "lf-handle",
        @class,
        @handle.class
      ]}
      data-handle-id={@handle_id}
      data-handle-type={@type}
      data-handle-position={@position}
      data-handle-connectable={@connectable}
      data-handle-connect-type={Map.get(@handle, :connect_type)}
      data-node-id={@node_id}
      style={handle_style(@handle)}
    >
    </div>
    """
  end

  @doc """
  Renders a source handle (output).
  """
  attr :id, :string, default: nil
  attr :position, :atom, default: :right
  attr :node_id, :string, required: true
  attr :connectable, :boolean, default: true
  attr :class, :string, default: nil

  def source(assigns) do
    handle =
      LiveFlow.Handle.source(assigns.position, id: assigns.id, connectable: assigns.connectable)

    assigns = assign(assigns, :handle, handle)

    ~H"""
    <.handle handle={@handle} node_id={@node_id} class={@class} />
    """
  end

  @doc """
  Renders a target handle (input).
  """
  attr :id, :string, default: nil
  attr :position, :atom, default: :left
  attr :node_id, :string, required: true
  attr :connectable, :boolean, default: true
  attr :class, :string, default: nil

  def target(assigns) do
    handle =
      LiveFlow.Handle.target(assigns.position, id: assigns.id, connectable: assigns.connectable)

    assigns = assign(assigns, :handle, handle)

    ~H"""
    <.handle handle={@handle} node_id={@node_id} class={@class} />
    """
  end

  defp handle_style(%LiveFlow.Handle{style: style}) when map_size(style) == 0, do: nil

  defp handle_style(%LiveFlow.Handle{style: style}) do
    style
    |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
    |> Enum.join("; ")
  end
end

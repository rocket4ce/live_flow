defmodule LiveFlow.Components.NodeResizer do
  @moduledoc """
  Node resizer component for LiveFlow.

  Adds resize handles to custom nodes, allowing users to interactively
  resize them by dragging corners or edges. Similar to React Flow's
  `<NodeResizer>` component.

  ## Usage

  Add the resizer inside your custom node component, and mark the node
  `resizable: true` so its size is kept:

      Node.new("note", %{x: 0, y: 0}, %{}, type: :note, resizable: true)

      defp my_resizable_node(assigns) do
        ~H\"\"\"
        <div style="width: 100%; height: 100%; min-height: 80px; padding: 16px;">
          <LiveFlow.Components.NodeResizer.node_resizer node_id={@node.id} />
          <div>Resize me!</div>
        </div>
        \"\"\"
      end

  Handles come from the node's `handles` list, as for any node.

  ## Options

    * `:node_id` - Required. The ID of the parent node.
    * `:min_width` - Minimum width in pixels (default: `50`).
    * `:min_height` - Minimum height in pixels (default: `30`).
    * `:max_width` / `:max_height` - Maximum size in pixels (default: `nil`).
    * `:keep_aspect_ratio` - Keep the width/height ratio (default: `false`).
    * `:color` - CSS color for resize handles (default: uses theme variable).
    * `:is_visible` - Whether the resizer is rendered (default: `true`).
    * `:handles` - List of handle positions to show. Default: all 8.
      Positions: `:n`, `:s`, `:e`, `:w`, `:ne`, `:nw`, `:se`, `:sw`

  The resizer renders small corner squares and edge lines that the user
  can drag to resize the node. During resize, edge paths connected to
  the node update in real time (client-side).
  """

  use Phoenix.Component

  @all_handles [:n, :s, :e, :w, :ne, :nw, :se, :sw]

  @doc """
  Renders resize handles for a node.

  ## Examples

      <.node_resizer node_id="node-1" />
      <.node_resizer node_id="node-1" min_width={100} min_height={80} />
      <.node_resizer node_id="node-1" handles={[:se, :e, :s]} />
      <.node_resizer node_id="node-1" max_width={400} keep_aspect_ratio />

  Resizing is constrained by the flow's `node_extent` option. The server
  receives a `resize` change with `resizing: true` when the resize starts
  and always a final one with `resizing: false` (also when it is aborted
  with Escape).
  """
  attr :node_id, :string, required: true
  attr :min_width, :integer, default: 50
  attr :min_height, :integer, default: 30
  attr :max_width, :integer, default: nil
  attr :max_height, :integer, default: nil
  attr :keep_aspect_ratio, :boolean, default: false
  attr :color, :string, default: nil
  attr :is_visible, :boolean, default: true
  attr :handles, :list, default: @all_handles

  def node_resizer(assigns) do
    assigns = assign(assigns, :all_handles, assigns.handles)

    ~H"""
    <div
      :if={@is_visible}
      class="lf-node-resizer-container"
      data-min-width={@min_width}
      data-min-height={@min_height}
    >
      <div
        :for={pos <- @all_handles}
        class={[
          "lf-node-resizer",
          corner?(pos) && "lf-node-resizer-corner",
          !corner?(pos) && "lf-node-resizer-line"
        ]}
        data-resizer-position={pos}
        data-node-id={@node_id}
        data-min-width={@min_width}
        data-min-height={@min_height}
        data-max-width={@max_width}
        data-max-height={@max_height}
        data-keep-aspect-ratio={to_string(@keep_aspect_ratio)}
        style={resizer_color_style(@color)}
      >
      </div>
    </div>
    """
  end

  defp corner?(pos) when pos in [:ne, :nw, :se, :sw], do: true
  defp corner?(_), do: false

  defp resizer_color_style(nil), do: nil
  defp resizer_color_style(color), do: "--lf-resizer-color: #{color}"
end

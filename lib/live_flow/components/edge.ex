defmodule LiveFlow.Components.Edge do
  @moduledoc """
  Edge function component for LiveFlow.

  Renders edges as SVG paths connecting nodes. Supports multiple
  path types (bezier, straight, step, smoothstep).
  """

  use Phoenix.Component

  alias LiveFlow.{Edge, Node, Handle}
  alias LiveFlow.Paths.Path

  @doc """
  Renders an edge between two nodes.

  ## Attributes

    * `:edge` - The `LiveFlow.Edge` struct (required)
    * `:source_node` - Source `LiveFlow.Node` struct (required)
    * `:target_node` - Target `LiveFlow.Node` struct (required)
    * `:class` - Additional CSS classes

  ## Examples

      <.edge edge={edge} source_node={source} target_node={target} />
  """
  attr :edge, Edge, required: true
  attr :source_node, Node, required: true
  attr :target_node, Node, required: true
  attr :class, :string, default: nil

  def edge(assigns) do
    edge = assigns.edge
    source_node = assigns.source_node
    target_node = assigns.target_node

    # Calculate handle positions
    {source_pos, source_handle_position} =
      get_handle_position(source_node, edge.source_handle, :source)

    {target_pos, target_handle_position} =
      get_handle_position(target_node, edge.target_handle, :target)

    # Calculate path
    path_module = Path.module_for_type(edge.type)

    path_result =
      if source_pos && target_pos do
        Path.calculate(
          path_module,
          %{x: source_pos.x, y: source_pos.y, position: source_handle_position},
          %{x: target_pos.x, y: target_pos.y, position: target_handle_position},
          Map.to_list(edge.path_options)
        )
      else
        %{path: "", label_x: 0, label_y: 0}
      end

    assigns =
      assigns
      |> assign(:path, path_result.path)
      |> assign(:label_x, path_result.label_x)
      |> assign(:label_y, path_result.label_y)
      |> assign(:marker_start_id, marker_id(edge.marker_start))
      |> assign(:marker_end_id, marker_id(edge.marker_end))

    ~H"""
    <g class={["lf-edge-group", @class, @edge.class]} data-edge-id={@edge.id}>
      <%!-- Invisible wider path for easier selection --%>
      <path
        class="lf-edge-interaction"
        d={@path}
        data-edge-id={@edge.id}
      />
      <%!-- Visible edge path --%>
      <path
        class="lf-edge"
        d={@path}
        data-edge-id={@edge.id}
        data-selected={@edge.selected}
        data-animated={@edge.animated}
        marker-start={@marker_start_id}
        marker-end={@marker_end_id}
        style={edge_style(@edge)}
      />
      <%!-- Edge label --%>
      <foreignObject
        :if={@edge.label}
        x={@label_x - 50}
        y={@label_y - 10}
        width="100"
        height="20"
        class="lf-edge-label-wrapper"
      >
        <div class="lf-edge-label" style={label_style(@edge)}>
          {@edge.label}
        </div>
      </foreignObject>
      <%!-- Insert "+" button on edge midpoint (only when edge.data[:insertable] is true) --%>
      <foreignObject
        :if={Map.get(@edge.data || %{}, :insertable, false) and not @edge.selected}
        x={@label_x - 12}
        y={@label_y - 12}
        width="24"
        height="24"
        class="lf-edge-insert-wrapper"
      >
        <div class="lf-edge-insert-btn" data-edge-id={@edge.id}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="12"
            height="12"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="3"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <line x1="12" y1="5" x2="12" y2="19" />
            <line x1="5" y1="12" x2="19" y2="12" />
          </svg>
        </div>
      </foreignObject>
      <%!-- Delete button when selected --%>
      <foreignObject
        :if={@edge.selected and @edge.deletable}
        x={@label_x - 12}
        y={@label_y - 12}
        width="24"
        height="24"
        class="lf-edge-delete-wrapper"
      >
        <div class="lf-edge-delete-btn" data-edge-id={@edge.id}>
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <polyline points="3 6 5 6 21 6" />
            <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
          </svg>
        </div>
      </foreignObject>
    </g>
    """
  end

  @doc """
  Renders the connection line during edge creation.
  """
  attr :from_x, :float, required: true
  attr :from_y, :float, required: true
  attr :to_x, :float, required: true
  attr :to_y, :float, required: true
  attr :from_position, :atom, default: :right
  attr :type, :atom, default: :bezier

  def connection_line(assigns) do
    path_module = Path.module_for_type(assigns.type)

    path_result =
      Path.calculate(
        path_module,
        %{x: assigns.from_x, y: assigns.from_y, position: assigns.from_position},
        %{x: assigns.to_x, y: assigns.to_y, position: opposite_position(assigns.from_position)},
        []
      )

    assigns = assign(assigns, :path, path_result.path)

    ~H"""
    <g class="lf-connection-line-group">
      <path class="lf-connection-line" d={@path} />
    </g>
    """
  end

  # Get the position of a handle on a node
  defp get_handle_position(%Node{} = node, handle_id, type) do
    # Find the handle
    handle = find_handle(node.handles, handle_id, type)
    handle_position = if handle, do: handle.position, else: default_handle_position(type)

    # Calculate position based on node bounds and handle position
    pos = calculate_handle_coords(node, handle_position)
    {pos, handle_position}
  end

  defp find_handle(handles, nil, type) do
    # No specific handle, find first of matching type
    Enum.find(handles, fn h -> h.type == type end)
  end

  defp find_handle(handles, handle_id, _type) do
    Enum.find(handles, fn h -> Handle.effective_id(h) == handle_id end)
  end

  defp default_handle_position(:source), do: :right
  defp default_handle_position(:target), do: :left

  defp calculate_handle_coords(%Node{position: pos, width: w, height: h}, handle_position) do
    w = w || 100
    h = h || 40

    case handle_position do
      :top -> %{x: pos.x + w / 2, y: pos.y}
      :bottom -> %{x: pos.x + w / 2, y: pos.y + h}
      :left -> %{x: pos.x, y: pos.y + h / 2}
      :right -> %{x: pos.x + w, y: pos.y + h / 2}
    end
  end

  defp opposite_position(:left), do: :right
  defp opposite_position(:right), do: :left
  defp opposite_position(:top), do: :bottom
  defp opposite_position(:bottom), do: :top

  defp marker_id(marker), do: LiveFlow.Components.Marker.marker_url(marker)

  defp edge_style(%Edge{style: style}) when map_size(style) == 0, do: nil

  defp edge_style(%Edge{style: style}) do
    style
    |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
    |> Enum.join("; ")
  end

  defp label_style(%Edge{label_style: style}) when map_size(style) == 0, do: nil

  defp label_style(%Edge{label_style: style}) do
    style
    |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
    |> Enum.join("; ")
  end
end

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
  attr :edge_types, :map, default: %{}
  attr :edge_label_renderer, :any, default: nil
  attr :edge_toolbar, :any, default: nil
  attr :class, :string, default: nil

  def edge(assigns) do
    edge = assigns.edge
    source_node = assigns.source_node
    target_node = assigns.target_node

    # Calculate handle positions
    {source_pos, source_handle_position} =
      get_handle_position(source_node, target_node, edge.source_handle, :source, edge)

    {target_pos, target_handle_position} =
      get_handle_position(target_node, source_node, edge.target_handle, :target, edge)

    # Calculate path using the base type for path computation
    # Custom edges can specify path_options: %{base_type: :smoothstep} to override
    path_type = Map.get(edge.path_options, :base_type, base_path_type(edge.type))
    path_module = Path.module_for_type(path_type)

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

    # Check for custom edge renderer
    custom_renderer = Map.get(assigns.edge_types, edge.type)

    assigns =
      assigns
      |> assign(:path, path_result.path)
      |> assign(:label_x, path_result.label_x)
      |> assign(:label_y, path_result.label_y)
      |> assign(:source_pos, source_pos)
      |> assign(:target_pos, target_pos)
      |> assign(:marker_start_id, marker_id(edge.marker_start))
      |> assign(:marker_end_id, marker_id(edge.marker_end))
      |> assign(:custom_renderer, custom_renderer)

    if custom_renderer && is_function(custom_renderer, 1) do
      render_custom_edge(custom_renderer, assigns)
    else
      render_default_edge(assigns)
    end
  end

  defp render_custom_edge(renderer, assigns) do
    # Mark all keys as changed so LiveView always diffs custom edge output.
    # Edge paths are server-computed and must update when nodes move.
    changed_keys = %{
      edge: true,
      path: true,
      label_x: true,
      label_y: true,
      source_pos: true,
      target_pos: true,
      marker_start_id: true,
      marker_end_id: true
    }

    renderer.(%{
      edge: assigns.edge,
      path: assigns.path,
      label_x: assigns.label_x,
      label_y: assigns.label_y,
      source_pos: assigns.source_pos,
      target_pos: assigns.target_pos,
      marker_start_id: assigns.marker_start_id,
      marker_end_id: assigns.marker_end_id,
      __changed__: changed_keys
    })
  end

  defp render_default_edge(assigns) do
    # Determine label renderer: per-edge data override > global edge_label_renderer > default
    label_renderer =
      Map.get(assigns.edge.data || %{}, :label_renderer) || assigns.edge_label_renderer

    assigns = assign(assigns, :label_renderer, label_renderer)

    ~H"""
    <g
      class={["lf-edge-group", @class, @edge.class]}
      data-edge-id={@edge.id}
      data-source={@edge.source}
      data-target={@edge.target}
      data-source-handle={@edge.source_handle}
      data-target-handle={@edge.target_handle}
    >
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
        data-selected={to_string(@edge.selected)}
        data-animated={to_string(@edge.animated)}
        marker-start={@marker_start_id}
        marker-end={@marker_end_id}
        style={edge_style(@edge)}
      />
      <%!-- Edge label --%>
      <%= if @edge.label && @label_renderer && is_function(@label_renderer, 1) do %>
        <foreignObject
          x={@label_x - 75}
          y={@label_y - 20}
          width="150"
          height="40"
          class="lf-edge-label-wrapper lf-edge-label-custom"
        >
          {render_label(@label_renderer, @edge, @label_x, @label_y)}
        </foreignObject>
      <% else %>
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
      <% end %>
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
      <%!-- Edge toolbar or delete button when selected --%>
      <%= if @edge.selected && @edge_toolbar && is_function(@edge_toolbar, 1) do %>
        <foreignObject
          x={@label_x - 60}
          y={@label_y - 18}
          width="120"
          height="36"
          class="lf-edge-toolbar-wrapper"
        >
          {render_toolbar(@edge_toolbar, @edge, @label_x, @label_y)}
        </foreignObject>
      <% else %>
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
      <% end %>
      <%!-- Reconnect handles at endpoints (shown when selected + reconnectable) --%>
      <circle
        :if={@edge.selected and Map.get(@edge, :reconnectable, false) and @source_pos}
        cx={@source_pos.x}
        cy={@source_pos.y}
        r="6"
        class="lf-edge-reconnect-handle"
        data-edge-id={@edge.id}
        data-reconnect-end="source"
      />
      <circle
        :if={@edge.selected and Map.get(@edge, :reconnectable, false) and @target_pos}
        cx={@target_pos.x}
        cy={@target_pos.y}
        r="6"
        class="lf-edge-reconnect-handle"
        data-edge-id={@edge.id}
        data-reconnect-end="target"
      />
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

  defp render_label(renderer, edge, label_x, label_y) do
    renderer.(%{edge: edge, x: label_x, y: label_y, __changed__: %{}})
  end

  defp render_toolbar(renderer, edge, label_x, label_y) do
    renderer.(%{edge: edge, x: label_x, y: label_y, __changed__: %{}})
  end

  # Map custom edge types to their base path type for path computation
  # Built-in types return themselves; custom types default to :bezier
  defp base_path_type(type) when type in [:bezier, :straight, :step, :smoothstep], do: type
  defp base_path_type(_custom_type), do: :bezier

  # Get the position of a handle on a node, with floating edge support
  defp get_handle_position(%Node{} = node, other_node, handle_id, type, edge) do
    floating =
      case type do
        :source -> Map.get(edge, :source_floating, false)
        :target -> Map.get(edge, :target_floating, false)
      end

    if floating do
      get_floating_position(node, other_node)
    else
      get_fixed_handle_position(node, handle_id, type)
    end
  end

  defp get_fixed_handle_position(%Node{} = node, handle_id, type) do
    # Find the handle
    handle = find_handle(node.handles, handle_id, type)
    handle_position = if handle, do: handle.position, else: default_handle_position(type)

    # Calculate position based on node bounds and handle position
    pos = calculate_handle_coords(node, handle_position)
    {pos, handle_position}
  end

  defp get_floating_position(%Node{} = node, %Node{} = other_node) do
    # Calculate the nearest boundary point on node facing other_node's center
    nw = node.width || 100
    nh = node.height || 40
    ow = other_node.width || 100
    oh = other_node.height || 40

    # Node center
    ncx = node.position.x + nw / 2
    ncy = node.position.y + nh / 2
    # Other node center
    ocx = other_node.position.x + ow / 2
    ocy = other_node.position.y + oh / 2

    # Direction vector from this node's center to other node's center
    dx = ocx - ncx
    dy = ocy - ncy

    # Determine which side of the rectangle to use
    # by checking the angle of the direction vector
    if abs(dx) < 0.001 and abs(dy) < 0.001 do
      # Nodes overlap, use default right position
      {%{x: node.position.x + nw, y: ncy}, :right}
    else
      # Check intersection with each side
      half_w = nw / 2
      half_h = nh / 2

      # Time to hit each edge (parametric)
      t_right = if dx > 0, do: half_w / dx, else: :infinity
      t_left = if dx < 0, do: -half_w / dx, else: :infinity
      t_bottom = if dy > 0, do: half_h / dy, else: :infinity
      t_top = if dy < 0, do: -half_h / dy, else: :infinity

      # Find minimum positive t
      candidates = [
        {t_right, :right},
        {t_left, :left},
        {t_bottom, :bottom},
        {t_top, :top}
      ]

      {t, side} =
        candidates
        |> Enum.reject(fn {t, _} -> t == :infinity end)
        |> Enum.min_by(fn {t, _} -> t end, fn -> {1.0, :right} end)

      # Clamp the intersection point to node boundaries
      ix = ncx + dx * t
      iy = ncy + dy * t

      ix = max(node.position.x, min(ix, node.position.x + nw))
      iy = max(node.position.y, min(iy, node.position.y + nh))

      {%{x: ix, y: iy}, side}
    end
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

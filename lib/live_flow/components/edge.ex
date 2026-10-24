defmodule LiveFlow.Components.Edge do
  @moduledoc """
  Edge function component for LiveFlow.

  Renders edges as SVG paths connecting nodes. Supports multiple
  path types (bezier, straight, step, smoothstep).
  """

  use Phoenix.Component

  alias LiveFlow.{Edge, Node}
  alias LiveFlow.Paths.{Geometry, Path}

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

    geometry = Geometry.edge_path(edge, source_node, target_node)

    {path_result, source_pos, target_pos, path_type} =
      case geometry do
        nil ->
          {%{path: "", label_x: 0, label_y: 0}, nil, nil, Geometry.base_path_type(edge.type)}

        g ->
          {g, Map.take(g.source, [:x, :y]), Map.take(g.target, [:x, :y]), g.path_type}
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
      |> assign(:path_type, path_type)
      |> assign(:source_position, geometry && geometry.source.position)
      |> assign(:target_position, geometry && geometry.target.position)
      |> assign(:path_options_json, path_options_json(edge.path_options))

    if custom_renderer && is_function(custom_renderer, 1) do
      render_custom_edge(custom_renderer, assigns)
    else
      render_default_edge(assigns)
    end
  end

  defp render_custom_edge(renderer, assigns) do
    # `__changed__: nil` disables change tracking: custom edges always diff
    # (their paths are server-computed and change when nodes move)
    renderer.(%{
      edge: assigns.edge,
      path: assigns.path,
      label_x: assigns.label_x,
      label_y: assigns.label_y,
      source_pos: assigns.source_pos,
      target_pos: assigns.target_pos,
      source_position: assigns.source_position,
      target_position: assigns.target_position,
      path_type: assigns.path_type,
      path_options_json: assigns.path_options_json,
      marker_start_id: assigns.marker_start_id,
      marker_end_id: assigns.marker_end_id,
      __changed__: nil
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
      data-source-floating={Map.get(@edge, :source_floating, false) && "true"}
      data-target-floating={Map.get(@edge, :target_floating, false) && "true"}
      data-path-type={@path_type}
      data-path-options={@path_options_json}
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
      <%!-- Reconnect handles at the endpoints of reconnectable edges (visible on hover/selection) --%>
      <circle
        :if={Map.get(@edge, :reconnectable, false) and @source_pos}
        cx={@source_pos.x}
        cy={@source_pos.y}
        r="6"
        class="lf-edge-reconnect-handle"
        data-edge-id={@edge.id}
        data-reconnect-end="source"
      />
      <circle
        :if={Map.get(@edge, :reconnectable, false) and @target_pos}
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

  # `__changed__: nil` re-renders custom labels/toolbars whenever the edge
  # changes (an empty map marked every assign as unchanged)
  defp render_label(renderer, edge, label_x, label_y) do
    renderer.(%{edge: edge, x: label_x, y: label_y, __changed__: nil})
  end

  defp render_toolbar(renderer, edge, label_x, label_y) do
    renderer.(%{edge: edge, x: label_x, y: label_y, __changed__: nil})
  end

  # Path options are mirrored to the client so it can redraw the edge with the
  # same algorithm while nodes move (see assets/js/live_flow/utils/edge_updater.js)
  defp path_options_json(options) do
    options = Map.delete(options, :base_type)
    if map_size(options) == 0, do: nil, else: Jason.encode!(options)
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

defmodule LiveFlow.Components.NodeWrapper do
  @moduledoc """
  Node wrapper LiveComponent for LiveFlow.

  Wraps node content and handles positioning, selection state,
  and handle rendering. Supports three ways to customize node content:

  1. **Function component** in `node_types` — simplest, receives `@node` assign
  2. **LiveComponent module** in `node_types` — for stateful custom nodes
  3. **`node_renderer` fallback** — global function for all unmatched types

  Priority: type-specific (node_types) > node_renderer > default label.
  """

  use Phoenix.LiveComponent

  alias LiveFlow.Node
  alias LiveFlow.Components.Handle, as: HandleComponent

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:node_types, fn -> %{} end)
      |> assign_new(:node_renderer, fn -> nil end)
      |> assign_new(:z, fn -> nil end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    node = assigns.node
    node_changed = node_changed(assigns)
    type_renderer = Map.get(assigns.node_types, node.type)
    fallback_renderer = assigns.node_renderer

    renderer_type =
      cond do
        is_function(type_renderer, 1) -> :function
        is_atom(type_renderer) and type_renderer != nil -> :component
        is_function(fallback_renderer, 1) -> :fallback
        true -> :default
      end

    assigns =
      assigns
      |> assign(:renderer_type, renderer_type)
      |> assign(:type_renderer, type_renderer)
      |> assign(:fallback_renderer, fallback_renderer)
      |> assign(:style, node_style(node, assigns.z))
      |> assign(:node_changed, node_changed)

    ~H"""
    <div
      id={@id}
      class={[
        "lf-node",
        @node.class,
        @node.selected && "lf-node-selected"
      ]}
      data-node-id={@node.id}
      data-node-type={@node.type}
      data-selected={to_string(@node.selected)}
      data-draggable={to_string(@node.draggable)}
      data-connectable={to_string(@node.connectable)}
      data-selectable={to_string(@node.selectable)}
      data-deletable={to_string(@node.deletable)}
      data-dragging={to_string(@node.dragging)}
      data-resizable={to_string(@node.resizable)}
      data-resizing={to_string(@node.resizing)}
      data-drag-handle={@node.drag_handle}
      data-parent-id={@node.parent_id}
      data-extent={@node.parent_id && extent_attr(@node.extent)}
      style={@style}
      phx-click="lf:node_click"
      phx-value-node-id={@node.id}
      phx-target={@myself}
    >
      <%!-- Render handles --%>
      <HandleComponent.handle
        :for={handle <- @node.handles}
        handle={handle}
        node_id={@node.id}
      />

      <%!-- Default handles if none specified --%>
      <%= if @node.handles == [] and @node.connectable do %>
        <HandleComponent.target position={:left} node_id={@node.id} />
        <HandleComponent.source position={:right} node_id={@node.id} />
      <% end %>

      <%!-- Delete button when selected --%>
      <div
        :if={@node.selected and @node.deletable}
        class="lf-node-delete-btn"
        data-node-id={@node.id}
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="12"
          height="12"
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

      <%!-- Node content --%>
      <div class="lf-node-content">
        <%= case @renderer_type do %>
          <% :function -> %>
            {render_function_node(@type_renderer, @node, @node_changed)}
          <% :component -> %>
            <.live_component module={@type_renderer} id={"#{@id}-content"} node={@node} />
          <% :fallback -> %>
            {render_function_node(@fallback_renderer, @node, @node_changed)}
          <% :default -> %>
            <.default_node node={@node} />
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Default node rendering when no custom type is specified.
  """
  attr :node, Node, required: true

  def default_node(assigns) do
    label =
      Map.get(assigns.node.data, :label) || Map.get(assigns.node.data, "label") || assigns.node.id

    assigns = assign(assigns, :label, label)

    ~H"""
    <div class="lf-default-node">
      <div class="lf-default-node-label">{@label}</div>
    </div>
    """
  end

  @impl true
  def handle_event("lf:node_click", %{"node-id" => node_id}, socket) do
    # Forward to parent
    send(self(), {:lf_node_click, node_id})
    {:noreply, socket}
  end

  # Pass the function component the same change map `<.component node={@node}>`
  # would: the old node when only the node changed, so its template re-sends
  # just the fields that differ, and nil (render everything) otherwise. An
  # empty map, as before, told the template nothing changed, so it never
  # redrew.
  defp render_function_node(renderer, node, node_changed) do
    Phoenix.LiveView.TagEngine.component(
      renderer,
      %{node: node, __changed__: node_changed},
      {__MODULE__, __ENV__.function, __ENV__.file, __ENV__.line}
    )
  end

  defp node_changed(%{__changed__: %{node: old_node} = changed})
       when map_size(changed) == 1,
       do: %{node: old_node}

  defp node_changed(_assigns), do: nil

  # Extent relative to the parent, read by the hook while dragging
  defp extent_attr(:parent), do: "parent"
  defp extent_attr({{x1, y1}, {x2, y2}}), do: Jason.encode!([[x1, y1], [x2, y2]])
  defp extent_attr(_), do: nil

  # `z` is the node's place in the render order computed by the Flow
  # component (z_index, selection elevation, sub-flow hierarchy), so the CSS
  # stacking matches it
  defp node_style(%Node{} = node, z) do
    %{position: pos, style: custom_style, dragging: dragging} = node
    z = z || node.z_index

    base_style = [
      "left: #{pos.x}px",
      "top: #{pos.y}px",
      "z-index: #{z + if(dragging, do: 1000, else: 0)}"
    ]

    # Include explicit width/height for resizable nodes that have been measured
    resize_style =
      if Map.get(node, :resizable) && node.width && node.height do
        ["width: #{node.width}px", "height: #{node.height}px"]
      else
        []
      end

    custom =
      custom_style
      |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)

    (base_style ++ resize_style ++ custom)
    |> Enum.join("; ")
  end
end

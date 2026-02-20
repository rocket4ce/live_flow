defmodule FlotasWeb.FlowDynamicLayoutLive do
  @moduledoc """
  Demo page: Dynamic Layouting.

  A self-organizing tree graph where structural changes (add child,
  convert placeholder, insert on edge, remove) automatically trigger
  a pure-JS tree layout with smooth CSS transitions.
  """

  use FlotasWeb, :live_view

  alias LiveFlow.{State, Node, Edge, Handle, History, Clipboard, Layout, Validation}

  @impl true
  def mount(_params, _session, socket) do
    flow = create_initial_tree()

    {:ok,
     assign(socket,
       page_title: "Dynamic Layouting",
       flow: flow,
       history: History.new(),
       clipboard: Clipboard.new(),
       direction: "TB",
       auto_layout: true,
       node_types: %{
         tree_node: &tree_node/1,
         placeholder: &placeholder_node/1
       },
       auto_layout_pending: true
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="h-screen flex flex-col">
        <div class="p-4 bg-base-200 border-b border-base-300">
          <h1 class="text-2xl font-bold">Dynamic Layouting</h1>
          <p class="text-sm text-base-content/70">
            Self-organizing tree — click nodes to add children, click "+" on edges to insert nodes
          </p>

          <div class="flex gap-2 mt-3 items-center">
            <button class="btn btn-sm btn-primary" phx-click="add_root_node">
              + Root Node
            </button>
            <button
              class={["btn btn-sm", if(@auto_layout, do: "btn-success", else: "btn-ghost")]}
              phx-click="toggle_auto_layout"
            >
              Auto Layout: {if @auto_layout, do: "ON", else: "OFF"}
            </button>
            <button class="btn btn-sm" phx-click="toggle_direction">
              Direction: {@direction}
            </button>
            <button class="btn btn-sm" phx-click="reset_flow">
              Reset
            </button>
            <button class="btn btn-sm" phx-click="fit_view">
              Fit View
            </button>
            <div class="divider divider-horizontal mx-1"></div>
            <button class="btn btn-sm btn-outline" phx-click={JS.dispatch("lf:export-svg", to: "#dynamic-layout-flow")}>
              SVG
            </button>
            <button class="btn btn-sm btn-outline" phx-click={JS.dispatch("lf:export-png", to: "#dynamic-layout-flow")}>
              PNG
            </button>
          </div>
        </div>

        <div class="flex-1 relative">
          <.live_component
            module={LiveFlow.Components.Flow}
            id="dynamic-layout-flow"
            flow={@flow}
            opts={
              %{
                controls: true,
                minimap: true,
                background: :dots,
                fit_view_on_init: true
              }
            }
            node_types={@node_types}
          />
        </div>

        <div class="p-4 bg-base-200 border-t border-base-300">
          <div class="text-sm">
            <span class="font-medium">Nodes:</span> {map_size(@flow.nodes)} |
            <span class="font-medium">Edges:</span> {map_size(@flow.edges)} |
            <span class="font-medium">Direction:</span> {@direction} |
            <span class="font-medium">Undo:</span> {History.undo_count(@history)} |
            <span class="font-medium">Redo:</span> {History.redo_count(@history)}
          </div>
          <div class="text-xs text-base-content/60 mt-1">
            Click "Add Child +" on tree nodes | Click dashed placeholders to convert |
            Hover edges for "+" insert | Ctrl+Z undo | Ctrl+Shift+Z redo
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ===== Custom Node Function Components =====

  defp tree_node(assigns) do
    label = Map.get(assigns.node.data, :label) || Map.get(assigns.node.data, "label", "Node")
    subtitle = Map.get(assigns.node.data, :subtitle) || Map.get(assigns.node.data, "subtitle", "")
    color = Map.get(assigns.node.data, :color) || Map.get(assigns.node.data, "color", "#3b82f6")

    assigns =
      assigns
      |> assign(:label, label)
      |> assign(:subtitle, subtitle)
      |> assign(:color, color)

    ~H"""
    <div style={"min-width: 160px; border-top: 3px solid #{@color}"}>
      <div style="padding: 2px 0 4px">
        <div style={"font-weight: 700; font-size: 14px; color: #{@color}"}>
          {@label}
        </div>
        <div
          :if={@subtitle != ""}
          style="font-size: 11px; color: var(--lf-text-muted); margin-top: 2px"
        >
          {@subtitle}
        </div>
        <button
          class="nodrag"
          phx-click="add_child"
          phx-value-parent-id={@node.id}
          style={"margin-top: 8px; padding: 3px 10px; font-size: 11px; font-weight: 600; border: 1px dashed #{@color}; border-radius: 4px; background: transparent; color: #{@color}; cursor: pointer; width: 100%; text-align: center;"}
        >
          Add Child +
        </button>
      </div>
    </div>
    """
  end

  defp placeholder_node(assigns) do
    ~H"""
    <div
      class="nodrag"
      phx-click="convert_placeholder"
      phx-value-node-id={@node.id}
      style="min-width: 120px; padding: 12px 16px; border: 2px dashed var(--lf-edge-stroke, #b1b1b7); border-radius: var(--lf-node-border-radius, 8px); background: transparent; text-align: center; cursor: pointer; opacity: 0.6; transition: opacity 0.2s;"
      onmouseenter="this.style.opacity='1'"
      onmouseleave="this.style.opacity='0.6'"
    >
      <div style="font-size: 20px; color: var(--lf-text-muted, #888)">+</div>
      <div style="font-size: 11px; color: var(--lf-text-muted, #888); margin-top: 2px">
        Click to add
      </div>
    </div>
    """
  end

  # ===== Event Handlers =====

  @impl true
  def handle_event("add_child", %{"parent-id" => parent_id}, socket) do
    n = System.unique_integer([:positive])
    colors = ["#3b82f6", "#8b5cf6", "#ec4899", "#f59e0b", "#10b981", "#6366f1", "#ef4444"]
    color = Enum.random(colors)

    parent = State.get_node(socket.assigns.flow, parent_id)
    initial_pos = child_position(parent, socket.assigns.direction)

    child = Node.new("tree-#{n}", initial_pos,
      %{label: "Node #{n}", subtitle: "child", color: color},
      type: :tree_node,
      handles: [Handle.target(:top), Handle.source(:bottom)]
    )

    edge = Edge.new("e-#{n}", parent_id, child.id,
      marker_end: %{type: :arrow},
      data: %{insertable: true}
    )

    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = socket.assigns.flow |> State.add_node(child) |> State.add_edge(edge)

    {:noreply,
     socket
     |> assign(flow: flow, history: history)
     |> maybe_trigger_auto_layout()}
  end

  @impl true
  def handle_event("convert_placeholder", %{"node-id" => node_id}, socket) do
    case State.get_node(socket.assigns.flow, node_id) do
      nil ->
        {:noreply, socket}

      node ->
        n = System.unique_integer([:positive])
        colors = ["#3b82f6", "#8b5cf6", "#ec4899", "#f59e0b", "#10b981", "#6366f1"]
        color = Enum.random(colors)

        updated_node = %{node |
          type: :tree_node,
          data: %{label: "Node #{n}", subtitle: "converted", color: color},
          handles: [Handle.target(:top), Handle.source(:bottom)]
        }

        # Add a placeholder child below the converted node
        placeholder = Node.new("ph-#{n}", child_position(node, socket.assigns.direction), %{},
          type: :placeholder,
          handles: [Handle.target(:top)],
          draggable: false
        )

        ph_edge = Edge.new("e-ph-#{n}", node_id, placeholder.id,
          marker_end: %{type: :arrow},
          data: %{insertable: true}
        )

        history = History.push(socket.assigns.history, socket.assigns.flow)

        flow =
          socket.assigns.flow
          |> Map.put(:nodes, Map.put(socket.assigns.flow.nodes, node_id, updated_node))
          |> State.add_node(placeholder)
          |> State.add_edge(ph_edge)

        {:noreply,
         socket
         |> assign(flow: flow, history: history)
         |> maybe_trigger_auto_layout()}
    end
  end

  @impl true
  def handle_event("lf:insert_on_edge", %{"edge_id" => edge_id}, socket) do
    case State.get_edge(socket.assigns.flow, edge_id) do
      nil ->
        {:noreply, socket}

      edge ->
        n = System.unique_integer([:positive])
        colors = ["#3b82f6", "#8b5cf6", "#ec4899", "#f59e0b", "#10b981"]
        color = Enum.random(colors)

        initial_pos = midpoint_position(socket.assigns.flow, edge)

        new_node = Node.new("tree-#{n}", initial_pos,
          %{label: "Node #{n}", subtitle: "inserted", color: color},
          type: :tree_node,
          handles: [Handle.target(:top), Handle.source(:bottom)]
        )

        # Remove old edge, create two new edges
        edge_to_new = Edge.new("e-#{n}a", edge.source, new_node.id,
          marker_end: %{type: :arrow},
          data: %{insertable: true}
        )

        edge_from_new = Edge.new("e-#{n}b", new_node.id, edge.target,
          marker_end: %{type: :arrow},
          data: %{insertable: true}
        )

        history = History.push(socket.assigns.history, socket.assigns.flow)

        flow =
          socket.assigns.flow
          |> State.remove_edge(edge_id)
          |> State.add_node(new_node)
          |> State.add_edge(edge_to_new)
          |> State.add_edge(edge_from_new)

        {:noreply,
         socket
         |> assign(flow: flow, history: history)
         |> maybe_trigger_auto_layout()}
    end
  end

  @impl true
  def handle_event("add_root_node", _params, socket) do
    n = System.unique_integer([:positive])
    colors = ["#3b82f6", "#8b5cf6", "#ec4899", "#f59e0b", "#10b981", "#6366f1"]
    color = Enum.random(colors)

    initial_pos = new_root_position(socket.assigns.flow)

    node = Node.new("tree-#{n}", initial_pos,
      %{label: "Root #{n}", subtitle: "root node", color: color},
      type: :tree_node,
      handles: [Handle.target(:top), Handle.source(:bottom)]
    )

    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.add_node(socket.assigns.flow, node)

    {:noreply,
     socket
     |> assign(flow: flow, history: history)
     |> maybe_trigger_auto_layout()}
  end

  @impl true
  def handle_event("toggle_auto_layout", _params, socket) do
    {:noreply, assign(socket, auto_layout: !socket.assigns.auto_layout)}
  end

  @impl true
  def handle_event("toggle_direction", _params, socket) do
    direction = if socket.assigns.direction == "TB", do: "LR", else: "TB"

    {:noreply,
     socket
     |> assign(direction: direction)
     |> trigger_auto_layout()}
  end

  @impl true
  def handle_event("reset_flow", _params, socket) do
    flow = create_initial_tree()

    {:noreply,
     socket
     |> assign(flow: flow, history: History.new(), clipboard: Clipboard.new(), auto_layout_pending: true)
     |> trigger_auto_layout()}
  end

  @impl true
  def handle_event("fit_view", _params, socket) do
    {:noreply, push_event(socket, "lf:fit_view", %{padding: 0.1, duration: 200})}
  end

  # ===== Standard LiveFlow event handlers =====

  @impl true
  def handle_event("lf:node_change", %{"changes" => changes}, socket) do
    history =
      Enum.reduce(changes, socket.assigns.history, fn change, acc ->
        maybe_push_history_for_drag(acc, socket.assigns.flow, change)
      end)

    flow =
      Enum.reduce(changes, socket.assigns.flow, fn change, acc ->
        apply_node_change(acc, change)
      end)

    socket = assign(socket, flow: flow, history: history)

    has_dimension_changes = Enum.any?(changes, &(&1["type"] == "dimensions"))

    socket =
      cond do
        # First measurement after mount/reset — always layout
        socket.assigns.auto_layout_pending and has_measured_nodes?(flow) ->
          socket
          |> assign(auto_layout_pending: false)
          |> trigger_auto_layout()

        # New dimensions arrived (e.g. newly added node measured) — re-layout with correct sizes
        has_dimension_changes and socket.assigns.auto_layout ->
          trigger_auto_layout(socket)

        true ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("lf:connect_end", params, socket) do
    case Validation.Connection.validate_and_create(socket.assigns.flow, params) do
      {:ok, edge} ->
        edge = %{edge | data: %{insertable: true}}
        history = History.push(socket.assigns.history, socket.assigns.flow)
        flow = State.add_edge(socket.assigns.flow, edge)

        {:noreply,
         socket
         |> assign(flow: flow, history: history)
         |> maybe_trigger_auto_layout()}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:selection_change", %{"nodes" => node_ids, "edges" => edge_ids}, socket) do
    flow =
      socket.assigns.flow
      |> Map.put(:selected_nodes, MapSet.new(node_ids))
      |> Map.put(:selected_edges, MapSet.new(edge_ids))

    nodes =
      Enum.reduce(flow.nodes, %{}, fn {id, node}, acc ->
        Map.put(acc, id, %{node | selected: id in node_ids})
      end)

    edges =
      Enum.reduce(flow.edges, %{}, fn {id, edge}, acc ->
        Map.put(acc, id, %{edge | selected: id in edge_ids})
      end)

    flow = %{flow | nodes: nodes, edges: edges}
    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:delete_selected", _params, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.delete_selected(socket.assigns.flow)

    {:noreply,
     socket
     |> assign(flow: flow, history: history)
     |> maybe_trigger_auto_layout()}
  end

  @impl true
  def handle_event("lf:viewport_change", params, socket) do
    flow = State.update_viewport(socket.assigns.flow, params)
    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:edge_change", %{"changes" => changes}, socket) do
    has_removes = Enum.any?(changes, &(&1["type"] == "remove"))

    history =
      if has_removes,
        do: History.push(socket.assigns.history, socket.assigns.flow),
        else: socket.assigns.history

    flow =
      Enum.reduce(changes, socket.assigns.flow, fn
        %{"type" => "remove", "id" => id}, acc -> State.remove_edge(acc, id)
        _change, acc -> acc
      end)

    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("lf:edge_label_change", %{"id" => id, "label" => label}, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.update_edge(socket.assigns.flow, id, label: label)
    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("lf:copy", _params, socket) do
    clipboard = Clipboard.copy(socket.assigns.clipboard, socket.assigns.flow)
    {:noreply, assign(socket, clipboard: clipboard)}
  end

  @impl true
  def handle_event("lf:cut", _params, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    {clipboard, flow} = Clipboard.cut(socket.assigns.clipboard, socket.assigns.flow)
    {:noreply, assign(socket, flow: flow, clipboard: clipboard, history: history)}
  end

  @impl true
  def handle_event("lf:paste", _params, socket) do
    case Clipboard.paste(socket.assigns.clipboard, socket.assigns.flow) do
      {:ok, flow, clipboard} ->
        history = History.push(socket.assigns.history, socket.assigns.flow)
        {:noreply, assign(socket, flow: flow, clipboard: clipboard, history: history)}

      :empty ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:duplicate", _params, socket) do
    clipboard = Clipboard.copy(socket.assigns.clipboard, socket.assigns.flow)

    case Clipboard.paste(clipboard, socket.assigns.flow) do
      {:ok, flow, clipboard} ->
        history = History.push(socket.assigns.history, socket.assigns.flow)
        {:noreply, assign(socket, flow: flow, clipboard: clipboard, history: history)}

      :empty ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:undo", _params, socket) do
    case History.undo(socket.assigns.history, socket.assigns.flow) do
      {:ok, flow, history} ->
        {:noreply,
         socket
         |> assign(flow: flow, history: history)
         |> maybe_trigger_auto_layout()}

      :empty ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:redo", _params, socket) do
    case History.redo(socket.assigns.history, socket.assigns.flow) do
      {:ok, flow, history} ->
        {:noreply,
         socket
         |> assign(flow: flow, history: history)
         |> maybe_trigger_auto_layout()}

      :empty ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:request_layout", _params, socket) do
    {:noreply, trigger_auto_layout(socket)}
  end

  @impl true
  def handle_event("lf:" <> _event, _params, socket) do
    {:noreply, socket}
  end

  # ===== Private Helpers =====

  # Calculate initial position for a new child node below/right of its parent
  defp child_position(nil, _direction), do: %{x: 0, y: 0}

  defp child_position(parent, "LR") do
    %{
      x: parent.position.x + (parent.width || 150) + 100,
      y: parent.position.y
    }
  end

  defp child_position(parent, _direction) do
    %{
      x: parent.position.x,
      y: parent.position.y + (parent.height || 50) + 100
    }
  end

  # Calculate midpoint between source and target of an edge
  defp midpoint_position(flow, edge) do
    source = State.get_node(flow, edge.source)
    target = State.get_node(flow, edge.target)

    case {source, target} do
      {nil, nil} -> %{x: 0, y: 0}
      {nil, t} -> %{x: t.position.x, y: t.position.y}
      {s, nil} -> %{x: s.position.x, y: s.position.y}
      {s, t} ->
        %{
          x: (s.position.x + t.position.x) / 2,
          y: (s.position.y + t.position.y) / 2
        }
    end
  end

  # Calculate position for a new root node (to the right of existing nodes)
  defp new_root_position(flow) do
    if map_size(flow.nodes) == 0 do
      %{x: 0, y: 0}
    else
      max_x =
        flow.nodes
        |> Map.values()
        |> Enum.map(fn n -> n.position.x + (n.width || 150) end)
        |> Enum.max()

      %{x: max_x + 80, y: 0}
    end
  end

  defp maybe_trigger_auto_layout(socket) do
    if socket.assigns.auto_layout do
      trigger_auto_layout(socket)
    else
      socket
    end
  end

  defp trigger_auto_layout(socket) do
    data = Layout.prepare_tree_layout_data(
      socket.assigns.flow,
      %{"direction" => socket.assigns.direction}
    )
    push_event(socket, "lf:tree_layout_data", data)
  end

  defp has_measured_nodes?(flow) do
    flow.nodes
    |> Map.values()
    |> Enum.any?(& &1.measured)
  end

  defp apply_node_change(flow, %{"type" => "position", "id" => id, "position" => pos} = change) do
    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated = %{
          node
          | position: %{x: pos["x"] / 1, y: pos["y"] / 1},
            dragging: Map.get(change, "dragging", false)
        }

        %{flow | nodes: Map.put(flow.nodes, id, updated)}
    end
  end

  defp apply_node_change(flow, %{"type" => "dimensions", "id" => id} = change) do
    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated = %{node | width: Map.get(change, "width"), height: Map.get(change, "height"), measured: true}
        %{flow | nodes: Map.put(flow.nodes, id, updated)}
    end
  end

  defp apply_node_change(flow, %{"type" => "remove", "id" => id}) do
    State.remove_node(flow, id)
  end

  defp apply_node_change(flow, _change), do: flow

  defp maybe_push_history_for_drag(history, flow, %{"type" => "position", "id" => id} = change) do
    dragging = Map.get(change, "dragging", false)

    was_dragging =
      case Map.get(flow.nodes, id) do
        nil -> false
        node -> node.dragging
      end

    if dragging and not was_dragging do
      History.push(history, flow)
    else
      history
    end
  end

  defp maybe_push_history_for_drag(history, _flow, _change), do: history

  defp create_initial_tree do
    nodes = [
      # Root
      Node.new("project", %{x: 0, y: 0},
        %{label: "Project", subtitle: "root", color: "#6366f1"},
        type: :tree_node,
        handles: [Handle.source(:bottom)]
      ),
      # Level 1
      Node.new("design", %{x: 0, y: 0},
        %{label: "Design", subtitle: "team", color: "#ec4899"},
        type: :tree_node,
        handles: [Handle.target(:top), Handle.source(:bottom)]
      ),
      Node.new("engineering", %{x: 0, y: 0},
        %{label: "Engineering", subtitle: "team", color: "#3b82f6"},
        type: :tree_node,
        handles: [Handle.target(:top), Handle.source(:bottom)]
      ),
      Node.new("marketing", %{x: 0, y: 0},
        %{label: "Marketing", subtitle: "team", color: "#f59e0b"},
        type: :tree_node,
        handles: [Handle.target(:top), Handle.source(:bottom)]
      ),
      # Level 2
      Node.new("ux-ui", %{x: 0, y: 0},
        %{label: "UX/UI", subtitle: "design", color: "#ec4899"},
        type: :tree_node,
        handles: [Handle.target(:top), Handle.source(:bottom)]
      ),
      Node.new("frontend", %{x: 0, y: 0},
        %{label: "Frontend", subtitle: "engineering", color: "#3b82f6"},
        type: :tree_node,
        handles: [Handle.target(:top), Handle.source(:bottom)]
      ),
      Node.new("backend", %{x: 0, y: 0},
        %{label: "Backend", subtitle: "engineering", color: "#3b82f6"},
        type: :tree_node,
        handles: [Handle.target(:top), Handle.source(:bottom)]
      ),
      Node.new("seo", %{x: 0, y: 0},
        %{label: "SEO", subtitle: "marketing", color: "#f59e0b"},
        type: :tree_node,
        handles: [Handle.target(:top), Handle.source(:bottom)]
      ),
      # Placeholder
      Node.new("ph-seo", %{x: 0, y: 0}, %{},
        type: :placeholder,
        handles: [Handle.target(:top)],
        draggable: false
      )
    ]

    edges = [
      # Level 0 -> 1
      Edge.new("e-proj-design", "project", "design",
        marker_end: %{type: :arrow}, data: %{insertable: true}),
      Edge.new("e-proj-eng", "project", "engineering",
        marker_end: %{type: :arrow}, data: %{insertable: true}),
      Edge.new("e-proj-mkt", "project", "marketing",
        marker_end: %{type: :arrow}, data: %{insertable: true}),
      # Level 1 -> 2
      Edge.new("e-design-ux", "design", "ux-ui",
        marker_end: %{type: :arrow}, data: %{insertable: true}),
      Edge.new("e-eng-front", "engineering", "frontend",
        marker_end: %{type: :arrow}, data: %{insertable: true}),
      Edge.new("e-eng-back", "engineering", "backend",
        marker_end: %{type: :arrow}, data: %{insertable: true}),
      Edge.new("e-mkt-seo", "marketing", "seo",
        marker_end: %{type: :arrow}, data: %{insertable: true}),
      # Placeholder
      Edge.new("e-seo-ph", "seo", "ph-seo",
        marker_end: %{type: :arrow}, data: %{insertable: true})
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

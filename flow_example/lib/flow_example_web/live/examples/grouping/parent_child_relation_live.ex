defmodule FlowExampleWeb.Examples.Grouping.ParentChildRelationLive do
  @moduledoc """
  Parent Child Relation: attach and detach nodes from parent containers with
  drag and drop.

  While a node is dragged, `lf:drag_move` reports its absolute position every
  50ms; `State.intersecting_nodes/3` finds the group under the node's center
  and that group is highlighted. When the drag ends (`lf:node_change` with
  `dragging: false`) the node is attached to that group with
  `State.set_parent/4` (which keeps the absolute position), or detached with
  `set_parent(flow, id, nil)` when it was dropped outside of its parent.
  Children have no `extent`, so they can always be dragged out.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.Components.NodeResizer
  alias LiveFlow.{Edge, Node, State}

  @padding 12
  @header 34
  @colors ~w(#6366f1 #0ea5e9 #10b981 #f59e0b #ef4444 #ec4899 #8b5cf6)

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(dragging: MapSet.new(), hover: nil, next_id: 6)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :relations, relations(assigns.flow))

    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #parent-child-flow .lf-node[data-node-type="group"] {
        border-radius: 14px;
        border-width: 1.5px;
        transition:
          border-color 150ms ease,
          background-color 150ms ease,
          box-shadow 150ms ease;
      }
      #parent-child-flow .lf-node[data-node-type="group"].drop-target {
        border-style: solid;
        border-color: #10b981;
        background: color-mix(in oklab, #10b981 10%, transparent);
        box-shadow: 0 0 0 4px color-mix(in oklab, #10b981 18%, transparent);
      }
      #parent-child-flow .lf-node[data-node-type="group"].drop-leave {
        border-color: #f43f5e;
        background: color-mix(in oklab, #f43f5e 6%, transparent);
      }
      #parent-child-flow .lf-node[data-node-type="item"] {
        border-radius: 10px;
      }
      #parent-child-flow .lf-node[data-node-type="item"][data-parent-id] {
        border-color: color-mix(in oklab, var(--item-color) 55%, var(--lf-node-border));
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="add-item" icon="hero-plus" variant={:primary} phx-click="add_node">
          Add node
        </.action>
        <.action id="reset-relations" icon="hero-arrow-path" phx-click="reset">Reset</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="parent-child-flow"
        flow={decorate(@flow, @hover)}
        node_types={%{item: &item_node/1, group: &group_node/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            minimap: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.15},
            elevate_nodes_on_select: false,
            connection_line_type: :smoothstep
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Drag a node over a group: <code>lf:drag_move</code>
            sends its absolute position and <code>State.intersecting_nodes(flow, rect)</code>
            finds the group under its center, which turns green.
          </.hint>
          <.hint>
            On drop (<code>dragging: false</code>) the node becomes a child with <code>State.set_parent(flow, id, group_id)</code>: same place on screen, position now
            relative to the group, and it moves with it. Drag it out and drop it on the pane to
            detach it (<code>set_parent(flow, id, nil)</code>).
          </.hint>
        </.option_group>

        <.option_group title="Relations">
          <div id="relations" class="space-y-2">
            <div
              :for={{group, children} <- @relations.groups}
              id={"relation-#{group.id}"}
              class="rounded-lg border border-base-300 bg-base-200/40 px-2.5 py-2"
            >
              <p class="flex items-center gap-1.5 text-xs font-semibold">
                <.icon name="hero-rectangle-group-mini" class="size-4 text-base-content/50" />
                {group.data.label}
                <span class="ml-auto font-mono text-[10px] font-normal text-base-content/40">
                  {length(children)}
                </span>
              </p>
              <div class="mt-1.5 flex flex-wrap gap-1">
                <span :if={children == []} class="text-[11px] text-base-content/40">empty</span>
                <.chip :for={child <- children} node={child} />
              </div>
            </div>
            <div id="relation-loose" class="px-1 pt-1">
              <p class="text-[11px] font-semibold uppercase tracking-wider text-base-content/40">
                Without parent
              </p>
              <div class="mt-1.5 flex flex-wrap gap-1">
                <span :if={@relations.loose == []} class="text-[11px] text-base-content/40">none</span>
                <.chip :for={node <- @relations.loose} node={node} />
              </div>
            </div>
          </div>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp chip(assigns) do
    ~H"""
    <span class="inline-flex items-center gap-1 rounded-md bg-base-100 px-1.5 py-0.5 text-[11px] shadow-xs">
      <span class="size-1.5 rounded-full" style={"background: #{@node.data.color}"}></span>
      {@node.data.label}
    </span>
    """
  end

  # ===== Node renderers =====

  attr :node, :map, required: true

  defp item_node(assigns) do
    ~H"""
    <div class="flex w-24 items-center gap-2" style={"--item-color: #{@node.data.color}"}>
      <span class="size-2.5 shrink-0 rounded-full" style={"background: #{@node.data.color}"}></span>
      <span class="truncate text-[13px] font-semibold" style="color: var(--lf-text-primary)">
        {@node.data.label}
      </span>
    </div>
    """
  end

  attr :node, :map, required: true

  defp group_node(assigns) do
    ~H"""
    <NodeResizer.node_resizer
      node_id={@node.id}
      min_width={160}
      min_height={120}
      is_visible={@node.selected}
    />
    <div class="pointer-events-none absolute inset-x-3 top-2 flex items-center justify-between gap-2">
      <span class="text-[11px] font-semibold uppercase tracking-wider text-base-content/50">
        {@node.data.label}
      </span>
      <span
        :if={@node.data[:hint]}
        class={[
          "rounded-full px-2 py-px text-[10px] font-semibold",
          if(@node.data.hint == :attach,
            do: "bg-emerald-500/15 text-emerald-600",
            else: "bg-rose-500/15 text-rose-600"
          )
        ]}
      >
        {if @node.data.hint == :attach, do: "Drop to attach", else: "Drop to detach"}
      </span>
    </div>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("lf:drag_move", %{"changes" => changes}, socket) do
    flow = socket.assigns.flow

    hover =
      Enum.find_value(changes, fn
        %{"id" => id, "position" => %{"x" => x, "y" => y}} ->
          case State.get_node(flow, id) do
            %Node{type: :item} = node ->
              rect = %{x: x, y: y, width: node.width || 100, height: node.height || 40}
              %{node: id, parent: node.parent_id, target: drop_target(flow, id, rect)}

            _group_or_missing ->
              nil
          end

        _other ->
          nil
      end)

    {:noreply, assign(socket, :hover, hover)}
  end

  def handle_event("lf:node_change", %{"changes" => changes} = params, socket) do
    started = for %{"type" => "position", "dragging" => true, "id" => id} <- changes, do: id

    ended =
      for %{"type" => "position", "dragging" => false, "id" => id} <- changes,
          MapSet.member?(socket.assigns.dragging, id),
          do: id

    {:noreply, socket} = FlowEvents.handle_event("lf:node_change", params, socket)

    dragging =
      socket.assigns.dragging
      |> MapSet.union(MapSet.new(started))
      |> MapSet.difference(MapSet.new(ended))

    socket = assign(socket, dragging: dragging, hover: nil)
    {:noreply, Enum.reduce(ended, socket, &relink/2)}
  end

  def handle_event("add_node", _params, socket) do
    id = socket.assigns.next_id
    flow = socket.assigns.flow

    {x, y} =
      case State.bounds(flow) do
        nil ->
          {0, 0}

        bounds ->
          {bounds.x + rem(id * 130, max(round(bounds.width), 1)), bounds.y + bounds.height + 50}
      end

    node = item("n#{id}", x, y, "Node #{id}", Enum.at(@colors, rem(id, length(@colors))))

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(flow: State.add_node(flow, node), next_id: id + 1)
     |> FlowEvents.log("add_node", %{"id" => node.id})}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(flow: build_flow(), hover: nil, dragging: MapSet.new())
     |> FlowEvents.log("reset", %{})}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Relations =====

  # After a drop: attach the node to the group under it, or detach it
  defp relink(id, socket) do
    flow = socket.assigns.flow

    case State.get_node(flow, id) do
      %Node{type: :item, parent_id: parent} ->
        target = drop_target(flow, id, State.node_rect(flow, id))

        cond do
          target == parent ->
            socket

          is_nil(target) ->
            socket
            |> assign(:flow, State.set_parent(flow, id, nil))
            |> FlowEvents.log("detach", %{"node" => id, "from" => parent})

          true ->
            flow = flow |> State.set_parent(id, target) |> keep_inside(id, target)

            socket
            |> assign(:flow, flow)
            |> FlowEvents.log("attach", %{"node" => id, "to" => target})
        end

      _group_or_missing ->
        socket
    end
  end

  # The smallest group containing the center of `rect` (absolute coordinates)
  defp drop_target(flow, id, rect) do
    center = %{x: rect.x + rect.width / 2, y: rect.y + rect.height / 2, width: 1, height: 1}
    exclude = [id | State.descendant_ids(flow, id)]

    flow
    |> State.intersecting_nodes(center)
    |> Enum.filter(&(&1.type == :group and &1.id not in exclude))
    |> Enum.min_by(&((&1.width || 0) * (&1.height || 0)), fn -> nil end)
    |> case do
      %Node{id: group_id} -> group_id
      nil -> nil
    end
  end

  # Pulls a freshly attached node fully inside its new parent (below the title)
  defp keep_inside(flow, id, group_id) do
    group = State.get_node(flow, group_id)

    State.update_node(flow, id, fn node ->
      w = node.width || 100
      h = node.height || 40
      max_x = max((group.width || 0) - w - @padding, @padding)
      max_y = max((group.height || 0) - h - @padding, @header)

      %{
        node
        | position: %{
            x: node.position.x |> max(@padding) |> min(max_x),
            y: node.position.y |> max(@header) |> min(max_y)
          }
      }
    end)
  end

  defp relations(flow) do
    nodes = flow.nodes |> Map.values() |> Enum.sort_by(& &1.id)
    groups = Enum.filter(nodes, &(&1.type == :group))

    %{
      groups:
        Enum.map(groups, fn group -> {group, Enum.filter(nodes, &(&1.parent_id == group.id))} end),
      loose: Enum.filter(nodes, &(&1.type != :group and is_nil(&1.parent_id)))
    }
  end

  # Highlights the group under the dragged node (and the parent it would
  # leave) at render time only
  defp decorate(flow, nil), do: flow

  # Moving inside its own parent: nothing changes on drop
  defp decorate(flow, %{target: same, parent: same}), do: flow

  defp decorate(flow, %{target: target, parent: parent}) do
    flow
    |> mark(target, "drop-target", :attach)
    |> mark(parent, "drop-leave", :detach)
  end

  defp mark(flow, nil, _class, _hint), do: flow

  defp mark(flow, id, class, hint) do
    State.update_node(flow, id, fn node ->
      %{node | class: class, data: Map.put(node.data, :hint, hint)}
    end)
  end

  # ===== Initial graph (groups first: parents render below their children) =====

  defp item(id, x, y, label, color, opts \\ []) do
    Node.new(id, %{x: x, y: y}, %{label: label, color: color}, [type: :item, z_index: 1] ++ opts)
  end

  defp group_box(id, x, y, w, h, label) do
    Node.new(id, %{x: x, y: y}, %{label: label},
      type: :group,
      resizable: true,
      connectable: false,
      width: w,
      height: h
    )
  end

  defp build_flow do
    nodes = [
      group_box("group-a", 0, 0, 300, 240, "Group A"),
      group_box("group-b", 380, 0, 300, 240, "Group B"),
      group_box("group-c", 190, 320, 300, 180, "Group C"),
      item("n1", 30, 60, "Node 1", "#6366f1", parent_id: "group-a"),
      item("n2", 150, 150, "Node 2", "#0ea5e9", parent_id: "group-a"),
      item("n3", 40, 90, "Node 3", "#10b981", parent_id: "group-b"),
      item("n4", -220, 120, "Node 4", "#f59e0b"),
      item("n5", 760, 320, "Node 5", "#ef4444")
    ]

    edges = [
      Edge.new("n1-n2", "n1", "n2", type: :smoothstep),
      Edge.new("n2-n3", "n2", "n3", type: :smoothstep, animated: true),
      Edge.new("n4-n1", "n4", "n1", type: :smoothstep)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

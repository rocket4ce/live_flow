defmodule FlowExampleWeb.Examples.Grouping.SelectionGroupingLive do
  @moduledoc """
  Selection Grouping: group the selected nodes into a parent node, and
  ungroup them again.

  "Group" adds a `type: :group` node around the bounds of the selection
  (plus padding) and re-parents the selected nodes with
  `State.set_parent(flow, id, group_id, extent: :parent)`, which keeps their
  absolute position. "Ungroup" detaches the children (`set_parent(nil)`) and
  removes the group. Groups are resizable; when a resize (or a child drag)
  ends, the group grows again to fit all of its children.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.Components.{NodeResizer, NodeToolbar}
  alias LiveFlow.{Edge, Node, State}

  @padding 24
  @header 28
  @colors ~w(#6366f1 #0ea5e9 #10b981 #f59e0b #ef4444 #ec4899)

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(next_group: 1, dragging: MapSet.new())
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    groupable = groupable_ids(assigns.flow)

    assigns =
      assign(assigns,
        groupable: groupable,
        selected_groups: selected_groups(assigns.flow),
        group_count: Enum.count(assigns.flow.nodes, fn {_id, n} -> n.type == :group end)
      )

    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #selection-grouping-flow .lf-node[data-node-type="group"] {
        border-width: 1.5px;
        border-color: color-mix(in oklab, var(--lf-node-selected-border) 45%, var(--lf-node-border));
        background: color-mix(in oklab, var(--lf-node-selected-border) 5%, transparent);
        border-radius: 14px;
        animation: grouping-in 220ms cubic-bezier(0.2, 0.9, 0.3, 1.2);
      }
      #selection-grouping-flow .lf-node[data-node-type="group"][data-selected="true"] {
        border-style: solid;
        background: color-mix(in oklab, var(--lf-node-selected-border) 9%, transparent);
      }
      #selection-grouping-flow .lf-node[data-node-type="item"] {
        border-radius: 10px;
      }
      #selection-grouping-flow .grouping-toolbar button {
        display: inline-flex;
        align-items: center;
        gap: 4px;
        padding: 3px 8px;
        border-radius: 6px;
        font-size: 12px;
        font-weight: 600;
        color: var(--lf-text-primary);
        transition: background 120ms ease;
      }
      #selection-grouping-flow .grouping-toolbar button:hover {
        background: color-mix(in oklab, var(--lf-node-selected-border) 12%, transparent);
      }
      @keyframes grouping-in {
        from {
          opacity: 0;
          scale: 0.97;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action
          id="group-btn"
          icon="hero-rectangle-group"
          variant={:primary}
          phx-click="group"
          disabled={length(@groupable) < 2}
        >
          Group {if length(@groupable) >= 2, do: "#{length(@groupable)} nodes", else: "nodes"}
        </.action>
        <.action
          :if={@selected_groups != []}
          id="ungroup-btn"
          icon="hero-squares-2x2"
          phx-click="ungroup"
        >
          Ungroup
        </.action>
        <.action id="reset-grouping" icon="hero-arrow-path" phx-click="reset">Reset</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="selection-grouping-flow"
        flow={with_toolbar(@flow, @groupable)}
        node_types={%{item: &item_node/1, group: &group_node/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            minimap: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.2},
            elevate_nodes_on_select: false,
            connection_line_type: :smoothstep
          }
        }
      />

      <:sidebar>
        <.option_group title="Try it">
          <ol class="space-y-2 text-sm">
            <li :for={{step, text} <- steps()} class="flex gap-2.5">
              <span class="grid size-5 shrink-0 place-items-center rounded-full bg-primary/10 text-[11px] font-semibold text-primary">
                {step}
              </span>
              <span class="text-base-content/70">{text}</span>
            </li>
          </ol>
          <p class="pt-2 text-xs text-base-content/55">
            Selected: <b id="groupable-count">{length(@groupable)}</b>
            groupable · Groups: <b id="group-count">{@group_count}</b>
          </p>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            The group is added first, then every selected node is re-parented with <code>State.set_parent(flow, id, group_id, extent: :parent)</code>: the absolute position
            is kept and stored relative to the group, and the node can't leave it anymore.
          </.hint>
          <.hint>
            Ungrouping calls <code>set_parent(flow, id, nil)</code>
            for every child before removing the group (<code>remove_node</code>
            would delete the children too).
          </.hint>
          <.hint>
            When a resize or a child drag ends (<code>resizing: false</code>
            / <code>dragging: false</code>) the group grows back to fit its children.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  defp steps do
    [
      {1, "Select two or more nodes: shift-drag a box on the pane, or ⌘/shift-click them."},
      {2, "Click “Group” in the toolbar above the selection or in the header."},
      {3, "Drag the group to move everything, or resize it from its handles."},
      {4, "Select a group and click “Ungroup” to release the nodes."}
    ]
  end

  # ===== Node renderers =====

  attr :node, :map, required: true

  defp item_node(assigns) do
    ~H"""
    <NodeToolbar.node_toolbar
      :if={@node.data[:toolbar]}
      node={@node}
      is_visible
      position={:top}
      class="grouping-toolbar"
    >
      <button id="toolbar-group-btn" type="button" phx-click="group">
        <.icon name="hero-rectangle-group-mini" class="size-4" /> Group {@node.data.toolbar} nodes
      </button>
    </NodeToolbar.node_toolbar>
    <div class="flex w-28 items-center gap-2">
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
      min_width={120}
      min_height={80}
      is_visible={@node.selected}
    />
    <NodeToolbar.node_toolbar node={@node} position={:top} class="grouping-toolbar">
      <button id={"ungroup-#{@node.id}"} type="button" phx-click="ungroup" phx-value-group={@node.id}>
        <.icon name="hero-squares-2x2-mini" class="size-4" /> Ungroup
      </button>
    </NodeToolbar.node_toolbar>
    <span class="pointer-events-none absolute top-1.5 left-3 text-[11px] font-semibold uppercase tracking-wider text-base-content/50">
      {@node.data.label}
    </span>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("group", _params, socket) do
    flow = socket.assigns.flow

    case groupable_ids(flow) do
      [_, _ | _] = ids ->
        n = socket.assigns.next_group
        group_id = "group-#{n}"
        rect = rect_of(flow, ids)

        group =
          Node.new(
            group_id,
            %{x: rect.x - @padding, y: rect.y - @padding - @header},
            %{label: "Group #{n}"},
            type: :group,
            resizable: true,
            connectable: false,
            width: rect.width + @padding * 2,
            height: rect.height + @padding * 2 + @header
          )

        # The group must exist before re-parenting (positions become relative to it)
        flow =
          ids
          |> Enum.reduce(State.add_node(flow, group), fn id, acc ->
            State.set_parent(acc, id, group_id, extent: :parent)
          end)
          |> State.select_nodes([group_id])

        socket
        |> FlowEvents.snapshot()
        |> assign(flow: flow, next_group: n + 1)
        |> FlowEvents.log("group", %{"group" => group_id, "nodes" => ids})
        |> noreply()

      _fewer ->
        noreply(socket)
    end
  end

  def handle_event("ungroup", params, socket) do
    flow = socket.assigns.flow

    group_ids =
      case params do
        %{"group" => id} -> [id]
        _all_selected -> Enum.map(selected_groups(flow), & &1.id)
      end

    {flow, released} =
      Enum.reduce(group_ids, {flow, []}, fn group_id, {acc, released} ->
        children = Enum.map(State.children(acc, group_id), & &1.id)

        acc =
          children
          |> Enum.reduce(acc, &State.set_parent(&2, &1, nil))
          |> State.remove_node(group_id)

        {acc, released ++ children}
      end)

    socket
    |> FlowEvents.snapshot()
    |> assign(:flow, State.select_nodes(flow, released))
    |> FlowEvents.log("ungroup", %{"groups" => group_ids, "released" => released})
    |> noreply()
  end

  def handle_event("reset", _params, socket) do
    socket
    |> FlowEvents.snapshot()
    |> assign(:flow, build_flow())
    |> FlowEvents.log("reset", %{})
    |> noreply()
  end

  def handle_event("lf:node_change", %{"changes" => changes} = params, socket) do
    started = for %{"type" => "position", "dragging" => true, "id" => id} <- changes, do: id

    ended =
      for %{"type" => "position", "dragging" => false, "id" => id} <- changes,
          MapSet.member?(socket.assigns.dragging, id),
          do: id

    resized = for %{"type" => "resize", "resizing" => false, "id" => id} <- changes, do: id

    {:noreply, socket} = FlowEvents.handle_event("lf:node_change", params, socket)

    dragging =
      socket.assigns.dragging
      |> MapSet.union(MapSet.new(started))
      |> MapSet.difference(MapSet.new(ended))

    flow = socket.assigns.flow

    # Groups to refit: the parents of dropped children and resized groups
    to_fit =
      (Enum.map(ended, &parent_id(flow, &1)) ++ resized)
      |> Enum.filter(&group?(flow, &1))
      |> Enum.uniq()

    {fitted, grown} =
      Enum.reduce(to_fit, {flow, []}, fn group_id, {acc, grown} ->
        case fit_group(acc, group_id) do
          {:grown, acc} -> {acc, [group_id | grown]}
          :fits -> {acc, grown}
        end
      end)

    socket = assign(socket, flow: fitted, dragging: dragging)

    socket =
      if grown == [],
        do: socket,
        else: FlowEvents.log(socket, "fit_group", %{"groups" => grown})

    noreply(socket)
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Grouping helpers =====

  # Selected top-level nodes that aren't groups
  defp groupable_ids(flow) do
    flow
    |> State.selected_nodes_list()
    |> Enum.filter(&(&1.type != :group and is_nil(&1.parent_id)))
    |> Enum.sort_by(&{&1.position.y, &1.position.x})
    |> Enum.map(& &1.id)
  end

  defp selected_groups(flow) do
    flow |> State.selected_nodes_list() |> Enum.filter(&(&1.type == :group))
  end

  # Bounding box of the nodes (absolute), with LiveFlow's default size for
  # nodes that haven't been measured yet
  defp rect_of(flow, ids) do
    rects = Enum.map(ids, &State.node_rect(flow, &1))
    x1 = rects |> Enum.map(& &1.x) |> Enum.min()
    y1 = rects |> Enum.map(& &1.y) |> Enum.min()
    x2 = rects |> Enum.map(&(&1.x + &1.width)) |> Enum.max()
    y2 = rects |> Enum.map(&(&1.y + &1.height)) |> Enum.max()
    %{x: x1, y: y1, width: x2 - x1, height: y2 - y1}
  end

  # Grows a group so all of its children fit inside (with padding). Children
  # above/left of the padding shift the group's origin, and keep their
  # absolute position.
  defp fit_group(flow, group_id) do
    group = State.get_node(flow, group_id)
    children = State.children(flow, group_id)

    if children == [] do
      :fits
    else
      rects = Enum.map(children, &child_rect/1)
      dx = max(@padding - Enum.min(Enum.map(rects, & &1.x)), 0)
      dy = max(@padding + @header - Enum.min(Enum.map(rects, & &1.y)), 0)
      width = group.width || 0
      height = group.height || 0
      need_w = Enum.max(Enum.map(rects, &(&1.x + &1.width))) + dx + @padding
      need_h = Enum.max(Enum.map(rects, &(&1.y + &1.height))) + dy + @padding
      new_w = max(width + dx, need_w)
      new_h = max(height + dy, need_h)

      if dx == 0 and dy == 0 and new_w <= width and new_h <= height do
        :fits
      else
        flow =
          flow
          |> State.update_node(group_id, fn g ->
            %{
              g
              | position: %{x: g.position.x - dx, y: g.position.y - dy},
                width: new_w,
                height: new_h,
                measured: true
            }
          end)
          |> shift_children(children, dx, dy)

        {:grown, flow}
      end
    end
  end

  defp shift_children(flow, _children, 0, 0), do: flow

  defp shift_children(flow, children, dx, dy) do
    Enum.reduce(children, flow, fn child, acc ->
      State.update_node(acc, child.id, fn n ->
        %{n | position: %{x: n.position.x + dx, y: n.position.y + dy}}
      end)
    end)
  end

  # Child position is relative to the group
  defp child_rect(%Node{position: pos} = node) do
    %{x: pos.x, y: pos.y, width: node.width || 100, height: node.height || 40}
  end

  defp parent_id(flow, id) do
    case State.get_node(flow, id) do
      %Node{parent_id: parent_id} -> parent_id
      nil -> nil
    end
  end

  defp group?(_flow, nil), do: false
  defp group?(flow, id), do: match?(%Node{type: :group}, State.get_node(flow, id))

  # Shows the "Group" toolbar above the top-most selected node (render only)
  defp with_toolbar(flow, [_, _ | _] = ids) do
    State.update_node(flow, hd(ids), fn node ->
      %{node | data: Map.put(node.data, :toolbar, length(ids))}
    end)
  end

  defp with_toolbar(flow, _ids), do: flow

  defp noreply(socket), do: {:noreply, socket}

  # ===== Initial graph =====

  defp build_flow do
    item = fn {id, x, y}, i ->
      Node.new(id, %{x: x, y: y}, %{label: "Node #{id}", color: Enum.at(@colors, i)},
        type: :item,
        z_index: 1
      )
    end

    nodes =
      [
        {"A", 0, 0},
        {"B", 220, 60},
        {"C", 40, 150},
        {"D", 460, 0},
        {"E", 640, 110},
        {"F", 470, 220}
      ]
      |> Enum.with_index()
      |> Enum.map(fn {spec, i} -> item.(spec, i) end)

    edges = [
      Edge.new("a-b", "A", "B", type: :smoothstep),
      Edge.new("c-b", "C", "B", type: :smoothstep),
      Edge.new("b-d", "B", "D", type: :smoothstep, animated: true),
      Edge.new("d-e", "D", "E", type: :smoothstep),
      Edge.new("f-e", "F", "E", type: :smoothstep)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

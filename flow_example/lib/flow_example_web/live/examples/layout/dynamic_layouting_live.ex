defmodule FlowExampleWeb.Examples.Layout.DynamicLayoutingLive do
  @moduledoc """
  Dynamic Layouting (Pro): a self-organizing tree. Every node has a "+"
  placeholder child; clicking a placeholder turns it into a node, clicking a
  node adds a child, and the "+" on edges inserts a node in between. After
  every change the tree is laid out again (Elixir) and animated.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Layout, Node, State}

  @flow_id "dynamic-layout-flow"
  @icons ~w(hero-bolt hero-envelope hero-clock hero-funnel hero-globe-alt hero-chat-bubble-left hero-document-text hero-bell)

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)
    flow = State.new(nodes: [step_node("root", "Trigger", 0)]) |> sync_placeholders()
    flow = Layout.apply_positions(flow, layout(flow))

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, counter: 1)
     |> FlowEvents.assign_flow(flow)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #dynamic-layout-flow .lf-node[data-node-type="placeholder"] {
        background: transparent;
        border: 1.5px dashed var(--lf-node-border);
        box-shadow: none;
        cursor: pointer;
        transition: border-color 0.15s ease, background 0.15s ease;
      }
      #dynamic-layout-flow .lf-node[data-node-type="placeholder"]:hover {
        border-color: var(--lf-node-selected-border);
        background: color-mix(in oklab, var(--lf-node-selected-border) 6%, transparent);
      }
      #dynamic-layout-flow .lf-node[data-node-type="placeholder"] .lf-handle {
        opacity: 0;
      }
      #dynamic-layout-flow .lf-node[data-node-type="step"] {
        cursor: pointer;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action icon="hero-arrow-path" phx-click="reset">Reset</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="dynamic-layout-flow"
        flow={@flow}
        node_types={%{step: &step/1, placeholder: &placeholder/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            nodes_draggable: false,
            nodes_connectable: false
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Click a dashed <b>+</b> placeholder to turn it into a step, click a step to add a child,
            or use the <b>+</b> on an edge to insert a step in between.
          </.hint>
          <.hint>
            Node clicks arrive as <code phx-no-curly-interpolation>handle_info({:lf_node_click, id}, socket)</code>; edges have <code phx-no-curly-interpolation>data: %{insertable: true}</code>, which pushes <code>lf:insert_on_edge</code>.
          </.hint>
          <.hint>
            After each change, <code>Layout.tree/2</code>
            computes the new positions and <code>LiveFlow.animate_positions/5</code>
            moves the nodes there. New nodes start on top of their parent.
          </.hint>
        </.option_group>
        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp step(assigns) do
    ~H"""
    <div class="flex w-[150px] items-center gap-2.5">
      <span class="grid size-8 shrink-0 place-items-center rounded-lg bg-primary/12 text-primary">
        <.icon name={@node.data.icon} class="size-4" />
      </span>
      <div class="min-w-0">
        <p class="truncate text-[13px] font-semibold" style="color: var(--lf-text-primary)">
          {@node.data.label}
        </p>
        <p class="text-[11px]" style="color: var(--lf-text-secondary)">Click to add a child</p>
      </div>
    </div>
    """
  end

  attr :node, :map, required: true

  defp placeholder(assigns) do
    ~H"""
    <div
      class="grid h-[36px] w-[150px] place-items-center text-lg font-light"
      style="color: var(--lf-text-secondary)"
    >
      +
    </div>
    """
  end

  @impl true
  def handle_event("reset", _params, socket) do
    flow = State.new(nodes: [step_node("root", "Trigger", 0)]) |> sync_placeholders()
    flow = Layout.apply_positions(flow, layout(flow))
    send_update(LiveFlow.Components.Flow, id: @flow_id, fit_view: true)
    {:noreply, socket |> assign(counter: 1) |> FlowEvents.assign_flow(flow)}
  end

  def handle_event("lf:insert_on_edge", %{"edge_id" => edge_id} = params, socket) do
    flow = socket.assigns.flow

    case State.get_edge(flow, edge_id) do
      %Edge{source: source, target: target} ->
        {id, socket} = next_id(socket)
        parent = State.get_node(flow, source)

        node = %{
          step_node(id, "Step #{socket.assigns.counter}", socket.assigns.counter)
          | position: parent.position
        }

        flow
        |> State.remove_edge(edge_id)
        |> State.add_node(node)
        |> State.add_edge(step_edge(source, id))
        |> State.add_edge(step_edge(id, target))
        |> apply_change(socket, "lf:insert_on_edge", params)

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, id}, socket) do
    flow = socket.assigns.flow

    case State.get_node(flow, id) do
      # A placeholder becomes a real step (its placeholder child is added by sync)
      %Node{type: :placeholder} = node ->
        label = "Step #{socket.assigns.counter}"
        {_id, socket} = next_id(socket)

        flow
        |> State.update_node(id, fn _ ->
          %{step_node(id, label, socket.assigns.counter) | position: node.position}
        end)
        |> State.update_edge(edge_into(flow, id),
          data: %{insertable: true},
          style: %{},
          marker_end: %{type: :arrow_closed}
        )
        |> apply_change(socket, "convert_placeholder", %{"id" => id})

      %Node{type: :step} = parent ->
        {child_id, socket} = next_id(socket)

        child = %{
          step_node(child_id, "Step #{socket.assigns.counter}", socket.assigns.counter)
          | position: parent.position
        }

        flow
        |> State.add_node(child)
        |> State.add_edge(step_edge(id, child_id))
        |> apply_change(socket, "add_child", %{"parent" => id})

      nil ->
        {:noreply, socket}
    end
  end

  defp apply_change(flow, socket, event, params) do
    flow = sync_placeholders(flow)

    {:noreply,
     socket
     |> FlowEvents.log(event, params)
     |> assign(:flow, flow)
     |> LiveFlow.animate_positions(@flow_id, flow, layout(flow), duration: 400, fit_view: true)}
  end

  defp next_id(socket) do
    {"step-#{System.unique_integer([:positive])}", update(socket, :counter, &(&1 + 1))}
  end

  # Every step has exactly one placeholder child; placeholders of removed
  # steps are dropped
  defp sync_placeholders(flow) do
    steps = flow.nodes |> Map.values() |> Enum.filter(&(&1.type == :step))

    Enum.reduce(steps, flow, fn step, acc ->
      has_placeholder? = acc |> State.outgoers(step.id) |> Enum.any?(&(&1.type == :placeholder))

      if has_placeholder? do
        acc
      else
        id = "ph-#{step.id}-#{System.unique_integer([:positive])}"

        acc
        |> State.add_node(placeholder_node(id, step.position))
        |> State.add_edge(
          Edge.new("#{step.id}->#{id}", step.id, id,
            type: :smoothstep,
            style: %{"stroke-dasharray" => "4 4"},
            marker_end: %{type: :none}
          )
        )
      end
    end)
  end

  defp edge_into(flow, id) do
    flow.edges |> Map.values() |> Enum.find_value(fn e -> if e.target == id, do: e.id end)
  end

  defp layout(flow), do: Layout.tree(flow, node_spacing: 24, rank_spacing: 60)

  defp step_node(id, label, i) do
    Node.new(id, %{x: 0, y: 0}, %{label: label, icon: Enum.at(@icons, rem(i, length(@icons)))},
      type: :step,
      width: 180,
      height: 56,
      selectable: false,
      draggable: false,
      handles: [Handle.target(:top), Handle.source(:bottom)]
    )
  end

  defp placeholder_node(id, position) do
    Node.new(id, position, %{},
      type: :placeholder,
      width: 180,
      height: 56,
      selectable: false,
      draggable: false,
      deletable: false,
      handles: [Handle.target(:top)]
    )
  end

  defp step_edge(source, target) do
    Edge.new("#{source}->#{target}", source, target,
      type: :smoothstep,
      data: %{insertable: true},
      marker_end: %{type: :arrow_closed}
    )
  end
end

defmodule FlowExampleWeb.CustomNodesLive do
  @moduledoc """
  Custom node types: form fields inside nodes, drag handles, typed handles
  and interactive content.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.FlowEvents
  alias LiveFlow.{Edge, Handle, Node, State}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Custom nodes")
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      active={:custom_nodes}
      title="Custom nodes"
      subtitle="Nodes are plain function components. Inputs keep their native behaviour: typing Backspace inside a field never deletes the node."
    >
      <.canvas_layout>
        <.live_component
          module={LiveFlow.Components.Flow}
          id="custom-flow"
          flow={@flow}
          node_types={
            %{form: &form_node/1, grip: &grip_node/1, typed: &typed_node/1, counter: &counter_node/1}
          }
          opts={%{background: :cross, background_gap: 28, controls: true, fit_view_on_init: true}}
        />

        <:sidebar>
          <.option_group title="Form fields">
            <.hint>
              The <b>Message</b> node edits its own data through a regular <code>phx-change</code>.
              Keyboard shortcuts are ignored while a field has focus.
            </.hint>
          </.option_group>
          <.option_group title="Drag handle" tag="new">
            <.hint>
              <code>Node.new(..., drag_handle: ".grip")</code>
              — the <b>Grip</b>
              node can only be dragged from its handle bar, so its body can hold selectable text.
            </.hint>
          </.option_group>
          <.option_group title="Typed handles">
            <.hint>
              Handles with a <code>connect_type</code>
              only connect to the same type: try linking <span class="text-sky-600">number</span>
              to <span class="text-rose-600">text</span>. The handle turns red while hovering.
            </.hint>
          </.option_group>
          <.option_group title="Event log">
            <.event_log entries={@event_log} />
          </.option_group>
        </:sidebar>
      </.canvas_layout>
    </Layouts.app>
    """
  end

  attr :node, :map, required: true

  defp form_node(assigns) do
    ~H"""
    <form id={"message-form-#{@node.id}"} class="w-56 space-y-2" phx-change="update_message">
      <input type="hidden" name="node_id" value={@node.id} />
      <p class="text-[13px] font-semibold" style="color: var(--lf-text-primary)">Message</p>
      <input
        type="text"
        name="text"
        value={@node.data.text}
        phx-debounce="200"
        class="w-full rounded-md border border-base-300 bg-base-100 px-2 py-1 text-xs text-base-content focus:border-primary focus:outline-none"
      />
      <select
        name="channel"
        class="w-full rounded-md border border-base-300 bg-base-100 px-2 py-1 text-xs text-base-content"
      >
        <option :for={c <- ~w(email slack sms)} value={c} selected={c == @node.data.channel}>
          {c}
        </option>
      </select>
    </form>
    """
  end

  attr :node, :map, required: true

  defp grip_node(assigns) do
    ~H"""
    <div class="w-52">
      <div class="grip -mx-[15px] -mt-[10px] mb-2 flex cursor-grab items-center justify-center rounded-t-lg bg-primary/10 py-1 text-primary active:cursor-grabbing">
        <.icon name="hero-bars-2" class="size-4" />
      </div>
      <p class="cursor-text text-[12px] select-text" style="color: var(--lf-text-primary)">
        Only the bar above drags this node. Select this text freely.
      </p>
    </div>
    """
  end

  attr :node, :map, required: true

  defp typed_node(assigns) do
    ~H"""
    <div class="w-40">
      <p class="text-[13px] font-semibold" style="color: var(--lf-text-primary)">
        {@node.data.title}
      </p>
      <p :for={handle <- @node.handles} class="text-[11px]" style="color: var(--lf-text-secondary)">
        {handle.type}: <span class={type_color(handle.connect_type)}>{handle.connect_type}</span>
      </p>
    </div>
    """
  end

  attr :node, :map, required: true

  defp counter_node(assigns) do
    ~H"""
    <div class="flex w-44 items-center justify-between gap-2">
      <div>
        <p class="text-[13px] font-semibold" style="color: var(--lf-text-primary)">Counter</p>
        <p class="font-mono text-lg" style="color: var(--lf-text-primary)">{@node.data.count}</p>
      </div>
      <button
        type="button"
        phx-click="increment"
        phx-value-id={@node.id}
        class="grid size-8 place-items-center rounded-lg bg-primary text-primary-content transition-transform active:scale-90"
      >
        <.icon name="hero-plus" class="size-4" />
      </button>
    </div>
    """
  end

  defp type_color(:number), do: "text-sky-600"
  defp type_color(:text), do: "text-rose-600"
  defp type_color(_), do: nil

  @impl true
  def handle_event("update_message", %{"node_id" => id} = params, socket) do
    flow =
      State.update_node(socket.assigns.flow, id, fn node ->
        %{node | data: %{node.data | text: params["text"], channel: params["channel"]}}
      end)

    {:noreply, assign(socket, :flow, flow)}
  end

  def handle_event("increment", %{"id" => id}, socket) do
    flow =
      State.update_node(socket.assigns.flow, id, fn node ->
        %{node | data: %{node.data | count: node.data.count + 1}}
      end)

    {:noreply, assign(socket, :flow, flow)}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _node_id}, socket), do: {:noreply, socket}

  defp build_flow do
    nodes = [
      Node.new("message", %{x: 0, y: 40}, %{text: "Order shipped 📦", channel: "slack"},
        type: :form,
        handles: [Handle.source(:right)]
      ),
      Node.new("grip", %{x: 340, y: 0}, %{},
        type: :grip,
        drag_handle: ".grip",
        handles: [Handle.target(:left)]
      ),
      Node.new("counter", %{x: 340, y: 160}, %{count: 0},
        type: :counter,
        handles: [Handle.target(:left)]
      ),
      Node.new("number-out", %{x: 0, y: 300}, %{title: "Price"},
        type: :typed,
        handles: [Handle.source(:right, id: "out", connect_type: :number)]
      ),
      Node.new("number-in", %{x: 340, y: 300}, %{title: "Total"},
        type: :typed,
        handles: [Handle.target(:left, id: "in", connect_type: :number)]
      ),
      Node.new("text-in", %{x: 340, y: 420}, %{title: "Label"},
        type: :typed,
        handles: [Handle.target(:left, id: "in", connect_type: :text)]
      )
    ]

    edges = [
      Edge.new("message-grip", "message", "grip", type: :smoothstep, animated: true),
      Edge.new("price-total", "number-out", "number-in",
        source_handle: "out",
        target_handle: "in"
      )
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

defmodule FlowExampleWeb.Examples.Layout.ElkjsMultipleHandlesLive do
  @moduledoc """
  Elkjs Multiple Handles: nodes with several handles on the same side
  (`Handle.source(:right, offset: 0.25)`). `Layout.prepare_layout_data/2` sends
  handles as ELK ports, so ELK orders the nodes to avoid edge crossings.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Layout, Node, State}

  @flow_id "elk-handles-flow"

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    socket =
      socket
      |> assign(example: example, page_title: example.title)
      |> assign(form: to_form(%{"ports" => "true"}, as: :elk), ports: true)
      |> FlowEvents.assign_flow(build_flow())

    {:ok, if(connected?(socket), do: layout(socket), else: socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #elk-handles-flow .port-label {
        position: absolute;
        transform: translateY(-50%);
        font-size: 10px;
        font-family: ui-monospace, monospace;
        color: var(--lf-text-secondary);
        pointer-events: none;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action icon="hero-arrow-path" variant={:primary} phx-click="layout">Run ELK</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="elk-handles-flow"
        flow={@flow}
        node_types={%{ports: &ports_node/1}}
        opts={%{background: :dots, controls: true}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Nodes declare several handles per side with <code>offset</code>
            (0.0 = top, 1.0 = bottom); edges attach exactly to them.
          </.hint>
          <.hint>
            <code>Layout.prepare_layout_data/2</code>
            sends every handle as an ELK port on a fixed side and order, so ELK places the nodes
            to keep edges from crossing. Turn ports off to compare.
          </.hint>
        </.option_group>
        <.option_group title="Options">
          <.form for={@form} id="elk-handles-options" phx-change="options">
            <.input
              field={@form[:ports]}
              type="checkbox"
              label="Send handles as ports"
              class={switch_class()}
            />
          </.form>
        </.option_group>
        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp ports_node(assigns) do
    ~H"""
    <p class="text-center text-[13px] font-semibold" style="color: var(--lf-text-primary)">
      {@node.data.label}
    </p>
    <span
      :for={handle <- @node.handles}
      class="port-label"
      style={
        if(handle.position == :left,
          do: "left: 8px; top: #{(handle.offset || 0.5) * 100}%",
          else: "right: 8px; top: #{(handle.offset || 0.5) * 100}%"
        )
      }
    >
      {handle.id}
    </span>
    """
  end

  @impl true
  def handle_event("options", %{"elk" => params}, socket) do
    {:noreply,
     socket
     |> assign(form: to_form(params, as: :elk), ports: params["ports"] == "true")
     |> layout()}
  end

  def handle_event("layout", _params, socket), do: {:noreply, layout(socket)}

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp layout(socket) do
    data =
      Layout.prepare_layout_data(socket.assigns.flow, %{
        "flow_id" => @flow_id,
        "direction" => "RIGHT",
        "options" => %{
          "elk.spacing.nodeNode" => "40",
          "elk.layered.spacing.nodeNodeBetweenLayers" => "90"
        }
      })

    data =
      if socket.assigns.ports,
        do: data,
        else: %{data | nodes: Enum.map(data.nodes, &Map.put(&1, :ports, []))}

    push_event(socket, "lf:layout_data", data)
  end

  defp build_flow do
    node = fn id, label, inputs, outputs ->
      handles =
        spread(inputs, &Handle.target(:left, id: &1, offset: &2)) ++
          spread(outputs, &Handle.source(:right, id: &1, offset: &2))

      height = max(56, 30 * max(length(inputs), length(outputs)) + 16)

      Node.new(id, %{x: 0, y: 0}, %{label: label},
        type: :ports,
        handles: handles,
        style: %{"width" => "170px", "height" => "#{height}px"}
      )
    end

    nodes = [
      node.("users", "Users", [], ["out"]),
      node.("orders", "Orders", [], ["out"]),
      node.("products", "Products", [], ["out"]),
      node.("events", "Events", [], ["out"]),
      node.("join", "Join", ["a", "b", "c"], ["rows"]),
      node.("split", "Split", ["in", "stream"], ["hot", "warm", "cold"]),
      node.("ml", "ML features", ["in"], []),
      node.("warehouse", "Warehouse", ["in"], []),
      node.("dashboard", "Dashboard", ["in"], []),
      node.("alerts", "Alerts", ["in"], [])
    ]

    edge = fn source, source_handle, target, target_handle ->
      Edge.new("#{source}.#{source_handle}->#{target}.#{target_handle}", source, target,
        source_handle: source_handle,
        target_handle: target_handle,
        type: :smoothstep
      )
    end

    edges = [
      edge.("users", "out", "join", "c"),
      edge.("orders", "out", "join", "a"),
      edge.("products", "out", "join", "b"),
      edge.("join", "rows", "split", "in"),
      edge.("events", "out", "split", "stream"),
      edge.("split", "hot", "alerts", "in"),
      edge.("split", "warm", "dashboard", "in"),
      edge.("split", "cold", "warehouse", "in"),
      edge.("join", "rows", "ml", "in")
    ]

    State.new(nodes: nodes, edges: edges)
  end

  # Spreads handles evenly along a side
  defp spread(ids, fun) do
    count = length(ids)
    ids |> Enum.with_index() |> Enum.map(fn {id, i} -> fun.(id, (i + 1) / (count + 1)) end)
  end
end

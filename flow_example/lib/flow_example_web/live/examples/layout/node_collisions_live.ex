defmodule FlowExampleWeb.Examples.Layout.NodeCollisionsLive do
  @moduledoc """
  Node Collisions: when a drag ends, `LiveFlow.Layout.resolve_collisions/2`
  pushes overlapping nodes apart (the dropped node stays where it was put)
  and the result is animated.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Layout, Node, State}

  @flow_id "collisions-flow"
  @colors ~w(#6366f1 #0ea5e9 #10b981 #f59e0b #ef4444 #ec4899 #8b5cf6 #14b8a6)

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)
    params = %{"margin" => "12", "auto" => "true"}

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, dragging: MapSet.new())
     |> assign(params: params, form: to_form(params, as: :collisions))
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action icon="hero-squares-plus" phx-click="scatter">Scatter</.action>
        <.action icon="hero-sparkles" variant={:primary} phx-click="resolve">Resolve all</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="collisions-flow"
        flow={@flow}
        node_types={%{tile: &tile/1}}
        opts={%{background: :dots, controls: true, fit_view_on_init: true, nodes_connectable: false}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Drop a node on top of others: on <code>lf:node_change</code>
            with <code>dragging: false</code>
            the LiveView runs <code>Layout.resolve_collisions(flow, fixed: [id], margin: m)</code>
            and animates the nodes that moved.
          </.hint>
          <.hint>
            The algorithm repeatedly pushes overlapping pairs apart along the axis with the smallest
            overlap until nothing collides. Child nodes are only compared with their siblings.
          </.hint>
        </.option_group>

        <.option_group title="Options">
          <.form for={@form} id="collisions-options" phx-change="options">
            <.input
              field={@form[:auto]}
              type="checkbox"
              label="Resolve on drop"
              class={switch_class()}
            />
            <.range field={@form[:margin]} label="Margin" min="0" max="60" />
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

  defp tile(assigns) do
    ~H"""
    <div class="flex h-[40px] w-[110px] items-center gap-2">
      <span class="size-3 shrink-0 rounded-full" style={"background: #{@node.data.color}"}></span>
      <span class="text-[13px] font-semibold" style="color: var(--lf-text-primary)">{@node.data.label}</span>
    </div>
    """
  end

  @impl true
  def handle_event("options", %{"collisions" => params}, socket) do
    {:noreply, assign(socket, params: params, form: to_form(params, as: :collisions))}
  end

  def handle_event("scatter", _params, socket) do
    positions =
      Map.new(socket.assigns.flow.nodes, fn {id, _} ->
        {id, %{x: :rand.uniform(520) * 1.0, y: :rand.uniform(320) * 1.0}}
      end)

    {:noreply,
     socket
     |> FlowEvents.log("scatter", %{})
     |> LiveFlow.animate_positions(@flow_id, socket.assigns.flow, positions, duration: 400)}
  end

  def handle_event("resolve", _params, socket), do: {:noreply, resolve(socket, [])}

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

    socket = assign(socket, :dragging, dragging)

    if ended != [] and socket.assigns.params["auto"] == "true" do
      {:noreply, resolve(socket, ended)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp resolve(socket, fixed) do
    flow = socket.assigns.flow
    margin = String.to_integer(socket.assigns.params["margin"])
    positions = Layout.resolve_collisions(flow, fixed: fixed, margin: margin)

    socket
    |> FlowEvents.log("resolve_collisions", %{"moved" => map_size(positions)})
    |> LiveFlow.animate_positions(@flow_id, flow, positions, duration: 300)
  end

  defp build_flow do
    nodes =
      for i <- 0..19 do
        # A loose grid with some nodes overlapping their neighbours
        x = rem(i, 5) * 150 + if(rem(i, 3) == 0, do: 60, else: 0)
        y = div(i, 5) * 90 + if(rem(i, 4) == 0, do: 40, else: 0)

        Node.new(
          "n#{i}",
          %{x: x, y: y},
          %{label: "Node #{i + 1}", color: Enum.at(@colors, rem(i, 8))},
          type: :tile,
          width: 140,
          height: 60,
          connectable: false
        )
      end

    State.new(nodes: nodes)
  end
end

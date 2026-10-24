defmodule FlowExampleWeb.Examples.Layout.DagreLive do
  @moduledoc """
  Tree Layout (React Flow's dagre example): a layered layout computed in
  Elixir with `LiveFlow.Layout.tree/2`, switching between vertical and
  horizontal with an animated transition.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.Layout

  @flow_id "dagre-flow"

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)
    params = %{"node_spacing" => "30", "rank_spacing" => "70"}
    flow = Samples.hierarchy(:tb)
    flow = Layout.apply_positions(flow, layout(flow, :tb, params))

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(direction: :tb, params: params, form: to_form(params, as: :spacing))
     |> FlowEvents.assign_flow(flow)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action
          icon="hero-arrow-down"
          variant={if(@direction == :tb, do: :primary, else: :ghost)}
          phx-click="direction"
          phx-value-direction="tb"
        >
          Vertical
        </.action>
        <.action
          icon="hero-arrow-right"
          variant={if(@direction == :lr, do: :primary, else: :ghost)}
          phx-click="direction"
          phx-value-direction="lr"
        >
          Horizontal
        </.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="dagre-flow"
        flow={@flow}
        node_types={FlowNodes.types()}
        opts={%{background: :dots, controls: true, minimap: true, fit_view_on_init: true}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            <code>LiveFlow.Layout.tree(flow, direction: :tb)</code>
            ranks the nodes by their longest path from the root, orders each rank to reduce
            crossings and centers parents over their children. It runs in Elixir: no JavaScript
            layout library.
          </.hint>
          <.hint>
            Switching direction moves the handles (<code>top/bottom</code>
            vs <code>left/right</code>) and animates the nodes with <code>LiveFlow.animate_positions/5</code>.
          </.hint>
        </.option_group>

        <.option_group title="Spacing">
          <.form for={@form} id="dagre-spacing" phx-change="spacing">
            <.range field={@form[:node_spacing]} label="Node spacing" min="10" max="120" />
            <.range field={@form[:rank_spacing]} label="Rank spacing" min="30" max="200" />
          </.form>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  @impl true
  def handle_event("direction", %{"direction" => direction}, socket) do
    direction = if direction == "lr", do: :lr, else: :tb
    flow = Samples.set_direction(socket.assigns.flow, direction)

    {:noreply,
     socket
     |> assign(direction: direction, flow: flow)
     |> relayout()}
  end

  def handle_event("spacing", %{"spacing" => params}, socket) do
    {:noreply,
     socket
     |> assign(params: params, form: to_form(params, as: :spacing))
     |> relayout()}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp relayout(socket) do
    %{flow: flow, direction: direction, params: params} = socket.assigns

    LiveFlow.animate_positions(socket, @flow_id, flow, layout(flow, direction, params),
      duration: 500,
      fit_view: true
    )
  end

  defp layout(flow, direction, params) do
    Layout.tree(flow,
      direction: direction,
      node_spacing: String.to_integer(params["node_spacing"]),
      rank_spacing: String.to_integer(params["rank_spacing"])
    )
  end
end

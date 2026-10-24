defmodule FlowExampleWeb.Examples.Layout.ElkjsLive do
  @moduledoc """
  Elkjs Tree: the layout runs in the browser with ELK. ELK is optional in
  LiveFlow; this app added it with `mix live_flow.gen.elk`.
  The server sends the graph with `lf:layout_data`; the client measures the
  nodes, runs ELK and pushes the positions back as node changes.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.Layout

  @flow_id "elkjs-flow"

  @algorithms [
    {"Layered", "layered"},
    {"Mr. Tree", "mrtree"},
    {"Radial", "radial"},
    {"Force", "force"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)
    params = %{"direction" => "DOWN", "algorithm" => "layered", "spacing" => "60"}

    socket =
      socket
      |> assign(example: example, page_title: example.title, algorithms: @algorithms)
      |> assign(params: params, form: to_form(params, as: :elk))
      |> FlowEvents.assign_flow(Samples.hierarchy(:tb))

    # Nodes start stacked at the origin: lay them out as soon as the hook runs
    {:ok, if(connected?(socket), do: layout(socket), else: socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action icon="hero-arrow-path" variant={:primary} phx-click="layout">Run ELK</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="elkjs-flow"
        flow={@flow}
        node_types={FlowNodes.types()}
        opts={%{background: :dots, controls: true}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            ELK is optional (about 1.6 MB of JS). <code>mix live_flow.gen.elk</code>
            vendors elkjs in <code>assets/vendor/</code>
            and registers it in <code>app.js</code>
            with <code>registerElk(ELK)</code>.
          </.hint>
          <.hint>
            <code phx-no-curly-interpolation>push_event(socket, "lf:layout_data", Layout.prepare_layout_data(flow, %{"direction" => "RIGHT"}))</code>
          </.hint>
          <.hint>
            The browser runs ELK with the measured node sizes, pushes the new positions as
            <code>lf:node_change</code>
            and fits the view. Any ELK option can be passed through <code>"options"</code>.
          </.hint>
        </.option_group>

        <.option_group title="ELK options">
          <.form for={@form} id="elk-options" phx-change="options">
            <.input
              field={@form[:algorithm]}
              type="select"
              label="Algorithm"
              class={select_class()}
              options={@algorithms}
            />
            <.input
              field={@form[:direction]}
              type="select"
              label="Direction"
              class={select_class()}
              options={[{"Down", "DOWN"}, {"Right", "RIGHT"}]}
            />
            <.range field={@form[:spacing]} label="Node spacing" min="20" max="160" />
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
  def handle_event("options", %{"elk" => params}, socket) do
    {:noreply, socket |> assign(params: params, form: to_form(params, as: :elk)) |> layout()}
  end

  def handle_event("layout", _params, socket), do: {:noreply, layout(socket)}

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp layout(socket) do
    %{params: params, flow: flow} = socket.assigns
    direction = if params["direction"] == "RIGHT", do: :lr, else: :tb
    flow = Samples.set_direction(flow, direction)

    data =
      Layout.prepare_layout_data(flow, %{
        "flow_id" => @flow_id,
        "direction" => params["direction"],
        "options" => %{
          "elk.algorithm" => params["algorithm"],
          "elk.spacing.nodeNode" => params["spacing"],
          "elk.layered.spacing.nodeNodeBetweenLayers" => params["spacing"]
        }
      })

    socket
    |> assign(:flow, flow)
    |> push_event("lf:layout_data", data)
  end
end

defmodule FlowExampleWeb.Examples.Edges.MultiConnectionLineLive do
  @moduledoc """
  Multi Connection Line: connect several nodes at once.

  With `multi_connection: true`, dragging a connection from a selected node
  draws a connection line from every selected node. Dropping it on a handle
  pushes one `lf:connect_end` per selected node, so the regular connect
  handler creates one edge for each of them.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.State

  @sources ~w(sensor-a sensor-b sensor-c sensor-d)

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> FlowEvents.assign_flow(build_flow())
     |> assign(:edge_opts,
       type: :smoothstep,
       path_options: %{border_radius: 10},
       marker_end: %{type: :arrow_closed}
     )}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        selected_count: MapSet.size(assigns.flow.selected_nodes),
        edge_count: map_size(assigns.flow.edges)
      )

    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="select-sources" icon="hero-cursor-arrow-rays" phx-click="select_sources">
          Select all sensors
        </.action>
        <.action
          id="clear-edges"
          icon="hero-trash"
          phx-click="clear_edges"
          disabled={@edge_count == 0}
        >
          Clear edges
        </.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="multi-connection-flow"
        flow={@flow}
        node_types={FlowNodes.types()}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.25},
            multi_connection: true,
            connection_line_type: :smoothstep,
            connection_line_style: %{stroke: "#6366f1", "stroke-width": 2}
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            1. Select several sensors:
            <.kbd>Shift</.kbd>
            + click them, or hold
            <.kbd>Shift</.kbd>
            and drag a selection box. Two are already selected.
          </.hint>
          <.hint>
            2. Drag a connection from the handle of one of the selected nodes: a line follows the
            pointer from <b>every</b> selected node.
          </.hint>
          <.hint>
            3. Drop it on the <b>Aggregator</b>
            or <b>Archive</b>
            handle. The client pushes one <code>lf:connect_end</code>
            per selected node, each one becomes its own edge.
          </.hint>
          <.hint>
            Enabled with <code>opts={"{%{multi_connection: true}}"}</code>.
          </.hint>
        </.option_group>

        <.option_group title="State">
          <div class="grid grid-cols-2 gap-2">
            <div class="rounded-lg bg-base-200/70 px-3 py-2">
              <p class="text-[11px] text-base-content/50">Selected nodes</p>
              <p id="selected-count" class="font-mono text-lg font-semibold">{@selected_count}</p>
            </div>
            <div class="rounded-lg bg-base-200/70 px-3 py-2">
              <p class="text-[11px] text-base-content/50">Edges</p>
              <p id="edge-count" class="font-mono text-lg font-semibold">{@edge_count}</p>
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

  @impl true
  def handle_event("select_sources", _params, socket) do
    {:noreply, update(socket, :flow, &State.select_nodes(&1, @sources))}
  end

  def handle_event("clear_edges", _params, socket) do
    socket = FlowEvents.snapshot(socket)
    flow = socket.assigns.flow
    {:noreply, assign(socket, :flow, State.remove_edges(flow, Map.keys(flow.edges)))}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp build_flow do
    nodes = [
      Samples.card("sensor-a", 0, 0, "Sensor A", "temperature", "hero-fire", :rose,
        inputs: false
      ),
      Samples.card("sensor-b", 0, 110, "Sensor B", "humidity", "hero-cloud", :sky, inputs: false),
      Samples.card("sensor-c", 0, 220, "Sensor C", "pressure", "hero-arrow-down-circle", :amber,
        inputs: false
      ),
      Samples.card("sensor-d", 0, 330, "Sensor D", "wind speed", "hero-arrow-path", :emerald,
        inputs: false
      ),
      Samples.card("aggregator", 480, 70, "Aggregator", "merges readings", "hero-funnel", :violet,
        outputs: false
      ),
      Samples.card("archive", 480, 270, "Archive", "cold storage", "hero-archive-box", :slate,
        outputs: false
      )
    ]

    [nodes: nodes, edges: []]
    |> State.new()
    |> State.select_nodes(["sensor-a", "sensor-b"])
  end
end

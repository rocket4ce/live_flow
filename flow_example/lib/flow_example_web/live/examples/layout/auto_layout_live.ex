defmodule FlowExampleWeb.Examples.Layout.AutoLayoutLive do
  @moduledoc """
  Auto Layout (Pro): whenever nodes or edges are added or removed, the graph
  is laid out again (tree or force, computed in Elixir) and animated.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, Layout, Node, State}

  @flow_id "auto-layout-flow"

  @names ~w(Ada Grace Alan Linus Margaret Edsger Barbara Ken Dennis Radia Joe José Chris Sasha Leslie)

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)
    params = %{"algorithm" => "tree_tb", "spacing" => "40"}

    flow = Samples.hierarchy(:tb)
    flow = Layout.apply_positions(flow, positions(flow, params))

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(params: params, form: to_form(params, as: :layout))
     |> FlowEvents.assign_flow(flow)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action
          icon="hero-plus"
          variant={:primary}
          phx-click="add_child"
          disabled={MapSet.size(@flow.selected_nodes) == 0}
        >
          Add child
        </.action>
        <.action icon="hero-sparkles" phx-click="add_random">Add random node</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="auto-layout-flow"
        flow={@flow}
        node_types={FlowNodes.types()}
        opts={%{background: :dots, controls: true, minimap: true, fit_view_on_init: true}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Every <code>lf:*</code>
            event is handled as usual; when it changed the set of nodes or edges (connect,
            delete, paste, the buttons above), the graph is laid out again and animated with <code>LiveFlow.animate_positions/5</code>.
          </.hint>
          <.hint>
            Select a node and press <b>Add child</b>, connect two nodes, or delete with
            <.kbd>⌫</.kbd>
            to see it re-arrange.
          </.hint>
        </.option_group>

        <.option_group title="Layout">
          <.form for={@form} id="auto-layout-options" phx-change="options">
            <.input
              field={@form[:algorithm]}
              type="select"
              label="Algorithm"
              class={select_class()}
              options={[
                {"Tree, top to bottom", "tree_tb"},
                {"Tree, left to right", "tree_lr"},
                {"Force directed", "force"}
              ]}
            />
            <.range field={@form[:spacing]} label="Spacing" min="16" max="120" />
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
  def handle_event("options", %{"layout" => params}, socket) do
    flow = Samples.set_direction(socket.assigns.flow, direction(params))

    {:noreply,
     socket
     |> assign(params: params, form: to_form(params, as: :layout), flow: flow)
     |> relayout()}
  end

  def handle_event("add_child", _params, socket) do
    parents = MapSet.to_list(socket.assigns.flow.selected_nodes)
    {:noreply, Enum.reduce(parents, FlowEvents.snapshot(socket), &add_node(&2, &1)) |> relayout()}
  end

  def handle_event("add_random", _params, socket) do
    parent = socket.assigns.flow.nodes |> Map.keys() |> Enum.random()
    {:noreply, socket |> FlowEvents.snapshot() |> add_node(parent) |> relayout()}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    before = structure(socket.assigns.flow)
    {:noreply, socket} = FlowEvents.handle_event(event, params, socket)

    if structure(socket.assigns.flow) != before do
      {:noreply, relayout(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp structure(flow), do: {Map.keys(flow.nodes), Map.keys(flow.edges)}

  # New nodes start on top of their parent so they slide out of it
  defp add_node(socket, parent_id) do
    flow = socket.assigns.flow
    parent = State.get_node(flow, parent_id)
    id = "n#{System.unique_integer([:positive])}"
    name = Enum.random(@names)

    node =
      Node.new(id, parent.position, %{label: name, subtitle: "Joined just now"},
        type: :person,
        width: 180,
        height: 56,
        handles: parent.handles
      )

    edge =
      Edge.new("#{parent_id}->#{id}", parent_id, id,
        type: :smoothstep,
        marker_end: %{type: :arrow_closed}
      )

    socket
    |> assign(:flow, flow |> State.add_node(node) |> State.add_edge(edge))
    |> FlowEvents.log("add_node", %{"id" => id, "parent" => parent_id})
  end

  defp relayout(socket) do
    %{flow: flow, params: params} = socket.assigns

    LiveFlow.animate_positions(socket, @flow_id, flow, positions(flow, params),
      duration: 450,
      fit_view: true
    )
  end

  defp positions(flow, %{"algorithm" => "force"} = params) do
    Layout.force(flow, iterations: 250, distance: String.to_integer(params["spacing"]) * 5)
  end

  defp positions(flow, params) do
    spacing = String.to_integer(params["spacing"])

    Layout.tree(flow,
      direction: direction(params),
      node_spacing: spacing,
      rank_spacing: spacing * 2
    )
  end

  defp direction(%{"algorithm" => "tree_lr"}), do: :lr
  defp direction(_), do: :tb
end

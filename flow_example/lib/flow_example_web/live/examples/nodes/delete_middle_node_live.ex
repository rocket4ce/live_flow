defmodule FlowExampleWeb.Examples.Nodes.DeleteMiddleNodeLive do
  @moduledoc """
  Delete Middle Node: deleting a node reconnects every node that pointed to
  it with every node it pointed to, so the flow never breaks.

  Built on `LiveFlow.State.incomers/2` and `LiveFlow.State.outgoers/2`.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}
  alias LiveFlow.Changes.NodeChange

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #delete-middle-node .lf-edge-group.is-bridge .lf-edge:not([data-selected="true"]) {
        stroke: var(--lf-node-selected-border);
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="delete-middle-reset" icon="hero-arrow-path" phx-click="reset">Reset</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="delete-middle-node"
        flow={@flow}
        opts={%{background: :dots, controls: true, fit_view_on_init: true}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Select a node and press
            <.kbd>Backspace</.kbd>
            (or use its delete button). Instead of leaving a gap, every <b>incomer</b>
            of the deleted node is connected to every <b>outgoer</b>.
          </.hint>
          <.hint>
            The LiveView intercepts <code>lf:delete_selected</code>
            and node <code>"remove"</code>
            changes, computes <code>State.incomers/2</code>
            × <code>State.outgoers/2</code>
            before removing the node, and adds the missing edges (duplicates are skipped).
          </.hint>
          <.hint>
            Deleting several nodes at once works too: they are removed one by one. New edges are
            highlighted.
          </.hint>
        </.option_group>
        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  @impl true
  def handle_event("lf:delete_selected", params, socket) do
    flow = socket.assigns.flow
    node_ids = MapSet.to_list(flow.selected_nodes)
    edge_ids = MapSet.to_list(flow.selected_edges)

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, flow |> delete_and_bridge(node_ids) |> State.remove_edges(edge_ids))
     |> FlowEvents.log("lf:delete_selected", params)}
  end

  def handle_event("lf:node_change", %{"changes" => changes} = params, socket) do
    case Enum.split_with(changes, &match?(%{"type" => "remove"}, &1)) do
      {[], _changes} ->
        FlowEvents.handle_event("lf:node_change", params, socket)

      {removals, other_changes} ->
        node_ids = Enum.map(removals, & &1["id"])

        flow =
          socket.assigns.flow
          |> NodeChange.apply_changes(other_changes)
          |> delete_and_bridge(node_ids)

        {:noreply,
         socket
         |> FlowEvents.snapshot()
         |> assign(:flow, flow)
         |> FlowEvents.log("lf:node_change", params)}
    end
  end

  def handle_event("reset", _params, socket) do
    {:noreply, FlowEvents.assign_flow(socket, build_flow())}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # Removes the nodes one by one, so deleting a chain (3 and 4 together)
  # still connects what was before the chain to what was after it.
  defp delete_and_bridge(flow, node_ids) do
    Enum.reduce(node_ids, flow, fn id, acc ->
      if State.get_node(acc, id) do
        bridges =
          for %Node{id: source} <- State.incomers(acc, id),
              %Node{id: target} <- State.outgoers(acc, id),
              source != target,
              do: {source, target}

        acc = State.remove_node(acc, id)

        Enum.reduce(bridges, acc, fn {source, target}, acc ->
          if State.edge_exists?(acc, source, target) do
            acc
          else
            State.add_edge(
              acc,
              Edge.new("#{source}->#{target}", source, target, animated: true, class: "is-bridge")
            )
          end
        end)
      else
        acc
      end
    end)
  end

  defp build_flow do
    node = fn id, x, y, label, handles ->
      Node.new(id, %{x: x, y: y}, %{label: label},
        handles: handles,
        style: %{"width" => "150px"}
      )
    end

    input = [Handle.source(:bottom)]
    middle = [Handle.target(:top), Handle.source(:bottom)]
    output = [Handle.target(:top)]

    nodes = [
      node.("1", -150, 0, "Start here...", input),
      node.("2", 150, 0, "...or here!", input),
      node.("3", 0, 110, "Delete me.", middle),
      node.("4", 0, 220, "Then me!", middle),
      node.("5", 0, 330, "End here!", output)
    ]

    edges = [
      Edge.new("1->3", "1", "3"),
      Edge.new("2->3", "2", "3"),
      Edge.new("3->4", "3", "4"),
      Edge.new("4->5", "4", "5")
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

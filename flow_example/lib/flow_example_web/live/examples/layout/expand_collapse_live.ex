defmodule FlowExampleWeb.Examples.Layout.ExpandCollapseLive do
  @moduledoc """
  Expand and Collapse (Pro): clicking the badge of a node hides or shows its
  subtree; the visible tree is laid out again with `LiveFlow.Layout.tree/2`
  and animated. Expanded children grow out of their parent.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Layout, State}

  @flow_id "expand-collapse-flow"

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    flow =
      Samples.hierarchy(:tb)
      |> then(fn flow ->
        %{flow | nodes: Map.new(flow.nodes, fn {id, n} -> {id, %{n | type: :collapsible}} end)}
      end)

    # Start with the second level collapsed
    flow = Enum.reduce(~w(cto cfo coo), flow, &set_collapsed(&2, &1, true))
    flow = Layout.apply_positions(flow, layout(flow))

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> FlowEvents.assign_flow(flow)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action icon="hero-arrows-pointing-out" phx-click="expand_all">Expand all</.action>
        <.action icon="hero-arrows-pointing-in" phx-click="collapse_all">Collapse all</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="expand-collapse-flow"
        flow={@flow}
        node_types={%{collapsible: &collapsible_node/1}}
        opts={%{background: :dots, controls: true, fit_view_on_init: true}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Click the <.kbd>+</.kbd>/<.kbd>−</.kbd>
            badge of a node. Its descendants (found with <code>State.outgoers/2</code>) get <code>hidden: true</code>, and their edges disappear with them.
          </.hint>
          <.hint>
            The visible nodes are laid out again with
            <code>Layout.tree(flow, nodes: visible_ids)</code>
            and animated with <code>LiveFlow.animate_positions/5</code>. Expanded nodes start at their
            parent's position, so they grow out of it.
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

  defp collapsible_node(assigns) do
    ~H"""
    <FlowNodes.person node={@node} />
    <button
      :if={@node.data[:children] > 0}
      type="button"
      phx-click="toggle"
      phx-value-id={@node.id}
      class={[
        "absolute -bottom-3 left-1/2 flex h-6 min-w-6 -translate-x-1/2 items-center justify-center gap-0.5 rounded-full border px-1.5 text-[11px] font-semibold shadow-sm transition-all hover:scale-110",
        if(@node.data[:collapsed],
          do: "border-primary bg-primary text-primary-content",
          else: "border-base-300 bg-base-100 text-base-content/70"
        )
      ]}
      title={if(@node.data[:collapsed], do: "Expand", else: "Collapse")}
    >
      <span>{if(@node.data[:collapsed], do: "+", else: "−")}</span>
      <span :if={@node.data[:collapsed]}>{@node.data[:hidden_count]}</span>
    </button>
    """
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    node = State.get_node(socket.assigns.flow, id)
    {:noreply, update_tree(socket, &set_collapsed(&1, id, node.data[:collapsed] != true))}
  end

  def handle_event("expand_all", _params, socket) do
    {:noreply,
     update_tree(socket, fn flow ->
       Enum.reduce(Map.keys(flow.nodes), flow, &set_collapsed(&2, &1, false))
     end)}
  end

  def handle_event("collapse_all", _params, socket) do
    {:noreply, update_tree(socket, &set_collapsed(&1, "ceo", true))}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp update_tree(socket, fun) do
    before = socket.assigns.flow
    flow = fun.(before)

    # Nodes that become visible start at their parent's position
    flow =
      Enum.reduce(flow.nodes, flow, fn {id, node}, acc ->
        if before.nodes[id].hidden and not node.hidden do
          parent = acc |> State.incomers(id) |> List.first()

          State.update_node(acc, id, fn n ->
            %{n | position: (parent && parent.position) || n.position}
          end)
        else
          acc
        end
      end)

    socket
    |> FlowEvents.log("toggle", %{})
    |> assign(:flow, flow)
    |> LiveFlow.animate_positions(@flow_id, flow, layout(flow), duration: 450, fit_view: true)
  end

  defp layout(flow) do
    visible = flow.nodes |> Map.values() |> Enum.reject(& &1.hidden) |> Enum.map(& &1.id)
    Layout.tree(flow, nodes: visible, node_spacing: 30, rank_spacing: 70)
  end

  # Collapsing hides every descendant; expanding shows them back, except the
  # subtrees of nodes that are still collapsed.
  defp set_collapsed(flow, id, collapsed) do
    flow =
      State.update_node(flow, id, fn n -> %{n | data: Map.put(n.data, :collapsed, collapsed)} end)

    flow = refresh_visibility(flow, "ceo", false)
    annotate(flow)
  end

  defp refresh_visibility(flow, id, hidden) do
    flow = State.update_node(flow, id, hidden: hidden)
    node = State.get_node(flow, id)
    hide_children = hidden or node.data[:collapsed] == true

    flow
    |> State.outgoers(id)
    |> Enum.reduce(flow, &refresh_visibility(&2, &1.id, hide_children))
  end

  # Children count and number of hidden descendants for the badges
  defp annotate(flow) do
    Enum.reduce(flow.nodes, flow, fn {id, _node}, acc ->
      children = State.outgoers(acc, id)
      hidden_count = acc |> descendants(id) |> Enum.count(& &1.hidden)

      State.update_node(acc, id, fn n ->
        %{n | data: Map.merge(n.data, %{children: length(children), hidden_count: hidden_count})}
      end)
    end)
  end

  defp descendants(flow, id) do
    children = State.outgoers(flow, id)
    children ++ Enum.flat_map(children, &descendants(flow, &1.id))
  end
end

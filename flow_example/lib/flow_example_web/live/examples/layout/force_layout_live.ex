defmodule FlowExampleWeb.Examples.Layout.ForceLayoutLive do
  @moduledoc """
  Force Layout (Pro): a force-directed layout computed in Elixir with
  `LiveFlow.Layout.force/2`. New nodes never overlap the existing ones and,
  after a drag, the graph settles around the dragged node (kept `fixed:`).
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Layout, Node, State}

  @flow_id "force-layout-flow"
  @colors ~w(#6366f1 #0ea5e9 #10b981 #f59e0b #ef4444 #ec4899 #8b5cf6)

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)
    params = %{"iterations" => "250", "distance" => "160"}
    flow = build_flow()
    flow = Layout.apply_positions(flow, layout(flow, params, []))

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(params: params, form: to_form(params, as: :force), dragging: MapSet.new())
     |> FlowEvents.assign_flow(flow)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #force-layout-flow .lf-node[data-node-type="bubble"] {
        border-radius: 9999px;
        padding: 0;
      }
      #force-layout-flow .lf-node[data-node-type="bubble"] .lf-node-content {
        padding: 0;
        min-width: 0;
      }
      #force-layout-flow .lf-node[data-node-type="bubble"] .lf-handle {
        opacity: 0;
      }
      #force-layout-flow .lf-node[data-node-type="bubble"]:hover .lf-handle {
        opacity: 1;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action icon="hero-plus" variant={:primary} phx-click="add_node">Add node</.action>
        <.action icon="hero-arrow-path" phx-click="shake">Shake</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="force-layout-flow"
        flow={@flow}
        node_types={%{bubble: &bubble/1}}
        edge_opts={[type: :straight]}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            connection_line_type: :straight,
            connection_mode: :loose
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            <code>LiveFlow.Layout.force/2</code>
            simulates repulsion between every pair of nodes and springs along the edges
            (Fruchterman–Reingold). It's deterministic and starts from the current positions.
          </.hint>
          <.hint>
            Drag a node: when you drop it the others settle around it, because it's passed as <code>fixed: [id]</code>.
            <b>Add node</b>
            connects a new node to the selected (or a random)
            node without overlapping anything.
          </.hint>
        </.option_group>

        <.option_group title="Simulation">
          <.form for={@form} id="force-options" phx-change="options">
            <.range field={@form[:iterations]} label="Iterations" min="20" max="600" step="10" />
            <.range field={@form[:distance]} label="Edge length" min="80" max="320" step="10" />
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

  defp bubble(assigns) do
    ~H"""
    <div
      class="grid size-16 place-items-center rounded-full text-sm font-semibold text-white shadow-inner"
      style={"background: #{@node.data.color}"}
    >
      {@node.data.label}
    </div>
    """
  end

  @impl true
  def handle_event("options", %{"force" => params}, socket) do
    {:noreply,
     socket |> assign(params: params, form: to_form(params, as: :force)) |> relayout([])}
  end

  def handle_event("add_node", _params, socket) do
    flow = socket.assigns.flow

    anchor =
      case MapSet.to_list(flow.selected_nodes) do
        [id | _] -> id
        [] -> flow.nodes |> Map.keys() |> Enum.random()
      end

    id = "n#{map_size(flow.nodes) + 1}-#{System.unique_integer([:positive])}"
    pos = State.get_node(flow, anchor).position
    node = bubble_node(id, pos.x + 20, pos.y + 20, map_size(flow.nodes))

    flow =
      flow
      |> State.add_node(node)
      |> State.add_edge(
        Edge.new("#{anchor}-#{id}", anchor, id,
          type: :straight,
          source_floating: true,
          target_floating: true
        )
      )

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, flow)
     |> FlowEvents.log("add_node", %{"id" => id, "anchor" => anchor})
     |> relayout([])}
  end

  def handle_event("shake", _params, socket) do
    flow =
      Enum.reduce(socket.assigns.flow.nodes, socket.assigns.flow, fn {id, node}, acc ->
        jitter = fn -> :rand.uniform(240) - 120 end

        State.update_node(acc, id, fn n ->
          %{n | position: %{x: node.position.x + jitter.(), y: node.position.y + jitter.()}}
        end)
      end)

    {:noreply, socket |> assign(:flow, flow) |> relayout([])}
  end

  def handle_event("lf:connect_end", params, socket) do
    socket =
      assign(socket, :edge_opts, type: :straight, source_floating: true, target_floating: true)

    {:noreply, socket} = FlowEvents.handle_event("lf:connect_end", params, socket)
    {:noreply, relayout(socket, [])}
  end

  # Re-run the simulation when a drag ends, keeping the dragged nodes fixed
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
    {:noreply, if(ended == [], do: socket, else: relayout(socket, ended))}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp relayout(socket, fixed) do
    %{flow: flow, params: params} = socket.assigns
    LiveFlow.animate_positions(socket, @flow_id, flow, layout(flow, params, fixed), duration: 600)
  end

  defp layout(flow, params, fixed) do
    Layout.force(flow,
      iterations: String.to_integer(params["iterations"]),
      distance: String.to_integer(params["distance"]),
      fixed: fixed
    )
  end

  defp bubble_node(id, x, y, i) do
    Node.new(
      id,
      %{x: x, y: y},
      %{
        label: String.upcase(String.slice(id, 0, 2)),
        color: Enum.at(@colors, rem(i, length(@colors)))
      },
      type: :bubble,
      width: 66,
      height: 66,
      handles: [Handle.source(:right), Handle.target(:left)]
    )
  end

  defp build_flow do
    ids = ~w(a b c d e f g h i j k l)

    nodes =
      ids
      |> Enum.with_index()
      |> Enum.map(fn {id, i} -> bubble_node(id, rem(i, 4) * 40, div(i, 4) * 40, i) end)

    edges =
      for {s, t} <- [
            {"a", "b"},
            {"a", "c"},
            {"a", "d"},
            {"b", "e"},
            {"b", "f"},
            {"c", "g"},
            {"d", "h"},
            {"h", "i"},
            {"h", "j"},
            {"e", "k"},
            {"k", "l"},
            {"g", "l"}
          ] do
        Edge.new("#{s}-#{t}", s, t, type: :straight, source_floating: true, target_floating: true)
      end

    State.new(nodes: nodes, edges: edges)
  end
end

defmodule FlowExampleWeb.Examples.Edges.DeleteEdgeOnDropLive do
  @moduledoc """
  Delete Edge on Drop: delete an edge when its end doesn't find a handle.

  Edges are created with `reconnectable: true`: both ends get a grab handle.
  Dropping an end on a handle pushes `lf:reconnect_edge` (applied with
  `LiveFlow.State.reconnect_edge/3`); dropping it on the pane pushes
  `lf:delete_reconnect_edge` with the drop position, and the edge is removed.
  Deleted edges can be restored from the sidebar.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, Node, State}

  @poof_ms 900

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, deleted: [])
     |> assign(:edge_opts, reconnectable: true)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #delete-edge-on-drop-flow .lf-node[data-node-type="poof"] {
        background: transparent;
        border: none;
        box-shadow: none;
        pointer-events: none;
      }
      #delete-edge-on-drop-flow .lf-node[data-node-type="poof"] .lf-node-content {
        min-width: 0;
        padding: 0;
      }
      #delete-edge-on-drop-flow .ded-poof {
        animation: ded-poof 900ms ease-out forwards;
      }
      @keyframes ded-poof {
        0% {
          opacity: 0;
          transform: scale(0.6);
        }
        20% {
          opacity: 1;
          transform: scale(1.05);
        }
        100% {
          opacity: 0;
          transform: scale(1.25) translateY(-8px);
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="reset-flow" icon="hero-arrow-path" phx-click="reset">Reset</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="delete-edge-on-drop-flow"
        flow={@flow}
        node_types={Map.put(FlowNodes.types(), :poof, &poof_node/1)}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.25}
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Hover an edge: a round handle appears at each end. Drag one of them to another handle to
            reconnect the edge, or drop it on the pane to delete it.
          </.hint>
          <.hint>
            Edges use <code>reconnectable: true</code>
            (new connections too, through <code>edge_opts</code>). The LiveView handles
            <code>lf:reconnect_edge</code>
            with <code>State.reconnect_edge/3</code>
            and <code>lf:delete_reconnect_edge</code>
            (it carries the dropped <code>end</code>
            and <code>position</code>) with <code>State.remove_edge/2</code>.
          </.hint>
        </.option_group>

        <.option_group title="Deleted edges">
          <p :if={@deleted == []} id="deleted-none" class="text-sm text-base-content/50">
            Nothing deleted yet.
          </p>
          <ul :if={@deleted != []} id="deleted-list" class="space-y-1.5">
            <li
              :for={edge <- @deleted}
              id={"deleted-#{edge.id}"}
              class="flex items-center gap-2 rounded-lg border border-base-300 px-2.5 py-1.5 text-sm"
            >
              <.icon name="hero-scissors-mini" class="size-4 text-base-content/40" />
              <span class="truncate">
                {node_title(@flow, edge.source)} → {node_title(@flow, edge.target)}
              </span>
              <button
                id={"restore-#{edge.id}"}
                type="button"
                phx-click="restore"
                phx-value-edge_id={edge.id}
                class="ml-auto rounded-md px-2 py-0.5 text-xs font-medium text-primary transition-colors hover:bg-primary/10"
              >
                Restore
              </button>
            </li>
          </ul>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  # A short-lived marker where an edge was dropped (removed after @poof_ms)
  defp poof_node(assigns) do
    ~H"""
    <div class="ded-poof flex h-7 w-24 items-center justify-center gap-1 rounded-full bg-rose-500 text-[11px] font-semibold text-white shadow-lg">
      <.icon name="hero-trash-mini" class="size-3.5" /> deleted
    </div>
    """
  end

  @impl true
  def handle_event("lf:reconnect_edge", params, socket) do
    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, State.reconnect_edge(socket.assigns.flow, params))
     |> FlowEvents.log("lf:reconnect_edge", params)}
  end

  def handle_event("lf:delete_reconnect_edge", %{"edge_id" => id} = params, socket) do
    case State.get_edge(socket.assigns.flow, id) do
      %Edge{} = edge ->
        {:noreply,
         socket
         |> FlowEvents.snapshot()
         |> assign(:flow, State.remove_edge(socket.assigns.flow, id))
         |> update(
           :deleted,
           &[%{edge | selected: false} | Enum.reject(&1, fn e -> e.id == id end)]
         )
         |> add_poof(params["position"])
         |> FlowEvents.log("lf:delete_reconnect_edge", params)}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("restore", %{"edge_id" => id}, socket) do
    flow = socket.assigns.flow

    case Enum.find(socket.assigns.deleted, &(&1.id == id)) do
      %Edge{} = edge ->
        restorable? =
          State.get_node(flow, edge.source) && State.get_node(flow, edge.target) &&
            !State.get_edge(flow, id)

        socket =
          if restorable?,
            do: socket |> FlowEvents.snapshot() |> assign(:flow, State.add_edge(flow, edge)),
            else: socket

        {:noreply, update(socket, :deleted, &Enum.reject(&1, fn e -> e.id == id end))}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(flow: build_flow(), deleted: [])}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:remove_poof, id}, socket) do
    if State.get_node(socket.assigns.flow, id),
      do: {:noreply, assign(socket, :flow, State.remove_node(socket.assigns.flow, id))},
      else: {:noreply, socket}
  end

  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp add_poof(socket, %{"x" => x, "y" => y}) when is_number(x) and is_number(y) do
    id = "poof-#{System.unique_integer([:positive])}"

    poof =
      Node.new(id, %{x: x - 48, y: y - 14}, %{},
        type: :poof,
        handles: [],
        connectable: false,
        draggable: false,
        selectable: false,
        deletable: false,
        z_index: 10
      )

    if connected?(socket), do: Process.send_after(self(), {:remove_poof, id}, @poof_ms)
    assign(socket, :flow, State.add_node(socket.assigns.flow, poof))
  end

  defp add_poof(socket, _position), do: socket

  defp node_title(flow, id) do
    case State.get_node(flow, id) do
      %Node{data: data} -> data[:title] || id
      nil -> id
    end
  end

  defp build_flow do
    nodes = [
      Samples.card("a", 0, 40, "Source A", "Drag my edges' ends", "hero-arrow-up-tray", :sky,
        inputs: false
      ),
      Samples.card("b", 0, 220, "Source B", "Drag my edges' ends", "hero-arrow-up-tray", :violet,
        inputs: false
      ),
      Samples.card("t1", 440, -20, "Target 1", "Drop here to reconnect", "hero-inbox", :emerald,
        outputs: false
      ),
      Samples.card("t2", 440, 130, "Target 2", "Drop here to reconnect", "hero-inbox", :emerald,
        outputs: false
      ),
      Samples.card("t3", 440, 280, "Target 3", "Drop here to reconnect", "hero-inbox", :emerald,
        outputs: false
      )
    ]

    edges = [
      Edge.new("a-t1", "a", "t1", reconnectable: true),
      Edge.new("a-t2", "a", "t2", reconnectable: true),
      Edge.new("b-t3", "b", "t3", reconnectable: true)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

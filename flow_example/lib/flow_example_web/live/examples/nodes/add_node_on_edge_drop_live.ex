defmodule FlowExampleWeb.Examples.Nodes.AddNodeOnEdgeDropLive do
  @moduledoc """
  Add Node On Edge Drop: releasing a connection line on the empty pane
  creates a node at the drop position, connected to the handle the line
  started from.

  The hook pushes `lf:connect_cancel` with `"reason" => "pane"` and the
  release point in flow coordinates.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}

  # React Flow's default node size. Nodes get an explicit width so the new
  # node can be centered on the drop point before it is measured.
  @node_width 150
  @node_height 40

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, next_id: 1)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #add-node-on-edge-drop .lf-node[data-node-id="0"] {
        border-color: color-mix(in oklab, var(--lf-node-selected-border) 55%, var(--lf-node-border));
      }

      #add-node-on-edge-drop .lf-node.is-new {
        animation: add-node-pop 260ms cubic-bezier(0.2, 0.9, 0.3, 1.25);
      }

      @keyframes add-node-pop {
        from {
          opacity: 0;
          scale: 0.85;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="add-node-reset" icon="hero-arrow-path" phx-click="reset">Reset</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="add-node-on-edge-drop"
        flow={@flow}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{max_zoom: 1, padding: 0.4}
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Drag a connection from a handle and release it on the empty pane: a new node appears
            where you dropped it, already connected.
          </.hint>
          <.hint>
            Releasing a line anywhere but on a handle pushes <code>lf:connect_cancel</code>
            with <code>"reason" =&gt; "pane"</code>
            and the release <code>position</code>
            in flow coordinates. The LiveView adds the node with its handle on that point.
          </.hint>
          <.hint>
            <code>handle_type</code>
            tells where the line started: from a <b>source</b>
            (bottom) the new node becomes a child, from a <b>target</b>
            (top) it becomes a parent.
          </.hint>
        </.option_group>
        <.option_group title="Nodes">
          <p id="add-node-count" class="text-sm">
            <span class="font-mono font-semibold">{map_size(@flow.nodes)}</span>
            <span class="text-base-content/60">nodes,</span>
            <span class="font-mono font-semibold">{map_size(@flow.edges)}</span>
            <span class="text-base-content/60">edges</span>
          </p>
        </.option_group>
        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  @impl true
  def handle_event(
        "lf:connect_cancel",
        %{"reason" => "pane", "node_id" => from_id, "position" => %{"x" => x, "y" => y}} =
          params,
        socket
      ) do
    flow = socket.assigns.flow

    if State.get_node(flow, from_id) do
      id = Integer.to_string(socket.assigns.next_id)
      from_source? = params["handle_type"] != "target"

      # Center the node horizontally on the drop point, with the handle that
      # receives the line (top target or bottom source) right on it.
      position = %{
        x: round(x - @node_width / 2),
        y: if(from_source?, do: round(y), else: round(y - @node_height))
      }

      edge =
        if from_source?,
          do: Edge.new("e#{from_id}-#{id}", from_id, id, source_handle: params["handle_id"]),
          else: Edge.new("e#{id}-#{from_id}", id, from_id, target_handle: params["handle_id"])

      flow =
        flow
        |> State.add_node(new_node(id, position, "Node #{id}", class: "is-new"))
        |> State.add_edge(edge)

      {:noreply,
       socket
       |> FlowEvents.snapshot()
       |> assign(flow: flow, next_id: socket.assigns.next_id + 1)
       |> FlowEvents.log("lf:connect_cancel", params)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> FlowEvents.assign_flow(build_flow())
     |> assign(:next_id, 1)}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp new_node(id, position, label, opts) do
    handles =
      if Keyword.get(opts, :input, true),
        do: [Handle.target(:top), Handle.source(:bottom)],
        else: [Handle.source(:bottom)]

    Node.new(id, position, %{label: label},
      handles: handles,
      class: opts[:class],
      style: %{"width" => "#{@node_width}px"}
    )
  end

  defp build_flow do
    State.new(nodes: [new_node("0", %{x: 0, y: 50}, "Node", input: false)])
  end
end

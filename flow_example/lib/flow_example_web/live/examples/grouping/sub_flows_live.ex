defmodule FlowExampleWeb.Examples.Grouping.SubFlowsLive do
  @moduledoc """
  Sub Flow: nested graphs and group nodes.

  Child nodes set `parent_id`: their position is relative to the parent, they
  move with it, and `extent: :parent` keeps them inside of it.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Node, State}

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
      #sub-flows .lf-node[data-node-type="group"][data-selected="true"] {
        background: color-mix(in oklab, var(--lf-node-selected-border) 6%, transparent);
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="sub-flows"
        flow={@flow}
        node_types={%{group: &group_node/1}}
        opts={%{background: :dots, controls: true, minimap: true, fit_view_on_init: true}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Child nodes are created with <code>parent_id: "A"</code>: their position is relative to
            the group, so dragging a group moves everything inside.
          </.hint>
          <.hint>
            <b>A-1</b>
            and <b>B-1</b>
            use <code>extent: :parent</code>
            and can't leave their group. <b>A-2</b>
            can be dragged out freely.
          </.hint>
          <.hint>
            Groups nest: <b>B</b> lives inside <b>A</b>, <b>B-1</b> inside <b>B</b>. Deleting a group
            deletes its children.
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

  defp group_node(assigns) do
    ~H"""
    <span class="pointer-events-none absolute top-2 left-3 text-xs font-semibold uppercase tracking-wide text-base-content/50">
      {@node.data.label}
    </span>
    """
  end

  @impl true
  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp build_flow do
    group = fn id, x, y, w, h, opts ->
      Node.new(
        id,
        %{x: x, y: y},
        %{label: "Group #{id}"},
        Keyword.merge(
          [
            type: :group,
            resizable: true,
            width: w,
            height: h,
            connectable: false
          ],
          opts
        )
      )
    end

    nodes = [
      Node.new("1", %{x: 0, y: 160}, %{label: "Node 1"}),
      group.("A", 220, 40, 420, 320, []),
      Node.new("A-1", %{x: 20, y: 50}, %{label: "A-1 (extent)"}, parent_id: "A", extent: :parent),
      Node.new("A-2", %{x: 20, y: 240}, %{label: "A-2 (free)"}, parent_id: "A"),
      group.("B", 200, 30, 190, 180, parent_id: "A", extent: :parent),
      Node.new("B-1", %{x: 25, y: 60}, %{label: "B-1"}, parent_id: "B", extent: :parent),
      Node.new("2", %{x: 760, y: 160}, %{label: "Node 2"})
    ]

    edges = [
      Edge.new("e1", "1", "A-1", type: :smoothstep),
      Edge.new("e2", "A-1", "B-1", type: :smoothstep, animated: true),
      Edge.new("e3", "A-2", "2", type: :smoothstep),
      Edge.new("e4", "B-1", "2", type: :smoothstep)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

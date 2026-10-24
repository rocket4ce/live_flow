defmodule FlowExampleWeb.Examples.Nodes.DragHandleLive do
  @moduledoc """
  Drag Handle: restrict dragging to a specific part of a node.

  Nodes created with `drag_handle: ".drag-handle"` can only be dragged from
  elements matching the selector; the rest of the content keeps selectable
  text and working controls.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}

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
      #drag-handle .lf-node[data-drag-handle] {
        cursor: default;
      }

      #drag-handle .drag-handle {
        cursor: grab;
        transition: background-color 150ms ease, color 150ms ease;
      }

      #drag-handle .drag-handle:hover {
        background: color-mix(in oklab, var(--lf-node-selected-border) 22%, transparent);
        color: var(--lf-node-selected-border);
      }

      #drag-handle .lf-node[data-dragging="true"] .drag-handle {
        cursor: grabbing;
        background: var(--lf-node-selected-border);
        color: white;
      }

      #drag-handle .selectable {
        user-select: text;
        cursor: text;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="drag-handle"
        flow={@flow}
        node_types={%{grip: &grip_node/1, note: &note_node/1}}
        opts={%{background: :dots, controls: true, fit_view_on_init: true}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            <code>Node.new(id, pos, data, drag_handle: ".drag-handle")</code>
            — a node with a <code>drag_handle</code>
            only starts a drag when the pointer goes down on an element matching the selector.
          </.hint>
          <.hint>
            Grab the <b>dotted grip</b>
            or the <b>title bar</b>
            to move a node. Everywhere else you can select the text or use the slider, without moving
            the node.
          </.hint>
          <.hint>
            The plain <b>Source</b> node has no drag handle: it is dragged from anywhere.
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

  # React Flow's version: a small grip next to a label
  defp grip_node(assigns) do
    ~H"""
    <div class="flex items-center gap-3 py-1">
      <span class="selectable text-[13px]" style="color: var(--lf-text-primary)">
        Only draggable here →
      </span>
      <span
        class="drag-handle grid size-7 place-items-center rounded-md"
        style="color: var(--lf-text-secondary); background: var(--lf-node-border)"
        title="Drag me"
      >
        <.icon name="hero-arrows-pointing-out-mini" class="size-4" />
      </span>
    </div>
    """
  end

  attr :node, :map, required: true

  # A card dragged by its title bar, with selectable text and a slider
  defp note_node(assigns) do
    ~H"""
    <div class="w-60">
      <div
        class="drag-handle -mx-[15px] -mt-[10px] mb-3 flex items-center gap-2 rounded-t-[7px] border-b px-3 py-1.5"
        style="border-color: var(--lf-node-border); color: var(--lf-text-secondary)"
      >
        <.icon name="hero-bars-2-mini" class="size-4" />
        <span class="text-[11px] font-semibold uppercase tracking-wider">{@node.data.title}</span>
      </div>
      <p class="selectable text-[12px] leading-relaxed" style="color: var(--lf-text-primary)">
        {@node.data.text}
      </p>
      <form id={"level-form-#{@node.id}"} phx-change="set_level" class="nodrag mt-3">
        <input type="hidden" name="node_id" value={@node.id} />
        <label
          class="flex items-center justify-between text-[11px]"
          style="color: var(--lf-text-secondary)"
        >
          <span>Volume</span>
          <span id={"level-value-#{@node.id}"} class="font-mono">{@node.data.level}%</span>
        </label>
        <input
          type="range"
          name="level"
          min="0"
          max="100"
          value={@node.data.level}
          class="mt-1 h-1.5 w-full cursor-pointer appearance-none rounded-full bg-base-300 accent-primary"
        />
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("set_level", %{"node_id" => id, "level" => level}, socket) do
    case Integer.parse(level) do
      {value, _} ->
        flow =
          State.update_node(socket.assigns.flow, id, fn node ->
            %{node | data: %{node.data | level: value |> max(0) |> min(100)}}
          end)

        {:noreply, assign(socket, :flow, flow)}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp build_flow do
    nodes = [
      Node.new("source", %{x: 0, y: 60}, %{label: "Source"}),
      Node.new("grip", %{x: 230, y: 50}, %{},
        type: :grip,
        drag_handle: ".drag-handle",
        handles: [Handle.target(:left), Handle.source(:right)]
      ),
      Node.new(
        "note",
        %{x: 560, y: 0},
        %{
          title: "Release notes",
          text: "Select this text freely: only the title bar above moves the note.",
          level: 60
        },
        type: :note,
        drag_handle: ".drag-handle",
        handles: [Handle.target(:left)]
      )
    ]

    edges = [
      Edge.new("e-source-grip", "source", "grip", animated: true),
      Edge.new("e-grip-note", "grip", "note", type: :smoothstep)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

defmodule FlowExampleWeb.Examples.Nodes.ConnectionLimitLive do
  @moduledoc """
  Connection Limit: handles that accept a limited number of connections.

  The connection count is derived from the edges after every change. Once a
  handle is full it is rendered with `connectable: false`, so the client
  refuses new lines, and the server enforces the same limit with
  `LiveFlow.Validation.max_connections/3`.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State, Validation}
  alias LiveFlow.Validation.Connection

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
      #connection-limit .lf-handle[data-handle-connectable="false"] {
        cursor: not-allowed;
        background: var(--lf-node-border);
        border-color: var(--lf-node-border);
      }

      #connection-limit .lf-handle[data-handle-connectable="false"]:hover {
        transform: translateY(-50%);
      }

      #connection-limit .lf-node.is-full {
        border-color: color-mix(in oklab, #f43f5e 45%, var(--lf-node-border));
      }

      #connection-limit .limit-slot {
        transition: background-color 200ms ease, transform 200ms ease;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="connection-limit"
        flow={@flow}
        node_types={%{source: &source_node/1, limited: &limited_node/1}}
        opts={%{background: :dots, controls: true, fit_view_on_init: true}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            <b>Single input</b>
            accepts one connection, <b>Two inputs</b>
            accepts two. Connect the sources on the left to fill them up.
          </.hint>
          <.hint>
            After every change the LiveView counts the edges of each limited handle and re-renders a full
            handle with <code>Handle.target(:left, connectable: false)</code>: the client won't
            start or end a connection on it.
          </.hint>
          <.hint>
            The server enforces the same rule in <code>lf:connect_end</code>
            with <code>Validation.max_connections(flow, params, max: n)</code>. Delete an edge
            (select it, <.kbd>Backspace</.kbd>) to free a slot again.
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

  defp source_node(assigns) do
    ~H"""
    <div class="flex w-32 items-center gap-2">
      <span class="grid size-7 shrink-0 place-items-center rounded-md bg-sky-500/15 text-sky-600">
        <.icon name="hero-arrow-right-start-on-rectangle-mini" class="size-4" />
      </span>
      <span class="text-[13px] font-semibold" style="color: var(--lf-text-primary)">
        {@node.data.label}
      </span>
    </div>
    """
  end

  attr :node, :map, required: true

  defp limited_node(assigns) do
    assigns = assign(assigns, :full, assigns.node.data.count >= assigns.node.data.limit)

    ~H"""
    <div class="w-48">
      <div class="flex items-center justify-between gap-2">
        <p class="text-[13px] font-semibold" style="color: var(--lf-text-primary)">
          {@node.data.label}
        </p>
        <span
          id={"limit-count-#{@node.id}"}
          class={[
            "rounded-full px-1.5 py-0.5 font-mono text-[11px] font-semibold",
            if(@full, do: "bg-rose-500/15 text-rose-600", else: "bg-emerald-500/15 text-emerald-600")
          ]}
        >
          {@node.data.count}/{@node.data.limit}
        </span>
      </div>
      <div class="mt-2 flex gap-1">
        <span
          :for={slot <- 1..@node.data.limit}
          class="limit-slot h-1.5 flex-1 rounded-full"
          style={
            if(slot <= @node.data.count,
              do: "background: var(--lf-node-selected-border)",
              else: "background: var(--lf-node-border)"
            )
          }
        />
      </div>
      <p class="mt-1.5 flex items-center gap-1 text-[11px]" style="color: var(--lf-text-secondary)">
        <%= if @full do %>
          <.icon name="hero-lock-closed-mini" class="size-3.5 text-rose-500" /> Limit reached
        <% else %>
          <.icon name="hero-arrow-left-mini" class="size-3.5" />
          {@node.data.limit - @node.data.count} more allowed
        <% end %>
      </p>
    </div>
    """
  end

  @impl true
  def handle_event("lf:connect_end", params, socket) do
    validators = Validation.preset(:default) ++ [&within_limit/2]

    case Connection.validate_and_create(socket.assigns.flow, params,
           validators: validators,
           edge_opts: [type: :smoothstep]
         ) do
      {:ok, edge} ->
        {:noreply,
         socket
         |> FlowEvents.snapshot()
         |> assign(:flow, socket.assigns.flow |> State.add_edge(edge) |> apply_limits())
         |> FlowEvents.log("lf:connect_end", params)}

      {:error, reason} ->
        {:noreply, FlowEvents.log(socket, "lf:connect_end", Map.put(params, "rejected", reason))}
    end
  end

  # Every other change (deleted edges, undo, reconnects, ...) can change a
  # count: recompute the limits after the standard handling.
  def handle_event("lf:" <> _ = event, params, socket) do
    {:noreply, socket} = FlowEvents.handle_event(event, params, socket)
    {:noreply, update(socket, :flow, &apply_limits/1)}
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # `Validation.max_connections/3` checks both ends of the connection against
  # the same `max`. The limit belongs to the target handle only, so the
  # source side is left out of the check.
  defp within_limit(flow, params) do
    case State.get_node(flow, params.target) do
      %Node{data: %{limit: max}} ->
        Validation.max_connections(flow, %{params | source: nil}, max: max)

      _ ->
        :ok
    end
  end

  # Stores the count in the node data (for the renderer) and disables the
  # handle once the limit is reached.
  defp apply_limits(flow) do
    Enum.reduce(flow.nodes, flow, fn
      {id, %Node{data: %{limit: limit}}}, acc ->
        count = connection_count(acc, id, "in")
        full = count >= limit

        State.update_node(acc, id, fn node ->
          %{
            node
            | data: Map.put(node.data, :count, count),
              class: if(full, do: "is-full"),
              handles: Enum.map(node.handles, &%{&1 | connectable: not full})
          }
        end)

      _other, acc ->
        acc
    end)
  end

  defp connection_count(flow, node_id, handle_id) do
    Enum.count(Map.values(flow.edges), fn edge ->
      edge.target == node_id and Edge.effective_target_handle(edge) == handle_id
    end)
  end

  defp build_flow do
    source = fn id, y, label ->
      Node.new(id, %{x: 0, y: y}, %{label: label},
        type: :source,
        handles: [Handle.source(:right, id: "out")]
      )
    end

    limited = fn id, y, label, limit ->
      Node.new(id, %{x: 340, y: y}, %{label: label, limit: limit, count: 0},
        type: :limited,
        handles: [Handle.target(:left, id: "in")]
      )
    end

    nodes = [
      source.("a", 0, "Source A"),
      source.("b", 110, "Source B"),
      source.("c", 220, "Source C"),
      limited.("single", 20, "Single input", 1),
      limited.("double", 170, "Two inputs", 2)
    ]

    edges = [
      Edge.new("a-single", "a", "single",
        source_handle: "out",
        target_handle: "in",
        type: :smoothstep
      ),
      Edge.new("b-double", "b", "double",
        source_handle: "out",
        target_handle: "in",
        type: :smoothstep
      )
    ]

    [nodes: nodes, edges: edges] |> State.new() |> apply_limits()
  end
end

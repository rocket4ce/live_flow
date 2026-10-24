defmodule FlowExampleWeb.Examples.Interaction.ValidationLive do
  @moduledoc """
  Validation: check if a new connection is valid and should be added.

  Two layers of validation:

    * **Server** — every `lf:connect_end` goes through
      `LiveFlow.Validation.Connection.validate_and_create/3` with the strict
      preset, `Validation.types_compatible/2` and a custom validator: the
      *Input* node may only connect to node *B* (React Flow's
      `isValidConnection = (c) => c.target === 'B'`). Rejected connections
      are never added and the target node flashes.
    * **Client** — handles with a `connect_type` refuse handles of another
      type while dragging (they turn red) and the hook pushes
      `lf:connect_cancel` with `reason: "invalid"` instead of `lf:connect_end`.

  Every attempt is logged in the sidebar.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State, Validation}
  alias LiveFlow.Validation.Connection

  @flash_ms 1600
  @max_attempts 10
  @type_colors %{number: "#10b981", text: "#0ea5e9"}

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(attempts: [], attempt_seq: 0, flash_node: nil)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #validation-flow .lf-handle.handle-number {
        border-color: #10b981;
        background: color-mix(in oklab, #10b981 25%, var(--lf-node-bg));
      }
      #validation-flow .lf-handle.handle-text {
        border-color: #0ea5e9;
        background: color-mix(in oklab, #0ea5e9 25%, var(--lf-node-bg));
      }
      #validation-flow .lf-handle[data-connecting="valid"] {
        background: #22c55e;
        border-color: #16a34a;
      }
      #validation-flow .lf-handle[data-connecting="invalid"] {
        background: #f43f5e;
        border-color: #e11d48;
      }
      #validation-flow .lf-node.validation-rejected {
        border-color: #f43f5e;
        box-shadow: 0 0 0 4px color-mix(in oklab, #f43f5e 22%, transparent);
        animation: validation-shake 380ms ease-in-out;
      }
      #validation-flow .lf-node[data-node-type="zone"] {
        background: transparent;
        border: 1px dashed color-mix(in oklab, var(--lf-node-border) 80%, transparent);
        box-shadow: none;
        pointer-events: none;
      }
      @keyframes validation-shake {
        0%,
        100% {
          translate: 0 0;
        }
        25% {
          translate: -5px 0;
        }
        75% {
          translate: 5px 0;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="validation-flow"
        flow={decorate(@flow, @flash_node)}
        node_types={%{rule: &rule_node/1, typed: &typed_node/1, zone: &zone_node/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.15},
            connection_line_type: :smoothstep
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            <b>Server rule.</b>
            <code>lf:connect_end</code>
            runs <code>Connection.validate_and_create/3</code>
            with <code>Validation.preset(:strict)</code>,
            <code>&amp;Validation.types_compatible/2</code>
            and a custom validator: connections from <b>Input</b>
            are only valid to <b>B</b>. Try A or C: the edge is refused and the node shakes.
          </.hint>
          <.hint>
            <b>Typed handles.</b>
            Handles created with <code>connect_type: :number</code>
            or <code>:text</code>
            only accept the same type. The check runs in the browser while you drag: a mismatched
            handle turns red and dropping on it sends <code>lf:connect_cancel</code>
            with <code>reason: "invalid"</code>. Untyped handles (the <b>Logger</b>) accept anything.
          </.hint>
        </.option_group>

        <.option_group title="Attempts">
          <ul id="validation-attempts" class="space-y-1.5">
            <li :if={@attempts == []} class="text-xs text-base-content/40">
              Connect two handles to validate the connection…
            </li>
            <li
              :for={attempt <- @attempts}
              id={"validation-attempt-#{attempt.id}"}
              data-result={attempt.result}
              data-by={attempt.by}
              class="rounded-lg bg-base-200/70 px-2.5 py-1.5 text-xs"
            >
              <div class="flex items-center gap-2">
                <.icon
                  name={
                    if attempt.result == :ok,
                      do: "hero-check-circle-mini",
                      else: "hero-no-symbol-mini"
                  }
                  class={[
                    "size-4 shrink-0",
                    if(attempt.result == :ok, do: "text-emerald-600", else: "text-rose-600")
                  ]}
                />
                <span class="truncate font-mono">{attempt.source} → {attempt.target}</span>
                <span class={[
                  "ml-auto rounded px-1.5 py-px text-[10px] font-semibold uppercase tracking-wide",
                  if(attempt.by == :client,
                    do: "bg-sky-500/15 text-sky-600",
                    else: "bg-violet-500/15 text-violet-600"
                  )
                ]}>
                  {attempt.by}
                </span>
              </div>
              <p :if={attempt.reason} class="mt-0.5 pl-6 text-base-content/55">{attempt.reason}</p>
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

  # ===== Node renderers =====

  attr :node, :map, required: true

  defp rule_node(assigns) do
    ~H"""
    <div class="flex w-36 items-center justify-between gap-2">
      <span class="text-sm font-semibold" style="color: var(--lf-text-primary)">
        {@node.data.label}
      </span>
      <span
        :if={@node.data[:hint]}
        class={[
          "rounded-full px-1.5 py-px text-[10px] font-medium",
          if(@node.data[:valid],
            do: "bg-emerald-500/15 text-emerald-600",
            else: "bg-base-content/8 text-base-content/50"
          )
        ]}
      >
        {@node.data.hint}
      </span>
    </div>
    """
  end

  attr :node, :map, required: true

  defp typed_node(assigns) do
    ~H"""
    <div class="w-44">
      <p class="text-sm font-semibold" style="color: var(--lf-text-primary)">{@node.data.label}</p>
      <div :if={@node.data[:ports]} class="mt-1.5 space-y-1">
        <p
          :for={{name, type} <- @node.data.ports}
          class="flex items-center gap-1.5 text-[11px]"
          style="color: var(--lf-text-secondary)"
        >
          <span class="size-2 rounded-full" style={"background: #{type_color(type)}"}></span>
          {name} <span class="font-mono opacity-70">{type || "any"}</span>
        </p>
      </div>
      <p :if={@node.data[:type]} class="mt-1 flex items-center gap-1.5 text-[11px]">
        <span class="size-2 rounded-full" style={"background: #{type_color(@node.data.type)}"}></span>
        <span class="font-mono" style="color: var(--lf-text-secondary)">{@node.data.type}</span>
      </p>
    </div>
    """
  end

  attr :node, :map, required: true

  defp zone_node(assigns) do
    ~H"""
    <span class="absolute top-2.5 left-3 text-[11px] font-semibold uppercase tracking-wider text-base-content/40">
      {@node.data.label}
    </span>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("lf:connect_end", params, socket) do
    flow = socket.assigns.flow

    validators =
      Validation.preset(:strict) ++ [&Validation.types_compatible/2, &input_only_to_b/2]

    case Connection.validate_and_create(flow, params,
           validators: validators,
           edge_opts: edge_opts(flow, params)
         ) do
      {:ok, edge} ->
        socket
        |> FlowEvents.snapshot()
        |> assign(:flow, State.add_edge(flow, edge))
        |> add_attempt(params["source"], params["target"], :ok, :server, nil)
        |> FlowEvents.log("lf:connect_end", params)
        |> noreply()

      {:error, reason} ->
        socket
        |> flash_node(params["target"])
        |> add_attempt(params["source"], params["target"], :rejected, :server, reason)
        |> FlowEvents.log("lf:connect_end", Map.put(params, "rejected", reason))
        |> noreply()
    end
  end

  def handle_event("lf:connect_cancel", %{"reason" => "invalid"} = params, socket) do
    flow = socket.assigns.flow
    target = handle_near(flow, params["position"])

    socket
    |> add_attempt(
      params["node_id"],
      target && target.node_id,
      :rejected,
      :client,
      client_reason(flow, params, target)
    )
    |> FlowEvents.log("lf:connect_cancel", params)
    |> noreply()
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:clear_flash, token}, %{assigns: %{flash_node: {_id, token}}} = socket) do
    {:noreply, assign(socket, :flash_node, nil)}
  end

  def handle_info({:clear_flash, _stale}, socket), do: {:noreply, socket}

  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Validation =====

  # React Flow's `isValidConnection = (connection) => connection.target === 'B'`,
  # scoped to the Input node
  defp input_only_to_b(_flow, %{source: "input", target: target}) when target != "B" do
    {:error, "Input can only connect to node B"}
  end

  defp input_only_to_b(_flow, _connection), do: :ok

  # Explains why the browser refused the handle the line was dropped on
  defp client_reason(flow, params, target) do
    source = find_handle(flow, params["node_id"], params["handle_id"], params["handle_type"])

    cond do
      is_nil(target) ->
        "Refused by the browser"

      target.node_id == params["node_id"] ->
        "A node can't connect to itself"

      to_string(target.handle.type) == params["handle_type"] ->
        "Strict mode only connects a source to a target"

      source && source.connect_type && target.handle.connect_type &&
          source.connect_type != target.handle.connect_type ->
        "Type mismatch: #{source.connect_type} → #{target.handle.connect_type}"

      true ->
        "Refused by the browser"
    end
  end

  defp find_handle(flow, node_id, handle_id, handle_type) do
    with %Node{handles: handles} <- State.get_node(flow, node_id) do
      Enum.find(handles, fn handle ->
        Handle.effective_id(handle) == handle_id and to_string(handle.type) == handle_type
      end)
    end
  end

  # The handle closest to a flow position (within 40 units), computed from
  # the node rectangles like the client does
  defp handle_near(_flow, nil), do: nil

  defp handle_near(flow, %{"x" => x, "y" => y}) do
    flow.nodes
    |> Map.values()
    |> Enum.flat_map(fn node ->
      rect = State.node_rect(flow, node)
      Enum.map(node.handles, &%{node_id: node.id, handle: &1, point: handle_point(rect, &1)})
    end)
    |> Enum.map(fn h ->
      {h, :math.sqrt(:math.pow(h.point.x - x, 2) + :math.pow(h.point.y - y, 2))}
    end)
    |> Enum.filter(fn {_h, distance} -> distance <= 40 end)
    |> Enum.min_by(fn {_h, distance} -> distance end, fn -> nil end)
    |> case do
      {handle, _distance} -> handle
      nil -> nil
    end
  end

  defp handle_point(rect, %Handle{position: position, offset: offset}) do
    offset = offset || 0.5

    case position do
      :left -> %{x: rect.x, y: rect.y + rect.height * offset}
      :right -> %{x: rect.x + rect.width, y: rect.y + rect.height * offset}
      :top -> %{x: rect.x + rect.width * offset, y: rect.y}
      :bottom -> %{x: rect.x + rect.width * offset, y: rect.y + rect.height}
    end
  end

  # Edges are colored like the type of their source handle
  defp edge_opts(flow, params) do
    type =
      case find_handle(flow, params["source"], params["source_handle"] || "source", "source") do
        %Handle{connect_type: type} -> type
        nil -> nil
      end

    base = [type: :smoothstep, animated: true]

    case Map.get(@type_colors, type) do
      nil -> base
      color -> base ++ [style: %{stroke: color, "stroke-width": 2}]
    end
  end

  # ===== Helpers =====

  defp flash_node(socket, nil), do: socket

  defp flash_node(socket, node_id) do
    token = make_ref()
    Process.send_after(self(), {:clear_flash, token}, @flash_ms)
    assign(socket, :flash_node, {node_id, token})
  end

  defp add_attempt(socket, source, target, result, by, reason) do
    flow = socket.assigns.flow
    id = socket.assigns.attempt_seq + 1

    attempt = %{
      id: id,
      result: result,
      by: by,
      reason: reason,
      source: label(flow, source),
      target: if(target, do: label(flow, target), else: "?")
    }

    socket
    |> assign(:attempt_seq, id)
    |> assign(:attempts, Enum.take([attempt | socket.assigns.attempts], @max_attempts))
  end

  # Adds the "rejected" class at render time only (state and history stay clean)
  defp decorate(flow, nil), do: flow

  defp decorate(flow, {node_id, _token}) do
    State.update_node(flow, node_id, &%{&1 | class: "validation-rejected"})
  end

  defp label(flow, id) do
    case State.get_node(flow, id) do
      %Node{data: %{label: label}} -> label
      _other -> to_string(id)
    end
  end

  defp type_color(type), do: Map.get(@type_colors, type, "#94a3b8")

  defp noreply(socket), do: {:noreply, socket}

  # ===== Initial graph =====

  defp build_flow do
    zone = fn id, x, y, w, h, label ->
      Node.new(id, %{x: x, y: y}, %{label: label},
        type: :zone,
        width: w,
        height: h,
        resizable: true,
        draggable: false,
        selectable: false,
        connectable: false,
        deletable: false,
        z_index: -1
      )
    end

    rule = fn id, x, y, data, handles ->
      Node.new(id, %{x: x, y: y}, data, type: :rule, handles: handles, z_index: 1)
    end

    typed = fn id, x, y, data, handles ->
      Node.new(id, %{x: x, y: y}, data, type: :typed, handles: handles, z_index: 1)
    end

    nodes = [
      zone.("zone-rule", -40, -60, 520, 400, "Server rule · only Input → B"),
      rule.("input", 0, 130, %{label: "Input"}, [Handle.source(:right)]),
      rule.("A", 280, 20, %{label: "A", hint: "rejected"}, [Handle.target(:left)]),
      rule.("B", 280, 130, %{label: "B", hint: "valid", valid: true}, [Handle.target(:left)]),
      rule.("C", 280, 240, %{label: "C", hint: "rejected"}, [Handle.target(:left)]),
      zone.("zone-types", 540, -60, 640, 400, "Typed handles · connect_type"),
      typed.("number", 580, 20, %{label: "Price", type: :number}, [
        Handle.source(:right, connect_type: :number, class: "handle-number")
      ]),
      typed.("text", 580, 200, %{label: "Product name", type: :text}, [
        Handle.source(:right, connect_type: :text, class: "handle-text")
      ]),
      typed.(
        "format",
        880,
        70,
        %{label: "Formatter", ports: [{"amount", :number}, {"label", :text}]},
        [
          Handle.target(:left,
            id: "amount",
            offset: 0.6,
            connect_type: :number,
            class: "handle-number"
          ),
          Handle.target(:left,
            id: "label",
            offset: 0.82,
            connect_type: :text,
            class: "handle-text"
          )
        ]
      ),
      typed.("logger", 880, 240, %{label: "Logger", ports: [{"in", nil}]}, [Handle.target(:left)])
    ]

    edges = [
      Edge.new("number-amount", "number", "format",
        target_handle: "amount",
        type: :smoothstep,
        animated: true,
        style: %{stroke: @type_colors.number, "stroke-width": 2}
      )
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

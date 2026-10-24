defmodule FlowExampleWeb.Examples.Interaction.ConnectionEventsLive do
  @moduledoc """
  Connection Events: the events emitted during the connection process, in order.

  With `connection_events: true` the hook pushes `lf:connect_start` when a
  connection line starts. Every attempt then ends with `lf:connect_end`
  (released on a valid handle) or `lf:connect_cancel` (released on the pane,
  on an invalid handle, or aborted with Escape). Dragging the end of a
  selected reconnectable edge pushes `lf:reconnect_edge` or
  `lf:delete_reconnect_edge`.

  The sidebar groups the events of each attempt in a timeline.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}
  alias LiveFlow.Validation.Connection

  @max_attempts 25

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, attempts: [], attempt_seq: 0)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="connection-events"
        flow={@flow}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.3},
            connection_events: true,
            connection_line_type: :smoothstep
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            <code>connection_events: true</code>
            makes the hook push <code>lf:connect_start</code>. Each attempt ends with
            <code>lf:connect_end</code>
            or <code>lf:connect_cancel</code>
            (<code>reason</code>: <b>pane</b>, <b>invalid</b>
            or <b>abort</b>, plus the release <code>position</code>).
          </.hint>
          <.hint>
            Drag from a handle and release it on another node, on the pane, or press
            <.kbd>Esc</.kbd>
            while connecting. Click a handle, then another one, to connect on click.
          </.hint>
          <.hint>
            Select an edge and drag one of its ends to fire <code>lf:reconnect_edge</code>; drop it on the pane for <code>lf:delete_reconnect_edge</code>.
          </.hint>
        </.option_group>

        <.option_group title="Timeline">
          <div class="mb-3 flex items-center justify-between">
            <span id="attempt-count" class="text-xs text-base-content/50">
              {length(@attempts)} {if length(@attempts) == 1, do: "attempt", else: "attempts"}
            </span>
            <button
              id="clear-timeline"
              type="button"
              phx-click="clear_timeline"
              disabled={@attempts == []}
              class="inline-flex items-center gap-1 rounded-md px-2 py-1 text-xs text-base-content/60 transition-colors hover:bg-base-200 hover:text-base-content disabled:pointer-events-none disabled:opacity-40"
            >
              <.icon name="hero-trash-mini" class="size-3.5" /> Clear
            </button>
          </div>

          <ol id="attempts" class="space-y-2.5">
            <li
              :if={@attempts == []}
              id="attempts-empty"
              class="rounded-lg border border-dashed border-base-300 px-3 py-4 text-center text-xs text-base-content/45"
            >
              Start dragging from a handle…
            </li>
            <li
              :for={attempt <- @attempts}
              id={"attempt-#{attempt.id}"}
              data-status={attempt.status}
              class={[
                "rounded-lg border bg-base-100 p-2.5 shadow-xs transition-colors",
                if(attempt.status == :pending,
                  do: "border-amber-400/60",
                  else: "border-base-300"
                )
              ]}
            >
              <div class="mb-2 flex items-center justify-between gap-2">
                <span class="text-xs font-semibold">
                  #{attempt.id}
                  <span class="font-normal text-base-content/50">
                    {if attempt.kind == :reconnect, do: "reconnect", else: "connect"}
                  </span>
                </span>
                <.status_badge status={attempt.status} />
              </div>

              <ol class="ml-1 space-y-1.5 border-l border-base-300 pl-3">
                <li
                  :for={{step, index} <- Enum.with_index(attempt.steps)}
                  id={"attempt-#{attempt.id}-step-#{index}"}
                  class="relative"
                >
                  <span class={[
                    "absolute top-1 -left-[16.5px] size-2 rounded-full ring-2 ring-base-100",
                    step_color(step.event)
                  ]} />
                  <div class="flex items-baseline justify-between gap-2 font-mono text-[11px]">
                    <span class="font-semibold text-base-content/85">{step.event}</span>
                    <span class="shrink-0 text-base-content/40">
                      {if index == 0,
                        do: Calendar.strftime(step.at, "%H:%M:%S"),
                        else: "+#{step.ms - hd(attempt.steps).ms} ms"}
                    </span>
                  </div>
                  <p class="text-[11px] leading-snug text-base-content/60">{step.detail}</p>
                </li>
              </ol>
            </li>
          </ol>
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-medium",
      badge_class(@status)
    ]}>
      <span :if={@status == :pending} class="size-1.5 animate-pulse rounded-full bg-current" />
      {badge_label(@status)}
    </span>
    """
  end

  defp badge_class(:pending), do: "bg-amber-500/15 text-amber-600"
  defp badge_class(:connected), do: "bg-emerald-500/15 text-emerald-600"
  defp badge_class(:reconnected), do: "bg-sky-500/15 text-sky-600"
  defp badge_class(:rejected), do: "bg-rose-500/15 text-rose-600"
  defp badge_class(:removed), do: "bg-rose-500/15 text-rose-600"
  defp badge_class(:cancelled), do: "bg-base-300 text-base-content/60"

  defp badge_label(:pending), do: "connecting"
  defp badge_label(status), do: Atom.to_string(status)

  defp step_color("lf:connect_start"), do: "bg-amber-500"
  defp step_color("lf:connect_end"), do: "bg-emerald-500"
  defp step_color("lf:connect_cancel"), do: "bg-base-content/40"
  defp step_color("lf:reconnect_edge"), do: "bg-sky-500"
  defp step_color(_event), do: "bg-rose-500"

  # ===== Connection events =====

  @impl true
  def handle_event("lf:connect_start", params, socket) do
    detail = "from #{params["node_id"]} · #{handle_label(params)}"

    socket
    |> start_attempt(:connect, step("lf:connect_start", detail))
    |> noreply()
  end

  def handle_event("lf:connect_end", params, socket) do
    connection = "#{params["source"]} → #{params["target"]}"

    case Connection.validate_and_create(socket.assigns.flow, params,
           edge_opts: [type: :smoothstep, reconnectable: true]
         ) do
      {:ok, edge} ->
        socket
        |> FlowEvents.snapshot()
        |> assign(:flow, State.add_edge(socket.assigns.flow, edge))
        |> finish_attempt(:connected, step("lf:connect_end", "#{connection} · edge #{edge.id}"))
        |> noreply()

      {:error, reason} ->
        socket
        |> finish_attempt(:rejected, step("lf:connect_end", "#{connection} · #{reason}"))
        |> noreply()
    end
  end

  def handle_event("lf:connect_cancel", params, socket) do
    %{"x" => x, "y" => y} = params["position"] || %{"x" => 0, "y" => 0}

    detail =
      "reason: #{params["reason"]} · released at (#{round(x)}, #{round(y)})"

    socket
    |> finish_attempt(:cancelled, step("lf:connect_cancel", detail))
    |> noreply()
  end

  def handle_event("lf:reconnect_edge", params, socket) do
    {:noreply, socket} = FlowEvents.handle_event("lf:reconnect_edge", params, socket)

    detail =
      "#{params["edge_id"]}: #{params["end"]} → #{params["node_id"]}" <>
        if(params["handle_id"], do: " (#{params["handle_id"]})", else: "")

    socket
    |> start_attempt(:reconnect, step("lf:reconnect_edge", detail), :reconnected)
    |> noreply()
  end

  def handle_event("lf:delete_reconnect_edge", params, socket) do
    {:noreply, socket} = FlowEvents.handle_event("lf:delete_reconnect_edge", params, socket)
    detail = "#{params["edge_id"]} dropped on the pane · deleted"

    socket
    |> start_attempt(:reconnect, step("lf:delete_reconnect_edge", detail), :removed)
    |> noreply()
  end

  def handle_event("clear_timeline", _params, socket) do
    {:noreply, assign(socket, attempts: [], attempt_seq: 0)}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Timeline =====

  defp step(event, detail) do
    %{
      event: event,
      detail: detail,
      at: Time.utc_now() |> Time.truncate(:second),
      ms: System.monotonic_time(:millisecond)
    }
  end

  defp start_attempt(socket, kind, step, status \\ :pending) do
    id = socket.assigns.attempt_seq + 1
    attempt = %{id: id, kind: kind, status: status, steps: [step]}

    socket
    |> assign(:attempt_seq, id)
    |> assign(:attempts, Enum.take([attempt | socket.assigns.attempts], @max_attempts))
  end

  # Appends the final event to the attempt in progress (or starts a new one
  # when the start event was missed, e.g. after clearing the timeline)
  defp finish_attempt(socket, status, step) do
    case socket.assigns.attempts do
      [%{status: :pending} = attempt | rest] ->
        attempt = %{attempt | status: status, steps: attempt.steps ++ [step]}
        assign(socket, :attempts, [attempt | rest])

      _attempts ->
        start_attempt(socket, :connect, step, status)
    end
  end

  defp handle_label(%{"handle_type" => type, "handle_id" => id}) when is_binary(id),
    do: "#{type} handle “#{id}”"

  defp handle_label(%{"handle_type" => type}), do: "#{type} handle"

  defp noreply(socket), do: {:noreply, socket}

  # ===== Initial graph =====

  defp build_flow do
    nodes = [
      Node.new("1", %{x: 0, y: 120}, %{label: "Node 1"}, handles: [Handle.source(:right)]),
      Node.new("2", %{x: 280, y: 0}, %{label: "Node 2"}),
      Node.new("3", %{x: 280, y: 240}, %{label: "Node 3"},
        handles: [
          Handle.target(:left),
          Handle.source(:right, id: "a"),
          Handle.source(:bottom, id: "b")
        ]
      ),
      Node.new("4", %{x: 560, y: 120}, %{label: "Node 4"}, handles: [Handle.target(:left)])
    ]

    edges = [
      Edge.new("e1-2", "1", "2", type: :smoothstep, reconnectable: true),
      Edge.new("e2-4", "2", "4", type: :smoothstep, reconnectable: true)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

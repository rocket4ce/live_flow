defmodule FlowExampleWeb.Examples.Interaction.PreventCyclesLive do
  @moduledoc """
  Preventing Cycles: check if a new connection would cause a cycle in the graph.

  `lf:connect_end` is validated on the server with
  `LiveFlow.Validation.Connection.validate_and_create/3` and the
  `LiveFlow.Validation.no_cycles/2` validator. Rejected connections are never
  added; the sidebar explains why and the path that would have closed the
  loop is highlighted for a moment (decorated at render time, so the flow
  state and the undo history stay clean).
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Node, State, Validation}
  alias LiveFlow.Validation.Connection

  @highlight_ms 3000
  @max_attempts 8

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(attempts: [], attempt_seq: 0, highlight: nil)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #prevent-cycles .cycle-edge .lf-edge {
        stroke: #f43f5e;
        stroke-width: 2.5;
        stroke-dasharray: 6 4;
        animation: prevent-cycles-dash 0.5s linear infinite;
      }
      #prevent-cycles .lf-node.cycle-node {
        border-color: #f43f5e;
        box-shadow: 0 0 0 4px color-mix(in oklab, #f43f5e 22%, transparent);
        transition: box-shadow 200ms ease, border-color 200ms ease;
      }
      @keyframes prevent-cycles-dash {
        to {
          stroke-dashoffset: -10;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="prevent-cycles"
        flow={decorate(@flow, @highlight)}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.25},
            connection_line_type: :smoothstep
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Every <code>lf:connect_end</code>
            goes through <code>Connection.validate_and_create/3</code>
            with <code>validators: Validation.preset(:default) ++ [&amp;Validation.no_cycles/2]</code>.
          </.hint>
          <.hint>
            <code>no_cycles/2</code>
            rejects a connection when the target already reaches the source. Try connecting
            <b>Node 5</b>
            back to <b>Node 1</b>, or <b>Node 4</b>
            to <b>Node 2</b>.
          </.hint>
        </.option_group>

        <.option_group title="Last attempt">
          <%= case @attempts do %>
            <% [] -> %>
              <p id="cycle-empty" class="text-xs text-base-content/45">
                Connect two nodes to validate the connection…
              </p>
            <% [%{result: :rejected} = attempt | _] -> %>
              <div
                id="cycle-notice"
                class="rounded-lg border border-rose-500/30 bg-rose-500/8 p-3 text-xs"
              >
                <p class="flex items-center gap-1.5 font-semibold text-rose-600">
                  <.icon name="hero-no-symbol-mini" class="size-4" /> Connection rejected
                </p>
                <p class="mt-1 text-base-content/70">{attempt.reason}.</p>
                <p :if={attempt.cycle} class="mt-2 font-mono text-[11px] text-base-content/60">
                  {Enum.join(attempt.cycle, " → ")}
                </p>
              </div>
            <% [attempt | _] -> %>
              <div
                id="connection-accepted"
                class="rounded-lg border border-emerald-500/30 bg-emerald-500/8 p-3 text-xs"
              >
                <p class="flex items-center gap-1.5 font-semibold text-emerald-600">
                  <.icon name="hero-check-circle-mini" class="size-4" /> Connection added
                </p>
                <p class="mt-1 font-mono text-[11px] text-base-content/60">
                  {attempt.source_label} → {attempt.target_label}
                </p>
              </div>
          <% end %>
        </.option_group>

        <.option_group title="Attempts">
          <ul id="cycle-attempts" class="space-y-1">
            <li :if={@attempts == []} class="text-xs text-base-content/40">None yet</li>
            <li
              :for={attempt <- @attempts}
              id={"cycle-attempt-#{attempt.id}"}
              data-result={attempt.result}
              class="flex items-center gap-2 rounded-md bg-base-200/70 px-2 py-1 text-xs"
            >
              <.icon
                name={if attempt.result == :ok, do: "hero-check-mini", else: "hero-x-mark-mini"}
                class={[
                  "size-4 shrink-0",
                  if(attempt.result == :ok, do: "text-emerald-600", else: "text-rose-600")
                ]}
              />
              <span class="font-mono">{attempt.source_label} → {attempt.target_label}</span>
            </li>
          </ul>
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("lf:connect_end", params, socket) do
    flow = socket.assigns.flow
    validators = Validation.preset(:default) ++ [&Validation.no_cycles/2]

    case Connection.validate_and_create(flow, params,
           validators: validators,
           edge_opts: [type: :smoothstep]
         ) do
      {:ok, edge} ->
        socket
        |> FlowEvents.snapshot()
        |> assign(flow: State.add_edge(flow, edge), highlight: nil)
        |> add_attempt(params, :ok, nil, nil)
        |> noreply()

      {:error, reason} ->
        path = cycle_path(flow, params["target"], params["source"])
        token = make_ref()
        if path, do: Process.send_after(self(), {:clear_highlight, token}, @highlight_ms)

        highlight =
          path &&
            %{
              token: token,
              edges: MapSet.new(path, & &1.id),
              nodes:
                MapSet.new([params["source"], params["target"] | Enum.map(path, & &1.target)])
            }

        cycle =
          path &&
            Enum.map(
              [params["source"], params["target"] | Enum.map(path, & &1.target)],
              &label(flow, &1)
            )

        socket
        |> assign(:highlight, highlight)
        |> add_attempt(params, :rejected, reason, cycle)
        |> noreply()
    end
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:clear_highlight, token}, %{assigns: %{highlight: %{token: token}}} = socket) do
    {:noreply, assign(socket, :highlight, nil)}
  end

  def handle_info({:clear_highlight, _stale}, socket), do: {:noreply, socket}

  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Helpers =====

  defp add_attempt(socket, params, result, reason, cycle) do
    flow = socket.assigns.flow
    id = socket.assigns.attempt_seq + 1

    attempt = %{
      id: id,
      result: result,
      reason: reason,
      cycle: cycle,
      source_label: label(flow, params["source"]),
      target_label: label(flow, params["target"])
    }

    socket
    |> assign(:attempt_seq, id)
    |> assign(:attempts, Enum.take([attempt | socket.assigns.attempts], @max_attempts))
    |> FlowEvents.log(
      "lf:connect_end",
      if(reason, do: Map.put(params, "rejected", reason), else: params)
    )
  end

  # Edges of the shortest path `from` -> `to` (breadth-first), or nil
  defp cycle_path(_flow, nil, _to), do: nil
  defp cycle_path(_flow, from, from), do: []
  defp cycle_path(flow, from, to), do: bfs([{from, []}], MapSet.new([from]), flow, to)

  defp bfs([], _seen, _flow, _to), do: nil

  defp bfs([{node, path} | rest], seen, flow, to) do
    if node == to do
      Enum.reverse(path)
    else
      next =
        flow.edges
        |> Map.values()
        |> Enum.filter(&(&1.source == node and not MapSet.member?(seen, &1.target)))
        |> Enum.sort_by(& &1.id)

      seen = Enum.reduce(next, seen, &MapSet.put(&2, &1.target))
      bfs(rest ++ Enum.map(next, &{&1.target, [&1 | path]}), seen, flow, to)
    end
  end

  # Adds the highlight classes at render time only
  defp decorate(flow, nil), do: flow

  defp decorate(%State{} = flow, %{edges: edge_ids, nodes: node_ids}) do
    %{
      flow
      | edges:
          Map.new(flow.edges, fn {id, edge} ->
            {id, if(id in edge_ids, do: %{edge | class: "cycle-edge"}, else: edge)}
          end),
        nodes:
          Map.new(flow.nodes, fn {id, node} ->
            {id, if(id in node_ids, do: %{node | class: "cycle-node"}, else: node)}
          end)
    }
  end

  defp label(flow, id) do
    case State.get_node(flow, id) do
      %Node{data: %{label: label}} -> label
      _other -> to_string(id)
    end
  end

  defp noreply(socket), do: {:noreply, socket}

  # ===== Initial graph =====

  defp build_flow do
    nodes = [
      Node.new("1", %{x: 0, y: 120}, %{label: "Node 1"}),
      Node.new("2", %{x: 240, y: 0}, %{label: "Node 2"}),
      Node.new("3", %{x: 240, y: 240}, %{label: "Node 3"}),
      Node.new("4", %{x: 480, y: 120}, %{label: "Node 4"}),
      Node.new("5", %{x: 720, y: 120}, %{label: "Node 5"}),
      Node.new("6", %{x: 720, y: 280}, %{label: "Node 6"})
    ]

    edges = [
      Edge.new("e1-2", "1", "2", type: :smoothstep),
      Edge.new("e1-3", "1", "3", type: :smoothstep),
      Edge.new("e2-4", "2", "4", type: :smoothstep),
      Edge.new("e3-4", "3", "4", type: :smoothstep),
      Edge.new("e4-5", "4", "5", type: :smoothstep, animated: true)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

defmodule FlowExampleWeb.Examples.Interaction.ComputingFlowsLive do
  @moduledoc """
  Computing Flows: nodes compute their values from the nodes connected to them.

  Text nodes hold a value edited through a form inside the node, the
  uppercase node transforms the value of its incomer and the result node
  lists every value flowing into it (`LiveFlow.State.incomers/2`).

  Derived values are recomputed on the server after every change (typing,
  connecting, deleting, undo...), so the graph is the single source of truth.
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
     |> assign(example: example, page_title: example.title, next_text: 3)
     |> FlowEvents.assign_flow(compute(build_flow()))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="add-text-node" icon="hero-plus" phx-click="add_text_node">
          Add text node
        </.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="computing-flows"
        flow={@flow}
        node_types={%{text: &text_node/1, uppercase: &uppercase_node/1, result: &result_node/1}}
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
            Type in a <b>Text</b>
            node: its form pushes a regular <code>phx-change</code>
            and the server stores the value in the node's <code>data</code>.
          </.hint>
          <.hint>
            Every change recomputes the derived nodes: <b>Uppercase</b>
            transforms the value of its incomer, <b>Result</b>
            lists the values of all its incomers (<code>State.incomers/2</code>).
          </.hint>
          <.hint>
            Connect, delete or reconnect edges and the values follow. Connections are validated
            with <code>Validation.no_cycles/2</code> and the uppercase node accepts a single input.
          </.hint>
        </.option_group>

        <.option_group title="Node outputs">
          <div id="node-outputs" class="space-y-1">
            <div
              :for={{id, label, value} <- outputs(@flow)}
              id={"output-#{id}"}
              class="flex items-center justify-between gap-3 rounded-md bg-base-200/70 px-2 py-1 text-xs"
            >
              <span class="text-base-content/60">{label}</span>
              <span class={[
                "truncate font-mono",
                if(value in [nil, ""], do: "text-base-content/35", else: "text-base-content")
              ]}>
                {display(value)}
              </span>
            </div>
          </div>
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

  defp text_node(assigns) do
    ~H"""
    <form
      id={"text-form-#{@node.id}"}
      class="w-52"
      phx-change="update_text"
      phx-submit="update_text"
    >
      <.node_header icon="hero-pencil-square-mini" label={@node.data.label} />
      <input type="hidden" name="node_id" value={@node.id} />
      <.input
        id={"text-input-#{@node.id}"}
        type="text"
        name="text"
        value={@node.data.text}
        autocomplete="off"
        phx-debounce="80"
        class="nodrag w-full rounded-md border bg-transparent px-2 py-1 text-sm transition-colors focus:border-primary focus:outline-none"
        style="color: var(--lf-text-primary); border-color: var(--lf-node-border)"
      />
    </form>
    """
  end

  attr :node, :map, required: true

  defp uppercase_node(assigns) do
    ~H"""
    <div class="w-52">
      <.node_header icon="hero-arrow-up-circle-mini" label="Uppercase" />
      <p
        id={"value-#{@node.id}"}
        class="truncate rounded-md px-2 py-1 font-mono text-sm"
        style="background: color-mix(in oklab, var(--lf-text-primary) 6%, transparent); color: var(--lf-text-primary)"
      >
        <%= if @node.data.value in [nil, ""] do %>
          <span style="color: var(--lf-text-secondary)">connect a text node</span>
        <% else %>
          {@node.data.value}
        <% end %>
      </p>
    </div>
    """
  end

  attr :node, :map, required: true

  defp result_node(assigns) do
    ~H"""
    <div class="w-56">
      <.node_header icon="hero-sparkles-mini" label="Result" />
      <p class="mb-1.5 text-[11px]" style="color: var(--lf-text-secondary)">
        Incoming texts ({length(@node.data.inputs)})
      </p>
      <div id={"inputs-#{@node.id}"} class="flex flex-wrap gap-1">
        <span
          :for={input <- @node.data.inputs}
          id={"result-#{@node.id}-#{input.id}"}
          class="max-w-full truncate rounded-full bg-primary/10 px-2 py-0.5 font-mono text-xs text-primary"
          title={input.label}
        >
          {display(input.value)}
        </span>
        <span
          :if={@node.data.inputs == []}
          class="text-xs italic"
          style="color: var(--lf-text-secondary)"
        >
          Nothing connected
        </span>
      </div>
    </div>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp node_header(assigns) do
    ~H"""
    <p
      class="mb-1.5 flex items-center gap-1.5 text-[11px] font-semibold uppercase tracking-wide"
      style="color: var(--lf-text-secondary)"
    >
      <.icon name={@icon} class="size-3.5" /> {@label}
    </p>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("update_text", %{"node_id" => id, "text" => text}, socket) do
    flow =
      State.update_node(socket.assigns.flow, id, fn
        %Node{type: :text} = node -> %{node | data: Map.put(node.data, :text, text)}
        node -> node
      end)

    {:noreply, assign(socket, :flow, compute(flow))}
  end

  def handle_event("add_text_node", _params, socket) do
    n = socket.assigns.next_text
    node = text("text-#{n}", 0, 220 + 130 * (n - 2), "Text #{n}", "")

    socket
    |> FlowEvents.snapshot()
    |> assign(:next_text, n + 1)
    |> assign(:flow, socket.assigns.flow |> State.add_node(node) |> compute())
    |> FlowEvents.log("add_text_node", %{"id" => node.id})
    |> noreply()
  end

  # Connections: default checks + no cycles + a single input for uppercase nodes
  def handle_event("lf:connect_end", params, socket) do
    validators = Validation.preset(:default) ++ [&Validation.no_cycles/2, &single_input/2]

    case Connection.validate_and_create(socket.assigns.flow, params,
           validators: validators,
           edge_opts: [type: :smoothstep, animated: true]
         ) do
      {:ok, edge} ->
        socket
        |> FlowEvents.snapshot()
        |> assign(:flow, socket.assigns.flow |> State.add_edge(edge) |> compute())
        |> FlowEvents.log("lf:connect_end", params)
        |> noreply()

      {:error, reason} ->
        socket
        |> FlowEvents.log("lf:connect_end", Map.put(params, "rejected", reason))
        |> noreply()
    end
  end

  # Everything else (deletes, reconnects, undo...) may change the graph
  def handle_event("lf:" <> _ = event, params, socket) do
    {:noreply, socket} = FlowEvents.handle_event(event, params, socket)
    {:noreply, assign(socket, :flow, compute(socket.assigns.flow))}
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Computation =====

  # Stores the derived values in the data of the uppercase and result nodes
  defp compute(%State{} = flow) do
    Enum.reduce(flow.nodes, flow, fn
      {id, %Node{type: :uppercase}}, acc ->
        State.update_node(acc, id, &put_data(&1, :value, output(flow, id)))

      {id, %Node{type: :result}}, acc ->
        State.update_node(acc, id, &put_data(&1, :inputs, inputs(flow, id)))

      _other, acc ->
        acc
    end)
  end

  defp put_data(node, key, value), do: %{node | data: Map.put(node.data, key, value)}

  # Value flowing out of a node (nil when it has none). `seen` guards against
  # cycles even though the validators already reject them.
  defp output(flow, id, seen \\ MapSet.new()) do
    node = State.get_node(flow, id)

    cond do
      is_nil(node) or MapSet.member?(seen, id) ->
        nil

      node.type == :text ->
        node.data.text

      node.type == :uppercase ->
        case State.incomers(flow, id) do
          [input | _] -> flow |> output(input.id, MapSet.put(seen, id)) |> upcase()
          [] -> nil
        end

      true ->
        nil
    end
  end

  defp inputs(flow, id) do
    flow
    |> State.incomers(id)
    |> Enum.sort_by(&{&1.position.y, &1.id})
    |> Enum.map(&%{id: &1.id, label: label(&1), value: output(flow, &1.id)})
  end

  defp single_input(flow, %{target: target}) do
    case State.get_node(flow, target) do
      %Node{type: :uppercase} ->
        if State.incomers(flow, target) == [],
          do: :ok,
          else: {:error, "Uppercase takes a single input"}

      _other ->
        :ok
    end
  end

  defp outputs(flow) do
    flow.nodes
    |> Map.values()
    |> Enum.reject(&(&1.type == :result))
    |> Enum.sort_by(&{&1.position.x, &1.position.y})
    |> Enum.map(&{&1.id, label(&1), output(flow, &1.id)})
  end

  defp label(%Node{type: :uppercase}), do: "Uppercase"
  defp label(%Node{data: data}), do: Map.get(data, :label, "Node")

  defp upcase(nil), do: nil
  defp upcase(text), do: String.upcase(text)

  defp display(value) when value in [nil, ""], do: "∅"
  defp display(value), do: value

  defp noreply(socket), do: {:noreply, socket}

  # ===== Initial graph =====

  defp build_flow do
    nodes = [
      text("text-1", 0, 0, "Text A", "hello"),
      text("text-2", 0, 220, "Text B", "world"),
      Node.new("upper", %{x: 340, y: 10}, %{value: nil},
        type: :uppercase,
        handles: [Handle.target(:left), Handle.source(:right)]
      ),
      Node.new("result", %{x: 680, y: 110}, %{inputs: []},
        type: :result,
        handles: [Handle.target(:left)]
      )
    ]

    edges = [
      Edge.new("e-text-1-upper", "text-1", "upper", type: :smoothstep, animated: true),
      Edge.new("e-upper-result", "upper", "result", type: :smoothstep, animated: true),
      Edge.new("e-text-2-result", "text-2", "result", type: :smoothstep, animated: true)
    ]

    State.new(nodes: nodes, edges: edges)
  end

  defp text(id, x, y, label, value) do
    Node.new(id, %{x: x, y: y}, %{label: label, text: value},
      type: :text,
      handles: [Handle.source(:right)]
    )
  end
end

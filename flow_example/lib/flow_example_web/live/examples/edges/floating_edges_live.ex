defmodule FlowExampleWeb.Examples.Edges.FloatingEdgesLive do
  @moduledoc """
  Floating Edges: instead of a fixed handle, edges attach to the point of the
  node's border that faces the other node.

  Edges are created with `source_floating: true` / `target_floating: true`.
  The server computes the attachment point (`LiveFlow.Paths.Geometry`) and
  the client mirrors it while nodes are dragged. New connections are floating
  too: FlowEvents builds them with the `edge_opts` assign.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}

  @path_types ~w(bezier straight smoothstep step)

  @satellites [
    {"phoenix", "Phoenix", "hero-fire"},
    {"liveview", "LiveView", "hero-bolt"},
    {"ecto", "Ecto", "hero-circle-stack"},
    {"oban", "Oban", "hero-queue-list"},
    {"nx", "Nx", "hero-cpu-chip"},
    {"broadway", "Broadway", "hero-arrows-right-left"},
    {"req", "Req", "hero-globe-alt"},
    {"bandit", "Bandit", "hero-server"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    settings = %{
      "path_type" => "bezier",
      "source_floating" => "true",
      "target_floating" => "true"
    }

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, path_types: @path_types)
     |> FlowEvents.assign_flow(build_flow())
     |> apply_settings(settings)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #floating-edges-flow .lf-node[data-node-type="bubble"] {
        border-radius: 9999px;
      }
      #floating-edges-flow .lf-node[data-node-type="bubble"] .lf-node-content {
        padding: 8px 16px 8px 8px;
      }
      #floating-edges-flow .lf-node[data-node-type="bubble"].is-hub {
        border-width: 2px;
        border-color: #8b5cf6;
        box-shadow: 0 0 0 6px rgb(139 92 246 / 0.12);
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="floating-edges-flow"
        flow={@flow}
        node_types={%{bubble: &bubble_node/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.15},
            connection_line_type: :straight
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Drag the nodes around: every edge leaves and enters its nodes at the border point facing
            the other node, whatever handles the nodes have.
          </.hint>
          <.hint>
            Edges use <code>source_floating: true</code>
            and <code>target_floating: true</code>. The server and the client compute the same
            attachment point, so edges stay attached during drags.
          </.hint>
          <.hint>
            Connect two nodes (bottom handle → top handle): FlowEvents creates the edge with <code>edge_opts</code>, so it floats too.
          </.hint>
        </.option_group>

        <.form for={@form} id="floating-form" phx-change="update_settings">
          <.option_group title="Path type">
            <.input
              field={@form[:path_type]}
              type="select"
              label="type"
              class={select_class()}
              options={@path_types}
            />
          </.option_group>
          <.option_group title="Floating ends">
            <.input
              field={@form[:source_floating]}
              type="checkbox"
              label="source_floating"
              class={switch_class()}
            />
            <.input
              field={@form[:target_floating]}
              type="checkbox"
              label="target_floating"
              class={switch_class()}
            />
            <.hint>Turn them off to compare with fixed handles (bottom → top).</.hint>
          </.option_group>
        </.form>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp bubble_node(assigns) do
    ~H"""
    <div class="flex items-center gap-2.5 whitespace-nowrap">
      <span class={[
        "grid size-8 place-items-center rounded-full",
        if(@node.data[:hub], do: "bg-violet-500 text-white", else: "bg-violet-500/15 text-violet-500")
      ]}>
        <.icon name={@node.data.icon} class="size-4" />
      </span>
      <span class="text-sm font-semibold" style="color: var(--lf-text-primary)">
        {@node.data.label}
      </span>
    </div>
    """
  end

  @impl true
  def handle_event("update_settings", %{"floating" => params}, socket) do
    {:noreply, apply_settings(socket, params)}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # Applies the sidebar settings to every edge and to `edge_opts` (read by
  # FlowEvents when a connection is made)
  defp apply_settings(socket, params) do
    path_type = if params["path_type"] in @path_types, do: params["path_type"], else: "bezier"

    opts = [
      type: String.to_existing_atom(path_type),
      source_floating: params["source_floating"] == "true",
      target_floating: params["target_floating"] == "true"
    ]

    flow = socket.assigns.flow
    edges = Map.new(flow.edges, fn {id, edge} -> {id, Edge.update(edge, opts)} end)

    socket
    |> assign(:flow, %{flow | edges: edges})
    |> assign(:edge_opts, opts ++ [marker_end: %{type: :arrow_closed}])
    |> assign(:form, to_form(Map.put(params, "path_type", path_type), as: :floating))
  end

  defp build_flow do
    handles = [Handle.target(:top), Handle.source(:bottom)]
    radius = 300
    count = length(@satellites)

    hub =
      Node.new("elixir", %{x: -70, y: -24}, %{label: "Elixir", icon: "hero-beaker", hub: true},
        type: :bubble,
        class: "is-hub",
        handles: handles
      )

    satellites =
      @satellites
      |> Enum.with_index()
      |> Enum.map(fn {{id, label, icon}, i} ->
        angle = 2 * :math.pi() * i / count - :math.pi() / 2
        x = round(radius * :math.cos(angle)) - 60
        y = round(radius * :math.sin(angle)) - 24

        Node.new(id, %{x: x, y: y}, %{label: label, icon: icon}, type: :bubble, handles: handles)
      end)

    # Every other edge points inwards
    edges =
      @satellites
      |> Enum.with_index()
      |> Enum.map(fn {{id, _label, _icon}, i} ->
        {source, target} = if rem(i, 2) == 0, do: {"elixir", id}, else: {id, "elixir"}

        Edge.new("e-#{source}-#{target}", source, target, marker_end: %{type: :arrow_closed})
      end)

    State.new(nodes: [hub | satellites], edges: edges)
  end
end

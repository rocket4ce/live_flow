defmodule FlowExampleWeb.Examples.Nodes.NodePositionAnimationLive do
  @moduledoc """
  Node Position Animation: animated transitions between graph layouts.

  The tree layouts come from `LiveFlow.Layout.tree/2`, the force layout from
  `LiveFlow.Layout.force/2`; the circle and the grid are computed here. The
  positions are sent with `LiveFlow.animate_positions/5`: the client animates
  nodes and edges, fits the view and pushes the final positions back as a
  regular `lf:node_change`.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Layout, Node, State}

  @flow_id "node-position-animation"
  # Rendered size of a node (140 x 40 content + 1px border)
  @node_width 142
  @node_height 42

  @layouts [
    %{id: "tree-tb", label: "Tree ↓", icon: "hero-arrow-down-circle"},
    %{id: "tree-lr", label: "Tree →", icon: "hero-arrow-right-circle"},
    %{id: "force", label: "Force", icon: "hero-share"},
    %{id: "circle", label: "Circle", icon: "hero-arrow-path-rounded-square"},
    %{id: "grid", label: "Grid", icon: "hero-squares-2x2"},
    %{id: "random", label: "Random", icon: "hero-sparkles"}
  ]

  # {id, label, group, parent} in depth-first order (also the circle/grid order)
  @services [
    {"gateway", "API Gateway", :core, nil},
    {"auth", "Auth", :identity, "gateway"},
    {"users", "Users", :identity, "auth"},
    {"sessions", "Sessions", :identity, "auth"},
    {"catalog", "Catalog", :catalog, "gateway"},
    {"search", "Search", :catalog, "catalog"},
    {"images", "Images", :catalog, "catalog"},
    {"pricing", "Pricing", :catalog, "catalog"},
    {"orders", "Orders", :orders, "gateway"},
    {"payments", "Payments", :orders, "orders"},
    {"shipping", "Shipping", :orders, "orders"},
    {"notify", "Notifications", :orders, "orders"}
  ]

  @colors %{
    core: "#f59e0b",
    identity: "#8b5cf6",
    catalog: "#0ea5e9",
    orders: "#10b981"
  }

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)
    params = %{"duration" => "800"}
    flow = build_flow()
    flow = Layout.apply_positions(flow, positions(flow, "tree-tb"))

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(layouts: @layouts, active_layout: "tree-tb", params: params)
     |> assign(:form, to_form(params, as: :animation))
     |> FlowEvents.assign_flow(flow)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #node-position-animation .lf-node-content {
        min-width: 0;
        padding: 0;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="node-position-animation"
        flow={@flow}
        node_types={%{service: &service_node/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            minimap: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.15}
          }
        }
      />

      <:sidebar>
        <.option_group title="Layout">
          <div id="layout-buttons" class="grid grid-cols-3 gap-2">
            <button
              :for={layout <- @layouts}
              id={"layout-#{layout.id}"}
              type="button"
              phx-click="layout"
              phx-value-layout={layout.id}
              class={[
                "group flex flex-col items-center gap-1.5 rounded-xl border px-2 py-3 text-xs font-medium transition-all duration-150 hover:-translate-y-0.5 active:scale-95",
                if(layout.id == @active_layout,
                  do: "border-primary/40 bg-primary/10 text-primary shadow-sm",
                  else:
                    "border-base-300 bg-base-100 text-base-content/70 hover:border-base-content/20 hover:text-base-content hover:shadow-sm"
                )
              ]}
            >
              <.icon
                name={layout.icon}
                class="size-5 transition-transform duration-200 group-hover:scale-110"
              />
              {layout.label}
            </button>
          </div>
        </.option_group>

        <.option_group title="Animation">
          <.form for={@form} id="animation-options" phx-change="set_duration">
            <.range
              field={@form[:duration]}
              label="Duration (ms)"
              min="100"
              max="2000"
              step="100"
            />
          </.form>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            Each button computes a <code phx-no-curly-interpolation>%{id => %{x, y}}</code>
            map on the server: <code>Layout.tree/2</code>
            (both directions), <code>Layout.force/2</code>
            (starting from the current positions), or a circle / grid / random placement computed in
            the LiveView.
          </.hint>
          <.hint>
            <code>LiveFlow.animate_positions(socket, id, flow, positions, duration: ms, fit_view: true)</code>
            animates the nodes and their edges on the client, fits the view and pushes the final
            positions back as <code>lf:node_change</code>: the state is never updated by hand.
          </.hint>
          <.hint>
            Edges use <code>source_floating</code>
            and <code>target_floating</code>, so they attach to the closest side in every layout.
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

  defp service_node(assigns) do
    ~H"""
    <div class="flex h-10 w-[140px] items-center gap-2 px-3">
      <span
        class="size-2.5 shrink-0 rounded-full ring-4"
        style={"background: #{@node.data.color}; --tw-ring-color: color-mix(in oklab, #{@node.data.color} 20%, transparent)"}
      ></span>
      <span class="truncate text-[13px] font-semibold" style="color: var(--lf-text-primary)">
        {@node.data.label}
      </span>
    </div>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("layout", %{"layout" => layout}, socket) do
    case Enum.find(@layouts, &(&1.id == layout)) do
      %{id: id} ->
        flow = socket.assigns.flow
        duration = String.to_integer(socket.assigns.params["duration"])

        {:noreply,
         socket
         |> assign(:active_layout, id)
         |> LiveFlow.animate_positions(@flow_id, flow, positions(flow, id),
           duration: duration,
           fit_view: %{padding: 0.15}
         )
         |> FlowEvents.log("layout", %{"layout" => id, "duration" => duration})}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("set_duration", %{"animation" => %{"duration" => duration}}, socket) do
    params =
      case Integer.parse(to_string(duration)) do
        {ms, ""} -> %{"duration" => Integer.to_string(ms |> max(100) |> min(2000))}
        _ -> socket.assigns.params
      end

    {:noreply, assign(socket, params: params, form: to_form(params, as: :animation))}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Layouts =====

  defp positions(flow, "tree-tb"),
    do: Layout.tree(flow, direction: :tb, node_spacing: 28, rank_spacing: 90)

  defp positions(flow, "tree-lr"),
    do: Layout.tree(flow, direction: :lr, node_spacing: 22, rank_spacing: 130)

  defp positions(flow, "force"), do: Layout.force(flow, iterations: 300, distance: 190)

  defp positions(_flow, "circle") do
    count = length(@services)
    # Leave roughly one node width between neighbours
    radius = max(260, count * (@node_width + 40) / (2 * :math.pi()))

    @services
    |> Enum.with_index()
    |> Map.new(fn {{id, _, _, _}, i} ->
      angle = 2 * :math.pi() * i / count - :math.pi() / 2

      {id,
       %{
         x: radius * :math.cos(angle) - @node_width / 2,
         y: radius * :math.sin(angle) - @node_height / 2
       }}
    end)
  end

  defp positions(_flow, "grid") do
    columns = ceil(:math.sqrt(length(@services)))

    @services
    |> Enum.with_index()
    |> Map.new(fn {{id, _, _, _}, i} ->
      {id, %{x: rem(i, columns) * (@node_width + 60), y: div(i, columns) * (@node_height + 80)}}
    end)
  end

  defp positions(_flow, "random") do
    Map.new(@services, fn {id, _, _, _} ->
      {id, %{x: :rand.uniform(900) * 1.0, y: :rand.uniform(600) * 1.0}}
    end)
  end

  # ===== Initial graph =====

  defp build_flow do
    nodes =
      for {id, label, group, _parent} <- @services do
        Node.new(id, %{x: 0, y: 0}, %{label: label, color: Map.fetch!(@colors, group)},
          type: :service,
          width: @node_width,
          height: @node_height,
          connectable: false
        )
      end

    edges =
      for {id, _label, _group, parent} <- @services, parent do
        Edge.new("#{parent}->#{id}", parent, id,
          source_floating: true,
          target_floating: true,
          marker_end: %{type: :arrow_closed}
        )
      end

    State.new(nodes: nodes, edges: edges)
  end
end

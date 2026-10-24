defmodule FlowExampleWeb.Examples.Interaction.ContextualZoomLive do
  @moduledoc """
  Contextual Zoom: only display the content of a node when you are zoomed in
  close enough.

  The hook reports the viewport with `lf:viewport_change`; the server keeps it
  in `flow.viewport` and, when the zoom crosses the threshold, flips a
  `detailed` flag in the data of every node. Nodes are only re-rendered when
  the level of detail changes, not on every zoom step.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Node, State}

  @flow_id "contextual-zoom"
  @min_zoom 0.2
  @max_zoom 2.0
  @default_threshold 0.9

  @accents %{
    "sky" => "bg-sky-500/15 text-sky-600",
    "violet" => "bg-violet-500/15 text-violet-600",
    "emerald" => "bg-emerald-500/15 text-emerald-600",
    "amber" => "bg-amber-500/15 text-amber-600",
    "rose" => "bg-rose-500/15 text-rose-600"
  }

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, flow_id: @flow_id)
     |> assign(threshold: @default_threshold, min_zoom: @min_zoom, max_zoom: @max_zoom)
     |> assign(:form, to_form(%{"threshold" => @default_threshold}, as: :zoom))
     |> FlowEvents.assign_flow(build_flow())
     |> sync_detail()}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        zoom: assigns.flow.viewport.zoom,
        detailed: assigns.flow.viewport.zoom >= assigns.threshold
      )

    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action
          id="zoom-out-button"
          icon="hero-magnifying-glass-minus"
          phx-click="zoom_to"
          phx-value-zoom="0.5"
        >
          Zoom to 0.5×
        </.action>
        <.action
          id="zoom-in-button"
          icon="hero-magnifying-glass-plus"
          phx-click="zoom_to"
          phx-value-zoom="1.3"
        >
          Zoom to 1.3×
        </.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id={@flow_id}
        flow={@flow}
        node_types={%{service: &service_node/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            minimap: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.15},
            min_zoom: @min_zoom,
            max_zoom: @max_zoom
          }
        }
      />

      <:sidebar>
        <.option_group title="Zoom">
          <div id="zoom-status" data-detailed={to_string(@detailed)} class="space-y-2">
            <div class="flex items-end justify-between">
              <span id="zoom-value" class="font-mono text-2xl font-semibold tabular-nums">
                {format_zoom(@zoom)}×
              </span>
              <span class={[
                "rounded-full px-2 py-0.5 text-[11px] font-medium transition-colors",
                if(@detailed,
                  do: "bg-emerald-500/15 text-emerald-600",
                  else: "bg-base-300 text-base-content/60"
                )
              ]}>
                {if @detailed, do: "Detailed", else: "Compact"}
              </span>
            </div>
            <div class="relative h-1.5 rounded-full bg-base-300">
              <div
                class="absolute inset-y-0 left-0 rounded-full bg-primary transition-[width] duration-200"
                style={"width: #{meter(@zoom)}%"}
              />
              <div
                class="absolute -top-1 h-3.5 w-0.5 rounded-full bg-base-content/60"
                style={"left: #{meter(@threshold)}%"}
                title="Threshold"
              />
            </div>
            <div class="flex justify-between font-mono text-[10px] text-base-content/40">
              <span>{format_zoom(@min_zoom)}×</span>
              <span>{format_zoom(@max_zoom)}×</span>
            </div>
          </div>
        </.option_group>

        <.option_group title="Threshold">
          <.form for={@form} id="zoom-options" phx-change="set_threshold">
            <.range
              field={@form[:threshold]}
              label="Show details from"
              min="0.4"
              max="1.6"
              step="0.05"
            />
          </.form>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            The hook pushes <code>lf:viewport_change</code>
            (throttled) and the server stores it in <code>flow.viewport</code>.
          </.hint>
          <.hint>
            When <code>zoom &gt;= threshold</code>
            changes, a <code>detailed</code>
            flag is written to every node's <code>data</code>: the node renderer shows metrics
            and a chart, or a compact placeholder readable from afar.
          </.hint>
          <.hint>
            Zoom with the wheel, the controls or the header buttons
            (<code>push_event("lf:zoom_to", ...)</code>).
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
    assigns = assign(assigns, :accent, Map.fetch!(@accents, assigns.node.data.color))

    ~H"""
    <div
      id={"service-#{@node.id}"}
      class="h-[124px] w-60"
      data-detail={if @node.data.detailed, do: "full", else: "compact"}
    >
      <%= if @node.data.detailed do %>
        <div class="flex items-center gap-2.5">
          <span class={["grid size-8 shrink-0 place-items-center rounded-lg", @accent]}>
            <.icon name={@node.data.icon} class="size-4" />
          </span>
          <div class="min-w-0 flex-1">
            <p
              class="truncate text-[13px] leading-tight font-semibold"
              style="color: var(--lf-text-primary)"
            >
              {@node.data.title}
            </p>
            <p class="truncate text-[11px]" style="color: var(--lf-text-secondary)">
              {@node.data.subtitle}
            </p>
          </div>
          <span
            class={[
              "size-2 shrink-0 rounded-full",
              if(@node.data.healthy, do: "bg-emerald-500", else: "bg-amber-500 animate-pulse")
            ]}
            title={if @node.data.healthy, do: "healthy", else: "degraded"}
          />
        </div>
        <div class="mt-2.5 grid grid-cols-3 gap-1.5">
          <div
            :for={{label, value} <- @node.data.metrics}
            class="rounded-md px-1.5 py-1"
            style="background: color-mix(in oklab, var(--lf-text-primary) 5%, transparent)"
          >
            <p class="text-[9px] uppercase tracking-wide" style="color: var(--lf-text-secondary)">
              {label}
            </p>
            <p class="font-mono text-[11px] font-semibold" style="color: var(--lf-text-primary)">
              {value}
            </p>
          </div>
        </div>
        <div class="mt-2 flex h-5 items-end gap-0.5">
          <span
            :for={h <- @node.data.series}
            class={["flex-1 rounded-sm opacity-70", @accent]}
            style={"height: #{h}%; background: currentColor"}
          />
        </div>
      <% else %>
        <div class="flex h-full flex-col items-center justify-center gap-2">
          <span class={["grid size-10 place-items-center rounded-xl", @accent]}>
            <.icon name={@node.data.icon} class="size-6" />
          </span>
          <p class="text-xl font-bold tracking-tight" style="color: var(--lf-text-primary)">
            {@node.data.title}
          </p>
          <div class="flex w-28 gap-1.5">
            <span
              class="h-1.5 flex-1 rounded-full"
              style="background: color-mix(in oklab, var(--lf-text-primary) 12%, transparent)"
            />
            <span
              class="h-1.5 w-8 rounded-full"
              style="background: color-mix(in oklab, var(--lf-text-primary) 12%, transparent)"
            />
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("set_threshold", %{"zoom" => %{"threshold" => value}}, socket) do
    threshold =
      case Float.parse(value) do
        {float, _rest} -> float |> max(@min_zoom) |> min(@max_zoom)
        :error -> socket.assigns.threshold
      end

    socket
    |> assign(:threshold, threshold)
    |> assign(:form, to_form(%{"threshold" => value}, as: :zoom))
    |> sync_detail()
    |> noreply()
  end

  def handle_event("zoom_to", %{"zoom" => zoom}, socket) do
    {zoom, _rest} = Float.parse(zoom)
    {:noreply, push_event(socket, "lf:zoom_to", %{zoom: zoom, duration: 400})}
  end

  def handle_event("lf:viewport_change", params, socket) do
    {:noreply, socket} = FlowEvents.handle_event("lf:viewport_change", params, socket)
    {:noreply, sync_detail(socket)}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Level of detail =====

  # Writes the level of detail into the nodes only when it changes, so
  # zooming doesn't re-render the nodes on every viewport update
  defp sync_detail(socket) do
    %{flow: flow, threshold: threshold} = socket.assigns
    detailed = flow.viewport.zoom >= threshold

    if Enum.all?(flow.nodes, fn {_id, node} -> node.data.detailed == detailed end) do
      socket
    else
      nodes =
        Map.new(flow.nodes, fn {id, node} ->
          {id, %{node | data: Map.put(node.data, :detailed, detailed)}}
        end)

      socket
      |> assign(:flow, %{flow | nodes: nodes})
      |> FlowEvents.log("level of detail", %{
        "zoom" => format_zoom(flow.viewport.zoom),
        "detailed" => detailed
      })
    end
  end

  defp meter(zoom) do
    ((zoom - @min_zoom) / (@max_zoom - @min_zoom) * 100)
    |> max(0.0)
    |> min(100.0)
    |> Float.round(1)
  end

  defp format_zoom(zoom), do: :erlang.float_to_binary(zoom / 1, decimals: 2)

  defp noreply(socket), do: {:noreply, socket}

  # ===== Initial graph =====

  defp build_flow do
    nodes = [
      service("gateway", 0, 160, "Gateway", "Edge · 3 regions", "hero-globe-alt", "sky",
        metrics: [{"rps", "12.4k"}, {"p95", "84ms"}, {"err", "0.1%"}],
        series: [40, 55, 48, 70, 62, 80, 74, 90, 68, 76]
      ),
      service("auth", 340, 0, "Auth", "OAuth · sessions", "hero-key", "violet",
        metrics: [{"rps", "3.1k"}, {"p95", "41ms"}, {"err", "0.0%"}],
        series: [30, 35, 32, 40, 38, 42, 36, 44, 40, 38]
      ),
      service("orders", 340, 320, "Orders", "Checkout API", "hero-shopping-cart", "amber",
        metrics: [{"rps", "1.8k"}, {"p95", "212ms"}, {"err", "1.4%"}],
        series: [20, 45, 30, 75, 50, 95, 60, 85, 40, 70],
        healthy: false
      ),
      service("db", 680, 160, "Postgres", "Primary + 2 replicas", "hero-circle-stack", "emerald",
        metrics: [{"qps", "8.2k"}, {"conn", "184"}, {"lag", "12ms"}],
        series: [50, 52, 58, 55, 60, 64, 61, 66, 63, 65]
      ),
      service("queue", 680, 480, "Queue", "Fulfilment jobs", "hero-queue-list", "rose",
        metrics: [{"jobs", "742"}, {"wait", "3.2s"}, {"fail", "4"}],
        series: [10, 25, 60, 35, 20, 80, 45, 30, 65, 50]
      )
    ]

    edges = [
      Edge.new("gateway-auth", "gateway", "auth", type: :smoothstep, animated: true),
      Edge.new("gateway-orders", "gateway", "orders", type: :smoothstep, animated: true),
      Edge.new("auth-db", "auth", "db", type: :smoothstep),
      Edge.new("orders-db", "orders", "db", type: :smoothstep),
      Edge.new("orders-queue", "orders", "queue", type: :smoothstep)
    ]

    State.new(nodes: nodes, edges: edges)
  end

  defp service(id, x, y, title, subtitle, icon, color, opts) do
    data = %{
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      metrics: Keyword.fetch!(opts, :metrics),
      series: Keyword.fetch!(opts, :series),
      healthy: Keyword.get(opts, :healthy, true),
      detailed: true
    }

    Node.new(id, %{x: x, y: y}, data, type: :service)
  end
end

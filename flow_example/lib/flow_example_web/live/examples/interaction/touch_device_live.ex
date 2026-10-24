defmodule FlowExampleWeb.Examples.Interaction.TouchDeviceLive do
  @moduledoc """
  Touch Device: tap a handle, then another one, to connect them.

  `connect_on_click: true` (the default) turns a tap on a handle without
  dragging into a "click connection": the line follows the pointer until a
  second handle is tapped (connect) or the pane is tapped (cancel). Handles
  are made much bigger with CSS scoped to the flow, and
  `connection_events: true` pushes `lf:connect_start` so the page can show a
  hint while a connection is pending.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}

  @defaults %{"connect_on_click" => "true", "handle_size" => "large"}
  @sizes [
    {"Default (10px)", "small"},
    {"Medium (16px)", "medium"},
    {"Large (24px)", "large"},
    {"Huge (32px)", "huge"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, pending: nil, sizes: @sizes)
     |> assign(edge_opts: [type: :smoothstep, animated: true])
     |> assign_params(@defaults)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #touch-canvas[data-handle-size="small"] #touch-flow {
        --lf-handle-size: 10px;
      }
      #touch-canvas[data-handle-size="medium"] #touch-flow {
        --lf-handle-size: 16px;
      }
      #touch-canvas[data-handle-size="large"] #touch-flow {
        --lf-handle-size: 24px;
      }
      #touch-canvas[data-handle-size="huge"] #touch-flow {
        --lf-handle-size: 32px;
      }
      #touch-flow {
        --lf-handle-border-width: 2px;
        --touch-accent: #8b5cf6;
      }
      #touch-flow .lf-handle {
        border-radius: 32%;
        border-color: var(--touch-accent);
        background: color-mix(in oklab, var(--touch-accent) 16%, var(--lf-node-bg));
        touch-action: none;
      }
      #touch-flow .lf-handle:hover,
      #touch-flow .lf-handle[data-connecting="valid"] {
        background: var(--touch-accent);
      }
      #touch-flow .lf-handle[data-connecting-source] {
        background: var(--touch-accent);
        animation: touch-handle-pulse 1.3s ease-out infinite;
      }
      #touch-flow .lf-node[data-node-type="touch"] {
        border-radius: 14px;
      }
      #touch-hint {
        animation: touch-hint-in 180ms cubic-bezier(0.2, 0.9, 0.3, 1.2);
      }
      @keyframes touch-handle-pulse {
        0% {
          box-shadow: 0 0 0 0 color-mix(in oklab, var(--touch-accent) 60%, transparent);
        }
        100% {
          box-shadow: 0 0 0 16px transparent;
        }
      }
      @keyframes touch-hint-in {
        from {
          opacity: 0;
          translate: 0 -6px;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <div id="touch-canvas" class="relative h-full w-full" data-handle-size={@params["handle_size"]}>
        <.live_component
          module={LiveFlow.Components.Flow}
          id="touch-flow"
          flow={@flow}
          node_types={%{touch: &touch_node/1}}
          opts={
            %{
              background: :dots,
              controls: true,
              fit_view_on_init: true,
              fit_view_options: %{padding: 0.3},
              connect_on_click: @params["connect_on_click"] == "true",
              connection_events: true,
              connection_radius: 36,
              connection_line_type: :smoothstep
            }
          }
        />

        <div
          :if={@pending}
          id="touch-hint"
          class="pointer-events-none absolute inset-x-0 top-4 z-20 flex justify-center px-4"
        >
          <div class="flex items-center gap-2.5 rounded-full border border-violet-500/30 bg-base-100/95 py-1.5 pr-4 pl-2 text-sm shadow-lg backdrop-blur">
            <span class="relative grid size-6 place-items-center">
              <span class="absolute inset-0 animate-ping rounded-full bg-violet-500/40"></span>
              <span class="relative size-2.5 rounded-full bg-violet-500"></span>
            </span>
            <span>
              Connecting from <b>{@pending.label}</b>
              <span class="text-base-content/50">
                · tap (or drop on) a {if @pending.handle_type == "source",
                  do: "target",
                  else: "source"} handle
              </span>
            </span>
          </div>
        </div>
      </div>

      <:sidebar>
        <.option_group title="Gestures">
          <ul id="touch-gestures" class="space-y-3">
            <li :for={{icon, title, text} <- gestures()} class="flex gap-3">
              <span class="grid size-8 shrink-0 place-items-center rounded-lg bg-violet-500/10 text-violet-600">
                <.icon name={icon} class="size-4" />
              </span>
              <div>
                <p class="text-sm font-medium">{title}</p>
                <p class="text-xs leading-relaxed text-base-content/55">{text}</p>
              </div>
            </li>
          </ul>
        </.option_group>

        <.option_group title="Options">
          <.form for={@form} id="touch-options" phx-change="options">
            <.input
              field={@form[:connect_on_click]}
              type="checkbox"
              label="Tap to connect (connect_on_click)"
              class={switch_class()}
            />
            <.input
              field={@form[:handle_size]}
              type="select"
              label="Handle size"
              class={select_class()}
              options={@sizes}
            />
          </.form>
          <.hint>
            Without <code>connect_on_click</code> a tap on a handle does nothing: you have to drag
            the connection line to the other handle.
          </.hint>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            Touch input reuses the mouse code paths: one finger drags nodes, pans the pane or draws
            a connection; two fingers pinch-zoom and pan around their midpoint.
          </.hint>
          <.hint>
            The handles are enlarged with a colocated stylesheet that sets
            <code>--lf-handle-size</code>
            on <code>#touch-flow</code>
            only. <code>connection_radius: 36</code>
            also snaps to a handle near the finger.
          </.hint>
          <.hint>
            <code>connection_events: true</code>
            sends <code>lf:connect_start</code>; the hint above the canvas lasts until
            <code>lf:connect_end</code>
            or <code>lf:connect_cancel</code>.
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

  defp touch_node(assigns) do
    ~H"""
    <div class="flex w-40 items-center gap-3 py-1">
      <span class="grid size-10 shrink-0 place-items-center rounded-xl bg-violet-500/12 text-violet-600">
        <.icon name={@node.data.icon} class="size-5" />
      </span>
      <div class="min-w-0">
        <p class="truncate text-sm font-semibold" style="color: var(--lf-text-primary)">
          {@node.data.label}
        </p>
        <p class="truncate text-[11px]" style="color: var(--lf-text-secondary)">
          {@node.data.subtitle}
        </p>
      </div>
    </div>
    """
  end

  defp gestures do
    [
      {"hero-cursor-arrow-ripple", "Tap, then tap",
       "Tap a handle, then tap a handle on another node to connect them. Tap the pane to cancel."},
      {"hero-hand-raised", "Drag",
       "Drag a node with one finger to move it, drag the pane to pan."},
      {"hero-magnifying-glass-plus", "Pinch", "Pinch with two fingers to zoom in and out."},
      {"hero-arrows-pointing-out", "Two-finger pan",
       "Move two fingers together to pan while you zoom."}
    ]
  end

  # ===== Events =====

  @impl true
  def handle_event("options", %{"touch" => params}, socket) do
    {:noreply, assign_params(socket, Map.merge(socket.assigns.params, params))}
  end

  def handle_event("lf:connect_start", %{"node_id" => node_id} = params, socket) do
    pending = %{
      label: label(socket.assigns.flow, node_id),
      handle_type: params["handle_type"]
    }

    {:noreply, socket |> assign(:pending, pending) |> FlowEvents.log("lf:connect_start", params)}
  end

  def handle_event("lf:" <> _ = event, params, socket)
      when event in ["lf:connect_end", "lf:connect_cancel"] do
    FlowEvents.handle_event(event, params, assign(socket, :pending, nil))
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Helpers =====

  defp assign_params(socket, params) do
    assign(socket, params: params, form: to_form(params, as: :touch))
  end

  defp label(flow, id) do
    case State.get_node(flow, id) do
      %Node{data: %{label: label}} -> label
      _other -> id
    end
  end

  defp build_flow do
    node = fn id, x, y, label, subtitle, icon, handles ->
      Node.new(id, %{x: x, y: y}, %{label: label, subtitle: subtitle, icon: icon},
        type: :touch,
        handles: handles
      )
    end

    nodes = [
      node.("sensor", 160, 0, "Sensor", "Reads every second", "hero-signal", [
        Handle.source(:bottom)
      ]),
      node.("filter", 0, 180, "Filter", "Drops noisy values", "hero-funnel", [
        Handle.target(:top),
        Handle.source(:bottom)
      ]),
      node.("alert", 320, 180, "Alert", "Pages the on-call", "hero-bell-alert", [
        Handle.target(:top),
        Handle.source(:bottom)
      ]),
      node.("dashboard", 160, 360, "Dashboard", "Live charts", "hero-chart-bar", [
        Handle.target(:top)
      ])
    ]

    edges = [Edge.new("sensor-filter", "sensor", "filter", type: :smoothstep, animated: true)]

    State.new(nodes: nodes, edges: edges)
  end
end

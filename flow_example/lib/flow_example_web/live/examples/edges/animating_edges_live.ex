defmodule FlowExampleWeb.Examples.Edges.AnimatingEdgesLive do
  @moduledoc """
  Animating Edges: edge animations that go beyond the built-in animated edge.

  Every animation is a custom edge type (`edge_types`). The renderer draws the
  regular edge path and adds SVG that moves along it with `<animateMotion>`.
  `<mpath href="#path-id">` points to the edge's own `<path>`, so the motion
  keeps following the path while the client redraws it during a node drag
  (`data-source`, `data-target`, ... on the root `<g>`). The `:flow` type
  animates `stroke-dashoffset` with CSS instead.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, State}

  @flow_id "animating-edges-flow"

  # type => {label, base duration in seconds}
  @types [
    comet: {"Glowing comet", 2.4},
    packets: {"Data packets", 3.0},
    plane: {"Paper plane", 3.4},
    flow: {"Flowing dashes", 0.9}
  ]
  @type_names Enum.map(@types, fn {type, _} -> Atom.to_string(type) end)

  @speeds [{"slow", 1.8}, {"normal", 1.0}, {"fast", 0.5}]

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, speed: "normal")
     |> assign(speeds: Enum.map(@speeds, &elem(&1, 0)))
     |> FlowEvents.assign_flow(build_flow())
     |> assign_new_type("comet")}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :flow_id, @flow_id)

    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #animating-edges-flow .ae-comet-head {
        fill: #ff0073;
      }
      #animating-edges-flow .ae-comet-trail {
        fill: #ff0073;
        opacity: 0.45;
      }
      #animating-edges-flow .ae-comet-trail.is-faint {
        opacity: 0.2;
      }
      #animating-edges-flow .ae-packet {
        fill: #0ea5e9;
        stroke: var(--lf-node-bg);
        stroke-width: 1;
      }
      #animating-edges-flow .ae-plane-bg {
        fill: var(--lf-node-bg);
        stroke: #8b5cf6;
        stroke-width: 1.5;
      }
      #animating-edges-flow .ae-plane-icon {
        fill: #8b5cf6;
      }
      #animating-edges-flow .ae-flow-overlay {
        fill: none;
        stroke: #10b981;
        stroke-width: 3.5;
        stroke-linecap: round;
        stroke-dasharray: 1 15;
        pointer-events: none;
        animation: ae-flow 0.9s linear infinite;
      }
      #animating-edges-flow .ae-motion {
        pointer-events: none;
      }
      @keyframes ae-flow {
        to {
          stroke-dashoffset: -16;
        }
      }
      @media (prefers-reduced-motion: reduce) {
        #animating-edges-flow .ae-flow-overlay {
          animation: none;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id={@flow_id}
        flow={@flow}
        node_types={FlowNodes.types()}
        edge_types={edge_types()}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.2}
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Each animation is a custom edge type registered with <code phx-no-curly-interpolation>edge_types={%{comet: &animated_edge/1, ...}}</code>. The renderer draws the edge path and an SVG element that travels along it.
          </.hint>
          <.hint>
            Motion uses <code>&lt;animateMotion&gt;</code>
            with <code phx-no-curly-interpolation>&lt;mpath href="#path-id"&gt;</code>
            pointing to the edge's own <code>&lt;path&gt;</code>: drag a node and the animation follows the
            path while the client redraws it. With <code>animateMotion path=...</code>
            instead, the motion would only catch up after the drop.
          </.hint>
          <.hint>
            <b>Flowing dashes</b>
            animates <code>stroke-dashoffset</code>
            of a second path with CSS — a lighter alternative to SMIL.
          </.hint>
        </.option_group>

        <.option_group title="Animations">
          <ul class="space-y-1.5">
            <li
              :for={{type, {label, _}} <- types()}
              id={"type-#{type}"}
              class="flex items-center gap-2 text-sm"
            >
              <span class={["size-2.5 rounded-full", swatch(type)]} />
              {label}
              <code class="ml-auto text-[11px] text-base-content/50">:{type}</code>
            </li>
          </ul>
        </.option_group>

        <.option_group title="Speed">
          <div class="flex gap-1 rounded-lg bg-base-200 p-1">
            <button
              :for={speed <- @speeds}
              id={"speed-#{speed}"}
              type="button"
              phx-click="set_speed"
              phx-value-speed={speed}
              class={[
                "flex-1 rounded-md px-2 py-1 text-xs font-medium capitalize transition-all duration-150 active:scale-95",
                if(speed == @speed,
                  do: "bg-base-100 text-base-content shadow-sm",
                  else: "text-base-content/60 hover:text-base-content"
                )
              ]}
            >
              {speed}
            </button>
          </div>
        </.option_group>

        <.option_group title="New connections">
          <.form for={@type_form} id="new-edge-type-form" phx-change="set_new_type">
            <.input
              field={@type_form[:type]}
              type="select"
              label="Edge type"
              class={select_class()}
              options={Enum.map(types(), fn {type, {label, _}} -> {label, type} end)}
            />
          </.form>
          <.hint>
            Connect two handles: <code>edge_opts</code> gives the new edge this type.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  # ── Edge renderers ────────────────────────────────────────────────────

  defp edge_types do
    Map.new(@types, fn {type, _} -> {type, &animated_edge/1} end)
  end

  defp animated_edge(assigns) do
    edge = assigns.edge

    assigns =
      assign(assigns,
        path_id: "#{@flow_id}-path-#{edge.id}",
        dur: duration(edge),
        path_type: Map.get(edge.path_options, :base_type, :bezier)
      )

    ~H"""
    <g
      class={["lf-edge-group ae-edge", "ae-#{@edge.type}"]}
      data-edge-id={@edge.id}
      data-source={@edge.source}
      data-target={@edge.target}
      data-source-handle={@edge.source_handle}
      data-target-handle={@edge.target_handle}
      data-path-type={@path_type}
    >
      <path class="lf-edge-interaction" d={@path} data-edge-id={@edge.id} />
      <path
        id={@path_id}
        class="lf-edge"
        d={@path}
        data-edge-id={@edge.id}
        data-selected={to_string(@edge.selected)}
        marker-end={@marker_end_id}
      />
      <.motion type={@edge.type} path_id={@path_id} dur={@dur} d={@path} />
    </g>
    """
  end

  attr :type, :atom, required: true
  attr :path_id, :string, required: true
  attr :dur, :float, required: true
  attr :d, :string, required: true

  # A glowing dot followed by two fading copies (started slightly earlier, so
  # they trail behind it on every loop)
  defp motion(%{type: :comet} = assigns) do
    assigns = assign(assigns, :filter_id, "#{assigns.path_id}-glow")

    ~H"""
    <defs>
      <filter id={@filter_id} x="-300%" y="-300%" width="700%" height="700%">
        <feGaussianBlur stdDeviation="3" result="blur" />
        <feMerge>
          <feMergeNode in="blur" />
          <feMergeNode in="SourceGraphic" />
        </feMerge>
      </filter>
    </defs>
    <g class="ae-motion">
      <circle
        :for={{class, r, lag} <- [{"is-faint", 2.5, 0.08}, {nil, 3.5, 0.04}]}
        class={["ae-comet-trail", class]}
        r={r}
      >
        <animateMotion dur={"#{@dur}s"} begin={"-#{fmt(@dur * (1 - lag))}s"} repeatCount="indefinite">
          <mpath href={"##{@path_id}"} />
        </animateMotion>
      </circle>
      <circle class="ae-comet-head" r="5" filter={"url(##{@filter_id})"}>
        <animateMotion dur={"#{@dur}s"} repeatCount="indefinite">
          <mpath href={"##{@path_id}"} />
        </animateMotion>
      </circle>
    </g>
    """
  end

  # Three packets evenly spread along the path, rotated with it
  defp motion(%{type: :packets} = assigns) do
    ~H"""
    <g class="ae-motion">
      <rect
        :for={i <- 0..2}
        class="ae-packet"
        x="-6"
        y="-3.5"
        width="12"
        height="7"
        rx="2"
      >
        <animateMotion
          dur={"#{@dur}s"}
          begin={"-#{fmt(@dur * i / 3)}s"}
          rotate="auto"
          repeatCount="indefinite"
        >
          <mpath href={"##{@path_id}"} />
        </animateMotion>
      </rect>
    </g>
    """
  end

  # An icon (heroicons paper-airplane, solid) pointing along the path
  defp motion(%{type: :plane} = assigns) do
    ~H"""
    <g class="ae-motion">
      <animateMotion dur={"#{@dur}s"} rotate="auto" repeatCount="indefinite">
        <mpath href={"##{@path_id}"} />
      </animateMotion>
      <circle class="ae-plane-bg" r="12" />
      <g transform="scale(0.62) translate(-12 -12)">
        <path
          class="ae-plane-icon"
          d="M3.478 2.404a.75.75 0 0 0-.926.941l2.432 7.905H13.5a.75.75 0 0 1 0 1.5H4.984l-2.432 7.905a.75.75 0 0 0 .926.94 60.519 60.519 0 0 0 18.445-8.986.75.75 0 0 0 0-1.218A60.517 60.517 0 0 0 3.478 2.404Z"
        />
      </g>
    </g>
    """
  end

  # A second path on top of the edge, dashed, with an animated dash offset.
  # It's a direct child of the edge <g> so the client redraws it too.
  defp motion(%{type: :flow} = assigns) do
    ~H"""
    <path class="ae-flow-overlay" d={@d} style={"animation-duration: #{@dur}s"} />
    """
  end

  # ── Events ────────────────────────────────────────────────────────────

  @impl true
  def handle_event("set_speed", %{"speed" => speed}, socket) do
    if List.keymember?(@speeds, speed, 0) do
      flow = socket.assigns.flow

      edges =
        Map.new(flow.edges, fn {id, edge} ->
          {id, %{edge | data: Map.put(edge.data, :speed, speed)}}
        end)

      {:noreply,
       socket
       |> assign(:speed, speed)
       |> assign(:flow, %{flow | edges: edges})
       |> assign_new_type(socket.assigns.new_type)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("set_new_type", %{"new_edge" => %{"type" => type}}, socket)
      when type in @type_names do
    {:noreply, assign_new_type(socket, type)}
  end

  def handle_event("set_new_type", _params, socket), do: {:noreply, socket}

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ── Helpers ───────────────────────────────────────────────────────────

  defp types, do: @types

  # `edge_opts` is read by FlowEvents when a connection is made
  defp assign_new_type(socket, type) do
    speed = Map.get(socket.assigns, :speed, "normal")

    socket
    |> assign(:new_type, type)
    |> assign(:type_form, to_form(%{"type" => type}, as: :new_edge))
    |> assign(:edge_opts,
      type: String.to_existing_atom(type),
      data: %{speed: speed}
    )
  end

  defp duration(%Edge{type: type, data: data}) do
    {_label, base} = Keyword.get(@types, type, {"", 2.0})
    factor = @speeds |> List.keyfind(Map.get(data, :speed, "normal"), 0, {"", 1.0}) |> elem(1)
    Float.round(base * factor, 2)
  end

  defp fmt(seconds), do: :erlang.float_to_binary(seconds / 1, decimals: 3)

  defp swatch(:comet), do: "bg-[#ff0073]"
  defp swatch(:packets), do: "bg-sky-500"
  defp swatch(:plane), do: "bg-violet-500"
  defp swatch(:flow), do: "bg-emerald-500"

  defp build_flow do
    rows = [
      {:comet, {"sensor", "Sensor", "Temperature feed", "hero-signal", :amber},
       {"gateway", "Gateway", "MQTT bridge", "hero-server-stack", :sky}},
      {:packets, {"producer", "Producer", "Order events", "hero-bolt", :violet},
       {"queue", "Queue", "Kafka topic", "hero-queue-list", :sky}},
      {:plane, {"outbox", "Outbox", "Transactional mail", "hero-envelope", :rose},
       {"inbox", "Inbox", "customer@acme.dev", "hero-inbox", :emerald}},
      {:flow, {"pump", "Pump", "1.2 m³/min", "hero-arrow-path", :emerald},
       {"tank", "Tank", "78% full", "hero-beaker", :slate}}
    ]

    {nodes, edges} =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {{type, {sid, st, ss, si, sc}, {tid, tt, ts, ti, tc}}, i} ->
        y = i * 150
        target_y = if rem(i, 2) == 0, do: y + 50, else: y - 20

        nodes = [
          Samples.card(sid, 0, y, st, ss, si, sc, inputs: false),
          Samples.card(tid, 480, target_y, tt, ts, ti, tc, outputs: false)
        ]

        opts =
          [type: type, data: %{speed: "normal"}] ++
            if(type == :flow, do: [path_options: %{base_type: :smoothstep}], else: [])

        {nodes, Edge.new(Atom.to_string(type), sid, tid, opts)}
      end)
      |> Enum.unzip()

    State.new(nodes: List.flatten(nodes), edges: edges)
  end
end

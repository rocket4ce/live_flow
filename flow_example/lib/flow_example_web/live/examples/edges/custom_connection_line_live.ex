defmodule FlowExampleWeb.Examples.Edges.CustomConnectionLineLive do
  @moduledoc """
  Custom Connection Line: change the appearance and behavior of the line drawn
  while connecting two handles.

  The preview line is drawn by the client, configured with three flow options:
  `connection_line_type` (path algorithm), `connection_line_style` (inline
  style map) and `connection_line_class` (extra CSS class, styled here with
  colocated CSS). `connection_radius` sets how close to a handle the line
  snaps. New edges get the same path type through `edge_opts`.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.State

  @line_types ~w(bezier straight step smoothstep)

  # id => {label, connection_line_style, connection_line_class}
  @presets [
    {"default", "Default", nil, nil},
    {"bold", "Bold pink", %{stroke: "#ff0072", "stroke-width": 3, "stroke-dasharray": "none"},
     nil},
    {"ants", "Marching ants", nil, "ccl-ants"},
    {"neon", "Neon pulse", nil, "ccl-neon"},
    {"dot", "Dot at the cursor", nil, "ccl-dot"}
  ]
  @preset_ids Enum.map(@presets, &elem(&1, 0))

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(line_types: @line_types, presets: @presets)
     |> assign(line_type: "bezier", preset: "dot", radius: 20)
     |> assign(:radius_form, to_form(%{"radius" => "20"}, as: :behavior))
     |> FlowEvents.assign_flow(build_flow())
     |> assign_line()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #ccl-presets .ccl-preview {
        fill: none;
        stroke: #b1b1b7;
        stroke-width: 2;
        stroke-dasharray: 5 5;
      }
      #custom-connection-line-flow .lf-connection-line.ccl-ants,
      #ccl-presets .ccl-preview.ccl-ants {
        stroke: #6366f1;
        stroke-width: 2.5;
        stroke-dasharray: 8 6;
        animation: ccl-ants 0.5s linear infinite;
      }
      #custom-connection-line-flow .lf-connection-line.ccl-neon,
      #ccl-presets .ccl-preview.ccl-neon {
        stroke: #a855f7;
        stroke-dasharray: none;
        stroke-linecap: round;
        animation: ccl-neon 0.9s ease-in-out infinite alternate;
      }
      #custom-connection-line-flow .lf-connection-line.ccl-dot,
      #ccl-presets .ccl-preview.ccl-dot {
        stroke: #ff0072;
        stroke-width: 1.5;
        stroke-dasharray: 5;
        marker-end: url(#ccl-dot-marker);
        animation: ccl-dot 0.5s linear infinite;
      }
      @keyframes ccl-ants {
        to {
          stroke-dashoffset: -14;
        }
      }
      @keyframes ccl-dot {
        to {
          stroke-dashoffset: -10;
        }
      }
      @keyframes ccl-neon {
        from {
          stroke: #a855f7;
          stroke-width: 2;
        }
        to {
          stroke: #ec4899;
          stroke-width: 5;
        }
      }
      #ccl-presets .ccl-preset {
        transition:
          border-color 150ms ease,
          background-color 150ms ease,
          transform 150ms ease;
      }
      #ccl-presets .ccl-preset:active {
        transform: scale(0.98);
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <%!-- Marker used by the "dot" preset (referenced from CSS: marker-end: url(#ccl-dot-marker)) --%>
      <svg class="pointer-events-none absolute size-0" aria-hidden="true" data-lf-export-ignore>
        <defs>
          <marker
            id="ccl-dot-marker"
            viewBox="0 0 12 12"
            refX="6"
            refY="6"
            markerWidth="12"
            markerHeight="12"
            markerUnits="userSpaceOnUse"
          >
            <circle cx="6" cy="6" r="4" fill="#fff" stroke="#ff0072" stroke-width="1.5" />
          </marker>
        </defs>
      </svg>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="custom-connection-line-flow"
        flow={@flow}
        node_types={FlowNodes.types()}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.3},
            connection_line_type: String.to_existing_atom(@line_type),
            connection_line_style: @line_style,
            connection_line_class: @line_class,
            connection_radius: @radius
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Drag from a handle: the preview line is drawn by the client with <code>connection_line_type</code>,
            <code>connection_line_style</code>
            (inline style map) and <code>connection_line_class</code>
            (an extra CSS class you style yourself).
          </.hint>
          <.hint>
            <b>Dot at the cursor</b>
            reproduces the React Flow original: animated dashes plus a circle at the end, drawn with
            <code>marker-end</code>
            from the class's CSS.
          </.hint>
        </.option_group>

        <.option_group title="Line type">
          <div class="grid grid-cols-2 gap-1 rounded-lg bg-base-200 p-1">
            <button
              :for={type <- @line_types}
              id={"line-type-#{type}"}
              type="button"
              phx-click="set_line_type"
              phx-value-type={type}
              class={[
                "rounded-md px-2 py-1 text-xs font-medium transition-all duration-150 active:scale-95",
                if(type == @line_type,
                  do: "bg-base-100 text-base-content shadow-sm",
                  else: "text-base-content/60 hover:text-base-content"
                )
              ]}
            >
              {type}
            </button>
          </div>
        </.option_group>

        <.option_group title="Style preset">
          <div id="ccl-presets" class="space-y-1.5">
            <button
              :for={{id, label, style, class} <- @presets}
              id={"preset-#{id}"}
              type="button"
              phx-click="set_preset"
              phx-value-preset={id}
              class={[
                "ccl-preset flex w-full items-center gap-3 rounded-lg border px-3 py-2 text-left text-sm",
                if(id == @preset,
                  do: "border-primary bg-primary/5 font-medium",
                  else: "border-base-300 hover:border-base-content/20 hover:bg-base-200"
                )
              ]}
            >
              <svg viewBox="0 0 72 16" class="h-4 w-[72px] shrink-0 overflow-visible">
                <path
                  d="M4 12 C 24 12, 40 4, 64 4"
                  class={["ccl-preview", class]}
                  style={style_string(style)}
                />
              </svg>
              {label}
            </button>
          </div>
        </.option_group>

        <.option_group title="Behavior">
          <.form for={@radius_form} id="radius-form" phx-change="set_radius">
            <.range field={@radius_form[:radius]} label="connection_radius" min="0" max="80" />
          </.form>
          <.hint>Distance (px) within which the line snaps to the closest handle.</.hint>
        </.option_group>

        <.option_group title="Options">
          <pre
            id="ccl-code"
            class="overflow-x-auto rounded-lg bg-base-200 p-3 font-mono text-[11px] leading-relaxed text-base-content/80"
          >{@code}</pre>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  @impl true
  def handle_event("set_line_type", %{"type" => type}, socket) when type in @line_types do
    {:noreply, socket |> assign(:line_type, type) |> assign_line()}
  end

  def handle_event("set_preset", %{"preset" => preset}, socket) when preset in @preset_ids do
    {:noreply, socket |> assign(:preset, preset) |> assign_line()}
  end

  def handle_event("set_radius", %{"behavior" => %{"radius" => radius} = params}, socket) do
    case Integer.parse(radius) do
      {value, _} ->
        {:noreply,
         socket
         |> assign(:radius, value |> max(0) |> min(80))
         |> assign(:radius_form, to_form(params, as: :behavior))
         |> assign_line()}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # Flow options of the current line, the code sample, and `edge_opts` (read
  # by FlowEvents on lf:connect_end): new edges use the preview's path type
  defp assign_line(socket) do
    %{line_type: type, preset: preset, radius: radius} = socket.assigns
    {_id, _label, style, class} = List.keyfind(@presets, preset, 0)

    assign(socket,
      line_style: style,
      line_class: class,
      code: code(type, style, class, radius),
      edge_opts: [type: String.to_existing_atom(type), marker_end: %{type: :arrow_closed}]
    )
  end

  defp style_string(nil), do: nil
  defp style_string(style), do: Enum.map_join(style, "; ", fn {k, v} -> "#{k}: #{v}" end)

  defp code(type, style, class, radius) do
    Enum.join(
      [
        "%{",
        "  connection_line_type: :#{type},",
        "  connection_line_style: #{inspect(style)},",
        "  connection_line_class: #{inspect(class)},",
        "  connection_radius: #{radius}",
        "}"
      ],
      "\n"
    )
  end

  defp build_flow do
    nodes = [
      Samples.card(
        "source",
        0,
        130,
        "Source",
        "Drag from my handle",
        "hero-cursor-arrow-rays",
        :amber,
        inputs: false
      ),
      Samples.card("a", 420, 0, "Target A", "Drop the line here", "hero-inbox-arrow-down", :sky,
        outputs: false
      ),
      Samples.card("b", 420, 130, "Target B", "…or here", "hero-inbox-arrow-down", :violet,
        outputs: false
      ),
      Samples.card("c", 420, 260, "Target C", "…or here", "hero-inbox-arrow-down", :emerald,
        outputs: false
      )
    ]

    State.new(nodes: nodes, edges: [])
  end
end

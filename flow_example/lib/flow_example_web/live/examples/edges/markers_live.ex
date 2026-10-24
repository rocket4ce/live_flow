defmodule FlowExampleWeb.Examples.Edges.MarkersLive do
  @moduledoc """
  Edge Markers: Make your edges into arrows, circles or custom markers.

  Every `marker_start` / `marker_end` config (`%{type, color, width, height,
  stroke_width}`) becomes one shared SVG `<marker>` definition; identical
  configs reuse the same definition.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Node, State}

  @types ~w(arrow arrow_closed circle circle_filled diamond diamond_filled)

  @playground %{
    "marker_start" => "circle_filled",
    "marker_end" => "arrow_closed",
    "color" => "#6366f1",
    "size" => "16",
    "stroke_width" => "1",
    "color_edge" => "true"
  }

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> FlowEvents.assign_flow(build_flow())
     |> assign_playground(@playground)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #markers-flow .lf-edge-label {
        font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
        font-size: 11px;
        font-weight: 500;
        white-space: nowrap;
      }
      #markers-flow .lf-node[data-node-type="section"] {
        background: transparent;
        border: none;
        box-shadow: none;
        cursor: default;
      }
      #markers-flow .lf-node[data-node-type="playground"] {
        border-style: dashed;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="markers-flow"
        flow={@flow}
        node_types={%{pill: &pill_node/1, section: &section_node/1, playground: &pill_node/1}}
        opts={%{background: :dots, controls: true, fit_view_on_init: true}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Markers are set per edge with <code>marker_start</code>
            and <code>marker_end</code>: <code phx-no-curly-interpolation>%{type: :arrow_closed, color: "#ff0072", width: 20, height: 20}</code>. The default end marker is <code phx-no-curly-interpolation>%{type: :arrow}</code>; use
            <code>type: :none</code>
            to remove it.
          </.hint>
          <.hint>
            Types: <code>:arrow</code>, <code>:arrow_closed</code>, <code>:circle</code>, <code>:circle_filled</code>,
            <code>:diamond</code>
            and <code>:diamond_filled</code>.
            Without a <code>color</code>
            a marker follows the theme's edge color.
          </.hint>
        </.option_group>

        <.form for={@form} id="marker-form" phx-change="update_marker">
          <.option_group title="Playground edge">
            <div class="grid grid-cols-2 gap-x-3">
              <.input
                field={@form[:marker_start]}
                type="select"
                label="Start"
                class={select_class()}
                options={marker_options()}
              />
              <.input
                field={@form[:marker_end]}
                type="select"
                label="End"
                class={select_class()}
                options={marker_options()}
              />
            </div>
            <.input
              field={@form[:color]}
              type="color"
              label="Color"
              class="h-9 w-full cursor-pointer rounded-lg border border-base-300 bg-base-100 p-1 transition-colors hover:border-base-content/30"
            />
            <.range field={@form[:size]} label="width / height" min="6" max="32" />
            <.range
              field={@form[:stroke_width]}
              label="stroke_width"
              min="0.5"
              max="3"
              step="0.5"
            />
            <.input
              field={@form[:color_edge]}
              type="checkbox"
              label="Color the edge too"
              class={switch_class()}
            />
            <pre
              id="marker-code"
              class="mt-2 overflow-x-auto rounded-lg bg-base-200 p-3 font-mono text-[11px] leading-relaxed text-base-content/80"
            >{@code}</pre>
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

  defp pill_node(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <span
        class="size-2 rounded-full"
        style={"background: #{@node.data[:color] || "var(--lf-edge-stroke)"}"}
      />
      <span class="text-xs font-medium" style="color: var(--lf-text-primary)">
        {@node.data.label}
      </span>
    </div>
    """
  end

  attr :node, :map, required: true

  defp section_node(assigns) do
    ~H"""
    <p
      class="text-[11px] font-semibold uppercase tracking-wider"
      style="color: var(--lf-text-secondary)"
    >
      {@node.data.label}
    </p>
    """
  end

  @impl true
  def handle_event("update_marker", %{"playground" => params}, socket) do
    {:noreply, assign_playground(socket, Map.merge(@playground, params))}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # The playground edge is rebuilt from the form params
  defp assign_playground(socket, params) do
    opts = playground_opts(params)

    flow =
      State.update_edge(socket.assigns.flow, "playground", Keyword.delete(opts, :code))

    socket
    |> assign(:flow, flow)
    |> assign(:form, to_form(params, as: :playground))
    |> assign(:code, opts[:code])
  end

  defp playground_opts(params) do
    color = params["color"]
    size = parse_number(params["size"], 16)
    stroke_width = parse_number(params["stroke_width"], 1)
    color_edge? = params["color_edge"] == "true"

    marker = fn type ->
      if type in @types do
        %{
          type: String.to_existing_atom(type),
          color: color,
          width: size,
          height: size,
          stroke_width: stroke_width
        }
      end
    end

    marker_start = marker.(params["marker_start"])
    marker_end = marker.(params["marker_end"])
    style = if color_edge?, do: %{stroke: color, "stroke-width": 2}, else: %{}

    code =
      Enum.join(
        [
          ~s|Edge.new("playground", "p-source", "p-target",|,
          "  marker_start: #{marker_code(marker_start)},",
          "  marker_end: #{marker_code(marker_end)},",
          "  style: #{inspect(style)}",
          ")"
        ],
        "\n"
      )

    [
      marker_start: marker_start,
      marker_end: marker_end || %{type: :none},
      style: style,
      code: code
    ]
  end

  defp marker_code(nil), do: "%{type: :none}"

  defp marker_code(marker) do
    ~s|%{type: #{inspect(marker.type)}, color: "#{marker.color}", | <>
      "width: #{marker.width}, height: #{marker.height}, stroke_width: #{marker.stroke_width}}"
  end

  defp marker_options do
    [{"none", "none"} | Enum.map(@types, &{&1, &1})]
  end

  defp parse_number(value, default) do
    case Float.parse(to_string(value)) do
      {number, _} when number == trunc(number) -> trunc(number)
      {number, _} -> number
      :error -> default
    end
  end

  defp build_flow do
    type_rows =
      @types
      |> Enum.with_index()
      |> Enum.map(fn {type, i} ->
        {"t-#{type}", 0, i, type, [marker_end: %{type: String.to_existing_atom(type)}], nil}
      end)

    custom_rows = [
      {"both-ends", 1, 0, "start + end",
       [marker_start: %{type: :circle_filled}, marker_end: %{type: :arrow_closed}], nil},
      {"color", 1, 1, "color: #ff0072", [marker_end: %{type: :arrow_closed, color: "#ff0072"}],
       nil},
      {"size", 1, 2, "width/height: 24",
       [marker_end: %{type: :arrow_closed, width: 24, height: 24}], nil},
      {"stroke", 1, 3, "stroke_width: 2.5",
       [marker_end: %{type: :arrow, width: 16, height: 16, stroke_width: 2.5}], nil},
      {"colored-edge", 1, 4, "colored edge",
       [
         marker_start: %{type: :diamond_filled, color: "#10b981"},
         marker_end: %{type: :arrow_closed, color: "#10b981"},
         style: %{stroke: "#10b981", "stroke-width": 2.5}
       ], "#10b981"},
      {"no-marker", 1, 5, "type: :none", [marker_end: %{type: :none}], nil}
    ]

    rows = type_rows ++ custom_rows

    nodes =
      [
        Node.new("section-types", %{x: 0, y: -60}, %{label: "Marker types"},
          type: :section,
          connectable: false,
          selectable: false,
          draggable: false
        ),
        Node.new("section-custom", %{x: 620, y: -60}, %{label: "Customization"},
          type: :section,
          connectable: false,
          selectable: false,
          draggable: false
        ),
        Node.new("p-source", %{x: 160, y: 540}, %{label: "Playground", color: "#6366f1"},
          type: :playground
        ),
        Node.new("p-target", %{x: 780, y: 620}, %{label: "Target", color: "#6366f1"},
          type: :playground
        )
      ] ++
        Enum.flat_map(rows, fn {id, column, row, _label, _opts, color} ->
          x = column * 620
          y = row * 80

          [
            Node.new("#{id}-a", %{x: x, y: y}, %{label: "Source", color: color}, type: :pill),
            Node.new("#{id}-b", %{x: x + 400, y: y}, %{label: "Target", color: color},
              type: :pill
            )
          ]
        end)

    edges =
      Enum.map(rows, fn {id, _column, _row, label, opts, _color} ->
        Edge.new(id, "#{id}-a", "#{id}-b", [type: :straight, label: label] ++ opts)
      end) ++
        [
          Edge.new("playground", "p-source", "p-target",
            type: :smoothstep,
            label: "playground",
            path_options: %{border_radius: 12}
          )
        ]

    State.new(nodes: nodes, edges: edges)
  end
end

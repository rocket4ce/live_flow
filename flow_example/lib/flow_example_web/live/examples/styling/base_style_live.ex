defmodule FlowExampleWeb.Examples.Styling.BaseStyleLive do
  @moduledoc """
  Base Style: the bare-bones base style without a theme.

  Default nodes, default edges and no `theme` option: the flow uses the
  default `--lf-*` variables of `live_flow.css`. Every color, radius and size
  is a CSS variable, so restyling a flow is a matter of overriding a few of
  them on (or above) `.lf-container`.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}

  @accents [
    {"Pink", "#ff0072"},
    {"Emerald", "#10b981"},
    {"Violet", "#8b5cf6"},
    {"Amber", "#f59e0b"}
  ]

  @override_defaults %{"enabled" => "false", "accent" => "#ff0072", "radius" => "3"}

  # Variables declared by live_flow.css (and every theme)
  @variables [
    {"Canvas",
     ~w(--lf-background --lf-background-dots-color --lf-background-lines-color --lf-background-cross-color)},
    {"Nodes",
     ~w(--lf-node-bg --lf-node-border --lf-node-border-radius --lf-node-shadow --lf-node-shadow-hover --lf-node-selected-border --lf-node-selected-shadow)},
    {"Edges",
     ~w(--lf-edge-stroke --lf-edge-stroke-width --lf-edge-stroke-selected --lf-edge-stroke-animated)},
    {"Handles",
     ~w(--lf-handle-size --lf-handle-bg --lf-handle-border --lf-handle-border-width --lf-handle-hover-bg)},
    {"Selection & guides", ~w(--lf-selection-bg --lf-selection-border --lf-helper-line-color)},
    {"Minimap",
     ~w(--lf-minimap-bg --lf-minimap-border --lf-minimap-node-bg --lf-minimap-viewport-border)},
    {"Controls",
     ~w(--lf-controls-bg --lf-controls-border --lf-controls-button-hover --lf-controls-color)},
    {"Text & surfaces",
     ~w(--lf-text-primary --lf-text-secondary --lf-text-muted --lf-surface-secondary --lf-border-secondary)},
    {"Delete buttons", ~w(--lf-delete-hover-bg --lf-delete-hover-color --lf-delete-hover-border)}
  ]

  @classes [
    {".lf-container", "root element (the flow id), holds the variables"},
    {".lf-node", "node wrapper: data-node-type, data-selected, data-dragging"},
    {".lf-node-content", "padding around the node content"},
    {".lf-default-node-label", "label of default nodes"},
    {".lf-handle", "handles: data-handle-type, data-handle-position"},
    {".lf-edge-group", "edge <g>: data-edge-id, data-source, data-target"},
    {".lf-edge", "visible edge path: data-selected, data-animated"},
    {".lf-edge-label", "edge label"},
    {".lf-background", "dots / lines / cross pattern"},
    {".lf-controls", "zoom controls (.lf-controls-button)"},
    {".lf-minimap", "minimap (.lf-minimap-node, .lf-minimap-viewport)"},
    {".lf-selection-box", "drag selection rectangle"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(variables: @variables, classes: @classes, accents: @accents)
     |> assign_override(@override_defaults)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      /* .lf-container declares its own defaults, so it has to be told to take
         the overrides set inline on the wrapper */
      #base-style-canvas[data-custom] .lf-container {
        --lf-node-border: inherit;
        --lf-node-border-radius: inherit;
        --lf-node-selected-border: inherit;
        --lf-node-selected-shadow: inherit;
        --lf-edge-stroke-selected: inherit;
        --lf-edge-stroke-animated: inherit;
        --lf-handle-border: inherit;
        --lf-handle-hover-bg: inherit;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <div
        id="base-style-canvas"
        class="absolute inset-0"
        data-custom={@override["enabled"] == "true"}
        style={@override_style}
      >
        <.live_component
          module={LiveFlow.Components.Flow}
          id="base-style-flow"
          flow={@flow}
          opts={
            %{
              background: :dots,
              controls: true,
              minimap: true,
              fit_view_on_init: true,
              fit_view_options: %{padding: 0.3}
            }
          }
        />
      </div>

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            No <code>theme</code>, no <code>node_types</code>, no <code>edge_types</code>: this is
            what <code>live_flow.css</code>
            looks like out of the box. Without a theme the flow also follows the
            site's dark mode.
          </.hint>
          <.hint>
            Everything is driven by <code>--lf-*</code>
            CSS variables, so a flow is restyled by overriding them instead of
            fighting selectors.
          </.hint>
        </.option_group>

        <.option_group title="Override variables" tag="live">
          <.form for={@override_form} id="base-style-overrides" phx-change="override">
            <.input
              field={@override_form[:enabled]}
              type="checkbox"
              label="Override on a wrapper"
              class={switch_class()}
            />
            <.input
              field={@override_form[:accent]}
              type="select"
              label="Accent"
              class={select_class()}
              options={@accents}
            />
            <.range field={@override_form[:radius]} label="Node radius (px)" min="0" max="24" />
          </.form>
          <pre
            id="base-style-css"
            class={[
              "overflow-x-auto rounded-lg bg-base-200 p-2.5 font-mono text-[10.5px] leading-relaxed text-base-content/70 transition-opacity",
              @override["enabled"] != "true" && "opacity-50"
            ]}
            phx-no-curly-interpolation
          ><%= override_css(@override) %></pre>
          <.hint>
            The wrapper sets the variables inline; one CSS rule makes <code>.lf-container</code>
            inherit them. In your app a plain rule is enough:
            <code phx-no-curly-interpolation>.my-flow .lf-container { --lf-edge-stroke: #ff0072; }</code>
          </.hint>
        </.option_group>

        <.option_group title="CSS variables">
          <div :for={{group, names} <- @variables} class="pb-2">
            <p class="pb-1 text-[11px] font-medium text-base-content/70">{group}</p>
            <div class="flex flex-wrap gap-1">
              <span
                :for={name <- names}
                class="inline-flex items-center gap-1 rounded bg-base-200 px-1.5 py-0.5 font-mono text-[10px] text-base-content/70"
              >
                <span
                  :if={color_variable?(name)}
                  class="lf-container inline-block shrink-0 rounded-sm ring-1 ring-base-content/15"
                  style={"width: 0.6rem; height: 0.6rem; cursor: inherit; background: var(#{name})"}
                />
                {name}
              </span>
            </div>
          </div>
          <.hint>Swatches show the default value with the current site theme.</.hint>
        </.option_group>

        <.option_group title="CSS classes">
          <dl class="space-y-1.5">
            <div :for={{class, description} <- @classes}>
              <dt class="font-mono text-[11px] font-semibold text-primary">{class}</dt>
              <dd class="text-[11px] text-base-content/55">{description}</dd>
            </div>
          </dl>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  @impl true
  def handle_event("override", %{"override" => params}, socket) do
    {:noreply, assign_override(socket, Map.merge(socket.assigns.override, params))}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp assign_override(socket, params) do
    accents = Enum.map(@accents, &elem(&1, 1))

    params = %{
      "enabled" => if(params["enabled"] == "true", do: "true", else: "false"),
      "accent" => if(params["accent"] in accents, do: params["accent"], else: "#ff0072"),
      "radius" => clamp_radius(params["radius"])
    }

    style =
      if params["enabled"] == "true",
        do: params |> override_vars() |> Enum.map_join(" ", fn {k, v} -> "#{k}: #{v};" end)

    assign(socket,
      override: params,
      override_form: to_form(params, as: :override),
      override_style: style
    )
  end

  defp override_vars(%{"accent" => accent, "radius" => radius}) do
    [
      {"--lf-node-border", accent},
      {"--lf-node-border-radius", "#{radius}px"},
      {"--lf-node-selected-border", accent},
      {"--lf-node-selected-shadow", "0 0 0 3px color-mix(in oklab, #{accent} 25%, transparent)"},
      {"--lf-edge-stroke-selected", accent},
      {"--lf-edge-stroke-animated", accent},
      {"--lf-handle-border", accent},
      {"--lf-handle-hover-bg", accent}
    ]
  end

  defp override_css(params) do
    body =
      params
      |> override_vars()
      |> Enum.map_join("\n", fn {k, v} -> "  #{k}: #{v};" end)

    ~s(<div id="base-style-canvas" style="\n#{body}\n">)
  end

  defp clamp_radius(value) do
    case Integer.parse(to_string(value)) do
      {n, _} -> n |> max(0) |> min(24) |> to_string()
      :error -> "3"
    end
  end

  defp color_variable?(name) do
    not String.ends_with?(name, ~w(-radius -shadow -shadow-hover -width -size))
  end

  defp build_flow do
    nodes = [
      Node.new("1", %{x: 0, y: 120}, %{label: "Node 1"}, handles: [Handle.source(:right)]),
      Node.new("2", %{x: 260, y: 20}, %{label: "Node 2"}),
      Node.new("3", %{x: 260, y: 220}, %{label: "Node 3"}),
      Node.new("4", %{x: 520, y: 220}, %{label: "Node 4"}, handles: [Handle.target(:left)])
    ]

    edges = [
      Edge.new("e1-2", "1", "2", animated: true),
      Edge.new("e1-3", "1", "3", label: "edge label")
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

defmodule FlowExampleWeb.Examples.Nodes.CustomNodeLive do
  @moduledoc """
  Custom Nodes: any content inside of a node.

  The color selector node holds a regular form; its `phx-change` updates the
  node data and the flow background.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}

  @initial_color "#c9f1dd"
  @swatches ~w(#c9f1dd #1a192b #ffd6a5 #cdb4db #a0c4ff #ff0072)

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, swatches: @swatches)
     |> assign_color(@initial_color)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      /* The wrapper sets --cn-bg / --cn-ink; .lf-container defines its own
         --lf-* defaults, so they are mapped here instead of inherited. */
      #custom-node-flow {
        --lf-background: var(--cn-bg);
        --lf-background-dots-color: color-mix(in oklab, var(--cn-ink) 22%, transparent);
        --lf-edge-stroke: var(--cn-ink);
        --lf-edge-stroke-animated: var(--cn-ink);
        transition: background-color 250ms ease;
      }

      #custom-node-flow .lf-connection-line {
        stroke: var(--cn-ink);
      }

      #custom-node-flow .lf-node[data-node-type="selector"] {
        border-width: 1.5px;
        border-color: color-mix(in oklab, var(--cn-bg) 60%, var(--lf-node-border));
      }

      #custom-node-flow .color-input::-webkit-color-swatch-wrapper {
        padding: 0;
      }

      #custom-node-flow .color-input::-webkit-color-swatch {
        border: none;
        border-radius: 6px;
      }

      #custom-node-flow .color-input::-moz-color-swatch {
        border: none;
        border-radius: 6px;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <div
        id="custom-node-canvas"
        class="absolute inset-0"
        style={"--cn-bg: #{@bg_color}; --cn-ink: #{@ink}"}
      >
        <.live_component
          module={LiveFlow.Components.Flow}
          id="custom-node-flow"
          flow={@flow}
          node_types={%{io: &io_node/1, selector: &selector_node/1}}
          opts={
            %{
              background: :dots,
              controls: true,
              minimap: true,
              snap_to_grid: true,
              snap_grid: {20, 20},
              min_zoom: 0.3,
              max_zoom: 2,
              fit_view_on_init: true
            }
          }
        />
      </div>

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Nodes are function components passed in <code>node_types</code>. The <b>color picker</b>
            node renders a form with a <code>&lt;input type="color"&gt;</code>; its
            <code>phx-change</code>
            is handled by the LiveView like any other form.
          </.hint>
          <.hint>
            The handler stores the color in the node data and on the page. Inputs never start a
            node drag, and keyboard shortcuts are ignored while they have focus.
          </.hint>
          <.hint>
            The canvas color comes from a wrapper <code>style</code>
            mapped to <code>--lf-background</code>; edges switch to a dark or light stroke to keep
            contrast.
          </.hint>
        </.option_group>
        <.option_group title="Presets">
          <div class="flex flex-wrap gap-2">
            <button
              :for={swatch <- @swatches}
              id={"swatch-#{String.trim_leading(swatch, "#")}"}
              type="button"
              phx-click="change_color"
              phx-value-color={swatch}
              title={swatch}
              class={[
                "size-7 rounded-lg border border-base-300 shadow-xs transition-transform duration-150 hover:scale-110 active:scale-95",
                swatch == @bg_color && "ring-2 ring-primary ring-offset-2 ring-offset-base-100"
              ]}
              style={"background: #{swatch}"}
            />
          </div>
        </.option_group>
        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp io_node(assigns) do
    ~H"""
    <div class="flex w-36 items-center gap-2.5">
      <span class={[
        "grid size-7 shrink-0 place-items-center rounded-md",
        if(@node.data.kind == :input,
          do: "bg-sky-500/15 text-sky-600",
          else: "bg-violet-500/15 text-violet-600"
        )
      ]}>
        <.icon
          name={if(@node.data.kind == :input, do: "hero-play-mini", else: "hero-flag-mini")}
          class="size-4"
        />
      </span>
      <div class="min-w-0">
        <p
          class="text-[10px] font-medium uppercase tracking-wider"
          style="color: var(--lf-text-secondary)"
        >
          {@node.data.kind}
        </p>
        <p class="truncate text-[13px] font-semibold" style="color: var(--lf-text-primary)">
          {@node.data.label}
        </p>
      </div>
    </div>
    """
  end

  attr :node, :map, required: true

  defp selector_node(assigns) do
    ~H"""
    <div class="w-52">
      <p
        class="text-[10px] font-medium uppercase tracking-wider"
        style="color: var(--lf-text-secondary)"
      >
        Custom color picker node
      </p>
      <p
        id="selector-color"
        class="mt-0.5 font-mono text-sm font-semibold"
        style="color: var(--lf-text-primary)"
      >
        {@node.data.color}
      </p>
      <form id="color-form" phx-change="change_color" class="nodrag mt-2">
        <input
          id="color-input"
          type="color"
          name="color"
          value={@node.data.color}
          phx-debounce="40"
          class="color-input nodrag block h-8 w-full cursor-pointer rounded-lg border bg-transparent p-0.5"
          style="border-color: var(--lf-node-border)"
        />
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("change_color", %{"color" => color}, socket) do
    if valid_color?(color) do
      flow =
        State.update_node(socket.assigns.flow, "selector", fn node ->
          %{node | data: %{node.data | color: color}}
        end)

      {:noreply,
       socket
       |> assign(:flow, flow)
       |> assign_color(color)
       |> FlowEvents.log("change_color", %{"color" => color})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # The value ends up in a style attribute: only accept #rrggbb
  defp valid_color?(color), do: is_binary(color) and color =~ ~r/\A#[0-9a-fA-F]{6}\z/

  defp assign_color(socket, color) do
    assign(socket, bg_color: color, ink: ink_for(color))
  end

  # Dark strokes on light backgrounds, white strokes on dark ones (WCAG
  # relative luminance).
  defp ink_for("#" <> hex) do
    [r, g, b] =
      for <<channel::binary-size(2) <- hex>> do
        value = String.to_integer(channel, 16) / 255
        if value <= 0.03928, do: value / 12.92, else: :math.pow((value + 0.055) / 1.055, 2.4)
      end

    if 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.4, do: "#1a192b", else: "#ffffff"
  end

  defp build_flow do
    nodes = [
      Node.new("input", %{x: 0, y: 60}, %{kind: :input, label: "An input node"},
        type: :io,
        handles: [Handle.source(:right)]
      ),
      Node.new("selector", %{x: 260, y: 20}, %{color: @initial_color},
        type: :selector,
        handles: [
          Handle.target(:left),
          Handle.source(:right, id: "a", offset: 0.3),
          Handle.source(:right, id: "b", offset: 0.75)
        ]
      ),
      Node.new("output-a", %{x: 600, y: -20}, %{kind: :output, label: "Output A"},
        type: :io,
        handles: [Handle.target(:left)]
      ),
      Node.new("output-b", %{x: 600, y: 140}, %{kind: :output, label: "Output B"},
        type: :io,
        handles: [Handle.target(:left)]
      )
    ]

    edges = [
      Edge.new("e-input-selector", "input", "selector", animated: true),
      Edge.new("e-selector-a", "selector", "output-a", source_handle: "a", animated: true),
      Edge.new("e-selector-b", "selector", "output-b", source_handle: "b", animated: true)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

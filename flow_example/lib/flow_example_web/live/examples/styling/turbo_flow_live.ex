defmodule FlowExampleWeb.Examples.Styling.TurboFlowLive do
  @moduledoc """
  Turbo Flow: nodes with glowing animated gradient borders.

  A port of React Flow's turbo example (inspired by turbo.build): a dark
  canvas, custom nodes whose border is a conic gradient (it spins while the
  node is hovered or selected) and a custom edge type stroked with an SVG
  gradient and ended with a circle marker.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Node, State}

  @marker %{type: :circle, color: "#2a8af6", width: 6, height: 6, stroke_width: 1.2}

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(edge_opts: edge_opts())
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #turbo-flow {
        --turbo-bg: rgb(17, 17, 17);
        --turbo-text: rgb(243, 244, 246);
        --turbo-radius: 10px;
        --turbo-glow: 10px 0 15px rgba(42, 138, 246, 0.3), -10px 0 15px rgba(233, 42, 103, 0.3);
        --lf-background: var(--turbo-bg);
        --lf-background-dots-color: #2b2b2b;
        --lf-controls-bg: var(--turbo-bg);
        --lf-controls-border: #95679e;
        --lf-controls-color: var(--turbo-text);
        --lf-controls-button-hover: #1f1f1f;
        --lf-minimap-bg: rgba(17, 17, 17, 0.92);
        --lf-minimap-border: #3b2f42;
        --lf-minimap-node-bg: #95679e;
        --lf-minimap-viewport-border: #2a8af6;
        --lf-selection-bg: rgba(42, 138, 246, 0.08);
        --lf-selection-border: rgba(42, 138, 246, 0.8);
        --lf-edge-stroke: #a853ba;
        color: var(--turbo-text);
      }

      /* The custom node draws the whole card: reset the wrapper */
      #turbo-flow .lf-node[data-node-type="turbo"] {
        background: transparent;
        border: none;
        border-radius: var(--turbo-radius);
        box-shadow: var(--turbo-glow);
      }

      #turbo-flow .lf-node[data-node-type="turbo"] > .lf-node-content {
        padding: 0;
      }

      #turbo-flow .lf-node[data-node-type="turbo"] .lf-handle {
        opacity: 0;
        background: var(--turbo-bg);
        border-color: #2a8af6;
        transition: opacity 0.2s ease, transform 0.15s ease;
      }

      #turbo-flow .lf-node[data-node-type="turbo"]:hover .lf-handle,
      #turbo-flow .lf-handle[data-connecting],
      #turbo-flow .lf-handle[data-connecting-source] {
        opacity: 1;
      }

      /* The cloud badge lives in the top-right corner: move the delete button */
      #turbo-flow .lf-node[data-node-type="turbo"] .lf-node-delete-btn {
        right: auto;
        left: -10px;
      }

      #turbo-flow .turbo-node {
        display: flex;
        position: relative;
        height: 70px;
        min-width: 150px;
        border-radius: var(--turbo-radius);
        letter-spacing: -0.2px;
      }

      #turbo-flow .turbo-wrapper {
        position: relative;
        display: flex;
        flex-grow: 1;
        overflow: hidden;
        padding: 2px;
        border-radius: var(--turbo-radius);
      }

      /* Oversized rotating disc behind the inner card: only a 2px ring shows */
      #turbo-flow .turbo-gradient::before {
        content: "";
        position: absolute;
        left: 50%;
        top: 50%;
        width: calc(100% * 1.41421356237);
        padding-bottom: calc(100% * 1.41421356237);
        border-radius: 100%;
        transform: translate(-50%, -50%);
        background: conic-gradient(
          from -160deg at 50% 50%,
          #e92a67 0deg,
          #a853ba 120deg,
          #2a8af6 240deg,
          #e92a67 360deg
        );
      }

      #turbo-flow .lf-node[data-selected="true"] .turbo-wrapper::before,
      #turbo-flow .lf-node:hover .turbo-wrapper::before {
        background: conic-gradient(
          from -160deg at 50% 50%,
          #e92a67 0deg,
          #a853ba 120deg,
          #2a8af6 240deg,
          rgba(42, 138, 246, 0) 360deg
        );
        animation: turbo-spin 4s linear infinite;
      }

      #turbo-flow .lf-node[data-selected="true"] {
        box-shadow: var(--turbo-glow), 0 0 0 1px rgba(42, 138, 246, 0.15);
      }

      @keyframes turbo-spin {
        100% {
          transform: translate(-50%, -50%) rotate(-360deg);
        }
      }

      #turbo-flow .turbo-inner {
        position: relative;
        display: flex;
        flex-direction: column;
        justify-content: center;
        flex-grow: 1;
        padding: 16px 20px;
        border-radius: calc(var(--turbo-radius) - 2px);
        background: var(--turbo-bg);
      }

      #turbo-flow .turbo-cloud {
        position: absolute;
        top: 0;
        right: 0;
        z-index: 1;
        display: flex;
        width: 30px;
        height: 30px;
        padding: 2px;
        overflow: hidden;
        border-radius: 100%;
        transform: translate(50%, -50%);
        box-shadow: var(--turbo-glow);
      }

      #turbo-flow .turbo-cloud > div {
        position: relative;
        display: flex;
        flex-grow: 1;
        align-items: center;
        justify-content: center;
        border-radius: 100%;
        background: var(--turbo-bg);
      }

      #turbo-flow .turbo-edge > .lf-edge {
        stroke-width: 2;
        stroke-opacity: 0.75;
        transition: stroke-opacity 0.15s ease, stroke-width 0.15s ease;
      }

      #turbo-flow .turbo-edge:hover > .lf-edge {
        stroke-opacity: 1;
      }

      #turbo-flow .turbo-edge > .lf-edge[data-selected="true"] {
        stroke-width: 3;
        stroke-opacity: 1;
        filter: drop-shadow(0 0 4px rgba(42, 138, 246, 0.7));
      }

      #turbo-flow .lf-connection-line {
        stroke: #a853ba;
        stroke-width: 2;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="turbo-flow"
        flow={@flow}
        node_types={%{turbo: &turbo_node/1}}
        edge_types={%{turbo: &turbo_edge/1}}
        opts={
          %{
            theme: "dark",
            background: :dots,
            background_gap: 24,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.3}
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            <b>Nodes:</b>
            an oversized <code>conic-gradient</code>
            disc sits behind the dark inner card, so only a 2px ring shows. Hover or select a node and the disc rotates.
          </.hint>
          <.hint>
            <b>Edges:</b>
            a custom <code>edge_types</code>
            renderer draws the path with a <code>&lt;linearGradient&gt;</code>
            defined inside its own <code>&lt;g&gt;</code>
            (unique id per edge, from source to target) and the edge's <code>marker_end</code>.
          </.hint>
          <.hint>
            The edge group carries <code>data-source</code>/<code>data-target</code>, so the client redraws it while you drag.
          </.hint>
        </.option_group>

        <.option_group title="Used here">
          <ul class="space-y-1 text-xs text-base-content/60">
            <li><code>theme: "dark"</code> + scoped <code>--lf-*</code> overrides</li>
            <li><code>node_types: %&lbrace;turbo: &amp;turbo_node/1&rbrace;</code></li>
            <li><code>edge_types: %&lbrace;turbo: &amp;turbo_edge/1&rbrace;</code></li>
            <li><code>marker_end: %&lbrace;type: :circle&rbrace;</code></li>
            <li>Colocated CSS (<code>FlowExampleWeb.ColocatedCSS</code>)</li>
          </ul>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp turbo_node(assigns) do
    ~H"""
    <div class="turbo-node font-mono font-medium">
      <div class="turbo-cloud turbo-gradient">
        <div><.icon name="hero-cloud" class="size-3.5" /></div>
      </div>
      <div class="turbo-wrapper turbo-gradient">
        <div class="turbo-inner">
          <div class="flex items-center">
            <div :if={@node.data[:icon]} class="mr-2 flex shrink-0 text-[#a3a3a3]">
              <.icon name={@node.data.icon} class="size-6" />
            </div>
            <div class="min-w-0">
              <div class="mb-0.5 text-base leading-none whitespace-nowrap">{@node.data.title}</div>
              <div :if={@node.data[:subline]} class="text-xs whitespace-nowrap text-[#777]">
                {@node.data.subline}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Custom edge renderer. The gradient uses userSpaceOnUse coordinates from the
  # source to the target handle: objectBoundingBox gradients disappear on
  # perfectly horizontal paths (zero-height bounding box).
  defp turbo_edge(assigns) do
    assigns =
      assign(assigns,
        gradient_id: "turbo-gradient-#{assigns.edge.id}",
        from: assigns.source_pos || %{x: 0, y: 0},
        to: assigns.target_pos || %{x: 0, y: 0}
      )

    ~H"""
    <g
      class="lf-edge-group turbo-edge"
      data-edge-id={@edge.id}
      data-source={@edge.source}
      data-target={@edge.target}
      data-source-handle={@edge.source_handle}
      data-target-handle={@edge.target_handle}
      data-path-type="bezier"
    >
      <defs>
        <linearGradient
          id={@gradient_id}
          gradientUnits="userSpaceOnUse"
          x1={@from.x}
          y1={@from.y}
          x2={@to.x}
          y2={@to.y}
        >
          <stop offset="0%" stop-color="#ae53ba" />
          <stop offset="100%" stop-color="#2a8af6" />
        </linearGradient>
      </defs>
      <path class="lf-edge-interaction" d={@path} data-edge-id={@edge.id} />
      <path
        class="lf-edge"
        d={@path}
        data-edge-id={@edge.id}
        data-selected={to_string(@edge.selected)}
        marker-end={@marker_end_id}
        style={"stroke: url(##{@gradient_id})"}
      />
    </g>
    """
  end

  @impl true
  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # Also used by FlowEvents for edges created by connecting handles
  defp edge_opts, do: [type: :turbo, marker_end: @marker]

  defp build_flow do
    turbo = fn id, x, y, data -> Node.new(id, %{x: x, y: y}, data, type: :turbo) end
    function = "hero-code-bracket-square"

    nodes = [
      turbo.("1", 0, 0, %{icon: function, title: "readFile", subline: "api.ts"}),
      turbo.("2", 300, 0, %{icon: function, title: "bundle", subline: "apiContents"}),
      turbo.("3", 0, 250, %{icon: function, title: "readFile", subline: "sdk.ts"}),
      turbo.("4", 300, 250, %{icon: function, title: "bundle", subline: "sdkContents"}),
      turbo.("5", 600, 125, %{icon: function, title: "concat", subline: "api, sdk"}),
      turbo.("6", 900, 125, %{icon: "hero-document-text", title: "fullBundle"})
    ]

    edges =
      for {source, target} <- [{"1", "2"}, {"3", "4"}, {"2", "5"}, {"4", "5"}, {"5", "6"}] do
        Edge.new("e#{source}-#{target}", source, target, edge_opts())
      end

    State.new(nodes: nodes, edges: edges)
  end
end

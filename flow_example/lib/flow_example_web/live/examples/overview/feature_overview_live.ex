defmodule FlowExampleWeb.Examples.Overview.FeatureOverviewLive do
  @moduledoc """
  Feature Overview: the most used LiveFlow features on one canvas.

  Built-in looking input/default/output nodes, custom nodes (annotations, a
  node with a toolbar, a resizable node, a circle and a text input), every
  edge path type, animated and styled edges, labels, markers, plus controls,
  minimap and background.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}
  alias LiveFlow.Components.{NodeResizer, NodeToolbar}

  @emojis ~w(🚀 🔥 ✨ 🌈)

  @features [
    {"hero-cube", "Node types", "input, default and output nodes"},
    {"hero-puzzle-piece", "Custom nodes", "toolbar, resizer, circle, text input, annotations"},
    {"hero-arrows-right-left", "Edge paths", "bezier, straight, step and smoothstep"},
    {"hero-paint-brush", "Edge styling", "animated, labels, markers and colors"},
    {"hero-map", "Overlays", "controls, minimap and dotted background"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, features: @features)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      /* Annotations: plain text on the canvas */
      #feature-overview .lf-node[data-node-type="annotation"],
      #feature-overview .lf-node[data-node-type="annotation"]:hover {
        background: transparent;
        border-color: transparent;
        box-shadow: none;
        cursor: default;
      }

      #feature-overview .lf-node[data-node-type="annotation"] .lf-node-content {
        padding: 0;
      }

      /* Built-in node types get an accent on their left side */
      #feature-overview .lf-node[data-node-type="input"] {
        border-left: 3px solid #0ea5e9;
      }

      #feature-overview .lf-node[data-node-type="output"] {
        border-left: 3px solid #8b5cf6;
      }

      #feature-overview .lf-node[data-node-type="circle"] {
        border-radius: 9999px;
      }

      #feature-overview .lf-node[data-node-type="circle"] .lf-node-content {
        min-width: 0;
        padding: 0;
      }

      #feature-overview .lf-node[data-node-type="resizer"] .lf-node-content {
        box-sizing: border-box;
        height: 100%;
      }

      #feature-overview .overview-emoji {
        transition: transform 200ms cubic-bezier(0.34, 1.56, 0.64, 1);
      }

      #feature-overview .lf-node:hover .overview-emoji {
        transform: scale(1.15) rotate(-6deg);
      }

      #feature-overview .tb-btn {
        display: grid;
        place-items: center;
        width: 30px;
        height: 30px;
        border-radius: 8px;
        font-size: 16px;
        transition: background-color 150ms ease, transform 150ms ease;
      }

      #feature-overview .tb-btn:hover {
        background: var(--lf-controls-button-hover);
        transform: translateY(-1px);
      }

      #feature-overview .tb-btn:active {
        transform: scale(0.9);
      }

      #feature-overview .tb-btn[aria-pressed="true"] {
        background: color-mix(in oklab, var(--lf-node-selected-border) 16%, transparent);
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action
          id="overview-fit"
          icon="hero-arrows-pointing-out"
          phx-click={JS.dispatch("lf:fit-view", to: "#feature-overview")}
        >
          Fit view
        </.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="feature-overview"
        flow={@flow}
        node_types={
          %{
            annotation: &annotation_node/1,
            toolbar: &toolbar_node/1,
            resizer: &resizer_node/1,
            circle: &circle_node/1,
            text_input: &text_input_node/1
          }
        }
        opts={
          %{
            background: :dots,
            controls: true,
            minimap: true,
            minimap_pannable: true,
            minimap_zoomable: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.1}
          }
        }
      />

      <:sidebar>
        <.option_group title="What's on the canvas">
          <ul id="feature-list" class="space-y-2.5">
            <li :for={{icon, title, text} <- @features} class="flex items-start gap-2.5">
              <span class="grid size-7 shrink-0 place-items-center rounded-lg bg-primary/10 text-primary">
                <.icon name={icon} class="size-4" />
              </span>
              <div class="min-w-0">
                <p class="text-[13px] leading-tight font-medium">{title}</p>
                <p class="text-xs text-base-content/55">{text}</p>
              </div>
            </li>
          </ul>
        </.option_group>

        <.option_group title="Try it">
          <.hint>
            Drag nodes, connect handles, select the resizable node to resize it, pick an emoji in the
            toolbar and type in the text node: its text becomes the label of the animated edge.
          </.hint>
          <.hint>
            Select and press
            <.kbd>Backspace</.kbd>
            to delete,
            <.kbd>⌘</.kbd>

            <.kbd>Z</.kbd>
            to undo.
          </.hint>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            Custom nodes are function components in <code>node_types</code>; the toolbar and the
            resize handles come from <code>NodeToolbar.node_toolbar/1</code>
            and <code>NodeResizer.node_resizer/1</code>.
          </.hint>
          <.hint>
            Edges set <code>type</code>, <code>animated</code>, <code>label</code>, <code>label_style</code>, <code>marker_start</code>/<code>marker_end</code>
            and <code>style</code>. Overlays are flow options: <code>controls</code>, <code>minimap</code>, <code>background</code>.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  # ===== Custom nodes =====

  attr :node, :map, required: true

  defp annotation_node(assigns) do
    ~H"""
    <div class="w-64">
      <div class="flex items-start gap-2.5">
        <span
          class="grid size-6 shrink-0 place-items-center rounded-full text-[11px] font-bold text-white shadow-sm"
          style="background: var(--lf-node-selected-border)"
        >
          {@node.data.level}
        </span>
        <p class="pt-0.5 text-[13px] leading-snug" style="color: var(--lf-text-secondary)">
          {@node.data.text}
        </p>
      </div>
      <svg
        :if={@node.data[:arrow]}
        viewBox="0 0 70 44"
        class={[
          "mt-1 ml-6 h-11 w-[70px] overflow-visible",
          @node.data.arrow == :down_left && "-scale-x-100"
        ]}
        fill="none"
        stroke-width="1.6"
        stroke-linecap="round"
        stroke-linejoin="round"
        style="stroke: var(--lf-text-secondary)"
      >
        <path d="M6 4 C 10 26, 34 38, 62 36" />
        <path d="M53 30 L62 36 L53 41" />
      </svg>
    </div>
    """
  end

  attr :node, :map, required: true

  defp toolbar_node(assigns) do
    assigns = assign(assigns, :emojis, @emojis)

    ~H"""
    <NodeToolbar.node_toolbar id={"toolbar-#{@node.id}"} node={@node} is_visible>
      <button
        :for={emoji <- @emojis}
        id={"emoji-#{@node.id}-#{emoji}"}
        type="button"
        class="tb-btn"
        phx-click="set_emoji"
        phx-value-node_id={@node.id}
        phx-value-emoji={emoji}
        aria-pressed={to_string(emoji == @node.data.emoji)}
      >
        {emoji}
      </button>
    </NodeToolbar.node_toolbar>
    <div class="flex w-40 items-center gap-3">
      <span id={"emoji-value-#{@node.id}"} class="overview-emoji text-3xl leading-none">
        {@node.data.emoji}
      </span>
      <div class="min-w-0">
        <p class="text-[13px] font-semibold" style="color: var(--lf-text-primary)">Toolbar node</p>
        <p class="text-[11px]" style="color: var(--lf-text-secondary)">Pick an emoji above</p>
      </div>
    </div>
    """
  end

  attr :node, :map, required: true

  defp resizer_node(assigns) do
    ~H"""
    <NodeResizer.node_resizer
      node_id={@node.id}
      is_visible={@node.selected}
      min_width={170}
      min_height={80}
    />
    <div class="flex h-full flex-col justify-between gap-2">
      <div class="flex items-center gap-2">
        <span class="flex" style="color: var(--lf-node-selected-border)">
          <.icon name="hero-arrows-pointing-out-mini" class="size-4" />
        </span>
        <p class="text-[13px] font-semibold" style="color: var(--lf-text-primary)">
          Resizable node
        </p>
      </div>
      <p class="text-[11px]" style="color: var(--lf-text-secondary)">
        Select me and drag the corners.
      </p>
      <p
        id={"size-#{@node.id}"}
        class="self-end rounded px-1.5 font-mono text-[11px]"
        style="color: var(--lf-text-secondary); background: color-mix(in oklab, var(--lf-text-primary) 6%, transparent)"
      >
        {round(@node.width || 0)} × {round(@node.height || 0)}
      </p>
    </div>
    """
  end

  attr :node, :map, required: true

  defp circle_node(assigns) do
    ~H"""
    <div class="grid size-[110px] place-items-center rounded-full text-center">
      <div>
        <span class="inline-flex" style="color: var(--lf-node-selected-border)">
          <.icon name="hero-map-pin-mini" class="size-4" />
        </span>
        <p class="text-[11px] font-semibold" style="color: var(--lf-text-primary)">Circle node</p>
        <p
          id={"position-#{@node.id}"}
          class="font-mono text-[10px]"
          style="color: var(--lf-text-secondary)"
        >
          {round(@node.position.x)}, {round(@node.position.y)}
        </p>
      </div>
    </div>
    """
  end

  attr :node, :map, required: true

  defp text_input_node(assigns) do
    ~H"""
    <form
      id={"text-form-#{@node.id}"}
      class="w-52"
      phx-change="update_text"
      phx-submit="update_text"
    >
      <p
        class="mb-1.5 flex items-center gap-1.5 text-[11px] font-medium uppercase tracking-wider"
        style="color: var(--lf-text-secondary)"
      >
        <.icon name="hero-pencil-square-mini" class="size-3.5" /> Text input node
      </p>
      <input type="hidden" name="node_id" value={@node.id} />
      <.input
        id={"text-input-#{@node.id}"}
        type="text"
        name="text"
        value={@node.data.text}
        placeholder="Edge label…"
        autocomplete="off"
        maxlength="24"
        phx-debounce="100"
        class="nodrag w-full rounded-md border bg-transparent px-2 py-1 text-sm transition-colors focus:outline-none"
        style="color: var(--lf-text-primary); border-color: var(--lf-node-border)"
      />
    </form>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("set_emoji", %{"node_id" => id, "emoji" => emoji}, socket)
      when emoji in @emojis do
    flow =
      State.update_node(socket.assigns.flow, id, fn node ->
        %{node | data: %{node.data | emoji: emoji}}
      end)

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, flow)
     |> FlowEvents.log("set_emoji", %{"emoji" => emoji})}
  end

  def handle_event("update_text", %{"node_id" => id, "text" => text}, socket)
      when is_binary(id) and is_binary(text) do
    text = String.slice(text, 0, 24)
    flow = socket.assigns.flow

    flow =
      flow
      |> State.update_node(id, fn node -> %{node | data: %{node.data | text: text}} end)
      |> label_edges_from(id, text)

    {:noreply, assign(socket, :flow, flow)}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # The text of the input node labels its outgoing edges
  defp label_edges_from(flow, node_id, text) do
    label = if String.trim(text) == "", do: nil, else: text

    flow.edges
    |> Map.values()
    |> Enum.filter(&(&1.source == node_id))
    |> Enum.reduce(flow, fn edge, acc -> State.update_edge(acc, edge.id, label: label) end)
  end

  # ===== Initial graph =====

  defp build_flow do
    annotation = fn id, x, y, level, text, arrow ->
      Node.new(id, %{x: x, y: y}, %{level: level, text: text, arrow: arrow},
        type: :annotation,
        draggable: false,
        selectable: false,
        connectable: false,
        deletable: false
      )
    end

    nodes = [
      annotation.(
        "annotation-1",
        -100,
        -170,
        "1",
        "Built-in node types: input, default and output. Drag them and connect their handles.",
        :down_right
      ),
      annotation.(
        "annotation-2",
        420,
        -170,
        "2",
        "Custom nodes: a toolbar, a resizer, a circle and a text input.",
        :down_right
      ),
      annotation.(
        "annotation-3",
        -100,
        410,
        "3",
        "Edges: bezier, straight, step and smoothstep paths, animated, with labels, markers and colors.",
        nil
      ),
      annotation.(
        "annotation-4",
        420,
        410,
        "4",
        "Controls, minimap and the dotted background are flow options.",
        nil
      ),
      Node.new("input", %{x: 60, y: 0}, %{label: "Input node"},
        type: :input,
        handles: [Handle.source(:bottom), Handle.source(:right, id: "r")]
      ),
      Node.new("default", %{x: 60, y: 130}, %{label: "Default node"},
        handles: [Handle.target(:top), Handle.source(:bottom), Handle.source(:right, id: "r")]
      ),
      Node.new("output-a", %{x: -60, y: 290}, %{label: "Output A"},
        type: :output,
        handles: [Handle.target(:top)]
      ),
      Node.new("output-b", %{x: 180, y: 290}, %{label: "Output B"},
        type: :output,
        handles: [Handle.target(:top)]
      ),
      Node.new("toolbar", %{x: 440, y: 40}, %{emoji: "🚀"},
        type: :toolbar,
        handles: [Handle.target(:left), Handle.source(:right)]
      ),
      Node.new("resizer", %{x: 440, y: 210}, %{},
        type: :resizer,
        resizable: true,
        width: 210,
        height: 110,
        handles: [Handle.target(:left)]
      ),
      Node.new("circle", %{x: 790, y: 30}, %{},
        type: :circle,
        handles: [Handle.target(:left), Handle.source(:bottom)]
      ),
      Node.new("text", %{x: 760, y: 250}, %{text: "Type here"},
        type: :text_input,
        handles: [Handle.target(:top), Handle.source(:bottom)]
      ),
      Node.new("output-c", %{x: 805, y: 440}, %{label: "Output C"},
        type: :output,
        handles: [Handle.target(:top)]
      )
    ]

    pink = "#ff0072"
    violet = "#8b5cf6"

    edges = [
      Edge.new("e-input-default", "input", "default",
        source_handle: "source",
        animated: true,
        label: "animated"
      ),
      Edge.new("e-default-a", "default", "output-a",
        source_handle: "source",
        type: :smoothstep,
        label: "smoothstep",
        marker_end: %{type: :arrow_closed}
      ),
      Edge.new("e-default-b", "default", "output-b",
        source_handle: "source",
        type: :step,
        label: "step",
        style: %{"stroke" => pink, "stroke-width" => 2},
        label_style: %{"color" => pink, "border-color" => pink},
        marker_end: %{type: :arrow_closed, color: pink}
      ),
      Edge.new("e-input-toolbar", "input", "toolbar",
        source_handle: "r",
        type: :straight,
        label: "straight"
      ),
      Edge.new("e-default-resizer", "default", "resizer",
        source_handle: "r",
        type: :smoothstep,
        label: "styled",
        style: %{"stroke" => violet, "stroke-width" => 2, "stroke-dasharray" => "6 4"},
        label_style: %{"color" => violet, "border-color" => violet},
        marker_end: %{type: :arrow_closed, color: violet}
      ),
      Edge.new("e-toolbar-circle", "toolbar", "circle",
        label: "markers",
        marker_start: %{type: :circle},
        marker_end: %{type: :arrow_closed}
      ),
      Edge.new("e-circle-text", "circle", "text", label: "bezier"),
      Edge.new("e-text-output", "text", "output-c",
        type: :smoothstep,
        animated: true,
        label: "Type here",
        label_style: %{
          "background" => "#fef3c7",
          "border-color" => "#f59e0b",
          "color" => "#92400e",
          "font-weight" => "600"
        },
        marker_end: %{type: :arrow_closed}
      )
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

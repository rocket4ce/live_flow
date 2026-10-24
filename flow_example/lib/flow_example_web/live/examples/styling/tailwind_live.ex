defmodule FlowExampleWeb.Examples.Styling.TailwindLive do
  @moduledoc """
  Tailwind: style nodes and edges with Tailwind classes.

  No custom CSS at all: the node component is plain Tailwind, handles get
  their classes through `Handle.target(:top, class: ...)`, edges through
  `Edge.new(..., class: ...)` and the canvas through an arbitrary variant on a
  wrapper.

  LiveFlow's own rules are unlayered CSS, so utilities that replace one of
  their declarations use Tailwind's important modifier (`bg-teal-500!`).
  Utilities that only set `--lf-*` variables need no modifier.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}

  # Resets the node wrapper (.lf-node) so the component draws the whole card;
  # `group` lets the content react to the wrapper's data-selected attribute
  @node_class "group bg-transparent! border-0! shadow-none! [&>.lf-node-content]:p-0!"

  @handle_class "w-16! rounded-full! border-0! bg-teal-500! hover:bg-teal-600! dark:bg-teal-400!"

  @edge_class "[--lf-edge-stroke:var(--color-teal-500)] [--lf-edge-stroke-selected:var(--color-teal-700)] [--lf-edge-stroke-width:2]"

  @canvas_class [
    "absolute inset-0",
    "[&_.lf-container]:[--lf-background:var(--color-teal-50)]",
    "[&_.lf-container]:[--lf-background-dots-color:var(--color-teal-200)]",
    "[&_.lf-container]:[--lf-minimap-node-bg:var(--color-teal-200)]",
    "dark:[&_.lf-container]:[--lf-background:var(--color-stone-950)]",
    "dark:[&_.lf-container]:[--lf-background-dots-color:var(--color-stone-800)]",
    "dark:[&_.lf-container]:[--lf-minimap-node-bg:var(--color-teal-900)]"
  ]

  @people [
    {"Jane Doe", "CEO", "😎"},
    {"Tyler Weary", "Designer", "🤓"},
    {"Kristi Price", "Developer", "🤩"},
    {"Omar Haddad", "Product Manager", "🧐"},
    {"Mei Tanaka", "Engineer", "🥳"},
    {"Lucas Silva", "Data Scientist", "🤠"},
    {"Ada Byrne", "Researcher", "🤯"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, canvas_class: @canvas_class)
     |> assign(edge_opts: edge_opts())
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="add-person" icon="hero-user-plus" phx-click="add_person">
          Add person
        </.action>
      </:actions>

      <div id="tailwind-canvas" class={@canvas_class}>
        <.live_component
          module={LiveFlow.Components.Flow}
          id="tailwind-flow"
          flow={@flow}
          node_types={%{custom: &custom_node/1}}
          opts={
            %{
              background: :dots,
              background_gap: 18,
              controls: true,
              minimap: true,
              fit_view_on_init: true,
              fit_view_options: %{padding: 0.35},
              connection_line_type: :smoothstep
            }
          }
        />
      </div>

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            The node is a function component styled only with Tailwind utilities,
            including <code>dark:</code>
            variants and <code>group-data-[selected=true]:</code>
            for the selected state.
          </.hint>
          <.hint>
            Handles take classes with <code>Handle.target(:top, class: "w-16! bg-teal-500!")</code>, edges with <code>Edge.new(..., class: "[--lf-edge-stroke:var(--color-teal-500)]")</code>.
          </.hint>
          <.hint>
            LiveFlow's CSS is unlayered, so utilities replacing one of its
            declarations need the <code>!</code>
            modifier. Setting <code>--lf-*</code>
            variables never does.
          </.hint>
        </.option_group>

        <.option_group title="Classes used">
          <div class="space-y-2 font-mono text-[10.5px] leading-relaxed text-base-content/70">
            <div>
              <p class="pb-0.5 font-sans text-[11px] font-medium text-base-content/60">
                Node wrapper
              </p>
              <p class="rounded bg-base-200 px-2 py-1 break-all">{node_class()}</p>
            </div>
            <div>
              <p class="pb-0.5 font-sans text-[11px] font-medium text-base-content/60">Handles</p>
              <p class="rounded bg-base-200 px-2 py-1 break-all">{handle_class()}</p>
            </div>
            <div>
              <p class="pb-0.5 font-sans text-[11px] font-medium text-base-content/60">Edges</p>
              <p class="rounded bg-base-200 px-2 py-1 break-all">{edge_class()}</p>
            </div>
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

  defp custom_node(assigns) do
    ~H"""
    <div class={[
      "flex items-center rounded-md border-2 bg-white px-4 py-2 shadow-md transition-all duration-150",
      "border-stone-400 hover:shadow-lg",
      "group-data-[selected=true]:border-teal-500 group-data-[selected=true]:shadow-lg group-data-[selected=true]:shadow-teal-500/20",
      "dark:border-stone-600 dark:bg-stone-900 dark:group-data-[selected=true]:border-teal-400"
    ]}>
      <div class="flex size-12 shrink-0 items-center justify-center rounded-full bg-gray-100 text-2xl transition-transform duration-200 group-hover:scale-105 dark:bg-stone-800">
        {@node.data.emoji}
      </div>
      <div class="ml-2 pr-1">
        <div class="text-lg leading-tight font-bold whitespace-nowrap text-stone-900 dark:text-stone-100">
          {@node.data.name}
        </div>
        <div class="whitespace-nowrap text-gray-500 dark:text-stone-400">{@node.data.job}</div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("add_person", _params, socket) do
    flow = socket.assigns.flow
    index = map_size(flow.nodes)
    {name, job, emoji} = Enum.at(@people, rem(index, length(@people)))
    id = "person-#{System.unique_integer([:positive])}"

    # Below the lowest node, alternating left and right
    bottom =
      flow.nodes
      |> Map.values()
      |> Enum.map(& &1.position.y)
      |> Enum.max(fn -> 0 end)

    x = if rem(index, 2) == 0, do: 220, else: -220
    node = person(id, x, bottom + 150, name, job, emoji)
    edge = Edge.new("e-1-#{id}", "1", id, edge_opts())

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, flow |> State.add_node(node) |> State.add_edge(edge))
     |> FlowEvents.log("add_person", %{"id" => id, "name" => name})}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp node_class, do: @node_class
  defp handle_class, do: @handle_class
  defp edge_class, do: @edge_class

  # Used for the initial edges and the ones created by connecting handles
  defp edge_opts do
    [type: :smoothstep, class: @edge_class, marker_end: %{type: :arrow_closed, color: "#14b8a6"}]
  end

  defp person(id, x, y, name, job, emoji) do
    Node.new(id, %{x: x, y: y}, %{name: name, job: job, emoji: emoji},
      type: :custom,
      class: @node_class,
      handles: [
        Handle.target(:top, class: @handle_class),
        Handle.source(:bottom, class: @handle_class)
      ]
    )
  end

  defp build_flow do
    nodes =
      @people
      |> Enum.take(3)
      |> Enum.zip([{0, 0}, {-220, 170}, {220, 170}])
      |> Enum.with_index(1)
      |> Enum.map(fn {{{name, job, emoji}, {x, y}}, i} ->
        person(to_string(i), x, y, name, job, emoji)
      end)

    edges = [
      Edge.new("e1-2", "1", "2", edge_opts()),
      Edge.new("e1-3", "1", "3", edge_opts())
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

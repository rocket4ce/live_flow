defmodule FlowExampleWeb.Examples.Edges.EdgeToolbarLive do
  @moduledoc """
  Edge Toolbar: display content on top of the selected edge.

  `edge_toolbar={&toolbar/1}` renders a toolbar on the selected edge, in a
  `foreignObject` centered on the label point (it receives `@edge`, `@x` and
  `@y`). Its buttons are plain `phx-click` buttons handled by the LiveView,
  which updates the edge with `LiveFlow.State.update_edge/3`.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, State}

  # nil = the theme's edge color
  @colors [nil, "#ff0072", "#6366f1", "#10b981", "#f59e0b"]
  @types [:bezier, :smoothstep, :step, :straight]

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :selected, selected_edge(assigns.flow))

    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #edge-toolbar-flow .et-toolbar {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 100%;
        height: 100%;
      }
      #edge-toolbar-flow .et-toolbar > div {
        display: flex;
        gap: 2px;
        padding: 3px;
        border-radius: 10px;
        border: 1px solid var(--lf-node-border);
        background: var(--lf-node-bg);
        box-shadow: 0 4px 14px rgb(0 0 0 / 0.14);
        animation: et-in 140ms ease-out;
      }
      #edge-toolbar-flow .et-btn {
        display: grid;
        place-items: center;
        width: 24px;
        height: 24px;
        border-radius: 7px;
        color: var(--lf-controls-color);
        cursor: pointer;
        transition:
          background-color 150ms ease,
          color 150ms ease,
          transform 150ms ease;
      }
      #edge-toolbar-flow .et-btn:hover {
        background: var(--lf-controls-button-hover);
        color: var(--lf-text-primary);
      }
      #edge-toolbar-flow .et-btn:active {
        transform: scale(0.9);
      }
      #edge-toolbar-flow .et-btn.is-on {
        color: var(--lf-edge-stroke-animated);
      }
      #edge-toolbar-flow .et-btn.is-danger:hover {
        background: var(--lf-delete-hover-bg);
        color: var(--lf-delete-hover-color);
      }
      #edge-toolbar-flow .et-swatch {
        width: 12px;
        height: 12px;
        border-radius: 9999px;
        box-shadow: inset 0 0 0 1.5px rgb(0 0 0 / 0.12);
      }
      @keyframes et-in {
        from {
          opacity: 0;
          transform: scale(0.92);
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="edge-toolbar-flow"
        flow={@flow}
        node_types={FlowNodes.types()}
        edge_toolbar={&toolbar/1}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.15}
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Click an edge to select it: a toolbar appears on it. It's rendered by <code phx-no-curly-interpolation>edge_toolbar={&toolbar/1}</code>, a function component receiving <code>@edge</code>,
            <code>@x</code>
            and <code>@y</code>, placed in a 120×36 <code>foreignObject</code>
            on the label point.
          </.hint>
          <.hint>
            The buttons are <code>phx-click</code>
            buttons: the LiveView changes the edge with <code>State.update_edge/3</code>
            (color, <code>animated</code>, <code>type</code>) or removes it.
          </.hint>
        </.option_group>

        <.option_group title="Selected edge">
          <p :if={!@selected} id="selected-none" class="text-sm text-base-content/50">
            Select an edge to show its toolbar.
          </p>
          <dl
            :if={@selected}
            id="selected-edge"
            class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm"
          >
            <dt class="text-base-content/50">id</dt>
            <dd class="font-mono text-xs leading-5">{@selected.id}</dd>
            <dt class="text-base-content/50">type</dt>
            <dd id="selected-type" class="font-mono text-xs leading-5">{inspect(@selected.type)}</dd>
            <dt class="text-base-content/50">color</dt>
            <dd id="selected-color" class="flex items-center gap-1.5 font-mono text-xs leading-5">
              <span
                class="size-3 rounded-full border border-base-300"
                style={"background: #{color(@selected) || "#b1b1b7"}"}
              />
              {color(@selected) || "theme"}
            </dd>
            <dt class="text-base-content/50">animated</dt>
            <dd id="selected-animated" class="font-mono text-xs leading-5">
              {to_string(@selected.animated)}
            </dd>
          </dl>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :edge, :map, required: true
  attr :x, :any, required: true
  attr :y, :any, required: true

  defp toolbar(assigns) do
    assigns = assign(assigns, :next_color, next(@colors, color(assigns.edge)))

    ~H"""
    <div class="et-toolbar">
      <div id={"edge-toolbar-#{@edge.id}"} role="toolbar" aria-label="Edge actions">
        <button
          id={"edge-toolbar-#{@edge.id}-color"}
          type="button"
          class="et-btn"
          phx-click="cycle_color"
          phx-value-edge_id={@edge.id}
          title="Change color"
        >
          <span class="et-swatch" style={"background: #{@next_color || "var(--lf-edge-stroke)"}"} />
        </button>
        <button
          id={"edge-toolbar-#{@edge.id}-animate"}
          type="button"
          class={["et-btn", @edge.animated && "is-on"]}
          phx-click="toggle_animated"
          phx-value-edge_id={@edge.id}
          title={if(@edge.animated, do: "Stop animation", else: "Animate")}
        >
          <.icon
            name={if(@edge.animated, do: "hero-pause-micro", else: "hero-play-micro")}
            class="size-4"
          />
        </button>
        <button
          id={"edge-toolbar-#{@edge.id}-type"}
          type="button"
          class="et-btn"
          phx-click="cycle_type"
          phx-value-edge_id={@edge.id}
          title={"Change type (next: #{next(types(), @edge.type)})"}
        >
          <.icon name="hero-arrow-trending-up-micro" class="size-4" />
        </button>
        <button
          id={"edge-toolbar-#{@edge.id}-delete"}
          type="button"
          class="et-btn is-danger"
          phx-click="delete_edge"
          phx-value-edge_id={@edge.id}
          title="Delete edge"
        >
          <.icon name="hero-trash-micro" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("cycle_color", %{"edge_id" => id} = params, socket) do
    change_edge(socket, id, "cycle_color", params, fn edge ->
      color = next(@colors, color(edge))
      marker = edge.marker_end || %{type: :arrow}

      [
        style:
          if(color,
            do: Map.put(edge.style, :stroke, color),
            else: Map.delete(edge.style, :stroke)
          ),
        marker_end:
          if(color, do: Map.put(marker, :color, color), else: Map.delete(marker, :color))
      ]
    end)
  end

  def handle_event("toggle_animated", %{"edge_id" => id} = params, socket) do
    change_edge(socket, id, "toggle_animated", params, &[animated: !&1.animated])
  end

  def handle_event("cycle_type", %{"edge_id" => id} = params, socket) do
    change_edge(socket, id, "cycle_type", params, &[type: next(@types, &1.type)])
  end

  def handle_event("delete_edge", %{"edge_id" => id} = params, socket) do
    if State.get_edge(socket.assigns.flow, id) do
      {:noreply,
       socket
       |> FlowEvents.snapshot()
       |> assign(:flow, State.remove_edge(socket.assigns.flow, id))
       |> FlowEvents.log("delete_edge", params)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp change_edge(socket, id, event, params, fun) do
    case State.get_edge(socket.assigns.flow, id) do
      %Edge{} = edge ->
        {:noreply,
         socket
         |> FlowEvents.snapshot()
         |> assign(:flow, State.update_edge(socket.assigns.flow, id, fun.(edge)))
         |> FlowEvents.log(event, params)}

      nil ->
        {:noreply, socket}
    end
  end

  defp types, do: @types

  defp color(%Edge{style: style}), do: style[:stroke]

  # The element after `current` (wrapping around)
  defp next(list, current) do
    case Enum.find_index(list, &(&1 == current)) do
      nil -> hd(list)
      index -> Enum.at(list, rem(index + 1, length(list)))
    end
  end

  defp selected_edge(flow) do
    flow.edges
    |> Map.values()
    |> Enum.filter(& &1.selected)
    |> Enum.sort_by(& &1.id)
    |> List.first()
  end

  defp build_flow do
    [edge_type: :bezier]
    |> Samples.pipeline()
    |> State.select_edge("e-validate-route")
  end
end

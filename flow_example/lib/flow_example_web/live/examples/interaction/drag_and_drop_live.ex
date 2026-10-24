defmodule FlowExampleWeb.Examples.Interaction.DragAndDropLive do
  @moduledoc """
  Drag and Drop: drag nodes from a sidebar palette and drop them on the flow.

  Palette items are native `draggable` elements; a colocated hook puts
  `{"type": ...}` in the `application/liveflow` drag data. The LiveFlow hook
  accepts drops carrying that data type and pushes `lf:drop` with the data and
  the drop position in flow coordinates (snapped, since `snap_to_grid` is on).
  The node is created centered on that point.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, State}

  @grid 16
  # Half the size of a card node (224 x 58), rounded to the grid so dropped
  # nodes stay aligned
  @center_offset {112, 32}

  @palette [
    %{
      type: "trigger",
      title: "Trigger",
      subtitle: "Starts the flow",
      icon: "hero-bolt",
      color: :amber,
      inputs: false,
      outputs: true
    },
    %{
      type: "action",
      title: "Action",
      subtitle: "Does some work",
      icon: "hero-cog-6-tooth",
      color: :sky,
      inputs: true,
      outputs: true
    },
    %{
      type: "condition",
      title: "Condition",
      subtitle: "Branches on a rule",
      icon: "hero-arrows-right-left",
      color: :violet,
      inputs: true,
      outputs: true
    },
    %{
      type: "output",
      title: "Output",
      subtitle: "Ends the flow",
      icon: "hero-flag",
      color: :emerald,
      inputs: true,
      outputs: false
    }
  ]

  @accents %{
    amber: "bg-amber-500/15 text-amber-600",
    sky: "bg-sky-500/15 text-sky-600",
    violet: "bg-violet-500/15 text-violet-600",
    emerald: "bg-emerald-500/15 text-emerald-600"
  }

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, palette: @palette, counter: 1)
     |> assign(:grid, @grid)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #dnd-canvas::after {
        content: "";
        position: absolute;
        inset: 10px;
        border: 2px dashed color-mix(in oklab, var(--color-primary) 55%, transparent);
        border-radius: 14px;
        background: color-mix(in oklab, var(--color-primary) 4%, transparent);
        opacity: 0;
        pointer-events: none;
        transition: opacity 150ms ease;
      }
      #dnd-canvas[data-drop-active]::after {
        opacity: 1;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <div id="dnd-canvas" class="relative h-full w-full">
        <.live_component
          module={LiveFlow.Components.Flow}
          id="drag-and-drop"
          flow={@flow}
          node_types={FlowNodes.types()}
          opts={
            %{
              background: :dots,
              background_gap: @grid,
              controls: true,
              fit_view_on_init: true,
              fit_view_options: %{padding: 0.4, max_zoom: 1},
              snap_to_grid: true,
              snap_grid: {@grid, @grid},
              connection_line_type: :smoothstep
            }
          }
        />
      </div>

      <:sidebar>
        <.option_group title="Palette">
          <div id="dnd-palette" phx-hook=".DragPalette" class="grid gap-2">
            <div
              :for={item <- @palette}
              id={"palette-#{item.type}"}
              draggable="true"
              data-type={item.type}
              class="group flex cursor-grab items-center gap-3 rounded-lg border border-base-300 bg-base-100 p-2.5 shadow-xs transition-all duration-150 select-none hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-md active:cursor-grabbing data-dragging:scale-[0.98] data-dragging:opacity-50"
            >
              <span class={[
                "grid size-8 shrink-0 place-items-center rounded-lg",
                Map.fetch!(accents(), item.color)
              ]}>
                <.icon name={item.icon} class="size-4" />
              </span>
              <div class="min-w-0 flex-1">
                <p class="text-[13px] leading-tight font-semibold">{item.title}</p>
                <p class="truncate text-[11px] text-base-content/55">{item.subtitle}</p>
              </div>
              <.icon
                name="hero-bars-3-mini"
                class="size-4 text-base-content/30 transition-colors group-hover:text-base-content/60"
              />
            </div>
          </div>
          <script :type={Phoenix.LiveView.ColocatedHook} name=".DragPalette">
            // Native HTML5 drag & drop: the LiveFlow hook only accepts drops
            // carrying "application/liveflow" data and pushes lf:drop.
            export default {
              mounted() {
                this.canvas = document.getElementById("dnd-canvas")

                this.el.addEventListener("dragstart", event => {
                  const item = event.target.closest("[data-type]")
                  if (!item) return
                  event.dataTransfer.setData("application/liveflow", JSON.stringify({type: item.dataset.type}))
                  event.dataTransfer.effectAllowed = "move"
                  item.dataset.dragging = ""
                  if (this.canvas) this.canvas.dataset.dropActive = ""
                })

                this.el.addEventListener("dragend", event => {
                  const item = event.target.closest("[data-type]")
                  if (item) delete item.dataset.dragging
                  if (this.canvas) delete this.canvas.dataset.dropActive
                })
              }
            }
          </script>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            Palette items are <code>draggable="true"</code>. A colocated hook sets
            <code>dataTransfer.setData("application/liveflow", ...)</code>
            with the node type.
          </.hint>
          <.hint>
            Dropping on the flow pushes <code>lf:drop</code>
            with that <code>data</code>
            and the drop <code>position</code>
            in flow coordinates, snapped to the {@grid}px grid (<code>snap_to_grid: true</code>). The
            server centers the new node on it.
          </.hint>
          <.hint>
            Unknown types are ignored: the payload comes from the browser, so it's never turned into an atom.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  defp accents, do: @accents

  # ===== Events =====

  @impl true
  def handle_event(
        "lf:drop",
        %{"data" => %{"type" => type}, "position" => position} = params,
        socket
      )
      when is_binary(type) do
    case {Enum.find(@palette, &(&1.type == type)), position} do
      {%{} = item, %{"x" => x, "y" => y}} when is_number(x) and is_number(y) ->
        n = socket.assigns.counter
        {dx, dy} = @center_offset

        node =
          Samples.card(
            "#{type}-#{n}",
            x - dx,
            y - dy,
            item.title,
            item.subtitle,
            item.icon,
            item.color,
            inputs: item.inputs,
            outputs: item.outputs
          )

        socket
        |> FlowEvents.snapshot()
        |> assign(flow: State.add_node(socket.assigns.flow, node), counter: n + 1)
        |> FlowEvents.log("lf:drop", params)
        |> noreply()

      _invalid ->
        socket |> FlowEvents.log("lf:drop", Map.put(params, "ignored", true)) |> noreply()
    end
  end

  def handle_event("lf:drop", params, socket) do
    socket |> FlowEvents.log("lf:drop", Map.put(params, "ignored", true)) |> noreply()
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp noreply(socket), do: {:noreply, socket}

  # ===== Initial graph =====

  defp build_flow do
    trigger = Enum.find(@palette, &(&1.type == "trigger"))
    action = Enum.find(@palette, &(&1.type == "action"))

    nodes = [
      Samples.card("start", 0, 0, "Webhook", "POST /signup", trigger.icon, trigger.color,
        inputs: false
      ),
      Samples.card("welcome", 320, 0, "Send email", "Welcome sequence", action.icon, action.color)
    ]

    edges = [Edge.new("e-start-welcome", "start", "welcome", type: :smoothstep, animated: true)]

    State.new(nodes: nodes, edges: edges)
  end
end

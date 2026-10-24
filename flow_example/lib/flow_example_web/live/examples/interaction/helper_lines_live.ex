defmodule FlowExampleWeb.Examples.Interaction.HelperLinesLive do
  @moduledoc """
  Helper Lines: guide lines that help to align nodes, with automatic snapping.

  `helper_lines: true` makes the hook compare the edges and centers of the
  dragged nodes with every other node while dragging: when they are within
  5px a dashed guide is drawn and the node snaps onto it. Everything happens
  in the browser; the server only receives the final, aligned position in
  `lf:node_change`. `snap_to_grid` applies on the axes without a guide.

  The hook reads `helper_lines` when it mounts, so toggling the option gives
  the flow a new DOM id (a fresh hook) instead of only updating `opts`.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Node, State}

  @defaults %{"helper_lines" => "true", "snap_to_grid" => "false", "grid" => "20"}
  @grids [{"10 px", "10"}, {"20 px", "20"}, {"40 px", "40"}]
  @colors ~w(#6366f1 #0ea5e9 #10b981 #f59e0b #ef4444 #ec4899 #8b5cf6 #14b8a6)

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, grids: @grids)
     |> assign(remounted: false, next_id: 1)
     |> assign_params(@defaults)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #helper-lines-canvas .lf-container {
        --lf-helper-line-color: #f43f5e;
      }
      #helper-lines-canvas .lf-helper-line {
        stroke-width: 1.5;
        opacity: 1;
      }
      #helper-lines-canvas .lf-node[data-node-type="box"] {
        border-radius: 10px;
        box-shadow: inset 0 3px 0 var(--box-color), var(--lf-node-shadow);
      }
      #helper-lines-canvas .lf-node[data-node-type="box"].lf-node-selected {
        box-shadow: inset 0 3px 0 var(--box-color), var(--lf-node-selected-shadow);
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="add-box" icon="hero-plus" variant={:primary} phx-click="add_box">
          Add node
        </.action>
        <.action id="reset-boxes" icon="hero-arrow-path" phx-click="reset">Reset</.action>
      </:actions>

      <div id="helper-lines-canvas" class="h-full w-full">
        <.live_component
          module={LiveFlow.Components.Flow}
          id={flow_id(@params)}
          flow={@flow}
          node_types={%{box: &box_node/1}}
          opts={
            %{
              background: if(@params["snap_to_grid"] == "true", do: :lines, else: :dots),
              background_gap: grid(@params),
              controls: true,
              minimap: true,
              fit_view_on_init: not @remounted,
              fit_view_options: %{padding: 0.2},
              nodes_connectable: false,
              helper_lines: @params["helper_lines"] == "true",
              snap_to_grid: @params["snap_to_grid"] == "true",
              snap_grid: {grid(@params), grid(@params)}
            }
          }
        />
      </div>

      <:sidebar>
        <.option_group title="Options">
          <.form for={@form} id="helper-lines-options" phx-change="options">
            <.input
              field={@form[:helper_lines]}
              type="checkbox"
              label="Helper lines"
              class={switch_class()}
            />
            <.input
              field={@form[:snap_to_grid]}
              type="checkbox"
              label="Snap to grid"
              class={switch_class()}
            />
            <.input
              :if={@params["snap_to_grid"] == "true"}
              field={@form[:grid]}
              type="select"
              label="Grid size"
              class={select_class()}
              options={@grids}
            />
          </.form>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            Drag a node close to the edge or the center of another one: a guide appears and the node
            snaps onto it (5px threshold). Left, right, top, bottom and both centers are compared,
            so nodes of different sizes still line up.
          </.hint>
          <.hint>
            The lines live in the browser only; the server receives the aligned position in <code>lf:node_change</code>. With
            <code>snap_to_grid</code>
            on as well, guides win on their axis and the grid applies to the other one.
          </.hint>
          <.hint>
            Selected groups align as a whole: shift-click several nodes and drag them together.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp box_node(assigns) do
    ~H"""
    <div class="flex h-full flex-col justify-between gap-1">
      <span
        class="flex items-center gap-1.5 text-[13px] font-semibold"
        style="color: var(--lf-text-primary)"
      >
        <span class="size-2 rounded-full" style={"background: #{@node.data.color}"}></span>
        {@node.data.label}
      </span>
      <span class="font-mono text-[10px]" style="color: var(--lf-text-secondary)">
        {@node.data.w} × {@node.data.h}
      </span>
    </div>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("options", %{"helper" => params}, socket) do
    params = Map.merge(socket.assigns.params, params)
    remount? = params["helper_lines"] != socket.assigns.params["helper_lines"]

    {:noreply,
     socket
     |> assign(:remounted, socket.assigns.remounted or remount?)
     |> assign_params(params)
     |> FlowEvents.log("options", Map.take(params, ["helper_lines", "snap_to_grid", "grid"]))}
  end

  def handle_event("add_box", _params, socket) do
    id = socket.assigns.next_id
    {w, h} = Enum.random([{120, 60}, {180, 80}, {90, 90}, {240, 56}, {140, 120}])
    flow = socket.assigns.flow

    {x, y} =
      case State.bounds(flow) do
        nil ->
          {0, 0}

        bounds ->
          {bounds.x + :rand.uniform(max(round(bounds.width), 1)), bounds.y + bounds.height + 40}
      end

    node = box("new-#{id}", "Node #{id}", x, y, w, h, Enum.at(@colors, rem(id, length(@colors))))

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(flow: State.add_node(flow, node), next_id: id + 1)
     |> FlowEvents.log("add_box", %{"id" => node.id, "size" => "#{w}×#{h}"})}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, build_flow())
     |> FlowEvents.log("reset", %{})}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Helpers =====

  # The hook only creates its helper line manager on mount: a new DOM id
  # remounts it when the option changes
  defp flow_id(%{"helper_lines" => "true"}), do: "helper-lines-flow"
  defp flow_id(_params), do: "helper-lines-flow-off"

  defp grid(params), do: String.to_integer(params["grid"])

  defp assign_params(socket, params) do
    assign(socket, params: params, form: to_form(params, as: :helper))
  end

  defp box(id, label, x, y, w, h, color) do
    Node.new(id, %{x: x, y: y}, %{label: label, w: w, h: h, color: color},
      type: :box,
      style: %{width: "#{w}px", height: "#{h}px", "--box-color": color}
    )
  end

  defp build_flow do
    nodes = [
      box("wide", "Wide", 0, 0, 260, 64, "#6366f1"),
      box("tall", "Tall", 330, 36, 110, 200, "#0ea5e9"),
      box("square", "Square", 520, 8, 130, 130, "#10b981"),
      box("small", "Small", 48, 150, 96, 54, "#f59e0b"),
      box("banner", "Banner", 170, 300, 320, 60, "#ef4444"),
      box("card", "Card", 560, 230, 170, 96, "#ec4899"),
      box("chip", "Chip", 20, 280, 110, 44, "#8b5cf6")
    ]

    State.new(nodes: nodes)
  end
end

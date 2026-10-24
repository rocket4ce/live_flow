defmodule FlowExampleWeb.Examples.Edges.EditableEdgeLive do
  @moduledoc """
  Editable Edge: edges whose path goes through user editable control points.

  A custom edge type (`edge_types: %{editable: &editable_edge/1}`) draws the
  path through `edge.data.points` (flow coordinates), as straight segments or
  a Catmull-Rom curve. A colocated hook listens (event delegation) on the flow
  container: it drags the control points with `liveflow.screenToFlowPosition`,
  redraws the path locally and pushes the final point to the server on
  release. Double-clicking a point removes it, the "+" buttons insert one.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, State}
  alias LiveFlow.Changes.NodeChange

  @algorithms ~w(linear catmull_rom)

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)
    params = %{"algorithm" => "catmull_rom"}

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> FlowEvents.assign_flow(build_flow("catmull_rom"))
     |> assign(:form, to_form(params, as: :editable))
     |> assign(:edge_opts, edge_opts("catmull_rom"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #editable-edge-flow .editable-controls {
        opacity: 0;
        transition: opacity 0.15s ease;
      }
      #editable-edge-flow .editable-edge:hover .editable-controls,
      #editable-edge-flow .editable-edge.is-selected .editable-controls,
      #editable-edge-flow .editable-edge.is-editing .editable-controls {
        opacity: 1;
      }
      #editable-edge-flow .editable-edge.is-editing .lf-edge {
        stroke: var(--lf-edge-stroke-selected);
      }
      #editable-edge-flow .editable-point {
        fill: var(--lf-node-bg);
        stroke: var(--lf-edge-stroke-selected);
        stroke-width: 2;
        cursor: grab;
        pointer-events: all;
        touch-action: none;
        transition: stroke-width 0.15s ease, fill 0.15s ease;
      }
      #editable-edge-flow .editable-point:hover {
        fill: var(--lf-edge-stroke-selected);
        stroke-width: 4;
      }
      #editable-edge-flow .editable-edge.is-editing .editable-point {
        cursor: grabbing;
      }
      #editable-edge-flow .editable-insert {
        cursor: copy;
        pointer-events: all;
        touch-action: none;
      }
      #editable-edge-flow .editable-insert circle {
        fill: var(--lf-node-bg);
        stroke: var(--lf-edge-stroke);
        stroke-width: 1.5;
        transition: fill 0.15s ease, stroke 0.15s ease;
      }
      #editable-edge-flow .editable-insert path {
        fill: none;
        stroke: var(--lf-text-secondary);
        stroke-width: 1.5;
        stroke-linecap: round;
      }
      #editable-edge-flow .editable-insert:hover circle {
        fill: var(--lf-edge-stroke-selected);
        stroke: var(--lf-edge-stroke-selected);
      }
      #editable-edge-flow .editable-insert:hover path {
        stroke: white;
      }
      #editable-edge-flow .editable-edge.is-editing .editable-insert {
        display: none;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="reset-points" icon="hero-arrow-path" phx-click="reset">Reset</.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="editable-edge-flow"
        flow={@flow}
        node_types={FlowNodes.types()}
        edge_types={%{editable: &editable_edge/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.2},
            connection_line_type: :straight
          }
        }
      />
      <%!-- Behaviour only: listens on the flow container (event delegation) --%>
      <div
        id="editable-edge-controller"
        phx-hook=".EditableEdge"
        data-flow-id="editable-edge-flow"
        hidden
      >
      </div>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".EditableEdge">
        const SVG_NS = "http://www.w3.org/2000/svg"

        // Mirrors svg_path/2 in the LiveView: straight segments or a uniform
        // Catmull-Rom spline converted to cubic Bezier segments
        function buildPath(points, algorithm) {
          if (points.length < 2) return ""
          let d = `M ${points[0][0]} ${points[0][1]}`
          for (let i = 0; i < points.length - 1; i++) {
            const p1 = points[i]
            const p2 = points[i + 1]
            if (algorithm === "catmull_rom") {
              const p0 = points[i - 1] || p1
              const p3 = points[i + 2] || p2
              const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6]
              const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6]
              d += ` C ${c1[0]} ${c1[1]} ${c2[0]} ${c2[1]} ${p2[0]} ${p2[1]}`
            } else {
              d += ` L ${p2[0]} ${p2[1]}`
            }
          }
          return d
        }

        export default {
          // Event delegation on the canvas (the parent of the flow and of this
          // element), capture phase: runs before the flow's own handlers
          mounted() {
            this.root = this.el.parentElement
            this.drag = null
            this.onPointerDown = e => this.pointerDown(e)
            this.onPointerMove = e => this.pointerMove(e)
            this.onPointerUp = e => this.pointerUp(e)
            this.onDblClick = e => this.dblClick(e)
            this.root.addEventListener("pointerdown", this.onPointerDown, true)
            this.root.addEventListener("dblclick", this.onDblClick, true)
          },

          destroyed() {
            this.root.removeEventListener("pointerdown", this.onPointerDown, true)
            this.root.removeEventListener("dblclick", this.onDblClick, true)
            this.stopTracking()
          },

          pointerDown(e) {
            const point = e.target.closest(".editable-point")
            const insert = e.target.closest(".editable-insert")
            if ((!point && !insert) || e.button !== 0) return
            this.flow = document.getElementById(this.el.dataset.flowId)
            if (!this.flow?.liveflow) return
            // Keeps the flow from panning / selecting (no compatibility mousedown)
            e.preventDefault()
            e.stopPropagation()

            const g = (point || insert).closest("g.editable-edge")
            const points = JSON.parse(g.dataset.points)
            let index
            let marker

            if (point) {
              index = Number(point.dataset.index) + 1
              marker = point
            } else {
              const segment = Number(insert.dataset.index)
              index = segment + 1
              points.splice(index, 0, [Number(insert.dataset.x), Number(insert.dataset.y)])
              // Temporary point, replaced by the server render
              marker = document.createElementNS(SVG_NS, "circle")
              marker.setAttribute("class", "editable-point")
              marker.setAttribute("r", "6")
              g.querySelector(".editable-controls").appendChild(marker)
            }

            this.drag = {
              g,
              points,
              index,
              marker,
              inserting: !point,
              edgeId: g.dataset.edgeId,
              algorithm: g.dataset.algorithm,
              startX: e.clientX,
              startY: e.clientY,
              moved: false,
            }
            g.classList.add("is-editing")
            this.redraw()
            window.addEventListener("pointermove", this.onPointerMove)
            window.addEventListener("pointerup", this.onPointerUp)
            window.addEventListener("pointercancel", this.onPointerUp)
          },

          pointerMove(e) {
            const drag = this.drag
            if (!drag) return
            if (!drag.moved && Math.hypot(e.clientX - drag.startX, e.clientY - drag.startY) < 3) return
            drag.moved = true
            const { x, y } = this.flow.liveflow.screenToFlowPosition({ x: e.clientX, y: e.clientY })
            drag.points[drag.index] = [Math.round(x), Math.round(y)]
            this.redraw()
          },

          pointerUp(_e) {
            const drag = this.drag
            this.stopTracking()
            if (!drag) return
            drag.g.classList.remove("is-editing")
            const [x, y] = drag.points[drag.index]
            const payload = { edge_id: drag.edgeId, index: drag.index - 1, x, y }

            if (drag.inserting) {
              this.pushEvent("insert_point", payload)
            } else if (drag.moved) {
              this.pushEvent("move_point", payload)
            }
          },

          dblClick(e) {
            const point = e.target.closest(".editable-point")
            if (!point || point.dataset.index === undefined) return
            e.preventDefault()
            e.stopPropagation()
            const g = point.closest("g.editable-edge")
            this.pushEvent("remove_point", { edge_id: g.dataset.edgeId, index: Number(point.dataset.index) })
          },

          redraw() {
            const { g, points, index, marker, algorithm } = this.drag
            const d = buildPath(points, algorithm)
            g.querySelectorAll(":scope > path").forEach(path => path.setAttribute("d", d))
            marker.setAttribute("cx", points[index][0])
            marker.setAttribute("cy", points[index][1])
          },

          stopTracking() {
            this.drag = null
            window.removeEventListener("pointermove", this.onPointerMove)
            window.removeEventListener("pointerup", this.onPointerUp)
            window.removeEventListener("pointercancel", this.onPointerUp)
          },
        }
      </script>

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Hover or select an edge to show its control points. Drag a point to reshape the edge,
            click or drag a <b>+</b>
            to insert a point in the middle of a segment, double-click a point to remove it.
          </.hint>
          <.hint>
            The points live in <code>edge.data.points</code>
            (flow coordinates) and a custom edge renderer draws the path through them. A colocated
            hook converts the pointer with <code>liveflow.screenToFlowPosition/1</code>, redraws the
            path locally while dragging and pushes <code>move_point</code>
            / <code>insert_point</code>
            / <code>remove_point</code>
            to the LiveView.
          </.hint>
          <.hint>
            Dragging a node applies the <code>lf:drag_move</code>
            positions on the server, so the edges follow the nodes. Edits are undoable with <.kbd>Ctrl</.kbd>/<.kbd>
              ⌘
            </.kbd>
            + <.kbd>Z</.kbd>.
          </.hint>
        </.option_group>

        <.form for={@form} id="editable-form" phx-change="set_algorithm">
          <.option_group title="Path algorithm">
            <.input
              field={@form[:algorithm]}
              type="select"
              class={select_class()}
              options={[{"Linear", "linear"}, {"Catmull-Rom", "catmull_rom"}]}
            />
          </.option_group>
        </.form>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  defp editable_edge(%{source_pos: nil} = assigns) do
    ~H"""
    <g data-edge-id={@edge.id}></g>
    """
  end

  defp editable_edge(assigns) do
    edge = assigns.edge
    algorithm = Map.get(edge.data, :algorithm, "catmull_rom")
    controls = Map.get(edge.data, :points, [])

    points =
      [point(assigns.source_pos)] ++ Enum.map(controls, &point/1) ++ [point(assigns.target_pos)]

    assigns =
      assign(assigns,
        d: svg_path(points, algorithm),
        algorithm: algorithm,
        points_json: Jason.encode!(points),
        controls: controls |> Enum.map(&point/1) |> Enum.with_index(),
        inserts: points |> midpoints(algorithm) |> Enum.with_index()
      )

    ~H"""
    <g
      class={["editable-edge", @edge.selected && "is-selected"]}
      data-edge-id={@edge.id}
      data-points={@points_json}
      data-algorithm={@algorithm}
    >
      <path class="lf-edge-interaction" d={@d} data-edge-id={@edge.id} />
      <path
        class="lf-edge"
        d={@d}
        data-edge-id={@edge.id}
        data-selected={to_string(@edge.selected)}
        marker-end={@marker_end_id}
      />
      <g class="editable-controls">
        <g
          :for={{[x, y], i} <- @inserts}
          class="editable-insert nopan nodrag"
          data-edge-id={@edge.id}
          data-index={i}
          data-x={x}
          data-y={y}
          transform={"translate(#{x} #{y})"}
        >
          <circle r="7" />
          <path d="M -3 0 H 3 M 0 -3 V 3" />
        </g>
        <circle
          :for={{[x, y], i} <- @controls}
          class="editable-point nopan nodrag"
          data-edge-id={@edge.id}
          data-index={i}
          cx={x}
          cy={y}
          r="6"
        />
      </g>
    </g>
    """
  end

  @impl true
  def handle_event("move_point", %{"edge_id" => id, "index" => index} = params, socket) do
    edit_points(socket, id, "move_point", params, fn points ->
      List.replace_at(points, to_int(index), new_point(params))
    end)
  end

  def handle_event("insert_point", %{"edge_id" => id, "index" => index} = params, socket) do
    edit_points(socket, id, "insert_point", params, fn points ->
      List.insert_at(points, to_int(index), new_point(params))
    end)
  end

  def handle_event("remove_point", %{"edge_id" => id, "index" => index} = params, socket) do
    edit_points(socket, id, "remove_point", params, &List.delete_at(&1, to_int(index)))
  end

  def handle_event("set_algorithm", %{"editable" => %{"algorithm" => algorithm} = params}, socket)
      when algorithm in @algorithms do
    flow = socket.assigns.flow

    edges =
      Map.new(flow.edges, fn {id, edge} ->
        {id, %{edge | data: Map.put(edge.data, :algorithm, algorithm)}}
      end)

    {:noreply,
     socket
     |> assign(:flow, %{flow | edges: edges})
     |> assign(:edge_opts, edge_opts(algorithm))
     |> assign(:form, to_form(params, as: :editable))}
  end

  def handle_event("reset", _params, socket) do
    algorithm = socket.assigns.form[:algorithm].value

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, build_flow(algorithm))}
  end

  # Custom edges are drawn on the server: follow the dragged nodes live
  def handle_event("lf:drag_move", %{"changes" => changes}, socket) do
    {:noreply, update(socket, :flow, &NodeChange.apply_changes(&1, changes))}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp edit_points(socket, id, event, params, fun) do
    case State.get_edge(socket.assigns.flow, id) do
      %Edge{data: data} ->
        points = fun.(Map.get(data, :points, []))

        {:noreply,
         socket
         |> FlowEvents.snapshot()
         |> update(:flow, &State.update_edge(&1, id, data: Map.put(data, :points, points)))
         |> FlowEvents.log(event, params)}

      nil ->
        {:noreply, socket}
    end
  end

  defp svg_path([first | _] = points, algorithm) do
    segments =
      points
      |> segments(algorithm)
      |> Enum.map(fn
        {:line, [x, y]} ->
          "L #{fmt(x)} #{fmt(y)}"

        {:curve, [c1x, c1y], [c2x, c2y], [x, y]} ->
          "C #{fmt(c1x)} #{fmt(c1y)} #{fmt(c2x)} #{fmt(c2y)} #{fmt(x)} #{fmt(y)}"
      end)

    Enum.join(["M #{fmt(Enum.at(first, 0))} #{fmt(Enum.at(first, 1))}" | segments], " ")
  end

  # Segment i goes from points[i] to points[i + 1]
  defp segments(points, "catmull_rom") do
    count = length(points)

    for i <- 0..(count - 2)//1 do
      [p1x, p1y] = p1 = Enum.at(points, i)
      [p2x, p2y] = p2 = Enum.at(points, i + 1)
      [p0x, p0y] = if i > 0, do: Enum.at(points, i - 1), else: p1
      [p3x, p3y] = if i + 2 < count, do: Enum.at(points, i + 2), else: p2

      {:curve, [p1x + (p2x - p0x) / 6, p1y + (p2y - p0y) / 6],
       [p2x - (p3x - p1x) / 6, p2y - (p3y - p1y) / 6], p2}
    end
  end

  defp segments(points, _linear), do: points |> tl() |> Enum.map(&{:line, &1})

  # Point in the middle of every segment (t = 0.5 on curves), for the "+" buttons
  defp midpoints(points, algorithm) do
    points
    |> segments(algorithm)
    |> Enum.zip(points)
    |> Enum.map(fn
      {{:line, [x2, y2]}, [x1, y1]} ->
        [round((x1 + x2) / 2), round((y1 + y2) / 2)]

      {{:curve, [c1x, c1y], [c2x, c2y], [x2, y2]}, [x1, y1]} ->
        [round((x1 + 3 * c1x + 3 * c2x + x2) / 8), round((y1 + 3 * c1y + 3 * c2y + y2) / 8)]
    end)
  end

  defp point(%{x: x, y: y}), do: [x, y]

  defp new_point(%{"x" => x, "y" => y}), do: %{x: x, y: y}

  defp to_int(value) when is_integer(value), do: value
  defp to_int(value) when is_binary(value), do: String.to_integer(value)

  defp fmt(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp fmt(value), do: to_string(value)

  defp edge_opts(algorithm) do
    [
      type: :editable,
      marker_end: %{type: :arrow_closed},
      data: %{points: [], algorithm: algorithm}
    ]
  end

  defp build_flow(algorithm) do
    nodes = [
      Samples.card("input", 0, 160, "Input", "raw events", "hero-arrow-down-tray", :amber,
        inputs: false
      ),
      Samples.card(
        "transform",
        420,
        0,
        "Transform",
        "map & filter",
        "hero-adjustments-horizontal",
        :violet
      ),
      Samples.card("output", 840, 160, "Output", "warehouse", "hero-circle-stack", :emerald,
        outputs: false
      )
    ]

    edge = fn id, source, target, points ->
      Edge.new(
        id,
        source,
        target,
        Keyword.put(edge_opts(algorithm), :data, %{points: points, algorithm: algorithm})
      )
    end

    edges = [
      edge.("input-transform", "input", "transform", [%{x: 320, y: 190}, %{x: 340, y: 30}]),
      edge.("transform-output", "transform", "output", [%{x: 760, y: -40}, %{x: 740, y: 190}]),
      edge.("input-output", "input", "output", [
        %{x: 300, y: 340},
        %{x: 520, y: 260},
        %{x: 740, y: 340}
      ])
    ]

    [nodes: nodes, edges: edges]
    |> State.new()
    |> State.select_edge("input-output")
  end
end

defmodule FlowExampleWeb.Examples.Nodes.RotatableNodeLive do
  @moduledoc """
  Rotatable Node: a custom node rotated with a CSS transform.

  The node renders a card with a rotation knob (`nodrag nopan`). A colocated
  hook tracks the pointer on `window` while the knob is dragged, computes the
  angle between the node center and the pointer and rotates the card locally.
  On release it pushes `rotate_node`, stored in the node data, so the server
  renders the same transform. Nodes are also resizable with `NodeResizer`.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}
  alias LiveFlow.Components.NodeResizer

  @snap_step 15

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, snap: false)
     |> assign(:snap_step, @snap_step)
     |> assign(:snap_form, snap_form(false))
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      /* The .lf-node box stays axis-aligned (edges and handles use it); the
         card inside of it is what rotates */
      #rotatable-node .lf-node[data-node-type="rotatable"],
      #rotatable-node .lf-node[data-node-type="rotatable"]:hover {
        background: transparent;
        border-color: transparent;
        box-shadow: none;
      }

      #rotatable-node .lf-node[data-node-type="rotatable"] .lf-node-content {
        height: 100%;
        min-width: 0;
        padding: 0;
      }

      #rotatable-node .rot-card {
        background: var(--lf-node-bg);
        border: 1px solid var(--lf-node-border);
        box-shadow: var(--lf-node-shadow);
        transition: border-color 150ms ease, box-shadow 150ms ease;
      }

      #rotatable-node .rot-card:not([data-rotating]) {
        transition: transform 180ms ease-out, border-color 150ms ease, box-shadow 150ms ease;
      }

      #rotatable-node .lf-node[data-selected="true"] .rot-card {
        border-color: var(--lf-node-selected-border);
        box-shadow: var(--lf-node-shadow), var(--lf-node-selected-shadow);
      }

      #rotatable-node .rot-handle {
        opacity: 0;
        pointer-events: none;
      }

      #rotatable-node .rot-knob {
        background: var(--lf-node-bg);
        border: 2px solid var(--lf-node-selected-border);
        cursor: grab;
        transition: scale 150ms ease, background-color 150ms ease;
      }

      /* Tailwind's -translate-x-1/2 uses the `translate` property: scale with `scale` */
      #rotatable-node .rot-knob:hover,
      #rotatable-node .rot-card[data-rotating] .rot-knob {
        background: var(--lf-node-selected-border);
        scale: 1.3;
      }

      #rotatable-node .rot-card[data-rotating] .rot-knob {
        cursor: grabbing;
      }

      #rotatable-node .rot-stem {
        background: var(--lf-node-selected-border);
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="reset-rotation" icon="hero-arrow-uturn-left" phx-click="reset_rotation">
          Reset rotation
        </.action>
      </:actions>

      <div
        id="rotatable-canvas"
        class="absolute inset-0"
        data-rotation-snap={if(@snap, do: @snap_step, else: 0)}
      >
        <.live_component
          module={LiveFlow.Components.Flow}
          id="rotatable-node"
          flow={@flow}
          node_types={%{rotatable: &rotatable_node/1}}
          opts={
            %{
              background: :dots,
              controls: true,
              fit_view_on_init: true,
              fit_view_options: %{padding: 0.35}
            }
          }
        />
      </div>

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Drag the round knob above a node to rotate it. The knob has the <code>nodrag nopan</code>
            classes, so it neither moves the node nor pans the canvas.
          </.hint>
          <.hint>
            A colocated hook follows the pointer on <code>window</code>, computes the angle between
            the node center and the pointer with <code>Math.atan2</code>
            and sets <code>transform: rotate()</code>
            on the card. On release it pushes <code>rotate_node</code>; the angle is stored in the
            node data and survives undo/redo.
          </.hint>
          <.hint>
            Select a resizable node to resize it with <code>NodeResizer</code>. The node box stays
            axis-aligned: edges attach to it while the card rotates inside.
          </.hint>
        </.option_group>

        <.option_group title="Options">
          <.form for={@snap_form} id="rotation-options" phx-change="set_snap">
            <.input
              field={@snap_form[:snap]}
              type="checkbox"
              label={"Snap rotation to #{@snap_step}°"}
              class={switch_class()}
            />
          </.form>
        </.option_group>

        <.option_group title="Nodes">
          <dl id="rotation-list" class="space-y-2 text-xs">
            <div
              :for={node <- Enum.sort_by(Map.values(@flow.nodes), & &1.id)}
              id={"rotation-row-#{node.id}"}
              class="flex items-center justify-between gap-2"
            >
              <dt class="truncate text-base-content/70">{node.data.label}</dt>
              <dd class="flex shrink-0 items-center gap-2 font-mono text-base-content/50">
                <span>{round(node.width || 0)} × {round(node.height || 0)}</span>
                <span class="rounded bg-base-200 px-1.5 text-base-content/80">
                  {node.data.rotation}°
                </span>
              </dd>
            </div>
          </dl>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".RotateNode">
      // Rotates the card while its knob is dragged and pushes the final angle.
      // The server renders the same transform from the node data; until it
      // confirms, the local angle is re-applied after every patch.
      export default {
        mounted() {
          this.rotation = null
          this.dragging = false

          this.onPointerDown = event => {
            if (event.button !== 0 || !event.target.closest("[data-rotate-handle]")) return
            event.preventDefault()
            this.dragging = true
            this.el.dataset.rotating = ""
            window.addEventListener("pointermove", this.onPointerMove)
            window.addEventListener("pointerup", this.onPointerUp)
            window.addEventListener("pointercancel", this.onPointerUp)
          }

          this.onPointerMove = event => {
            // The .lf-node box isn't rotated: its center is the rotation center
            const box = (this.el.closest(".lf-node") || this.el).getBoundingClientRect()
            const cx = box.left + box.width / 2
            const cy = box.top + box.height / 2
            // 0° = knob straight above the center
            let angle = Math.atan2(event.clientY - cy, event.clientX - cx) * 180 / Math.PI + 90
            const snap = Number(this.el.closest("[data-rotation-snap]")?.dataset.rotationSnap) || 0
            angle = snap > 0 ? Math.round(angle / snap) * snap : Math.round(angle)
            this.rotation = ((angle % 360) + 360) % 360
            this.apply()
          }

          this.onPointerUp = () => {
            this.stopTracking()
            this.dragging = false
            delete this.el.dataset.rotating

            const rotation = this.rotation
            if (rotation === null) return
            if (rotation === Number(this.el.dataset.rotation)) {
              this.rotation = null
              return
            }

            this.pushEvent("rotate_node", {node_id: this.el.dataset.nodeId, rotation}, () => {
              if (!this.dragging && this.rotation === rotation) this.rotation = null
            })
          }

          this.el.addEventListener("pointerdown", this.onPointerDown)
        },

        updated() {
          if (this.rotation !== null) this.apply()
        },

        destroyed() {
          this.stopTracking()
        },

        stopTracking() {
          window.removeEventListener("pointermove", this.onPointerMove)
          window.removeEventListener("pointerup", this.onPointerUp)
          window.removeEventListener("pointercancel", this.onPointerUp)
        },

        apply() {
          this.el.style.transform = `rotate(${this.rotation}deg)`
          const label = this.el.querySelector("[data-rotation-label]")
          if (label) label.textContent = `${this.rotation}°`
        }
      }
    </script>
    """
  end

  attr :node, :map, required: true

  defp rotatable_node(assigns) do
    ~H"""
    <div
      id={"rotatable-#{@node.id}"}
      phx-hook=".RotateNode"
      data-node-id={@node.id}
      data-rotation={@node.data.rotation}
      class="rot-card relative flex h-full w-full flex-col items-center justify-center gap-1.5 rounded-xl px-3 py-2"
      style={"transform: rotate(#{@node.data.rotation}deg)"}
    >
      <NodeResizer.node_resizer
        node_id={@node.id}
        is_visible={@node.data.resizable and @node.selected}
        min_width={150}
        min_height={90}
      />
      <span
        :if={@node.data.rotatable}
        class="rot-stem pointer-events-none absolute -top-5 left-1/2 h-5 w-px -translate-x-1/2"
      ></span>
      <span
        :if={@node.data.rotatable}
        id={"rotate-knob-#{@node.id}"}
        data-rotate-handle
        title="Drag to rotate"
        class="rot-knob nodrag nopan absolute -top-8 left-1/2 size-3.5 -translate-x-1/2 rounded-full"
      ></span>

      <p
        class="text-center text-[13px] leading-tight font-semibold"
        style="color: var(--lf-text-primary)"
      >
        {@node.data.label}
      </p>
      <span
        data-rotation-label
        class="font-mono text-[11px]"
        style="color: var(--lf-text-secondary)"
      >
        {@node.data.rotation}°
      </span>
      <div class="mt-0.5 flex gap-1">
        <.flag_toggle node={@node} flag="rotatable" icon="hero-arrow-path-mini" />
        <.flag_toggle node={@node} flag="resizable" icon="hero-arrows-pointing-out-mini" />
      </div>
    </div>
    """
  end

  attr :node, :map, required: true
  attr :flag, :string, required: true
  attr :icon, :string, required: true

  defp flag_toggle(assigns) do
    assigns = assign(assigns, :on, Map.fetch!(assigns.node.data, flag_key(assigns.flag)))

    ~H"""
    <button
      id={"toggle-#{@flag}-#{@node.id}"}
      type="button"
      phx-click="toggle_flag"
      phx-value-node_id={@node.id}
      phx-value-flag={@flag}
      aria-pressed={to_string(@on)}
      class={[
        "nodrag inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[10px] font-medium transition-all duration-150 active:scale-95",
        if(@on, do: "border-transparent", else: "opacity-60 hover:opacity-100")
      ]}
      style={
        if(@on,
          do:
            "background: color-mix(in oklab, var(--lf-node-selected-border) 14%, transparent); color: var(--lf-node-selected-border)",
          else: "border-color: var(--lf-node-border); color: var(--lf-text-secondary)"
        )
      }
    >
      <.icon name={@icon} class="size-3" />
      {@flag}
    </button>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("rotate_node", %{"node_id" => id, "rotation" => rotation}, socket)
      when is_binary(id) and is_number(rotation) do
    rotation = rotation |> round() |> Integer.mod(360)

    case State.get_node(socket.assigns.flow, id) do
      %Node{} ->
        socket =
          socket
          |> FlowEvents.snapshot()
          |> update(:flow, &put_data(&1, id, :rotation, rotation))
          |> FlowEvents.log("rotate_node", %{"node_id" => id, "rotation" => rotation})

        {:reply, %{rotation: rotation}, socket}

      nil ->
        {:reply, %{}, socket}
    end
  end

  def handle_event("toggle_flag", %{"node_id" => id, "flag" => flag}, socket)
      when flag in ["rotatable", "resizable"] do
    key = flag_key(flag)

    flow =
      State.update_node(socket.assigns.flow, id, fn node ->
        %{node | data: Map.update!(node.data, key, &(not &1))}
      end)

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, flow)
     |> FlowEvents.log("toggle_flag", %{"node_id" => id, "flag" => flag})}
  end

  def handle_event("set_snap", %{"rotation" => %{"snap" => value}}, socket) do
    snap = value == "true"
    {:noreply, assign(socket, snap: snap, snap_form: snap_form(snap))}
  end

  def handle_event("reset_rotation", _params, socket) do
    flow = socket.assigns.flow

    flow =
      Enum.reduce(Map.keys(flow.nodes), flow, fn id, acc -> put_data(acc, id, :rotation, 0) end)

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, flow)
     |> FlowEvents.log("reset_rotation", %{})}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp flag_key("rotatable"), do: :rotatable
  defp flag_key("resizable"), do: :resizable

  defp put_data(flow, id, key, value) do
    State.update_node(flow, id, fn node -> %{node | data: Map.put(node.data, key, value)} end)
  end

  defp snap_form(snap), do: to_form(%{"snap" => snap}, as: :rotation)

  # ===== Initial graph =====

  defp build_flow do
    node = fn id, x, y, label, data ->
      Node.new(
        id,
        %{x: x, y: y},
        Map.merge(%{label: label, rotation: 0, rotatable: false, resizable: false}, data),
        type: :rotatable,
        resizable: true,
        width: 190,
        height: 110,
        # The edges attach to the axis-aligned box: the handles are invisible
        handles: [
          Handle.target(:top, class: "rot-handle", connectable: false),
          Handle.source(:bottom, class: "rot-handle", connectable: false)
        ]
      )
    end

    nodes = [
      node.("1", 0, 0, "Node with rotation", %{rotatable: true, rotation: 345}),
      node.("2", 330, 210, "Node with resize", %{resizable: true}),
      node.("3", 0, 430, "Rotation and resize", %{rotatable: true, resizable: true, rotation: 15})
    ]

    edges = [
      Edge.new("e1-2", "1", "2", type: :smoothstep, marker_end: %{type: :none}),
      Edge.new("e2-3", "2", "3", type: :smoothstep, marker_end: %{type: :none})
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

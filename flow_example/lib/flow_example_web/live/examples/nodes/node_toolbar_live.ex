defmodule FlowExampleWeb.Examples.Nodes.NodeToolbarLive do
  @moduledoc """
  Node Toolbar: a toolbar with buttons appears next to the selected node.

  Custom nodes render `LiveFlow.Components.NodeToolbar.node_toolbar/1`. Its
  position, alignment and visibility come from the node data, updated from
  the sidebar.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Node, State}
  alias LiveFlow.Components.NodeToolbar

  @positions [:top, :right, :bottom, :left]
  @aligns [:start, :center, :end]
  @colors ~w(sky violet emerald amber rose)
  @hex %{
    "sky" => "#0ea5e9",
    "violet" => "#8b5cf6",
    "emerald" => "#10b981",
    "amber" => "#f59e0b",
    "rose" => "#f43f5e"
  }

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)
    toolbar = %{position: :top, align: :center, visible: false}

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, next_id: 4)
     |> assign(positions: @positions, aligns: @aligns, toolbar: toolbar)
     |> assign(:visibility_form, visibility_form(false))
     |> FlowEvents.assign_flow(build_flow(toolbar))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #node-toolbar .tb-btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 4px;
        height: 28px;
        padding: 0 8px;
        border-radius: 6px;
        color: var(--lf-controls-color);
        font-size: 12px;
        font-weight: 500;
        transition: background-color 150ms ease, color 150ms ease, transform 150ms ease;
      }

      #node-toolbar .tb-btn:hover {
        background: var(--lf-controls-button-hover);
        color: var(--lf-text-primary);
      }

      #node-toolbar .tb-btn:active {
        transform: scale(0.94);
      }

      #node-toolbar .tb-btn.tb-danger:hover {
        background: var(--lf-delete-hover-bg);
        color: var(--lf-delete-hover-color);
      }

      #node-toolbar .lf-node-toolbar {
        animation: node-toolbar-in 140ms ease-out;
      }

      @keyframes node-toolbar-in {
        from {
          opacity: 0;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="node-toolbar"
        flow={@flow}
        node_types={%{toolbar: &toolbar_node/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.35}
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Select a node: its toolbar appears next to it. The buttons are regular
            <code>phx-click</code>
            buttons handled by the LiveView.
          </.hint>
          <.hint>
            The node renders
            <code phx-no-curly-interpolation>&lt;NodeToolbar.node_toolbar node={@node} position={:top} align={:center}&gt;</code>
            — it's visible while <code>@node.selected</code>, or always with <code>is_visible</code>.
          </.hint>
        </.option_group>
        <.option_group title="Toolbar position">
          <.segmented
            id_prefix="toolbar-position"
            event="set_position"
            options={@positions}
            value={@toolbar.position}
          />
        </.option_group>
        <.option_group title="Toolbar align">
          <.segmented
            id_prefix="toolbar-align"
            event="set_align"
            options={@aligns}
            value={@toolbar.align}
          />
        </.option_group>
        <.option_group title="Visibility">
          <.form for={@visibility_form} id="toolbar-visibility-form" phx-change="set_visible">
            <.input
              field={@visibility_form[:always_visible]}
              type="checkbox"
              label="Always show toolbars"
              class={switch_class()}
            />
          </.form>
        </.option_group>
        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :id_prefix, :string, required: true
  attr :event, :string, required: true
  attr :options, :list, required: true
  attr :value, :atom, required: true

  defp segmented(assigns) do
    ~H"""
    <div class="flex gap-1 rounded-lg bg-base-200 p-1">
      <button
        :for={option <- @options}
        id={"#{@id_prefix}-#{option}"}
        type="button"
        phx-click={@event}
        phx-value-value={option}
        class={[
          "flex-1 rounded-md px-2 py-1 text-xs font-medium capitalize transition-all duration-150 active:scale-95",
          if(option == @value,
            do: "bg-base-100 text-base-content shadow-sm",
            else: "text-base-content/60 hover:text-base-content"
          )
        ]}
      >
        {option}
      </button>
    </div>
    """
  end

  attr :node, :map, required: true

  defp toolbar_node(assigns) do
    assigns = assign(assigns, :hex, Map.fetch!(@hex, assigns.node.data.color))

    ~H"""
    <NodeToolbar.node_toolbar
      id={"toolbar-#{@node.id}"}
      node={@node}
      position={@node.data.toolbar.position}
      align={@node.data.toolbar.align}
      is_visible={@node.data.toolbar.visible || nil}
    >
      <button
        id={"toolbar-#{@node.id}-color"}
        type="button"
        class="tb-btn"
        phx-click="cycle_color"
        phx-value-id={@node.id}
        title="Change color"
      >
        <.icon name="hero-swatch-mini" class="size-4" /> Color
      </button>
      <button
        id={"toolbar-#{@node.id}-duplicate"}
        type="button"
        class="tb-btn"
        phx-click="duplicate"
        phx-value-id={@node.id}
        title="Duplicate"
      >
        <.icon name="hero-document-duplicate-mini" class="size-4" /> Duplicate
      </button>
      <button
        id={"toolbar-#{@node.id}-delete"}
        type="button"
        class="tb-btn tb-danger"
        phx-click="delete"
        phx-value-id={@node.id}
        title="Delete"
      >
        <.icon name="hero-trash-mini" class="size-4" /> Delete
      </button>
    </NodeToolbar.node_toolbar>
    <div class="flex w-40 items-center gap-2.5">
      <span
        class="grid size-8 shrink-0 place-items-center rounded-lg text-white shadow-sm transition-colors duration-200"
        style={"background: #{@hex}"}
      >
        <.icon name="hero-cube-mini" class="size-4" />
      </span>
      <div class="min-w-0">
        <p class="truncate text-[13px] font-semibold" style="color: var(--lf-text-primary)">
          {@node.data.label}
        </p>
        <p class="truncate text-[11px] capitalize" style="color: var(--lf-text-secondary)">
          {@node.data.color}
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("set_position", %{"value" => value}, socket) do
    {:noreply, update_toolbar(socket, :position, find_option(@positions, value))}
  end

  def handle_event("set_align", %{"value" => value}, socket) do
    {:noreply, update_toolbar(socket, :align, find_option(@aligns, value))}
  end

  def handle_event("set_visible", %{"toolbar" => %{"always_visible" => value}}, socket) do
    visible = value == "true"

    {:noreply,
     socket
     |> assign(:visibility_form, visibility_form(visible))
     |> update_toolbar(:visible, visible)}
  end

  def handle_event("cycle_color", %{"id" => id}, socket) do
    flow =
      State.update_node(socket.assigns.flow, id, fn node ->
        index = Enum.find_index(@colors, &(&1 == node.data.color)) || 0
        next = Enum.at(@colors, rem(index + 1, length(@colors)))
        %{node | data: %{node.data | color: next}}
      end)

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, flow)
     |> FlowEvents.log("cycle_color", %{"id" => id})}
  end

  def handle_event("duplicate", %{"id" => id}, socket) do
    case State.get_node(socket.assigns.flow, id) do
      %Node{} = node ->
        new_id = "n#{socket.assigns.next_id}"

        copy = %{
          node
          | id: new_id,
            position: %{x: node.position.x + 40, y: node.position.y + 70},
            data: %{node.data | label: "Node #{socket.assigns.next_id}"},
            selected: false,
            dragging: false
        }

        {:noreply,
         socket
         |> FlowEvents.snapshot()
         |> assign(
           flow: State.add_node(socket.assigns.flow, copy),
           next_id: socket.assigns.next_id + 1
         )
         |> FlowEvents.log("duplicate", %{"id" => id, "copy" => new_id})}

      nil ->
        {:noreply, socket}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> update(:flow, &State.remove_node(&1, id))
     |> FlowEvents.log("delete", %{"id" => id})}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # Option values come from the client: match them against the known atoms
  defp find_option(options, value), do: Enum.find(options, &(Atom.to_string(&1) == value))

  defp update_toolbar(socket, _key, nil), do: socket

  defp update_toolbar(socket, key, value) do
    toolbar = Map.put(socket.assigns.toolbar, key, value)

    nodes =
      Map.new(socket.assigns.flow.nodes, fn {id, node} ->
        {id, %{node | data: Map.put(node.data, :toolbar, toolbar)}}
      end)

    assign(socket, toolbar: toolbar, flow: %{socket.assigns.flow | nodes: nodes})
  end

  defp visibility_form(visible) do
    to_form(%{"always_visible" => visible}, as: :toolbar)
  end

  defp build_flow(toolbar) do
    node = fn id, x, y, label, color ->
      Node.new(id, %{x: x, y: y}, %{label: label, color: color, toolbar: toolbar}, type: :toolbar)
    end

    nodes = [
      node.("1", 0, 80, "Select me", "sky"),
      node.("2", 340, 0, "Or me", "violet"),
      node.("3", 340, 170, "Me too", "emerald")
    ]

    edges = [
      Edge.new("e1-2", "1", "2", type: :smoothstep),
      Edge.new("e1-3", "1", "3", type: :smoothstep)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

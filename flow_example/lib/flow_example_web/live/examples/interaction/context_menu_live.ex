defmodule FlowExampleWeb.Examples.Interaction.ContextMenuLive do
  @moduledoc """
  Context Menu: right-click a node, an edge or the pane to display custom actions.

  With `context_menu: true` the hook prevents the browser menu and pushes
  `lf:node_context_menu`, `lf:edge_context_menu` or `lf:pane_context_menu`
  with `x`/`y` relative to the flow container (to position the menu) and
  `position` in flow coordinates (to add a node there). `pane_click_events: true`
  adds `lf:pane_click`, used to close the menu.

  The menu is a sibling of the flow inside a relatively positioned wrapper; a
  colocated hook keeps it inside the canvas.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Node, State}

  @flow_id "context-menu-flow"

  @colors [
    {"slate", "#64748b"},
    {"sky", "#0ea5e9"},
    {"violet", "#8b5cf6"},
    {"emerald", "#10b981"},
    {"amber", "#f59e0b"},
    {"rose", "#f43f5e"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, menu: nil, next_id: 5)
     |> assign(colors: @colors, flow_id: @flow_id)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #context-menu-flow .lf-node[data-node-type="swatch"] {
        border-color: color-mix(in oklab, var(--accent) 45%, var(--lf-node-border));
        box-shadow: inset 4px 0 0 var(--accent), var(--lf-node-shadow);
      }
      #context-menu-flow .lf-node[data-node-type="swatch"].lf-node-selected {
        border-color: var(--lf-node-selected-border);
      }
      #context-menu {
        animation: context-menu-in 120ms cubic-bezier(0.2, 0.9, 0.3, 1.2);
      }
      @keyframes context-menu-in {
        from {
          opacity: 0;
          scale: 0.94;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <div id="context-menu-canvas" class="relative h-full w-full">
        <.live_component
          module={LiveFlow.Components.Flow}
          id={@flow_id}
          flow={@flow}
          node_types={%{swatch: &swatch_node/1}}
          opts={
            %{
              background: :dots,
              controls: true,
              minimap: true,
              fit_view_on_init: true,
              fit_view_options: %{padding: 0.3},
              context_menu: true,
              pane_click_events: true
            }
          }
        />

        <div
          :if={@menu}
          id="context-menu"
          role="menu"
          phx-hook=".ContextMenu"
          phx-window-keydown="close_menu"
          phx-key="Escape"
          data-x={@menu.x}
          data-y={@menu.y}
          style={"left: #{@menu.x}px; top: #{@menu.y}px"}
          class="absolute z-50 w-56 rounded-xl border border-base-300 bg-base-100/95 p-1.5 text-sm shadow-xl ring-1 ring-black/5 backdrop-blur"
        >
          <%= case @menu.kind do %>
            <% :node -> %>
              <.menu_header
                title={node_menu_title(@flow, @menu.targets)}
                subtitle={node_menu_subtitle(@menu.targets)}
              />
              <.menu_item id="menu-duplicate" icon="hero-document-duplicate" phx-click="duplicate">
                Duplicate
              </.menu_item>
              <div class="px-2.5 pt-2 pb-1.5">
                <p class="mb-1.5 text-[11px] font-medium text-base-content/50">Color</p>
                <div class="flex items-center gap-1.5">
                  <button
                    :for={{name, hex} <- @colors}
                    id={"menu-color-#{name}"}
                    type="button"
                    role="menuitem"
                    phx-click="change_color"
                    phx-value-color={name}
                    aria-label={"Color #{name}"}
                    title={name}
                    class={[
                      "size-5 rounded-full ring-offset-2 ring-offset-base-100 transition-transform duration-150 hover:scale-115 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary",
                      current_color(@flow, @menu.targets) == name && "ring-2 ring-base-content/40"
                    ]}
                    style={"background: #{hex}"}
                  />
                </div>
              </div>
              <div class="my-1 border-t border-base-300" />
              <.menu_item id="menu-delete" icon="hero-trash" danger phx-click="delete_nodes">
                Delete
              </.menu_item>
            <% :edge -> %>
              <.menu_header title={"Edge #{@menu.id}"} subtitle={edge_subtitle(@flow, @menu.id)} />
              <.menu_item id="menu-toggle-animated" icon="hero-sparkles" phx-click="toggle_animated">
                {if edge_animated?(@flow, @menu.id), do: "Stop animation", else: "Animate"}
              </.menu_item>
              <div class="my-1 border-t border-base-300" />
              <.menu_item id="menu-delete-edge" icon="hero-scissors" danger phx-click="delete_edge">
                Delete edge
              </.menu_item>
            <% :pane -> %>
              <.menu_header
                title="Canvas"
                subtitle={"x #{round(@menu.position["x"])} · y #{round(@menu.position["y"])}"}
              />
              <.menu_item id="menu-add-node" icon="hero-plus-circle" phx-click="add_node">
                Add node here
              </.menu_item>
              <.menu_item
                id="menu-fit-view"
                icon="hero-arrows-pointing-out"
                phx-click={JS.dispatch("lf:fit-view", to: "##{@flow_id}") |> JS.push("close_menu")}
              >
                Fit view
              </.menu_item>
          <% end %>
        </div>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".ContextMenu">
          // Keeps the menu inside the canvas: it opens towards the free side
          // (like native menus) and is clamped to the canvas bounds.
          export default {
            mounted() {
              this.place()
              this.el.querySelector("button")?.focus({preventScroll: true})
            },
            updated() {
              this.place()
            },
            place() {
              const parent = this.el.offsetParent
              if (!parent) return
              const pad = 8
              const x = Number(this.el.dataset.x)
              const y = Number(this.el.dataset.y)
              const w = this.el.offsetWidth
              const h = this.el.offsetHeight
              const maxX = parent.clientWidth - w - pad
              const maxY = parent.clientHeight - h - pad
              let left = x > maxX ? x - w : x
              let top = y > maxY ? y - h : y
              left = Math.max(pad, Math.min(left, maxX))
              top = Math.max(pad, Math.min(top, maxY))
              this.el.style.left = `${left}px`
              this.el.style.top = `${top}px`
              this.el.style.transformOrigin = `${left < x ? "right" : "left"} ${top < y ? "bottom" : "top"}`
            }
          }
        </script>
      </div>

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Right-click a <b>node</b>, an <b>edge</b>
            or the <b>pane</b>. With <code>context_menu: true</code>
            the hook pushes <code>lf:node_context_menu</code>, <code>lf:edge_context_menu</code>
            or <code>lf:pane_context_menu</code>.
          </.hint>
          <.hint>
            The payload has <code>x</code>/<code>y</code>
            relative to the flow container, used to place this menu, and <code>position</code>
            in flow coordinates, used by <b>Add node here</b>. Node menus also receive the current <code>selection</code>: right-click a multi-selection to act on all of it.
          </.hint>
          <.hint>
            The menu closes on <code>lf:pane_click</code>
            (<code>pane_click_events: true</code>), on node click, when the viewport moves, after an action and with <.kbd>Esc</.kbd>.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil

  defp menu_header(assigns) do
    ~H"""
    <div class="mb-1 border-b border-base-300 px-2.5 pt-1 pb-2">
      <p class="truncate text-xs font-semibold">{@title}</p>
      <p :if={@subtitle} class="truncate font-mono text-[11px] text-base-content/50">{@subtitle}</p>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :danger, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  defp menu_item(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      role="menuitem"
      class={[
        "group flex w-full items-center gap-2.5 rounded-lg px-2.5 py-1.5 text-left text-[13px] transition-colors duration-100 focus:outline-none",
        if(@danger,
          do: "text-rose-600 hover:bg-rose-500/10 focus-visible:bg-rose-500/10",
          else: "hover:bg-base-200 focus-visible:bg-base-200"
        )
      ]}
      {@rest}
    >
      <.icon
        name={@icon <> "-mini"}
        class="size-4 opacity-70 transition-transform duration-150 group-hover:scale-110"
      />
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :node, :map, required: true

  defp swatch_node(assigns) do
    ~H"""
    <div class="flex w-36 items-center gap-2.5" data-color={@node.data.color}>
      <span class="size-2.5 shrink-0 rounded-full" style="background: var(--accent)" />
      <div class="min-w-0">
        <p
          class="truncate text-[13px] leading-tight font-semibold"
          style="color: var(--lf-text-primary)"
        >
          {@node.data.label}
        </p>
        <p class="font-mono text-[11px]" style="color: var(--lf-text-secondary)">
          {@node.data.color}
        </p>
      </div>
    </div>
    """
  end

  # ===== Opening / closing the menu =====

  @impl true
  def handle_event("lf:node_context_menu", %{"id" => id} = params, socket) do
    selection = params["selection"] || []
    targets = if id in selection and length(selection) > 1, do: selection, else: [id]
    menu = %{kind: :node, id: id, targets: targets, x: params["x"], y: params["y"]}

    socket
    |> assign(:menu, menu)
    |> FlowEvents.log("lf:node_context_menu", Map.drop(params, ["position"]))
    |> noreply()
  end

  def handle_event("lf:edge_context_menu", %{"id" => id} = params, socket) do
    socket
    |> assign(:menu, %{kind: :edge, id: id, x: params["x"], y: params["y"]})
    |> FlowEvents.log("lf:edge_context_menu", Map.drop(params, ["position"]))
    |> noreply()
  end

  def handle_event("lf:pane_context_menu", params, socket) do
    menu = %{kind: :pane, x: params["x"], y: params["y"], position: params["position"]}

    socket
    |> assign(:menu, menu)
    |> FlowEvents.log("lf:pane_context_menu", params)
    |> noreply()
  end

  def handle_event("close_menu", _params, socket) do
    {:noreply, assign(socket, :menu, nil)}
  end

  # ===== Node actions =====

  def handle_event("duplicate", _params, %{assigns: %{menu: %{kind: :node} = menu}} = socket) do
    {nodes, next_id} =
      menu.targets
      |> Enum.map(&State.get_node(socket.assigns.flow, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.map_reduce(socket.assigns.next_id, fn node, n ->
        copy =
          swatch(
            Integer.to_string(n),
            node.position.x + 40,
            node.position.y + 40,
            "#{node.data.label} copy",
            node.data.color
          )

        {copy, n + 1}
      end)

    socket
    |> FlowEvents.snapshot()
    |> assign(:flow, State.add_nodes(socket.assigns.flow, nodes))
    |> assign(next_id: next_id, menu: nil)
    |> FlowEvents.log("duplicate", %{"nodes" => Enum.map(nodes, & &1.id)})
    |> noreply()
  end

  def handle_event("delete_nodes", _params, %{assigns: %{menu: %{kind: :node} = menu}} = socket) do
    socket
    |> FlowEvents.snapshot()
    |> assign(:flow, State.remove_nodes(socket.assigns.flow, menu.targets))
    |> assign(:menu, nil)
    |> FlowEvents.log("delete", %{"nodes" => menu.targets})
    |> noreply()
  end

  def handle_event(
        "change_color",
        %{"color" => color},
        %{assigns: %{menu: %{kind: :node} = menu}} = socket
      ) do
    case List.keyfind(@colors, color, 0) do
      {name, hex} ->
        flow =
          Enum.reduce(menu.targets, socket.assigns.flow, fn id, flow ->
            State.update_node(flow, id, fn node ->
              %{
                node
                | data: Map.put(node.data, :color, name),
                  style: Map.put(node.style, "--accent", hex)
              }
            end)
          end)

        socket
        |> FlowEvents.snapshot()
        |> assign(flow: flow, menu: nil)
        |> FlowEvents.log("change_color", %{"nodes" => menu.targets, "color" => name})
        |> noreply()

      nil ->
        {:noreply, socket}
    end
  end

  # ===== Edge actions =====

  def handle_event("delete_edge", _params, %{assigns: %{menu: %{kind: :edge, id: id}}} = socket) do
    socket
    |> FlowEvents.snapshot()
    |> assign(flow: State.remove_edge(socket.assigns.flow, id), menu: nil)
    |> FlowEvents.log("delete_edge", %{"edge" => id})
    |> noreply()
  end

  def handle_event(
        "toggle_animated",
        _params,
        %{assigns: %{menu: %{kind: :edge, id: id}}} = socket
      ) do
    animated = not edge_animated?(socket.assigns.flow, id)

    socket
    |> FlowEvents.snapshot()
    |> assign(flow: State.update_edge(socket.assigns.flow, id, animated: animated), menu: nil)
    |> FlowEvents.log("toggle_animated", %{"edge" => id, "animated" => animated})
    |> noreply()
  end

  # ===== Pane actions =====

  def handle_event("add_node", _params, %{assigns: %{menu: %{kind: :pane} = menu}} = socket) do
    n = socket.assigns.next_id
    %{"x" => x, "y" => y} = menu.position
    node = swatch(Integer.to_string(n), x, y, "Node #{n}", "sky")

    socket
    |> FlowEvents.snapshot()
    |> assign(flow: State.add_node(socket.assigns.flow, node), next_id: n + 1, menu: nil)
    |> FlowEvents.log("add_node", %{"id" => node.id, "position" => menu.position})
    |> noreply()
  end

  # A menu action arriving after the menu was closed (e.g. double click)
  def handle_event(action, _params, socket)
      when action in ~w(duplicate delete_nodes change_color delete_edge toggle_animated add_node) do
    {:noreply, socket}
  end

  # ===== Flow events =====

  def handle_event("lf:pane_click", params, socket) do
    socket
    |> assign(:menu, nil)
    |> FlowEvents.log("lf:pane_click", params)
    |> noreply()
  end

  def handle_event("lf:viewport_change", params, socket) do
    {:noreply, socket} = FlowEvents.handle_event("lf:viewport_change", params, socket)
    {:noreply, assign(socket, :menu, nil)}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    {:noreply, socket} = FlowEvents.handle_event(event, params, socket)
    {:noreply, close_stale_menu(socket)}
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, assign(socket, :menu, nil)}

  # ===== Helpers =====

  # Closes the menu when its node/edge disappeared (keyboard delete, undo...)
  defp close_stale_menu(%{assigns: %{menu: %{kind: :node, targets: ids}}} = socket) do
    if Enum.all?(ids, &State.get_node(socket.assigns.flow, &1)),
      do: socket,
      else: assign(socket, :menu, nil)
  end

  defp close_stale_menu(%{assigns: %{menu: %{kind: :edge, id: id}}} = socket) do
    if State.get_edge(socket.assigns.flow, id), do: socket, else: assign(socket, :menu, nil)
  end

  defp close_stale_menu(socket), do: socket

  defp node_menu_title(flow, [id]) do
    case State.get_node(flow, id) do
      nil -> "Node"
      node -> node.data.label
    end
  end

  defp node_menu_title(_flow, ids), do: "#{length(ids)} nodes"

  defp node_menu_subtitle([id]), do: "id: #{id}"
  defp node_menu_subtitle(ids), do: Enum.join(ids, ", ")

  defp current_color(flow, [id]) do
    case State.get_node(flow, id) do
      nil -> nil
      node -> node.data.color
    end
  end

  defp current_color(_flow, _ids), do: nil

  defp edge_subtitle(flow, id) do
    case State.get_edge(flow, id) do
      nil -> nil
      edge -> "#{edge.source} → #{edge.target}"
    end
  end

  defp edge_animated?(flow, id) do
    case State.get_edge(flow, id) do
      %Edge{animated: animated} -> animated
      nil -> false
    end
  end

  defp noreply(socket), do: {:noreply, socket}

  # ===== Initial graph =====

  defp swatch(id, x, y, label, color) do
    {_name, hex} = List.keyfind(@colors, color, 0, {"slate", "#64748b"})

    Node.new(id, %{x: x, y: y}, %{label: label, color: color},
      type: :swatch,
      style: %{"--accent" => hex}
    )
  end

  defp build_flow do
    nodes = [
      swatch("1", 0, 100, "Node 1", "sky"),
      swatch("2", 260, 0, "Node 2", "violet"),
      swatch("3", 260, 200, "Node 3", "emerald"),
      swatch("4", 520, 100, "Node 4", "amber")
    ]

    edges = [
      Edge.new("e1-2", "1", "2", type: :smoothstep),
      Edge.new("e1-3", "1", "3", type: :smoothstep),
      Edge.new("e2-4", "2", "4", type: :smoothstep, animated: true),
      Edge.new("e3-4", "3", "4", type: :smoothstep)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

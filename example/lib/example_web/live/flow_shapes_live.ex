defmodule ExampleWeb.FlowShapesLive do
  @moduledoc """
  Flow Shapes demo — custom SVG shape nodes for flow diagrams.

  Shows how to render a single "shape" node type that draws different SVG paths
  based on `node.data.shape`. Includes a sidebar for adding shapes, a color
  picker for selected nodes, and a minimap.
  """

  use ExampleWeb, :live_view

  alias LiveFlow.{State, Node, Edge, Handle, History, Clipboard, Layout}
  alias LiveFlow.Validation

  @colors ~w(#ef4444 #f97316 #eab308 #22c55e #3b82f6 #8b5cf6)

  @shapes ~w(circle round-rectangle rectangle hexagon diamond arrow-rectangle cylinder triangle parallelogram plus)

  # ───────────────────────── Mount ─────────────────────────

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Flow Shapes",
       flow: create_demo_flow(),
       history: History.new(),
       clipboard: Clipboard.new(),
       node_types: %{shape: &shape_node/1},
       lf_theme: nil
     )}
  end

  # ───────────────────────── Render ─────────────────────────

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:colors, @colors)
      |> assign(:shapes, @shapes)
      |> assign(:selected_node, first_selected_node(assigns.flow))

    ~H"""
    <div>
      <div class="h-screen flex flex-col">
        <div class="flex-1 relative">
          <.sidebar shapes={@shapes} colors={@colors} selected_node={@selected_node} />

          <.live_component
            module={LiveFlow.Components.Flow}
            id="shapes-flow"
            flow={@flow}
            opts={
              %{
                controls: true,
                minimap: true,
                background: :dots,
                fit_view_on_init: true,
                snap_to_grid: true,
                snap_grid: {20, 20},
                theme: @lf_theme,
                helper_lines: true
              }
            }
            node_types={@node_types}
          />
        </div>
      </div>
    </div>
    """
  end

  # ───────────────────────── Sidebar ─────────────────────────

  attr :shapes, :list, required: true
  attr :colors, :list, required: true
  attr :selected_node, :any, default: nil

  defp sidebar(assigns) do
    ~H"""
    <div
      class="absolute top-4 left-4 z-10 bg-base-100/90 backdrop-blur-sm border border-base-300 rounded-xl p-3 shadow-lg"
      style="width: 200px"
    >
      <p class="text-xs font-medium text-base-content/70 mb-2">Drag shapes to the canvas</p>
      <div class="grid grid-cols-4 gap-1.5">
        <button
          :for={shape <- @shapes}
          class="w-10 h-10 flex items-center justify-center rounded-lg hover:bg-base-200 transition-colors cursor-grab"
          phx-click="add_shape"
          phx-value-shape={shape}
          title={shape}
        >
          <.sidebar_shape shape={shape} />
        </button>
      </div>

      <div :if={@selected_node} class="mt-3 pt-3 border-t border-base-300">
        <p class="text-xs text-base-content/60 mb-2">Node color</p>
        <div class="flex gap-1.5 justify-center">
          <button
            :for={color <- @colors}
            class={[
              "w-6 h-6 rounded-full border-2 transition-transform hover:scale-110",
              if(Map.get(@selected_node.data, :color) == color,
                do: "border-base-content scale-110",
                else: "border-transparent"
              )
            ]}
            style={"background: #{color}"}
            phx-click="change_node_color"
            phx-value-color={color}
          />
        </div>
      </div>
    </div>
    """
  end

  # ───────────────────────── Shape Node Renderer ─────────────────────────

  defp shape_node(assigns) do
    node = assigns.node
    shape = Map.get(node.data, :shape) || Map.get(node.data, "shape", "rectangle")
    color = Map.get(node.data, :color) || Map.get(node.data, "color", "#3b82f6")
    label = Map.get(node.data, :label) || Map.get(node.data, "label", "")
    {w, h} = shape_dimensions(shape)

    assigns =
      assigns
      |> assign(:shape, shape)
      |> assign(:color, color)
      |> assign(:label, label)
      |> assign(:selected, node.selected)
      |> assign(:w, w)
      |> assign(:h, h)

    ~H"""
    <div style={"width: #{@w}px; height: #{@h}px"}>
      <svg
        width={@w}
        height={@h}
        viewBox={"0 0 #{@w} #{@h}"}
        xmlns="http://www.w3.org/2000/svg"
      >
        <.shape_path shape={@shape} color={@color} w={@w} h={@h} selected={@selected} />
        <text
          x={div(@w, 2)}
          y={text_y(@shape, @h)}
          text-anchor="middle"
          dominant-baseline="central"
          fill="white"
          font-size="13"
          font-weight="600"
          style="pointer-events: none"
        >
          {@label}
        </text>
      </svg>
    </div>
    """
  end

  # ───────────────────────── SVG Shape Paths ─────────────────────────

  attr :shape, :string, required: true
  attr :color, :string, required: true
  attr :w, :integer, required: true
  attr :h, :integer, required: true
  attr :selected, :boolean, default: false

  defp shape_path(%{shape: "round-rectangle"} = assigns) do
    ~H"""
    <rect
      x="1"
      y="1"
      width={@w - 2}
      height={@h - 2}
      rx="12"
      ry="12"
      fill={@color}
      stroke={if(@selected, do: "rgba(0,0,0,0.4)", else: "none")}
      stroke-width={if(@selected, do: "2", else: "0")}
    />
    """
  end

  defp shape_path(%{shape: "circle"} = assigns) do
    ~H"""
    <ellipse
      cx={div(@w, 2)}
      cy={div(@h, 2)}
      rx={div(@w, 2) - 1}
      ry={div(@h, 2) - 1}
      fill={@color}
      stroke={if(@selected, do: "rgba(0,0,0,0.4)", else: "none")}
      stroke-width={if(@selected, do: "2", else: "0")}
    />
    """
  end

  defp shape_path(%{shape: "diamond"} = assigns) do
    cx = div(assigns.w, 2)
    cy = div(assigns.h, 2)

    assigns =
      assign(assigns, :points, "#{cx},2 #{assigns.w - 2},#{cy} #{cx},#{assigns.h - 2} 2,#{cy}")

    ~H"""
    <polygon
      points={@points}
      fill={@color}
      stroke={if(@selected, do: "rgba(0,0,0,0.4)", else: "none")}
      stroke-width={if(@selected, do: "2", else: "0")}
    />
    """
  end

  defp shape_path(%{shape: "hexagon"} = assigns) do
    w = assigns.w
    h = assigns.h
    inset = round(w * 0.2)

    assigns =
      assign(
        assigns,
        :points,
        "#{inset},1 #{w - inset},1 #{w - 1},#{div(h, 2)} #{w - inset},#{h - 1} #{inset},#{h - 1} 1,#{div(h, 2)}"
      )

    ~H"""
    <polygon
      points={@points}
      fill={@color}
      stroke={if(@selected, do: "rgba(0,0,0,0.4)", else: "none")}
      stroke-width={if(@selected, do: "2", else: "0")}
    />
    """
  end

  defp shape_path(%{shape: "arrow-rectangle"} = assigns) do
    w = assigns.w
    h = assigns.h
    tip = round(w * 0.2)

    assigns =
      assign(
        assigns,
        :points,
        "1,1 #{w - tip},1 #{w - 1},#{div(h, 2)} #{w - tip},#{h - 1} 1,#{h - 1}"
      )

    ~H"""
    <polygon
      points={@points}
      fill={@color}
      stroke={if(@selected, do: "rgba(0,0,0,0.4)", else: "none")}
      stroke-width={if(@selected, do: "2", else: "0")}
    />
    """
  end

  defp shape_path(%{shape: "cylinder"} = assigns) do
    assigns = assign(assigns, :ry, 15)

    ~H"""
    <ellipse cx={div(@w, 2)} cy={@h - @ry} rx={div(@w, 2) - 1} ry={@ry} fill={@color} />
    <rect x="1" y={@ry} width={@w - 2} height={@h - 2 * @ry} fill={@color} />
    <ellipse cx={div(@w, 2)} cy={@ry} rx={div(@w, 2) - 1} ry={@ry} fill={@color} />
    <ellipse cx={div(@w, 2)} cy={@ry} rx={div(@w, 2) - 1} ry={@ry} fill="rgba(255,255,255,0.15)" />
    """
  end

  defp shape_path(%{shape: "rectangle"} = assigns) do
    ~H"""
    <rect
      x="1"
      y="1"
      width={@w - 2}
      height={@h - 2}
      fill={@color}
      stroke={if(@selected, do: "rgba(0,0,0,0.4)", else: "none")}
      stroke-width={if(@selected, do: "2", else: "0")}
    />
    """
  end

  defp shape_path(%{shape: "parallelogram"} = assigns) do
    w = assigns.w
    h = assigns.h
    skew = round(w * 0.18)
    assigns = assign(assigns, :points, "#{skew},1 #{w - 1},1 #{w - skew},#{h - 1} 1,#{h - 1}")

    ~H"""
    <polygon
      points={@points}
      fill={@color}
      stroke={if(@selected, do: "rgba(0,0,0,0.4)", else: "none")}
      stroke-width={if(@selected, do: "2", else: "0")}
    />
    """
  end

  defp shape_path(%{shape: "plus"} = assigns) do
    w = assigns.w
    h = assigns.h
    t = round(w * 0.3)

    assigns =
      assign(
        assigns,
        :points,
        "#{t},1 #{w - t},1 #{w - t},#{t} #{w - 1},#{t} #{w - 1},#{h - t} #{w - t},#{h - t} #{w - t},#{h - 1} #{t},#{h - 1} #{t},#{h - t} 1,#{h - t} 1,#{t} #{t},#{t}"
      )

    ~H"""
    <polygon
      points={@points}
      fill={@color}
      stroke={if(@selected, do: "rgba(0,0,0,0.4)", else: "none")}
      stroke-width={if(@selected, do: "2", else: "0")}
    />
    """
  end

  defp shape_path(%{shape: "triangle"} = assigns) do
    w = assigns.w
    h = assigns.h
    assigns = assign(assigns, :points, "#{div(w, 2)},2 #{w - 2},#{h - 2} 2,#{h - 2}")

    ~H"""
    <polygon
      points={@points}
      fill={@color}
      stroke={if(@selected, do: "rgba(0,0,0,0.4)", else: "none")}
      stroke-width={if(@selected, do: "2", else: "0")}
    />
    """
  end

  defp shape_path(assigns) do
    ~H"""
    <rect
      x="1"
      y="1"
      width={@w - 2}
      height={@h - 2}
      rx="4"
      ry="4"
      fill={@color}
      stroke={if(@selected, do: "rgba(0,0,0,0.4)", else: "none")}
      stroke-width={if(@selected, do: "2", else: "0")}
    />
    """
  end

  # ───────────────────────── Sidebar Shape Previews ─────────────────────────

  attr :shape, :string, required: true

  defp sidebar_shape(%{shape: "circle"} = assigns) do
    ~H"""
    <svg width="28" height="28" viewBox="0 0 28 28">
      <ellipse cx="14" cy="14" rx="12" ry="12" fill="none" stroke="#888" stroke-width="1.5" />
    </svg>
    """
  end

  defp sidebar_shape(%{shape: "round-rectangle"} = assigns) do
    ~H"""
    <svg width="28" height="28" viewBox="0 0 28 28">
      <rect
        x="2"
        y="6"
        width="24"
        height="16"
        rx="5"
        ry="5"
        fill="none"
        stroke="#888"
        stroke-width="1.5"
      />
    </svg>
    """
  end

  defp sidebar_shape(%{shape: "rectangle"} = assigns) do
    ~H"""
    <svg width="28" height="28" viewBox="0 0 28 28">
      <rect x="3" y="5" width="22" height="18" fill="none" stroke="#888" stroke-width="1.5" />
    </svg>
    """
  end

  defp sidebar_shape(%{shape: "hexagon"} = assigns) do
    ~H"""
    <svg width="28" height="28" viewBox="0 0 28 28">
      <polygon points="7,3 21,3 27,14 21,25 7,25 1,14" fill="none" stroke="#888" stroke-width="1.5" />
    </svg>
    """
  end

  defp sidebar_shape(%{shape: "diamond"} = assigns) do
    ~H"""
    <svg width="28" height="28" viewBox="0 0 28 28">
      <polygon points="14,2 26,14 14,26 2,14" fill="none" stroke="#888" stroke-width="1.5" />
    </svg>
    """
  end

  defp sidebar_shape(%{shape: "arrow-rectangle"} = assigns) do
    ~H"""
    <svg width="28" height="28" viewBox="0 0 28 28">
      <polygon points="2,5 20,5 26,14 20,23 2,23" fill="none" stroke="#888" stroke-width="1.5" />
    </svg>
    """
  end

  defp sidebar_shape(%{shape: "cylinder"} = assigns) do
    ~H"""
    <svg width="28" height="28" viewBox="0 0 28 28">
      <ellipse cx="14" cy="8" rx="10" ry="4" fill="none" stroke="#888" stroke-width="1.5" />
      <line x1="4" y1="8" x2="4" y2="20" stroke="#888" stroke-width="1.5" />
      <line x1="24" y1="8" x2="24" y2="20" stroke="#888" stroke-width="1.5" />
      <path d="M4,20 A10,4 0 0,0 24,20" fill="none" stroke="#888" stroke-width="1.5" />
    </svg>
    """
  end

  defp sidebar_shape(%{shape: "triangle"} = assigns) do
    ~H"""
    <svg width="28" height="28" viewBox="0 0 28 28">
      <polygon points="14,3 25,25 3,25" fill="none" stroke="#888" stroke-width="1.5" />
    </svg>
    """
  end

  defp sidebar_shape(%{shape: "parallelogram"} = assigns) do
    ~H"""
    <svg width="28" height="28" viewBox="0 0 28 28">
      <polygon points="8,5 26,5 20,23 2,23" fill="none" stroke="#888" stroke-width="1.5" />
    </svg>
    """
  end

  defp sidebar_shape(%{shape: "plus"} = assigns) do
    ~H"""
    <svg width="28" height="28" viewBox="0 0 28 28">
      <polygon
        points="10,3 18,3 18,10 25,10 25,18 18,18 18,25 10,25 10,18 3,18 3,10 10,10"
        fill="none"
        stroke="#888"
        stroke-width="1.5"
      />
    </svg>
    """
  end

  defp sidebar_shape(assigns) do
    ~H"""
    <svg width="28" height="28" viewBox="0 0 28 28">
      <rect
        x="3"
        y="5"
        width="22"
        height="18"
        rx="3"
        ry="3"
        fill="none"
        stroke="#888"
        stroke-width="1.5"
      />
    </svg>
    """
  end

  # ───────────────────────── Helpers ─────────────────────────

  defp shape_dimensions(shape) do
    case shape do
      "round-rectangle" -> {180, 50}
      "circle" -> {90, 90}
      "diamond" -> {100, 100}
      "hexagon" -> {150, 70}
      "arrow-rectangle" -> {180, 60}
      "cylinder" -> {130, 100}
      "rectangle" -> {130, 80}
      "parallelogram" -> {180, 60}
      "plus" -> {80, 80}
      "triangle" -> {120, 100}
      _ -> {130, 80}
    end
  end

  defp text_y("cylinder", h), do: div(h, 2) + 5
  defp text_y("triangle", h), do: div(h * 2, 3)
  defp text_y(_shape, h), do: div(h, 2)

  defp first_selected_node(flow) do
    case MapSet.to_list(flow.selected_nodes) do
      [id | _] -> Map.get(flow.nodes, id)
      _ -> nil
    end
  end

  # ───────────────────────── Event Handlers ─────────────────────────

  @impl true
  def handle_event("add_shape", %{"shape" => shape_type}, socket) do
    n = map_size(socket.assigns.flow.nodes) + 1
    color = Enum.random(@colors)

    node =
      Node.new(
        "shape-#{n}",
        %{x: 300 + rem(n, 5) * 50, y: 200 + rem(n, 3) * 50},
        %{shape: shape_type, label: shape_type, color: color},
        type: :shape,
        class: "shape-node",
        handles: [Handle.target(:left), Handle.source(:right)]
      )

    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.add_node(socket.assigns.flow, node)
    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("change_node_color", %{"color" => color}, socket) do
    selected_ids = MapSet.to_list(socket.assigns.flow.selected_nodes)

    if selected_ids == [] do
      {:noreply, socket}
    else
      history = History.push(socket.assigns.history, socket.assigns.flow)

      flow =
        Enum.reduce(selected_ids, socket.assigns.flow, fn node_id, acc ->
          case Map.get(acc.nodes, node_id) do
            nil ->
              acc

            node ->
              updated = %{node | data: Map.put(node.data, :color, color)}
              %{acc | nodes: Map.put(acc.nodes, node_id, updated)}
          end
        end)

      {:noreply, assign(socket, flow: flow, history: history)}
    end
  end

  @impl true
  def handle_event("reset_flow", _params, socket) do
    {:noreply,
     assign(socket, flow: create_demo_flow(), history: History.new(), clipboard: Clipboard.new())}
  end

  @impl true
  def handle_event("fit_view", _params, socket) do
    {:noreply, push_event(socket, "lf:fit_view", %{padding: 0.1, duration: 200})}
  end

  @impl true
  def handle_event("change_theme", %{"theme" => ""}, socket) do
    {:noreply, assign(socket, lf_theme: nil)}
  end

  def handle_event("change_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, lf_theme: theme)}
  end

  @impl true
  def handle_event("lf:node_change", %{"changes" => changes}, socket) do
    history =
      Enum.reduce(changes, socket.assigns.history, fn change, acc ->
        maybe_push_history_for_drag(acc, socket.assigns.flow, change)
      end)

    flow =
      Enum.reduce(changes, socket.assigns.flow, fn change, acc ->
        apply_node_change(acc, change)
      end)

    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("lf:connect_end", params, socket) do
    case Validation.Connection.validate_and_create(socket.assigns.flow, params) do
      {:ok, edge} ->
        history = History.push(socket.assigns.history, socket.assigns.flow)
        flow = State.add_edge(socket.assigns.flow, edge)
        {:noreply, assign(socket, flow: flow, history: history)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:selection_change", %{"nodes" => node_ids, "edges" => edge_ids}, socket) do
    flow =
      socket.assigns.flow
      |> Map.put(:selected_nodes, MapSet.new(node_ids))
      |> Map.put(:selected_edges, MapSet.new(edge_ids))

    nodes =
      Enum.reduce(flow.nodes, %{}, fn {id, node}, acc ->
        Map.put(acc, id, %{node | selected: id in node_ids})
      end)

    edges =
      Enum.reduce(flow.edges, %{}, fn {id, edge}, acc ->
        Map.put(acc, id, %{edge | selected: id in edge_ids})
      end)

    flow = %{flow | nodes: nodes, edges: edges}
    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:delete_selected", _params, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.delete_selected(socket.assigns.flow)
    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("lf:edge_label_change", %{"id" => id, "label" => label}, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.update_edge(socket.assigns.flow, id, label: label)
    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("lf:viewport_change", params, socket) do
    flow = State.update_viewport(socket.assigns.flow, params)
    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:edge_change", %{"changes" => changes}, socket) do
    has_removes = Enum.any?(changes, &(&1["type"] == "remove"))

    history =
      if has_removes,
        do: History.push(socket.assigns.history, socket.assigns.flow),
        else: socket.assigns.history

    flow =
      Enum.reduce(changes, socket.assigns.flow, fn
        %{"type" => "remove", "id" => id}, acc -> State.remove_edge(acc, id)
        _change, acc -> acc
      end)

    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("lf:copy", _params, socket) do
    clipboard = Clipboard.copy(socket.assigns.clipboard, socket.assigns.flow)
    {:noreply, assign(socket, clipboard: clipboard)}
  end

  @impl true
  def handle_event("lf:cut", _params, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    {clipboard, flow} = Clipboard.cut(socket.assigns.clipboard, socket.assigns.flow)
    {:noreply, assign(socket, flow: flow, clipboard: clipboard, history: history)}
  end

  @impl true
  def handle_event("lf:paste", _params, socket) do
    case Clipboard.paste(socket.assigns.clipboard, socket.assigns.flow) do
      {:ok, flow, clipboard} ->
        history = History.push(socket.assigns.history, socket.assigns.flow)
        {:noreply, assign(socket, flow: flow, clipboard: clipboard, history: history)}

      :empty ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:duplicate", _params, socket) do
    clipboard = Clipboard.copy(socket.assigns.clipboard, socket.assigns.flow)

    case Clipboard.paste(clipboard, socket.assigns.flow) do
      {:ok, flow, clipboard} ->
        history = History.push(socket.assigns.history, socket.assigns.flow)
        {:noreply, assign(socket, flow: flow, clipboard: clipboard, history: history)}

      :empty ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:undo", _params, socket) do
    case History.undo(socket.assigns.history, socket.assigns.flow) do
      {:ok, flow, history} -> {:noreply, assign(socket, flow: flow, history: history)}
      :empty -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:redo", _params, socket) do
    case History.redo(socket.assigns.history, socket.assigns.flow) do
      {:ok, flow, history} -> {:noreply, assign(socket, flow: flow, history: history)}
      :empty -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:request_layout", params, socket) do
    history = History.push(socket.assigns.history, socket.assigns.flow)
    data = Layout.prepare_layout_data(socket.assigns.flow, params)
    {:noreply, socket |> assign(history: history) |> push_event("lf:layout_data", data)}
  end

  @impl true
  def handle_event("lf:" <> _event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:lf_node_click, _node_id}, socket) do
    {:noreply, socket}
  end

  # ───────────────────────── Node Change Helpers ─────────────────────────

  defp apply_node_change(flow, %{"type" => "position", "id" => id, "position" => pos} = change) do
    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated = %{
          node
          | position: %{x: pos["x"] / 1, y: pos["y"] / 1},
            dragging: Map.get(change, "dragging", false)
        }

        %{flow | nodes: Map.put(flow.nodes, id, updated)}
    end
  end

  defp apply_node_change(flow, %{"type" => "dimensions", "id" => id} = change) do
    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated = %{
          node
          | width: Map.get(change, "width"),
            height: Map.get(change, "height"),
            measured: true
        }

        %{flow | nodes: Map.put(flow.nodes, id, updated)}
    end
  end

  defp apply_node_change(flow, %{"type" => "remove", "id" => id}) do
    State.remove_node(flow, id)
  end

  defp apply_node_change(flow, _change), do: flow

  defp maybe_push_history_for_drag(history, flow, %{"type" => "position", "id" => id} = change) do
    dragging = Map.get(change, "dragging", false)

    was_dragging =
      case Map.get(flow.nodes, id) do
        nil -> false
        node -> node.dragging
      end

    if dragging and not was_dragging do
      History.push(history, flow)
    else
      history
    end
  end

  defp maybe_push_history_for_drag(history, _flow, _change), do: history

  # ───────────────────────── Demo Flow ─────────────────────────

  defp create_demo_flow do
    nodes = [
      Node.new(
        "round-rect",
        %{x: 370, y: 30},
        %{shape: "round-rectangle", label: "round-rectangle", color: "#4A90D9"},
        type: :shape,
        class: "shape-node",
        handles: [Handle.source(:bottom, id: "s")]
      ),
      Node.new(
        "diamond",
        %{x: 415, y: 140},
        %{shape: "diamond", label: "diamond", color: "#E8A838"},
        type: :shape,
        class: "shape-node",
        handles: [
          Handle.target(:top, id: "t"),
          Handle.source(:left, id: "s-left"),
          Handle.source(:right, id: "s-right"),
          Handle.source(:bottom, id: "s-bottom")
        ]
      ),
      Node.new("circle", %{x: 255, y: 165}, %{shape: "circle", label: "circle", color: "#6A9B5A"},
        type: :shape,
        class: "shape-node",
        handles: [Handle.target(:right, id: "t")]
      ),
      Node.new(
        "hexagon",
        %{x: 600, y: 165},
        %{shape: "hexagon", label: "hexagon", color: "#C05555"},
        type: :shape,
        class: "shape-node",
        handles: [Handle.target(:left, id: "t"), Handle.source(:right, id: "s")]
      ),
      Node.new(
        "arrow-rect",
        %{x: 130, y: 340},
        %{shape: "arrow-rectangle", label: "arrow-rectangle", color: "#7B68AE"},
        type: :shape,
        class: "shape-node",
        handles: [
          Handle.target(:top, id: "t"),
          Handle.source(:right, id: "s-right"),
          Handle.source(:bottom, id: "s-bottom")
        ]
      ),
      Node.new(
        "cylinder",
        %{x: 400, y: 320},
        %{shape: "cylinder", label: "cylinder", color: "#D4A840"},
        type: :shape,
        class: "shape-node",
        handles: [
          Handle.target(:left, id: "t"),
          Handle.source(:right, id: "s-right"),
          Handle.source(:bottom, id: "s-bottom")
        ]
      ),
      Node.new(
        "rectangle",
        %{x: 790, y: 280},
        %{shape: "rectangle", label: "rectangle", color: "#4A8050"},
        type: :shape,
        class: "shape-node",
        handles: [Handle.target(:left, id: "t"), Handle.source(:bottom, id: "s")]
      ),
      Node.new(
        "parallelogram",
        %{x: 580, y: 440},
        %{shape: "parallelogram", label: "parallelogram", color: "#7B68AE"},
        type: :shape,
        class: "shape-node",
        handles: [Handle.target(:left, id: "t-left"), Handle.target(:top, id: "t-top")]
      ),
      Node.new("plus", %{x: 185, y: 500}, %{shape: "plus", label: "plus", color: "#D06038"},
        type: :shape,
        class: "shape-node",
        handles: [Handle.target(:top, id: "t"), Handle.source(:right, id: "s")]
      ),
      Node.new(
        "triangle",
        %{x: 410, y: 530},
        %{shape: "triangle", label: "triangle", color: "#5B9BD5"},
        type: :shape,
        class: "shape-node",
        handles: [Handle.target(:top, id: "t-top"), Handle.target(:left, id: "t-left")]
      )
    ]

    edges = [
      Edge.new("e1", "round-rect", "diamond",
        source_handle: "s",
        target_handle: "t",
        marker_end: %{type: :arrow}
      ),
      Edge.new("e2", "diamond", "circle",
        source_handle: "s-left",
        target_handle: "t",
        marker_end: %{type: :arrow}
      ),
      Edge.new("e3", "diamond", "hexagon",
        source_handle: "s-right",
        target_handle: "t",
        marker_end: %{type: :arrow}
      ),
      Edge.new("e4", "diamond", "arrow-rect",
        source_handle: "s-bottom",
        target_handle: "t",
        marker_end: %{type: :arrow}
      ),
      Edge.new("e5", "arrow-rect", "cylinder",
        source_handle: "s-right",
        target_handle: "t",
        marker_end: %{type: :arrow}
      ),
      Edge.new("e6", "arrow-rect", "plus",
        source_handle: "s-bottom",
        target_handle: "t",
        marker_end: %{type: :arrow}
      ),
      Edge.new("e7", "hexagon", "rectangle",
        source_handle: "s",
        target_handle: "t",
        marker_end: %{type: :arrow}
      ),
      Edge.new("e8", "cylinder", "parallelogram",
        source_handle: "s-right",
        target_handle: "t-left",
        marker_end: %{type: :arrow}
      ),
      Edge.new("e9", "cylinder", "triangle",
        source_handle: "s-bottom",
        target_handle: "t-top",
        marker_end: %{type: :arrow}
      ),
      Edge.new("e10", "rectangle", "parallelogram",
        source_handle: "s",
        target_handle: "t-top",
        marker_end: %{type: :arrow}
      ),
      Edge.new("e11", "plus", "triangle",
        source_handle: "s",
        target_handle: "t-left",
        marker_end: %{type: :arrow}
      )
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

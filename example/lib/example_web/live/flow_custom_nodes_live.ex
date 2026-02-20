defmodule ExampleWeb.FlowCustomNodesLive do
  @moduledoc """
  Demo page showcasing custom node types in LiveFlow.

  Demonstrates three ways to customize node rendering:
  1. Function components in `node_types` — simplest approach
  2. LiveComponent modules in `node_types` — for stateful nodes
  3. `node_renderer` fallback — global renderer for unmatched types
  """

  use ExampleWeb, :live_view

  alias LiveFlow.{State, Node, Edge, Handle, History, Clipboard, Serializer, Layout}
  alias LiveFlow.Validation

  @impl true
  def mount(_params, _session, socket) do
    flow = create_demo_flow()

    {:ok,
     assign(socket,
       page_title: "Custom Node Types",
       flow: flow,
       history: History.new(),
       clipboard: Clipboard.new(),
       node_types: %{
         card: &card_node/1,
         metric: &metric_node/1,
         status: &status_node/1,
         header: &header_node/1
       },
       lf_theme: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="h-screen flex flex-col">
        <div class="p-4 bg-base-200 border-b border-base-300">
          <h1 class="text-2xl font-bold">Custom Node Types</h1>
          <p class="text-sm text-base-content/70">
            Function components, LiveComponents, and node_renderer fallback
          </p>

          <div class="flex gap-2 mt-3 items-center">
            <button class="btn btn-sm btn-primary" phx-click="add_card_node">
              + Card
            </button>
            <button class="btn btn-sm btn-secondary" phx-click="add_metric_node">
              + Metric
            </button>
            <button class="btn btn-sm btn-accent" phx-click="add_status_node">
              + Status
            </button>
            <button class="btn btn-sm" phx-click="reset_flow">
              Reset
            </button>
            <button class="btn btn-sm" phx-click="fit_view">
              Fit View
            </button>
            <button
              class="btn btn-sm btn-info"
              phx-click={JS.dispatch("lf:auto-layout", to: "#custom-nodes-flow")}
            >
              Auto Layout
            </button>
            <div class="divider divider-horizontal mx-1"></div>
            <button class="btn btn-sm btn-outline" phx-click="export_json">
              Export JSON
            </button>
            <button
              class="btn btn-sm btn-outline"
              onclick="document.getElementById('import-file-input').click()"
            >
              Import JSON
            </button>
            <input
              type="file"
              id="import-file-input"
              accept=".json"
              class="hidden"
              phx-hook="FileImport"
            />
            <button
              class="btn btn-sm btn-outline"
              phx-click={JS.dispatch("lf:export-svg", to: "#custom-nodes-flow")}
            >
              SVG
            </button>
            <button
              class="btn btn-sm btn-outline"
              phx-click={JS.dispatch("lf:export-png", to: "#custom-nodes-flow")}
            >
              PNG
            </button>
            <div class="divider divider-horizontal mx-1"></div>
            <form phx-change="change_theme" class="flex items-center gap-2">
              <label class="text-sm font-medium">Theme:</label>
              <select class="select select-sm select-bordered w-40" name="theme">
                <option value="" selected={@lf_theme == nil}>auto</option>
                <option
                  :for={
                    t <-
                      ~w(light dark ocean forest sunset synthwave nord autumn cyberpunk pastel dracula coffee)
                  }
                  value={t}
                  selected={@lf_theme == t}
                >
                  {t}
                </option>
              </select>
            </form>
          </div>
        </div>

        <div class="flex-1 relative">
          <.live_component
            module={LiveFlow.Components.Flow}
            id="custom-nodes-flow"
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

        <div class="p-4 bg-base-200 border-t border-base-300">
          <div class="text-sm">
            <span class="font-medium">Nodes:</span> {map_size(@flow.nodes)} |
            <span class="font-medium">Edges:</span> {map_size(@flow.edges)} |
            <span class="font-medium">Types:</span>
            card, metric, status, header, default |
            <span class="font-medium">Undo:</span> {History.undo_count(@history)} |
            <span class="font-medium">Redo:</span> {History.redo_count(@history)} |
            <span class="font-medium">Clipboard:</span> {Clipboard.node_count(@clipboard)}
          </div>
          <div class="text-xs text-base-content/60 mt-1">
            Ctrl+C copy | Ctrl+V paste | Ctrl+X cut | Ctrl+D duplicate | Ctrl+Z undo | Ctrl+Shift+Z redo
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ===== Custom Node Function Components =====

  defp card_node(assigns) do
    description =
      Map.get(assigns.node.data, :description) || Map.get(assigns.node.data, "description", "")

    label = Map.get(assigns.node.data, :label) || Map.get(assigns.node.data, "label", "Card")
    icon = Map.get(assigns.node.data, :icon, "")
    color = Map.get(assigns.node.data, :color, "#3b82f6")

    assigns =
      assigns
      |> assign(:label, label)
      |> assign(:description, description)
      |> assign(:icon, icon)
      |> assign(:color, color)

    ~H"""
    <div style={"min-width: 200px; border-top: 3px solid #{@color}"}>
      <div style="padding: 2px 0 4px">
        <div style={"display: flex; align-items: center; gap: 6px; color: #{@color}; font-weight: 700; font-size: 14px"}>
          <span :if={@icon != ""}>{@icon}</span>
          {@label}
        </div>
        <div
          :if={@description != ""}
          style="font-size: 12px; color: var(--lf-text-muted); margin-top: 4px; line-height: 1.4"
        >
          {@description}
        </div>
      </div>
    </div>
    """
  end

  defp metric_node(assigns) do
    label = Map.get(assigns.node.data, :label, "Metric")
    value = Map.get(assigns.node.data, :value, "0")
    unit = Map.get(assigns.node.data, :unit, "")
    trend = Map.get(assigns.node.data, :trend, :neutral)
    change = Map.get(assigns.node.data, :change, "")

    {trend_color, trend_icon} =
      case trend do
        :up -> {"#22c55e", "+"}
        :down -> {"#ef4444", "-"}
        _ -> {"#94a3b8", ""}
      end

    assigns =
      assigns
      |> assign(:label, label)
      |> assign(:value, value)
      |> assign(:unit, unit)
      |> assign(:trend_color, trend_color)
      |> assign(:trend_icon, trend_icon)
      |> assign(:change, change)

    ~H"""
    <div style="min-width: 160px; text-align: center; padding: 4px 0">
      <div style="font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; color: var(--lf-text-muted); font-weight: 600">
        {@label}
      </div>
      <div style="font-size: 28px; font-weight: 800; color: var(--lf-text-primary); margin: 4px 0">
        {@value}<span
          :if={@unit != ""}
          style="font-size: 14px; font-weight: 400; color: var(--lf-text-muted)"
        >
          {@unit}
        </span>
      </div>
      <div :if={@change != ""} style={"font-size: 12px; font-weight: 600; color: #{@trend_color}"}>
        {@trend_icon}{@change}
      </div>
    </div>
    """
  end

  defp status_node(assigns) do
    label = Map.get(assigns.node.data, :label, "Status")
    status = Map.get(assigns.node.data, :status, :idle)
    detail = Map.get(assigns.node.data, :detail, "")

    {status_color, status_label} =
      case status do
        :active -> {"#22c55e", "Active"}
        :warning -> {"#f59e0b", "Warning"}
        :error -> {"#ef4444", "Error"}
        :inactive -> {"#94a3b8", "Inactive"}
        _ -> {"#3b82f6", "Idle"}
      end

    assigns =
      assigns
      |> assign(:label, label)
      |> assign(:status_color, status_color)
      |> assign(:status_label, status_label)
      |> assign(:detail, detail)

    ~H"""
    <div style="min-width: 150px">
      <div style="display: flex; align-items: center; gap: 8px">
        <div
          style={"width: 10px; height: 10px; border-radius: 50%; background: #{@status_color}; box-shadow: 0 0 6px #{@status_color}80"}
          }
        >
        </div>
        <div>
          <div style="font-weight: 600; font-size: 13px; color: var(--lf-text-primary)">
            {@label}
          </div>
          <div style={"font-size: 11px; font-weight: 500; color: #{@status_color}"}>
            {@status_label}
          </div>
        </div>
      </div>
      <div
        :if={@detail != ""}
        style="font-size: 11px; color: var(--lf-text-muted); margin-top: 6px; padding-top: 6px; border-top: 1px solid var(--lf-border-secondary, #ddd)"
      >
        {@detail}
      </div>
    </div>
    """
  end

  defp header_node(assigns) do
    label = Map.get(assigns.node.data, :label, "Header")
    subtitle = Map.get(assigns.node.data, :subtitle, "")
    color = Map.get(assigns.node.data, :color, "#6366f1")

    assigns =
      assigns
      |> assign(:label, label)
      |> assign(:subtitle, subtitle)
      |> assign(:color, color)

    ~H"""
    <div style={"min-width: 180px; background: #{@color}; margin: -10px -15px; padding: 12px 16px; border-radius: var(--lf-node-border-radius)"}>
      <div style="font-size: 16px; font-weight: 700; color: white">{@label}</div>
      <div
        :if={@subtitle != ""}
        style="font-size: 12px; color: rgba(255,255,255,0.8); margin-top: 2px"
      >
        {@subtitle}
      </div>
    </div>
    """
  end

  # ===== Event Handlers =====

  @impl true
  def handle_event("add_card_node", _params, socket) do
    n = map_size(socket.assigns.flow.nodes) + 1

    node =
      Node.new(
        "card-#{n}",
        %{x: 100 + rem(n, 4) * 200, y: 100 + div(n, 4) * 120},
        %{label: "Card #{n}", description: "A new card node", color: "#3b82f6"},
        type: :card,
        handles: [Handle.target(:left), Handle.source(:right)]
      )

    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.add_node(socket.assigns.flow, node)
    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("add_metric_node", _params, socket) do
    n = map_size(socket.assigns.flow.nodes) + 1

    node =
      Node.new(
        "metric-#{n}",
        %{x: 100 + rem(n, 4) * 200, y: 100 + div(n, 4) * 120},
        %{
          label: "Metric #{n}",
          value: "#{:rand.uniform(999)}",
          unit: "ms",
          trend: :up,
          change: "12%"
        },
        type: :metric,
        handles: [Handle.target(:left), Handle.source(:right)]
      )

    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.add_node(socket.assigns.flow, node)
    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("add_status_node", _params, socket) do
    n = map_size(socket.assigns.flow.nodes) + 1
    statuses = [:active, :warning, :error, :idle]

    node =
      Node.new(
        "status-#{n}",
        %{x: 100 + rem(n, 4) * 200, y: 100 + div(n, 4) * 120},
        %{label: "Service #{n}", status: Enum.random(statuses), detail: "port 443"},
        type: :status,
        handles: [Handle.target(:left), Handle.source(:right)]
      )

    history = History.push(socket.assigns.history, socket.assigns.flow)
    flow = State.add_node(socket.assigns.flow, node)
    {:noreply, assign(socket, flow: flow, history: history)}
  end

  @impl true
  def handle_event("reset_flow", _params, socket) do
    {:noreply,
     assign(socket, flow: create_demo_flow(), history: History.new(), clipboard: Clipboard.new())}
  end

  @impl true
  def handle_event("export_json", _params, socket) do
    json = Serializer.to_json(socket.assigns.flow)

    {:noreply,
     push_event(socket, "lf:download_file", %{
       content: json,
       filename: "flow.json",
       type: "application/json"
     })}
  end

  @impl true
  def handle_event("export_svg", _params, socket) do
    {:noreply, push_event(socket, "lf:export_svg", %{})}
  end

  @impl true
  def handle_event("export_png", _params, socket) do
    {:noreply, push_event(socket, "lf:export_png", %{})}
  end

  @impl true
  def handle_event("import_json", %{"content" => content}, socket) do
    case Serializer.from_json(content) do
      {:ok, flow} ->
        history = History.push(socket.assigns.history, socket.assigns.flow)
        {:noreply, assign(socket, flow: flow, history: history)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Import failed: #{reason}")}
    end
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

  # ===== Private Helpers =====

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

  defp create_demo_flow do
    nodes = [
      # Header node (function component)
      Node.new(
        "header-1",
        %{x: 50, y: 20},
        %{label: "Data Pipeline", subtitle: "Real-time ETL", color: "#6366f1"},
        type: :header,
        handles: [Handle.source(:bottom)]
      ),

      # Card nodes (function component)
      Node.new(
        "card-1",
        %{x: 30, y: 160},
        %{
          label: "API Gateway",
          description: "Receives incoming webhook events and validates payload schema",
          icon: "~",
          color: "#3b82f6"
        },
        type: :card,
        handles: [Handle.target(:top), Handle.source(:right)]
      ),
      Node.new(
        "card-2",
        %{x: 30, y: 340},
        %{
          label: "Message Queue",
          description: "Buffers events for downstream processing",
          icon: "~",
          color: "#8b5cf6"
        },
        type: :card,
        handles: [Handle.target(:top), Handle.source(:right)]
      ),

      # Metric nodes (function component)
      Node.new(
        "metric-1",
        %{x: 340, y: 140},
        %{label: "Throughput", value: "1,247", unit: "/s", trend: :up, change: "12%"},
        type: :metric,
        handles: [Handle.target(:left), Handle.source(:right)]
      ),
      Node.new(
        "metric-2",
        %{x: 340, y: 320},
        %{label: "Latency", value: "23", unit: "ms", trend: :down, change: "8%"},
        type: :metric,
        handles: [Handle.target(:left), Handle.source(:right)]
      ),

      # Status nodes (function component)
      Node.new(
        "status-1",
        %{x: 600, y: 140},
        %{label: "Database", status: :active, detail: "PostgreSQL 16 - 3 replicas"},
        type: :status,
        handles: [Handle.target(:left), Handle.source(:right)]
      ),
      Node.new(
        "status-2",
        %{x: 600, y: 320},
        %{label: "Cache Layer", status: :warning, detail: "Redis - 87% memory"},
        type: :status,
        handles: [Handle.target(:left)]
      ),

      # Default node (no custom type — uses built-in)
      Node.new("output", %{x: 870, y: 220}, %{label: "Output"}, handles: [Handle.target(:left)])
    ]

    edges = [
      Edge.new("e1", "header-1", "card-1",
        style: %{"stroke" => "#6366f1"},
        marker_end: %{type: :arrow, color: "#6366f1"}
      ),
      Edge.new("e2", "card-1", "metric-1", marker_end: %{type: :arrow}),
      Edge.new("e3", "card-1", "card-2",
        style: %{"stroke" => "#8b5cf6"},
        marker_end: %{type: :arrow, color: "#8b5cf6"}
      ),
      Edge.new("e4", "card-2", "metric-2", marker_end: %{type: :arrow}),
      Edge.new("e5", "metric-1", "status-1", marker_end: %{type: :arrow}),
      Edge.new("e6", "metric-2", "status-2", marker_end: %{type: :arrow}),
      Edge.new("e7", "status-1", "output", marker_end: %{type: :arrow})
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

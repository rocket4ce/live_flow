defmodule FlotasWeb.FlowFormsLive do
  @moduledoc """
  Demo page for LiveFlow with complex node content (forms, conditions, actions).
  """

  use FlotasWeb, :live_view

  alias LiveFlow.{State, Node, Edge, Handle, Layout}

  alias FlotasWeb.FlowForms.{FormNode, ConditionNode, ActionNode}

  @impl true
  def mount(_params, _session, socket) do
    flow = create_demo_flow()

    {:ok,
     assign(socket,
       page_title: "Flow Forms Demo",
       flow: flow,
       node_types: %{
         form: FormNode,
         condition: ConditionNode,
         action: ActionNode
       }
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="h-screen flex flex-col">
        <div class="p-4 bg-base-200 border-b border-base-300">
          <h1 class="text-2xl font-bold">Flow Forms Demo</h1>
          <p class="text-sm text-base-content/70">
            Complex node content: forms, conditions, and actions
          </p>

          <div class="flex gap-2 mt-3">
            <button class="btn btn-sm btn-primary" phx-click="reset_flow">
              Reset
            </button>
            <button class="btn btn-sm" phx-click="fit_view">
              Fit View
            </button>
            <button class="btn btn-sm btn-accent" phx-click={JS.dispatch("lf:auto-layout", to: "#forms-flow")}>
              Auto Layout
            </button>
          </div>
        </div>

        <div class="flex-1 relative">
          <.live_component
            module={LiveFlow.Components.Flow}
            id="forms-flow"
            flow={@flow}
            opts={
              %{
                controls: true,
                minimap: true,
                background: :dots,
                fit_view_on_init: true,
                snap_to_grid: true,
                snap_grid: {20, 20}
              }
            }
            node_types={@node_types}
          />
        </div>

        <div class="p-4 bg-base-200 border-t border-base-300">
          <div class="text-sm">
            <span class="font-medium">Nodes:</span> {map_size(@flow.nodes)} |
            <span class="font-medium">Edges:</span> {map_size(@flow.edges)} |
            <span class="font-medium">Selected:</span> {MapSet.size(@flow.selected_nodes)}
          </div>
          <div class="text-xs text-base-content/60 mt-1">
            Drag nodes to move | Scroll to zoom | Interact with form fields inside nodes
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("reset_flow", _params, socket) do
    flow = create_demo_flow()
    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("fit_view", _params, socket) do
    {:noreply, push_event(socket, "lf:fit_view", %{padding: 0.1, duration: 200})}
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
  def handle_event("lf:node_change", %{"changes" => changes}, socket) do
    flow =
      Enum.reduce(changes, socket.assigns.flow, fn change, acc ->
        apply_node_change(acc, change)
      end)

    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:edge_change", %{"changes" => changes}, socket) do
    flow =
      Enum.reduce(changes, socket.assigns.flow, fn
        %{"type" => "remove", "id" => id}, acc -> State.remove_edge(acc, id)
        _change, acc -> acc
      end)

    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:connect_end", params, socket) do
    source = params["source"]
    target = params["target"]

    if source && target && source != target do
      edge_id = "e-#{System.unique_integer([:positive])}"

      edge =
        Edge.new(edge_id, source, target,
          source_handle: params["source_handle"],
          target_handle: params["target_handle"]
        )

      flow = State.add_edge(socket.assigns.flow, edge)
      {:noreply, assign(socket, flow: flow)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("lf:delete_selected", _params, socket) do
    flow = State.delete_selected(socket.assigns.flow)
    {:noreply, assign(socket, flow: flow)}
  end

  @impl true
  def handle_event("lf:request_layout", params, socket) do
    data = Layout.prepare_layout_data(socket.assigns.flow, params)
    {:noreply, push_event(socket, "lf:layout_data", data)}
  end

  # Catch-all for other lf: events
  @impl true
  def handle_event("lf:" <> _event, _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:lf_node_click, _node_id}, socket) do
    {:noreply, socket}
  end

  # Node change helpers

  defp apply_node_change(flow, %{"type" => "position", "id" => id, "position" => pos} = change) do
    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated_node = %{
          node
          | position: %{x: pos["x"] / 1, y: pos["y"] / 1},
            dragging: Map.get(change, "dragging", false)
        }

        %{flow | nodes: Map.put(flow.nodes, id, updated_node)}
    end
  end

  defp apply_node_change(flow, %{"type" => "dimensions", "id" => id} = change) do
    case Map.get(flow.nodes, id) do
      nil ->
        flow

      node ->
        updated_node = %{
          node
          | width: Map.get(change, "width"),
            height: Map.get(change, "height"),
            measured: true
        }

        %{flow | nodes: Map.put(flow.nodes, id, updated_node)}
    end
  end

  defp apply_node_change(flow, %{"type" => "remove", "id" => id}) do
    State.remove_node(flow, id)
  end

  defp apply_node_change(flow, _change), do: flow

  # Demo flow

  defp create_demo_flow do
    nodes = [
      # Trigger node (default type)
      Node.new("trigger", %{x: 50, y: 200}, %{label: "New Lead"},
        type: :default,
        handles: [Handle.source(:right)]
      ),

      # Contact form node
      Node.new(
        "contact-form",
        %{x: 250, y: 120},
        %{
          title: "Contact Form",
          color: "#3b82f6",
          fields: [
            %{name: "name", label: "Name", type: "text", value: "John Doe"},
            %{name: "email", label: "Email", type: "text", value: "john@example.com"},
            %{
              name: "status",
              label: "Status",
              type: "select",
              options: ["Lead", "VIP", "Partner"],
              value: "VIP"
            }
          ]
        },
        type: :form,
        handles: [Handle.target(:left), Handle.source(:right)]
      ),

      # Condition node
      Node.new(
        "condition-1",
        %{x: 550, y: 180},
        %{
          condition: "status == VIP?",
          description: "Check lead status",
          color: "#f59e0b"
        },
        type: :condition,
        handles: [
          Handle.target(:left),
          Handle.source(:right, id: "yes"),
          Handle.source(:bottom, id: "no")
        ]
      ),

      # Action: send email
      Node.new(
        "action-email",
        %{x: 820, y: 120},
        %{
          action: "send_email",
          label: "Send Welcome Email",
          icon: :email,
          color: "#8b5cf6",
          params: %{to: "{{email}}", subject: "Welcome VIP!"}
        },
        type: :action,
        handles: [Handle.target(:left), Handle.source(:right)]
      ),

      # Action: save to DB
      Node.new(
        "action-db",
        %{x: 820, y: 330},
        %{
          action: "save_to_db",
          label: "Save to Database",
          icon: :database,
          color: "#06b6d4",
          params: %{table: "leads", status: "pending"}
        },
        type: :action,
        handles: [Handle.target(:left), Handle.source(:right)]
      ),

      # End nodes
      Node.new("end-1", %{x: 1080, y: 150}, %{label: "Done (VIP)"},
        type: :default,
        handles: [Handle.target(:left)]
      ),
      Node.new("end-2", %{x: 1080, y: 360}, %{label: "Done (Standard)"},
        type: :default,
        handles: [Handle.target(:left)]
      )
    ]

    edges = [
      Edge.new("e1", "trigger", "contact-form",
        marker_end: %{type: :arrow_closed, color: "#64748b"}
      ),
      Edge.new("e2", "contact-form", "condition-1",
        marker_end: %{type: :arrow_closed, color: "#64748b"}
      ),
      Edge.new("e3", "condition-1", "action-email",
        source_handle: "yes",
        label: "Yes",
        style: %{"stroke" => "#22c55e"},
        marker_end: %{type: :arrow_closed, color: "#22c55e"}
      ),
      Edge.new("e4", "condition-1", "action-db",
        source_handle: "no",
        label: "No",
        style: %{"stroke" => "#ef4444"},
        marker_end: %{type: :arrow_closed, color: "#ef4444"}
      ),
      Edge.new("e5", "action-email", "end-1",
        marker_end: %{type: :arrow_closed, color: "#64748b"}
      ),
      Edge.new("e6", "action-db", "end-2", marker_end: %{type: :arrow_closed, color: "#64748b"})
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

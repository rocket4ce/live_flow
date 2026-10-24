defmodule FlowExampleWeb.EdgesLive do
  @moduledoc """
  Edge types and path options. Paths are computed on the server and mirrored
  by the client while nodes move, so step/smoothstep edges keep their shape.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, Handle, Node, State}

  @defaults %{
    "type" => "smoothstep",
    "step_position" => "0.5",
    "border_radius" => "8",
    "offset" => "20",
    "curvature" => "0.25",
    "animated" => "false",
    "labels" => "true",
    "marker" => "arrow_closed",
    "reconnectable" => "true",
    "floating" => "false"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Edges")
     |> FlowEvents.assign_flow(build_flow(@defaults))
     |> assign(:form, to_form(@defaults, as: :opts))
     |> assign(:params, @defaults)
     |> assign(:edge_opts, edge_opts(@defaults))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      active={:edges}
      title="Edges"
      badge="step_position"
      subtitle="Bezier, straight, step and smoothstep paths. Smoothstep and step are a port of xyflow's getSmoothStepPath, identical on the server and in the browser."
    >
      <.canvas_layout>
        <.live_component
          module={LiveFlow.Components.Flow}
          id="edges-flow"
          flow={@flow}
          node_types={FlowNodes.types()}
          opts={
            %{
              background: :lines,
              background_gap: 32,
              controls: true,
              fit_view_on_init: true,
              connection_line_type: String.to_existing_atom(@params["type"])
            }
          }
        />

        <:sidebar>
          <.form for={@form} id="edge-options" phx-change="update_opts">
            <.option_group title="Path">
              <.input
                field={@form[:type]}
                type="select"
                label="Edge type"
                class={select_class()}
                options={[
                  {"Smoothstep", "smoothstep"},
                  {"Step", "step"},
                  {"Bezier", "bezier"},
                  {"Straight", "straight"}
                ]}
              />
              <%= if @params["type"] in ["step", "smoothstep"] do %>
                <.range
                  field={@form[:step_position]}
                  label="step_position"
                  min="0"
                  max="1"
                  step="0.05"
                />
                <.range field={@form[:offset]} label="offset" min="0" max="60" />
                <.range
                  :if={@params["type"] == "smoothstep"}
                  field={@form[:border_radius]}
                  label="border_radius"
                  min="0"
                  max="30"
                />
              <% end %>
              <.range
                :if={@params["type"] == "bezier"}
                field={@form[:curvature]}
                label="curvature"
                min="0"
                max="1"
                step="0.05"
              />
              <.hint>
                <code class="font-mono">step_position</code>
                moves the bend between the source (0) and the target (1). Drag the nodes: the edges keep their shape while moving.
              </.hint>
            </.option_group>

            <.option_group title="Decoration">
              <.input
                field={@form[:animated]}
                type="checkbox"
                label="Animated"
                class={switch_class()}
              />
              <.input field={@form[:labels]} type="checkbox" label="Labels" class={switch_class()} />
              <.input
                field={@form[:marker]}
                type="select"
                label="End marker"
                class={select_class()}
                options={[{"Closed arrow", "arrow_closed"}, {"Arrow", "arrow"}, {"None", "none"}]}
              />
            </.option_group>

            <.option_group title="Behaviour">
              <.input
                field={@form[:reconnectable]}
                type="checkbox"
                label="Reconnectable"
                class={switch_class()}
              />
              <.input
                field={@form[:floating]}
                type="checkbox"
                label="Floating ends"
                class={switch_class()}
              />
              <.hint>
                Select an edge and drag one of its ends to another handle. Double-click a label to edit it.
              </.hint>
            </.option_group>
          </.form>

          <.option_group title="Event log">
            <.event_log entries={@event_log} />
          </.option_group>
        </:sidebar>
      </.canvas_layout>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("update_opts", %{"opts" => params}, socket) do
    params = Map.merge(@defaults, params)
    opts = edge_opts(params)

    # Keep positions/selection, restyle every edge
    flow = socket.assigns.flow

    edges =
      Map.new(flow.edges, fn {id, edge} ->
        label = if params["labels"] == "true", do: edge.data[:label]
        {id, struct(edge, Keyword.put(opts, :label, label))}
      end)

    {:noreply,
     socket
     |> assign(:flow, %{flow | edges: edges})
     |> assign(:params, params)
     |> assign(:edge_opts, opts)
     |> assign(:form, to_form(params, as: :opts))}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _node_id}, socket), do: {:noreply, socket}

  # Options applied to every edge (also used for new connections)
  defp edge_opts(params) do
    type = String.to_existing_atom(params["type"])

    path_options =
      case type do
        :bezier ->
          %{curvature: float(params["curvature"])}

        :straight ->
          %{}

        _ ->
          %{
            step_position: float(params["step_position"]),
            offset: float(params["offset"]),
            border_radius: float(params["border_radius"])
          }
      end

    floating = params["floating"] == "true"

    [
      type: type,
      path_options: path_options,
      animated: params["animated"] == "true",
      reconnectable: params["reconnectable"] == "true",
      source_floating: floating,
      target_floating: floating,
      marker_end:
        if(params["marker"] != "none", do: %{type: String.to_existing_atom(params["marker"])})
    ]
  end

  defp float(value) do
    {number, _} = Float.parse(value)
    number
  end

  defp build_flow(params) do
    opts = edge_opts(params)

    hub =
      Node.new(
        "hub",
        %{x: 420, y: 220},
        %{title: "Hub", subtitle: "4 sides", icon: "hero-cpu-chip", color: :violet},
        type: :card,
        handles: [
          Handle.source(:top, id: "top"),
          Handle.source(:right, id: "right"),
          Handle.source(:bottom, id: "bottom"),
          Handle.source(:left, id: "left")
        ]
      )

    nodes = [
      hub,
      Samples.card("north", 120, 0, "North", "target on bottom", "hero-arrow-up", :sky,
        outputs: false
      )
      |> with_handles([Handle.target(:bottom)]),
      Samples.card("east", 820, 60, "East", "target on left", "hero-arrow-right", :emerald,
        outputs: false
      ),
      Samples.card("south", 640, 460, "South", "target on top", "hero-arrow-down", :amber,
        outputs: false
      )
      |> with_handles([Handle.target(:top)]),
      Samples.card("west", 20, 340, "West", "target on right", "hero-arrow-left", :rose,
        outputs: false
      )
      |> with_handles([Handle.target(:right)]),
      Samples.card(
        "loop",
        820,
        300,
        "Same side",
        "right → right",
        "hero-arrow-uturn-right",
        :slate,
        outputs: false
      )
      |> with_handles([Handle.target(:right)])
    ]

    edges = [
      edge("hub-north", "top", "north", "north", opts),
      edge("hub-east", "right", "east", "east", opts),
      edge("hub-south", "bottom", "south", "south", opts),
      edge("hub-west", "left", "west", "west", opts),
      edge("hub-loop", "right", "loop", "same side", opts)
    ]

    State.new(nodes: nodes, edges: edges)
  end

  defp with_handles(node, handles), do: %{node | handles: handles}

  defp edge(id, source_handle, target, label, opts) do
    Edge.new(
      id,
      "hub",
      target,
      Keyword.merge(opts, source_handle: source_handle, label: label, data: %{label: label})
    )
  end
end

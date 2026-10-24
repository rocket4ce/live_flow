defmodule FlowExampleWeb.ResizingLive do
  @moduledoc """
  NodeResizer: min/max sizes, aspect ratio, node extent and the paired
  resize start/end changes.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.FlowEvents
  alias LiveFlow.{Edge, Handle, Node, State}
  alias LiveFlow.Components.NodeResizer

  @extent {{-40, -40}, {960, 520}}

  @impl true
  def mount(_params, _session, socket) do
    params = %{"node_extent" => "false", "snap_to_grid" => "false"}

    {:ok,
     socket
     |> assign(:page_title, "Resizing")
     |> assign(:extent, @extent)
     |> FlowEvents.assign_flow(build_flow())
     |> assign(:form, to_form(params, as: :opts))
     |> assign(:params, params)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      active={:resizing}
      title="Resizing"
      badge="xyflow 12.12"
      subtitle="Drag the corners and sides of a selected node. Every resize sends a start change (resizing: true) and always a matching end change, even when you cancel with Esc."
    >
      <.canvas_layout>
        <.live_component
          module={LiveFlow.Components.Flow}
          id="resizing-flow"
          flow={@flow}
          node_types={%{resizable: &resizable_node/1}}
          opts={
            %{
              background: :dots,
              controls: true,
              fit_view_on_init: true,
              snap_to_grid: @params["snap_to_grid"] == "true",
              snap_grid: {20, 20},
              node_extent: if(@params["node_extent"] == "true", do: @extent)
            }
          }
        />

        <:sidebar>
          <.form for={@form} id="resizing-options" phx-change="update_opts">
            <.option_group title="Constraints" tag="new">
              <.input
                field={@form[:node_extent]}
                type="checkbox"
                label="node_extent (960 × 560 area)"
                class={switch_class()}
              />
              <.input
                field={@form[:snap_to_grid]}
                type="checkbox"
                label="Snap size to grid"
                class={switch_class()}
              />
              <.hint>
                With an extent, nodes can be neither dragged nor resized outside of it.
              </.hint>
            </.option_group>
          </.form>

          <.option_group title="Nodes">
            <dl class="space-y-2 text-xs">
              <div
                :for={node <- Enum.sort_by(Map.values(@flow.nodes), & &1.id)}
                class="flex justify-between"
              >
                <dt class="text-base-content/70">{node.data.title}</dt>
                <dd class="font-mono text-base-content/50">
                  {round(node.width || 0)} × {round(node.height || 0)}
                  <span :if={node.resizing} class="text-primary">resizing</span>
                </dd>
              </div>
            </dl>
          </.option_group>

          <.option_group title="Event log">
            <.event_log entries={@event_log} />
          </.option_group>
        </:sidebar>
      </.canvas_layout>
    </Layouts.app>
    """
  end

  attr :node, :map, required: true

  defp resizable_node(assigns) do
    ~H"""
    <NodeResizer.node_resizer
      node_id={@node.id}
      is_visible={@node.selected}
      min_width={@node.data.min_width}
      min_height={@node.data.min_height}
      max_width={@node.data[:max_width]}
      max_height={@node.data[:max_height]}
      keep_aspect_ratio={@node.data[:keep_aspect_ratio] || false}
    />
    <div class="flex h-full flex-col justify-between gap-2">
      <div>
        <p class="text-[13px] font-semibold" style="color: var(--lf-text-primary)">
          {@node.data.title}
        </p>
        <p class="text-[11px]" style="color: var(--lf-text-secondary)">{@node.data.hint}</p>
      </div>
      <p class="font-mono text-[11px]" style="color: var(--lf-text-secondary)">
        {round(@node.width || 0)} × {round(@node.height || 0)}
      </p>
    </div>
    """
  end

  @impl true
  def handle_event("update_opts", %{"opts" => params}, socket) do
    {:noreply, socket |> assign(:params, params) |> assign(:form, to_form(params, as: :opts))}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _node_id}, socket), do: {:noreply, socket}

  defp build_flow do
    nodes = [
      node("free", 0, 40, 220, 120, %{
        title: "Free",
        hint: "min 120 × 60",
        min_width: 120,
        min_height: 60
      }),
      node("ratio", 320, 0, 200, 200, %{
        title: "Aspect ratio",
        hint: "keep_aspect_ratio",
        min_width: 80,
        min_height: 80,
        keep_aspect_ratio: true
      }),
      node("bounded", 640, 60, 220, 140, %{
        title: "Bounded",
        hint: "max 360 × 240",
        min_width: 140,
        min_height: 80,
        max_width: 360,
        max_height: 240
      })
    ]

    edges = [
      Edge.new("free-ratio", "free", "ratio", type: :smoothstep),
      Edge.new("ratio-bounded", "ratio", "bounded", type: :smoothstep)
    ]

    State.new(nodes: nodes, edges: edges)
  end

  defp node(id, x, y, width, height, data) do
    Node.new(id, %{x: x, y: y}, data,
      type: :resizable,
      resizable: true,
      width: width,
      height: height,
      handles: [Handle.target(:left), Handle.source(:right)]
    )
  end
end

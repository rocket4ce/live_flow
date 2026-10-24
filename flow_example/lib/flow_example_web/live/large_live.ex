defmodule FlowExampleWeb.LargeLive do
  @moduledoc """
  Large flows with server-side viewport culling (virtualization).
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.FlowEvents

  @impl true
  def mount(_params, _session, socket) do
    params = %{"count" => "1000", "virtualization" => "true"}

    {:ok,
     socket
     |> assign(:page_title, "Large flows")
     |> assign(:form, to_form(params, as: :opts))
     |> assign(:params, params)
     |> FlowEvents.assign_flow(Samples.grid(1000))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      active={:large}
      title="Large flows"
      subtitle="With virtualization only the nodes inside the viewport (plus a margin) are rendered. Pan around or drag the minimap viewport."
    >
      <.canvas_layout>
        <.live_component
          module={LiveFlow.Components.Flow}
          id="large-flow"
          flow={@flow}
          opts={
            %{
              virtualization: @params["virtualization"] == "true",
              minimap: true,
              minimap_pannable: true,
              minimap_zoomable: true,
              controls: true,
              background: :dots,
              min_zoom: 0.05
            }
          }
        />

        <:sidebar>
          <.form for={@form} id="large-options" phx-change="update_opts">
            <.option_group title="Size">
              <.input
                field={@form[:count]}
                type="select"
                label="Nodes"
                class={select_class()}
                options={[{"200", "200"}, {"1,000", "1000"}, {"2,500", "2500"}, {"5,000", "5000"}]}
              />
              <.input
                field={@form[:virtualization]}
                type="checkbox"
                label="Virtualization"
                class={switch_class()}
              />
            </.option_group>
          </.form>

          <.option_group title="Stats">
            <dl class="grid grid-cols-2 gap-2 text-xs">
              <div class="rounded-lg bg-base-200 p-2">
                <dt class="text-base-content/50">Nodes</dt>
                <dd class="font-mono text-base">{map_size(@flow.nodes)}</dd>
              </div>
              <div class="rounded-lg bg-base-200 p-2">
                <dt class="text-base-content/50">Edges</dt>
                <dd class="font-mono text-base">{map_size(@flow.edges)}</dd>
              </div>
            </dl>
            <.hint>
              Without virtualization every node is in the DOM. Culling is pure Elixir
              (<code>LiveFlow.Viewport.Culling</code>) and caps the rendered nodes at 500.
            </.hint>
          </.option_group>
        </:sidebar>
      </.canvas_layout>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("update_opts", %{"opts" => params}, socket) do
    socket = assign(socket, params: params, form: to_form(params, as: :opts))

    socket =
      if params["count"] != to_string(map_size(socket.assigns.flow.nodes)) do
        FlowEvents.assign_flow(socket, Samples.grid(String.to_integer(params["count"])))
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _node_id}, socket), do: {:noreply, socket}
end

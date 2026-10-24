defmodule FlowExampleWeb.PlaygroundLive do
  @moduledoc """
  A complete editor: add nodes, undo/redo, clipboard, auto-layout,
  JSON/SVG/PNG export, JSON import, themes and overlays.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{FlowEvents, FlowNodes}
  alias LiveFlow.{History, Serializer, State, Viewport}

  @themes ~w(auto light dark ocean forest sunset synthwave nord dracula cyberpunk coffee)

  @defaults %{
    "theme" => "auto",
    "background" => "dots",
    "minimap" => "true",
    "controls" => "true",
    "helper_lines" => "true",
    "snap_to_grid" => "false"
  }

  @palette [
    {"Transform", "Map & filter fields", "hero-adjustments-horizontal", :violet},
    {"HTTP request", "GET api.example.com", "hero-globe-alt", :sky},
    {"Delay", "Wait 5 minutes", "hero-clock", :amber},
    {"Condition", "amount > 100", "hero-funnel", :rose},
    {"Database", "Insert into orders", "hero-circle-stack", :emerald}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Playground")
     |> FlowEvents.assign_flow(Samples.pipeline())
     |> assign(:themes, @themes)
     |> assign_options(@defaults)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      active={:playground}
      title="Playground"
      subtitle="A full editor built from the LiveFlow primitives. The parent LiveView owns the state; history, clipboard and layout are plain Elixir modules."
    >
      <:actions>
        <.action icon="hero-plus" variant={:primary} phx-click="add_node">Add node</.action>
        <.action
          icon="hero-arrow-uturn-left"
          phx-click="lf:undo"
          disabled={!History.can_undo?(@history)}
          title="Undo (⌘Z)"
        >
          Undo
        </.action>
        <.action
          icon="hero-arrow-uturn-right"
          phx-click="lf:redo"
          disabled={!History.can_redo?(@history)}
          title="Redo (⌘⇧Z)"
        >
          Redo
        </.action>
        <.action icon="hero-arrow-path" phx-click="reset">Reset</.action>
      </:actions>

      <.canvas_layout>
        <.live_component
          module={LiveFlow.Components.Flow}
          id="playground-flow"
          flow={@flow}
          node_types={FlowNodes.types()}
          opts={@flow_opts}
        />

        <:sidebar>
          <.form for={@form} id="playground-options" phx-change="update_opts">
            <.option_group title="Appearance">
              <.input
                field={@form[:theme]}
                type="select"
                label="Flow theme"
                class={select_class()}
                options={Enum.map(@themes, &{String.capitalize(&1), &1})}
              />
              <.input
                field={@form[:background]}
                type="select"
                label="Background"
                class={select_class()}
                options={[{"Dots", "dots"}, {"Lines", "lines"}, {"Cross", "cross"}, {"None", "none"}]}
              />
              <.input field={@form[:minimap]} type="checkbox" label="Minimap" class={switch_class()} />
              <.input
                field={@form[:controls]}
                type="checkbox"
                label="Controls"
                class={switch_class()}
              />
              <.input
                field={@form[:helper_lines]}
                type="checkbox"
                label="Helper lines"
                class={switch_class()}
              />
              <.input
                field={@form[:snap_to_grid]}
                type="checkbox"
                label="Snap to grid"
                class={switch_class()}
              />
            </.option_group>
          </.form>

          <.option_group title="Layout">
            <div class="grid grid-cols-2 gap-2">
              <.action icon="hero-arrow-down" phx-click="auto_layout" phx-value-direction="DOWN">
                Vertical
              </.action>
              <.action icon="hero-arrow-right" phx-click="auto_layout" phx-value-direction="RIGHT">
                Horizontal
              </.action>
            </div>
            <.hint>Auto-layout runs ELK in the browser with the measured node sizes.</.hint>
          </.option_group>

          <.option_group title="Import / export">
            <div class="grid grid-cols-3 gap-2">
              <.action phx-click="export_json">JSON</.action>
              <.action phx-click={JS.dispatch("lf:export-svg", to: "#playground-flow")}>SVG</.action>
              <.action phx-click={JS.dispatch("lf:export-png", to: "#playground-flow")}>PNG</.action>
            </div>
            <label class="mt-2 flex cursor-pointer items-center justify-center gap-2 rounded-lg border border-dashed border-base-300 px-3 py-2 text-sm text-base-content/70 transition-colors hover:border-primary hover:text-primary">
              <.icon name="hero-arrow-up-tray" class="size-4" /> Import JSON
              <input
                id="playground-import"
                type="file"
                accept="application/json,.json"
                class="hidden"
                phx-hook="FileImport"
              />
            </label>
          </.option_group>

          <.option_group title="Shortcuts">
            <div class="grid grid-cols-[auto_1fr] items-center gap-x-3 gap-y-1.5 text-xs text-base-content/70">
              <span><.kbd>⌘ C</.kbd>
              
              <.kbd>⌘ V</.kbd></span><span>Copy / paste</span>
              <span><.kbd>⌘ D</.kbd></span><span>Duplicate</span>
              <span><.kbd>⌘ Z</.kbd></span><span>Undo</span>
              <span><.kbd>⌫</.kbd></span><span>Delete selection</span>
              <span><.kbd>?</.kbd></span><span>All shortcuts</span>
            </div>
          </.option_group>

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
    {:noreply, assign_options(socket, Map.merge(@defaults, params))}
  end

  def handle_event("add_node", _params, socket) do
    flow = socket.assigns.flow
    count = map_size(flow.nodes)
    {title, subtitle, icon, color} = Enum.at(@palette, rem(count, length(@palette)))

    # Drop the node at the center of the visible area
    {x, y} = viewport_center(flow.viewport)
    id = "node-#{System.unique_integer([:positive])}"

    node =
      Samples.card(
        id,
        x - 112 + rem(count, 4) * 12,
        y - 29 + rem(count, 4) * 12,
        title,
        subtitle,
        icon,
        color
      )

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, flow |> State.add_node(node) |> State.select_nodes([id]))
     |> FlowEvents.log("add_node", %{"id" => id})}
  end

  def handle_event("auto_layout", %{"direction" => direction}, socket) do
    FlowEvents.handle_event("lf:request_layout", %{"direction" => direction}, socket)
  end

  def handle_event("export_json", _params, socket) do
    {:noreply,
     push_event(socket, "lf:download_file", %{
       content: Serializer.to_json(socket.assigns.flow),
       filename: "flow.json",
       type: "application/json"
     })}
  end

  def handle_event("import_json", %{"content" => content}, socket) do
    case Serializer.from_json(content) do
      {:ok, flow} ->
        send_update(LiveFlow.Components.Flow, id: "playground-flow", fit_view: true)

        {:noreply,
         socket
         |> FlowEvents.snapshot()
         |> assign(:flow, flow)
         |> put_flash(:info, "Flow imported")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Import failed: #{reason}")}
    end
  end

  def handle_event("reset", _params, socket) do
    send_update(LiveFlow.Components.Flow, id: "playground-flow", fit_view: true)
    {:noreply, FlowEvents.assign_flow(socket, Samples.pipeline())}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _node_id}, socket), do: {:noreply, socket}

  defp assign_options(socket, params) do
    socket
    |> assign(:form, to_form(params, as: :opts))
    |> assign(:flow_opts, %{
      fit_view_on_init: true,
      theme: if(params["theme"] in (@themes -- ["auto"]), do: params["theme"]),
      background: background(params["background"]),
      background_gap: 24,
      minimap: params["minimap"] == "true",
      minimap_pannable: true,
      minimap_zoomable: true,
      controls: params["controls"] == "true",
      helper_lines: params["helper_lines"] == "true",
      snap_to_grid: params["snap_to_grid"] == "true",
      snap_grid: {24, 24}
    })
  end

  defp background("lines"), do: :lines
  defp background("cross"), do: :cross
  defp background("none"), do: nil
  defp background(_), do: :dots

  # Approximate center of the visible flow area (the container size is not
  # tracked by the parent LiveView)
  defp viewport_center(%Viewport{} = vp) do
    Viewport.screen_to_flow(vp, 360, 300, snap_to_grid: true, snap_grid: {24, 24})
  end
end

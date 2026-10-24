defmodule FlowExampleWeb.Examples.Misc.ServerSideImageLive do
  @moduledoc """
  Server Side Image Creation: generate static SVG images of a flow on the
  server, without a browser.

  `LiveFlow.Export.to_svg/2` is pure Elixir: it draws nodes (as boxes with
  their label), edges (same path algorithms as the client), markers and
  labels. Here it re-renders a preview after every change of the flow; the
  same call works in a background job, a mailer or a controller.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Export, Handle, Node, State}

  @themes [{"Light", "light"}, {"Dark", "dark"}, {"Brand (custom map)", "brand"}]

  # `theme:` also accepts a map overriding the light colors
  @brand %{
    background: "#f5f3ff",
    node_bg: "#ffffff",
    node_border: "#c4b5fd",
    text: "#3b0764",
    edge: "#8b5cf6",
    selected: "#db2777",
    label_bg: "#ede9fe"
  }

  @defaults %{"theme" => "light", "background" => "true", "padding" => "40"}

  @labels ~w(Analyze Prototype Iterate Measure Polish Document Launch Celebrate)

  @snippet """
  # e.g. in an Oban worker
  svg = LiveFlow.Export.to_svg(flow, theme: :dark, padding: 24)
  File.write!("flow.svg", svg)
  """

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, themes: @themes, snippet: @snippet)
     |> assign(edge_opts: [type: :smoothstep, marker_end: %{type: :arrow_closed}])
     |> assign(preview_key: nil)
     |> assign_options(@defaults)
     |> FlowEvents.assign_flow(build_flow())
     |> refresh_preview()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="add-node" icon="hero-plus" phx-click="add_node">Add node</.action>
        <.action
          id="download-server-svg"
          icon="hero-arrow-down-tray"
          variant={:primary}
          phx-click="download_svg"
        >
          Download SVG
        </.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="server-image-flow"
        flow={@flow}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.25},
            connection_line_type: :smoothstep
          }
        }
      />

      <:sidebar>
        <.option_group title="Server preview" tag="live">
          <div class="overflow-hidden rounded-lg border border-base-300 bg-[repeating-conic-gradient(var(--color-base-200)_0_25%,transparent_0_50%)] bg-[length:14px_14px]">
            <img
              id="server-svg-preview"
              src={"data:image/svg+xml;base64," <> Base.encode64(@svg)}
              alt="SVG of the flow rendered on the server"
              class="mx-auto block max-h-64 w-full object-contain"
            />
          </div>
          <p
            id="server-svg-stats"
            class="flex justify-between pt-1 font-mono text-[10.5px] text-base-content/50"
          >
            <span>{map_size(@flow.nodes)} nodes · {map_size(@flow.edges)} edges</span>
            <span>{format_bytes(byte_size(@svg))} · {format_time(@render_us)}</span>
          </p>
          <.hint>
            Regenerated with <code>LiveFlow.Export.to_svg/2</code>
            after every change: drag, connect, delete (<.kbd>Backspace</.kbd>), add nodes or edit an edge label (double click).
          </.hint>
        </.option_group>

        <.option_group title="Export options">
          <.form for={@form} id="server-image-options" phx-change="options">
            <.input
              field={@form[:theme]}
              type="select"
              label="theme"
              class={select_class()}
              options={@themes}
            />
            <.input
              field={@form[:background]}
              type="checkbox"
              label="background"
              class={switch_class()}
            />
            <.range field={@form[:padding]} label="padding" min="0" max="120" step="10" />
          </.form>
        </.option_group>

        <.option_group title="No browser needed">
          <.hint>
            The SVG is built from <code>%LiveFlow.State{}</code>
            alone, so it works where there is no DOM: Oban jobs, mailers (thumbnails in emails),
            controllers serving <code>image/svg+xml</code>, or <code>mix</code>
            tasks.
          </.hint>
          <pre
            id="server-image-snippet"
            class="mt-2 overflow-x-auto rounded-lg bg-base-200 p-2.5 font-mono text-[10.5px] leading-relaxed text-base-content/70"
          >{@snippet}</pre>
          <.hint>
            Custom node components aren't rendered (nodes are drawn as labeled boxes). For pixel-perfect images use the client-side export (Download Image example).
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  @impl true
  def handle_event("options", %{"export" => params}, socket) do
    {:noreply,
     socket
     |> assign_options(Map.merge(socket.assigns.options, params))
     |> refresh_preview()}
  end

  def handle_event("add_node", _params, socket) do
    flow = socket.assigns.flow
    count = map_size(flow.nodes)
    id = "n#{System.unique_integer([:positive])}"
    label = Enum.at(@labels, rem(count, length(@labels)))

    # Next to the right-most node, connected to it
    last = flow.nodes |> Map.values() |> Enum.max_by(& &1.position.x, fn -> nil end)

    {position, edges} =
      case last do
        nil ->
          {%{x: 0, y: 0}, []}

        node ->
          y = node.position.y + if(rem(count, 2) == 0, do: -60, else: 60)

          {%{x: node.position.x + 220, y: y},
           [Edge.new("e-#{node.id}-#{id}", node.id, id, socket.assigns.edge_opts)]}
      end

    flow =
      flow |> State.add_node(Node.new(id, position, %{label: label})) |> State.add_edges(edges)

    {:noreply,
     socket
     |> FlowEvents.snapshot()
     |> assign(:flow, flow)
     |> FlowEvents.log("add_node", %{"id" => id, "label" => label})
     |> refresh_preview()}
  end

  def handle_event("download_svg", _params, socket) do
    {:noreply,
     socket
     |> push_event("lf:download_file", %{
       content: socket.assigns.svg,
       filename: "flow.svg",
       type: "image/svg+xml"
     })
     |> FlowEvents.log("lf:download_file", %{"bytes" => byte_size(socket.assigns.svg)})}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    {:noreply, socket} = FlowEvents.handle_event(event, params, socket)
    {:noreply, refresh_preview(socket)}
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp assign_options(socket, params) do
    theme =
      if params["theme"] in Enum.map(@themes, &elem(&1, 1)), do: params["theme"], else: "light"

    padding =
      case Integer.parse(to_string(params["padding"])) do
        {n, _} -> n |> max(0) |> min(120)
        :error -> 40
      end

    params = %{
      "theme" => theme,
      "background" => if(params["background"] == "false", do: "false", else: "true"),
      "padding" => to_string(padding)
    }

    assign(socket, options: params, form: to_form(params, as: :export))
  end

  # Only re-render when something drawn in the image changed (viewport
  # changes, for instance, don't affect the SVG)
  defp refresh_preview(socket) do
    %{flow: flow, options: options} = socket.assigns
    key = :erlang.phash2({flow.nodes, flow.edges, options})

    if key == socket.assigns.preview_key do
      socket
    else
      {time, svg} = :timer.tc(fn -> Export.to_svg(flow, export_opts(options)) end)
      assign(socket, svg: svg, render_us: time, preview_key: key)
    end
  end

  defp export_opts(%{"theme" => theme, "background" => background, "padding" => padding}) do
    [
      theme: export_theme(theme),
      background: background == "true",
      padding: String.to_integer(padding)
    ]
  end

  defp export_theme("dark"), do: :dark
  defp export_theme("brand"), do: @brand
  defp export_theme(_), do: :light

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_time(us) when us < 1000, do: "#{us} µs"
  defp format_time(us), do: "#{Float.round(us / 1000, 1)} ms"

  defp build_flow do
    nodes = [
      Node.new("idea", %{x: 0, y: 100}, %{label: "Idea"}, handles: [Handle.source(:right)]),
      Node.new("research", %{x: 220, y: 0}, %{label: "Research"}),
      Node.new("design", %{x: 220, y: 200}, %{label: "Design"}),
      Node.new("build", %{x: 460, y: 100}, %{label: "Build"}),
      Node.new("ship", %{x: 680, y: 100}, %{label: "Ship"}, handles: [Handle.target(:left)])
    ]

    edges = [
      Edge.new("e-idea-research", "idea", "research", type: :smoothstep, animated: true),
      Edge.new("e-idea-design", "idea", "design", type: :smoothstep, animated: true),
      Edge.new("e-research-build", "research", "build", type: :smoothstep),
      Edge.new("e-design-build", "design", "build", type: :smoothstep, label: "specs"),
      Edge.new("e-build-ship", "build", "ship",
        type: :smoothstep,
        label: "v1.0",
        style: %{stroke: "#10b981"},
        marker_end: %{type: :arrow_closed, color: "#10b981"}
      )
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

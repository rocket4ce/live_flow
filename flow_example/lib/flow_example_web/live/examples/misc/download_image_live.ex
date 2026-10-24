defmodule FlowExampleWeb.Examples.Misc.DownloadImageLive do
  @moduledoc """
  Download Image: save the flow as a PNG or SVG image.

  The export runs in the browser: `JS.dispatch("lf:export-png", to: "#flow")`
  (or `lf:export-svg`) clones the rendered nodes and edges with their computed
  styles inlined, so Tailwind classes, icons and the current theme end up in
  the image. The server can trigger the same export with
  `push_event(socket, "lf:export_png", %{})`.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.State

  @themes [
    {"Site theme", "system"},
    {"Light", "light"},
    {"Dark", "dark"},
    {"Ocean", "ocean"},
    {"Nord", "nord"},
    {"Coffee", "coffee"}
  ]

  @backgrounds [{"Dots", "dots"}, {"Lines", "lines"}, {"Cross", "cross"}, {"None", "none"}]

  @defaults %{"theme" => "system", "background" => "dots"}

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(themes: @themes, backgrounds: @backgrounds)
     |> assign_appearance(@defaults)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action
          id="download-png"
          icon="hero-photo"
          variant={:primary}
          phx-click={JS.dispatch("lf:export-png", to: "#download-image-flow")}
        >
          Download PNG
        </.action>
        <.action
          id="download-svg"
          icon="hero-arrow-down-tray"
          phx-click={JS.dispatch("lf:export-svg", to: "#download-image-flow")}
        >
          Download SVG
        </.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="download-image-flow"
        flow={@flow}
        node_types={%{card: &card_node/1}}
        opts={
          %{
            theme: @theme,
            background: @background,
            controls: true,
            minimap: true,
            fit_view_on_init: true
          }
        }
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            The buttons dispatch a DOM event to the flow container:
            <code>JS.dispatch("lf:export-png", to: "#download-image-flow")</code>
            (or <code>lf:export-svg</code>). No server round-trip.
          </.hint>
          <.hint>
            Nodes and edges are cloned with their computed styles inlined, so
            Tailwind classes, icons, markers and the current theme are kept.
            The PNG is the same SVG rasterized at 2x.
          </.hint>
        </.option_group>

        <.option_group title="What's exported">
          <ul class="space-y-1 text-xs text-base-content/60">
            <li class="flex gap-1.5">
              <.icon name="hero-check-mini" class="size-4 shrink-0 text-success" />
              Nodes, edges, markers and labels, framed to fit all nodes
            </li>
            <li class="flex gap-1.5">
              <.icon name="hero-check-mini" class="size-4 shrink-0 text-success" />
              Background color and pattern of the current theme
            </li>
            <li class="flex gap-1.5">
              <.icon name="hero-x-mark-mini" class="size-4 shrink-0 text-error" />
              Editor chrome: controls, minimap, selection box, delete buttons, resizers, edge toolbars, reconnect handles
            </li>
            <li class="flex gap-1.5">
              <.icon name="hero-x-mark-mini" class="size-4 shrink-0 text-error" />
              Any element with <code>data-lf-export-ignore</code>, like the amber <b>editor only</b>
              badges
            </li>
          </ul>
        </.option_group>

        <.option_group title="Appearance">
          <.form for={@form} id="image-options" phx-change="appearance">
            <.input
              field={@form[:theme]}
              type="select"
              label="Theme"
              class={select_class()}
              options={@themes}
            />
            <.input
              field={@form[:background]}
              type="select"
              label="Background"
              class={select_class()}
              options={@backgrounds}
            />
          </.form>
          <.hint>The image matches what you see: change the theme, then download.</.hint>
        </.option_group>

        <.option_group title="From the server">
          <.action id="export-from-server" icon="hero-server" phx-click="export_from_server">
            PNG via push_event
          </.action>
          <.hint>
            <code>push_event(socket, "lf:export_png", %&lbrace;&rbrace;)</code>
            asks the hook to export, e.g. after saving a document.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp card_node(assigns) do
    ~H"""
    <div class="relative">
      <FlowNodes.card node={@node} />
      <span
        :if={@node.data[:draft]}
        data-lf-export-ignore
        class="absolute -top-[22px] -left-[10px] inline-flex items-center gap-0.5 rounded-full bg-amber-400 px-1.5 py-0.5 text-[10px] font-semibold text-amber-950 shadow-sm"
      >
        <.icon name="hero-eye-slash-micro" class="size-3" /> editor only
      </span>
    </div>
    """
  end

  @impl true
  def handle_event("appearance", %{"image" => params}, socket) do
    {:noreply, assign_appearance(socket, Map.merge(socket.assigns.appearance, params))}
  end

  def handle_event("export_from_server", _params, socket) do
    {:noreply,
     socket
     |> push_event("lf:export_png", %{})
     |> FlowEvents.log("push_event", %{"event" => "lf:export_png"})}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp assign_appearance(socket, params) do
    theme = pick(params["theme"], @themes, "system")
    background = pick(params["background"], @backgrounds, "dots")
    params = %{"theme" => theme, "background" => background}

    assign(socket,
      appearance: params,
      form: to_form(params, as: :image),
      theme: if(theme == "system", do: nil, else: theme),
      background: if(background == "none", do: nil, else: String.to_existing_atom(background))
    )
  end

  defp pick(value, options, default) do
    if Enum.any?(options, fn {_label, v} -> v == value end), do: value, else: default
  end

  defp build_flow do
    Enum.reduce(["enrich", "archive"], Samples.pipeline(), fn id, flow ->
      State.update_node(flow, id, fn node -> %{node | data: Map.put(node.data, :draft, true)} end)
    end)
  end
end

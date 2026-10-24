defmodule FlowExampleWeb.HomeLive do
  @moduledoc """
  Showcase landing page.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{FlowEvents, FlowNodes}

  @demos [
    {"/examples", "React Flow examples",
     "Every React Flow example, including the Pro ones, rebuilt with LiveFlow.",
     "hero-rectangle-group"},
    {"/playground", "Playground",
     "A full editor: history, clipboard, auto-layout, import/export and themes.",
     "hero-sparkles"},
    {"/interaction", "Interaction",
     "Auto-pan, pan activation keys, selection on drag, key combos and node extent.",
     "hero-cursor-arrow-rays"},
    {"/edges", "Edges",
     "Bezier, straight, step and smoothstep paths with step_position and floating ends.",
     "hero-arrows-right-left"},
    {"/resizing", "Resizing",
     "NodeResizer with min/max size, aspect ratio and paired start/end events.",
     "hero-arrows-pointing-out"},
    {"/custom-nodes", "Custom nodes",
     "Form fields, drag handles, typed handles and interactive content.", "hero-cube"},
    {"/large", "Large flows", "Thousands of nodes with server-side viewport culling.",
     "hero-rectangle-stack"}
  ]

  @changes [
    {"Auto-pan on selection", "12.11.0",
     "The viewport follows a selection box dragged to its edge (also node drags and connections)."},
    {"Resize start/end always paired", "12.12.0",
     "A resize start is always followed by an end change, even when cancelled."},
    {"step_position + rounded bends", "12.10.2",
     "Smoothstep is a byte-exact port of getSmoothStepPath, on server and client."},
    {"Middle mouse & Control panning", "12.11.3",
     "Pan with the middle button from anywhere, or hold Space / Control."},
    {"Key combinations", "12.11.3",
     "Key options accept combos of any length like Meta+Shift+Backspace."},
    {"Node extent for drag & resize", "12.11.0",
     "Nodes can't be dragged or resized past node_extent."},
    {"snap_grid in screen_to_flow", "12.10.2",
     "Viewport.screen_to_flow/4 snaps drop positions to the grid."},
    {"Background pattern offset", "12.11.3",
     "SVG pattern aligned to the grid, synced during client-side pan/zoom."},
    {"Bounds without phantom origin", "12.11.3",
     "State.bounds/2 ignores unknown ids and hidden nodes (fit view, minimap)."},
    {"Custom edge ids", "12.10.0",
     "validate_and_create/3 and State.reconnect_edge/3 accept an :edge_id function."}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Overview")
     |> assign(:demos, @demos)
     |> assign(:changes, @changes)
     |> FlowEvents.assign_flow(Samples.pipeline())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active={:home}>
      <div class="h-full overflow-y-auto">
        <div class="mx-auto max-w-6xl space-y-12 px-6 py-10">
          <section class="grid items-center gap-8 lg:grid-cols-[1fr_1.3fr]">
            <div class="space-y-5">
              <span class="inline-flex items-center gap-1.5 rounded-full bg-primary/10 px-3 py-1 text-xs font-medium text-primary">
                <span class="size-1.5 animate-pulse rounded-full bg-primary"></span>
                Synced with xyflow 12.12
              </span>
              <h1 class="text-4xl font-semibold tracking-tight text-balance">
                Node-based editors for <span class="text-primary">Phoenix LiveView</span>
              </h1>
              <p class="text-base leading-relaxed text-base-content/70">
                LiveFlow brings the React Flow experience to LiveView: your LiveView owns the
                state, the hook keeps dragging, panning and connecting at 60fps.
              </p>
              <div class="flex flex-wrap gap-2">
                <.link
                  navigate={~p"/examples"}
                  class="inline-flex items-center gap-1.5 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-content shadow-sm transition-all hover:brightness-110 active:scale-95"
                >
                  Browse the examples <.icon name="hero-arrow-right" class="size-4" />
                </.link>
                <.link
                  navigate={~p"/playground"}
                  class="inline-flex items-center gap-1.5 rounded-lg border border-base-300 bg-base-100 px-4 py-2 text-sm font-medium transition-colors hover:bg-base-200"
                >
                  Playground
                </.link>
                <a
                  href="https://hexdocs.pm/live_flow"
                  class="inline-flex items-center gap-1.5 rounded-lg border border-base-300 bg-base-100 px-4 py-2 text-sm font-medium transition-colors hover:bg-base-200"
                >
                  Documentation
                </a>
              </div>
            </div>

            <div class="h-80 overflow-hidden rounded-2xl border border-base-300 bg-base-100 shadow-xl shadow-base-content/5 ring-1 ring-base-content/5">
              <.live_component
                module={LiveFlow.Components.Flow}
                id="hero-flow"
                flow={@flow}
                node_types={FlowNodes.types()}
                opts={
                  %{
                    background: :dots,
                    fit_view_on_init: true,
                    fit_view_options: %{padding: 0.08},
                    zoom_on_scroll: false,
                    pan_on_scroll: false,
                    prevent_scrolling: false
                  }
                }
              />
            </div>
          </section>

          <section>
            <h2 class="mb-4 text-sm font-semibold uppercase tracking-wider text-base-content/50">
              Examples
            </h2>
            <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <.link
                :for={{path, title, description, icon} <- @demos}
                navigate={path}
                class="group rounded-xl border border-base-300 bg-base-100 p-5 transition-all duration-200 hover:-translate-y-0.5 hover:border-primary/40 hover:shadow-lg hover:shadow-primary/5"
              >
                <span class="mb-3 grid size-9 place-items-center rounded-lg bg-primary/10 text-primary transition-transform group-hover:scale-110">
                  <.icon name={icon} class="size-5" />
                </span>
                <h3 class="flex items-center gap-1 font-medium">
                  {title}
                  <.icon
                    name="hero-arrow-right-mini"
                    class="size-4 opacity-0 transition-all group-hover:translate-x-0.5 group-hover:opacity-60"
                  />
                </h3>
                <p class="mt-1 text-sm leading-relaxed text-base-content/60">{description}</p>
              </.link>
            </div>
          </section>

          <section>
            <h2 class="mb-4 text-sm font-semibold uppercase tracking-wider text-base-content/50">
              What's new in this update
            </h2>
            <div class="divide-y divide-base-300 overflow-hidden rounded-xl border border-base-300 bg-base-100">
              <div
                :for={{title, version, description} <- @changes}
                class="flex items-start gap-4 px-5 py-3"
              >
                <span class="mt-0.5 shrink-0 rounded bg-base-200 px-1.5 py-0.5 font-mono text-[11px] text-base-content/60">
                  {version}
                </span>
                <div>
                  <p class="text-sm font-medium">{title}</p>
                  <p class="text-sm text-base-content/60">{description}</p>
                </div>
              </div>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _node_id}, socket), do: {:noreply, socket}
end

defmodule FlowExampleWeb.Examples.Layout.HorizontalLive do
  @moduledoc """
  Horizontal Flow: a left-to-right diagram. Handles sit on the left (target)
  and right (source) of every node; positions come from
  `LiveFlow.Layout.tree(flow, direction: :lr)`.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Edge, Layout, State}

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="horizontal-flow"
        flow={@flow}
        node_types={FlowNodes.types()}
        opts={%{background: :dots, controls: true, minimap: true, fit_view_on_init: true}}
      />

      <:sidebar>
        <.option_group title="How it works">
          <.hint>
            Every node has <code>Handle.target(:left)</code>
            and <code>Handle.source(:right)</code>, so edges flow from left to right. Smoothstep
            edges keep the diagram orthogonal.
          </.hint>
          <.hint>
            The positions come from <code>LiveFlow.Layout.tree(flow, direction: :lr)</code>; the
            animated edges are the steps currently running.
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
  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  defp build_flow do
    card = fn id, title, subtitle, icon, color, opts ->
      Samples.card(
        id,
        0,
        0,
        title,
        subtitle,
        icon,
        color,
        Keyword.merge([width: 226, height: 60], opts)
      )
    end

    nodes = [
      card.("commit", "Commit", "main @ 4f2a9c1", "hero-code-bracket", :slate, inputs: false),
      card.("build", "Build", "mix compile", "hero-wrench-screwdriver", :sky, []),
      card.("unit", "Unit tests", "412 passed", "hero-check-badge", :emerald, []),
      card.("lint", "Credo", "No issues", "hero-sparkles", :emerald, []),
      card.("security", "Security scan", "Running…", "hero-shield-check", :amber, []),
      card.("package", "Package", "Release tarball", "hero-archive-box", :violet, []),
      card.("staging", "Deploy staging", "fly.io", "hero-cloud-arrow-up", :sky, []),
      card.("docs", "Publish docs", "hexdocs", "hero-book-open", :slate, outputs: false),
      card.("e2e", "E2E tests", "Playwright", "hero-cursor-arrow-rays", :amber, []),
      card.("production", "Production", "Waiting for approval", "hero-rocket-launch", :rose,
        outputs: false
      )
    ]

    running = MapSet.new(["security", "e2e"])

    edges =
      for {source, target} <- [
            {"commit", "build"},
            {"build", "unit"},
            {"build", "lint"},
            {"build", "security"},
            {"unit", "package"},
            {"lint", "package"},
            {"security", "package"},
            {"package", "staging"},
            {"package", "docs"},
            {"staging", "e2e"},
            {"e2e", "production"}
          ] do
        Edge.new("#{source}-#{target}", source, target,
          type: :smoothstep,
          animated: MapSet.member?(running, target),
          marker_end: %{type: :arrow_closed}
        )
      end

    flow = State.new(nodes: nodes, edges: edges)

    Layout.apply_positions(
      flow,
      Layout.tree(flow, direction: :lr, node_spacing: 28, rank_spacing: 70)
    )
  end
end

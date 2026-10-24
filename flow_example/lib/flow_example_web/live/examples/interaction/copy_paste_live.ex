defmodule FlowExampleWeb.Examples.Interaction.CopyPasteLive do
  @moduledoc """
  Copy and Paste: select nodes and edges to cut, copy, and paste them.

  The hook turns ⌘C / ⌘X / ⌘V / ⌘D into `lf:copy`, `lf:cut`, `lf:paste` and
  `lf:duplicate`; `FlowExampleWeb.FlowEvents` handles them with
  `LiveFlow.Clipboard` (copy the selection plus the edges between the copied
  nodes, paste with new ids and a growing offset). The header buttons call
  the very same handlers.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{Examples, FlowEvents, FlowNodes}
  alias LiveFlow.{Clipboard, Edge, State}

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title)
     |> assign(edge_opts: [type: :smoothstep])
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        selected: MapSet.size(assigns.flow.selected_nodes),
        selected_edges: MapSet.size(assigns.flow.selected_edges),
        clip_nodes: Clipboard.node_count(assigns.clipboard),
        clip_edges: length(assigns.clipboard.edges)
      )

    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #clipboard-indicator[data-filled] .clipboard-icon {
        animation: clipboard-pop 260ms cubic-bezier(0.2, 0.9, 0.3, 1.4);
      }
      @keyframes clipboard-pop {
        from {
          scale: 0.6;
        }
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <span
          id="clipboard-indicator"
          data-filled={@clip_nodes > 0}
          title="Nodes in the clipboard"
          class={[
            "inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium transition-colors",
            if(@clip_nodes > 0,
              do: "bg-primary/10 text-primary",
              else: "bg-base-200 text-base-content/50"
            )
          ]}
        >
          <.icon
            name={if @clip_nodes > 0, do: "hero-clipboard-document-check", else: "hero-clipboard"}
            class="clipboard-icon size-4"
          />
          <span id="clipboard-count">{@clip_nodes}</span>
        </span>
        <.action
          id="cut-btn"
          icon="hero-scissors"
          phx-click="clipboard"
          phx-value-op="cut"
          disabled={@selected == 0}
          title="Cut (⌘X)"
        >
          Cut
        </.action>
        <.action
          id="copy-btn"
          icon="hero-document-duplicate"
          phx-click="clipboard"
          phx-value-op="copy"
          disabled={@selected == 0}
          title="Copy (⌘C)"
        >
          Copy
        </.action>
        <.action
          id="paste-btn"
          icon="hero-clipboard-document"
          variant={:primary}
          phx-click="clipboard"
          phx-value-op="paste"
          disabled={@clip_nodes == 0}
          title="Paste (⌘V)"
        >
          Paste
        </.action>
        <.action
          id="duplicate-btn"
          icon="hero-square-2-stack"
          phx-click="clipboard"
          phx-value-op="duplicate"
          disabled={@selected == 0}
          title="Duplicate (⌘D)"
        >
          Duplicate
        </.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="copy-paste-flow"
        flow={@flow}
        node_types={FlowNodes.types()}
        opts={
          %{
            background: :dots,
            controls: true,
            minimap: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.2}
          }
        }
      />

      <:sidebar>
        <.option_group title="Shortcuts">
          <ul class="space-y-1.5 text-sm">
            <li :for={{keys, text} <- shortcuts()} class="flex items-center justify-between gap-2">
              <span class="text-base-content/70">{text}</span>
              <span class="flex gap-1"><.kbd :for={key <- keys}>{key}</.kbd></span>
            </li>
          </ul>
          <.hint>Ctrl works as well as ⌘. Click the canvas first so the flow has the focus.</.hint>
        </.option_group>

        <.option_group title="Clipboard">
          <div id="clipboard-panel" class="rounded-xl border border-base-300 bg-base-200/50 p-3">
            <div class="flex items-center justify-between text-xs">
              <span class="font-medium">
                <span id="clipboard-nodes">{@clip_nodes}</span>
                {plural(@clip_nodes, "node")} · <span id="clipboard-edges">{@clip_edges}</span>
                {plural(@clip_edges, "edge")}
              </span>
              <span :if={@clipboard.paste_count > 0} class="text-base-content/50">
                pasted {@clipboard.paste_count}×
              </span>
            </div>
            <p :if={@clip_nodes == 0} class="mt-2 text-xs text-base-content/45">
              Empty. Select nodes and press ⌘C.
            </p>
            <div :if={@clip_nodes > 0} class="mt-2 flex flex-wrap gap-1">
              <span
                :for={node <- @clipboard.nodes}
                class="rounded-md bg-base-100 px-1.5 py-0.5 text-[11px] shadow-xs"
              >
                {node.data[:title]}
              </span>
            </div>
          </div>
          <p class="pt-1 text-xs text-base-content/55">
            Selection: <b id="selection-count">{@selected}</b>
            {plural(@selected, "node")}, {@selected_edges} {plural(@selected_edges, "edge")}
          </p>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            <code>Clipboard.copy/2</code>
            stores the selected nodes and every edge between them. <code>Clipboard.paste/2</code>
            gives the copies new ids, offsets them by 50px more on every paste and selects them, so
            you can drag them away right after.
          </.hint>
          <.hint>
            Cut and paste push a snapshot to <code>LiveFlow.History</code> first: ⌘Z undoes them.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  defp shortcuts do
    [
      {["⌘", "C"], "Copy"},
      {["⌘", "X"], "Cut"},
      {["⌘", "V"], "Paste"},
      {["⌘", "D"], "Duplicate"},
      {["⌘", "A"], "Select all"},
      {["⇧", "drag"], "Box selection"},
      {["⌘", "Z"], "Undo"}
    ]
  end

  defp plural(1, word), do: word
  defp plural(_count, word), do: word <> "s"

  # ===== Events =====

  # Header buttons run the same handlers as the keyboard shortcuts
  @impl true
  def handle_event("clipboard", %{"op" => op}, socket)
      when op in ["copy", "cut", "paste", "duplicate"] do
    FlowEvents.handle_event("lf:" <> op, %{"from" => "toolbar"}, socket)
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Initial graph =====

  defp build_flow do
    nodes = [
      Samples.card("source", 0, 120, "Form", "Signup submitted", "hero-document-text", :amber,
        inputs: false
      ),
      Samples.card("check", 300, 40, "Verify email", "Send a magic link", "hero-envelope", :sky),
      Samples.card(
        "score",
        300,
        220,
        "Lead score",
        "Company size + role",
        "hero-chart-bar",
        :violet
      ),
      Samples.card("crm", 600, 120, "CRM", "Create contact", "hero-user-plus", :emerald,
        outputs: false
      )
    ]

    edges = [
      Edge.new("source-check", "source", "check", type: :smoothstep, animated: true),
      Edge.new("source-score", "source", "score", type: :smoothstep, animated: true),
      Edge.new("check-crm", "check", "crm", type: :smoothstep),
      Edge.new("score-crm", "score", "crm", type: :smoothstep)
    ]

    State.new(nodes: nodes, edges: edges)
    |> State.select_nodes(["check", "score"])
  end
end

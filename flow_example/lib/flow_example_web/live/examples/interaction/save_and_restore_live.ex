defmodule FlowExampleWeb.Examples.Interaction.SaveAndRestoreLive do
  @moduledoc """
  Save and Restore: save the diagram in the browser and reload it after
  refreshing the page.

  **Save** serializes the flow (nodes, edges and viewport) with
  `LiveFlow.Serializer.to_json/1` and pushes it to a colocated hook that keeps
  it in `localStorage`. **Restore** asks the hook for the saved JSON, which is
  pushed back and loaded with `LiveFlow.Serializer.from_json/1`; the saved
  viewport is applied with the `lf:set_viewport` event.
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Node, Serializer, State}

  @storage_key "liveflow:save-and-restore"

  @colors %{
    "sky" => "bg-sky-500",
    "violet" => "bg-violet-500",
    "emerald" => "bg-emerald-500",
    "amber" => "bg-amber-500",
    "rose" => "bg-rose-500"
  }

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, storage_key: @storage_key)
     |> assign(last_save: nil, saved_json: nil, status: nil, dims: %{})
     |> FlowEvents.assign_flow(build_flow())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.example flash={@flash} example={@example}>
      <:actions>
        <.action id="add-node-button" icon="hero-plus" phx-click="add_node">Add node</.action>
        <.action id="restore-button" icon="hero-arrow-uturn-left" phx-click="restore">
          Restore
        </.action>
        <.action id="save-button" icon="hero-arrow-down-tray" variant={:primary} phx-click="save">
          Save
        </.action>
      </:actions>

      <.live_component
        module={LiveFlow.Components.Flow}
        id="save-and-restore"
        flow={@flow}
        node_types={%{note: &note_node/1}}
        opts={
          %{
            background: :dots,
            controls: true,
            minimap: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.3}
          }
        }
      />

      <:sidebar>
        <div id="flow-storage" phx-hook=".FlowStorage" data-key={@storage_key} class="hidden" />
        <script :type={Phoenix.LiveView.ColocatedHook} name=".FlowStorage">
          // Keeps the serialized flow in localStorage. The server pushes
          // "flow-storage:save" / "flow-storage:load" / "flow-storage:clear";
          // loads are answered with a "restore_flow" event.
          export default {
            mounted() {
              this.key = this.el.dataset.key

              this.handleEvent("flow-storage:save", ({json, saved_at}) => {
                try {
                  localStorage.setItem(this.key, JSON.stringify({json, saved_at}))
                } catch (error) {
                  this.pushEvent("storage_error", {message: String(error)})
                }
              })
              this.handleEvent("flow-storage:load", () => this.pushEvent("restore_flow", this.read()))
              this.handleEvent("flow-storage:clear", () => localStorage.removeItem(this.key))

              // A save from a previous visit
              const saved = this.read()
              if (saved.json) this.pushEvent("storage_info", saved)
            },
            read() {
              try {
                return JSON.parse(localStorage.getItem(this.key)) || {}
              } catch (_error) {
                return {}
              }
            }
          }
        </script>

        <.option_group title="Storage">
          <div id="last-save-panel" class="space-y-2">
            <%= if @last_save do %>
              <div id="last-save" class="rounded-lg border border-base-300 bg-base-200/50 p-3">
                <p class="flex items-center gap-1.5 text-xs font-semibold">
                  <.icon name="hero-check-badge-mini" class="size-4 text-emerald-600" />
                  Saved at {Calendar.strftime(@last_save.at, "%H:%M:%S")} UTC
                </p>
                <p class="mt-1 text-[11px] text-base-content/60">
                  {Calendar.strftime(@last_save.at, "%b %d, %Y")} · {@last_save.nodes} nodes · {@last_save.edges} edges · zoom {format_zoom(
                    @last_save.zoom
                  )}×
                </p>
                <p :if={@last_save.previous_visit} class="mt-1 text-[11px] text-primary">
                  From a previous visit — press Restore to load it.
                </p>
              </div>
              <button
                id="clear-storage"
                type="button"
                phx-click="clear_storage"
                class="inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-xs text-base-content/50 transition-colors hover:bg-base-200 hover:text-base-content"
              >
                <.icon name="hero-trash-mini" class="size-3.5" /> Clear saved flow
              </button>
            <% else %>
              <p id="no-save" class="text-xs text-base-content/45">
                Nothing saved yet. Arrange the flow and press <b>Save</b>.
              </p>
            <% end %>
          </div>
          <p
            :if={@status}
            id="storage-status"
            data-kind={@status.kind}
            class={[
              "mt-2 flex items-center gap-1.5 rounded-md px-2 py-1 text-xs",
              @status.kind == :ok && "bg-emerald-500/10 text-emerald-700",
              @status.kind == :error && "bg-rose-500/10 text-rose-600"
            ]}
          >
            <.icon
              name={
                if @status.kind == :ok, do: "hero-check-mini", else: "hero-exclamation-triangle-mini"
              }
              class="size-4 shrink-0"
            />
            {@status.message}
          </p>
        </.option_group>

        <.option_group title="How it works">
          <.hint>
            <b>Save</b>
            serializes nodes, edges and the viewport with <code>Serializer.to_json/1</code>
            and pushes it to a colocated hook, which writes it to <code>localStorage</code>.
          </.hint>
          <.hint>
            <b>Restore</b>
            asks the hook for the JSON (<code>pushEvent</code>
            back to the server), loads it with <code>Serializer.from_json/1</code>
            and applies the saved viewport with <code>push_event("lf:set_viewport", ...)</code>.
          </.hint>
          <.hint>
            Save, move things around (or refresh the page), then restore.
          </.hint>
        </.option_group>

        <.option_group :if={@saved_json} title="Saved JSON">
          <details id="saved-json" class="group">
            <summary class="cursor-pointer list-none text-xs text-base-content/60 transition-colors hover:text-base-content">
              <.icon
                name="hero-chevron-right-mini"
                class="size-4 transition-transform group-open:rotate-90"
              />
              {byte_size(@saved_json)} bytes
            </summary>
            <pre class="mt-2 max-h-72 overflow-auto rounded-lg bg-base-200 p-2 font-mono text-[10px] leading-relaxed text-base-content/70">{@saved_json}</pre>
          </details>
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  attr :node, :map, required: true

  defp note_node(assigns) do
    assigns = assign(assigns, :dot, Map.get(@colors, assigns.node.data[:color], "bg-slate-400"))

    ~H"""
    <div class="flex w-32 items-center gap-2">
      <span class={["size-2.5 shrink-0 rounded-full", @dot]} />
      <span class="truncate text-[13px] font-semibold" style="color: var(--lf-text-primary)">
        {@node.data[:label]}
      </span>
    </div>
    """
  end

  # ===== Save / restore =====

  @impl true
  def handle_event("save", _params, socket) do
    flow = socket.assigns.flow
    json = Serializer.to_json(flow)
    saved_at = DateTime.utc_now() |> DateTime.truncate(:second)

    last_save = %{
      at: saved_at,
      nodes: map_size(flow.nodes),
      edges: map_size(flow.edges),
      zoom: flow.viewport.zoom,
      previous_visit: false
    }

    socket
    |> push_event("flow-storage:save", %{json: json, saved_at: DateTime.to_iso8601(saved_at)})
    |> assign(last_save: last_save, saved_json: json)
    |> assign(:status, %{kind: :ok, message: "Saved to localStorage"})
    |> FlowEvents.log("save", %{"bytes" => byte_size(json)})
    |> noreply()
  end

  def handle_event("restore", _params, socket) do
    {:noreply, push_event(socket, "flow-storage:load", %{})}
  end

  def handle_event("restore_flow", %{"json" => json}, socket) when is_binary(json) do
    case Serializer.from_json(json) do
      {:ok, restored} ->
        restored = with_dims(restored, socket.assigns.dims)
        %{x: x, y: y, zoom: zoom} = restored.viewport

        socket
        |> FlowEvents.snapshot()
        |> assign(:flow, restored)
        |> assign(:saved_json, json)
        |> push_event("lf:set_viewport", %{x: x, y: y, zoom: zoom})
        |> assign(:status, %{
          kind: :ok,
          message:
            "Restored #{map_size(restored.nodes)} nodes and #{map_size(restored.edges)} edges"
        })
        |> FlowEvents.log("restore", %{"nodes" => map_size(restored.nodes)})
        |> noreply()

      {:error, reason} ->
        socket
        |> assign(:status, %{kind: :error, message: "Could not restore: #{reason}"})
        |> noreply()
    end
  end

  def handle_event("restore_flow", _params, socket) do
    {:noreply, assign(socket, :status, %{kind: :error, message: "Nothing saved yet"})}
  end

  # A save left by a previous visit (sent by the hook when it mounts)
  def handle_event("storage_info", %{"json" => json, "saved_at" => saved_at}, socket)
      when is_binary(json) and is_binary(saved_at) do
    with {:ok, at, _offset} <- DateTime.from_iso8601(saved_at),
         {:ok, saved} <- Serializer.from_json(json) do
      last_save = %{
        at: at,
        nodes: map_size(saved.nodes),
        edges: map_size(saved.edges),
        zoom: saved.viewport.zoom,
        previous_visit: true
      }

      {:noreply, assign(socket, last_save: last_save, saved_json: json)}
    else
      _error -> {:noreply, socket}
    end
  end

  def handle_event("storage_info", _params, socket), do: {:noreply, socket}

  def handle_event("storage_error", %{"message" => message}, socket) do
    {:noreply, assign(socket, :status, %{kind: :error, message: "Could not save: #{message}"})}
  end

  def handle_event("clear_storage", _params, socket) do
    socket
    |> push_event("flow-storage:clear", %{})
    |> assign(last_save: nil, saved_json: nil, status: nil)
    |> noreply()
  end

  def handle_event("add_node", _params, socket) do
    flow = socket.assigns.flow
    n = next_number(flow)
    colors = Map.keys(@colors)

    node =
      note(
        Integer.to_string(n),
        Enum.random(0..640),
        Enum.random(-40..360),
        "Node #{n}",
        Enum.random(colors)
      )

    socket
    |> FlowEvents.snapshot()
    |> assign(:flow, State.add_node(flow, node))
    |> FlowEvents.log("add_node", %{"id" => node.id})
    |> noreply()
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    {:noreply, socket} = FlowEvents.handle_event(event, params, socket)
    {:noreply, remember_dims(socket)}
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # ===== Helpers =====

  # The serializer doesn't keep measured sizes (only explicit ones of
  # resizable nodes), and the hook doesn't re-measure a node whose element
  # keeps the same id and size, so the sizes seen so far are reused for the
  # restored nodes. Edges are drawn on the server from node sizes.
  defp remember_dims(socket) do
    dims =
      for {id, %Node{width: w, height: h}} <- socket.assigns.flow.nodes,
          is_number(w) and is_number(h),
          into: socket.assigns.dims,
          do: {id, {w, h}}

    assign(socket, :dims, dims)
  end

  defp with_dims(flow, dims) do
    nodes =
      Map.new(flow.nodes, fn {id, node} ->
        case {node.width, Map.get(dims, id)} do
          {nil, {w, h}} -> {id, Node.set_dimensions(node, w, h)}
          _other -> {id, node}
        end
      end)

    %{flow | nodes: nodes}
  end

  defp next_number(flow) do
    flow.nodes
    |> Map.keys()
    |> Enum.map(&Integer.parse/1)
    |> Enum.flat_map(fn
      {n, ""} -> [n]
      _other -> []
    end)
    |> Enum.max(fn -> 0 end)
    |> Kernel.+(1)
  end

  defp format_zoom(zoom), do: :erlang.float_to_binary(zoom / 1, decimals: 2)

  defp noreply(socket), do: {:noreply, socket}

  # ===== Initial graph =====

  defp note(id, x, y, label, color) do
    Node.new(id, %{x: x, y: y}, %{label: label, color: color}, type: :note)
  end

  defp build_flow do
    nodes = [
      note("1", 0, 120, "Node 1", "sky"),
      note("2", 240, 0, "Node 2", "violet"),
      note("3", 240, 240, "Node 3", "emerald"),
      note("4", 480, 120, "Node 4", "amber")
    ]

    edges = [
      Edge.new("e1-2", "1", "2", type: :smoothstep),
      Edge.new("e1-3", "1", "3", type: :smoothstep),
      Edge.new("e2-4", "2", "4", type: :smoothstep, animated: true),
      Edge.new("e3-4", "3", "4", type: :smoothstep, animated: true)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

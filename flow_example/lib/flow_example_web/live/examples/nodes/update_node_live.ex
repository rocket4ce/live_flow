defmodule FlowExampleWeb.Examples.Nodes.UpdateNodeLive do
  @moduledoc """
  Updating Nodes: edit the label, background and visibility of a node.

  The sidebar form's `phx-change` calls `LiveFlow.State.update_node/3` with
  `data`, `style` and `hidden`; the flow re-renders only that node (and the
  edges of a hidden node disappear with it).
  """
  use FlowExampleWeb, :live_view

  alias FlowExampleWeb.{Examples, FlowEvents}
  alias LiveFlow.{Edge, Handle, Node, State}

  @node_id "1"
  @initial %{"label" => "Node 1", "bg" => "#eeeeee", "hidden" => false}
  @presets ~w(#eeeeee #c9f1dd #ffd6a5 #cdb4db #a0c4ff #ff0072 #1a192b)

  @impl true
  def mount(_params, _session, socket) do
    example = Examples.for_module(__MODULE__)

    {:ok,
     socket
     |> assign(example: example, page_title: example.title, presets: @presets)
     |> FlowEvents.assign_flow(build_flow())
     |> apply_params(@initial)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style :type={FlowExampleWeb.ColocatedCSS}>
      #update-node .lf-node {
        transition: background-color 200ms ease, border-color 200ms ease, box-shadow 150ms ease;
      }

      #update-node .lf-node[data-node-id="1"] {
        border-width: 1.5px;
      }

      #update-node-form .color-input::-webkit-color-swatch-wrapper {
        padding: 0;
      }

      #update-node-form .color-input::-webkit-color-swatch {
        border: none;
        border-radius: 6px;
      }

      #update-node-form .color-input::-moz-color-swatch {
        border: none;
        border-radius: 6px;
      }
    </style>
    <Layouts.example flash={@flash} example={@example}>
      <.live_component
        module={LiveFlow.Components.Flow}
        id="update-node"
        flow={@flow}
        opts={
          %{
            background: :dots,
            controls: true,
            fit_view_on_init: true,
            fit_view_options: %{padding: 0.6, max_zoom: 1.4}
          }
        }
      />

      <:sidebar>
        <.form for={@form} id="update-node-form" phx-change="update">
          <.option_group title="Node 1">
            <.input
              field={@form[:label]}
              type="text"
              label="Label"
              autocomplete="off"
              maxlength="40"
              class="w-full rounded-lg border border-base-300 bg-base-100 px-2.5 py-1.5 text-sm shadow-xs transition-colors hover:border-base-content/30 focus:border-primary focus:outline-none"
            />
            <.input
              field={@form[:bg]}
              type="color"
              label="Background"
              class="color-input h-9 w-full cursor-pointer rounded-lg border border-base-300 bg-base-100 p-1 transition-colors hover:border-base-content/30"
            />
            <div class="mb-3 flex flex-wrap gap-1.5">
              <button
                :for={color <- @presets}
                id={"preset-#{String.trim_leading(color, "#")}"}
                type="button"
                phx-click="preset"
                phx-value-color={color}
                title={color}
                class={[
                  "size-6 rounded-md border border-base-300 shadow-xs transition-transform duration-150 hover:scale-110 active:scale-95",
                  color == @params["bg"] && "ring-2 ring-primary ring-offset-1 ring-offset-base-100"
                ]}
                style={"background: #{color}"}
              />
            </div>
            <.input
              field={@form[:hidden]}
              type="checkbox"
              label="Hidden"
              class={switch_class()}
            />
          </.option_group>
        </.form>

        <.option_group title="The update">
          <pre
            id="update-code"
            class="overflow-x-auto rounded-lg bg-base-200 p-3 font-mono text-[11px] leading-relaxed text-base-content/80"
          >{@code}</pre>
          <.hint>
            Every change of the form runs this call: the node re-renders immediately. A hidden node
            isn't rendered, and neither are its edges.
          </.hint>
        </.option_group>

        <.option_group title="Event log">
          <.event_log entries={@event_log} />
        </.option_group>
      </:sidebar>
    </Layouts.example>
    """
  end

  # ===== Events =====

  @impl true
  def handle_event("update", %{"node" => params}, socket) do
    {:noreply,
     socket
     |> apply_params(params)
     |> FlowEvents.log("update", Map.take(params, ["label", "bg", "hidden"]))}
  end

  def handle_event("preset", %{"color" => color}, socket) do
    {:noreply,
     socket
     |> apply_params(Map.put(socket.assigns.params, "bg", color))
     |> FlowEvents.log("preset", %{"bg" => color})}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _id}, socket), do: {:noreply, socket}

  # Normalizes the form params (the color ends up in a style attribute: only
  # #rrggbb is accepted) and updates node 1.
  defp apply_params(socket, params) do
    current = Map.get(socket.assigns, :params, @initial)

    label = params |> Map.get("label", current["label"]) |> to_string() |> String.slice(0, 40)
    bg = if valid_color?(params["bg"]), do: String.downcase(params["bg"]), else: current["bg"]
    hidden = params["hidden"] in [true, "true"]

    # The default node label is colored with --lf-text-primary
    style = %{"background" => bg, "--lf-text-primary" => ink_for(bg)}

    flow =
      State.update_node(socket.assigns.flow, @node_id,
        data: %{label: label},
        style: style,
        hidden: hidden
      )

    params = %{"label" => label, "bg" => bg, "hidden" => hidden}

    assign(socket,
      flow: flow,
      params: params,
      form: to_form(params, as: :node),
      code: code(label, bg, hidden)
    )
  end

  defp code(label, bg, hidden) do
    """
    State.update_node(flow, "#{@node_id}",
      data: %{label: #{inspect(label)}},
      style: %{"background" => "#{bg}"},
      hidden: #{hidden}
    )\
    """
  end

  defp valid_color?(color), do: is_binary(color) and color =~ ~r/\A#[0-9a-fA-F]{6}\z/

  # Dark text on light backgrounds, white text on dark ones (WCAG relative
  # luminance)
  defp ink_for("#" <> hex) do
    [r, g, b] =
      for <<channel::binary-size(2) <- hex>> do
        value = String.to_integer(channel, 16) / 255
        if value <= 0.03928, do: value / 12.92, else: :math.pow((value + 0.055) / 1.055, 2.4)
      end

    if 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.4, do: "#1a192b", else: "#ffffff"
  end

  # ===== Initial graph =====

  defp build_flow do
    nodes = [
      Node.new(@node_id, %{x: 120, y: 0}, %{label: "Node 1"}, handles: [Handle.source(:bottom)]),
      Node.new("2", %{x: 0, y: 150}, %{label: "Node 2"},
        handles: [Handle.target(:top), Handle.source(:right)]
      ),
      Node.new("3", %{x: 240, y: 150}, %{label: "Node 3"},
        handles: [Handle.target(:top), Handle.target(:left, id: "left")]
      )
    ]

    edges = [
      Edge.new("e1-2", @node_id, "2", type: :smoothstep),
      Edge.new("e1-3", @node_id, "3", type: :smoothstep),
      Edge.new("e2-3", "2", "3", target_handle: "left", animated: true)
    ]

    State.new(nodes: nodes, edges: edges)
  end
end

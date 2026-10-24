defmodule FlowExampleWeb.InteractionLive do
  @moduledoc """
  Live playground for the interaction options ported from xyflow 12.10 – 12.12:
  auto-pan, pan activation keys, middle-mouse panning, selection on drag,
  key combinations, node extent and connection radius.
  """
  use FlowExampleWeb, :live_view

  alias FlowExample.Samples
  alias FlowExampleWeb.{FlowEvents, FlowNodes}
  alias LiveFlow.{Node, State}

  @extent {{-60, -80}, {1160, 420}}

  @defaults %{
    "pan_on_drag" => "default",
    "pan_on_scroll" => "false",
    "pan_on_scroll_mode" => "free",
    "pan_activation_key" => "Space",
    "zoom_on_double_click" => "true",
    "selection_on_drag" => "false",
    "selection_mode" => "partial",
    "auto_pan_on_selection" => "true",
    "auto_pan_on_node_drag" => "true",
    "auto_pan_on_connect" => "true",
    "auto_pan_speed" => "15",
    "node_drag_threshold" => "1",
    "snap_to_grid" => "false",
    "node_extent" => "false",
    "connection_line_type" => "smoothstep",
    "connection_radius" => "20",
    "connection_mode" => "strict",
    "delete_key_code" => "default",
    "disable_keyboard_a11y" => "false"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Interaction")
     |> FlowEvents.assign_flow(Samples.pipeline())
     |> assign_options(@defaults)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      active={:interaction}
      title="Interaction"
      badge="xyflow 12.12"
      subtitle="Panning, selection, dragging and keyboard options ported from the latest xyflow releases. Every change applies live."
    >
      <:actions>
        <.action icon="hero-arrows-pointing-in" phx-click="fit_view">Fit view</.action>
        <.action icon="hero-arrow-path" phx-click="reset">Reset</.action>
      </:actions>

      <.canvas_layout>
        <.live_component
          module={LiveFlow.Components.Flow}
          id="interaction-flow"
          flow={@flow}
          node_types={FlowNodes.types()}
          opts={@flow_opts}
        />

        <:sidebar>
          <.form for={@form} id="interaction-options" phx-change="update_opts">
            <.option_group title="Panning" tag="new">
              <.input
                field={@form[:pan_on_drag]}
                type="select"
                label="Pan on drag"
                class={select_class()}
                options={[
                  {"Left + middle button", "default"},
                  {"Middle button only", "middle"},
                  {"Right button only", "right"},
                  {"Disabled", "false"}
                ]}
              />
              <.input
                field={@form[:pan_activation_key]}
                type="select"
                label="Pan activation key"
                class={select_class()}
                options={[{"Space", "Space"}, {"Control", "Control"}, {"None", "none"}]}
              />
              <.input
                field={@form[:pan_on_scroll]}
                type="checkbox"
                label="Pan on scroll"
                class={switch_class()}
              />
              <.input
                :if={@form[:pan_on_scroll].value == "true"}
                field={@form[:pan_on_scroll_mode]}
                type="select"
                label="Scroll direction"
                class={select_class()}
                options={[{"Free", "free"}, {"Vertical", "vertical"}, {"Horizontal", "horizontal"}]}
              />
              <.input
                field={@form[:zoom_on_double_click]}
                type="checkbox"
                label="Zoom on double click"
                class={switch_class()}
              />
              <.hint>
                Hold
                <.kbd>{key_label(@form[:pan_activation_key].value)}</.kbd>
                to pan from anywhere, even over nodes. The middle button pans too, also from a selection box.
              </.hint>
            </.option_group>

            <.option_group title="Selection" tag="new">
              <.input
                field={@form[:selection_on_drag]}
                type="checkbox"
                label="Select on drag"
                class={switch_class()}
              />
              <.input
                field={@form[:selection_mode]}
                type="select"
                label="Selection mode"
                class={select_class()}
                options={[{"Partial (touching)", "partial"}, {"Full (inside)", "full"}]}
              />
              <.input
                field={@form[:auto_pan_on_selection]}
                type="checkbox"
                label="Auto-pan on selection"
                class={switch_class()}
              />
              <.hint>
                <.kbd>Shift</.kbd>
                + drag draws a selection box. Drag it to the edge of the canvas to auto-pan.
              </.hint>
            </.option_group>

            <.option_group title="Dragging">
              <.input
                field={@form[:auto_pan_on_node_drag]}
                type="checkbox"
                label="Auto-pan on node drag"
                class={switch_class()}
              />
              <.input
                field={@form[:snap_to_grid]}
                type="checkbox"
                label="Snap to grid"
                class={switch_class()}
              />
              <.input
                field={@form[:node_extent]}
                type="checkbox"
                label="Constrain to node extent"
                class={switch_class()}
              />
              <.input
                field={@form[:disable_keyboard_a11y]}
                type="checkbox"
                label="Disable arrow key moves"
                class={switch_class()}
              />
              <.range
                field={@form[:node_drag_threshold]}
                label="Drag threshold (px)"
                min="0"
                max="20"
              />
              <.range field={@form[:auto_pan_speed]} label="Auto-pan speed" min="5" max="40" />
              <.hint>
                Select nodes and use the arrow keys to move them (<.kbd>Shift</.kbd>
                = 4×).
                <.kbd>Esc</.kbd>
                cancels a drag in progress.
              </.hint>
            </.option_group>

            <.option_group title="Connecting">
              <.input
                field={@form[:auto_pan_on_connect]}
                type="checkbox"
                label="Auto-pan on connect"
                class={switch_class()}
              />
              <.input
                field={@form[:connection_line_type]}
                type="select"
                label="Connection line"
                class={select_class()}
                options={[
                  {"Bezier", "bezier"},
                  {"Smoothstep", "smoothstep"},
                  {"Step", "step"},
                  {"Straight", "straight"}
                ]}
              />
              <.input
                field={@form[:connection_mode]}
                type="select"
                label="Connection mode"
                class={select_class()}
                options={[{"Strict (source → target)", "strict"}, {"Loose (any handle)", "loose"}]}
              />
              <.range
                field={@form[:connection_radius]}
                label="Connection radius (px)"
                min="0"
                max="80"
              />
            </.option_group>

            <.option_group title="Keyboard" tag="new">
              <.input
                field={@form[:delete_key_code]}
                type="select"
                label="Delete selection with"
                class={select_class()}
                options={[
                  {"Backspace / Delete", "default"},
                  {"Meta + Backspace", "Meta+Backspace"},
                  {"Meta + Shift + Backspace", "Meta+Shift+Backspace"},
                  {"Disabled", "none"}
                ]}
              />
              <.hint>
                Key options accept combinations of any length. Press
                <.kbd>?</.kbd>
                over the canvas to see every shortcut.
              </.hint>
            </.option_group>
          </.form>

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

  def handle_event("fit_view", _params, socket) do
    send_update(LiveFlow.Components.Flow, id: "interaction-flow", fit_view: true)
    {:noreply, socket}
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> FlowEvents.assign_flow(Samples.pipeline())
     |> assign_options(@defaults)}
  end

  def handle_event("lf:" <> _ = event, params, socket) do
    FlowEvents.handle_event(event, params, socket)
  end

  @impl true
  def handle_info({:lf_node_click, _node_id}, socket), do: {:noreply, socket}

  defp assign_options(socket, params) do
    flow = toggle_extent_area(socket.assigns.flow, params["node_extent"] == "true")

    socket
    |> assign(:form, to_form(params, as: :opts))
    |> assign(:flow, flow)
    |> assign(:flow_opts, flow_opts(params))
  end

  defp flow_opts(params) do
    %{
      controls: true,
      minimap: true,
      minimap_pannable: true,
      background: :dots,
      fit_view_on_init: true,
      pan_on_drag: pan_on_drag(params["pan_on_drag"]),
      pan_on_scroll: params["pan_on_scroll"] == "true",
      pan_on_scroll_mode: atom(params["pan_on_scroll_mode"], [:free, :vertical, :horizontal]),
      pan_activation_key: key_option(params["pan_activation_key"]),
      zoom_on_double_click: params["zoom_on_double_click"] == "true",
      selection_on_drag: params["selection_on_drag"] == "true",
      selection_mode: atom(params["selection_mode"], [:partial, :full]),
      auto_pan_on_selection: params["auto_pan_on_selection"] == "true",
      auto_pan_on_node_drag: params["auto_pan_on_node_drag"] == "true",
      auto_pan_on_connect: params["auto_pan_on_connect"] == "true",
      auto_pan_speed: String.to_integer(params["auto_pan_speed"]),
      node_drag_threshold: String.to_integer(params["node_drag_threshold"]),
      snap_to_grid: params["snap_to_grid"] == "true",
      snap_grid: {20, 20},
      node_extent: if(params["node_extent"] == "true", do: @extent),
      connection_line_type:
        atom(params["connection_line_type"], [:bezier, :smoothstep, :step, :straight]),
      connection_radius: String.to_integer(params["connection_radius"]),
      connection_mode: atom(params["connection_mode"], [:strict, :loose]),
      delete_key_code: delete_keys(params["delete_key_code"]),
      disable_keyboard_a11y: params["disable_keyboard_a11y"] == "true"
    }
  end

  # Maps a form value to one of the allowed atoms (first one is the default)
  defp atom(value, [default | _] = allowed) do
    Enum.find(allowed, default, &(Atom.to_string(&1) == value))
  end

  defp pan_on_drag("default"), do: true
  defp pan_on_drag("middle"), do: [1]
  defp pan_on_drag("right"), do: [2]
  defp pan_on_drag(_), do: false

  defp key_option("none"), do: nil
  defp key_option(key), do: key

  defp delete_keys("default"), do: ["Backspace", "Delete"]
  defp delete_keys("none"), do: nil
  defp delete_keys(combo), do: combo

  defp key_label("none"), do: "—"
  defp key_label(key), do: key

  # The extent is drawn as a passive dashed area behind the nodes
  defp toggle_extent_area(flow, false), do: State.remove_node(flow, "extent")

  defp toggle_extent_area(flow, true) do
    {{x1, y1}, {x2, y2}} = @extent

    State.add_node(
      flow,
      Node.new("extent", %{x: x1, y: y1}, %{label: "node_extent"},
        type: :area,
        class: "lf-extent-area",
        draggable: false,
        selectable: false,
        connectable: false,
        deletable: false,
        resizable: true,
        width: x2 - x1,
        height: y2 - y1,
        z_index: 0
      )
    )
  end
end

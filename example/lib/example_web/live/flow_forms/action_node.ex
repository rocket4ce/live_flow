defmodule ExampleWeb.FlowForms.ActionNode do
  @moduledoc """
  Custom node component that renders an action step (email, API call, database, etc.).
  """

  use Phoenix.LiveComponent

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    action = Map.get(assigns.node.data, :action, "action")
    label = Map.get(assigns.node.data, :label, "Action")
    color = Map.get(assigns.node.data, :color, "#8b5cf6")
    icon = Map.get(assigns.node.data, :icon, :bolt)

    assigns =
      assigns
      |> assign(:action, action)
      |> assign(:label, label)
      |> assign(:color, color)
      |> assign(:icon, icon)

    ~H"""
    <div class="lf-action-node">
      <div class="lf-action-node-header" style={"background: #{@color}"}>
        <.action_icon icon={@icon} />
        <span>{@label}</span>
      </div>
      <div class="lf-action-node-body">
        <div class="lf-action-node-type">{@action}</div>
        <%= if params = Map.get(@node.data, :params) do %>
          <div class="lf-action-node-params">
            <div :for={{key, val} <- params} class="lf-action-node-param">
              <span class="lf-action-param-key">{key}:</span>
              <span class="lf-action-param-val">{val}</span>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  attr :icon, :atom, required: true

  defp action_icon(%{icon: :email} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
    >
      <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
      <polyline points="22,6 12,13 2,6" />
    </svg>
    """
  end

  defp action_icon(%{icon: :database} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
    >
      <ellipse cx="12" cy="5" rx="9" ry="3" />
      <path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3" />
      <path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5" />
    </svg>
    """
  end

  defp action_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="14"
      height="14"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
    >
      <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
    </svg>
    """
  end
end

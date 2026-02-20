defmodule FlotasWeb.FlowForms.ConditionNode do
  @moduledoc """
  Custom node component that renders a decision/condition.
  """

  use Phoenix.LiveComponent

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    condition = Map.get(assigns.node.data, :condition, "condition?")
    description = Map.get(assigns.node.data, :description, "")
    color = Map.get(assigns.node.data, :color, "#f59e0b")

    assigns =
      assigns
      |> assign(:condition, condition)
      |> assign(:description, description)
      |> assign(:color, color)

    ~H"""
    <div class="lf-condition-node">
      <div class="lf-condition-node-header" style={"background: #{@color}"}>
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <path d="M6 3h12l4 6-10 13L2 9z" />
        </svg>
        <span>Condition</span>
      </div>
      <div class="lf-condition-node-body">
        <div class="lf-condition-node-expression">{@condition}</div>
        <div :if={@description != ""} class="lf-condition-node-desc">{@description}</div>
        <div class="lf-condition-node-branches">
          <span class="lf-condition-branch-yes">Yes</span>
          <span class="lf-condition-branch-no">No</span>
        </div>
      </div>
    </div>
    """
  end
end

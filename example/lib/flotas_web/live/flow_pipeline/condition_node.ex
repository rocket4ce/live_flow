defmodule FlotasWeb.FlowPipeline.ConditionNode do
  use Phoenix.LiveComponent

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    data = assigns.node.data
    status = Map.get(data, :status, :idle)
    expression = Map.get(data, :expression, "")
    label = Map.get(data, :label, "Condition")
    branch_taken = Map.get(data, :branch_taken)
    duration = Map.get(data, :duration_ms)

    assigns =
      assigns
      |> assign(:status, status)
      |> assign(:expression, expression)
      |> assign(:label, label)
      |> assign(:branch_taken, branch_taken)
      |> assign(:duration, duration)

    ~H"""
    <div class={"pipeline-node pipeline-condition-node pipeline-node-#{@status}"}>
      <div class="pipeline-node-header" style="background: #ec4899">
        <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M16 3h5v5M4 20L21 3M21 16v5h-5M15 15l6 6M4 4l5 5" />
        </svg>
        <span>{@label}</span>
        <.status_icon status={@status} />
      </div>
      <div class="pipeline-node-body">
        <code class="pipeline-node-code">{@expression}</code>
        <div :if={@branch_taken != nil} class="pipeline-branch-indicator">
          <span class={"pipeline-branch-badge #{if @branch_taken, do: "true", else: "false"}"}>
            {if @branch_taken, do: "TRUE", else: "FALSE"}
          </span>
        </div>
        <div class="pipeline-condition-labels">
          <span class="pipeline-condition-true">True →</span>
          <span class="pipeline-condition-false">False ↓</span>
        </div>
        <div :if={@status == :success && @duration} class="pipeline-node-meta">
          {@duration}ms
        </div>
      </div>
    </div>
    """
  end

  defp status_icon(%{status: :running} = assigns) do
    ~H"""
    <span class="pipeline-status-badge running">running</span>
    """
  end

  defp status_icon(%{status: :success} = assigns) do
    ~H"""
    <span class="pipeline-status-badge success">done</span>
    """
  end

  defp status_icon(%{status: :error} = assigns) do
    ~H"""
    <span class="pipeline-status-badge error">error</span>
    """
  end

  defp status_icon(assigns) do
    ~H"""
    """
  end
end

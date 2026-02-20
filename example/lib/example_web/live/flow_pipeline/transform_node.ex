defmodule ExampleWeb.FlowPipeline.TransformNode do
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
    label = Map.get(data, :label, "Transform")
    duration = Map.get(data, :duration_ms)

    assigns =
      assigns
      |> assign(:status, status)
      |> assign(:expression, expression)
      |> assign(:label, label)
      |> assign(:duration, duration)

    ~H"""
    <div class={"pipeline-node pipeline-node-#{@status}"}>
      <div class="pipeline-node-header" style="background: #f59e0b">
        <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="16 18 22 12 16 6" /><polyline points="8 6 2 12 8 18" />
        </svg>
        <span>{@label}</span>
        <.status_icon status={@status} />
      </div>
      <div class="pipeline-node-body">
        <code class="pipeline-node-code">{@expression}</code>
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

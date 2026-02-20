defmodule ExampleWeb.FlowPipeline.DelayNode do
  use Phoenix.LiveComponent

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    data = assigns.node.data
    status = Map.get(data, :status, :idle)
    delay = Map.get(data, :delay, 1000)
    duration = Map.get(data, :duration_ms)

    assigns =
      assigns
      |> assign(:status, status)
      |> assign(:delay, delay)
      |> assign(:duration, duration)

    ~H"""
    <div class={"pipeline-node pipeline-node-#{@status}"}>
      <div class="pipeline-node-header" style="background: #06b6d4">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <circle cx="12" cy="12" r="10" /><polyline points="12 6 12 12 16 14" />
        </svg>
        <span>Delay</span>
        <.status_icon status={@status} />
      </div>
      <div class="pipeline-node-body">
        <div class="pipeline-node-config">
          {@delay}ms
        </div>
        <div :if={@status == :success && @duration} class="pipeline-node-meta">
          {@duration}ms actual
        </div>
      </div>
    </div>
    """
  end

  defp status_icon(%{status: :running} = assigns) do
    ~H"""
    <span class="pipeline-status-badge running">waiting</span>
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

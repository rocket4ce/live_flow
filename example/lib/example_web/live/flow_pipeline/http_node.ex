defmodule ExampleWeb.FlowPipeline.HttpNode do
  use Phoenix.LiveComponent

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    data = assigns.node.data
    status = Map.get(data, :status, :idle)
    method = Map.get(data, :method, "GET")
    url = Map.get(data, :url, "")
    output = Map.get(data, :output)
    duration = Map.get(data, :duration_ms)

    assigns =
      assigns
      |> assign(:status, status)
      |> assign(:method, method)
      |> assign(:url, url)
      |> assign(:output, output)
      |> assign(:duration, duration)

    ~H"""
    <div class={"pipeline-node pipeline-node-#{@status}"}>
      <div class="pipeline-node-header" style="background: #3b82f6">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <circle cx="12" cy="12" r="10" /><line x1="2" y1="12" x2="22" y2="12" />
          <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
        </svg>
        <span>HTTP Request</span>
        <.status_icon status={@status} />
      </div>
      <div class="pipeline-node-body">
        <div class="pipeline-node-config">
          <span class="pipeline-method-badge">{@method}</span>
          <span class="pipeline-url-text">{@url}</span>
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

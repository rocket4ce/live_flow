defmodule ExampleWeb.FlowPipeline.StartNode do
  use Phoenix.LiveComponent

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    status = Map.get(assigns.node.data, :status, :idle)
    payload = Map.get(assigns.node.data, :payload, %{})
    payload_preview = inspect(payload, pretty: true, limit: 3)

    assigns =
      assigns
      |> assign(:status, status)
      |> assign(:payload_preview, payload_preview)

    ~H"""
    <div class={"pipeline-node pipeline-node-#{@status}"}>
      <div class="pipeline-node-header" style="background: #22c55e">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="14"
          height="14"
          viewBox="0 0 24 24"
          fill="currentColor"
        >
          <polygon points="5 3 19 12 5 21 5 3" />
        </svg>
        <span>Start</span>
        <.status_icon status={@status} />
      </div>
      <div class="pipeline-node-body">
        <pre class="pipeline-node-preview">{@payload_preview}</pre>
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

defmodule ExampleWeb.FlowPipeline.LogNode do
  use Phoenix.LiveComponent

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    data = assigns.node.data
    status = Map.get(data, :status, :idle)
    label = Map.get(data, :label, "Log")
    output = Map.get(data, :output)
    duration = Map.get(data, :duration_ms)
    output_preview = if output, do: format_output(output), else: "waiting..."

    assigns =
      assigns
      |> assign(:status, status)
      |> assign(:label, label)
      |> assign(:output_preview, output_preview)
      |> assign(:duration, duration)

    ~H"""
    <div class={"pipeline-node pipeline-node-#{@status}"}>
      <div class="pipeline-node-header" style="background: #64748b">
        <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
          <polyline points="14 2 14 8 20 8" /><line x1="16" y1="13" x2="8" y2="13" />
          <line x1="16" y1="17" x2="8" y2="17" />
        </svg>
        <span>{@label}</span>
        <.status_icon status={@status} />
      </div>
      <div class="pipeline-node-body">
        <pre class={"pipeline-node-output #{if @status == :success, do: "has-data", else: ""}"}>{@output_preview}</pre>
        <div :if={@status == :success && @duration} class="pipeline-node-meta">
          {@duration}ms
        </div>
      </div>
    </div>
    """
  end

  defp format_output(output) when is_binary(output) do
    if String.length(output) > 80 do
      String.slice(output, 0, 80) <> "..."
    else
      output
    end
  end

  defp format_output(output) do
    output
    |> inspect(pretty: true, limit: 5, printable_limit: 80)
    |> then(fn s -> if String.length(s) > 120, do: String.slice(s, 0, 120) <> "...", else: s end)
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

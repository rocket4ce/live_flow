defmodule LiveFlow.Validation.Connection do
  @moduledoc """
  Helper to validate and create edges from `lf:connect_end` event params.

  Combines validation + edge creation in a single call, reducing boilerplate
  in parent LiveView `handle_event` clauses.

  ## Example

      def handle_event("lf:connect_end", params, socket) do
        case LiveFlow.Validation.Connection.validate_and_create(socket.assigns.flow, params) do
          {:ok, edge} ->
            flow = State.add_edge(socket.assigns.flow, edge)
            {:noreply, assign(socket, flow: flow)}

          {:error, _reason} ->
            {:noreply, socket}
        end
      end

  ## Custom validators

      validate_and_create(flow, params,
        validators: [
          &Validation.no_duplicate_edges/2,
          &Validation.no_cycles/2,
          fn flow, params -> Validation.max_connections(flow, params, max: 1) end
        ],
        edge_opts: [animated: true]
      )
  """

  alias LiveFlow.{Edge, Validation}

  @doc """
  Validates connection params and creates an edge if valid.

  Returns `{:ok, edge}` or `{:error, reason}`.

  ## Options

    * `:validators` — list of validator functions (default: `Validation.preset(:default)`)
    * `:edge_opts` — extra options passed to `Edge.new/4`
  """
  @spec validate_and_create(LiveFlow.State.t(), map(), keyword()) ::
          {:ok, Edge.t()} | {:error, String.t()}
  def validate_and_create(flow, params, opts \\ []) do
    validators = Keyword.get(opts, :validators, Validation.preset(:default))
    edge_opts = Keyword.get(opts, :edge_opts, [])

    conn_params = normalize_params(params)

    source = conn_params.source
    target = conn_params.target

    if source && target && source != target do
      case Validation.validate(flow, conn_params, validators) do
        :ok ->
          edge_id = "e-#{System.unique_integer([:positive])}"

          edge =
            Edge.new(
              edge_id,
              source,
              target,
              Keyword.merge(edge_opts,
                source_handle: conn_params.source_handle,
                target_handle: conn_params.target_handle
              )
            )

          {:ok, edge}

        {:error, _} = error ->
          error
      end
    else
      {:error, "Invalid source or target"}
    end
  end

  defp normalize_params(%{} = params) do
    %{
      source: params["source"] || params[:source],
      target: params["target"] || params[:target],
      source_handle: params["source_handle"] || params[:source_handle],
      target_handle: params["target_handle"] || params[:target_handle]
    }
  end
end

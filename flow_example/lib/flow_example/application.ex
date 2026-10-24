defmodule FlowExample.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FlowExampleWeb.Telemetry,
      FlowExample.Repo,
      {DNSCluster, query: Application.get_env(:flow_example, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FlowExample.PubSub},
      # Shared state and presence of the collaborative example
      FlowExample.FlowStore,
      FlowExampleWeb.Presence,
      # Start to serve requests, typically the last entry
      FlowExampleWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FlowExample.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FlowExampleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

defmodule Flotas.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FlotasWeb.Telemetry,
      Flotas.Repo,
      {DNSCluster, query: Application.get_env(:flotas, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Flotas.PubSub},
      Flotas.FlowRealtimeStore,
      FlotasWeb.Presence,
      # Start to serve requests, typically the last entry
      FlotasWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Flotas.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FlotasWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

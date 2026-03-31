defmodule Jalka2026.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies) || []

    children = [
      {Cluster.Supervisor, [topologies, [name: Jalka2026.ClusterSupervisor]]},
      # Start the Ecto repository
      Jalka2026.Repo,
      # Start the Telemetry supervisor
      Jalka2026Web.Telemetry,
      # Start the Performance Alerter for monitoring and alerts
      Jalka2026.Telemetry.PerformanceAlerter,
      # Start the PubSub system
      {Phoenix.PubSub, name: Jalka2026.PubSub},
      # Start the ETS cache for immutable tournament data (teams, groups, competition)
      Jalka2026.Football.Cache,
      # Start the Endpoint (http/https)
      Jalka2026Web.Endpoint,
      # Start a worker by calling: Jalka2026.Worker.start_link(arg)
      # {Jalka2026.Worker, arg},
      Jalka2026.Leaderboard
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Jalka2026.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Jalka2026Web.Endpoint.config_change(changed, removed)
    :ok
  end
end

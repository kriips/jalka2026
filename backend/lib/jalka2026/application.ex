defmodule Jalka2026.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Jalka2026.Repo,
      # Finch for HTTP calls (US2 ingestion)
      {Finch, name: Jalka2026Finch}
      # Ingestion supervisor will be added here (T005) e.g.
      # {Jalka2026.Ingestion.Supervisor, []}
    ]

    opts = [strategy: :one_for_one, name: Jalka2026.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

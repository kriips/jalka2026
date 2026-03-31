defmodule Jalka2026.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :jalka2026
  require Logger

  def migrate do
    load_app()

    for repo <- repos() do
      case Jalka2026.Repo.__adapter__().storage_up(Jalka2026.Repo.config()) do
        :ok ->
          Logger.info("The database has been created.")

        {:error, :already_up} ->
          Logger.info("The database already exists.")

        {:error, term} ->
          Logger.info("An error occurred while creating the database: #{inspect(term)}")
      end

      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end

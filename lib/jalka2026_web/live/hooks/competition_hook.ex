defmodule Jalka2026Web.Hooks.CompetitionHook do
  @moduledoc """
  LiveView on_mount hook that assigns `competition_id` and `competition`
  from the current active competition.

  Ensures every LiveView has consistent competition context without
  duplicating resolution logic in individual mount/3 callbacks.
  """

  import Phoenix.Component, only: [assign_new: 3]

  alias Jalka2026.Competitions

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign_new(:competition_id, fn -> Competitions.current_id() end)
      |> assign_new(:competition, fn -> Competitions.current() end)

    {:cont, socket}
  end
end

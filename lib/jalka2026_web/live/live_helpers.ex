defmodule Jalka2026Web.LiveHelpers do
  @moduledoc """
  Shared helpers imported into every LiveView via `use Jalka2026Web, :live_view`.

  Auth-related assigns (`current_user`, `competition`) are now handled by
  `Jalka2026Web.Hooks.AuthHook` and `Jalka2026Web.Hooks.CompetitionHook`
  registered as `on_mount` hooks in the router.
  """

  @doc """
  Checks if predictions are still open (before the tournament deadline).
  Returns true if predictions can still be made, false if the deadline has passed.
  """
  def predictions_open? do
    deadline = Application.get_env(:jalka2026, :prediction_deadline)
    deadline == nil or DateTime.compare(DateTime.utc_now(), deadline) == :lt
  end
end

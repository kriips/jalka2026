defmodule Jalka2026Web.LiveHelpers do
  @estonian_time_zone "Europe/Tallinn"
  @utc_time_zone "Etc/UTC"

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

  @doc """
  Formats a match date+time in Estonian local time as `DD.MM.YYYY HH:MM` (no seconds).
  """
  def format_match_time(nil), do: ""

  def format_match_time(%NaiveDateTime{} = dt),
    do: dt |> match_time_in_estonia() |> format_datetime()

  def format_match_time(%DateTime{} = dt),
    do: dt |> Timex.Timezone.convert(@estonian_time_zone) |> format_datetime()

  defp match_time_in_estonia(%NaiveDateTime{} = dt) do
    dt
    |> Timex.to_datetime(@utc_time_zone)
    |> Timex.Timezone.convert(@estonian_time_zone)
  end

  defp format_datetime(dt), do: Calendar.strftime(dt, "%d.%m.%Y %H:%M")
end

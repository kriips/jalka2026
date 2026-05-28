defmodule Jalka2026Web.UserPredictionLive.Navigate do
  use Jalka2026Web, :live_view

  alias Jalka2026.Football
  alias Jalka2026Web.Resolvers.FootballResolver

  # Total: 72 group predictions + 31 bracket slots (16+8+4+2+1)
  @total_predictions 103

  @impl true
  def mount(_params, _session, socket) do
    filled_predictions = FootballResolver.filled_predictions(socket.assigns.current_user.id)
    bracket_predictions = Football.get_bracket_predictions_by_user(socket.assigns.current_user.id)
    progress = count_progress(filled_predictions, bracket_predictions)
    progress_percentage = progress_percentage(progress)

    playoffs_disabled =
      case progress < 72 do
        true -> "disabled"
        _ -> ""
      end

    playoffs_filled =
      case progress == @total_predictions do
        true -> ""
        _ -> "button-outline"
      end

    deadline = Application.get_env(:jalka2026, :prediction_deadline)
    predictions_open = Jalka2026Web.LiveHelpers.predictions_open?()

    {:ok,
     assign(socket,
       filled: map_style(filled_predictions),
       progress: progress_percentage,
       playoffs_disabled: playoffs_disabled,
       playoffs_filled: playoffs_filled,
       prediction_deadline: deadline,
       predictions_open: predictions_open
     )}
  end

  @impl true
  def handle_event("predictions_locked", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:error, "Ennustamine on suletud - turniir on alanud")
     |> redirect(to: "/")}
  end

  defp map_style(filled_predictions) do
    filled_predictions
    |> Enum.map(fn {group, count} ->
      if count != 6 do
        {group, "button-outline"}
      else
        {group, ""}
      end
    end)
    |> Enum.into(%{})
  end

  defp count_progress(filled_predictions, bracket_predictions) do
    group_count =
      filled_predictions
      |> Enum.reduce(0, fn {_group, count}, acc ->
        acc + count
      end)

    bracket_count = length(bracket_predictions)

    group_count + bracket_count
  end

  defp progress_percentage(progress) do
    round(progress * 100 / @total_predictions)
  end
end

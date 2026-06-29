defmodule Jalka2026Web.FootballLive.User do
  use Jalka2026Web, :live_view

  alias Jalka2026.Badges
  alias Jalka2026.Football
  alias Jalka2026.Football.Qualifiers
  alias Jalka2026.Football.TeamTranslations
  alias Jalka2026Web.Resolvers.AccountsResolver
  alias Jalka2026Web.Resolvers.FootballResolver

  @impl true
  def mount(params, _session, socket) do
    user_id = params["id"]
    user_id_int = String.to_integer(user_id)

    favorite_teams = Football.get_user_favorite_teams(user_id_int)
    bias_stats = Football.get_prediction_bias_stats(user_id_int)
    user_badges = Badges.get_user_badges(user_id_int)

    predictions =
      FootballResolver.get_predictions_by_user(user_id)
      |> FootballResolver.add_correctness()

    prediction_stream_items =
      predictions
      |> Enum.with_index()
      |> Enum.map(fn {{prediction, correct_result, correct_score}, idx} ->
        %{
          id: "prediction-#{idx}",
          prediction: prediction,
          correct_result: correct_result,
          correct_score: correct_score
        }
      end)

    {:ok,
     socket
     |> assign(
       predictions: predictions,
       user: AccountsResolver.get_user(user_id),
       playoff_predictions:
         FootballResolver.get_playoff_predictions_with_team_names(user_id)
         |> FootballResolver.add_playoff_correctness(),
       favorite_teams: favorite_teams,
       bias_stats: bias_stats,
       user_badges: user_badges,
       predicted_last_32_names: build_predicted_last_32_names(user_id_int)
     )
     |> stream(:prediction_rows, prediction_stream_items)}
  end

  # "32 parimat" stage: the user's predicted round-of-32 qualifiers (group qualifiers with their
  # R32 swap-overrides applied). Returns `[%{name, correct}]` where `correct` is true if the team
  # actually reached the round of 32, so the view can highlight the correct picks.
  defp build_predicted_last_32_names(user_id) do
    actual = Qualifiers.actual_last_32()

    user_id
    |> Qualifiers.predicted_last_32()
    |> Enum.map(&Football.get_team/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn team ->
      %{name: TeamTranslations.translate(team.name), correct: team.id in actual}
    end)
    |> Enum.sort_by(& &1.name)
  end
end

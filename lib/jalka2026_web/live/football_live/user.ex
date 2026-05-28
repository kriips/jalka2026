defmodule Jalka2026Web.FootballLive.User do
  use Jalka2026Web, :live_view

  alias Jalka2026.Badges
  alias Jalka2026.Football
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
       user_badges: user_badges
     )
     |> stream(:prediction_rows, prediction_stream_items)}
  end
end

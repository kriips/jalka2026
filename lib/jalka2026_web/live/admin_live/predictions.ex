defmodule Jalka2026Web.AdminLive.Predictions do
  use Jalka2026Web, :live_view

  alias Jalka2026Web.Resolvers.{AccountsResolver, FootballResolver}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    users = AccountsResolver.list_users()
    validation_results = validate_all_predictions(users)

    {:noreply,
     socket
     |> assign(:page_title, "Ennustuste valideerimine")
     |> assign(:users, users)
     |> assign(:validation_results, validation_results)
     |> assign(:filter, :all)}
  end

  @impl true
  def handle_event("filter", %{"type" => filter_type}, socket) do
    filter = String.to_existing_atom(filter_type)

    {:noreply, assign(socket, :filter, filter)}
  end

  defp validate_all_predictions(users) do
    users
    |> Enum.map(fn user ->
      group_predictions = FootballResolver.filled_predictions(user.id)
      group_count = group_predictions |> Map.values() |> Enum.sum()

      playoff_predictions = FootballResolver.get_playoff_predictions(user.id)

      # Calculate playoff counts by phase
      phase_counts = %{
        32 => length(Map.get(playoff_predictions, 32, [])),
        16 => length(Map.get(playoff_predictions, 16, [])),
        8 => length(Map.get(playoff_predictions, 8, [])),
        4 => length(Map.get(playoff_predictions, 4, [])),
        2 => length(Map.get(playoff_predictions, 2, []))
      }

      # Expected counts per phase. Predictions are derived from bracket winner
      # picks, so phase P holds the winners picked in that round: 16 in the
      # round of 32, 8 in the round of 16, 4 in the QFs, 2 in the SFs and the
      # single champion at phase 2.
      expected_counts = %{32 => 16, 16 => 8, 8 => 4, 4 => 2, 2 => 1}

      # Validate
      group_valid = group_count == 72

      playoff_valid =
        Enum.all?(expected_counts, fn {phase, expected} ->
          Map.get(phase_counts, phase, 0) == expected
        end)

      incomplete_groups =
        group_predictions
        |> Enum.filter(fn {_group, count} -> count < 6 end)
        |> Enum.map(fn {group, count} -> {String.replace(group, "Alagrupp ", ""), count} end)

      incomplete_phases =
        expected_counts
        |> Enum.filter(fn {phase, expected} ->
          Map.get(phase_counts, phase, 0) != expected
        end)
        |> Enum.map(fn {phase, expected} ->
          {phase, Map.get(phase_counts, phase, 0), expected}
        end)

      %{
        user_id: user.id,
        user_name: user.name,
        group_count: group_count,
        group_valid: group_valid,
        playoff_valid: playoff_valid,
        phase_counts: phase_counts,
        incomplete_groups: incomplete_groups,
        incomplete_phases: incomplete_phases,
        overall_valid: group_valid && playoff_valid
      }
    end)
    |> Enum.sort_by(& &1.user_name)
  end

  def filtered_results(results, filter) do
    case filter do
      :all -> results
      :valid -> Enum.filter(results, & &1.overall_valid)
      :invalid -> Enum.filter(results, &(!&1.overall_valid))
      :incomplete_groups -> Enum.filter(results, &(!&1.group_valid))
      :incomplete_playoffs -> Enum.filter(results, &(!&1.playoff_valid))
    end
  end

  def summary_stats(results) do
    total = length(results)
    valid = Enum.count(results, & &1.overall_valid)
    invalid = total - valid
    incomplete_groups = Enum.count(results, &(!&1.group_valid))
    incomplete_playoffs = Enum.count(results, &(!&1.playoff_valid))

    %{
      total: total,
      valid: valid,
      invalid: invalid,
      incomplete_groups: incomplete_groups,
      incomplete_playoffs: incomplete_playoffs,
      completion_rate: if(total > 0, do: Float.round(valid / total * 100, 1), else: 0.0)
    }
  end
end

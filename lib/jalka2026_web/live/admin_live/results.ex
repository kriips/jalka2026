defmodule Jalka2026Web.AdminLive.Results do
  use Jalka2026Web, :live_view

  alias Jalka2026.Football
  alias Jalka2026.Leaderboard
  alias Jalka2026Web.Resolvers.FootballResolver

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"type" => "groups"}, _url, socket) do
    matches = FootballResolver.list_matches()
    groups = group_matches_by_group(matches)
    selected_group = "A"

    {:noreply,
     socket
     |> assign(:page_title, "Alagrupitulemused")
     |> assign(:type, :groups)
     |> assign(:groups, groups)
     |> assign(:matches, matches)
     |> assign(:selected_group, selected_group)
     |> stream(:match_rows, matches_to_stream_items(Map.get(groups, selected_group, [])),
       reset: true
     )}
  end

  @impl true
  def handle_params(%{"type" => "playoffs"}, _url, socket) do
    teams = Football.get_teams()
    playoff_results = FootballResolver.list_playoff_results()
    teams_by_group = FootballResolver.get_teams_by_group()

    {:noreply,
     socket
     |> assign(:page_title, "Playoff-tulemused")
     |> assign(:type, :playoffs)
     |> assign(:teams, teams)
     |> assign(:teams_by_group, teams_by_group)
     |> assign(:playoff_results, playoff_results)
     |> assign(:phases, playoff_phases())
     |> assign(:selected_phase, Jalka2026.Scoring.last_32_phase())
     |> stream(:match_rows, [], reset: true)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, push_navigate(socket, to: Routes.admin_results_path(socket, :index, "groups"))}
  end

  @impl true
  def handle_event("select_group", %{"group" => group}, socket) do
    {:noreply,
     socket
     |> assign(:selected_group, group)
     |> stream(:match_rows, matches_to_stream_items(Map.get(socket.assigns.groups, group, [])),
       reset: true
     )}
  end

  @impl true
  def handle_event("select_phase", %{"phase" => phase}, socket) do
    {:noreply, assign(socket, :selected_phase, String.to_integer(phase))}
  end

  @impl true
  def handle_event(
        "save_result",
        %{"match_id" => match_id, "home_score" => home_score, "away_score" => away_score},
        socket
      ) do
    case {parse_score(home_score), parse_score(away_score)} do
      {{:ok, h}, {:ok, a}} ->
        case FootballResolver.update_match(%{
               "game_id" => match_id,
               "home_score" => Integer.to_string(h),
               "away_score" => Integer.to_string(a)
             }) do
          {:ok, _results} ->
            matches = FootballResolver.list_matches()
            groups = group_matches_by_group(matches)

            {:noreply,
             socket
             |> put_flash(:info, "Tulemus salvestatud")
             |> assign(:matches, matches)
             |> assign(:groups, groups)
             |> stream(
               :match_rows,
               matches_to_stream_items(Map.get(groups, socket.assigns.selected_group, [])),
               reset: true
             )}

          {:error, failed_step, reason, _changes} ->
            {:noreply,
             put_flash(socket, :error, "Viga sammus #{failed_step}: #{inspect(reason)}")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Vigane skoor")}
    end
  end

  @impl true
  def handle_event("save_playoff_result", %{"team_id" => team_id, "phase" => phase}, socket) do
    case FootballResolver.update_playoff_result(%{
           "team_id" => team_id,
           "phase" => phase
         }) do
      {:ok, _results} ->
        playoff_results = FootballResolver.list_playoff_results()

        {:noreply,
         socket
         |> put_flash(:info, "Playoff-tulemus salvestatud")
         |> assign(:playoff_results, playoff_results)}

      {:error, failed_step, reason, _changes} ->
        {:noreply, put_flash(socket, :error, "Viga sammus #{failed_step}: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("recalc_leaderboard", _params, socket) do
    Leaderboard.recalc_leaderboard()
    {:noreply, put_flash(socket, :info, "Edetabel uuendatud")}
  end

  defp matches_to_stream_items(matches) do
    Enum.map(matches, fn match ->
      %{id: "match-row-#{match.id}", match: match}
    end)
  end

  defp group_matches_by_group(matches) do
    matches
    |> Enum.group_by(fn match ->
      match.group |> String.replace("Alagrupp ", "")
    end)
    |> Enum.sort_by(fn {group, _} -> group end)
    |> Enum.into(%{})
  end

  defp parse_score(score) when is_binary(score) do
    case Integer.parse(score) do
      {n, ""} when n >= 0 -> {:ok, n}
      _ -> :error
    end
  end

  defp parse_score(_), do: :error

  # Phases the admin can mark, in tournament order. The leading phase is the "32 parimat"
  # (reached round of 32) stage; the rest are the bracket winner-pick phases.
  def playoff_phases, do: [Jalka2026.Scoring.last_32_phase(), 32, 16, 8, 4, 2]

  def phase_name(phase) do
    cond do
      phase == Jalka2026.Scoring.last_32_phase() -> "32 parimat"
      phase == 32 -> "Kaheksandikfinaal (32)"
      phase == 16 -> "Veerandfinaal (16)"
      phase == 8 -> "Poolfinaal (8)"
      phase == 4 -> "Finaal (4)"
      phase == 2 -> "Võitja (2)"
      true -> "Faas #{phase}"
    end
  end

  def team_in_phase?(playoff_results, team_id, phase) do
    Enum.any?(playoff_results, fn result ->
      result.team_id == team_id && result.phase == phase
    end)
  end
end

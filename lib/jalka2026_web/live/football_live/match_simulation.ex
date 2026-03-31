defmodule Jalka2026Web.FootballLive.MatchSimulation do
  use Jalka2026Web, :live_view

  alias Jalka2026.Football
  alias Jalka2026.Football.MatchSimulation, as: Simulator
  alias Jalka2026Web.TelemetryHooks
  alias Jalka2026.Telemetry.Events, as: TelemetryEvents

  @impl true
  def mount(_params, _session, socket) do
    TelemetryHooks.with_mount_telemetry(__MODULE__, socket, fn ->
      teams = Football.get_teams() |> Enum.sort_by(& &1.name)

      {:ok,
       assign(socket,
         teams: teams,
         team1: nil,
         team2: nil,
         simulation_results: nil,
         team1_breakdown: nil,
         team2_breakdown: nil,
         simulating: false,
         num_simulations: 10_000
       )}
    end)
  end

  @impl true
  def handle_event("select_team1", %{"team" => team_code}, socket) do
    team = Enum.find(socket.assigns.teams, &(&1.code == team_code))
    {:noreply, assign(socket, team1: team, simulation_results: nil)}
  end

  def handle_event("select_team2", %{"team" => team_code}, socket) do
    team = Enum.find(socket.assigns.teams, &(&1.code == team_code))
    {:noreply, assign(socket, team2: team, simulation_results: nil)}
  end

  def handle_event("simulate", _params, socket) do
    team1 = socket.assigns.team1
    team2 = socket.assigns.team2

    if team1 && team2 && team1.code != team2.code do
      socket = assign(socket, simulating: true)
      send(self(), {:run_simulation, team1.code, team2.code})
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("clear", _params, socket) do
    {:noreply,
     assign(socket,
       team1: nil,
       team2: nil,
       simulation_results: nil,
       team1_breakdown: nil,
       team2_breakdown: nil,
       simulating: false
     )}
  end

  @impl true
  def handle_info({:run_simulation, team1_code, team2_code}, socket) do
    metadata = %{
      home_team: team1_code,
      away_team: team2_code,
      simulation_count: socket.assigns.num_simulations
    }

    {results, team1_breakdown, team2_breakdown} =
      TelemetryEvents.span_match_simulation(metadata, fn ->
        results =
          Simulator.simulate_match(team1_code, team2_code,
            simulations: socket.assigns.num_simulations
          )

        team1_breakdown = Simulator.get_strength_breakdown(team1_code, team2_code)
        team2_breakdown = Simulator.get_strength_breakdown(team2_code, team1_code)

        {results, team1_breakdown, team2_breakdown}
      end)

    {:noreply,
     assign(socket,
       simulation_results: results,
       team1_breakdown: team1_breakdown,
       team2_breakdown: team2_breakdown,
       simulating: false
     )}
  end

  def probability_color(percentage) do
    cond do
      percentage >= 10.0 -> "probability-high"
      percentage >= 5.0 -> "probability-medium"
      percentage >= 2.0 -> "probability-low"
      percentage > 0 -> "probability-minimal"
      true -> "probability-zero"
    end
  end

  def strength_color(value) do
    cond do
      value >= 1.2 -> "strength-high"
      value >= 1.0 -> "strength-medium"
      value >= 0.8 -> "strength-low"
      true -> "strength-very-low"
    end
  end

  def format_percentage(value) do
    :erlang.float_to_binary(value, decimals: 1)
  end
end

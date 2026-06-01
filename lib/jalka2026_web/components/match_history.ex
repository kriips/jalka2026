defmodule Jalka2026Web.Components.MatchHistory do
  @moduledoc """
  Shared "Ajalugu" (history) dropdown for a match.

  Renders the collapsible head-to-head / World Cup history panel. Used by the
  single game page; the markup mirrors the inline panel on the group
  predictions page (`prediction_live/groups.html.heex`), which can adopt this
  component to dedupe.

  The parent LiveView is responsible for the `toggle_analysis` event and for
  loading `detailed_history` (see `load_history/2`).
  """
  use Phoenix.Component

  alias Jalka2026.Football
  alias Jalka2026.Football.TeamTranslations

  attr :expanded, :boolean, required: true
  attr :simulating, :boolean, required: true
  attr :detailed_history, :map, default: nil
  attr :home_team_name, :string, required: true
  attr :away_team_name, :string, required: true
  attr :match_id, :any, required: true
  attr :toggle_event, :string, default: "toggle_analysis"
  attr :toggle_target, :any, default: nil

  def history_panel(assigns) do
    ~H"""
    <div class="match-analysis-section">
      <button
        type="button"
        class={"match-analysis-toggle #{if @expanded, do: "active", else: ""}"}
        phx-click={@toggle_event}
        phx-target={@toggle_target}
        phx-value-match-id={@match_id}
        aria-expanded={@expanded}
        aria-controls={"analysis-panel-#{@match_id}"}
      >
        <span class="analysis-toggle-icon"><%= if @expanded, do: "▼", else: "▶" %></span>
        <span class="analysis-toggle-text">Ajalugu</span>
      </button>

      <%= if @expanded do %>
        <div class="match-analysis-panel" id={"analysis-panel-#{@match_id}"}>
          <%= if @simulating or @detailed_history == nil do %>
            <div class="analysis-loading">
              <div class="spinner-small"></div>
              <span>Laen andmeid...</span>
            </div>
          <% else %>
            <div class="analysis-content">
              <!-- Head to Head Stats -->
              <%= if @detailed_history.stats && @detailed_history.stats.total_matches > 0 do %>
                <div class="h2h-compact">
                  <div class="h2h-header">Omavahelised kohtumised (<%= @detailed_history.stats.total_matches %>)</div>
                  <div class="h2h-stats-row">
                    <div class="h2h-stat-item">
                      <span class="h2h-stat-team"><%= @home_team_name %></span>
                      <span class="h2h-stat-value wins"><%= @detailed_history.stats.team1_wins %></span>
                    </div>
                    <div class="h2h-stat-item draws">
                      <span class="h2h-stat-label">Viiki</span>
                      <span class="h2h-stat-value"><%= @detailed_history.stats.draws %></span>
                    </div>
                    <div class="h2h-stat-item">
                      <span class="h2h-stat-team"><%= @away_team_name %></span>
                      <span class="h2h-stat-value wins"><%= @detailed_history.stats.team2_wins %></span>
                    </div>
                  </div>
                  <div class="h2h-goals-row">
                    Väravaid: <%= @detailed_history.stats.team1_goals %> - <%= @detailed_history.stats.team2_goals %>
                  </div>
                </div>
              <% else %>
                <div class="h2h-empty">Omavahelised kohtumised puuduvad</div>
              <% end %>

              <!-- World Cup Matches (all, no limit) -->
              <%= if length(@detailed_history.world_cup_matches) > 0 do %>
                <div class="wc-history-compact">
                  <div class="wc-history-header">MM-kohtumised</div>
                  <div class="wc-matches-list-compact">
                    <%= for wc_match <- @detailed_history.world_cup_matches do %>
                      <div class="wc-match-item-compact">
                        <span class="wc-match-date"><%= format_date(wc_match.date) %></span>
                        <span class="wc-match-score"><%= TeamTranslations.translate(wc_match.home_team_name) %> <%= wc_match.home_score %>-<%= wc_match.away_score %> <%= TeamTranslations.translate(wc_match.away_team_name) %></span>
                        <%= if wc_match.stage do %>
                          <span class="wc-match-stage"><%= Football.stage_display_name(wc_match.stage) %></span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <!-- WC Stats Comparison by Tournament -->
              <%= if @detailed_history.team1_wc_stats && @detailed_history.team1_wc_stats.matches_played > 0 || @detailed_history.team2_wc_stats && @detailed_history.team2_wc_stats.matches_played > 0 do %>
                <div class="wc-stats-section">
                  <div class="wc-stats-header">MM-ajalugu üldiselt</div>

                  <!-- Overall totals -->
                  <div class="wc-stats-totals">
                    <div class="wc-stats-team-total">
                      <span class="wc-stats-team-name"><%= @home_team_name %></span>
                      <%= if @detailed_history.team1_wc_stats && @detailed_history.team1_wc_stats.matches_played > 0 do %>
                        <span class="wc-stats-total-line">Kokku: <%= @detailed_history.team1_wc_stats.matches_played %> mängu</span>
                        <span class="wc-stats-total-line">V/Vi/K: <%= @detailed_history.team1_wc_stats.wins %>/<%= @detailed_history.team1_wc_stats.draws %>/<%= @detailed_history.team1_wc_stats.losses %></span>
                        <%= if @detailed_history.team1_wc_positions.total_top_4 > 0 do %>
                          <span class="wc-stats-positions">
                            <%= if @detailed_history.team1_wc_positions.counts.gold > 0 do %><span class="wc-position wc-gold" title="1. koht"><%= @detailed_history.team1_wc_positions.counts.gold %>x</span><% end %>
                            <%= if @detailed_history.team1_wc_positions.counts.silver > 0 do %><span class="wc-position wc-silver" title="2. koht"><%= @detailed_history.team1_wc_positions.counts.silver %>x</span><% end %>
                            <%= if @detailed_history.team1_wc_positions.counts.bronze > 0 do %><span class="wc-position wc-bronze" title="3. koht"><%= @detailed_history.team1_wc_positions.counts.bronze %>x</span><% end %>
                            <%= if @detailed_history.team1_wc_positions.counts.fourth > 0 do %><span class="wc-position wc-fourth" title="4. koht"><%= @detailed_history.team1_wc_positions.counts.fourth %>x</span><% end %>
                          </span>
                        <% end %>
                      <% else %>
                        <span class="wc-stats-empty">MM-ajalugu puudub</span>
                      <% end %>
                    </div>
                    <div class="wc-stats-team-total">
                      <span class="wc-stats-team-name"><%= @away_team_name %></span>
                      <%= if @detailed_history.team2_wc_stats && @detailed_history.team2_wc_stats.matches_played > 0 do %>
                        <span class="wc-stats-total-line">Kokku: <%= @detailed_history.team2_wc_stats.matches_played %> mängu</span>
                        <span class="wc-stats-total-line">V/Vi/K: <%= @detailed_history.team2_wc_stats.wins %>/<%= @detailed_history.team2_wc_stats.draws %>/<%= @detailed_history.team2_wc_stats.losses %></span>
                        <%= if @detailed_history.team2_wc_positions.total_top_4 > 0 do %>
                          <span class="wc-stats-positions">
                            <%= if @detailed_history.team2_wc_positions.counts.gold > 0 do %><span class="wc-position wc-gold" title="1. koht"><%= @detailed_history.team2_wc_positions.counts.gold %>x</span><% end %>
                            <%= if @detailed_history.team2_wc_positions.counts.silver > 0 do %><span class="wc-position wc-silver" title="2. koht"><%= @detailed_history.team2_wc_positions.counts.silver %>x</span><% end %>
                            <%= if @detailed_history.team2_wc_positions.counts.bronze > 0 do %><span class="wc-position wc-bronze" title="3. koht"><%= @detailed_history.team2_wc_positions.counts.bronze %>x</span><% end %>
                            <%= if @detailed_history.team2_wc_positions.counts.fourth > 0 do %><span class="wc-position wc-fourth" title="4. koht"><%= @detailed_history.team2_wc_positions.counts.fourth %>x</span><% end %>
                          </span>
                        <% end %>
                      <% else %>
                        <span class="wc-stats-empty">MM-ajalugu puudub</span>
                      <% end %>
                    </div>
                  </div>

                  <!-- Tournament by tournament breakdown -->
                  <div class="wc-tournament-breakdown">
                    <div class="wc-tournament-column">
                      <%= if length(@detailed_history.team1_wc_by_tournament) > 0 do %>
                        <%= for tournament <- @detailed_history.team1_wc_by_tournament do %>
                          <% position = get_position_for_year(@detailed_history.team1_wc_positions, tournament.year) %>
                          <% elimination = get_elimination_for_year(@detailed_history.team1_wc_eliminations, tournament.year) %>
                          <div class={"wc-tournament-item #{if position, do: "wc-has-position-#{position}", else: if(elimination, do: "wc-eliminated", else: "")}"}>
                            <span class="wc-tournament-year"><%= tournament.year %></span>
                            <%= if position do %>
                              <span class={"wc-tournament-position wc-pos-#{position}"}><%= position_icon(position) %></span>
                            <% else %>
                              <%= if elimination do %>
                                <span class="wc-tournament-elimination" title={Football.stage_display_name(elimination)}><%= stage_short(elimination) %></span>
                              <% end %>
                            <% end %>
                            <span class="wc-tournament-stats"><%= tournament.wins %>V <%= tournament.draws %>Vi <%= tournament.losses %>K</span>
                          </div>
                        <% end %>
                      <% end %>
                    </div>
                    <div class="wc-tournament-column">
                      <%= if length(@detailed_history.team2_wc_by_tournament) > 0 do %>
                        <%= for tournament <- @detailed_history.team2_wc_by_tournament do %>
                          <% position = get_position_for_year(@detailed_history.team2_wc_positions, tournament.year) %>
                          <% elimination = get_elimination_for_year(@detailed_history.team2_wc_eliminations, tournament.year) %>
                          <div class={"wc-tournament-item #{if position, do: "wc-has-position-#{position}", else: if(elimination, do: "wc-eliminated", else: "")}"}>
                            <span class="wc-tournament-year"><%= tournament.year %></span>
                            <%= if position do %>
                              <span class={"wc-tournament-position wc-pos-#{position}"}><%= position_icon(position) %></span>
                            <% else %>
                              <%= if elimination do %>
                                <span class="wc-tournament-elimination" title={Football.stage_display_name(elimination)}><%= stage_short(elimination) %></span>
                              <% end %>
                            <% end %>
                            <span class="wc-tournament-stats"><%= tournament.wins %>V <%= tournament.draws %>Vi <%= tournament.losses %>K</span>
                          </div>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Loads the head-to-head / World Cup history for two team codes.

  Returns the `detailed_history` map consumed by `history_panel/1`.
  """
  def load_history(team1_code, team2_code) do
    %{
      matches: Football.get_historical_matchup(team1_code, team2_code),
      world_cup_matches: Football.get_world_cup_matchup(team1_code, team2_code),
      stats: Football.get_historical_stats(team1_code, team2_code),
      team1_form: Football.get_team_recent_form(team1_code, 5),
      team2_form: Football.get_team_recent_form(team2_code, 5),
      team1_wc_stats: Football.get_team_world_cup_stats(team1_code),
      team2_wc_stats: Football.get_team_world_cup_stats(team2_code),
      team1_wc_by_tournament: Football.get_team_world_cup_stats_by_tournament(team1_code),
      team2_wc_by_tournament: Football.get_team_world_cup_stats_by_tournament(team2_code),
      team1_wc_positions: Football.get_team_world_cup_positions(team1_code),
      team2_wc_positions: Football.get_team_world_cup_positions(team2_code),
      team1_wc_eliminations: Football.get_team_world_cup_eliminations(team1_code),
      team2_wc_eliminations: Football.get_team_world_cup_eliminations(team2_code)
    }
  end

  def format_date(date) do
    Calendar.strftime(date, "%d.%m.%Y")
  end

  def get_position_for_year(positions_data, year) do
    case Enum.find(positions_data.finishes, fn f -> f.year == year end) do
      nil -> nil
      finish -> finish.position
    end
  end

  def position_icon(1), do: "🥇"
  def position_icon(2), do: "🥈"
  def position_icon(3), do: "🥉"
  def position_icon(4), do: "4."
  def position_icon(_), do: nil

  def get_elimination_for_year(eliminations_data, year) do
    Map.get(eliminations_data, year)
  end

  def stage_short(stage) do
    Football.stage_short_name(stage)
  end
end

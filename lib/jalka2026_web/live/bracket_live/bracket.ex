defmodule Jalka2026Web.BracketLive.Bracket do
  use Jalka2026Web, :live_view

  alias Jalka2026.Football
  alias Jalka2026.Football.BracketPrediction
  alias Jalka2026Web.TelemetryHooks

  @impl true
  def mount(_params, _session, socket) do
    TelemetryHooks.with_mount_telemetry(__MODULE__, socket, fn ->
      socket = load_bracket_data(socket)
      {:ok, socket}
    end)
  end

  @impl true
  def handle_params(params, _url, socket) do
    user_id = params["user_id"]

    socket =
      if user_id && user_id != to_string(socket.assigns.current_user.id) do
        # Viewing another user's bracket
        viewed_user = Jalka2026.Accounts.get_user!(String.to_integer(user_id))
        socket
        |> assign(:viewed_user, viewed_user)
        |> assign(:viewing_own, false)
        |> load_bracket_data_for_user(viewed_user.id)
      else
        socket
        |> assign(:viewed_user, socket.assigns.current_user)
        |> assign(:viewing_own, true)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("select-team", %{"round" => round, "position" => position, "team-id" => team_id}, socket) do
    if socket.assigns.viewing_own && Jalka2026Web.LiveHelpers.predictions_open?() do
      user_id = socket.assigns.current_user.id
      team_id = String.to_integer(team_id)
      position = String.to_integer(position)

      Football.set_bracket_prediction(%{
        user_id: user_id,
        round: round,
        position: position,
        team_id: team_id
      })

      {:noreply, load_bracket_data(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear-team", %{"round" => round, "position" => position}, socket) do
    if socket.assigns.viewing_own && Jalka2026Web.LiveHelpers.predictions_open?() do
      user_id = socket.assigns.current_user.id
      position = String.to_integer(position)

      # Get current prediction to cascade removal
      case Football.get_bracket_prediction(user_id, round, position) do
        nil ->
          :ok

        prediction when not is_nil(prediction.team_id) ->
          Football.cascade_bracket_removal(user_id, prediction.team_id, round)

        _ ->
          :ok
      end

      Football.clear_bracket_prediction(user_id, round, position)

      {:noreply, load_bracket_data(socket)}
    else
      {:noreply, socket}
    end
  end

  defp load_bracket_data(socket) do
    load_bracket_data_for_user(socket, socket.assigns.current_user.id)
  end

  defp load_bracket_data_for_user(socket, user_id) do
    predictions = Football.get_bracket_predictions_by_round(user_id)
    results = Football.get_bracket_results_by_round()
    teams = Football.get_teams() |> Enum.map(fn t -> {t.id, t} end) |> Map.new()
    accuracy = Football.calculate_bracket_accuracy(user_id)
    points = Football.calculate_bracket_points(user_id)

    # Get teams that qualified to Round of 32 from playoffs predictions
    playoff_predictions = Football.get_playoff_predictions_by_user(user_id)
    qualified_teams =
      playoff_predictions
      |> Enum.filter(fn p -> p.phase == 32 end)
      |> Enum.map(fn p -> p.team end)

    socket
    |> assign(:predictions, predictions)
    |> assign(:results, results)
    |> assign(:teams, teams)
    |> assign(:qualified_teams, qualified_teams)
    |> assign(:accuracy, accuracy)
    |> assign(:points, points)
    |> assign(:rounds, build_bracket_structure(predictions, results, teams))
  end

  defp build_bracket_structure(predictions, results, _teams) do
    rounds = ["round_of_32", "round_of_16", "quarter_final", "semi_final", "final", "winner"]

    Enum.map(rounds, fn round ->
      positions = BracketPrediction.positions_for_round(round)
      round_predictions = Map.get(predictions, round, [])
      round_results = Map.get(results, round, [])

      slots =
        Enum.map(1..positions, fn pos ->
          prediction = Enum.find(round_predictions, &(&1.position == pos))
          result = Enum.find(round_results, &(&1.position == pos))

          %{
            position: pos,
            predicted_team: prediction && prediction.team,
            actual_team: result && result.team,
            is_correct: prediction && result && prediction.team_id == result.team_id,
            is_wrong: prediction && result && prediction.team_id != result.team_id
          }
        end)

      %{
        round: round,
        display_name: BracketPrediction.round_display_name(round),
        slots: slots,
        slot_count: positions
      }
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main role="main" class="container bracket-container" aria-label="Turniiri tabel">
      <h1 id="page-title">
        <%= if @viewing_own do %>
          Minu turniiri tabel
        <% else %>
          <%= @viewed_user.email %> turniiri tabel
        <% end %>
      </h1>

      <div class="bracket-stats">
        <div class="stat-card">
          <span class="stat-value"><%= @points %></span>
          <span class="stat-label">Punktid</span>
        </div>
        <div class="stat-card">
          <span class="stat-value"><%= Float.round(@accuracy.overall_accuracy, 1) %>%</span>
          <span class="stat-label">Täpsus</span>
        </div>
        <div class="stat-card">
          <span class="stat-value"><%= @accuracy.total_correct %>/<%= @accuracy.total_possible %></span>
          <span class="stat-label">Õiged</span>
        </div>
      </div>

      <div class="bracket-wrapper">
        <div class="bracket">
          <%= for {round_data, idx} <- Enum.with_index(@rounds) do %>
            <div class={"bracket-round bracket-round-#{idx}"} data-round={round_data.round}>
              <h3 class="round-title"><%= round_data.display_name %></h3>
              <div class="bracket-slots">
                <%= for slot <- round_data.slots do %>
                  <div class={"bracket-slot #{slot_class(slot)}"} data-position={slot.position}>
                    <%= if slot.predicted_team do %>
                      <div class="bracket-team">
                        <span class="team-flag"><%= slot.predicted_team.code %></span>
                        <span class="team-name"><%= slot.predicted_team.name %></span>
                        <%= if slot.is_correct do %>
                          <span class="result-icon correct" title="Õige">✓</span>
                        <% end %>
                        <%= if slot.is_wrong do %>
                          <span class="result-icon wrong" title="Vale">✗</span>
                        <% end %>
                        <%= if @viewing_own && Jalka2026Web.LiveHelpers.predictions_open?() do %>
                          <button
                            class="clear-btn"
                            phx-click="clear-team"
                            phx-value-round={round_data.round}
                            phx-value-position={slot.position}
                            title="Eemalda"
                          >×</button>
                        <% end %>
                      </div>
                    <% else %>
                      <%= if @viewing_own && Jalka2026Web.LiveHelpers.predictions_open?() do %>
                        <.team_selector
                          round={round_data.round}
                          position={slot.position}
                          available_teams={get_available_teams(round_data.round, slot.position, @predictions, @qualified_teams)}
                        />
                      <% else %>
                        <div class="bracket-team empty">
                          <span class="team-name">—</span>
                        </div>
                      <% end %>
                    <% end %>
                    <%= if slot.actual_team do %>
                      <div class="actual-result">
                        <span class="actual-label">Tegelik:</span>
                        <span class="actual-team"><%= slot.actual_team.name %></span>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <div class="bracket-legend">
        <h3>Punktid ringide kaupa</h3>
        <ul>
          <li><strong>32 parimat:</strong> 1 punkt</li>
          <li><strong>Kaheksandikfinaal:</strong> 2 punkti</li>
          <li><strong>Veerandfinaal:</strong> 4 punkti</li>
          <li><strong>Poolfinaal:</strong> 8 punkti</li>
          <li><strong>Finaal:</strong> 16 punkti</li>
          <li><strong>Võitja:</strong> 32 punkti</li>
        </ul>
      </div>

      <nav class="back-button-container" aria-label="Navigeerimine">
        <.link navigate="/" class="button button-large button-main">Tagasi</.link>
        <%= if not @viewing_own do %>
          <.link navigate={~p"/bracket"} class="button button-large button-outline">Minu tabel</.link>
        <% end %>
      </nav>
    </main>
    """
  end

  defp team_selector(assigns) do
    ~H"""
    <div class="team-selector">
      <select
        phx-change="select-team"
        phx-value-round={@round}
        phx-value-position={@position}
        name="team-id"
      >
        <option value="">Vali meeskond...</option>
        <%= for team <- @available_teams do %>
          <option value={team.id}><%= team.name %></option>
        <% end %>
      </select>
    </div>
    """
  end

  defp slot_class(slot) do
    cond do
      slot.is_correct -> "correct"
      slot.is_wrong -> "wrong"
      slot.predicted_team -> "filled"
      true -> "empty"
    end
  end

  defp get_available_teams(round, _position, predictions, qualified_teams) do
    case round do
      "round_of_32" ->
        # For R32, use teams from playoff predictions (phase 32)
        qualified_teams

      _ ->
        # For later rounds, use teams predicted in the previous round
        prev_round = prev_round(round)
        prev_predictions = Map.get(predictions, prev_round, [])
        Enum.map(prev_predictions, & &1.team) |> Enum.reject(&is_nil/1)
    end
  end

  defp prev_round(round) do
    case round do
      "round_of_16" -> "round_of_32"
      "quarter_final" -> "round_of_16"
      "semi_final" -> "quarter_final"
      "final" -> "semi_final"
      "winner" -> "final"
      _ -> nil
    end
  end
end

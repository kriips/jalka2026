defmodule Jalka2026Web.UserLive.Rivalries do
  use Jalka2026Web, :live_view

  alias Jalka2026.Football
  alias Jalka2026.Leaderboard

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Jalka2026.PubSub, "user:#{user.id}:rivalries")
    end

    rivalries_with_stats = Football.get_user_rivalries_with_stats(user.id)
    leaderboard = Leaderboard.get_leaderboard()
    users = get_users_for_dropdown(leaderboard, user.id, rivalries_with_stats)

    {:ok,
     assign(socket,
       page_title: "Rivaalid",
       rivalries: rivalries_with_stats,
       users: users,
       search: "",
       selected_rivalry: nil,
       show_add_modal: false
     )}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, search: search)}
  end

  @impl true
  def handle_event("add_rival", %{"rival_id" => rival_id}, socket) do
    user = socket.assigns.current_user
    rival_id = String.to_integer(rival_id)

    # Limit to 10 rivals
    if length(socket.assigns.rivalries) >= 10 do
      {:noreply, put_flash(socket, :error, "Maksimaalselt 10 rivaali")}
    else
      case Football.add_rival(user.id, rival_id) do
        {:ok, _} ->
          rivalries_with_stats = Football.get_user_rivalries_with_stats(user.id)
          users = get_users_for_dropdown(
            Leaderboard.get_leaderboard(),
            user.id,
            rivalries_with_stats
          )

          # Broadcast rivalry creation for notifications
          broadcast_rivalry_event(user.id, rival_id, :rivalry_created)

          {:noreply,
           socket
           |> assign(rivalries: rivalries_with_stats, users: users, show_add_modal: false)
           |> put_flash(:info, "Rivaal lisatud")}

        {:error, changeset} ->
          error_message = get_error_message(changeset)
          {:noreply, put_flash(socket, :error, error_message)}
      end
    end
  end

  @impl true
  def handle_event("remove_rival", %{"rival_id" => rival_id}, socket) do
    user = socket.assigns.current_user
    rival_id = String.to_integer(rival_id)

    Football.remove_rival(user.id, rival_id)

    rivalries_with_stats = Football.get_user_rivalries_with_stats(user.id)
    users = get_users_for_dropdown(
      Leaderboard.get_leaderboard(),
      user.id,
      rivalries_with_stats
    )

    {:noreply,
     socket
     |> assign(rivalries: rivalries_with_stats, users: users, selected_rivalry: nil)
     |> put_flash(:info, "Rivaal eemaldatud")}
  end

  @impl true
  def handle_event("toggle_notifications", %{"rival_id" => rival_id}, socket) do
    user = socket.assigns.current_user
    rival_id = String.to_integer(rival_id)

    case Football.toggle_rivalry_notifications(user.id, rival_id) do
      {:ok, _} ->
        rivalries_with_stats = Football.get_user_rivalries_with_stats(user.id)
        {:noreply, assign(socket, rivalries: rivalries_with_stats)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Viga teavituste muutmisel")}
    end
  end

  @impl true
  def handle_event("view_rivalry", %{"rival_id" => rival_id}, socket) do
    rival_id = String.to_integer(rival_id)

    rivalry =
      Enum.find(socket.assigns.rivalries, fn r ->
        r.rivalry.rival_id == rival_id
      end)

    if rivalry do
      user_id = socket.assigns.current_user.id
      differing = Football.get_differing_predictions(user_id, rival_id)

      {:noreply, assign(socket, selected_rivalry: %{rivalry | differing_predictions: differing})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_rivalry_details", _, socket) do
    {:noreply, assign(socket, selected_rivalry: nil)}
  end

  @impl true
  def handle_event("show_add_modal", _, socket) do
    {:noreply, assign(socket, show_add_modal: true)}
  end

  @impl true
  def handle_event("close_add_modal", _, socket) do
    {:noreply, assign(socket, show_add_modal: false, search: "")}
  end

  @impl true
  def handle_info({:rivalry_prediction_diff, _data}, socket) do
    # Refresh rivalries when there's a prediction difference update
    user = socket.assigns.current_user
    rivalries_with_stats = Football.get_user_rivalries_with_stats(user.id)
    {:noreply, assign(socket, rivalries: rivalries_with_stats)}
  end

  defp get_users_for_dropdown(leaderboard, current_user_id, rivalries) do
    rival_ids = Enum.map(rivalries, fn r -> r.rivalry.rival_id end) |> MapSet.new()

    leaderboard
    |> Enum.map(fn {id, _rank, name, _gp, _pp, _bp, _cs, _ls, _total} ->
      {id, name}
    end)
    |> Enum.reject(fn {id, _name} ->
      id == current_user_id or MapSet.member?(rival_ids, id)
    end)
    |> Enum.sort_by(fn {_id, name} -> String.downcase(name) end)
  end

  defp filtered_users(users, search) do
    search_lower = String.downcase(search)

    users
    |> Enum.filter(fn {_id, name} ->
      search == "" or String.contains?(String.downcase(name), search_lower)
    end)
  end

  defp get_error_message(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {_field, errors} -> Enum.join(errors, ", ") end)
    |> Enum.join("; ")
    |> case do
      "" -> "Viga rivaali lisamisel"
      msg -> msg
    end
  end

  defp broadcast_rivalry_event(user_id, rival_id, event) do
    Phoenix.PubSub.broadcast(
      Jalka2026.PubSub,
      "user:#{rival_id}:rivalries",
      {event, %{from_user_id: user_id}}
    )
  end

  defp comparison_class(val1, val2) do
    cond do
      val1 > val2 -> "winning"
      val1 < val2 -> "losing"
      true -> "tied"
    end
  end

  defp result_label(result) do
    case result do
      "home" -> "Kodu"
      "away" -> "Võõrsil"
      "draw" -> "Viik"
      _ -> result
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main role="main" class="container">
      <div class="prediction-page-header">
        <h1 id="page-title">Rivaalid</h1>
        <p class="page-subtitle">Võistle sõpradega ja jälgi omavahelisi tulemusi</p>
      </div>

      <div class="container" id="main-content">
        <!-- Rivalries List -->
        <div class="section-card">
          <div class="section-card-header">
            <h2 class="section-card-title">Sinu rivaalid</h2>
            <button
              type="button"
              class="button button-small button-main"
              phx-click="show_add_modal"
            >
              Lisa rivaal
            </button>
          </div>

          <%= if @rivalries == [] do %>
            <p class="empty-state">Sul pole veel rivaale lisatud. Lisa rivaale, et jälgida omavahelist võistlust!</p>
          <% else %>
            <div class="rivalries-list">
              <%= for rivalry_data <- @rivalries do %>
                <% rivalry = rivalry_data.rivalry %>
                <% stats = rivalry_data.stats %>
                <% rivalry_class = cond do
                  stats.user_total_points > stats.rival_total_points -> "rivalry-winning"
                  stats.user_total_points < stats.rival_total_points -> "rivalry-losing"
                  true -> "rivalry-tied"
                end %>
                <div class={"rivalry-card #{rivalry_class}"}>
                  <div class="rivalry-header">
                    <span class="rival-name"><%= rivalry.rival.name %></span>
                    <div class="rivalry-score">
                      <span class={"your-score #{comparison_class(stats.user_total_points, stats.rival_total_points)}"}><%= stats.user_total_points %></span>
                      <span class="score-separator">-</span>
                      <span class={"rival-score #{comparison_class(stats.rival_total_points, stats.user_total_points)}"}><%= stats.rival_total_points %></span>
                    </div>
                  </div>

                  <div class="rivalry-quick-stats">
                    <div class="quick-stat">
                      <span class="quick-stat-label">Võite</span>
                      <span class="quick-stat-value"><%= stats.matches_user_won %></span>
                    </div>
                    <div class="quick-stat">
                      <span class="quick-stat-label">Viike</span>
                      <span class="quick-stat-value"><%= stats.matches_tied %></span>
                    </div>
                    <div class="quick-stat">
                      <span class="quick-stat-label">Kaotusi</span>
                      <span class="quick-stat-value"><%= stats.matches_rival_won %></span>
                    </div>
                  </div>

                  <div class="rivalry-actions">
                    <button
                      type="button"
                      class="button button-small button-outline"
                      phx-click="view_rivalry"
                      phx-value-rival_id={rivalry.rival_id}
                    >
                      Vaata detaile
                    </button>
                    <button
                      type="button"
                      class={"button button-small #{if rivalry.notifications_enabled, do: "button-outline", else: "button-muted"}"}
                      phx-click="toggle_notifications"
                      phx-value-rival_id={rivalry.rival_id}
                      title={if rivalry.notifications_enabled, do: "Teavitused sees", else: "Teavitused väljas"}
                    >
                      <%= if rivalry.notifications_enabled do %>
                        Teavitused sees
                      <% else %>
                        Teavitused väljas
                      <% end %>
                    </button>
                    <.link
                      navigate={Routes.football_compare_path(@socket, :view, user1: @current_user.id, user2: rivalry.rival_id)}
                      class="button button-small button-outline"
                    >
                      Võrdle detailselt
                    </.link>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Selected Rivalry Details Modal -->
        <%= if @selected_rivalry do %>
          <div class="modal-overlay" phx-click="close_rivalry_details">
            <div class="modal-content rivalry-details-modal" phx-click-away="close_rivalry_details">
              <button type="button" class="modal-close" phx-click="close_rivalry_details">x</button>

              <h2 class="modal-title">Rivaalitsus: <%= @selected_rivalry.rivalry.rival.name %></h2>

              <div class="rivalry-detailed-stats">
                <div class="stat-comparison">
                  <div class="stat-item">
                    <span class="stat-label">Sinu punktid</span>
                    <span class={"stat-value #{comparison_class(@selected_rivalry.stats.user_total_points, @selected_rivalry.stats.rival_total_points)}"}><%= @selected_rivalry.stats.user_total_points %></span>
                  </div>
                  <div class="stat-vs">VS</div>
                  <div class="stat-item">
                    <span class="stat-label">Rivaali punktid</span>
                    <span class={"stat-value #{comparison_class(@selected_rivalry.stats.rival_total_points, @selected_rivalry.stats.user_total_points)}"}><%= @selected_rivalry.stats.rival_total_points %></span>
                  </div>
                </div>

                <div class="detailed-breakdown">
                  <div class="breakdown-row">
                    <span class="breakdown-label">Grupi punktid:</span>
                    <span class={"breakdown-value #{comparison_class(@selected_rivalry.stats.user_group_points, @selected_rivalry.stats.rival_group_points)}"}><%= @selected_rivalry.stats.user_group_points %></span>
                    <span class="breakdown-vs">vs</span>
                    <span class={"breakdown-value #{comparison_class(@selected_rivalry.stats.rival_group_points, @selected_rivalry.stats.user_group_points)}"}><%= @selected_rivalry.stats.rival_group_points %></span>
                  </div>
                  <div class="breakdown-row">
                    <span class="breakdown-label">Playoffi punktid:</span>
                    <span class={"breakdown-value #{comparison_class(@selected_rivalry.stats.user_playoff_points, @selected_rivalry.stats.rival_playoff_points)}"}><%= @selected_rivalry.stats.user_playoff_points %></span>
                    <span class="breakdown-vs">vs</span>
                    <span class={"breakdown-value #{comparison_class(@selected_rivalry.stats.rival_playoff_points, @selected_rivalry.stats.user_playoff_points)}"}><%= @selected_rivalry.stats.rival_playoff_points %></span>
                  </div>
                  <div class="breakdown-row">
                    <span class="breakdown-label">Õigeid tulemusi:</span>
                    <span class={"breakdown-value #{comparison_class(@selected_rivalry.stats.user_correct_results, @selected_rivalry.stats.rival_correct_results)}"}><%= @selected_rivalry.stats.user_correct_results %></span>
                    <span class="breakdown-vs">vs</span>
                    <span class={"breakdown-value #{comparison_class(@selected_rivalry.stats.rival_correct_results, @selected_rivalry.stats.user_correct_results)}"}><%= @selected_rivalry.stats.rival_correct_results %></span>
                  </div>
                  <div class="breakdown-row">
                    <span class="breakdown-label">Õigeid skoore:</span>
                    <span class={"breakdown-value #{comparison_class(@selected_rivalry.stats.user_correct_scores, @selected_rivalry.stats.rival_correct_scores)}"}><%= @selected_rivalry.stats.user_correct_scores %></span>
                    <span class="breakdown-vs">vs</span>
                    <span class={"breakdown-value #{comparison_class(@selected_rivalry.stats.rival_correct_scores, @selected_rivalry.stats.user_correct_scores)}"}><%= @selected_rivalry.stats.rival_correct_scores %></span>
                  </div>
                </div>

                <div class="head-to-head-summary">
                  <h3>Mängud</h3>
                  <div class="h2h-record">
                    <span class="h2h-wins winning"><%= @selected_rivalry.stats.matches_user_won %> V</span>
                    <span class="h2h-draws tied"><%= @selected_rivalry.stats.matches_tied %> D</span>
                    <span class="h2h-losses losing"><%= @selected_rivalry.stats.matches_rival_won %> K</span>
                  </div>
                  <p class="h2h-total"><%= @selected_rivalry.stats.finished_matches_count %> mängu lõppenud</p>
                </div>

                <%= if Map.get(@selected_rivalry, :differing_predictions, []) != [] do %>
                  <div class="differing-predictions">
                    <h3>Erinevad ennustused (tulevased mängud)</h3>
                    <div class="differing-list">
                      <%= for diff <- @selected_rivalry.differing_predictions do %>
                        <div class="differing-match">
                          <div class="differing-match-info">
                            <span class="differing-match-teams">
                              <%= diff.match.home_team.name %> vs <%= diff.match.away_team.name %>
                            </span>
                          </div>
                          <div class="differing-predictions-row">
                            <span class="your-prediction">
                              Sina: <%= diff.user_prediction.home_score %>-<%= diff.user_prediction.away_score %>
                              (<%= result_label(diff.user_prediction.result) %>)
                            </span>
                            <span class="rival-prediction">
                              <%= @selected_rivalry.rivalry.rival.name %>: <%= diff.rival_prediction.home_score %>-<%= diff.rival_prediction.away_score %>
                              (<%= result_label(diff.rival_prediction.result) %>)
                            </span>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>

              <div class="modal-actions">
                <button
                  type="button"
                  class="button button-danger"
                  phx-click="remove_rival"
                  phx-value-rival_id={@selected_rivalry.rivalry.rival_id}
                  data-confirm="Kas oled kindel, et soovid selle rivaali eemaldada?"
                >
                  Eemalda rivaal
                </button>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Add Rival Modal -->
        <%= if @show_add_modal do %>
          <div class="modal-overlay" phx-click="close_add_modal">
            <div class="modal-content add-rival-modal" phx-click-away="close_add_modal">
              <button type="button" class="modal-close" phx-click="close_add_modal">x</button>

              <h2 class="modal-title">Lisa rivaal</h2>

              <form phx-change="search" class="search-form">
                <input
                  type="text"
                  name="search"
                  value={@search}
                  placeholder="Otsi kasutajat..."
                  class="search-input"
                  autocomplete="off"
                  phx-debounce="300"
                />
              </form>

              <div class="users-list">
                <%= for {id, name} <- filtered_users(@users, @search) do %>
                  <div class="user-item">
                    <span class="user-name"><%= name %></span>
                    <button
                      type="button"
                      class="button button-small button-main"
                      phx-click="add_rival"
                      phx-value-rival_id={id}
                    >
                      Lisa
                    </button>
                  </div>
                <% end %>
                <%= if filtered_users(@users, @search) == [] do %>
                  <p class="no-users-found">Kasutajaid ei leitud</p>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <div class="back-button-container">
          <.link navigate={Routes.page_path(@socket, :index)} class="button button-large button-main">
            Tagasi
          </.link>
        </div>
      </div>
    </main>
    """
  end
end

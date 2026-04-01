defmodule Jalka2026Web.UserLive.FavoriteTeams do
  use Jalka2026Web, :live_view

  alias Jalka2026.Football
  alias Jalka2026.Football.TeamTranslations

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    teams = Football.get_teams() |> Enum.sort_by(& &1.name)
    favorite_teams = Football.get_user_favorite_teams(user.id)
    favorite_team_ids = Enum.map(favorite_teams, & &1.team_id) |> MapSet.new()

    {:ok,
     assign(socket,
       page_title: "Lemmikmeeskonnad",
       teams: teams,
       favorite_teams: favorite_teams,
       favorite_team_ids: favorite_team_ids,
       search: ""
     )}
  end

  @impl true
  def handle_event("add_favorite", %{"team_id" => team_id}, socket) do
    user = socket.assigns.current_user
    team_id = String.to_integer(team_id)

    # Limit to 3 favorites
    if MapSet.size(socket.assigns.favorite_team_ids) >= 3 do
      {:noreply, put_flash(socket, :error, "Maksimaalselt 3 lemmikmeeskonda")}
    else
      is_primary = MapSet.size(socket.assigns.favorite_team_ids) == 0

      case Football.add_favorite_team(user.id, team_id, is_primary) do
        {:ok, _} ->
          favorite_teams = Football.get_user_favorite_teams(user.id)
          favorite_team_ids = Enum.map(favorite_teams, & &1.team_id) |> MapSet.new()

          {:noreply,
           socket
           |> assign(favorite_teams: favorite_teams, favorite_team_ids: favorite_team_ids)
           |> put_flash(:info, "Meeskond lisatud")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Viga meeskonna lisamisel")}
      end
    end
  end

  @impl true
  def handle_event("remove_favorite", %{"team_id" => team_id}, socket) do
    user = socket.assigns.current_user
    team_id = String.to_integer(team_id)

    Football.remove_favorite_team(user.id, team_id)

    favorite_teams = Football.get_user_favorite_teams(user.id)
    favorite_team_ids = Enum.map(favorite_teams, & &1.team_id) |> MapSet.new()

    {:noreply,
     socket
     |> assign(favorite_teams: favorite_teams, favorite_team_ids: favorite_team_ids)
     |> put_flash(:info, "Meeskond eemaldatud")}
  end

  @impl true
  def handle_event("set_primary", %{"team_id" => team_id}, socket) do
    user = socket.assigns.current_user
    team_id = String.to_integer(team_id)

    case Football.set_primary_team(user.id, team_id) do
      {:ok, _} ->
        favorite_teams = Football.get_user_favorite_teams(user.id)

        {:noreply,
         socket
         |> assign(favorite_teams: favorite_teams)
         |> put_flash(:info, "Peamine meeskond muudetud")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Viga peamise meeskonna seadmisel")}
    end
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, search: search)}
  end

  defp filtered_teams(teams, search, favorite_team_ids) do
    search_lower = String.downcase(search)

    teams
    |> Enum.reject(fn team -> MapSet.member?(favorite_team_ids, team.id) end)
    |> Enum.filter(fn team ->
      search == "" or
        String.contains?(String.downcase(team.name), search_lower) or
        String.contains?(String.downcase(TeamTranslations.translate(team.name)), search_lower)
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main role="main" class="container">
      <div class="prediction-page-header">
        <h1 id="page-title">Lemmikmeeskonnad</h1>
        <p class="page-subtitle">Vali kuni 3 meeskonda, keda toetad</p>
      </div>

      <div class="container" id="main-content">
        <div class="section-card">
          <h2 class="section-card-title">Sinu lemmikud</h2>
          <%= if @favorite_teams == [] do %>
            <p class="empty-state">Sul pole veel lemmikmeeskondi valitud</p>
          <% else %>
            <div class="favorite-teams-list">
              <%= for fav <- @favorite_teams do %>
                <div class={"favorite-team-item #{if fav.is_primary, do: "is-primary", else: ""}"}>
                  <div class="team-flag-container">
                    <img class="team-flag" src={fav.team.flag} alt={"#{TeamTranslations.translate(fav.team.name)} vapp"} />
                  </div>
                  <span class="team-name"><%= TeamTranslations.translate(fav.team.name) %></span>
                  <%= if fav.is_primary do %>
                    <span class="primary-badge">Peamine</span>
                  <% else %>
                    <button
                      class="button button-small button-outline"
                      phx-click="set_primary"
                      phx-value-team_id={fav.team_id}
                    >
                      Tee peamiseks
                    </button>
                  <% end %>
                  <button
                    class="button button-small button-danger"
                    phx-click="remove_favorite"
                    phx-value-team_id={fav.team_id}
                  >
                    Eemalda
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="section-card">
          <h2 class="section-card-title">Lisa meeskondi</h2>
          <form phx-change="search" class="search-form">
            <input
              type="text"
              name="search"
              value={@search}
              placeholder="Otsi meeskonda..."
              class="search-input"
              autocomplete="off"
            />
          </form>

          <div class="teams-grid selectable">
            <%= for team <- filtered_teams(@teams, @search, @favorite_team_ids) do %>
              <button
                class="team-card"
                phx-click="add_favorite"
                phx-value-team_id={team.id}
                title={"Lisa #{TeamTranslations.translate(team.name)} lemmikute hulka"}
              >
                <div class="team-flag-container">
                  <img class="team-flag" src={team.flag} alt={"#{TeamTranslations.translate(team.name)} vapp"} />
                </div>
                <span class="team-name"><%= TeamTranslations.translate(team.name) %></span>
              </button>
            <% end %>
          </div>
        </div>

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

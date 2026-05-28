defmodule Jalka2026Web.BracketLive.Compare do
  use Jalka2026Web, :live_view

  alias Jalka2026.Accounts
  alias Jalka2026.Football
  alias Jalka2026Web.TelemetryHooks

  @impl true
  def mount(_params, _session, socket) do
    TelemetryHooks.with_mount_telemetry(__MODULE__, socket, fn ->
      # Get all users for comparison selection
      users = Accounts.list_users() |> Enum.reject(&(&1.id == socket.assigns.current_user.id))

      socket =
        socket
        |> assign(:users, users)
        |> assign(:compared_user, nil)
        |> assign(:comparison, nil)

      {:ok, socket}
    end)
  end

  @impl true
  def handle_params(%{"user_id" => user_id}, _url, socket) do
    compared_user = Accounts.get_user!(String.to_integer(user_id))
    comparison = Football.compare_brackets(socket.assigns.current_user.id, compared_user.id)

    socket =
      socket
      |> assign(:compared_user, compared_user)
      |> assign(:comparison, comparison)

    {:noreply, socket}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("select-user", %{"user_id" => user_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/bracket/compare/#{user_id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main role="main" class="container bracket-compare-container" aria-label="Turniiri tabelite võrdlus">
      <h1 id="page-title">Tabelite võrdlus</h1>

      <div class="user-selector">
        <label for="compare-user">Võrdle kasutajaga:</label>
        <select id="compare-user" phx-change="select-user" name="user_id">
          <option value="">Vali kasutaja...</option>
          <%= for user <- @users do %>
            <option value={user.id} selected={@compared_user && @compared_user.id == user.id}>
              <%= user.email %>
            </option>
          <% end %>
        </select>
      </div>

      <%= if @comparison do %>
        <div class="comparison-summary">
          <div class="summary-card user1">
            <h3><%= @current_user.email %></h3>
            <span class="points"><%= @comparison.user1_points %> punkti</span>
          </div>
          <div class="summary-vs">VS</div>
          <div class="summary-card user2">
            <h3><%= @compared_user.email %></h3>
            <span class="points"><%= @comparison.user2_points %> punkti</span>
          </div>
        </div>

        <div class="bracket-comparison">
          <%= for round <- @comparison.rounds do %>
            <div class="comparison-round">
              <h3 class="round-title"><%= round.round_display %></h3>
              <div class="comparison-positions">
                <%= for pos <- round.positions do %>
                  <div class={"comparison-slot #{comparison_slot_class(pos)}"}>
                    <div class="slot-user1">
                      <%= if pos.user1_team do %>
                        <span class={"team-name #{if pos.user1_correct, do: "correct"} #{if pos.actual_team && !pos.user1_correct, do: "wrong"}"}>
                          <%= pos.user1_team.name %>
                          <%= if pos.user1_correct do %><span class="check">✓</span><% end %>
                        </span>
                      <% else %>
                        <span class="team-name empty">—</span>
                      <% end %>
                    </div>
                    <div class="slot-position">
                      <span class="position-num"><%= pos.position %></span>
                      <%= if pos.both_same do %>
                        <span class="same-pick" title="Sama valik">≡</span>
                      <% end %>
                    </div>
                    <div class="slot-user2">
                      <%= if pos.user2_team do %>
                        <span class={"team-name #{if pos.user2_correct, do: "correct"} #{if pos.actual_team && !pos.user2_correct, do: "wrong"}"}>
                          <%= pos.user2_team.name %>
                          <%= if pos.user2_correct do %><span class="check">✓</span><% end %>
                        </span>
                      <% else %>
                        <span class="team-name empty">—</span>
                      <% end %>
                    </div>
                    <%= if pos.actual_team do %>
                      <div class="slot-actual">
                        <span class="actual-label">Tegelik:</span>
                        <span class="actual-team"><%= pos.actual_team.name %></span>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <div class="comparison-legend">
          <div class="legend-item">
            <span class="legend-color same"></span>
            <span>Sama valik</span>
          </div>
          <div class="legend-item">
            <span class="legend-color correct"></span>
            <span>Õige</span>
          </div>
          <div class="legend-item">
            <span class="legend-color wrong"></span>
            <span>Vale</span>
          </div>
        </div>
      <% else %>
        <div class="no-comparison">
          <p>Vali kasutaja, kelle tabeliga soovid enda oma võrrelda.</p>
        </div>
      <% end %>

      <nav class="back-button-container" aria-label="Navigeerimine">
        <.link navigate={~p"/bracket"} class="button button-large button-main">Minu tabel</.link>
        <.link navigate="/" class="button button-large button-outline">Avaleht</.link>
      </nav>
    </main>
    """
  end

  defp comparison_slot_class(pos) do
    cond do
      pos.both_same && pos.user1_correct -> "same correct"
      pos.both_same -> "same"
      pos.user1_correct || pos.user2_correct -> "has-correct"
      true -> ""
    end
  end
end

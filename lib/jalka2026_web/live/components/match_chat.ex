defmodule Jalka2026Web.Live.Components.MatchChat do
  use Phoenix.LiveComponent

  alias Jalka2026.Chat
  alias Jalka2026.Accounts.User

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:comment_form, to_form(%{"content" => ""}))}
  end

  @impl true
  def update(%{match_id: match_id} = assigns, socket) do
    if connected?(socket) and !socket.assigns[:subscribed] do
      Chat.subscribe(match_id)
    end

    comments = Chat.list_comments(match_id, limit: 100)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:comments, comments)
     |> assign(:subscribed, true)}
  end

  @impl true
  def handle_event("submit_comment", %{"content" => content}, socket) do
    content = String.trim(content)

    if content != "" and socket.assigns[:current_user] do
      case Chat.create_comment(%{
             content: content,
             user_id: socket.assigns.current_user.id,
             match_id: socket.assigns.match_id
           }) do
        {:ok, _comment} ->
          {:noreply,
           socket
           |> assign(:comment_form, to_form(%{"content" => ""}))}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Kommentaari saatmine ebaõnnestus")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_comment", %{"id" => id}, socket) do
    comment = Chat.get_comment!(id)

    case Chat.delete_comment(comment, socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply, socket}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "Sul pole õigust seda kommentaari kustutada")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Kommentaari kustutamine ebaõnnestus")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="match-chat" class="match-chat-container" phx-hook="MatchChat" phx-target={@myself}>
      <div class="match-chat-header">
        <h3>Vestlus</h3>
        <span class="chat-message-count"><%= length(@comments) %> sõnumit</span>
      </div>

      <div class="match-chat-messages" data-chat-messages>
        <%= if length(@comments) == 0 do %>
          <div class="chat-empty-state">
            <p>Vestlust pole veel alustatud. Ole esimene, kes kommenteerib!</p>
          </div>
        <% else %>
          <%= for comment <- @comments do %>
            <div class="chat-message" id={"comment-#{comment.id}"}>
              <div class="chat-message-header">
                <span class="chat-message-author"><%= comment.user.name %></span>
                <span class="chat-message-time"><%= format_time(comment.inserted_at) %></span>
                <%= if can_delete?(comment, @current_user) do %>
                  <button
                    type="button"
                    class="chat-delete-btn"
                    phx-click="delete_comment"
                    phx-value-id={comment.id}
                    phx-target={@myself}
                    aria-label="Kustuta kommentaar"
                  >
                    &times;
                  </button>
                <% end %>
              </div>
              <div class="chat-message-content">
                <%= comment.content %>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>

      <%= if @current_user do %>
        <form phx-submit="submit_comment" phx-target={@myself} class="match-chat-form">
          <input
            type="text"
            name="content"
            value={@comment_form.params["content"]}
            placeholder="Kirjuta kommentaar..."
            maxlength="500"
            autocomplete="off"
            class="chat-input"
          />
          <button type="submit" class="chat-submit-btn">Saada</button>
        </form>
      <% else %>
        <div class="chat-login-prompt">
          <p>Kommenteerimiseks logi sisse</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_time(naive_datetime) do
    # Format as "HH:MM" for today, or "DD.MM HH:MM" for older
    now = NaiveDateTime.utc_now()
    today = NaiveDateTime.to_date(now)
    comment_date = NaiveDateTime.to_date(naive_datetime)

    if comment_date == today do
      Calendar.strftime(naive_datetime, "%H:%M")
    else
      Calendar.strftime(naive_datetime, "%d.%m %H:%M")
    end
  end

  defp can_delete?(_comment, nil), do: false

  defp can_delete?(comment, user) do
    comment.user_id == user.id || User.admin?(user)
  end
end

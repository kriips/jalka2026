defmodule Jalka2026Web.AdminLive.Users do
  use Jalka2026Web, :live_view

  alias Jalka2026.{Accounts, Repo}
  alias Jalka2026Web.Resolvers.{AccountsResolver, FootballResolver}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    users = load_users_with_stats()

    {:noreply,
     socket
     |> assign(:page_title, "Kasutajate haldamine")
     |> assign(:users, users)
     |> assign(:search_query, "")
     |> assign(:sort_by, :name)
     |> assign(:sort_dir, :asc)
     |> stream(:user_rows, users_to_stream_items(users), reset: true)}
  end

  defp users_to_stream_items(users) do
    Enum.map(users, fn user ->
      user
      |> Map.put(:user_id, user.id)
      |> Map.put(:id, "user-row-#{user.id}")
    end)
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    users =
      load_users_with_stats()
      |> filter_users(query)
      |> sort_users(socket.assigns.sort_by, socket.assigns.sort_dir)

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:search_query, query)
     |> stream(:user_rows, users_to_stream_items(users), reset: true)}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)
    current_sort = socket.assigns.sort_by
    current_dir = socket.assigns.sort_dir

    new_dir =
      if field == current_sort do
        if current_dir == :asc, do: :desc, else: :asc
      else
        :asc
      end

    users =
      socket.assigns.users
      |> sort_users(field, new_dir)

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:sort_by, field)
     |> assign(:sort_dir, new_dir)
     |> stream(:user_rows, users_to_stream_items(users), reset: true)}
  end

  @impl true
  def handle_event("toggle_admin", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)
    current_user = socket.assigns.current_user

    # Prevent removing own admin status
    if user.id == current_user.id do
      {:noreply, put_flash(socket, :error, "Ei saa enda administraatori staatust muuta")}
    else
      new_admin_status = !user.is_admin

      user
      |> Ecto.Changeset.change(%{is_admin: new_admin_status})
      |> Repo.update!()

      users = load_users_with_stats() |> filter_users(socket.assigns.search_query)

      message =
        if new_admin_status,
          do: "#{user.name} on nüüd administraator",
          else: "#{user.name} ei ole enam administraator"

      {:noreply,
       socket
       |> put_flash(:info, message)
       |> assign(:users, users)
       |> stream(:user_rows, users_to_stream_items(users), reset: true)}
    end
  end

  defp load_users_with_stats do
    AccountsResolver.list_users()
    |> Enum.map(fn user ->
      predictions = FootballResolver.filled_predictions(user.id)
      prediction_count = predictions |> Map.values() |> Enum.sum()
      playoff_predictions = FootballResolver.get_playoff_predictions(user.id)
      playoff_count = playoff_predictions |> Map.values() |> List.flatten() |> length()

      %{
        id: user.id,
        name: user.name,
        email: user.email,
        is_admin: user.is_admin,
        confirmed_at: user.confirmed_at,
        inserted_at: user.inserted_at,
        prediction_count: prediction_count,
        playoff_prediction_count: playoff_count
      }
    end)
  end

  defp filter_users(users, ""), do: users

  defp filter_users(users, query) do
    query = String.downcase(query)

    Enum.filter(users, fn user ->
      String.contains?(String.downcase(user.name || ""), query) ||
        String.contains?(String.downcase(user.email || ""), query)
    end)
  end

  defp sort_users(users, field, dir) do
    Enum.sort_by(users, &Map.get(&1, field), fn a, b ->
      case dir do
        :asc -> compare_values(a, b)
        :desc -> compare_values(b, a)
      end
    end)
  end

  defp compare_values(nil, _), do: true
  defp compare_values(_, nil), do: false

  defp compare_values(a, b) when is_binary(a) and is_binary(b),
    do: String.downcase(a) <= String.downcase(b)

  defp compare_values(a, b), do: a <= b

  def sort_indicator(current_field, sort_by, sort_dir) do
    if current_field == sort_by do
      if sort_dir == :asc, do: " ↑", else: " ↓"
    else
      ""
    end
  end
end

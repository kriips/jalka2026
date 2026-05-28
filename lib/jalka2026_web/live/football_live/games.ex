defmodule Jalka2026Web.FootballLive.Games do
  use Jalka2026Web, :live_view

  alias Jalka2026.Football.TeamTranslations
  alias Jalka2026Web.Resolvers.FootballResolver

  @impl true
  def mount(_params, _session, socket) do
    matches = FootballResolver.list_matches()

    # Group matches by group letter for accordion display
    grouped_matches =
      matches
      |> Enum.group_by(& &1.group)
      |> Enum.sort_by(fn {group, _} -> group end)

    {:ok,
     assign(socket,
       matches: matches,
       grouped_matches: grouped_matches,
       expanded_groups: MapSet.new(),
       selected_match: nil,
       predictions: nil,
       crowd_confidence: nil,
       show_bottom_sheet: false
     )}
  end

  @impl true
  def handle_event("toggle_group", %{"group" => group}, socket) do
    expanded_groups =
      if MapSet.member?(socket.assigns.expanded_groups, group) do
        MapSet.delete(socket.assigns.expanded_groups, group)
      else
        MapSet.put(socket.assigns.expanded_groups, group)
      end

    {:noreply, assign(socket, expanded_groups: expanded_groups)}
  end

  def handle_event("show_match", %{"id" => id}, socket) do
    match = FootballResolver.list_match(id)

    case match do
      nil ->
        {:noreply, socket}

      match ->
        predictions = FootballResolver.get_predictions_by_match_result(id)
        crowd_confidence = FootballResolver.get_crowd_confidence(id)

        {:noreply,
         assign(socket,
           selected_match: match,
           predictions: predictions,
           crowd_confidence: crowd_confidence,
           show_bottom_sheet: true
         )}
    end
  end

  def handle_event("close_bottom_sheet", _params, socket) do
    {:noreply,
     assign(socket,
       show_bottom_sheet: false,
       selected_match: nil,
       predictions: nil,
       crowd_confidence: nil
     )}
  end

  defp group_summary(matches) do
    finished = Enum.count(matches, & &1.finished)
    total = length(matches)
    {finished, total}
  end
end

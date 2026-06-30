defmodule Jalka2026Web.FootballLive.Playoffs do
  use Jalka2026Web, :live_view

  alias Jalka2026Web.Resolvers.FootballResolver

  @impl true
  def mount(_params, _session, socket) do
    predictions = FootballResolver.get_playoff_predictions()
    # Phases are already sorted most teams -> fewest (64, 32, ...); default the round tab to the first.
    selected_phase = predictions |> List.first() |> phase_of()

    {:ok, assign(socket, predictions: predictions, selected_phase: selected_phase)}
  end

  @impl true
  def handle_event("select_phase", %{"phase" => phase}, socket) do
    {:noreply, assign(socket, selected_phase: String.to_integer(phase))}
  end

  defp phase_of(nil), do: nil
  defp phase_of({phase, _teams}), do: phase

  @doc """
  Estonian label for a playoff phase. Public so the template can reuse it for both the tabs and the
  selected round's heading.
  """
  def phase_name(2), do: "Võitja"
  def phase_name(4), do: "Finalistid"
  def phase_name(8), do: "Poolfinalistid"
  def phase_name(16), do: "Veerandfinalistid"
  def phase_name(32), do: "Kaheksandikfinalistid"
  def phase_name(64), do: "32 parimat"
  def phase_name(phase), do: "Faas #{phase}"

  @doc """
  Short tab label for a playoff phase. The full descriptive name (`phase_name/1`) is long and
  unbreakable (e.g. "Kaheksandikfinalistid"), so the tabs use these compact labels and the selected
  round's heading shows the full name.
  """
  def phase_tab_label(2), do: "Võitja"
  def phase_tab_label(4), do: "Finaal"
  def phase_tab_label(8), do: "1/2 finaal"
  def phase_tab_label(16), do: "1/4 finaal"
  def phase_tab_label(32), do: "1/8 finaal"
  def phase_tab_label(64), do: "32 parimat"
  def phase_tab_label(phase), do: "Faas #{phase}"
end

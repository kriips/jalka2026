defmodule Jalka2026Web.ResultLive.Playoff do
  use Jalka2026Web, :live_view

  alias Jalka2026Web.Resolvers.FootballResolver

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("save", values, socket) do
    FootballResolver.update_playoff_result(values["result"])
    {:noreply, socket}
  end
end

defmodule Jalka2026.Telemetry.Events do
  @moduledoc """
  Custom telemetry events for tracking application performance.

  Provides standardized telemetry events for:
  - Prediction submissions (group and playoff)
  - Leaderboard calculations
  - Page load metrics
  """

  require Logger

  @doc """
  Execute a telemetry span for prediction submission.
  Measures the time taken to save a prediction to the database.

  ## Events emitted:
  - `[:jalka2026, :prediction, :group, :start]`
  - `[:jalka2026, :prediction, :group, :stop]`
  - `[:jalka2026, :prediction, :group, :exception]`

  ## Metadata:
  - `:user_id` - The ID of the user making the prediction
  - `:match_id` - The ID of the match being predicted
  - `:group` - The group name (optional)
  """
  def span_group_prediction(metadata, fun) do
    :telemetry.span(
      [:jalka2026, :prediction, :group],
      metadata,
      fn ->
        result = fun.()
        {result, metadata}
      end
    )
  end

  @doc """
  Execute a telemetry span for playoff prediction submission.

  ## Events emitted:
  - `[:jalka2026, :prediction, :playoff, :start]`
  - `[:jalka2026, :prediction, :playoff, :stop]`
  - `[:jalka2026, :prediction, :playoff, :exception]`

  ## Metadata:
  - `:user_id` - The ID of the user making the prediction
  - `:team_id` - The ID of the team being predicted
  - `:phase` - The playoff phase (32, 16, 8, 4, 2, 1)
  - `:action` - `:add` or `:remove`
  """
  def span_playoff_prediction(metadata, fun) do
    :telemetry.span(
      [:jalka2026, :prediction, :playoff],
      metadata,
      fn ->
        result = fun.()
        {result, metadata}
      end
    )
  end

  @doc """
  Execute a telemetry span for leaderboard calculation.
  Measures the full leaderboard recalculation time.

  ## Events emitted:
  - `[:jalka2026, :leaderboard, :calculation, :start]`
  - `[:jalka2026, :leaderboard, :calculation, :stop]`
  - `[:jalka2026, :leaderboard, :calculation, :exception]`

  ## Metadata:
  - `:user_count` - Number of users in the leaderboard
  - `:match_count` - Number of finished matches
  - `:playoff_result_count` - Number of playoff results
  """
  def span_leaderboard_calculation(metadata, fun) do
    :telemetry.span(
      [:jalka2026, :leaderboard, :calculation],
      metadata,
      fn ->
        result = fun.()
        # Allow metadata enrichment from the result
        final_metadata =
          case result do
            {_computed_result, extra_meta} when is_map(extra_meta) ->
              Map.merge(metadata, extra_meta)

            _ ->
              metadata
          end

        {result, final_metadata}
      end
    )
  end

  @doc """
  Execute a telemetry span for LiveView mount.
  Measures page load time for LiveViews.

  ## Events emitted:
  - `[:jalka2026, :live_view, :mount, :start]`
  - `[:jalka2026, :live_view, :mount, :stop]`
  - `[:jalka2026, :live_view, :mount, :exception]`

  ## Metadata:
  - `:view` - The LiveView module name
  - `:connected` - Whether this is a connected mount
  - `:user_id` - The current user ID (optional)
  """
  def span_live_view_mount(metadata, fun) do
    :telemetry.span(
      [:jalka2026, :live_view, :mount],
      metadata,
      fn ->
        result = fun.()
        {result, metadata}
      end
    )
  end

  @doc """
  Execute a telemetry span for LiveView event handling.
  Measures event processing time.

  ## Events emitted:
  - `[:jalka2026, :live_view, :handle_event, :start]`
  - `[:jalka2026, :live_view, :handle_event, :stop]`
  - `[:jalka2026, :live_view, :handle_event, :exception]`

  ## Metadata:
  - `:view` - The LiveView module name
  - `:event` - The event name
  - `:user_id` - The current user ID (optional)
  """
  def span_live_view_event(metadata, fun) do
    :telemetry.span(
      [:jalka2026, :live_view, :handle_event],
      metadata,
      fn ->
        result = fun.()
        {result, metadata}
      end
    )
  end

  @doc """
  Execute a telemetry span for match simulation.
  Measures simulation calculation time.

  ## Events emitted:
  - `[:jalka2026, :simulation, :match, :start]`
  - `[:jalka2026, :simulation, :match, :stop]`
  - `[:jalka2026, :simulation, :match, :exception]`

  ## Metadata:
  - `:home_team` - Home team code
  - `:away_team` - Away team code
  - `:simulation_count` - Number of simulations run
  """
  def span_match_simulation(metadata, fun) do
    :telemetry.span(
      [:jalka2026, :simulation, :match],
      metadata,
      fn ->
        result = fun.()
        {result, metadata}
      end
    )
  end

  @doc """
  Emit a single telemetry event for counting purposes.
  """
  def emit_prediction_count(type) when type in [:group, :playoff] do
    :telemetry.execute(
      [:jalka2026, :prediction, type, :count],
      %{count: 1},
      %{timestamp: System.system_time()}
    )
  end

  @doc """
  Emit a page view event for analytics.
  """
  def emit_page_view(view_name, metadata \\ %{}) do
    :telemetry.execute(
      [:jalka2026, :page, :view],
      %{count: 1},
      Map.merge(%{view: view_name, timestamp: System.system_time()}, metadata)
    )
  end
end

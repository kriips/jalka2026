defmodule Jalka2026.Telemetry.PerformanceAlerter do
  @moduledoc """
  Monitors telemetry events for performance degradation and emits alerts.

  Attaches to telemetry events and tracks:
  - Response time thresholds
  - Error rates
  - Slow operations

  Alerts are logged and can be integrated with external monitoring systems.
  """

  use GenServer
  require Logger

  @thresholds %{
    # Prediction submission should be under 500ms
    prediction_group: 500,
    prediction_playoff: 500,
    # Leaderboard calculation should be under 2 seconds
    leaderboard_calculation: 2_000,
    # LiveView mount should be under 1 second
    live_view_mount: 1_000,
    # LiveView events should be under 500ms
    live_view_event: 500,
    # Match simulation can take up to 5 seconds
    match_simulation: 5_000
  }

  # Rolling window size for rate calculations
  @window_size_ms 60_000
  # Alert if more than 10% of operations exceed threshold
  @alert_rate_threshold 0.10
  # Minimum sample size before alerting on rates
  @min_samples 10

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    attach_handlers()

    state = %{
      metrics: %{},
      alerts: [],
      last_cleanup: System.monotonic_time(:millisecond)
    }

    # Schedule periodic cleanup of old metrics
    :timer.send_interval(30_000, :cleanup_old_metrics)

    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup_old_metrics, state) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - @window_size_ms

    # Remove old metrics from each category
    metrics =
      state.metrics
      |> Enum.map(fn {key, entries} ->
        filtered = Enum.filter(entries, fn {ts, _duration} -> ts > cutoff end)
        {key, filtered}
      end)
      |> Map.new()

    # Keep only last 100 alerts
    alerts = Enum.take(state.alerts, 100)

    {:noreply, %{state | metrics: metrics, alerts: alerts, last_cleanup: now}}
  end

  @impl true
  def handle_cast({:record_metric, key, duration_ms}, state) do
    now = System.monotonic_time(:millisecond)
    entry = {now, duration_ms}

    metrics = Map.update(state.metrics, key, [entry], fn entries -> [entry | entries] end)

    # Check for threshold violations
    state =
      if threshold = Map.get(@thresholds, key) do
        if duration_ms > threshold do
          alert = create_alert(key, duration_ms, threshold, :threshold_exceeded)
          log_alert(alert)
          %{state | metrics: metrics, alerts: [alert | state.alerts]}
        else
          %{state | metrics: metrics}
        end
      else
        %{state | metrics: metrics}
      end

    # Check rate-based alerts
    state = check_rate_alerts(state, key)

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - @window_size_ms

    stats =
      state.metrics
      |> Enum.map(fn {key, entries} ->
        recent = Enum.filter(entries, fn {ts, _} -> ts > cutoff end)
        durations = Enum.map(recent, fn {_, d} -> d end)

        if length(durations) > 0 do
          {key,
           %{
             count: length(durations),
             avg_ms: Enum.sum(durations) / length(durations),
             max_ms: Enum.max(durations),
             min_ms: Enum.min(durations),
             p95_ms: percentile(durations, 95),
             threshold_ms: Map.get(@thresholds, key),
             violations:
               Enum.count(durations, fn d ->
                 threshold = Map.get(@thresholds, key, :infinity)
                 d > threshold
               end)
           }}
        else
          {key, %{count: 0}}
        end
      end)
      |> Map.new()

    {:reply, %{stats: stats, recent_alerts: Enum.take(state.alerts, 10)}, state}
  end

  # Public API

  @doc """
  Get current performance statistics and recent alerts.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Get configured thresholds.
  """
  def get_thresholds, do: @thresholds

  # Private functions

  defp attach_handlers do
    events = [
      {[:jalka2026, :prediction, :group, :stop], :prediction_group},
      {[:jalka2026, :prediction, :playoff, :stop], :prediction_playoff},
      {[:jalka2026, :leaderboard, :calculation, :stop], :leaderboard_calculation},
      {[:jalka2026, :live_view, :mount, :stop], :live_view_mount},
      {[:jalka2026, :live_view, :handle_event, :stop], :live_view_event},
      {[:jalka2026, :simulation, :match, :stop], :match_simulation}
    ]

    Enum.each(events, fn {event, key} ->
      :telemetry.attach(
        "performance-alerter-#{key}",
        event,
        &__MODULE__.handle_telemetry_event/4,
        key
      )
    end)

    # Also attach to exception events for error tracking
    exception_events = [
      {[:jalka2026, :prediction, :group, :exception], :prediction_group_error},
      {[:jalka2026, :prediction, :playoff, :exception], :prediction_playoff_error},
      {[:jalka2026, :leaderboard, :calculation, :exception], :leaderboard_error}
    ]

    Enum.each(exception_events, fn {event, key} ->
      :telemetry.attach(
        "performance-alerter-#{key}",
        event,
        &__MODULE__.handle_exception_event/4,
        key
      )
    end)
  end

  def handle_telemetry_event(_event, measurements, _metadata, key) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
    GenServer.cast(__MODULE__, {:record_metric, key, duration_ms})
  end

  def handle_exception_event(_event, _measurements, metadata, key) do
    Logger.error(
      "[PerformanceAlerter] Exception in #{key}: #{inspect(metadata[:kind])} - #{inspect(metadata[:reason])}"
    )

    alert = %{
      type: :exception,
      key: key,
      timestamp: System.system_time(:second),
      details: %{
        kind: metadata[:kind],
        reason: inspect(metadata[:reason])
      }
    }

    GenServer.cast(__MODULE__, {:record_alert, alert})
  end

  defp check_rate_alerts(state, key) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - @window_size_ms

    case Map.get(state.metrics, key) do
      entries when is_list(entries) and length(entries) >= @min_samples ->
        recent = Enum.filter(entries, fn {ts, _} -> ts > cutoff end)

        if length(recent) >= @min_samples do
          threshold = Map.get(@thresholds, key, :infinity)
          violations = Enum.count(recent, fn {_, d} -> d > threshold end)
          rate = violations / length(recent)

          if rate > @alert_rate_threshold do
            alert =
              create_alert(key, rate * 100, @alert_rate_threshold * 100, :high_violation_rate)

            if not recently_alerted?(state.alerts, key, :high_violation_rate) do
              log_alert(alert)
              %{state | alerts: [alert | state.alerts]}
            else
              state
            end
          else
            state
          end
        else
          state
        end

      _ ->
        state
    end
  end

  defp recently_alerted?(alerts, key, type) do
    now = System.system_time(:second)
    # Don't re-alert for same issue within 5 minutes
    cooldown = 300

    Enum.any?(alerts, fn alert ->
      alert.key == key and alert.type == type and now - alert.timestamp < cooldown
    end)
  end

  defp create_alert(key, value, threshold, type) do
    %{
      key: key,
      type: type,
      value: value,
      threshold: threshold,
      timestamp: System.system_time(:second)
    }
  end

  defp log_alert(alert) do
    message =
      case alert.type do
        :threshold_exceeded ->
          "[PerformanceAlerter] ALERT: #{alert.key} exceeded threshold - " <>
            "#{Float.round(alert.value * 1.0, 1)}ms > #{alert.threshold}ms"

        :high_violation_rate ->
          "[PerformanceAlerter] ALERT: #{alert.key} high violation rate - " <>
            "#{Float.round(alert.value * 1.0, 1)}% > #{alert.threshold}%"

        _ ->
          "[PerformanceAlerter] ALERT: #{alert.key} - #{inspect(alert)}"
      end

    Logger.warning(message)

    # Emit telemetry event for external monitoring integration
    :telemetry.execute(
      [:jalka2026, :performance, :alert],
      %{count: 1},
      %{
        key: alert.key,
        type: alert.type,
        value: alert.value,
        threshold: alert.threshold
      }
    )
  end

  defp percentile([], _), do: 0

  defp percentile(values, p) when p >= 0 and p <= 100 do
    sorted = Enum.sort(values)
    rank = p / 100 * (length(sorted) - 1)
    lower = floor(rank)
    upper = ceil(rank)

    if lower == upper do
      Enum.at(sorted, lower)
    else
      lower_val = Enum.at(sorted, lower)
      upper_val = Enum.at(sorted, upper)
      lower_val + (upper_val - lower_val) * (rank - lower)
    end
  end
end

defmodule Jalka2026Web.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("jalka2026.repo.query.total_time", unit: {:native, :millisecond}),
      summary("jalka2026.repo.query.decode_time", unit: {:native, :millisecond}),
      summary("jalka2026.repo.query.query_time", unit: {:native, :millisecond}),
      summary("jalka2026.repo.query.queue_time", unit: {:native, :millisecond}),
      summary("jalka2026.repo.query.idle_time", unit: {:native, :millisecond}),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),

      # Prediction Submission Metrics
      summary("jalka2026.prediction.group.stop.duration",
        unit: {:native, :millisecond},
        tags: [:user_id, :match_id],
        description: "Time taken to save a group prediction"
      ),
      counter("jalka2026.prediction.group.count.count",
        tags: [],
        description: "Total number of group predictions submitted"
      ),
      summary("jalka2026.prediction.playoff.stop.duration",
        unit: {:native, :millisecond},
        tags: [:user_id, :phase, :action],
        description: "Time taken to save a playoff prediction"
      ),
      counter("jalka2026.prediction.playoff.count.count",
        tags: [],
        description: "Total number of playoff predictions submitted"
      ),

      # Leaderboard Calculation Metrics
      summary("jalka2026.leaderboard.calculation.stop.duration",
        unit: {:native, :millisecond},
        tags: [:user_count, :match_count],
        description: "Time taken to recalculate the full leaderboard"
      ),

      # LiveView Page Load Metrics
      summary("jalka2026.live_view.mount.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view, :connected],
        description: "Time taken to mount a LiveView"
      ),
      counter("jalka2026.page.view.count",
        tags: [:view],
        description: "Page views by LiveView module"
      ),

      # LiveView Event Handling Metrics
      summary("jalka2026.live_view.handle_event.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view, :event],
        description: "Time taken to handle a LiveView event"
      ),

      # Match Simulation Metrics
      summary("jalka2026.simulation.match.stop.duration",
        unit: {:native, :millisecond},
        tags: [:home_team, :away_team, :simulation_count],
        description: "Time taken to run match simulations"
      ),

      # Performance Alert Metrics
      counter("jalka2026.performance.alert.count",
        tags: [:key, :type],
        description: "Performance alerts triggered"
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {Jalka2026Web, :count_users, []}
    ]
  end
end

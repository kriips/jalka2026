defmodule Jalka2026Web.TelemetryHooks do
  @moduledoc """
  Telemetry hooks for LiveView lifecycle events.

  Provides automatic instrumentation for:
  - Page load metrics (mount timing)
  - Event handling metrics
  - Error tracking

  ## Usage

  In your LiveView:

      use Jalka2026Web, :live_view

  Then call the hook functions:

      def mount(params, session, socket) do
        Jalka2026Web.TelemetryHooks.emit_mount_start(__MODULE__, socket)
        # ... your mount logic ...
        result = {:ok, socket}
        Jalka2026Web.TelemetryHooks.emit_mount_stop(__MODULE__, socket)
        result
      end
  """

  require Logger

  @doc """
  Emit telemetry event for LiveView mount start.
  Call this at the beginning of your mount/3 function.
  """
  def emit_mount_start(view_module, socket) do
    start_time = System.monotonic_time()
    Process.put(:telemetry_mount_start, start_time)

    :telemetry.execute(
      [:jalka2026, :live_view, :mount, :start],
      %{system_time: System.system_time()},
      %{
        view: view_module,
        connected: Phoenix.LiveView.connected?(socket),
        user_id: get_user_id(socket)
      }
    )
  end

  @doc """
  Emit telemetry event for LiveView mount stop.
  Call this at the end of your mount/3 function.
  """
  def emit_mount_stop(view_module, socket) do
    start_time = Process.get(:telemetry_mount_start)
    duration = if start_time, do: System.monotonic_time() - start_time, else: 0

    :telemetry.execute(
      [:jalka2026, :live_view, :mount, :stop],
      %{duration: duration},
      %{
        view: view_module,
        connected: Phoenix.LiveView.connected?(socket),
        user_id: get_user_id(socket)
      }
    )

    # Also emit a page view event
    :telemetry.execute(
      [:jalka2026, :page, :view],
      %{count: 1},
      %{
        view: view_module,
        timestamp: System.system_time(),
        user_id: get_user_id(socket)
      }
    )
  end

  @doc """
  Emit telemetry event for LiveView event handling start.
  Call this at the beginning of your handle_event/3 function.
  """
  def emit_event_start(view_module, event_name, socket) do
    start_time = System.monotonic_time()
    Process.put(:telemetry_event_start, start_time)

    :telemetry.execute(
      [:jalka2026, :live_view, :handle_event, :start],
      %{system_time: System.system_time()},
      %{
        view: view_module,
        event: event_name,
        user_id: get_user_id(socket)
      }
    )
  end

  @doc """
  Emit telemetry event for LiveView event handling stop.
  Call this at the end of your handle_event/3 function.
  """
  def emit_event_stop(view_module, event_name, socket) do
    start_time = Process.get(:telemetry_event_start)
    duration = if start_time, do: System.monotonic_time() - start_time, else: 0

    :telemetry.execute(
      [:jalka2026, :live_view, :handle_event, :stop],
      %{duration: duration},
      %{
        view: view_module,
        event: event_name,
        user_id: get_user_id(socket)
      }
    )
  end

  @doc """
  Wrap a LiveView mount function with telemetry.
  Returns {:ok, socket} or {:ok, socket, options}.
  """
  def with_mount_telemetry(view_module, socket, fun) do
    emit_mount_start(view_module, socket)

    result = fun.()

    # Extract socket from result to emit stop event
    case result do
      {:ok, result_socket} ->
        emit_mount_stop(view_module, result_socket)
        result

      {:ok, result_socket, _opts} ->
        emit_mount_stop(view_module, result_socket)
        result

      other ->
        other
    end
  end

  @doc """
  Wrap a LiveView handle_event function with telemetry.
  Returns {:noreply, socket} or {:reply, map, socket}.
  """
  def with_event_telemetry(view_module, event_name, socket, fun) do
    emit_event_start(view_module, event_name, socket)

    result = fun.()

    # Extract socket from result to emit stop event
    case result do
      {:noreply, result_socket} ->
        emit_event_stop(view_module, event_name, result_socket)
        result

      {:reply, _reply, result_socket} ->
        emit_event_stop(view_module, event_name, result_socket)
        result

      other ->
        other
    end
  end

  # Helper to safely get user_id from socket assigns
  defp get_user_id(socket) do
    case socket.assigns do
      %{current_user: %{id: id}} -> id
      _ -> nil
    end
  end
end

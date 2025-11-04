defmodule Jalka2026.Test.TimeHelpers do
  @moduledoc false
  # Simple helpers; can be replaced with libraries like Mox or Mock for time if needed.

  def freeze_now do
    put_env(:jalka2026, :frozen_now, DateTime.utc_now())
  end

  def advance_ms(ms) do
    current = get_env(:jalka2026, :frozen_now) || DateTime.utc_now()
    new = DateTime.add(current, ms, :millisecond)
    put_env(:jalka2026, :frozen_now, new)
    new
  end

  def now do
    get_env(:jalka2026, :frozen_now) || DateTime.utc_now()
  end

  defp put_env(app, key, value), do: Application.put_env(app, key, value)
  defp get_env(app, key), do: Application.get_env(app, key)
end

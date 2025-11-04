defmodule Jalka2026.Ingestion.ConfigurationValidationTest do
  use ExUnit.Case, async: true
  alias Jalka2026.Ingestion.Configuration

  test "polling interval must be >= 30" do
    changeset = Configuration.changeset(%Configuration{}, %{polling_interval_seconds: 10, feed_enabled: true, max_retries: 5, degraded_mode: false})
    refute changeset.valid?
    assert "must be greater than or equal to 30" in errors_on(changeset)[:polling_interval_seconds]
  end

  test "max_retries bounds" do
    low = Configuration.changeset(%Configuration{}, %{polling_interval_seconds: 60, feed_enabled: true, max_retries: 0, degraded_mode: false})
    refute low.valid?
    high = Configuration.changeset(%Configuration{}, %{polling_interval_seconds: 60, feed_enabled: true, max_retries: 11, degraded_mode: false})
    refute high.valid?
  end

  test "feed_url format" do
    cs = Configuration.changeset(%Configuration{}, %{polling_interval_seconds: 60, feed_enabled: true, max_retries: 5, degraded_mode: false, feed_url: "ftp://example.com"})
    refute cs.valid?
  end

  test "valid baseline" do
    cs = Configuration.changeset(%Configuration{}, %{polling_interval_seconds: 60, feed_enabled: true, max_retries: 5, degraded_mode: false, feed_url: "https://example.com"})
    assert cs.valid?
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end

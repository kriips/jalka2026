defmodule Jalka2026Web.Hooks.PredictionsHook do
  @moduledoc """
  LiveView on_mount hook that checks whether predictions are still open.

  ## Modes

    * `:require_open` – halts with redirect when the prediction deadline has passed
    * `:assign_status` – assigns `predictions_open` boolean (for templates that
      conditionally show edit controls)
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  @doc false
  def on_mount(:require_open, _params, _session, socket) do
    if Jalka2026Web.LiveHelpers.predictions_open?() do
      {:cont, assign(socket, :predictions_open, true)}
    else
      {:halt,
       socket
       |> put_flash(:error, "Ennustamine on suletud - turniir on alanud")
       |> redirect(to: "/")}
    end
  end

  def on_mount(:assign_status, _params, _session, socket) do
    {:cont, assign(socket, :predictions_open, Jalka2026Web.LiveHelpers.predictions_open?())}
  end
end

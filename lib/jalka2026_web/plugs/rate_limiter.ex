defmodule Jalka2026Web.Plugs.RateLimiter do
  @moduledoc """
  Rate limiting plug using Hammer to protect against brute force attacks
  and abuse on authentication and other sensitive endpoints.

  Usage in router:
    plug(Jalka2026Web.Plugs.RateLimiter, :login)
    plug(Jalka2026Web.Plugs.RateLimiter, :registration)
    plug(Jalka2026Web.Plugs.RateLimiter, :password_reset)
  """
  import Plug.Conn
  import Phoenix.Controller, only: [put_flash: 3, redirect: 2]

  @rate_limits %{
    login:
      {60_000, 5, "/users/log_in",
       "Liiga palju sisselogimiskatseid. Proovi uuesti 1 minuti pärast."},
    registration:
      {300_000, 3, "/users/register",
       "Liiga palju registreerimiskatseid. Proovi uuesti 5 minuti pärast."},
    password_reset:
      {300_000, 3, "/users/reset_password",
       "Liiga palju parooli taastamise katseid. Proovi uuesti 5 minuti pärast."}
  }

  def init(action) when is_atom(action), do: action

  def call(conn, action) do
    if Application.get_env(:jalka2026, :environment) == :test do
      conn
    else
      do_rate_limit(conn, action)
    end
  end

  defp do_rate_limit(conn, action) do
    {window_ms, max_requests, redirect_to, error_message} = @rate_limits[action]
    key = "#{action}:#{client_ip(conn)}"
    retry_after = Integer.to_string(div(window_ms, 1000))

    case Hammer.check_rate(key, window_ms, max_requests) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_resp_header("retry-after", retry_after)
        |> put_flash(:error, error_message)
        |> redirect(to: redirect_to)
        |> halt()
    end
  end

  defp client_ip(conn) do
    # Check for forwarded IP (when behind proxy/load balancer like Fly.io)
    forwarded_for =
      conn
      |> get_req_header("x-forwarded-for")
      |> List.first()

    case forwarded_for do
      nil ->
        conn.remote_ip |> :inet.ntoa() |> to_string()

      forwarded ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()
    end
  end
end

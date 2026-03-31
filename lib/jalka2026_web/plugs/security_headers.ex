defmodule Jalka2026Web.Plugs.SecurityHeaders do
  @moduledoc """
  Plug that adds additional security headers beyond Phoenix defaults.
  Includes Content-Security-Policy, HSTS, Referrer-Policy, and Permissions-Policy.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_csp_header()
    |> put_resp_header("strict-transport-security", "max-age=63072000; includeSubDomains; preload")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=(), payment=()")
    |> put_resp_header("x-download-options", "noopen")
    |> put_resp_header("x-permitted-cross-domain-policies", "none")
  end

  defp put_csp_header(conn) do
    nonce = generate_nonce()
    conn = assign(conn, :csp_nonce, nonce)

    csp =
      [
        "default-src 'self'",
        "script-src 'self' 'nonce-#{nonce}'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: https://flagcdn.com",
        "font-src 'self'",
        "connect-src 'self' wss://jalka2026.fly.dev wss://jalka.eys.ee ws://localhost:*",
        "frame-ancestors 'none'",
        "base-uri 'self'",
        "form-action 'self'"
      ]
      |> Enum.join("; ")

    put_resp_header(conn, "content-security-policy", csp)
  end

  defp generate_nonce do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end
end

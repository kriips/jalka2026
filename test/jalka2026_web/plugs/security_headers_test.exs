defmodule Jalka2026Web.Plugs.SecurityHeadersTest do
  use Jalka2026Web.ConnCase

  alias Jalka2026Web.Plugs.SecurityHeaders

  describe "call/2" do
    test "adds security headers to connection" do
      conn =
        build_conn()
        |> SecurityHeaders.call([])

      assert get_resp_header(conn, "strict-transport-security") == [
               "max-age=63072000; includeSubDomains; preload"
             ]

      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]

      assert get_resp_header(conn, "permissions-policy") == [
               "camera=(), microphone=(), geolocation=(), payment=()"
             ]

      assert get_resp_header(conn, "x-download-options") == ["noopen"]
      assert get_resp_header(conn, "x-permitted-cross-domain-policies") == ["none"]
    end

    test "adds content-security-policy header with nonce" do
      conn =
        build_conn()
        |> SecurityHeaders.call([])

      [csp] = get_resp_header(conn, "content-security-policy")
      assert csp =~ "default-src 'self'"
      assert csp =~ "script-src 'self' 'nonce-"
      assert csp =~ "style-src 'self' 'unsafe-inline'"
      assert csp =~ "frame-ancestors 'none'"
    end

    test "assigns csp_nonce to conn" do
      conn =
        build_conn()
        |> SecurityHeaders.call([])

      assert conn.assigns[:csp_nonce] != nil
      assert is_binary(conn.assigns[:csp_nonce])
    end
  end

  describe "init/1" do
    test "passes through opts" do
      assert SecurityHeaders.init([]) == []
      assert SecurityHeaders.init(foo: :bar) == [foo: :bar]
    end
  end
end

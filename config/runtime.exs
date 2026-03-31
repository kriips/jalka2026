import Config

if Config.config_env() == :dev do
  # Works because the dependency is already compiled
  DotenvParser.load_file(".env")
end

maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

db_config = Application.get_env(:jalka2026, Jalka2026.Repo)

database_url =
  case Config.config_env() do
    :test ->
      "postgres://#{db_config[:username]}:#{db_config[:password]}@#{db_config[:hostname]}/#{db_config[:database]}"

    _ ->
      System.get_env("DATABASE_URL") ||
        raise """
        environment variable DATABASE_URL is missing.
        For example: ecto://USER:PASS@HOST/DATABASE
        """
  end

config :jalka2026, Jalka2026.Repo,
  # ssl: true,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "15"),
  socket_options: maybe_ipv6,
  # Shed load gracefully under concurrent LiveView connections.
  # queue_target: if avg checkout time exceeds this (ms), DBConnection
  #   starts randomly dropping queued requests to reduce pressure.
  # queue_interval: window (ms) over which queue_target is measured.
  queue_target: String.to_integer(System.get_env("DB_QUEUE_TARGET") || "50"),
  queue_interval: String.to_integer(System.get_env("DB_QUEUE_INTERVAL") || "1000")

# Competition ID - identifies the active tournament for this deployment
# Override via COMPETITION_ID env var; defaults to "wc-2026"
# Format: "type-year" e.g., "wc-2026", "euros-2028", "wc-2030"
if competition_id = System.get_env("COMPETITION_ID") do
  config :jalka2026, :competition_id, competition_id
end

# Email configuration
if Config.config_env() == :prod do
  # Email sender address (optional)
  if email_from = System.get_env("EMAIL_FROM") do
    config :jalka2026, :email_from, {"Jalka2026", email_from}
  end

  # Enable email notifications in production if EMAIL_NOTIFICATIONS_ENABLED is set to "true"
  # Uses LocalAdapter by default (logs emails to console)
  # To send real emails, add an HTTP-based adapter like bamboo_postmark or bamboo_sendgrid
  if System.get_env("EMAIL_NOTIFICATIONS_ENABLED") == "true" do
    config :jalka2026, :email_notifications_enabled, true
  end
end

case Config.config_env() do
  :prod ->
    app_name =
      System.get_env("FLY_APP_NAME") ||
        raise "FLY_APP_NAME not available"

    secret_key =
      System.get_env("SECRET_KEY_BASE") ||
        raise """
        environment variable SECRET_KEY_BASE is missing.
        """

    signing_salt =
      System.get_env("SIGNING_SALT") ||
        raise """
        environment variable SIGNING_SALT is missing.
        """

    port =
      System.get_env("PORT") ||
        raise """
        environment variable PORT is missing.
        """

    config :jalka2026, Jalka2026Web.Endpoint,
      url: [host: "#{app_name}.fly.dev", port: 80],
      http: [
        ip: {0, 0, 0, 0, 0, 0, 0, 0},
        port: String.to_integer(port)
      ],
      secret_key_base: secret_key,
      live_view: [signing_salt: signing_salt],
      server: true,
      check_origin: [
        "//jalka2026.fly.dev",
        "//jalka.eys.ee"
      ]

    config :libcluster,
      debug: true,
      topologies: [
        fly6pn: [
          strategy: Cluster.Strategy.DNSPoll,
          config: [
            polling_interval: 5_000,
            query: "#{app_name}.internal",
            node_basename: app_name
          ]
        ]
      ]

  :dev ->
    config :jalka2026, Jalka2026Web.Endpoint, server: true

  :test ->
    config :jalka2026, Jalka2026Web.Endpoint, server: false
end

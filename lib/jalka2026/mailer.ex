defmodule Jalka2026.Mailer do
  @moduledoc """
  Mailer module for sending emails using Bamboo.

  In development, emails are logged to the console.
  In production, emails are sent via SMTP using configuration from environment variables.
  """

  use Bamboo.Mailer, otp_app: :jalka2026
end

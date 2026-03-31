defmodule Jalka2026Web do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels and so on.

  This can be used in your application as:

      use Jalka2026Web, :controller
      use Jalka2026Web, :html

  The definitions below will be executed for every component,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: Jalka2026Web.Layouts]

      import Phoenix.LiveView.Router
      import Plug.Conn
      use Gettext, backend: Jalka2026Web.Gettext
      alias Jalka2026Web.Router.Helpers, as: Routes

      unquote(verified_routes())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {Jalka2026Web.Layouts, :live}

      unquote(html_helpers())
      import Jalka2026Web.LiveHelpers
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      use Gettext, backend: Jalka2026Web.Gettext
    end
  end

  defp html_helpers do
    quote do
      # HTML escaping functionality
      import Phoenix.HTML

      # Core UI components and translation
      import Phoenix.Component

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Form helpers
      import Phoenix.HTML.Form
      use PhoenixHTMLHelpers

      import Jalka2026Web.ErrorHelpers
      use Gettext, backend: Jalka2026Web.Gettext
      alias Jalka2026Web.Router.Helpers, as: Routes

      # Team name translations (Estonian)
      alias Jalka2026.Football.TeamTranslations

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: Jalka2026Web.Endpoint,
        router: Jalka2026Web.Router,
        statics: Jalka2026Web.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/component/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

defmodule Jalka2026Web.Router do
  use Jalka2026Web, :router

  import Jalka2026Web.UserAuth

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {Jalka2026Web.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:fetch_current_user)
  end

  pipeline :rate_limit_auth do
    plug(Jalka2026Web.Plugs.RateLimiter, :login)
  end

  pipeline :rate_limit_register do
    plug(Jalka2026Web.Plugs.RateLimiter, :registration)
  end

  pipeline :rate_limit_reset do
    plug(Jalka2026Web.Plugs.RateLimiter, :password_reset)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  # Public LiveViews - user is optional
  scope "/", Jalka2026Web do
    pipe_through(:browser)

    live_session :public,
      on_mount: [
        {Jalka2026Web.Hooks.AuthHook, :assign_user},
        {Jalka2026Web.Hooks.CompetitionHook, :default}
      ] do
      live("/leaderboard", LeaderboardLive.Leaderboard, :view)
      live("/football/games/:id", FootballLive.Game, :view)
      live("/football/games", FootballLive.Games, :view)
      live("/football/playoffs", FootballLive.Playoffs, :view)
      live("/football/scenarios", FootballLive.GroupScenarios, :view)
      live("/football/scenarios/:group", FootballLive.GroupScenarios, :view)
      live("/football/simulate", FootballLive.MatchSimulation, :view)
      live("/football/user/:id", FootballLive.User, :view)
      live("/football/user/:id/analytics", FootballLive.Analytics, :view)
      live("/football/compare", FootballLive.Compare, :view)
      live("/", PageLive, :index)
    end
  end

  # Bracket challenge routes - require authentication
  scope "/", Jalka2026Web do
    pipe_through([:browser, :require_authenticated_user])

    live_session :authenticated_bracket,
      on_mount: [
        {Jalka2026Web.Hooks.AuthHook, :require_user},
        {Jalka2026Web.Hooks.CompetitionHook, :default}
      ] do
      live("/bracket", BracketLive.Bracket, :view)
      live("/bracket/user/:user_id", BracketLive.Bracket, :view)
      live("/bracket/compare", BracketLive.Compare, :compare)
      live("/bracket/compare/:user_id", BracketLive.Compare, :compare)
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", Jalka2026Web do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Application.compile_env!(:jalka2026, :env) in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through(:browser)
      live_dashboard("/dashboard", metrics: Jalka2026Web.Telemetry)
    end
  end

  ## Authentication routes

  # GET routes - no rate limiting needed (just render forms)
  scope "/", Jalka2026Web do
    pipe_through([:browser, :redirect_if_user_is_authenticated])

    live_session :unauthenticated,
      on_mount: [
        {Jalka2026Web.Hooks.AuthHook, :assign_user},
        {Jalka2026Web.Hooks.CompetitionHook, :default}
      ] do
      live("/users/register", UserRegistrationLive.New, :new)
    end

    get("/users/log_in", UserSessionController, :new)
    get("/users/reset_password", UserResetPasswordController, :new)
    get("/users/reset_password/:token", UserResetPasswordController, :edit)
  end

  # POST/PUT routes - rate limited to prevent brute force
  scope "/", Jalka2026Web do
    pipe_through([:browser, :redirect_if_user_is_authenticated, :rate_limit_auth])
    post("/users/log_in", UserSessionController, :create)
  end

  scope "/", Jalka2026Web do
    pipe_through([:browser, :redirect_if_user_is_authenticated, :rate_limit_register])
    post("/users/register", UserRegistrationController, :create)
  end

  scope "/", Jalka2026Web do
    pipe_through([:browser, :redirect_if_user_is_authenticated, :rate_limit_reset])
    post("/users/reset_password", UserResetPasswordController, :create)
    put("/users/reset_password/:token", UserResetPasswordController, :update)
  end

  # Authenticated user settings - mix of controller routes and LiveViews
  scope "/", Jalka2026Web do
    pipe_through([:browser, :require_authenticated_user])

    get("/users/settings", UserSettingsController, :edit)
    put("/users/settings", UserSettingsController, :update)
    put("/users/settings/theme", UserSettingsController, :update_theme)
    get("/users/settings/confirm_email/:token", UserSettingsController, :confirm_email)

    live_session :authenticated_user,
      on_mount: [
        {Jalka2026Web.Hooks.AuthHook, :require_user},
        {Jalka2026Web.Hooks.CompetitionHook, :default}
      ] do
      live("/users/favorite-teams", UserLive.FavoriteTeams, :edit)
      live("/users/rivalries", UserLive.Rivalries, :edit)
    end
  end

  # Admin routes - require authentication AND admin role
  scope "/admin", Jalka2026Web do
    pipe_through([:browser, :require_authenticated_user, :require_admin])

    live_session :admin,
      on_mount: [
        {Jalka2026Web.Hooks.AuthHook, :require_admin},
        {Jalka2026Web.Hooks.CompetitionHook, :default}
      ] do
      live("/", AdminLive.Dashboard, :index)
      live("/results/:type", AdminLive.Results, :index)
      live("/users", AdminLive.Users, :index)
      live("/predictions", AdminLive.Predictions, :index)

      # Keep old result routes protected by admin now
      live("/result/group", ResultLive.Groups, :create)
      live("/result/playoff", ResultLive.Playoff, :create)
    end
  end

  # Prediction routes - require authentication AND predictions to be open
  scope "/", Jalka2026Web do
    pipe_through([:browser, :require_authenticated_user, :require_predictions_open])

    live_session :authenticated_predictions,
      on_mount: [
        {Jalka2026Web.Hooks.AuthHook, :require_user},
        {Jalka2026Web.Hooks.CompetitionHook, :default}
      ] do
      live("/football/predict", UserPredictionLive.Navigate, :navigate)
      live("/football/predict/playoffs", UserPredictionLive.Playoffs, :edit)
      live("/football/predict/:group", UserPredictionLive.Groups, :edit)
    end
  end

  scope "/", Jalka2026Web do
    pipe_through([:browser])
    delete("/users/log_out", UserSessionController, :delete)
    get("/users/confirm", UserConfirmationController, :new)
    post("/users/confirm", UserConfirmationController, :create)
    get("/users/confirm/:token", UserConfirmationController, :confirm)
  end
end

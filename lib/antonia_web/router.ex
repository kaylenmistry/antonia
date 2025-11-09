defmodule AntoniaWeb.Router do
  use AntoniaWeb, :router

  alias AntoniaWeb.Plugs.FetchCurrentUser
  alias AntoniaWeb.Plugs.RedirectAuthenticatedUser
  alias AntoniaWeb.Plugs.ReferrerPolicy
  alias AntoniaWeb.Plugs.RequireAdminUser
  alias AntoniaWeb.Plugs.RequireAuthenticatedUser

  @csp :antonia
       |> Application.compile_env(:content_security_policy)
       |> Enum.join("; ")

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AntoniaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => @csp}
    plug FetchCurrentUser
    plug ReferrerPolicy
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/auth", AntoniaWeb do
    pipe_through [:browser, RequireAuthenticatedUser]

    get "/logout", AuthController, :logout
  end

  # Authentication routes
  scope "/auth", AntoniaWeb do
    pipe_through [:browser, RedirectAuthenticatedUser]

    get "/login", AuthController, :login
    get "/register", AuthController, :register
    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  scope "/", AntoniaWeb do
    pipe_through :browser

    live "/", SplashLive
    live "/reports/:id", ReportLive
    live "/reporting", ReportingLive
    live "/reporting/groups/:id", ReportingLive
    live "/reporting/groups/:id/buildings/:building_id", BuildingLive
    live "/reporting/groups/:id/buildings/:building_id/stores/:store_id", StoreLive
    live "/submit/:token", ReportSubmissionLive
  end

  scope "/app", AntoniaWeb do
    pipe_through [:browser, RequireAuthenticatedUser]

    live "/", GroupsLive
    live "/groups/:id", ReportingLive
    live "/groups/:id/buildings/:building_id", BuildingLive
    live "/groups/:id/buildings/:building_id/stores/:store_id", StoreLive
  end

  # Admin routes (authenticated users only)
  scope "/admin", AntoniaWeb do
    pipe_through [:browser, RequireAuthenticatedUser, RequireAdminUser]

    import Oban.Web.Router
    import Backpex.Router

    oban_dashboard("/oban")
    backpex_routes()

    live_session :default, on_mount: Backpex.InitAssigns do
      live_resources("/users", Admin.Resources.UserLive)
      live_resources("/stores", Admin.Resources.StoreLive)
      live_resources("/groups", Admin.Resources.GroupLive)
      live_resources("/buildings", Admin.Resources.BuildingLive)
      live_resources("/reports", Admin.Resources.ReportLive)
      live_resources("/attachments", Admin.Resources.AttachmentLive)
      live_resources("/email_logs", Admin.Resources.EmailLogLive)
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:antonia, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AntoniaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

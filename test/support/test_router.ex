defmodule PhoenixKitHelloWorld.Test.Router do
  @moduledoc """
  Minimal Router used by the LiveView test suite. Routes match the URLs
  produced by `PhoenixKitHelloWorld.Paths` so `live/2` calls in tests
  work with exactly the same URLs the LiveViews push themselves to.

  `PhoenixKit.Utils.Routes.path/1` defaults to no URL prefix when the
  `phoenix_kit_settings` table is unavailable, and admin paths always
  get the default locale ("en") prefix — so our base becomes
  `/en/admin/hello-world`.
  """

  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {PhoenixKitHelloWorld.Test.Layouts, :root})
    plug(:protect_from_forgery)
  end

  scope "/en/admin/hello-world", PhoenixKitHelloWorld.Web do
    pipe_through(:browser)

    live_session :hello_world_test,
      layout: {PhoenixKitHelloWorld.Test.Layouts, :app},
      on_mount: {PhoenixKitHelloWorld.Test.Hooks, :assign_scope} do
      live("/", HelloLive, :index)
      live("/events", EventsLive, :index)
      live("/components", ComponentsLive, :index)
      live("/notifications", NotificationsLive, :index)
    end
  end
end

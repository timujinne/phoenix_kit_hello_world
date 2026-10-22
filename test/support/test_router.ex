defmodule PhoenixKitHelloWorld.Test.Router do
  @moduledoc """
  Minimal Router used by the LiveView test suite. Routes match the URLs
  produced by `PhoenixKitHelloWorld.Paths` so `live/2` calls in tests
  work with exactly the same URLs the LiveViews push themselves to.

  `PhoenixKit.Utils.Routes.path/1` defaults to no URL prefix when the
  `phoenix_kit_settings` table is unavailable. Since core 2.62 it also emits
  no locale segment on a single-language site, which the test database is, so
  our base is `/admin/hello-world`. (A multilingual host that serves its
  primary language with a prefix still gets `/en/admin/...`.)
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

  # The prefixless base is where `Paths.*` land on a single-language site. The
  # `/en` base is the same pages as a multilingual host serves them; it is a
  # separate live_session, so a patch does not cross between the two.
  for {base, session} <- [
        {"/admin/hello-world", :hello_world_test},
        {"/en/admin/hello-world", :hello_world_test_locale}
      ] do
    scope base, PhoenixKitHelloWorld.Web do
      pipe_through(:browser)

      live_session session,
        layout: {PhoenixKitHelloWorld.Test.Layouts, :app},
        on_mount: {PhoenixKitHelloWorld.Test.Hooks, :assign_scope} do
        live("/", HelloLive, :index)
        live("/events", EventsLive, :index)
        live("/components", ComponentsLive, :index)
        live("/notifications", NotificationsLive, :index)
      end
    end
  end
end

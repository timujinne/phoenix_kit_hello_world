# Template scaffold — uncomment the stubs below when tabs with `live_view:`
# are not expressive enough, or the module needs public routes. Not wired up
# by default; enable by uncommenting `route_module/0` in the main module.

defmodule PhoenixKitHelloWorld.Routes do
  @moduledoc """
  Route module for complex routing needs.

  The `live_view` field on each tab in `admin_tabs/0` is the default way to
  route an admin page — PhoenixKit generates one route per tab, and the tab's
  `path` may carry dynamic segments (`"hello-world/:id/edit"`), so list, form
  and edit pages are all tabs (hidden ones set `visible: false` and
  `parent:`). This module routes its four pages that way.

  Implement this module, and return it from `route_module/0`, for what tabs
  cannot express: public-facing routes, custom controllers, or many `live`
  routes you do not want to enumerate as tabs.

  ## Available functions

  | Function                  | Position in router                        | Use for                               |
  |---------------------------|-------------------------------------------|---------------------------------------|
  | `admin_locale_routes/0`   | Inside admin live_session (localized)     | Admin LiveView routes                 |
  | `admin_routes/0`          | Inside admin live_session (non-localized) | Same, for non-locale-prefixed paths   |
  | `generate/1`              | Early, before localized routes            | Non-catch-all public routes           |
  | `public_routes/1`         | **Last**, after all other routes          | Catch-all public routes               |

  ## When you need this

  If every page of your module is an admin LiveView, you DON'T need this —
  give each page a tab with `live_view:`. Delete this file and leave
  `route_module/0` at its `nil` default.

  Reach for it when you want localized and non-localized admin variants with
  their own `:as` names, many admin routes without a tab each, or anything
  that is not a `live` route. Tabs and a route module coexist, but never
  register the same path both ways. `admin_routes/0` and
  `admin_locale_routes/0` may contain only `live` declarations — controllers,
  `forward`, nested `scope` and `pipe_through` go in `generate/1` or
  `public_routes/1`.

  ## Route ordering warning

  If your module has catch-all routes like `/:slug` or `/:group/*path`, they
  **must** go in `public_routes/1` — NOT `generate/1`. Routes in `generate/1`
  are placed early in the router and will intercept `/admin/*` paths, breaking
  the admin panel.

  ## Example: admin routes declared here instead of as tabs

      def admin_locale_routes do
        quote do
          live "/admin/my-module", MyModule.Web.Index, :index, as: :my_module_localized
          live "/admin/my-module/new", MyModule.Web.Form, :new, as: :my_module_new_localized
          live "/admin/my-module/:id/edit", MyModule.Web.Form, :edit, as: :my_module_edit_localized
          live "/admin/settings/my-module", MyModule.Web.Settings, :index, as: :my_module_settings_localized
        end
      end

      def admin_routes do
        quote do
          live "/admin/my-module", MyModule.Web.Index, :index, as: :my_module
          live "/admin/my-module/new", MyModule.Web.Form, :new, as: :my_module_new
          live "/admin/my-module/:id/edit", MyModule.Web.Form, :edit, as: :my_module_edit
          live "/admin/settings/my-module", MyModule.Web.Settings, :index, as: :my_module_settings
        end
      end
  """

  # ── Admin routes ─────────────────────────────────────────────────────
  # Uncomment and customize these to declare admin routes here rather than as
  # tabs with `live_view:`.
  # Both functions must define the same routes — one for localized paths
  # (with /:locale prefix) and one for non-localized paths.
  #
  # IMPORTANT: Every route needs a unique `:as` name. Use a `_localized`
  # suffix to distinguish the two sets.

  # def admin_locale_routes do
  #   quote do
  #     live "/admin/hello-world", PhoenixKitHelloWorld.Web.HelloLive, :index,
  #       as: :hello_world_localized
  #   end
  # end

  # def admin_routes do
  #   quote do
  #     live "/admin/hello-world", PhoenixKitHelloWorld.Web.HelloLive, :index,
  #       as: :hello_world
  #   end
  # end

  # ── Public routes ────────────────────────────────────────────────────
  # Uncomment if your module needs public (non-admin) routes.
  #
  # Use `generate/1` for specific, non-catch-all public routes (placed
  # early in the router).

  # def generate(url_prefix) do
  #   quote do
  #     scope unquote(url_prefix) do
  #       pipe_through [:browser, :phoenix_kit_auto_setup]
  #
  #       post "/hello-world/submit",
  #            PhoenixKitHelloWorld.Web.SubmitController,
  #            :submit
  #     end
  #   end
  # end

  # Use `public_routes/1` for catch-all routes like `/:slug` or
  # `/:group/*path`. These are placed LAST in the router, after all
  # admin and localized routes, so they won't intercept other paths.
  # WARNING: Putting catch-all routes in `generate/1` will break the
  # admin panel.

  # def public_routes(url_prefix) do
  #   quote do
  #     scope unquote(url_prefix) do
  #       pipe_through [:browser, :phoenix_kit_auto_setup]
  #
  #       live "/:slug", PhoenixKitHelloWorld.Web.PageLive, :show
  #     end
  #   end
  # end
end

defmodule PhoenixKitHelloWorld do
  @moduledoc """
  A minimal PhoenixKit plugin module — use this as a starting point for your own.

  This module demonstrates every required and commonly-used optional callback from
  the `PhoenixKit.Module` behaviour. Copy this project, rename it, and replace the
  callbacks with your own logic.

  ## How it works

  1. `use PhoenixKit.Module` marks this module as a plugin (persists a
     `@phoenix_kit_module` attribute in the `.beam` file).
  2. PhoenixKit scans `.beam` files at startup and discovers this module
     automatically — no config line needed.
  3. The callbacks below tell PhoenixKit how to integrate the module:
     admin tabs, permissions, enable/disable toggling, etc.

  ## Installation

  Add to your parent app's `mix.exs`:

      {:phoenix_kit_hello_world, "~> 0.2"}

  Or for local development:

      {:phoenix_kit_hello_world, path: "../phoenix_kit_hello_world"}

  Then run `mix deps.get`. That's it — the module appears in the admin
  Modules page and sidebar automatically.

  ## Database

  This module has no tables — it's a template, and a demo module has no
  business creating one in every host that installs it. When YOUR module needs
  tables, it ships the migrations that create them: a versioned coordinator in
  your own repo, returned from `migration_module/0`, never a new `Vxxx` in core
  `phoenix_kit`'s chain. `mix phoenix_kit.update` in the host app then installs
  and upgrades them, so there is no install task to write. The copyable
  (all-comments) template is `lib/phoenix_kit_hello_world/migrations.ex`.

  ## What you get for free

  - Admin sidebar tab (appears/disappears when module is toggled)
  - Entry in the admin Modules page with enable/disable toggle
  - Permission key in the roles/permissions matrix
  - Live sidebar updates (no page reload needed when toggling)
  - Route auto-generated at compile time from the `live_view` field

  ## Navigation paths

  All `href` attributes and `redirect/2` calls must go through
  `PhoenixKit.Utils.Routes.path/1` — never use relative paths.
  Create a `Paths` module (e.g., `MyModule.Paths`) that wraps
  `Routes.path/1` to centralize your module's paths in one place.
  See the README for the full pattern.

  ## JavaScript

  A LiveView hook must be in the host's single `LiveSocket` at construction
  time, so hooks are delivered as **prebuilt bundles declared by
  `js_sources/0`** — never from an inline `<script>`, which morphdom does not
  execute when the page is reached via `navigate/2` (the hook then binds to
  nothing, silently).

  Prefer a core hook first: core's hooks ship in PhoenixKit's own bundle and
  are registered on every page load. When core has none, ship your own
  `priv/static/assets/<app>.js` assigning hooks to a namespaced global and
  declare it:

      @impl PhoenixKit.Module
      def js_sources do
        [%{app: :my_module, file: "static/assets/my_module.js", global: "MyModuleHooks"}]
      end

  The `:phoenix_kit_js_sources` compiler folds that global into
  `window.PhoenixKitHooks`, which the host already spreads into the
  `LiveSocket` — no parent-app `app.js` edit. The `:global` must be unique
  across modules (the compiler fails loudly on a collision) and hook names
  inside the bundle must be namespaced too, since the fold is last-write-wins
  on hook names and would otherwise override a core hook.

  hello_world ships no hooks of its own, so it leaves `js_sources/0` at its
  `[]` default.

  ## Callbacks overview

  | Callback                  | Required? | What it does                                      |
  |---------------------------|-----------|---------------------------------------------------|
  | `module_key/0`            | Yes       | Unique string key (used in settings, permissions)  |
  | `module_name/0`           | Yes       | Human-readable name (shown in admin UI)            |
  | `enabled?/0`              | Yes       | Whether the module is currently on                 |
  | `enable_system/0`         | Yes       | Turn the module on (persists to DB)                |
  | `disable_system/0`        | Yes       | Turn the module off (persists to DB)               |
  | `permission_metadata/0`   | No        | Icon, label, description for permissions UI        |
  | `admin_tabs/0`            | No        | Tabs to add to the admin sidebar                   |
  | `settings_tabs/0`         | No        | Tabs to add to the admin settings page             |
  | `children/0`              | No        | Supervisor child specs (GenServers, workers, etc.) |
  | `version/0`               | No        | Version string (default: "0.0.0")                  |
  | `get_config/0`            | No        | Stats/config map shown on the Modules page         |
  | `route_module/0`          | No        | Module providing custom route macros               |
  | `user_dashboard_tabs/0`   | No        | Tabs for the user-facing dashboard                 |
  | `migration_module/0`      | No        | Versioned migration coordinator module             |
  | `css_sources/0`           | No        | OTP apps whose templates Tailwind scans            |
  | `js_sources/0`            | No        | Prebuilt JS hook bundles for the host LiveSocket   |
  | `required_integrations/0` | No        | Integration provider keys this module needs        |
  | `integration_providers/0` | No        | Custom provider definitions to contribute          |
  """

  use PhoenixKit.Module

  # Single-sourced from mix.exs, read at compile time, so a version bump is one
  # edit. The behaviour test asserts version/0 against Mix.Project.config().
  @version Mix.Project.config()[:version]

  alias PhoenixKit.Dashboard.Tab
  alias PhoenixKit.Settings

  # ===========================================================================
  # Required callbacks
  # ===========================================================================

  @impl PhoenixKit.Module
  @doc "Unique key for this module. Used in settings, permissions, and PubSub events."
  def module_key, do: "hello_world"

  @impl PhoenixKit.Module
  @doc "Display name shown in the admin UI."
  def module_name, do: "Hello World"

  @impl PhoenixKit.Module
  @doc """
  Whether the module is currently enabled.

  Reads from the DB-backed settings table. Defensive against three
  failure modes that can hit before/around DB availability:

  - `rescue _`: DB not running, table missing, schema mismatch, etc.
  - `catch :exit, _`: connection pool checkout `EXIT` (e.g. when a
    test sandbox owner has just stopped — test-environment artifact,
    but harmless to handle in production code too).

  All branches return `false` so callers don't need to special-case
  startup ordering.
  """
  def enabled? do
    Settings.get_boolean_setting("hello_world_enabled", false)
  rescue
    _ -> false
  catch
    :exit, _ -> false
  end

  @impl PhoenixKit.Module
  @doc """
  Enables the module by persisting a boolean setting.

  `update_boolean_setting_with_module/3` stores the value and tracks which
  module owns the setting. The third argument must match `module_key/0`.
  """
  def enable_system do
    Settings.update_boolean_setting_with_module("hello_world_enabled", true, module_key())
  end

  @impl PhoenixKit.Module
  @doc "Disables the module. Same pattern as `enable_system/0`."
  def disable_system do
    Settings.update_boolean_setting_with_module("hello_world_enabled", false, module_key())
  end

  # ===========================================================================
  # Optional callbacks (remove any you don't need — defaults are provided)
  # ===========================================================================

  @impl PhoenixKit.Module
  @doc "Version string. Shown on the admin Modules page."
  def version, do: @version

  @impl PhoenixKit.Module
  @doc """
  Permission metadata for the roles/permissions matrix.

  The `:key` MUST match `module_key/0` — PhoenixKit validates this at startup.
  Icons use the `hero-` prefix (Heroicons via `phoenix_heroicons`).

  Return `nil` to opt out of the permissions system entirely (default).
  """
  def permission_metadata do
    %{
      key: module_key(),
      label: "Hello World",
      icon: "hero-hand-raised",
      description: "Demo module showing Hello World in the admin panel"
    }
  end

  @impl PhoenixKit.Module
  @doc """
  Admin sidebar tabs for this module.

  Each tab needs at minimum: `:id`, `:label`, `:path`, `:level`, `:permission`.

  Key fields:
  - `:id` — unique atom across ALL modules (prefix with `:admin_yourmodule`)
  - `:path` — must start with `/admin` and use hyphens, not underscores
  - `:permission` — must match `module_key/0` so custom roles get proper access
  - `:group` — use `:admin_modules` to appear in the Modules section of the sidebar
  - `:priority` — controls sort order (higher = further down). Built-in modules
    use 500-620; use 640+ for external modules
  - `:live_view` — `{Module, :action}` tuple; PhoenixKit auto-generates the route
  - `:icon` — Heroicon name (optional, shown in sidebar)
  - `:match` — `:exact` or `:prefix` for active-state highlighting

  Return `[]` to have no admin tabs (default).
  """
  def admin_tabs do
    [
      # Parent tab — match: :prefix keeps subtabs highlighted on any /hello-world/* page.
      # subtab_display: :when_active shows subtabs only when this module is active.
      %Tab{
        id: :admin_hello_world,
        label: "Hello World",
        icon: "hero-hand-raised",
        path: "hello-world",
        priority: 640,
        level: :admin,
        permission: module_key(),
        match: :prefix,
        group: :admin_modules,
        subtab_display: :when_active,
        highlight_with_subtabs: false,
        live_view: {PhoenixKitHelloWorld.Web.HelloLive, :index}
      },
      # Subtabs — Overview (same path as parent), Events, Components
      %Tab{
        id: :admin_hello_world_overview,
        label: "Overview",
        icon: "hero-hand-raised",
        path: "hello-world",
        priority: 641,
        level: :admin,
        permission: module_key(),
        match: :exact,
        parent: :admin_hello_world,
        live_view: {PhoenixKitHelloWorld.Web.HelloLive, :index}
      },
      %Tab{
        id: :admin_hello_world_events,
        label: "Events",
        icon: "hero-clock",
        path: "hello-world/events",
        priority: 642,
        level: :admin,
        permission: module_key(),
        parent: :admin_hello_world,
        live_view: {PhoenixKitHelloWorld.Web.EventsLive, :index}
      },
      %Tab{
        id: :admin_hello_world_components,
        label: "Components",
        icon: "hero-squares-2x2",
        path: "hello-world/components",
        priority: 643,
        level: :admin,
        permission: module_key(),
        parent: :admin_hello_world,
        live_view: {PhoenixKitHelloWorld.Web.ComponentsLive, :index}
      },
      %Tab{
        id: :admin_hello_world_notifications,
        label: "Notifications",
        icon: "hero-bell-alert",
        path: "hello-world/notifications",
        priority: 644,
        level: :admin,
        permission: module_key(),
        parent: :admin_hello_world,
        live_view: {PhoenixKitHelloWorld.Web.NotificationsLive, :index}
      }
    ]
  end

  @impl PhoenixKit.Module
  @doc "OTP apps whose templates Tailwind should scan for CSS classes."
  def css_sources, do: [:phoenix_kit_hello_world]

  # ── Versioned migrations ───────────────────────────────────────────────────
  #
  # A module owns the DDL for its own tables: the migration coordinator lives
  # in the module's OWN repo and ships with its package — never as a new
  # `Vxxx` added to core `phoenix_kit`'s migration chain. `mix
  # phoenix_kit.update` in the host app finds it through this callback,
  # compares the installed version against `current_version/0`, and generates
  # + runs a host migration when they differ.
  #
  # hello_world is a template and owns no tables, so it leaves the callback at
  # its `nil` default. When your module needs one, uncomment this and copy
  # lib/phoenix_kit_hello_world/migrations.ex (the fully commented
  # coordinator template):
  #
  #   @impl PhoenixKit.Module
  #   def migration_module, do: MyModule.Migrations

  # ── Dashboard widgets ──────────────────────────────────────────────────────
  #
  # Any PhoenixKit module can contribute widgets to `phoenix_kit_dashboards` by
  # exporting a zero-arity `phoenix_kit_widgets/0` returning a list of PLAIN
  # MAPS. This is a duck-typed, ONE-WAY contract: no dependency on the
  # dashboards package, no behaviour, no `@impl` — its Registry discovers the
  # function at runtime and normalizes each map into its own struct.
  #
  # The single definition below deliberately uses EVERY field of the contract;
  # the component (`Web.HelloWidget`) demonstrates the render side. Copy both
  # when adding widgets to your module.
  @doc false
  def phoenix_kit_widgets do
    [
      %{
        # Globally-unique key, conventionally "<module_key>.<widget>".
        key: "hello_world.hello",
        # Catalog card text. Plain strings — the dashboards builder translates
        # them dynamically at render when a translation exists.
        name: "Hello world",
        description: "The reference widget — every widget API capability in one card.",
        # Any Heroicon name (core's <.icon> set).
        icon: "hero-hand-raised",
        # Gates visibility on THIS module being enabled + permitted for the
        # viewer. Omit it for a widget that should always be offered.
        module_key: "hello_world",
        # The Phoenix.LiveComponent that renders instances of this widget.
        component: PhoenixKitHelloWorld.Web.HelloWidget,
        # Groups the catalog entry (the drawer also sections by provider).
        category: "Hello World",
        # Cell spans in the dashboards LATTICE units (25px nominal square
        # cells; a screenful is e.g. 64x36): default when added; min floors
        # resizing. There is no max — the user owns the box size and widget
        # content self-fits. Each VIEW may raise the minimum further (below).
        default_size: %{w: 12, h: 8},
        min_size: %{w: 8, h: 4},
        # Milliseconds between host refresh ticks (floored to 1000). Each tick
        # re-runs the component's update/2; omit for a static widget.
        refresh_interval: 5_000,
        # Named render variants. The instance stores the selected key and the
        # host passes it as the `view` assign. A view's own min_size wins over
        # the widget-level minimum while that view is selected.
        views: [
          %{key: "card", name: "Card", min_size: %{w: 8, h: 4}},
          %{key: "counter", name: "Counter (live)", min_size: %{w: 8, h: 8}},
          %{key: "contract", name: "Contract (debug)", min_size: %{w: 12, h: 8}}
        ],
        # One entry per settings-form field. Types: :string, :text, :number,
        # :boolean, :select. Select options are plain strings OR
        # {label, value} tuples (store machine keys, show human labels).
        settings_schema: [
          %{key: "greeting", type: :string, label: "Greeting", default: "Hello"},
          %{key: "note", type: :text, label: "Note", default: ""},
          %{key: "step", type: :number, label: "Counter step", default: "1"},
          %{key: "show_size", type: :boolean, label: "Show size", default: true},
          %{
            key: "tone",
            type: :select,
            label: "Tone",
            options: [
              {"Default", ""},
              {"Primary", "primary"},
              {"Success", "success"},
              {"Warning", "warning"}
            ],
            default: ""
          },
          %{
            key: "punctuation",
            type: :select,
            label: "Punctuation",
            options: ["!", ".", "?!"],
            default: "!"
          }
        ]
      }
    ]
  end

  # ── Project extension (reference implementation) ──────────────────────
  #
  # Any PhoenixKit module can plug into individual PROJECTS by exporting a
  # zero-arity `phoenix_kit_project_extensions/0` returning a list of PLAIN
  # MAPS — the same duck-typed, one-way shape as `phoenix_kit_widgets/0`
  # above: no dependency on `phoenix_kit_projects`, no behaviour, no
  # `@impl`. Its Extensions.Registry discovers this function at runtime and
  # normalizes each map; an admin then toggles the extension per project in
  # that project's Modules panel.
  #
  # The single definition below deliberately uses EVERY contract field; the
  # tab LV (`Web.ProjectHelloTabLive`) demonstrates the render side and the
  # embed-session contract. Copy the pair when adding a project extension
  # to your module.
  @doc false
  def phoenix_kit_project_extensions do
    [
      %{
        # Globally-unique key, conventionally "<module_key>_<capability>".
        key: "hello_world_tab",
        # Catalog text for the project Modules panel (translated dynamically
        # at render when a translation exists).
        name: "Hello World",
        description: "The reference project extension — every contract field in one entry.",
        icon: "hero-hand-raised",
        # Gates availability on THIS site module being enabled (and its
        # permission for visibility). Omit for hub-owned built-ins only.
        module_key: "hello_world",
        # Tabs contributed to the project show page. Each LV is rendered by
        # the hub via live_render with the embed-session contract — it must
        # mount off-router (no handle_params/3); see the tab LV's moduledoc.
        tabs: [
          %{
            key: "hello",
            label: "Hello",
            icon: "hero-hand-raised",
            lv: PhoenixKitHelloWorld.Web.ProjectHelloTabLive
          }
        ],
        # Per-instance config fields, edited in the project's Modules panel
        # and delivered to the tab LV as session["config"]. Writes are
        # whitelisted to these keys — same field types as settings_schema.
        config_schema: [
          %{key: "greeting", type: :string, label: "Greeting", default: "Hello"}
        ],
        # Per-project feature flags this extension owns (resolved by the
        # hub's Features layer; `requires` names flag dependencies).
        feature_flags: [
          %{key: "hello_world_confetti", label: "Confetti", default: false, requires: []}
        ],
        # Action keys the extension's UI asks PhoenixKitProjects.Authz about.
        permission_actions: [:view],
        # Merged into notification preference types (core's shape).
        notification_types: [],
        # {module, function}/2 called with (project_uuid, config) after a
        # successful toggle. Best-effort: failures log, never abort.
        on_enable: nil,
        on_disable: nil,
        # Whether projects WITHOUT an explicit row get this extension.
        # Reference stays false — demo tabs shouldn't appear unbidden.
        default_enabled: false
      }
    ]
  end

  @impl PhoenixKit.Module
  @doc """
  Notification types this module contributes.

  Each type becomes a per-user toggle in notification preferences. `actions`
  maps the activity `action` strings this module emits to the type, so a user
  who mutes "Hello World" stops receiving those notifications.

  Optionally declare `sub_types` for finer control: the base type then acts as a
  master switch (off ⇒ every sub muted) and each sub is individually toggleable
  (see `PhoenixKit.Notifications.Types`). Sub keys are bare here (`"greetings"`)
  and composed to `"hello_world.greetings"` at registration. When a type is fully
  split, leave its own `actions: []` so every action is owned by exactly one sub.
  See the Notifications admin page (`Web.NotificationsLive`) for the senders.
  """
  def notification_types do
    [
      %{
        key: "hello_world",
        label: "Hello World",
        description: "Greetings and demos from the Hello World module",
        actions: [],
        default: true,
        sub_types: [
          %{
            key: "greetings",
            label: "Greetings",
            description: "Plain greetings from the demo",
            actions: ["hello.greeting"],
            default: true
          },
          %{
            key: "custom",
            label: "Custom demos",
            description: "Custom-display demo notifications",
            actions: ["hello.custom"],
            default: true
          }
        ]
      }
    ]
  end

  @doc """
  Optional integration with `phoenix_kit_comments`: make this module's resources
  clickable in the comments moderation admin.

  If your module owns things that users comment on (the `resource_type` you pass
  to the comments component), implement `resolve_comment_resources/1` to turn a
  list of resource uuids into display chips. Return `%{uuid => info}` where
  `info` is:

    * `:title` — the chip label (e.g. the record's name)
    * `:path`  — a **raw** app path, e.g. `"/admin/widgets/\#{uuid}"`. The comments
      module runs it through `PhoenixKit.Utils.Routes.path/1` itself (prefix +
      locale), so do NOT pre-apply the prefix here or the link double-prefixes.
    * `:thumb_url` — optional image URL for a thumbnail (otherwise a type badge
      shows). Omit the key when there's none.

  Then register the handler so comments dispatches `"hello_world"` resources to
  this module:

      # config/config.exs
      config :phoenix_kit, :comment_resource_handlers, %{
        "hello_world" => PhoenixKitHelloWorld
      }

  A real implementation queries your schema:

      def resolve_comment_resources(uuids) do
        import Ecto.Query

        from(w in Widget, where: w.uuid in ^uuids, select: {w.uuid, w.name})
        |> Repo.all()
        |> Map.new(fn {uuid, name} ->
          {uuid, %{title: name, path: "/admin/widgets/\#{uuid}"}}
        end)
      rescue
        _ -> %{}
      end

  Hello World has no resources of its own, so this returns an empty map.
  Hosts can also link a type with **no code** via Settings → Comments →
  Resource Paths (a path template like `/admin/widgets/:uuid`).
  """
  @spec resolve_comment_resources([binary()]) :: %{binary() => map()}
  def resolve_comment_resources(_resource_uuids), do: %{}

  # ===========================================================================
  # Route module (for multi-page modules)
  # ===========================================================================
  #
  # This module has a single admin page, so the `live_view` field on admin_tabs
  # handles routing automatically. If you add more pages (e.g., a form, settings,
  # sub-pages), uncomment this and define your routes in the Routes module:
  #
  #   @impl PhoenixKit.Module
  #   def route_module, do: PhoenixKitHelloWorld.Routes
  #
  # When using route_module, you can REMOVE the `live_view` field from
  # admin_tabs — the Routes module takes over all route registration.
  # See lib/phoenix_kit_hello_world/routes.ex for the full pattern.

  # ===========================================================================
  # Other optional callbacks you can override (shown with their defaults):
  #
  #   def get_config, do: %{enabled: enabled?()}
  #   def settings_tabs, do: []
  #   def user_dashboard_tabs, do: []
  #   def children, do: []
  #   def route_module, do: nil          # see Route module section above
  #   def migration_module, do: nil      # see Versioned migrations section above
  #   def required_integrations, do: []  # e.g., ["google"] or ["openrouter"]
  #   def integration_providers, do: []  # e.g., [%{key: "my_provider", name: "My Provider"}]
  #
  # See the PhoenixKit.Module docs for details on each.
  # ===========================================================================
end

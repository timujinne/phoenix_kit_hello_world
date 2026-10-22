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

  Every callback of `PhoenixKit.Module` at the core floor. "Here" says whether
  this module implements it; everything else keeps the default
  `use PhoenixKit.Module` provides.

  | Callback                     | Required? | Here | What it does                                              |
  |------------------------------|-----------|------|-----------------------------------------------------------|
  | `module_key/0`               | Yes       | yes  | Unique string key (settings, permissions, PubSub)         |
  | `module_name/0`              | Yes       | yes  | Human-readable name (shown in admin UI)                   |
  | `enabled?/0`                 | Yes       | yes  | Whether the module is currently on                        |
  | `enable_system/0`            | Yes       | yes  | Turn the module on (persists to DB)                       |
  | `disable_system/0`           | Yes       | yes  | Turn the module off (persists to DB)                      |
  | `version/0`                  | No        | yes  | Version string (default: `"0.0.0"`)                       |
  | `permission_metadata/0`      | No        | yes  | Permission key, label, icon, sub-permissions              |
  | `admin_tabs/0`               | No        | yes  | Tabs (and their routes) in the admin sidebar              |
  | `css_sources/0`              | No        | yes  | OTP apps whose templates Tailwind scans                   |
  | `notification_types/0`       | No        | yes  | Per-user notification toggles this module owns            |
  | `resource_links/0`           | No        | yes  | Deep-links for this module's `resource_type`s             |
  | `get_config/0`               | No        | no   | Stats/config map shown on the Modules page                |
  | `settings_tabs/0`            | No        | no   | Tabs under the admin Settings page                        |
  | `user_dashboard_tabs/0`      | No        | no   | Tabs for the user-facing dashboard                        |
  | `children/0`                 | No        | no   | Supervisor child specs (GenServers, workers, …)           |
  | `route_module/0`             | No        | no   | Module providing extra route macros                       |
  | `migration_module/0`         | No        | no   | Versioned migration coordinator module                    |
  | `js_sources/0`               | No        | no   | Prebuilt JS hook bundles for the host LiveSocket          |
  | `required_modules/0`         | No        | no   | Module keys that must be enabled before this one          |
  | `required_integrations/0`    | No        | no   | Integration provider keys this module needs               |
  | `integration_providers/0`    | No        | no   | Custom provider definitions to contribute                 |
  | `notification_channels/0`    | No        | no   | Extra notification delivery channels                      |
  | `before_user_delete/1`       | No        | no   | Hook run before a user row is deleted                     |
  | `sitemap_sources/0`          | No        | no   | Sitemap source modules for public content                 |
  | `oban_queues/0`              | No        | no   | Oban queues this module's jobs run in                     |
  | `reserved_route_prefixes/0`  | No        | no   | Top-level path segments this module owns                  |
  | `migrate_legacy/0`           | No        | no   | One-shot legacy data migrations, run at boot              |
  | `email_settings_sections/0`  | No        | no   | Sections added to the core email settings page            |
  | `media_reorganizer/0`        | No        | no   | Storage reorganizer source for this module's records      |
  | `oban_crons/0`               | No        | no   | Cron schedules for this module's Oban workers             |
  | `email_templates/0`          | No        | no   | Email templates the admin can preview and edit            |
  | `job_kinds/0`                | No        | no   | Kinds of long-running run shown under Admin → Jobs        |
  | `api_tools/0`                | No        | no   | REST operations core builds from this module's tools      |

  Two further integrations are **duck-typed** — plain functions another
  package discovers at runtime, with no behaviour and no `@impl`:
  `phoenix_kit_widgets/0` (dashboards) and `phoenix_kit_project_extensions/0`
  (projects). Both are implemented below.
  """

  use PhoenixKit.Module
  # The module's own Gettext backend — see `PhoenixKitHelloWorld.Gettext`.
  use Gettext, backend: PhoenixKitHelloWorld.Gettext

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

  ## Base key vs sub-permissions

  The **base key** (`"hello_world"`) answers "may this role enter the module":
  every tab carries it as `:permission`, core's admin `on_mount` enforces it,
  and pages read it with `Scope.has_module_access?/2`.

  A **sub-permission** is an additive grant for one capability *inside* the
  module. It is declared here with a bare key (`"moderate"`), stored and
  checked as the composed dotted key `"hello_world.moderate"`, and the module
  checks it itself with `PhoenixKit.Users.Auth.Scope.can?/2` — core gates no
  route on it. Granting a sub grants its base, and a sub is only effective
  while the module is enabled, which is why `can?/2` (which re-reads
  enablement) is the check and not `has_module_access?/2`. `Web.HelloLive`
  gates its "Log moderation event" button on it.

  `gettext_backend:` / `gettext_domain:` make the label render translated in
  the permissions matrix; sub-permission labels inherit the backend. The
  msgids are pinned by `translatable_labels/0`.

  Return `nil` to opt out of the permissions system entirely (default).
  """
  def permission_metadata do
    %{
      key: module_key(),
      label: "Hello World",
      icon: "hero-hand-raised",
      description: "Demo module showing Hello World in the admin panel",
      gettext_backend: PhoenixKitHelloWorld.Gettext,
      gettext_domain: "default",
      sub_permissions: [
        %{
          key: "moderate",
          label: "Moderate",
          description: "Log moderation events from the Hello World overview page"
        }
      ]
    }
  end

  @doc """
  The composed key of this module's one sub-permission, for `Scope.can?/2`.
  """
  @spec moderate_permission() :: String.t()
  def moderate_permission, do: module_key() <> ".moderate"

  @impl PhoenixKit.Module
  @doc """
  Admin sidebar tabs for this module.

  Each tab needs at minimum: `:id`, `:label`, `:path`, `:level`, `:permission`.

  Key fields:
  - `:id` — unique atom across ALL modules (prefix with `:admin_yourmodule`)
  - `:path` — relative to the admin root (`"hello-world"` resolves to
    `/admin/hello-world` under the host's URL prefix and locale); hyphens, not
    underscores. May carry dynamic segments (`"hello-world/:id/edit"`)
  - `:permission` — must match `module_key/0` so custom roles get proper access
  - `:group` — use `:admin_modules` to appear in the Modules section of the sidebar
  - `:priority` — controls sort order (higher = further down). Built-in modules
    use 500-620; use 640+ for external modules
  - `:live_view` — `{Module, :action}` tuple; PhoenixKit auto-generates the route
  - `:icon` — Heroicon name (optional, shown in sidebar)
  - `:match` — `:exact` or `:prefix` for active-state highlighting
  - `:gettext_backend` / `:gettext_domain` — the label is used as a msgid
    against this backend when the sidebar renders. The label stays a plain
    literal here, so `translatable_labels/0` pins it for the extractor

  Return `[]` to have no admin tabs (default).
  """
  def admin_tabs do
    [
      # Parent tab — match: :prefix keeps subtabs highlighted on any /hello-world/* page.
      # subtab_display: :when_active shows subtabs only when this module is active.
      %Tab{
        id: :admin_hello_world,
        label: "Hello World",
        gettext_backend: PhoenixKitHelloWorld.Gettext,
        gettext_domain: "default",
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
      # Subtabs — Overview (same path as parent), Events, Components, Notifications
      %Tab{
        id: :admin_hello_world_overview,
        label: "Overview",
        gettext_backend: PhoenixKitHelloWorld.Gettext,
        gettext_domain: "default",
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
        gettext_backend: PhoenixKitHelloWorld.Gettext,
        gettext_domain: "default",
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
        gettext_backend: PhoenixKitHelloWorld.Gettext,
        gettext_domain: "default",
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
        gettext_backend: PhoenixKitHelloWorld.Gettext,
        gettext_domain: "default",
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

  @doc """
  Pins every label this module declares as plain data as a gettext msgid.

  `permission_metadata/0` and `admin_tabs/0` declare their labels as string
  literals in maps and structs, which `mix gettext.extract` cannot see; core
  translates them at render time through each declaration's
  `gettext_backend` / `gettext_domain`, and that lookup only resolves when the
  msgid is in this module's catalogue. `dgettext_noop/2` registers the msgid
  and returns it unchanged — nothing here runs at request time. Add a tab or
  rename a label and this list changes with it, or the sidebar shows the
  English label in every locale.
  """
  @spec translatable_labels() :: [String.t()]
  def translatable_labels do
    [
      dgettext_noop("default", "Hello World"),
      dgettext_noop("default", "Overview"),
      dgettext_noop("default", "Events"),
      dgettext_noop("default", "Components"),
      dgettext_noop("default", "Notifications"),
      dgettext_noop("default", "Moderate")
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
  # The single definition below uses every field the dashboards normalizer
  # reads (`max_size` is accepted and ignored, so it is left out); the
  # component (`Web.HelloWidget`) demonstrates the render side. Copy both when
  # adding widgets to your module.
  #
  # The catalog strings (`name`, `description`, view names, settings labels)
  # are rendered by the dashboards package through ITS catalogue, so a
  # provider's own backend cannot translate them; they stay plain strings.
  #
  # Two companion contracts are NOT implemented here, because both describe a
  # module that owns records and this one owns none:
  #
  #   * `phoenix_kit_dashboard_slots/0` — declares a PLACE a dashboard can be
  #     shown (a sidebar sub-tab under your module, or a tab inside one of
  #     your records). Declaring one is consent to a tab appearing in your
  #     module's navigation.
  #   * `phoenix_kit_dashboard_viewer_context/2` — `(kind, scope) -> id | nil`,
  #     answering "which one is MINE" for a context kind your module owns.
  #
  # `phoenix_kit_projects` (`lib/phoenix_kit_projects.ex`) is the reference
  # implementation of both; the field tables are in `phoenix_kit_dashboards`'
  # `PhoenixKitDashboards.Slot` and `PhoenixKitDashboards.Binds`.
  @doc false
  def phoenix_kit_widgets do
    [
      %{
        # Globally-unique key, conventionally "<module_key>.<widget>".
        key: "hello_world.hello",
        # Catalog card text.
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
        # A minimum is a recommendation: a user may override it per instance
        # down to 1x1, so the component still has to render below it.
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
        # :boolean, :select. A :text field is edited in the host's rich
        # editor, so its value is rich content (Markdown or HTML) — render it
        # sanitised, never raw. Select options are plain strings OR
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
          },
          # `context:` marks a field as holding a CONTEXT SUBJECT — the id of
          # a record of the named kind — rather than an ordinary setting. The
          # field still stores and reads a plain id; declaring the kind lets
          # the host offer "the one this page is about" and "mine" as sources
          # and write the resolved id into this field before render. A kind
          # is a namespaced string owned by the module that owns the record.
          # This module owns no records, so the example borrows
          # `phoenix_kit_projects`' kind: placed on a project's Dashboard tab
          # the widget is handed that project's uuid. A module that owns the
          # kind also supplies `options:` (its picker for "a specific one")
          # and `phoenix_kit_dashboard_viewer_context/2` (for "mine").
          %{
            key: "project",
            type: :string,
            label: "Project",
            default: "",
            context: "projects.project"
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
  # The single definition below names every field the hub's normalizer reads
  # (`data_retention` is not one: the hub fixes it to `:keep` — disabling an
  # extension hides it and never deletes its data). The tab LV
  # (`Web.ProjectHelloTabLive`) demonstrates the render side and the
  # embed-session contract. Copy the pair when adding a project extension to
  # your module.
  #
  # `name`, `description` and flag labels are rendered by the hub through ITS
  # catalogue, so they stay plain strings here.
  @doc false
  def phoenix_kit_project_extensions do
    [
      %{
        # Globally-unique key, conventionally "<module_key>_<capability>".
        key: "hello_world_tab",
        # Catalog text for the project Modules panel.
        name: "Hello World",
        description: "The reference project extension — every contract field in one entry.",
        icon: "hero-hand-raised",
        # Which group of the Modules panel lists the extension. One of the
        # hub's category keys ("collaborate", "documents", "clients", "data",
        # "more"); anything else, or nothing, lands in "more".
        category: "more",
        # Gates availability on THIS site module being enabled (and its
        # permission for visibility). Omit for hub-owned built-ins only.
        module_key: "hello_world",
        # The site permission a viewer needs to SEE the extension's tabs.
        # nil falls back to `module_key`, then to the hub's own permission;
        # set it only when the tab needs a different key than the module's.
        permission: nil,
        # Tabs contributed to the project show page. Each LV is rendered by
        # the hub via live_render with the embed-session contract — it must
        # mount off-router (no handle_params/3); see the tab LV's moduledoc.
        # A tab's key is also its URL segment (`/projects/:id/<key>`), so it
        # may not reuse one of the project page's own segments (`edit`,
        # `files`, `members`, `tasks`, …) — the hub drops such a tab.
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
        # Action keys the extension's UI asks the hub's Authz about. The
        # FIRST action other than :view is the extension's write action: the
        # hub resolves it for the viewer against the project and hands the
        # tab the answer as session["can_write"]. With only [:view] declared
        # every tab gets can_write false.
        permission_actions: [:view, :greet],
        # Merged into notification preference types (core's shape).
        notification_types: [],
        # {module, function}/2 called with (project_uuid, config) after a
        # successful toggle. Best-effort: failures log, never abort.
        on_enable: nil,
        on_disable: nil,
        # A module (or list of modules) putting one of this extension's
        # records on the projects JSON API under `/ext/<resource>` — it
        # follows the hub's `Extensions.ApiProvider` contract (`resource/0`,
        # `scopes/0`, `action/0`, `list/2`, `get/2`, `create/2`, `update/3`,
        # `docs/0`). nil: this module has no records to serve.
        api: nil,
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

  @impl PhoenixKit.Module
  @doc """
  Deep-links for this module's resource types — zero host configuration.

  Core's activity feed, notifications and the `phoenix_kit_comments`
  moderation admin all turn a `(resource_type, resource_uuid)` pair into a
  clickable link through `PhoenixKit.ResourceLinks`, which collects this
  callback from every module. Return `resource_type => resolver`, where a
  resolver is:

    * a **path template** — `"/admin/widgets/:uuid"`, with `:uuid` and
      `:metadata.<key>` placeholders. The no-code form; use
      `%{"path" => "...", "title" => ":metadata.name"}` to set a title.
    * a **module** exporting `resolve_comment_resources/1` — for a title and
      thumbnail that need a lookup (see that function below).

  Paths are **raw** app paths: the renderer applies
  `PhoenixKit.Utils.Routes.path/1` (URL prefix + locale) once, so a
  pre-prefixed path double-prefixes.

  The one resource type this module logs with a uuid is declared:
  `"hello_world_greeting"` (the demo notifications) links to the page that
  sends them. Only entries carrying both a `resource_type` and a
  `resource_uuid` are resolved, and type keys share one namespace across
  every module — prefix yours. A module with records links each type to its
  record page instead:

      def resource_links, do: %{"widget" => "/admin/widgets/:uuid"}

  A host can still override or add a type without code, in
  `config :phoenix_kit, :comment_resource_handlers` (a `type => module` map)
  or the `comment_resource_paths` setting (Settings → Comments → Resource
  Paths).
  """
  def resource_links do
    %{"hello_world_greeting" => "/admin/hello-world/notifications"}
  end

  @doc """
  The rich resolver behind `resource_links/0`: turns resource uuids into
  display chips with a title and optional thumbnail.

  Point a type at a module in `resource_links/0`
  (`%{"widget" => MyModule}`) and core calls this function on it with the
  uuids to resolve. Return `%{uuid => info}` where `info` is:

    * `:title` — the chip label (e.g. the record's name)
    * `:path`  — a **raw** app path, e.g. `"/admin/widgets/\#{uuid}"`
    * `:thumb_url` — optional image URL (otherwise a type badge shows). Omit
      the key when there is none.

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

  Hello World's one type has no per-record title to look up, so it uses a
  path template and this returns an empty map.
  """
  @spec resolve_comment_resources([binary()]) :: %{binary() => map()}
  def resolve_comment_resources(_resource_uuids), do: %{}

  # ===========================================================================
  # Route module (when tabs are not expressive enough)
  # ===========================================================================
  #
  # This module's four admin pages are all routed by the `live_view` field on
  # their tabs — including, if it had them, sub-pages with dynamic segments
  # (`path: "hello-world/:id/edit"` with `visible: false` and `parent:` set).
  # That is the default and covers most modules.
  #
  # Add a route module when tabs are not enough: many `live` routes you do not
  # want to enumerate as tabs, separate localized and non-localized variants
  # with their own `:as` names, or routes OUTSIDE the admin live_session
  # (controllers, API endpoints, public pages):
  #
  #   @impl PhoenixKit.Module
  #   def route_module, do: PhoenixKitHelloWorld.Routes
  #
  # The two coexist — keep `live_view` on the tabs that have one — but never
  # register the same path both ways. See lib/phoenix_kit_hello_world/routes.ex
  # for the full pattern and AGENTS.md → Routing for the constraints.

  # ===========================================================================
  # Optional callbacks this module leaves at their defaults (shown as the
  # default `use PhoenixKit.Module` provides):
  #
  #   def get_config, do: %{enabled: enabled?()}
  #   def settings_tabs, do: []
  #   def user_dashboard_tabs, do: []
  #   def children, do: []
  #   def route_module, do: nil            # see Route module section above
  #   def migration_module, do: nil        # see Versioned migrations section above
  #   def js_sources, do: []               # see the JavaScript section of the moduledoc
  #   def required_modules, do: []         # e.g., ["entities"]
  #   def required_integrations, do: []    # e.g., ["google"] or ["openrouter"]
  #   def integration_providers, do: []    # e.g., [%{key: "my_provider", name: "My Provider"}]
  #   def notification_channels, do: []    # modules implementing Notifications.Channel
  #   def sitemap_sources, do: []
  #   def oban_queues, do: []              # e.g., [my_imports: 2]
  #   def reserved_route_prefixes, do: []  # e.g., ["hello"]
  #   def migrate_legacy, do: :ok
  #   def email_settings_sections, do: []
  #   def media_reorganizer, do: nil
  #
  # `before_user_delete/1` has no default: implement it only when a user's
  # deletion needs remediation the database cascades cannot do.
  #
  # See the PhoenixKit.Module docs for details on each.
  # ===========================================================================
end

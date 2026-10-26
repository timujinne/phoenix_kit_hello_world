# PhoenixKitHelloWorld

A minimal PhoenixKit plugin module. Use this as a template for building your own.

Modules can be **full-featured** (admin pages, settings, routes) or **headless** (just functions and tools, no UI). This module demonstrates the full-featured pattern. See [Headless modules](#headless-modules) for the lightweight alternative.

## Table of Contents

- [What this demonstrates](#what-this-demonstrates)
- [Quick start](#quick-start)
- [Dependency types: development vs production](#dependency-types-development-vs-production)
- [Creating your own module](#creating-your-own-module)
- [Headless modules](#headless-modules)
- [Project structure](#project-structure)
- [Available callbacks](#available-callbacks)
- [Common patterns](#common-patterns)
- [Navigation system](#navigation-system)
- [Admin integration deep dive](#admin-integration-deep-dive)
- [Permissions system](#permissions-system)
- [PhoenixKit components](#phoenixkit-components)
- [Component reuse](#component-reuse)
- [Translations (Gettext)](#translations-gettext)
- [JavaScript in modules](#javascript-in-modules)
- [Available PhoenixKit APIs](#available-phoenixkit-apis)
- [Cross-module integration](#cross-module-integration)
- [Database conventions](#database-conventions)
- [Testing](#testing)
- [Verifying your module](#verifying-your-module)
- [Tailwind CSS scanning for modules](#tailwind-css-scanning-for-modules)
- [Troubleshooting](#troubleshooting)
- [Publishing to Hex](#publishing-to-hex)

## What this demonstrates

- Zero-config auto-discovery (just add the dep and `:phoenix_kit` to `extra_applications`)
- Admin sidebar tab with automatic routing
- Enable/disable toggle on the admin Modules page
- Permission key in the roles/permissions matrix
- Live sidebar updates when the module is toggled
- A sub-permission, declared in `permission_metadata/0` and checked with `Scope.can?/2`
- The module's own Gettext backend and catalogue (`priv/gettext`, Estonian and Russian)
- Activity logging, an activity feed, and notifications driven by the activity log
- Deep-links for the module's resource types through `resource_links/0`
- A live showcase of the core components module authors need
- The two duck-typed integrations: a dashboard widget and a project extension

## Quick start

For local development, add to your parent app's `mix.exs` using a path dependency:

```elixir
{:phoenix_kit_hello_world, path: "../phoenix_kit_hello_world"}
```

Run `mix deps.get` and start the server. The module appears in:

- **Admin sidebar** (under Modules section) — click to see the Hello World page
- **Admin > Modules** — toggle it on/off
- **Admin > Roles** — grant/revoke access per role

## Dependency types: development vs production

PhoenixKit modules are standard Mix dependencies. How you reference them in the parent app's `mix.exs` depends on your workflow:

### Local development (`path:`)

```elixir
{:my_phoenix_kit_module, path: "../my_phoenix_kit_module"}
```

- **Best for**: active development where you're editing the module and the parent app together
- Changes to the module's source are picked up automatically on recompile — no `--force` needed
- The directory must exist on disk at the given relative path

### Git dependency (`git:`)

```elixir
{:my_phoenix_kit_module, git: "https://github.com/you/my_phoenix_kit_module.git"}
# or pin to a branch/tag/ref:
{:my_phoenix_kit_module, git: "https://github.com/you/my_phoenix_kit_module.git", branch: "main"}
{:my_phoenix_kit_module, git: "https://github.com/you/my_phoenix_kit_module.git", tag: "v1.0.0"}
```

- **Best for**: private modules not published to Hex, or referencing a specific commit/branch
- Lives in `deps/` after `mix deps.get` — the dev reloader does **not** watch deps
- After updating the remote, run `mix deps.update my_phoenix_kit_module`
- To pick up changes: `mix deps.compile my_phoenix_kit_module --force` + restart the server

### Hex package

```elixir
{:my_phoenix_kit_module, "~> 1.0"}
```

- **Best for**: published, versioned modules shared across projects
- Lives in `deps/` — same recompile/restart workflow as git deps
- See [Publishing to Hex](#publishing-to-hex) for how to publish your module

### Why `path:` deps behave differently

With `path:` dependencies, Mix treats the source directory as part of your project — file changes trigger recompilation automatically. With `git:` or Hex deps, the code lives in `deps/` and is compiled once. The Phoenix dev reloader only watches the parent app's own source files, not `deps/`. That's why non-path deps require `mix deps.compile <module> --force` and a server restart to pick up changes.

## Creating your own module

### 1. Copy this project

```bash
cp -r phoenix_kit_hello_world my_phoenix_kit_module
cd my_phoenix_kit_module
```

Rename everything:

- `PhoenixKitHelloWorld` → `MyPhoenixKitModule`
- `phoenix_kit_hello_world` → `my_phoenix_kit_module`
- `hello_world` → `my_module` (the module key)

### 2. Update mix.exs

```elixir
def project do
  [
    app: :my_phoenix_kit_module,
    version: "0.1.0",
    deps: deps()
  ]
end

# Required: :phoenix_kit must be in extra_applications for auto-discovery.
# :gettext is there for the module's own Gettext backend.
def application do
  [
    extra_applications: [:logger, :gettext, :phoenix_kit]
  ]
end

defp deps do
  [
    # Compound form: a patch-precise floor and an open ceiling. A
    # three-segment `~> 2.38.0` means `< 2.39.0` and makes `mix deps.get`
    # unsolvable for any host on a newer core minor.
    {:phoenix_kit, ">= 2.38.0 and < 3.0.0"},
    {:phoenix_live_view, "~> 1.1"},
    {:gettext, "~> 1.0"}
  ]
end
```

Set the `phoenix_kit` floor to the oldest core release that has everything your
module calls, and raise it in the same change that starts using something
newer — a function, a component, or a single component attribute. A host on an
older core otherwise fails at compile time or, worse, at render.

> **Important:** `:phoenix_kit` must be listed in `extra_applications`. Without it, `PhoenixKit.ModuleDiscovery` won't find your module and routes will return 404.

### 3. Implement the behaviour

The main module (`lib/my_phoenix_kit_module.ex`) needs `use PhoenixKit.Module` and 5 required callbacks:

```elixir
defmodule MyPhoenixKitModule do
  use PhoenixKit.Module

  alias PhoenixKit.Dashboard.Tab
  alias PhoenixKit.Settings

  # --- Required ---

  @impl true
  def module_key, do: "my_module"

  @impl true
  def module_name, do: "My Module"

  @impl true
  def enabled? do
    Settings.get_boolean_setting("my_module_enabled", false)
  rescue
    _ -> false
  end

  @impl true
  def enable_system do
    Settings.update_boolean_setting_with_module("my_module_enabled", true, module_key())
  end

  @impl true
  def disable_system do
    Settings.update_boolean_setting_with_module("my_module_enabled", false, module_key())
  end

  # --- Optional (remove what you don't need) ---

  @impl true
  def permission_metadata do
    %{
      key: module_key(),
      label: "My Module",
      icon: "hero-puzzle-piece",
      description: "Description shown in the permissions matrix"
    }
  end

  @impl true
  def admin_tabs do
    [
      %Tab{
        id: :admin_my_module,
        label: "My Module",
        icon: "hero-puzzle-piece",
        path: "my-module",
        priority: 650,
        level: :admin,
        permission: module_key(),
        match: :prefix,
        group: :admin_modules,
        live_view: {MyPhoenixKitModule.Web.IndexLive, :index}
      }
    ]
  end
end
```

### 4. Create your LiveView

```elixir
defmodule MyPhoenixKitModule.Web.IndexLive do
  use PhoenixKitWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "My Module",
       page_subtitle: "What this page is for"
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col px-4 py-6 gap-6">
      <p class="text-base-content/70">Your content here.</p>
    </div>
    """
  end
end
```

The admin layout (sidebar, header, theme) is applied automatically. You don't need to wrap anything in `LayoutWrapper`.

Two layout rules are worth internalizing now, because they're easy to get wrong and hard to un-see afterwards:

- **The layout renders `page_title`/`page_subtitle` in the page header — so your template renders no page heading of its own.** Adding an `<h1>My Module</h1>` to the template puts two titles on screen, and in practice they drift apart in wording.
- **No page-level width cap.** The page-root `<div>` gets spacing only. No `container`, no page-level `max-w-*` — the admin layout already owns page width. (A `max-w-*` scoped to one form card is fine.)

See "UI & Layout Conventions" in [AGENTS.md](AGENTS.md) for the full list.

### 5. Add to parent app

For local development, add a path dependency to the parent app's `mix.exs`:

```elixir
# In parent app's mix.exs (local development)
{:my_phoenix_kit_module, path: "../my_phoenix_kit_module"}
```

Run `mix deps.get`, start the server, and your module appears in the admin panel.

See [Dependency types: development vs production](#dependency-types-development-vs-production) for git and Hex alternatives when deploying.

## Headless modules

Not every module needs admin pages. A **headless module** provides functions, tools, or background workers — no tabs, no routes, no LiveViews. It still gets auto-discovery, enable/disable toggles, and permission integration.

### Minimal example

```elixir
defmodule MyPhoenixKitUtils do
  use PhoenixKit.Module

  alias PhoenixKit.Settings

  # --- Required callbacks (5 total) ---

  @impl true
  def module_key, do: "my_utils"

  @impl true
  def module_name, do: "My Utils"

  @impl true
  def enabled? do
    Settings.get_boolean_setting("my_utils_enabled", false)
  rescue
    _ -> false
  end

  @impl true
  def enable_system do
    Settings.update_boolean_setting_with_module("my_utils_enabled", true, module_key())
  end

  @impl true
  def disable_system do
    Settings.update_boolean_setting_with_module("my_utils_enabled", false, module_key())
  end

  # --- Optional: permission metadata ---
  # Include this if you want the module to appear in the roles/permissions matrix.
  # Omit it if the module is always available to all users.

  @impl true
  def permission_metadata do
    %{
      key: module_key(),
      label: "My Utils",
      icon: "hero-wrench-screwdriver",
      description: "Utility functions for data processing"
    }
  end

  # --- Your public API ---
  # No admin_tabs, settings_tabs, user_dashboard_tabs, or route_module needed.
  # All default to empty/nil automatically.

  def calculate(x, y), do: x + y

  def format_currency(amount, currency \\ "USD") do
    # ...
  end

  def send_notification(user, message) do
    if enabled?() do
      # ...
      :ok
    else
      {:error, :module_disabled}
    end
  end
end
```

That's it. No LiveView, no routes, no templates. The module:

- **Auto-discovered** — just add the dep, appears on Admin > Modules
- **Toggleable** — enable/disable from the admin panel
- **Permission-gated** — custom roles can be granted or denied access via the permissions matrix
- **API-only** — other modules and the parent app call its functions directly

### What you get without any UI callbacks

| Feature | How |
|---|---|
| Shows on Admin > Modules page | Automatic (auto-discovery) |
| Enable/disable toggle | Via `enable_system/0` and `disable_system/0` |
| Permission in roles matrix | Via `permission_metadata/0` (optional) |
| Access check in code | `Scope.has_module_access?(scope, "my_utils")` |
| Background workers | Override `children/0` to return supervisor child specs |
| Config stats on Modules page | Override `get_config/0` to return a stats map |

### When to use headless vs full-featured

| Use headless when... | Use full-featured when... |
|---|---|
| Module provides utility functions | Module needs its own admin page |
| Module runs background jobs | Users need to view/edit data in a UI |
| Module extends other modules' APIs | Module has settings to configure |
| Module is a data pipeline or integration | Module has its own dashboard section |

### Adding a worker to a headless module

```elixir
@impl true
def children do
  if enabled?() do
    [{MyPhoenixKitUtils.SyncWorker, interval: :timer.minutes(5)}]
  else
    []
  end
end
```

### Guarding API calls with enabled?()

For modules that should no-op when disabled:

```elixir
def process(data) do
  if enabled?() do
    do_process(data)
  else
    {:error, :module_disabled}
  end
end
```

For modules where the API is always available but behavior changes:

```elixir
def enrich(record) do
  if enabled?() do
    %{record | ai_summary: generate_summary(record)}
  else
    record  # pass through unchanged
  end
end
```

### Real-world example

PhoenixKit's built-in **Connections** module follows this pattern — 50+ public API functions for follows, connections, and blocks. Zero admin tabs, zero routes. It's toggled on/off from the Modules page and its permission key gates access in the roles matrix, but all interaction happens through function calls from other modules and the parent app.

## Project structure

```
lib/
  my_phoenix_kit_module.ex                   # Main module (behaviour callbacks)
  my_phoenix_kit_module/
    paths.ex                                 # Centralized path helpers (recommended)
    gettext.ex                               # The module's own Gettext backend
    web/
      index_live.ex                          # Main admin page
      detail_live.ex                         # Detail/edit page
      settings_live.ex                       # Settings page (optional)
      components/
        shared_panel.ex                      # Shared UI components
priv/
  gettext/                                   # default.pot + one .po per shipped locale
  static/assets/my_phoenix_kit_module.js     # Prebuilt JS hook bundle (only if needed)
test/
  my_phoenix_kit_module_test.exs             # Behaviour compliance tests
mix.exs                                      # Package configuration
```

`priv` must be in the package's `files:` list in `mix.exs`, or the published
package ships neither the translations nor the JS bundle.

For modules with database tables, add:

```
lib/
  my_phoenix_kit_module/
    migrations.ex                            # Versioned migration coordinator
    schemas/
      item.ex                                # Ecto schema
test/
  support/
    migration_runner.ex                      # Ecto.Migration wrapper (tests only)
  migrations_test.exs                        # Guards the migration contract
```

The module ships the DDL for its own tables — nothing goes into core
`phoenix_kit`'s migration chain, and the host app needs no install task: `mix
phoenix_kit.update` finds the coordinator through `migration_module/0` and
generates the host migration itself. See [Versioned
migrations](#versioned-migrations) below.

`phoenix_kit_hello_world` is a template and owns no tables, so it carries the
coordinator and schema as fully-commented files that compile to nothing
(`lib/phoenix_kit_hello_world/migrations.ex`,
`lib/phoenix_kit_hello_world/schemas/example_item.ex`) — copy and uncomment.
For versions that actually run, read `phoenix_kit_boards` (single table) or
`phoenix_kit_web_analytics` (two tables plus indexes).

## Available callbacks

| Callback | Required | Default | Description |
|---|---|---|---|
| `module_key/0` | Yes | — | Unique string key |
| `module_name/0` | Yes | — | Display name |
| `enabled?/0` | Yes | — | Whether module is on |
| `enable_system/0` | Yes | — | Turn on |
| `disable_system/0` | Yes | — | Turn off |
| `version/0` | No | `"0.0.0"` | Version string |
| `get_config/0` | No | `%{enabled: enabled?()}` | Config/stats map for Modules page |
| `permission_metadata/0` | No | `nil` | Permission UI metadata |
| `admin_tabs/0` | No | `[]` | Admin sidebar tabs |
| `settings_tabs/0` | No | `[]` | Settings page subtabs |
| `user_dashboard_tabs/0` | No | `[]` | User dashboard tabs |
| `children/0` | No | `[]` | Supervisor child specs |
| `route_module/0` | No | `nil` | Custom route macros |
| `migration_module/0` | No | `nil` | Versioned migration coordinator |
| `css_sources/0` | No | `[]` | OTP app names for Tailwind CSS scanning |
| `js_sources/0` | No | `[]` | Prebuilt JS hook bundles for the host LiveSocket |
| `notification_types/0` | No | `[]` | Per-user notification toggles the module owns |
| `notification_channels/0` | No | `[]` | Extra notification delivery channels |
| `resource_links/0` | No | `%{}` | Deep-links for the module's `resource_type`s |
| `required_modules/0` | No | `[]` | Module keys that must be enabled before this one |
| `required_integrations/0` | No | `[]` | Integration provider keys the module needs |
| `integration_providers/0` | No | `[]` | Provider definitions the module contributes |
| `before_user_delete/1` | No | — | Hook run before a user row is deleted |
| `sitemap_sources/0` | No | `[]` | Sitemap sources for public content |
| `oban_queues/0` | No | `[]` | Oban queues the module's jobs run in |
| `reserved_route_prefixes/0` | No | `[]` | Top-level path segments the module owns |
| `migrate_legacy/0` | No | `:ok` | One-shot legacy data migrations, run at boot |
| `email_settings_sections/0` | No | `[]` | Sections added to the core email settings page |
| `media_reorganizer/0` | No | `nil` | Storage reorganizer source for the module's records |

That is every callback in core 2.38. Later core releases add
`email_templates/0` (2.44) and `job_kinds/0` (2.48); raise your `phoenix_kit`
floor before implementing either with `@impl`. The authoritative list is
`PhoenixKit.Module` in the core version you depend on.

Two further integrations are not callbacks at all but duck-typed functions
another package discovers at runtime: `phoenix_kit_widgets/0`
(`phoenix_kit_dashboards`) and `phoenix_kit_project_extensions/0`
(`phoenix_kit_projects`). `lib/phoenix_kit_hello_world.ex` implements both with
every field commented.

## Common patterns

### Headless module (no UI)

See [Headless modules](#headless-modules) above for the full guide. The short version: don't override `admin_tabs/0`, `settings_tabs/0`, or `user_dashboard_tabs/0` — the defaults return `[]` and no sidebar entries or routes are created.

### Adding a settings subtab

```elixir
@impl true
def settings_tabs do
  [
    %Tab{
      id: :settings_my_module,
      label: "My Module",
      icon: "hero-puzzle-piece",
      path: "my-module",
      level: :settings,
      permission: module_key(),
      live_view: {MyPhoenixKitModule.Web.SettingsLive, :index}
    }
  ]
end
```

### Starting a GenServer with the module

```elixir
@impl true
def children do
  if enabled?() do
    [{MyPhoenixKitModule.Worker, []}]
  else
    []
  end
end
```

### Conditional children with optional dependencies

If your module optionally uses a library that provides a supervisor child (e.g., ChromicPDF for PDF generation), guard the child spec:

```elixir
@impl true
def children do
  if Code.ensure_loaded?(ChromicPDF) do
    [{MyPhoenixKitModule.PdfSupervisor, []}]
  else
    []
  end
end
```

This ensures the module loads even when the optional dependency isn't installed.

### Custom config for the Modules page

```elixir
@impl true
def get_config do
  %{
    enabled: enabled?(),
    items_count: MyPhoenixKitModule.count_items(),
    last_sync: MyPhoenixKitModule.last_sync_at()
  }
end
```

**Performance warning:** `get_config/0` is called on every render of the admin Modules page. Do not perform slow queries here. Use cached values or single aggregate queries.

### Multiple pages and sub-routes

Return multiple tabs from `admin_tabs/0`. Use `:match` and `:parent` to control sidebar behavior:

```elixir
@impl true
def admin_tabs do
  [
    # Main tab (visible in sidebar)
    %Tab{
      id: :admin_my_module,
      label: "My Module",
      icon: "hero-puzzle-piece",
      path: "my-module",
      priority: 650,
      level: :admin,
      permission: module_key(),
      match: :prefix,
      group: :admin_modules,
      live_view: {MyPhoenixKitModule.Web.IndexLive, :index}
    },
    # Detail page (not in sidebar, but keeps parent tab highlighted)
    %Tab{
      id: :admin_my_module_detail,
      path: "my-module/:id",
      level: :admin,
      permission: module_key(),
      visible: false,
      parent: :admin_my_module,
      live_view: {MyPhoenixKitModule.Web.DetailLive, :show}
    }
  ]
end
```

For pages that shouldn't appear in the sidebar, set `visible: false`. The `:parent` field keeps the parent tab highlighted when viewing the child page. Use `:match` with `:prefix` on the parent so `my-module/anything` keeps it active.

## Navigation system

Every path your module generates — in templates, redirects, or LiveView navigation — **must** go through `PhoenixKit.Utils.Routes.path/1`. This handles the configurable URL prefix (e.g., `/phoenix_kit`) and locale prefix (e.g., `/ja`) automatically.

### The Paths module pattern (recommended)

Create a dedicated `Paths` module to centralize all your module's navigation paths. This is the pattern used by production modules like Document Creator, and it ensures you have a single place to update if paths ever change.

```elixir
# lib/my_phoenix_kit_module/paths.ex
defmodule MyPhoenixKitModule.Paths do
  @moduledoc """
  Centralized path helpers for My Module.

  All navigation paths go through `PhoenixKit.Utils.Routes.path/1`, which
  handles the configurable URL prefix and locale prefix automatically.

  Use these helpers in templates and `redirect/2` calls instead of
  hardcoding paths.
  """

  alias PhoenixKit.Utils.Routes

  @base "/admin/my-module"

  # ── Main ──────────────────────────────────────────────────────────
  def index, do: Routes.path(@base)

  # ── Items ─────────────────────────────────────────────────────────
  def item_new, do: Routes.path("#{@base}/items/new")
  def item_edit(uuid), do: Routes.path("#{@base}/items/#{uuid}/edit")
  def item_show(uuid), do: Routes.path("#{@base}/items/#{uuid}")

  # ── Settings ──────────────────────────────────────────────────────
  def settings, do: Routes.path("#{@base}/settings")
end
```

### Using paths in LiveViews and templates

```elixir
# In LiveView mount or event handlers
alias MyPhoenixKitModule.Paths

# Redirect after save
{:noreply, redirect(socket, to: Paths.index())}

# Redirect to edit page after creation
{:noreply, redirect(socket, to: Paths.item_edit(item.uuid))}

# Handle not-found
case get_item(uuid) do
  nil ->
    socket
    |> put_flash(:error, "Item not found")
    |> redirect(to: Paths.index())

  item ->
    assign(socket, item: item)
end
```

```heex
<%!-- In templates --%>
<a href={Paths.item_edit(@item.uuid)} class="btn btn-sm">Edit</a>
<a href={Paths.index()} class="btn btn-ghost btn-sm">Back to list</a>
```

### Tab paths vs template paths — two different systems

| Where | How to specify paths |
|---|---|
| Tab struct `path` field | `"my-module"` (relative — core prepends `/admin/`) |
| Template `href` / `redirect` | `Paths.index()` (via your Paths module wrapping `Routes.path/1`) |
| Email URLs | `Routes.url("/users/confirm/#{token}")` (full URL) |

Tab structs use a relative convention where the core handles the `/admin/` prefix. Template paths and redirects are raw — they need the full path via `Routes.path/1`. The Paths module bridges this gap by centralizing the `/admin/my-module` base path in one `@base` attribute.

### Why relative paths break

**Never use relative paths** in `href` or `redirect(to:)`. The browser resolves them relative to the current URL. When locale segments (e.g., `/ja/`) or a URL prefix are in the path, relative paths resolve incorrectly:

```elixir
# If current URL is /phoenix_kit/ja/admin/my-module
# A relative href="items/new" would resolve to:
#   /phoenix_kit/ja/admin/my-module/items/new  (maybe correct by accident)
# But from /phoenix_kit/ja/admin/my-module/items/123:
#   /phoenix_kit/ja/admin/my-module/items/items/new  (broken!)

# Always use absolute paths via Routes.path/1:
Paths.item_new()  # → /phoenix_kit/ja/admin/my-module/items/new (always correct)
```

## Admin integration deep dive

### How routing works

You do **not** add routes manually. The `live_view` field in your tab structs tells PhoenixKit to generate routes at compile time. For a tab like:

```elixir
%Tab{
  path: "my-module",
  live_view: {MyPhoenixKitModule.Web.IndexLive, :index}
}
```

PhoenixKit generates:

```elixir
live "/admin/my-module", MyPhoenixKitModule.Web.IndexLive, :index
```

inside the admin `live_session` with the admin layout applied. This happens at compile time in `integration.ex`. After adding a new external module, the parent app needs a recompile (`mix deps.compile phoenix_kit --force` or restart the server).

### Admin layout is auto-applied

PhoenixKit's `on_mount` hook detects external plugin LiveViews and automatically applies the admin layout (sidebar, header, theme).

There are two supported shapes here. Pick one — don't mix them.

**1. Auto-applied chrome (the default — what this template does).** Assign `page_title` / `page_subtitle` in `mount/3` and render your inner content directly. Do not call `<PhoenixKitWeb.Components.LayoutWrapper.app_layout>` yourself; the layout already did.

**2. Self-wrapped layout (opt-out).** A module that needs to own the wrapper — to pass `app_layout` attributes the automatic call doesn't set — registers an `on_mount` that points `socket.private[:live_layout]` at the host's plain layout, then calls `app_layout` from its own `render/1`:

```elixir
on_mount({__MODULE__, :self_wrapped_layout})

def on_mount(:self_wrapped_layout, _params, _session, socket) do
  {:cont, put_in(socket.private[:live_layout], {MyAppWeb.Layouts, :app})}
end
```

`phoenix_kit_warehouse`'s `stock_live.ex` and `phoenix_kit_manufacturing`'s `machines_live.ex` both ship this pattern.

A stray `app_layout` call — pattern 2's `render/1` without pattern 2's `on_mount` — no longer produces two sidebars. Core's `LayoutWrapper.app_layout/1` detects that admin chrome was already rendered earlier in the same render tree, short-circuits to `render_slot(@inner_block)`, and logs a `:debug` message naming the fix. You get one sidebar and a log line rather than a broken page.

This all applies to admin LiveViews. Public controller templates (rendered via `Phoenix.Controller.render/2`) still need the wrapper if they use the app layout.

### Route module for complex routes

For simple modules, the `live_view` field in `admin_tabs/0` is sufficient — PhoenixKit auto-generates the admin route. For modules with complex routing needs (multiple admin pages, public-facing routes, custom controllers), implement `route_module/0`:

```elixir
@impl PhoenixKit.Module
def route_module, do: MyPhoenixKitModule.Routes
```

Your route module can implement these functions:

| Function | Position in router | Use for |
|---|---|---|
| `admin_locale_routes/0` | Inside admin live_session (localized) | Complex admin LiveView routes |
| `admin_routes/0` | Inside admin live_session (non-localized) | Same, for non-locale-prefixed paths |
| `generate/1` | Early, before localized routes | Non-catch-all public routes |
| `public_routes/1` | **Last**, after all other routes | Catch-all public routes (`/:group/*path`) |

**Route ordering matters.** If your module has catch-all routes like `/:group` or `/:group/*path`, they **must** go in `public_routes/1` — not `generate/1`. Routes in `generate/1` are placed early and will intercept admin paths, breaking the entire admin panel. `public_routes/1` is placed last, after all admin and localized routes, so catch-alls only match when nothing else does.

### Assigns available in admin LiveViews

PhoenixKit's `on_mount` hooks inject these assigns into every admin LiveView:

| Assign | Type | Description |
|---|---|---|
| `@phoenix_kit_current_scope` | `Scope` | The authenticated user's scope (roles, permissions) |
| `@phoenix_kit_current_user` | `User` | The authenticated user struct (`.uuid`, `.email`, …) |
| `@current_locale` | `String` | The current locale string (e.g., `"en"`, `"ja"`) |
| `@url_path` | `String` | The current URL path (used for active nav highlighting) |

Read the acting user with `PhoenixKitWeb.Actor.uuid(socket)` /
`PhoenixKitWeb.Actor.opts(socket)` rather than from the assigns by hand — it
checks the scope first, then the bare user.

These you **set** in `mount/3`; the admin layout reads them to draw the page
header, so a page never renders its own `<h1>`:

| Assign | Description |
|---|---|
| `page_title` | This page's title — this page only, no module prefix and no trail |
| `page_section` | The module's name (its admin tab label). Set on every sub-page; the landing page leaves it out, because there the module *is* the title |
| `page_section_path` | Where the section crumb links: the module's landing page |
| `page_crumbs` | Every level between the module and this page, as `[%{label:, path:}]` — omit when there is none |
| `page_subtitle` | One optional sentence under the title |

```elixir
assign(socket,
  page_title: gettext("Events"),
  page_section: gettext("Hello World"),
  page_section_path: Paths.index(),
  page_subtitle: gettext("Events logged by the Hello World module.")
)
```

### Tab struct complete reference

All fields available on `%PhoenixKit.Dashboard.Tab{}`:

| Field | Type | Default | Description |
|---|---|---|---|
| `:id` | atom | *required* | Unique identifier (prefix with `:admin_yourmodule`) |
| `:label` | string | *required* | Display text in sidebar |
| `:icon` | string | `nil` | Heroicon name (e.g., `"hero-puzzle-piece"`) |
| `:path` | string | *required* | Relative slug (`"my-module"`, the preferred form) or absolute (`"/admin/my-module"`). May carry dynamic segments (`"my-module/:id/edit"`) |
| `:priority` | integer | `500` | Sort order (lower = higher in sidebar) |
| `:level` | atom | `:user` | `:admin`, `:user`, or `:all`. Anything else is read as `:user` — a tab returned from `settings_tabs/0` is `:admin` too |
| `:permission` | string | `nil` | Permission key (use `module_key()`) |
| `:group` | atom | `nil` | Sidebar group (`:admin_modules` for module tabs) |
| `:match` | atom/fn | `:prefix` | `:exact`, `:prefix`, `{:regex, ~r/...}`, or `fn path -> bool end` |
| `:live_view` | tuple | `nil` | `{Module, :action}` for auto-routing |
| `:parent` | atom | `nil` | Parent tab ID (for hidden sub-pages or subtabs) |
| `:visible` | bool/fn/nil | `nil` | `nil` is "auto": shown unless the path has router parameters (`:id`, `*splat`), which are routes rather than navigation. `true`/`false` force it; `fn scope -> bool end` decides per viewer. For access control use `:permission`, not this |
| `:badge` | `Badge` | `nil` | Badge indicator (count, dot, status) |
| `:tooltip` | string | `nil` | Hover text |
| `:external` | bool | `false` | Whether this links to an external site |
| `:new_tab` | bool | `false` | Whether to open in a new browser tab |
| `:attention` | atom | `nil` | Animation: `:pulse`, `:bounce`, `:shake`, `:glow` |
| `:metadata` | map | `%{}` | Custom metadata for advanced use cases |
| `:subtab_display` | atom | `:when_active` | When to show subtabs: `:when_active` or `:always` |
| `:subtab_indent` | string | `nil` | Tailwind padding class (e.g., `"pl-6"`) |
| `:subtab_icon_size` | string | `nil` | Icon size class (e.g., `"w-3 h-3"`) |
| `:subtab_text_size` | string | `nil` | Text size class (e.g., `"text-xs"`) |
| `:subtab_animation` | atom | `nil` | `:none`, `:slide`, `:fade`, `:collapse` |
| `:redirect_to_first_subtab` | bool | `false` | Navigate to first subtab when clicking parent |
| `:highlight_with_subtabs` | bool | `false` | Keep parent highlighted when subtab is active |
| `:personal` | bool | `false` | The page shows the viewer their OWN data (an inbox, preferences), so it needs no `:permission` — marking it says the omission is deliberate |
| `:auto_grant_admin` | bool | `true` | Whether the Admin role is granted this tab's permission by default |
| `:dynamic_children` | fn | `nil` | `fn scope -> [tab] end` or `fn scope, locale -> [tab] end`, producing child tabs at render time |
| `:gettext_backend` | module | `nil` | Backend that translates `:label` and `:tooltip` at render. `nil` renders them as written, in every locale |
| `:gettext_domain` | string | `"default"` | The Gettext domain used with `:gettext_backend` |

### Subtabs (visible child tabs)

Subtabs appear indented under their parent in the sidebar. Use them for section-level navigation within your module:

```elixir
@impl true
def admin_tabs do
  [
    # Parent tab with subtab configuration
    %Tab{
      id: :admin_my_module,
      label: "My Module",
      icon: "hero-puzzle-piece",
      path: "my-module",
      priority: 650,
      level: :admin,
      permission: module_key(),
      match: :prefix,
      group: :admin_modules,
      subtab_display: :when_active,        # Show subtabs only when parent is active
      highlight_with_subtabs: false,        # Don't highlight parent when subtab is active
      live_view: {MyPhoenixKitModule.Web.IndexLive, :index}
    },
    # Visible subtab — appears indented in sidebar under parent
    %Tab{
      id: :admin_my_module_reports,
      label: "Reports",
      icon: "hero-chart-bar",
      path: "my-module/reports",
      priority: 651,
      level: :admin,
      permission: module_key(),
      parent: :admin_my_module,
      live_view: {MyPhoenixKitModule.Web.ReportsLive, :index}
    },
    # Another visible subtab
    %Tab{
      id: :admin_my_module_settings,
      label: "Settings",
      icon: "hero-cog-6-tooth",
      path: "my-module/settings",
      priority: 652,
      level: :admin,
      permission: module_key(),
      parent: :admin_my_module,
      live_view: {MyPhoenixKitModule.Web.SettingsLive, :index}
    }
  ]
end
```

### Hidden pages (invisible child tabs)

For pages that should exist as routes but not appear in the sidebar (e.g., edit pages, detail views), set `visible: false`:

```elixir
# Hidden — route exists, but no sidebar entry
%Tab{
  id: :admin_my_module_item_edit,
  path: "my-module/items/:uuid/edit",
  level: :admin,
  permission: module_key(),
  parent: :admin_my_module,           # Keeps parent highlighted
  visible: false,                      # Not shown in sidebar
  live_view: {MyPhoenixKitModule.Web.ItemEditorLive, :edit}
}
```

### Conditional tabs via config flags

Use `Application.compile_env/3` to gate tabs behind configuration:

```elixir
@testing_mode Application.compile_env(:my_phoenix_kit_module, :testing_mode, false)

@impl true
def admin_tabs do
  base_tabs() ++ testing_tabs()
end

defp base_tabs do
  [
    %Tab{id: :admin_my_module, ...}
  ]
end

defp testing_tabs do
  if @testing_mode do
    [
      %Tab{
        id: :admin_my_module_testing,
        label: "Testing",
        icon: "hero-beaker",
        path: "my-module/testing",
        priority: 690,
        level: :admin,
        permission: module_key(),
        parent: :admin_my_module,
        live_view: {MyPhoenixKitModule.Web.TestingLive, :index}
      }
    ]
  else
    []
  end
end
```

Users enable testing tabs in their config:

```elixir
config :my_phoenix_kit_module, :testing_mode, true
```

### Real-world example: Document Creator's 14 tabs

The Document Creator module demonstrates a complex multi-page admin integration:

```elixir
def admin_tabs do
  [
    # Main landing page (visible in sidebar, with subtabs)
    %Tab{id: :admin_document_creator, path: "document-creator",
         subtab_display: :when_active, highlight_with_subtabs: false, ...},

    # Hidden CRUD pages (route exists, no sidebar entry)
    %Tab{id: :admin_document_creator_template_new, path: "document-creator/templates/new",
         visible: false, parent: :admin_document_creator, ...},
    %Tab{id: :admin_document_creator_template_edit, path: "document-creator/templates/:uuid/edit",
         visible: false, parent: :admin_document_creator, ...},
    %Tab{id: :admin_document_creator_document_edit, path: "document-creator/documents/:uuid/edit",
         visible: false, parent: :admin_document_creator, ...},

    # Visible subtabs (appear under parent in sidebar)
    %Tab{id: :admin_document_creator_headers, path: "document-creator/headers",
         parent: :admin_document_creator, ...},
    %Tab{id: :admin_document_creator_footers, path: "document-creator/footers",
         parent: :admin_document_creator, ...},

    # Hidden pages for subtab CRUD
    %Tab{id: :admin_document_creator_header_new, path: "document-creator/headers/new",
         visible: false, parent: :admin_document_creator, ...},
    # ... and so on for header_edit, footer_new, footer_edit

    # Conditional testing tabs (behind config flag)
    # ... only included when :testing_editors config is true
  ]
end
```

Key takeaways from this pattern:
- **One main tab** visible in the sidebar with `subtab_display: :when_active`
- **Subtabs** for major sections (Headers, Footers) — visible, with `parent` pointing to main
- **Hidden tabs** for CRUD pages (new, edit) — `visible: false`, still auto-routed
- **Path parameters** work in tab paths: `"document-creator/templates/:uuid/edit"`
- **All tabs** share the same `permission: module_key()` for consistent access control

### Priority ranges

Priority controls the sort order in the sidebar (lower number = higher position):

| Range | Used by |
|---|---|
| 100-199 | Core admin (Dashboard) |
| 200-299 | Users section |
| 300-399 | Media section |
| 400-499 | Reserved for future core sections |
| 500-639 | First-party modules |
| **640-899** | **Your module's tabs — use this range** |
| 900-999 | System section (Settings, Modules) |

Pick a priority in the **640-899** range for your module. Avoid exact conflicts with other modules by spacing them out (e.g., 650, 700, 750).

### Sidebar groups

| Group | Description |
|---|---|
| `:admin_main` | Top-level admin sections |
| `:admin_modules` | Feature modules (use this for your tabs) |
| `:admin_system` | Settings, Modules page, system tools |

### Icons

PhoenixKit uses [Heroicons v2](https://heroicons.com). Reference them with the `hero-` prefix:

```
hero-puzzle-piece       hero-chart-bar        hero-shopping-cart
hero-document-text      hero-cog-6-tooth      hero-bolt
hero-bell               hero-envelope         hero-globe-alt
hero-cube               hero-rocket-launch    hero-sparkles
```

Browse the full set at [heroicons.com](https://heroicons.com). Use outline style (the default) — just prefix with `hero-` and convert to kebab-case.

## Permissions system

### How permissions work

PhoenixKit uses a role-based permission system. Every module can register a permission key via `permission_metadata/0`.

| Role type | Default access | Can be changed? |
|---|---|---|
| **Owner** | Full access to everything | No — hardcoded, cannot be restricted |
| **Admin** | All permission keys by default | Yes — per key via Admin > Roles |
| **Custom roles** | No permissions initially | Yes — must be granted explicitly |

### Registering your permission

```elixir
@impl true
def permission_metadata do
  %{
    key: module_key(),          # MUST match module_key/0 exactly
    label: "My Module",         # Shown in the permissions matrix UI
    icon: "hero-puzzle-piece",  # Icon in the matrix
    description: "Access to the My Module admin pages",
    # Translate the label in the permissions matrix through your own backend.
    gettext_backend: MyModule.Gettext,
    gettext_domain: "default",
    # Optional: fine-grained grants inside the module (see below).
    sub_permissions: [
      %{key: "moderate", label: "Moderate", description: "Approve or reject entries"}
    ]
  }
end
```

If you return `nil` (the default), the module has no dedicated permission key. Admins and owners can still see it, but custom roles never will.

### Checking permissions in code

The scope is available in admin LiveViews via `@phoenix_kit_current_scope`:

```elixir
alias PhoenixKit.Users.Auth.Scope

# In a LiveView
scope = socket.assigns.phoenix_kit_current_scope

Scope.has_module_access?(scope, "my_module")   # holds the module's base permission?
Scope.can?(scope, "my_module.moderate")         # holds this key AND the module is enabled?
Scope.can_access_admin_area?(scope)             # may reach the admin area at all?
Scope.system_role?(scope)                       # Owner, Admin, or User (not custom)?
Scope.owner?(scope)                             # is user Owner?
Scope.user_roles(scope)                         # list of role names
```

`can_access_admin_area?/1` is true for **anyone holding at least one admin
permission**, including a custom role with a single key — it does not mean
"Owner or Admin". (`Scope.admin?/1` is its deprecated old name, kept only as an
alias: the name promised a role check it never made.) To ask about a role, use
`owner?/1` or `user_roles/1`; to ask about a capability, use a permission.

### Sub-permissions

The base key answers "may this role enter the module". A **sub-permission** is
an additive grant for one capability inside it. Declare it in
`permission_metadata/0` with a bare key (`"moderate"`); it is stored, shown in
the roles matrix and checked as the composed key `"my_module.moderate"`.
Granting a sub grants its base, and a sub is only effective while the module is
enabled — so check it with `Scope.can?/2`, which re-reads enablement, in the
event handler as well as in the template:

```elixir
def handle_event("moderate", _params, socket) do
  if Scope.can?(socket.assigns[:phoenix_kit_current_scope], "my_module.moderate") do
    # ...
  else
    {:noreply, put_flash(socket, :error, gettext("You may not moderate."))}
  end
end
```

`Web.HelloLive` in this template shows both checks side by side: "Log demo
event" needs the base key, "Log moderation event" needs
`"hello_world.moderate"`.

### Access guards on admin tabs

PhoenixKit's `on_mount` hook automatically checks the `:permission` field on each tab before rendering the LiveView. If the user's role doesn't have the permission, they get a 302 redirect. You don't need to add manual guards — just set the `:permission` field correctly.

For fine-grained checks within a page (e.g., showing/hiding a delete button),
gate on a sub-permission. Resolve it once into an assign — `Scope.can?/2` reads
module enablement, so do it in `handle_params/3`, not in the template — and
check again in the handler, because a hidden button does not stop a crafted
event:

```elixir
def handle_params(_params, _uri, socket) do
  can_delete = Scope.can?(socket.assigns[:phoenix_kit_current_scope], "my_module.delete")
  {:noreply, assign(socket, :can_delete, can_delete)}
end

def render(assigns) do
  ~H"""
  <button :if={@can_delete} phx-click="delete" phx-disable-with={gettext("Deleting…")}>
    {gettext("Delete")}
  </button>
  """
end
```

### Permission validation at startup

The ModuleRegistry validates at boot:
- `permission_metadata().key` must match `module_key/0` — warns if mismatched
- Tabs with no `:permission` field — warns if the module has `permission_metadata`
- Duplicate tab IDs across modules — warns

These are warnings, not crashes, so a misconfigured module won't take down the app. But the symptom is that toggling the module works in the UI but permission checks use the wrong key.

## PhoenixKit components

`use PhoenixKitWeb, :live_view` is the recommended default for an admin LiveView: it imports PhoenixKit's core components, core's Gettext macros, layout config and HTML helpers. Follow it with `use Gettext, backend: MyModule.Gettext` so `gettext/1` translates through your own catalogue — the later `use` wins.

`use Phoenix.LiveView` directly is also fine, and is what an embedded LiveView (a nested `live_render`, a project-extension tab) should use; it then imports each core component it renders. Three LiveViews in this template do that — `events_live.ex`, `notifications_live.ex` and `project_hello_tab_live.ex`:

```elixir
use Phoenix.LiveView
use Gettext, backend: MyModule.Gettext

import PhoenixKitWeb.Components.Core.EmptyState, only: [empty_state: 1]
import PhoenixKitWeb.Components.Core.Icon, only: [icon: 1]
```

Either way the rule is the same: reach for the core component, not raw HTML.

Among the components `:live_view` imports:

- `<.icon name="hero-*" />` — Heroicons
- `<.button>`, `<.simple_form>`, `<.input>`, `<.select>`, `<.textarea>`, `<.checkbox>`
- `<.form_section>`, `<.form_actions>`, `<.label>` and `<.error>` (the form-field label and error primitives the inputs use)
- `<.flash>`, `<.header>`, `<.stat_card>`, `<.status_badge>` (also `<.role_badge>`, `<.enabled_badge>` — there is no bare `<.badge>`; a plain badge is the daisyUI `badge` class)
- `<.table_default>` with `<.sort_header_cell>`, `<.search_toolbar>`, `<.table_row_menu>`, the bulk-select family
- `<.modal>`, `<.confirm_modal>`, `<.popover_panel>`, `<.nav_tabs>`, `<.pagination>`, `<.load_more>`, `<.empty_state>`, `<.search_picker>`

The **Components** page of this module (`components_live.ex`) renders each of these live with a copy-paste snippet.

```elixir
defmodule MyModule.Web.DashboardLive do
  use PhoenixKitWeb, :live_view  # imports all PhoenixKit components

  def render(assigns) do
    ~H\"""
    <div class="card bg-base-100 shadow">
      <div class="card-body">
        <h2 class="card-title">
          <.icon name="hero-chart-bar" class="w-5 h-5" /> Dashboard
        </h2>
        <p class="text-base-content/70">Your module content here.</p>
      </div>
    </div>
    \"""
  end
end
```

For controllers, use `use PhoenixKitWeb, :controller`.

## Component reuse

As your module grows, extract shared UI into reusable function components. This keeps your LiveViews focused on business logic while shared presentation lives in dedicated component modules.

> **Important:** If your components use Tailwind CSS classes, implement `css_sources/0` in your main module so the parent app's Tailwind build can scan your templates. See [Tailwind CSS scanning for modules](#tailwind-css-scanning-for-modules) for details.

### Extracting a shared component

Create a component module under `web/components/`:

```elixir
# lib/my_phoenix_kit_module/web/components/item_card.ex
defmodule MyPhoenixKitModule.Web.Components.ItemCard do
  use Phoenix.Component

  attr :item, :map, required: true
  attr :on_edit, :string, default: nil
  attr :on_delete, :string, default: nil

  def item_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h3 class="card-title">{@item.name}</h3>
        <p class="text-base-content/70 text-sm">{@item.description}</p>
        <div class="card-actions justify-end">
          <button :if={@on_edit} class="btn btn-sm btn-ghost" phx-click={@on_edit} phx-value-uuid={@item.uuid}>
            Edit
          </button>
          <button :if={@on_delete} class="btn btn-sm btn-error btn-outline" phx-click={@on_delete} phx-value-uuid={@item.uuid}>
            Delete
          </button>
        </div>
      </div>
    </div>
    """
  end
end
```

### Using components in LiveViews

Import the component module and call the function:

```elixir
defmodule MyPhoenixKitModule.Web.IndexLive do
  use PhoenixKitWeb, :live_view

  import MyPhoenixKitModule.Web.Components.ItemCard

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-3 gap-4 p-4">
      <.item_card :for={item <- @items} item={item} on_edit="edit_item" on_delete="delete_item" />
    </div>
    """
  end
end
```

The same component can be used across multiple LiveViews in your module:

```elixir
# In another LiveView
defmodule MyPhoenixKitModule.Web.SearchResultsLive do
  use PhoenixKitWeb, :live_view

  import MyPhoenixKitModule.Web.Components.ItemCard

  def render(assigns) do
    ~H"""
    <div class="space-y-4 p-4">
      <.item_card :for={item <- @results} item={item} on_edit="view_item" />
    </div>
    """
  end
end
```

### Shared editor panel pattern

For modules with multiple editor pages (e.g., editing different entity types with the same UI), extract the editor shell as a component:

```elixir
# lib/my_phoenix_kit_module/web/components/editor_panel.ex
defmodule MyPhoenixKitModule.Web.Components.EditorPanel do
  use Phoenix.Component

  attr :id, :string, required: true, doc: "Unique prefix for all element IDs"
  attr :hook, :string, required: true, doc: "Phoenix hook name"
  attr :save_event, :string, required: true, doc: "LiveView event name for saving"
  attr :show_toolbar, :boolean, default: true

  def editor_panel(assigns) do
    ~H"""
    <div class="flex-1">
      <div
        id={"#{@id}-wrapper"}
        phx-hook={@hook}
        phx-update="ignore"
        data-editor-id={"#{@id}-editor"}
        data-save-event={@save_event}
      >
        <div :if={@show_toolbar} id={"#{@id}-toolbar"} class="border-b border-base-300 p-2">
          <%!-- Toolbar rendered by JS hook --%>
        </div>
        <div id={"#{@id}-editor"} style="min-height: 500px;"></div>
      </div>
    </div>
    """
  end
end
```

Then each editor LiveView imports and uses it with different parameters:

```elixir
# Template editor
import MyPhoenixKitModule.Web.Components.EditorPanel
<.editor_panel id="template" hook="TemplateEditor" save_event="save_template" />

# Document editor
<.editor_panel id="document" hook="DocumentEditor" save_event="save_document" show_toolbar={false} />
```

### Multi-step modal component

For complex workflows, extract modal components. Build them on core's
`<.modal>`, never on a raw `<div class="modal modal-open">`: core's modal is a
native dialog in the top layer, so it traps focus, closes on Esc, and guards
unsaved input. A hand-rolled `modal-open` div has none of that.

```elixir
# lib/my_phoenix_kit_module/web/components/create_modal.ex
defmodule MyPhoenixKitModule.Web.Components.CreateModal do
  use Phoenix.Component

  import PhoenixKitWeb.Components.Core.Modal, only: [modal: 1]

  attr :open, :boolean, required: true
  attr :step, :string, default: "choose"
  attr :on_close, :string, default: "modal_close"

  def create_modal(assigns) do
    ~H"""
    <.modal id="create-modal" show={@open} on_close={@on_close} max_width="lg">
      <%= case @step do %>
        <% "choose" -> %>
          <h3 class="text-lg font-bold">Choose Type</h3>
          <%!-- Step 1 content --%>
        <% "configure" -> %>
          <h3 class="text-lg font-bold">Configure</h3>
          <%!-- Step 2 content --%>
      <% end %>
    </.modal>
    """
  end
end
```

The Components page shows the same modal live, with a form inside it and the
drawer placement.

### Component design guidelines

1. **Use `attr` declarations** — they provide documentation, validation, and compile-time warnings
2. **Use daisyUI semantic classes** — `bg-base-100`, `text-base-content`, `btn btn-primary` (never hardcode colors)
3. **Use `text-base-content/70`** for muted text, not `text-gray-500`
4. **Prefix element IDs** with the component's `@id` attr to avoid collisions when multiple instances are on the same page
5. **Pass event names as attrs** (e.g., `on_edit="edit_item"`) rather than hardcoding them — this makes the component reusable across LiveViews with different event handlers

## Translations (Gettext)

A module owns its translations: its own Gettext backend, its own catalogue in
`priv/gettext`, shipped in its own package. A host then gets your strings
translated without touching core's catalogue or its own.

### 1. The backend

```elixir
# lib/my_phoenix_kit_module/gettext.ex
defmodule MyPhoenixKitModule.Gettext do
  use Gettext.Backend, otp_app: :my_phoenix_kit_module
end
```

with `{:gettext, "~> 1.0"}` in `deps`, `:gettext` in `extra_applications`, and
`priv` in the package's `files:`.

### 2. Call sites use the macros, with a literal msgid

```elixir
use PhoenixKitWeb, :live_view
use Gettext, backend: MyPhoenixKitModule.Gettext   # AFTER the web macro: the later `use` wins

gettext("Save")
gettext("Saved note: %{note}", note: note)
ngettext("%{count} event", "%{count} events", count)
```

`mix gettext.extract` reads the macros at compile time. A runtime call —
`Gettext.gettext(MyPhoenixKitModule.Gettext, "Save")` — is invisible to it:
the string lands in no catalogue, every locale shows English, and every
"untranslated" count still says zero.

Wrap everything a user reads: `page_title`, `page_subtitle`, flashes, button
labels, `phx-disable-with` text, empty-state copy, `aria-label`s. Code samples
inside `<pre>` are not copy.

**One sentence is one msgid.** Word order differs between languages, so a
sentence assembled from translated fragments around a link or a value cannot
be translated. Put values in with `%{placeholders}`; for a link or a `<code>`
span in the middle of a sentence, `Web.HelloLive`'s `<.inline>` renders markup
where the placeholder is while keeping the msgid one whole, HTML-free sentence.
A count gets `ngettext/3` — Russian has three plural forms, not two.

### 3. Labels that are data, not code

Tab labels and the permission label are plain strings in structs and maps;
core translates them when it renders the sidebar and the permissions matrix,
through the backend each declaration names:

```elixir
%Tab{label: "Events", gettext_backend: MyPhoenixKitModule.Gettext, gettext_domain: "default", ...}

%{key: module_key(), label: "My Module", gettext_backend: MyPhoenixKitModule.Gettext, ...}
```

The extractor cannot see a string that is not inside a Gettext macro, so pin
each one — `dgettext_noop/2` registers the msgid and returns it unchanged:

```elixir
def translatable_labels do
  [dgettext_noop("default", "My Module"), dgettext_noop("default", "Events")]
end
```

`PhoenixKitHelloWorld.translatable_labels/0` is that list here, and a test
compares it against the labels the module actually declares.

Strings a *different* package renders from your data — widget names in the
`phoenix_kit_dashboards` catalog, extension names in a project's Modules
panel — go through that package's catalogue, not yours; leave them plain.

### 4. Extract, translate, verify

```bash
mix gettext.extract --merge          # refresh default.pot and every .po
mix gettext.merge priv/gettext --locale et   # add a locale
```

Then fill every new `msgstr` in every locale you ship, in the same change.
Review each `#, fuzzy` entry the merge produced — its guesses are wrong more
often than right, and Gettext ignores a fuzzy entry at runtime anyway — and
diff the `.po` files to see that no existing translation changed. Completeness
is a code-versus-catalogue question, not an empty-`msgstr` count:
`test/phoenix_kit_hello_world_test.exs` asks the real backend for every msgid
in `default.pot` in every shipped locale.

An embedded LiveView (a nested `live_render`) is its own process and starts in
the default locale; set it on mount from the session, for **both** backends —
your own and core's — as `project_hello_tab_live.ex` does:

```elixir
Gettext.put_locale(MyPhoenixKitModule.Gettext, locale)
Gettext.put_locale(PhoenixKitWeb.Gettext, locale)
```

Setting only your own leaves every core component inside the embed in the
default language.

## JavaScript in modules

A LiveView JS hook has to be in the host's single `LiveSocket` **when it is
constructed**. A module cannot edit the host's `app.js`, and it must not
register a hook from an inline `<script>` in a template either: morphdom does
not execute a script tag it inserts, so an inline hook works on a full page
load and silently binds to nothing once the page is reached by
`navigate/2` — which is how every sidebar link reaches it. There is no error;
the element just has no behaviour.

So there are exactly two ways to get a hook, in this order.

### First: use a core hook

Core's hooks ship in PhoenixKit's own bundle, are in the `LiveSocket` on every
page load, and usually come wrapped in a component — you write no JavaScript
at all. `InfiniteScroll` pairs with `<.load_more infinite>`:

```elixir
import PhoenixKitWeb.Components.Core.Pagination, only: [load_more: 1]

<.load_more id="events-load-more" loaded={@loaded} total={@total} infinite />
```

`events_live.ex` in this template uses exactly that — auto-load on scroll plus
a manual "Load more" fallback button, and no JS of its own. Others you get the
same way: `PkDialog` (`<.modal>`), `RowMenu` (`<.table_row_menu>`),
`BulkSelectScope` (`<.bulk_select_scope>`), `SearchPicker`
(`<.search_picker>`), `TableCardView` (`<.table_default toggleable>`),
`TimeAgo` (`<.time_ago>`) and the sortable hooks behind `<.draggable_list>`.
The Components page of this module exercises each one.

### Otherwise: ship a prebuilt bundle and declare it with `js_sources/0`

When core has nothing suitable, your module ships its own hooks as a
**prebuilt** JavaScript file in its `priv/` and declares it:

```elixir
# lib/my_phoenix_kit_module.ex
@impl PhoenixKit.Module
def js_sources do
  [
    %{
      app: :my_phoenix_kit_module,
      file: "static/assets/my_phoenix_kit_module.js",
      global: "MyPhoenixKitModuleHooks"
    }
  ]
end
```

| Key | Meaning |
|---|---|
| `:app` | The OTP app that ships the file. Resolved through `:code.priv_dir/1`, so Hex installs and path deps both work |
| `:file` | Path of the bundle **inside that app's `priv/`** |
| `:global` | The `window.<Name>` the bundle assigns its hooks to. Must be unique across every installed module — the compiler fails on a collision |

The bundle is plain browser JavaScript that assigns an object of hooks to that
global:

```javascript
// priv/static/assets/my_phoenix_kit_module.js
window.MyPhoenixKitModuleHooks = {
  // Namespace every hook name with the module's name.
  MyPhoenixKitModuleEditor: {
    mounted() {
      this.el.addEventListener("input", () => {
        this.pushEvent("content_changed", {value: this.el.value});
      });
      this.handleEvent("load-content", ({value}) => { this.el.value = value; });
    }
  }
};
```

```heex
<textarea id="my-editor" phx-hook="MyPhoenixKitModuleEditor" phx-update="ignore"></textarea>
```

Core's `:phoenix_kit_js_sources` compiler — installed in the host by
`mix phoenix_kit.install` / `mix phoenix_kit.update` — concatenates every
declared bundle into the host's `priv/static/assets/vendor/phoenix_kit_modules.js`
and folds each `window.<Global>` into `window.PhoenixKitHooks`, which the host
already spreads into its `LiveSocket`. The host loads one script and edits
nothing per module.

Rules that bite:

- **Prebuilt means prebuilt.** The host does not run your bundler. If you
  write TypeScript or import npm packages, build to a single browser-ready
  file and commit the output under `priv/static/assets/`. A third-party
  library goes **into** that bundle — not behind a CDN `<script>` tag, which
  is an inline script again, an external request on every page, and a
  supply-chain dependency the host never agreed to.
- **`priv` must be in `files:`** in your `mix.exs` package, or the published
  package has no bundle and the hook is missing only for Hex installs.
- **Namespace hook names** (`MyPhoenixKitModuleEditor`, not `Editor`). The
  compiler enforces unique *globals* but cannot see inside a bundle, and the
  final fold is last-write-wins on *hook names*: two modules exporting `Chart`
  clobber each other, and a hook named like a core one (`RowMenu`) silently
  replaces core's.
- **Do not annotate `js_sources/0` with `@impl` unless your `phoenix_kit`
  floor declares the callback** (core 2.38 does). Against an older core the
  annotation is a compile warning, and warnings are errors in `mix precommit`.
- **The host recompiles to pick it up.** After adding or changing a bundle,
  the host needs `mix compile` (the compiler regenerates the combined file)
  and a hard reload.
- **Make hooks an enhancement where you can.** A page that still works with
  the hook absent degrades instead of breaking; `phoenix_kit_dashboards`'
  drag-and-drop hooks sit on top of a form that does the same job.

References: `phoenix_kit_dashboards` (`js_sources/0` plus
`priv/static/assets/phoenix_kit_dashboards.js`) and `phoenix_kit_comments`.
This template ships no hook of its own, so it leaves `js_sources/0` at its
`[]` default.

### LiveView JS interop

Communicate between your JS hooks and LiveView:

```javascript
// JS → Elixir (push events to the server)
this.pushEvent("save_content", {html: editor.getHtml(), css: editor.getCss()});

// Elixir → JS (handle server-pushed events)
this.handleEvent("load-content", ({html, css}) => {
  editor.setContent(html);
});

// Elixir → JS (push from server in handle_event)
// In your LiveView:
{:noreply, push_event(socket, "load-content", %{html: content.html, css: content.css})}
```

## Available PhoenixKit APIs

Your module has access to the full PhoenixKit API through the dependency. Here's what's available and where to look. Run `mix docs` in phoenix_kit for the full API reference.

### Settings (`PhoenixKit.Settings`)

Read and write persistent key/value settings stored in the database.

```elixir
Settings.get_setting("my_key")                          # returns string or nil
Settings.get_boolean_setting("my_key", false)            # returns boolean with default
Settings.get_json_setting("my_key")                      # returns decoded map/list
Settings.update_setting("my_key", "value")               # write a string
Settings.update_boolean_setting_with_module("my_key", true, module_key())  # write boolean tied to module
```

### Permissions & Scope (`PhoenixKit.Users.Permissions`, `PhoenixKit.Users.Auth.Scope`)

Check what the current user can access. The scope is available in LiveViews via `@phoenix_kit_current_scope`.

```elixir
# In a LiveView
scope = socket.assigns.phoenix_kit_current_scope

Scope.has_module_access?(scope, "my_module")   # holds the module's base permission?
Scope.can?(scope, "my_module.moderate")         # holds this key AND the module is enabled?
Scope.can_access_admin_area?(scope)             # may reach the admin area at all (any admin permission)
Scope.system_role?(scope)                       # Owner, Admin, or User (not custom)?
Scope.owner?(scope)                             # is user Owner?
```

See [Checking permissions in code](#checking-permissions-in-code) — `Scope.admin?/1` is deprecated.

### Tab struct (`PhoenixKit.Dashboard.Tab`)

See [Tab struct complete reference](#tab-struct-complete-reference) for all fields.

### Routes & Navigation (`PhoenixKit.Utils.Routes`)

See [Navigation system](#navigation-system) for the full guide.

```elixir
alias PhoenixKit.Utils.Routes

Routes.path("/admin/my-module")       # → /phoenix_kit/ja/admin/my-module
Routes.url("/users/confirm/#{token}") # full URL for emails
```

### Date formatting (`PhoenixKit.Utils.Date`)

```elixir
alias PhoenixKit.Utils.Date, as: UtilsDate

UtilsDate.utc_now()                              # truncated to seconds (safe for DB writes)
UtilsDate.format_datetime_with_user_format(dt)   # uses admin settings for format
```

### UI guidelines

PhoenixKit's UI targets **daisyUI 5** — minimum **5.6.0**, verified against 5.6.17. daisyUI lives in the **host app** (`assets/vendor/daisyui.js`), not in PhoenixKit; core ships themes only. `mix phoenix_kit.doctor` warns when the host's copy is older than the minimum, and `PhoenixKit.Install.DaisyUI.minimum_version/0` is the authoritative value.

- Use **daisyUI semantic classes** — `bg-base-100`, `text-base-content`, `btn btn-primary`, `badge badge-success`
- Never hardcode colors like `bg-white`, `text-gray-500`, etc. — these break with themes
- Use `text-base-content/70` for muted text
- **Don't use daisyUI v4 classes that v5 removed** ([upgrade guide](https://daisyui.com/docs/upgrade/)): `btn-group` (use `join` + `join-item`), `label-text` (plain text inside `<label class="label">`), and the `*-bordered` family — `input-bordered`, `select-bordered`, `textarea-bordered`, `file-input-bordered` — which are unnecessary because those elements have a border by default in v5
- daisyUI 5 needs the wrapper `<label class="select">` pattern around a bare `<select>` — the core `<.select>` component handles this, which is one more reason to use it over raw HTML
- The admin layout is applied automatically for plugin LiveViews — just render your content
- **Render no page-level heading and no page-level width cap** — `page_title`/`page_subtitle` are rendered once by the layout, and the layout owns page width. No `container`, no page-root `max-w-*`
- Use `card bg-base-100 shadow-xl` for card containers
- Use `badge badge-sm` for status indicators
- Prefer core components over hand-rolled markup: `<.table_default>`, `<.pagination>` / `<.load_more>`, `<.empty_state>`, and the core form primitives. The Components showcase pairs each raw daisyUI section with its core counterpart

## Cross-module integration

Your module can depend on other PhoenixKit modules or external plugins. There are two patterns depending on whether the dependency is required or optional.

### Required dependency

If your module won't work without another module, add it to `mix.exs`. Mix enforces it at install time — if the user doesn't have it, `mix deps.get` fails with a clear error.

```elixir
# mix.exs
defp deps do
  [
    {:phoenix_kit, ">= 2.38.0 and < 3.0.0"},
    {:phoenix_kit_billing, "~> 0.21"}  # hard requirement
  ]
end
```

Then use it directly in your code — the code is always there, but the feature
can still be switched off, so ask `enabled?/0`:

```elixir
def checkout_currencies do
  if PhoenixKitBilling.enabled?() do
    PhoenixKitBilling.list_enabled_currencies()
  else
    []  # billing code is installed but the feature is toggled off
  end
end
```

Declare the same requirement to core with `required_modules/0`
(`def required_modules, do: ["billing"]`), so the Modules page can say why
yours cannot be enabled on its own.

### Optional dependency

If your module has bonus features when another module is present but works fine without it, declare the dep `optional: true` and check for it at runtime with `Code.ensure_loaded?/1`:

```elixir
# mix.exs
{:phoenix_kit_ai, "~> 0.25", optional: true}
```

```elixir
# The module is absent in hosts that do not install it; tell the compiler
# the reference is deliberate, or it is an "undefined module" warning.
@compile {:no_warn_undefined, PhoenixKitAI}

def ai_features_available? do
  Code.ensure_loaded?(PhoenixKitAI) and PhoenixKitAI.enabled?()
end

def maybe_generate_summary(endpoint_uuid, content) do
  if ai_features_available?() do
    PhoenixKitAI.ask(endpoint_uuid, "Summarize this:\n\n" <> content)
  else
    {:ok, nil}
  end
end
```

`optional: true` governs the *consumer's* dependency closure only — the dep is
still present in your own build, so a direct reference you forgot to guard
compiles fine for you and breaks in a host without it. Keep every call behind
one doorway function, and compile once with the dep removed to prove it.

Two integrations need no dependency in either direction, because the other
package discovers a plain function on your module at runtime:
`phoenix_kit_widgets/0` contributes widgets to `phoenix_kit_dashboards`, and
`phoenix_kit_project_extensions/0` contributes a tab to `phoenix_kit_projects`.
This template implements both as fully commented references
(`lib/phoenix_kit_hello_world.ex`, `web/hello_widget.ex`,
`web/project_hello_tab_live.ex`). Likewise `resource_links/0` makes your
resource types clickable in core's activity feed and in `phoenix_kit_comments`
with no host configuration.

### Pattern summary

| Scenario | How | What happens if missing |
|---|---|---|
| **Required** | Add to `mix.exs` deps | `mix deps.get` fails |
| **Optional** | `optional: true` dep + `Code.ensure_loaded?/1` + `enabled?()` | Feature hidden, no errors |
| **Duck-typed** | Export the function the other package looks for | Nothing happens; no dependency either way |
| **Feature flag** | `Settings.get_boolean_setting/2` | Feature toggled off at runtime |

## Database conventions

If your module needs database tables, follow these conventions to avoid collisions with other modules and phoenix_kit internals.

### Table naming

Prefix all tables with `phoenix_kit_` followed by your module key:

```
phoenix_kit_my_module_items
phoenix_kit_my_module_categories
```

Never use generic names like `items` or `posts` — another module or the parent app might use them.

### Ecto schemas

Every table-backed schema starts with the same two lines:

```elixir
defmodule MyPhoenixKitModule.Schemas.Item do
  use Ecto.Schema
  use PhoenixKit.SchemaPrefix
  import Ecto.Changeset

  @primary_key {:uuid, UUIDv7, autogenerate: true}
  @foreign_key_type UUIDv7

  schema "phoenix_kit_my_module_items" do
    field :name, :string
    timestamps(type: :utc_datetime_usec)
  end
end
```

`use PhoenixKit.SchemaPrefix` is load-bearing: PhoenixKit supports installing
into a named Postgres schema (`mix phoenix_kit.install --prefix "auth"`), and
the migrations create your tables inside that schema. This line makes your
queries target it too — without it they resolve via the connection's
`search_path`, which works on public installs and silently breaks on prefixed
ones. With no prefix configured it compiles to nil (zero behavior change), so
never omit it.

A fully-commented copyable template lives at
`lib/phoenix_kit_hello_world/schemas/example_item.ex`, and
`test/schema_prefix_conformance_test.exs` (also part of this template) scans
`lib/` so a schema can't silently skip the attribute — copy both.

One more rule that file records: the schema's `timestamps/1` type must match
the one your migration used — both templates here use `:utc_datetime_usec`.
`timestamps(type: :utc_datetime)` against the microsecond columns
`:utc_datetime_usec` creates silently truncates on write.

### Versioned migrations

**Your module owns the DDL for its own tables.** The migrations that create
them live in your repo and ship inside your package — they are *not* added as a
new `Vxxx` to core `phoenix_kit`'s migration chain. Core's chain stays about
core's tables; your schema versions with the package that owns it, and hosts
that never install your module never carry your DDL.

`phoenix_kit_hello_world` is the template and owns no tables of its own — a
demo module has no business creating one in every host that installs it. It
carries the pattern as a fully-commented file that compiles to nothing,
`lib/phoenix_kit_hello_world/migrations.ex`: copy it, uncomment, rename. Two
published modules run this exact shape if you want a working reference —
`phoenix_kit_boards` (single table) and `phoenix_kit_web_analytics` (two
tables plus indexes).

#### How it works

1. Your module implements `migration_module/0`, returning a coordinator module.
2. The coordinator tracks the installed version in a `COMMENT ON TABLE` on one
   of your tables.
3. Each version is an immutable step (`up_v1/1`, `up_v2/1`, …) that creates or
   alters tables.
4. In the host app, `mix phoenix_kit.update` discovers every module's
   coordinator, generates a host migration for each one that is behind, and
   runs `mix ecto.migrate`.

No install task, and no hand-written SQL in the host.

#### Before you claim a table

Check that core's chain does not already create it:

```bash
grep -rn "<your table name>" deps/phoenix_kit/lib/phoenix_kit/migrations/postgres/
```

This matters because `mix phoenix_kit.update` runs core's own migrations
*before* module migrations. If core's chain also ships your DDL, core wins every
time: your table always pre-exists, your `up/1` is dead code on every host, and
the two definitions quietly drift — different column widths, different index
names, sometimes a different primary key. Nothing errors, and the update prints
a green line for a module whose migration has never executed.

`phoenix_kit_legal` shipped in exactly that state until 0.1.11: core's V43
creates `phoenix_kit_consent_logs`, so the module's own coordinator had never
run anywhere, and the two DDLs disagreed on four column definitions and the
primary key. The writeup is in that repo at
`dev_docs/reports/2026-08-10-module-migration-versioning.md`.

If core does create your table, you do not get to start clean. Your first real
version is the step that **reconciles** both shapes, and it has to reach the same
end state from either starting point — which also means adopting one index naming
scheme and dropping the other, rather than creating a parallel set every host
then maintains twice.

#### The coordinator

The shape below is the skeleton of the template at
`lib/phoenix_kit_hello_world/migrations.ex` — read that file for the fully
commented version.

```elixir
defmodule MyModule.Migrations do
  @moduledoc "Versioned migration coordinator for `my_module`."

  use Ecto.Migration

  alias PhoenixKit.Migrations.Postgres.Helpers

  @initial_version 1
  @current_version 1
  @default_prefix "public"
  @version_table "phoenix_kit_my_module_items"

  @doc "The version this code expects the schema to be at."
  def current_version, do: @current_version

  @doc "The version a bare, freshly created table is at."
  def initial_version, do: @initial_version

  @doc """
  The table whose COMMENT carries the version marker.

  Not part of the protocol core calls. Export it so an auditor can verify your
  marker really carries a version (a bare number, or a namespaced marker for
  an adopted table) without hard-coding your table name — see
  `mix phoenix_kit_hello_world.audit_migrations`.
  """
  def version_table, do: @version_table

  def up(opts \\ []) do
    opts = with_defaults(opts, @current_version)
    initial = migrated_version(opts)

    cond do
      initial == 0 -> change(@initial_version..opts.version, :up, opts)
      initial < opts.version -> change((initial + 1)..opts.version, :up, opts)
      true -> :ok
    end

    :ok
  end

  @doc """
  Roll back to the target version. `version: 0` drops; any higher target KEEPS
  the table. Core generates `down(version: 1)` for a V2→V1 rollback, so a
  coordinator whose `down/1` always drops answers "return to V1" by deleting the
  user's data.
  """
  def down(opts \\ []) do
    opts = with_defaults(opts, 0)
    current = migrated_version(opts)
    target = opts.version

    if current > target, do: change(current..(target + 1)//-1, :down, opts)

    :ok
  end

  # Migration context — reads through the `Ecto.Migration` repo() helper. No
  # rescue: inside a migration, a version you cannot read must abort the
  # transaction, never be guessed at.
  def migrated_version(opts \\ []) do
    opts = with_defaults(opts, @initial_version)
    read_version(repo(), opts.prefix)
  end

  # Runtime context — this is the one `mix phoenix_kit.update` calls, from a
  # Mix task with no migrator running, so it goes through PhoenixKit's
  # configured repo instead.
  #
  # An invalid prefix is re-raised, matching core's own reader: 0 means "this
  # module is not installed here", so reporting it for a bad prefix tells the
  # operator something false and sends the updater off to install a schema over
  # live data. Genuine unreachability still yields 0, which is safe only because
  # up/1 re-reads the version in migration context before touching anything.
  def migrated_version_runtime(opts \\ []) do
    opts = with_defaults(opts, @initial_version)
    read_version(PhoenixKit.RepoHelper.repo(), opts.prefix)
  rescue
    e in ArgumentError -> reraise e, __STACKTRACE__
    _ -> 0
  end

  # ── v1 ──────────────────────────────────────────────────────────────────

  defp up_v1(prefix) do
    # Don't assume core's chain ran first. `uuid_generate_v7()` is built on
    # pgcrypto's `gen_random_bytes` and `ensure_uuid_v7_function/1` does not
    # install extensions — without the first line the function is created and
    # then fails on the first insert.
    Helpers.ensure_extension!("pgcrypto")
    Helpers.ensure_uuid_v7_function(prefix)

    create_if_not_exists table(:phoenix_kit_my_module_items,
                           primary_key: false,
                           prefix: prefix
                         ) do
      add(:uuid, :uuid,
        primary_key: true,
        null: false,
        default: fragment(Helpers.uuid_v7_call(prefix))
      )

      add(:name, :string, null: false)
      add(:status, :string, size: 20, null: false, default: "active")

      timestamps(type: :utc_datetime_usec)
    end

    # Bare index name — `CREATE INDEX schema.name` is a syntax error.
    create_if_not_exists(index(:phoenix_kit_my_module_items, [:status], prefix: prefix))
  end

  defp down_v1(prefix) do
    drop_if_exists(table(:phoenix_kit_my_module_items, prefix: prefix))
  end

  # ── internals ───────────────────────────────────────────────────────────

  defp change(range, direction, opts) do
    Enum.each(range, &apply_step(direction, &1, opts.prefix))

    case direction do
      :up -> record_version(opts, Enum.max(range))
      :down -> record_version(opts, max(Enum.min(range) - 1, 0))
    end
  end

  defp apply_step(:up, 1, prefix), do: up_v1(prefix)
  defp apply_step(:down, 1, prefix), do: down_v1(prefix)

  defp apply_step(direction, version, _prefix) do
    raise ArgumentError, "no #{direction} step defined for schema version #{version}"
  end

  defp record_version(_opts, 0), do: :ok

  defp record_version(%{prefix: prefix}, version) do
    execute("COMMENT ON TABLE #{Helpers.qualify_table(@version_table, prefix)} IS '#{version}'")
  end

  defp with_defaults(opts, version) do
    opts = Enum.into(opts, %{})
    prefix = Map.get(opts, :prefix) || @default_prefix

    # The prefix is interpolated into the DDL above, so an invalid one has to
    # fail here rather than reach the query text.
    Helpers.validate_prefix!(prefix)

    opts
    |> Map.put(:prefix, prefix)
    |> Map.put_new(:version, version)
  end

  # Reads use bound parameters, so the prefix never reaches the query text.
  defp read_version(repo, prefix) do
    if table_exists?(repo, prefix) do
      repo |> table_comment(prefix) |> parse_version()
    else
      0
    end
  end

  defp table_exists?(repo, prefix) do
    query = """
    SELECT EXISTS (
      SELECT FROM information_schema.tables
      WHERE table_name = $1 AND table_schema = $2
    )
    """

    case repo.query(query, [@version_table, prefix], log: false) do
      {:ok, %{rows: [[exists?]]}} -> exists?
      {:error, error} -> raise error
    end
  end

  defp table_comment(repo, prefix) do
    query = """
    SELECT pg_catalog.obj_description(c.oid, 'pg_class')
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = $1 AND n.nspname = $2
    """

    case repo.query(query, [@version_table, prefix], log: false) do
      {:ok, %{rows: [[comment]]}} -> comment
      {:ok, %{rows: []}} -> nil
      {:error, error} -> raise error
    end
  end

  # A numeric comment is the marker. Anything else on a table that exists means
  # V1 — either no comment yet, or someone else's prose. `Integer.parse/1` and
  # not `String.to_integer/1`: the latter RAISES on prose, and that raise lands
  # in migrated_version_runtime's rescue, which turns it into 0 — "not
  # installed" for a populated table.
  defp parse_version(comment) when is_binary(comment) do
    case Integer.parse(String.trim(comment)) do
      {version, ""} -> version
      _ -> @initial_version
    end
  end

  defp parse_version(_), do: @initial_version
end
```

#### Registering it

```elixir
@impl PhoenixKit.Module
def migration_module, do: MyModule.Migrations
```

That is the entire registration — no config entry, no install task.

#### How upgrades work

When a host updates your dep and runs `mix phoenix_kit.update`:

1. PhoenixKit discovers your module by scanning beam files.
2. It calls `migration_module/0` to find the coordinator.
3. It compares `migrated_version_runtime(prefix: prefix)` with `current_version()`.
4. If the database is behind, it writes a migration into the host's
   `priv/repo/migrations/` and runs `mix ecto.migrate`:

```elixir
defmodule MyApp.Repo.Migrations.MyModuleUpdateV01ToV02 do
  use Ecto.Migration

  def up, do: MyModule.Migrations.up(prefix: "public", version: 2)
  def down, do: MyModule.Migrations.down(prefix: "public", version: 1)
end
```

Fresh installs run V1 → V2 → … in order; hosts at V1 run only the steps after V1.

#### Adding a V2

When you need to change the schema, **never edit V1**. A host that already ran
V1 will never run it again, so an edit there only forks fresh installs from
upgraded ones. Add a step:

```elixir
defp up_v2(prefix) do
  alter table(:phoenix_kit_my_module_items, prefix: prefix) do
    add_if_not_exists(:metadata, :map, null: false, default: %{})
  end

  create_if_not_exists(index(:phoenix_kit_my_module_items, [:name], prefix: prefix))
end

defp down_v2(prefix) do
  alter table(:phoenix_kit_my_module_items, prefix: prefix) do
    remove_if_exists(:metadata, :map)
  end
end
```

Then add the dispatch clauses and bump the version:

```elixir
defp apply_step(:up, 2, prefix), do: up_v2(prefix)
defp apply_step(:down, 2, prefix), do: down_v2(prefix)

@current_version 2  # was 1
```

Two rules that only bite at V2, so they are easy to ship without noticing:

- **The version must be *stored*, not inferred.** A reader that answers "is the
  table there?" cannot tell V1 from V2, so it reports the target version for
  every host and core skips the delta — printing success while applying nothing.
  That is why the marker lives in `COMMENT ON TABLE`.
- **Repair inference and rollback together.** While the marker is inferred, no
  host with an existing table is ever handed an upgrade migration, so a `down/1`
  that always drops is unreachable and looks harmless. Fix the marker alone and
  you arm it: real `down(version: N > 0)` calls start the same day.

#### Auditing a live host

```bash
mix phoenix_kit_hello_world.audit_migrations
mix phoenix_kit_hello_world.audit_migrations --prefix auth
```

Run in the host app against a migrated database. For every installed module that
declares a `migration_module/0` it checks the protocol exports, that an absent
schema reports 0, that an unusable prefix raises instead of reporting 0, that the
reported version is not ahead of the shipped code, and — when the coordinator
exports `version_table/0` — that the stored marker actually carries a version —
a bare number, or a namespaced marker like `pkl_schema:1` for an adopted table —
rather than someone's prose description. Read-only, and exits non-zero on
failure so it can gate a release.

Everything it checks is silent when broken, which is the point: none of these
defects produce an error message, and a database-less test suite cannot see any
of them.

What it cannot decide for you is who owns the table. These three queries settle
that, and they disagree with the source more often than you would expect:

```sql
-- is the marker a number, or someone else's prose?
SELECT pg_catalog.obj_description(c.oid, 'pg_class')
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname = '<your table>';

-- whose index names are these?
SELECT indexname FROM pg_indexes
WHERE schemaname = 'public' AND tablename = '<your table>';

-- whose CREATE TABLE ran? column ORDER is the fingerprint
SELECT column_name, data_type, character_maximum_length, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = '<your table>'
ORDER BY ordinal_position;
```

#### Prefix safety

PhoenixKit can install into a named Postgres schema
(`mix phoenix_kit.install --prefix "auth"`), and the generated host migration
passes that prefix straight into your `up/1`. Migration code that ignores it
scatters half the module's tables into `public`. Rules:

- Pass `prefix:` to every `table/2`, `index/3`, and `alter table`.
- Keep index **names** bare on `CREATE INDEX` — Postgres rejects
  `CREATE INDEX schema.name` and scopes an index to its table's schema anyway.
  Only `DROP INDEX schema.name` accepts a qualified name.
- Anchor existence checks to the target schema
  (`AND table_schema = '#{prefix}'`), never to `search_path`.
- Use `PhoenixKit.Migrations.Postgres.Helpers` rather than hand-rolling SQL
  strings: `qualify_table/2`, `uuid_v7_call/1`, `ensure_uuid_v7_function/1`,
  `validate_prefix!/1`.

#### Adopting a table core already creates (extraction)

Some module tables were born in core — the module once lived there, or the
table predates the module-owned protocol — and ship in core's squashed
baseline, so on every existing install the table exists before your chain
first runs. Extraction is an **adoption**, in phases (live reference:
`phoenix_kit_legal`, `PhoenixKit.Modules.Legal.Migrations` and its
`dev_docs/reports/2026-08-10-consent-logs-extraction.md`):

**The rule since 2026-10-25: a module's tables are created and changed only by
its own chain.** Core's migrations no longer touch a module's table after V223
(core's `PhoenixKit.Migrations.ModuleOwnedTables` says which core-created
tables are whose, and a core test fails a later version that names one), so a
change to a table core created for your module always goes into your chain,
never into a core release. Core's
`dev_docs/plans/2026-10-25-module-table-ownership.md` tracks moving every
module there.

**Prove your chain builds its tables without core**: on a host core's chain
runs first, so your adoption DDL never runs and nothing shows whether it is
complete. `PhoenixKit.TestSupport.ModuleChainCheck.check(MyModule.Test.Repo,
MyModule.Migrations)` from an `async: false` `ExUnit.Case` test builds them
both ways in a scratch schema and lists every difference (core's
`dev_docs/guides/2026-09-05-module-table-extraction-guide.md`).

- **Phase 0 — V1 adopts, changes nothing.** `CREATE TABLE IF NOT EXISTS`
  shape-identical to core's baseline with core's exact object names, then a
  **namespaced** marker stamp (`pkl_schema:1` — an adopted table may carry a
  foreign comment, and your reader must treat prose as version 0). Build the
  DDL from your schema module's single shape authority, expose the statements
  as data, and test-pin them: widths, core's names, idempotence guards, and —
  for data-bearing tables — no `DROP`/`TRUNCATE`/`DELETE` in either
  direction. An audit-trail table survives `down/1`: unstamp, keep the rows.
  Because the shape is unchanged, core's `ExpectedSchema` stays accurate —
  **no core release is needed and there is no ordering hazard**.
- **Phase 1 — your first shape change (V2+) is when core moves.** Before that
  release: add the altered objects to core's manifest generator
  `@excluded_exact` and regenerate `ExpectedSchema` (maintainer tooling),
  then raise your core floor to that release — otherwise
  `mix phoenix_kit.repair` restores the old shape after every run.
- **Phase 2 — creation leaves core at the next baseline squash.** Fresh
  installs then get the table from your V1, which is why V1 must be able to
  create the full table even though today it always finds one. Existing
  installs are untouched.

Never write a conditional core migration of the form "module absent → drop
the table": it is nondeterministic (the schema would depend on which packages
are compiled in, breaking the manifest, the chain hash and the squash
verification oracles) and it destroys data on hosts that merely removed the
package. Real uninstalls are a human step — ship a "removing this module"
snippet in your README instead.

Core keeps a short pointer to this section for people who start from the
core repo: `dev_docs/guides/2026-09-05-module-table-extraction-guide.md`.

#### Testing your migration

A coordinator that compiles is not a coordinator that runs. `up/1` uses
`Ecto.Migration` macros, so it needs a migrator process around it — wrap it
once in `test/support/migration_runner.ex`:

```elixir
defmodule MyModule.Test.MigrationRunner do
  use Ecto.Migration

  def up, do: MyModule.Migrations.up(prefix: "public")
  def down, do: MyModule.Migrations.down(prefix: "public", version: 0)
end
```

and run it from `test/test_helper.exs`, after core's chain:

```elixir
PhoenixKit.Migration.ensure_current(MyModule.Test.Repo, log: false)

Ecto.Migrator.up(
  MyModule.Test.Repo,
  :os.system_time(:microsecond),
  MyModule.Test.MigrationRunner,
  log: false
)
```

The microsecond version makes the wrapper re-run on every boot instead of
being short-circuited by a stale `schema_migrations` row; the coordinator is
idempotent, so a re-run against an up-to-date database is a no-op. Your test
database is then built by exactly the code a host app runs — no separate
fixture DDL to drift.

#### Key rules

- **Module tables belong to the module** — never add them to core's `Vxxx` chain.
- **Version steps are immutable** — never edit a shipped V1. Add a V2 instead.
- **V1 creates the original schema** — even if you later change it. V2 ALTERs it.
- **Use `create_if_not_exists`** and `add_if_not_exists` for idempotency.
- **Track the version via SQL comment** — `COMMENT ON TABLE {table} IS '{version}'`;
  "does the table exist" can't tell V0 from V1.
- **Everything takes a prefix** — see Prefix safety above.

### Schemas

```elixir
# In your schema
defmodule MyModule.Schemas.Item do
  use Ecto.Schema
  use PhoenixKit.SchemaPrefix   # right after `use Ecto.Schema` — see above

  import Ecto.Changeset

  # `UUIDv7` is the top-level module from the `uuidv7` package, pulled in by
  # phoenix_kit — no alias needed.
  @primary_key {:uuid, UUIDv7, autogenerate: true}
  @foreign_key_type UUIDv7

  schema "phoenix_kit_my_module_items" do
    field :name, :string
    field :status, :string, default: "active"

    belongs_to :user, PhoenixKit.Users.Auth.User,
      foreign_key: :user_uuid, references: :uuid, type: UUIDv7

    # Must match the type your migration used for `timestamps/1`.
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :status, :user_uuid])
    |> validate_required([:name])
    |> validate_inclusion(:status, ~w(active archived))
  end
end
```

### Foreign keys to phoenix_kit tables

These tables are part of the public schema contract and safe to reference:

| Table | Primary key | Notes |
|---|---|---|
| `phoenix_kit_users` | `uuid` (UUIDv7) | User accounts |
| `phoenix_kit_user_roles` | `uuid` (UUIDv7) | Role definitions |
| `phoenix_kit_settings` | `uuid` (UUIDv7) | Key/value settings |

Always reference the `uuid` column, not `id` (integer IDs are deprecated).

## Testing

Run tests with:

```bash
mix test
```

### Test levels

PhoenixKit modules have two distinct test levels:

- **Unit tests** — no database, test schemas/changesets/pure functions (`use ExUnit.Case, async: true`)
- **Integration tests** — need PostgreSQL, test context modules and data flow (`use MyModule.DataCase`)

Unit tests always run. Integration tests are automatically excluded when the database is unavailable.

### Unit tests (no database needed)

These verify your module implements the `PhoenixKit.Module` behaviour correctly. They work without any infrastructure:

```elixir
defmodule MyModuleTest do
  use ExUnit.Case, async: true

  # Behaviour compliance
  test "implements PhoenixKit.Module" do
    behaviours =
      MyModule.__info__(:attributes)
      |> Keyword.get_values(:behaviour)
      |> List.flatten()

    assert PhoenixKit.Module in behaviours
  end

  test "has @phoenix_kit_module attribute for auto-discovery" do
    attrs = MyModule.__info__(:attributes)
    assert Keyword.get(attrs, :phoenix_kit_module) == [true]
  end

  # Required callbacks
  test "module_key/0 returns expected key" do
    assert MyModule.module_key() == "my_module"
  end

  test "enabled?/0 returns false when DB unavailable" do
    # Will rescue since no DB is running in unit tests
    refute MyModule.enabled?()
  end

  # Permission metadata
  test "permission key matches module_key" do
    assert MyModule.permission_metadata().key == MyModule.module_key()
  end

  test "icon uses hero- prefix" do
    assert String.starts_with?(MyModule.permission_metadata().icon, "hero-")
  end

  # Tab conventions
  test "tab IDs are namespaced" do
    for tab <- MyModule.admin_tabs() do
      assert tab.id |> to_string() |> String.starts_with?("admin_my_module")
    end
  end

  test "tab paths use hyphens not underscores" do
    for tab <- MyModule.admin_tabs() do
      refute String.contains?(tab.path, "_"),
        "Tab path #{tab.path} contains underscores — use hyphens"
    end
  end

  test "all tabs have permission matching module_key" do
    for tab <- MyModule.admin_tabs() do
      assert tab.permission == MyModule.module_key()
    end
  end

  test "main tab has live_view for route generation" do
    [tab | _] = MyModule.admin_tabs()
    assert {_module, _action} = tab.live_view
  end

  test "all subtabs reference parent" do
    [main | subtabs] = MyModule.admin_tabs()
    for tab <- subtabs do
      assert tab.parent == main.id
    end
  end
end
```

For modules with Ecto schemas, you can test changesets without a database:

```elixir
test "changeset validates required fields" do
  changeset = MySchema.changeset(%MySchema{}, %{})
  refute changeset.valid?
  assert "can't be blank" in errors_on(changeset).name
end
```

### Integration test infrastructure

If your module uses the database, you need test infrastructure. Here's the complete setup:

#### 1. Update `mix.exs`

```elixir
def project do
  [
    # ... existing config ...
    elixirc_paths: elixirc_paths(Mix.env()),
  ]
end

defp elixirc_paths(:test), do: ["lib", "test/support"]
defp elixirc_paths(_), do: ["lib"]

defp aliases do
  [
    # ... existing aliases ...
    "test.setup": ["ecto.create --quiet", "ecto.migrate --quiet"],
    "test.reset": ["ecto.drop --quiet", "test.setup"]
  ]
end
```

#### 2. Create `config/config.exs` and `config/test.exs`

```elixir
# config/config.exs
import Config

if config_env() == :test do
  import_config "test.exs"
end
```

```elixir
# config/test.exs
import Config

# Your module's own test repo
config :my_module, ecto_repos: [MyModule.Test.Repo]

config :my_module, MyModule.Test.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  database: "my_module_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Wire repo for PhoenixKit.RepoHelper — without this, all DB calls crash
config :phoenix_kit, repo: MyModule.Test.Repo

config :logger, level: :warning
```

#### 3. Create test support modules

```elixir
# test/support/test_repo.ex
defmodule MyModule.Test.Repo do
  use Ecto.Repo,
    otp_app: :my_module,
    adapter: Ecto.Adapters.Postgres
end
```

```elixir
# test/support/data_case.ex
defmodule MyModule.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :integration

      alias MyModule.Test.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
    end
  end

  alias Ecto.Adapters.SQL.Sandbox
  alias MyModule.Test.Repo, as: TestRepo

  setup tags do
    pid = Sandbox.start_owner!(TestRepo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
    :ok
  end
end
```

#### 4. Create `test/test_helper.exs`

```elixir
alias MyModule.Test.Repo, as: TestRepo

db_config = Application.get_env(:my_module, TestRepo, [])
db_name = db_config[:database] || "my_module_test"

# One classified connection attempt, with the repo's OWN credentials and
# transport, before anything starts the pool. Core ships the preflight.
#
# Do not probe with `psql -l` instead: it runs as the shell's user over a unix
# socket, so it says "the database is there" and nothing about whether the
# CONFIGURED role can reach it over TCP — and when it cannot, the answer
# arrives minutes later as a pool checkout timeout that reads like a flaky test.
db_check =
  case PhoenixKit.TestSupport.PostgresPreflight.check(db_config) do
    :ok ->
      :exists

    {:error, _reason, message} ->
      IO.puts(:stderr, "\n" <> message)
      :not_found
  end

repo_available =
  if db_check == :not_found do
    IO.puts("\n  Cannot reach test database \"#{db_name}\" — integration tests excluded.\n  The reason is printed above.\n")
    false
  else
    try do
      {:ok, _} = TestRepo.start_link()

      # Build the schema with real migrations — never hand-rolled DDL, which
      # drifts from what hosts actually run. Core's chain first (it brings
      # phoenix_kit_settings, phoenix_kit_activities, uuid_generate_v7(), ...):
      PhoenixKit.Migration.ensure_current(TestRepo, log: false)

      # Then your module's own coordinator, through its migration wrapper.
      # See "Testing your migration" above for MigrationRunner.
      Ecto.Migrator.up(
        TestRepo,
        :os.system_time(:microsecond),
        MyModule.Test.MigrationRunner,
        log: false
      )

      Ecto.Adapters.SQL.Sandbox.mode(TestRepo, :manual)
      true
    rescue
      e ->
        IO.puts("\n  Could not connect to test database — integration tests excluded.\n  Error: #{Exception.message(e)}\n")
        false
    catch
      :exit, reason ->
        IO.puts("\n  Could not connect to test database — integration tests excluded.\n  Error: #{inspect(reason)}\n")
        false
    end
  end

# Start minimal PhoenixKit services needed for tests
{:ok, _} = PhoenixKit.PubSub.Manager.start_link([])
{:ok, _} = PhoenixKit.ModuleRegistry.start_link([])

exclude = if repo_available, do: [], else: [:integration]
ExUnit.start(exclude: exclude)
```

#### 5. Create the database

```bash
createdb my_module_test
mix test
```

Integration tests are tagged `:integration` via the `DataCase` and automatically excluded when the database doesn't exist.

### Gotchas

These are common issues you'll hit when setting up tests for PhoenixKit modules:

**Use string keys for context module attrs.** PhoenixKit context modules (like `Connections.create_connection/1`) may inject string keys internally. If you pass atom keys, you'll get `Ecto.CastError: mixed keys`. Always use string keys:

```elixir
# Bad — will crash with mixed key error
Connections.create_connection(%{name: "Test", direction: "sender", site_url: "https://example.com"})

# Good
Connections.create_connection(%{"name" => "Test", "direction" => "sender", "site_url" => "https://example.com"})
```

**Use `UUIDv7.generate()` for foreign key fields.** Fields like `approved_by_uuid` reference the `phoenix_kit_users` table. Passing a plain string like `"admin"` causes `Ecto.ChangeError: does not match type UUIDv7`:

```elixir
# Bad
Connections.approve_connection(conn, "admin")

# Good
Connections.approve_connection(conn, UUIDv7.generate())
```

**Ecto schema types vs migration types.** Migrations use `:bigint` and `:text`, but Ecto schemas must use `:integer` and `:string` — Ecto doesn't have `:bigint` or `:text` as schema field types. The distinction only matters at the database level.

**`enabled?/0` hits the database.** Calling `enabled?/0` or `get_config/0` in unit tests triggers a DB call through `PhoenixKit.Settings`, which fails with a sandbox ownership error. Either tag those tests as `:integration` or just test `function_exported?/3`:

```elixir
# In unit tests (no DB) — test the export, not the call
test "get_config/0 is exported" do
  assert function_exported?(MyModule, :get_config, 0)
end
```

**Run your migrations via `Ecto.Migrator`.** You can't call `MyModule.Migrations.up()` directly — it uses `Ecto.Migration` macros that require a migrator process. Wrap it (see "Testing your migration") and run the wrapper:

```elixir
# In test_helper.exs
Ecto.Migrator.up(TestRepo, :os.system_time(:microsecond), MyModule.Test.MigrationRunner, log: false)
```

Don't pass a fixed version like `0`: once `0` is in `schema_migrations` the wrapper is never invoked again, so the versions you ship later silently stop applying to your test database.

**ETS-based stores use hardcoded table names.** If your module has a GenServer with ETS (like a session store), the table name is global. Tests that start their own instance will conflict. Use `setup_all` with `already_started` handling:

```elixir
setup_all do
  case MyStore.start_link([]) do
    {:ok, _pid} -> :ok
    {:error, {:already_started, _pid}} -> :ok
  end
  :ok
end
```

**`uuid_generate_v7()` has to exist before your table uses it as a default.** Core's V40 migration creates it, so `PhoenixKit.Migration.ensure_current/2` in `test_helper.exs` covers the test database. In a host you can't assume core's chain ran first — at the top of your `up_v1/1` call `PhoenixKit.Migrations.Postgres.Helpers.ensure_extension!("pgcrypto")` **and then** `Helpers.ensure_uuid_v7_function(prefix)`. Both are no-ops when already present. The first is not optional: `uuid_generate_v7()` is built on pgcrypto's `gen_random_bytes`, and `ensure_uuid_v7_function/1` installs no extensions — skip it and the function is created fine and then fails on the first insert.

## Verifying your module

After adding your module to the parent app and starting the server, check:

**Full-featured modules:**

1. **Admin > Modules page** — your module should appear with its name, icon, and toggle
2. **Admin sidebar** — your tab should appear under the Modules group (if enabled)
3. **Admin > Roles** — your permission key should appear in the permissions matrix
4. **Click the tab** — your LiveView should render inside the admin layout

**Headless modules:**

1. **Admin > Modules page** — your module should appear with its name, icon, and toggle
2. **Admin > Roles** — your permission key should appear (if you defined `permission_metadata/0`)
3. **No sidebar entry** — expected, since there are no tabs
4. **Call your functions** — verify your API works from `iex -S mix` or from another module

The Admin role automatically gets access to new modules. Custom roles need the permission granted by an Owner or Admin.

## Tailwind CSS scanning for modules

When your module has templates with Tailwind CSS classes (inline `~H` sigils or `.heex` files), the parent app's Tailwind build needs to know where to scan for those classes. Without this, Tailwind will purge your module's CSS classes and your UI will break (elements hidden, styles missing).

### How it works

PhoenixKit's installer (`mix phoenix_kit.install`) automatically discovers plugin modules and adds `@source` directives to the parent app's `assets/css/app.css`. Each module declares which OTP app to scan via the `css_sources/0` callback.

### Adding CSS source scanning to your module

If your module uses Tailwind classes in its templates, implement `css_sources/0`:

```elixir
@impl PhoenixKit.Module
def css_sources, do: [:my_phoenix_kit_module]
```

The return value is a list of OTP app name atoms. The installer resolves the correct file path automatically:

- **Hex deps** → scans `deps/my_phoenix_kit_module/`
- **Path deps** → scans the declared path from `mix.exs` (e.g. `../my_phoenix_kit_module`)

After adding a new module with CSS sources, the user runs `mix phoenix_kit.install` and the installer adds the `@source` line to their `app.css`. This is idempotent — safe to run multiple times.

### When you DON'T need this

- **Headless modules** (no templates, no UI) — skip the callback, the default `[]` is fine
- **Modules using only PhoenixKit's built-in components** — if all your Tailwind classes already exist in `phoenix_kit` or daisyUI, they're already scanned
- **Modules with no custom Tailwind classes** — if you only use classes that are already present in `phoenix_kit`'s templates

### When you DO need this

- Your module has `~H` sigils or `.heex` templates with Tailwind responsive classes (`sm:block`, `md:grid-cols-2`, etc.)
- You use Tailwind utility classes in module attributes or string literals that get rendered as HTML
- You have custom CSS class combinations not used anywhere in `phoenix_kit`

### Example: what the installer generates

For a path dep (`path: "../phoenix_kit_publishing"`):
```css
@source "../../../phoenix_kit_publishing";
```

For a Hex dep:
```css
@source "../../deps/phoenix_kit_publishing";
```

### Troubleshooting CSS issues

If elements are invisible or styles are missing after extracting a module:

1. Check that `css_sources/0` is implemented and returns your app name
2. Run `mix phoenix_kit.install` in the parent app
3. Verify the `@source` line was added to `assets/css/app.css`
4. Restart the Phoenix server (Tailwind watches for file changes, but the source config is read on startup)

## Troubleshooting

### Sidebar disappears / socket crashes when clicking into my admin page

**Symptoms:**

- The admin layout (sidebar, header) is missing on your custom admin page, but shows up on other PhoenixKit admin pages
- Navigating from another admin page logs `navigate event failed because you are redirecting across live_sessions. A full page reload will be performed instead` and the WebSocket reconnects

**Cause:** You hand-registered a `live` route for a plugin LiveView in your parent app's `router.ex`. That route ends up in a different (or unnamed) `live_session` than PhoenixKit's `:phoenix_kit_admin`. Two things break:

1. The admin layout is applied by the `:phoenix_kit_ensure_admin` on_mount hook, which only runs inside `live_session :phoenix_kit_admin`. Your route never hits it.
2. Phoenix LiveView forbids `push_navigate` across `live_session` boundaries — the socket is torn down and a full page reload runs instead.

**Fix:** Remove the hand-written route and register your page through PhoenixKit's tab system so the route is injected into `:phoenix_kit_admin` automatically.

- If your page is part of a plugin module (like `phoenix_kit_entities` or `phoenix_kit_publishing`), its routes are **already** auto-discovered — just delete your manual routes and rely on `phoenix_kit_routes()` in `router.ex`.
- If your page is in your parent app, register it via `config :phoenix_kit, :admin_dashboard_tabs, [...]` with a `live_view: {MyAppWeb.SomeLive, :action}` field. See the [Custom Admin Pages guide](../phoenix_kit/guides/custom-admin-pages.md) (`phoenix_kit/guides/custom-admin-pages.md` in the monorepo).

**Do not** try to work around this by creating your own `live_session :phoenix_kit_admin` block — Phoenix raises at compile time on duplicate live_session names. There is exactly one, and PhoenixKit owns it.

**Do not** put `:phoenix_kit_ensure_admin` in a `pipe_through` list — it is an `on_mount` hook, not a Plug, and has no effect as a pipeline step.

### Module doesn't show up in the admin sidebar

1. **Check the dep is installed** — run `mix deps.get` and verify no errors
2. **Check it compiles** — run `mix compile` and look for errors in your module
3. **Check `@phoenix_kit_module` attribute** — `use PhoenixKit.Module` sets this automatically. If you're not using the macro, you need `@phoenix_kit_module true` in your module
4. **Check `admin_tabs/0`** — returns a list of `%Tab{}` structs? Has `:live_view` field set?
5. **Check the module is enabled** — go to Admin > Modules and toggle it on
6. **Recompile the parent** — routes are generated at compile time: `mix deps.compile phoenix_kit --force`

### Tab shows but clicking gives a 404

1. **Check `:live_view` field** — must be `{MyModule.Web.SomeLive, :action}` with a real module
2. **Check the LiveView compiles** — typo in the module name?
3. **Check `:path` uses hyphens** — `"my-module"` not `"my_module"`
4. **Restart the server** — routes are compiled at startup, not hot-reloaded
5. **Check path parameters** — `:uuid` in the path must match params handled in `handle_params/3`

### Permission denied (302 redirect)

1. **Check `:permission` on your tab** — should match `module_key()`
2. **Check `permission_metadata/0`** — the `key` field must match `module_key()`
3. **Check the role has permission** — Admin gets it automatically, custom roles need it granted
4. **Check module is enabled** — disabled modules deny access to non-system roles

### `enabled?/0` crashes on startup

Your `enabled?/0` runs before migrations have created the settings table. Always wrap it:

```elixir
def enabled? do
  Settings.get_boolean_setting("my_module_enabled", false)
rescue
  _ -> false
end
```

### Settings not persisting

Make sure you're using `update_boolean_setting_with_module/3` (not `update_setting/2`) for the enable/disable toggle. The `_with_module` variant ties the setting to your module key for proper cleanup.

### JS hooks not registering

1. **Check how the hook is delivered** — a hook registered by an inline `<script>` in `render/1` only exists after a full page load, never after `navigate/2`. Use a core hook, or ship a bundle declared by `js_sources/0` ([JavaScript in modules](#javascript-in-modules))
2. **Check `window.PhoenixKitHooks`** — open the browser console and look for your hook's (namespaced) name. Absent: the host has not recompiled since the bundle was added, the published package is missing `priv`, or the bundle assigns a different global than `js_sources/0` declares
3. **Check for a name collision** — a hook that exists but behaves like something else was overwritten by another bundle exporting the same hook name
4. **Check the element has `phx-hook`** — must match the hook name exactly
5. **Check the element has a unique `id`** — required for hooks to work

### Changes not taking effect

Stale compiled `.beam` files can persist old module versions. When changes aren't showing up:

1. **Force recompile your dep** — `mix deps.compile my_module --force` from the parent app
2. **Full clean rebuild** — `mix deps.clean my_module && mix deps.get && mix deps.compile my_module --force`
3. **Restart the server** — the dev reloader doesn't watch deps for changes
4. **Recompile the parent too** — `mix compile --force` (needed when routes or callbacks change)

This is especially common when debugging route registration, CSS scanning, or callback changes.

### Translations not showing

1. **Check the string is extracted** — only the macro form with a literal msgid (`gettext("…")`) reaches `default.pot`. A runtime `Gettext.gettext(Backend, msgid)` call, or a label stored as data, is in no catalogue unless a `gettext_noop/1` pins it
2. **Check which backend is in effect** — after `use PhoenixKitWeb, :live_view` the macros point at core's backend until your own `use Gettext, backend: MyModule.Gettext` follows it
3. **Check the `.po` entry** — an empty `msgstr` and a `#, fuzzy` entry both render the English msgid
4. **Check the package** — `priv` must be in `files:`, and the host recompiles the dep to pick up changed `.po` files

## Publishing to Hex

When your module is ready to share:

1. Add hex metadata to `mix.exs`:

```elixir
def project do
  [
    app: :my_phoenix_kit_module,
    version: "1.0.0",
    description: "A PhoenixKit plugin that does X",
    package: package(),
    deps: deps()
  ]
end

defp package do
  [
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/you/my_phoenix_kit_module"},
    # `priv` carries the Gettext catalogue and any JS bundle — without it the
    # published package has neither.
    files: ~w(lib priv .formatter.exs mix.exs README.md CHANGELOG.md LICENSE)
  ]
end
```

2. Make sure the phoenix_kit dep is the Hex requirement, in the compound form, and not a `path:`:

```elixir
{:phoenix_kit, ">= 2.38.0 and < 3.0.0"}  # not path: "../phoenix_kit"
```

This template never writes a `path:` tuple at all: `pk_dep/3` in its `mix.exs`
swaps the Hex pin for a local checkout only while an environment variable is
exported (`PHOENIX_KIT_PATH=../phoenix_kit mix test`), so there is nothing to
switch back before publishing, and `test/core_pin_conformance_test.exs` fails
the build on a committed `path:` or a narrowed pin.

3. Publish:

```bash
mix hex.publish
```

Users install with:

```elixir
{:my_phoenix_kit_module, "~> 1.0"}
```

No config needed — auto-discovery handles the rest.

## Important rules

1. **`module_key/0`** must be unique across all modules
2. **`permission_metadata().key`** must match `module_key/0`
3. **Tab `:id`** must be unique across all modules (prefix with `:admin_yourmodule`)
4. **Tab `:path`** — use relative slugs with **hyphens** (e.g., `"my-module"`). Core prepends `/admin/` or `/admin/settings/` based on context. Use absolute paths (starting with `/`) only for special cases.
5. **Tab `:permission`** should match `module_key/0` so custom roles get proper access
6. **`enabled?/0`** should rescue and return `false` — it's called before migrations run
7. **Settings keys** must be namespaced (e.g., `"my_module_enabled"`, not `"enabled"`)
8. **`get_config/0`** is called on every Modules page render — keep it fast
9. **Paths** must go through `Routes.path/1` — never use relative paths in templates
10. **JS hooks** come from core, or ship as a prebuilt bundle declared by `js_sources/0` with namespaced hook names — never from an inline `<script>`
11. **User-facing strings** go through your own Gettext backend in the macro form, and every shipped locale's `.po` is filled in the same change
12. **The `phoenix_kit` pin** is the compound form (`>= x.y.z and < 3.0.0`), with the floor at the oldest core that has everything you call

## License

MIT

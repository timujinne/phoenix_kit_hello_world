# AGENTS.md

Guidance for AI agents working on `phoenix_kit_hello_world`.

## Overview

The PhoenixKit plugin-module template and showcase: a working example of the `PhoenixKit.Module` behaviour that a parent Phoenix app auto-discovers, kept deliberately minimal so it can be copied as the starting point for a real module. It ships four admin pages that demonstrate the most common patterns — **Overview** (module info plus a "Log demo event" button showing the canonical activity-logging pattern), **Events** (infinite-scroll activity feed filtered to `module: "hello_world"`), **Notifications** (sending, customizing and managing notifications), and **Components** (live showcase of core components with copy-paste snippets) — plus a reference dashboard widget and a reference project extension.

- **Depends on:** `phoenix_kit` `~> 2.0` (Hex) and `phoenix_live_view` `~> 1.1`. No sibling `phoenix_kit_*` deps. `rustler` is pulled as an optional dep so MDEx's Rust NIF can build from source on OTP versions that ship no compatible precompiled NIF (the same escape hatch core carries).
- **Consumed by:** nothing. It is the copy-from reference; other modules copy its shapes rather than depend on it.
- **Admin surface:** parent tab `/admin/hello-world` plus four subtabs — Overview (same path), Events (`/events`), Components (`/components`), Notifications (`/notifications`). All in the `:admin_modules` sidebar group at priorities 640–644.
- **Module key** `"hello_world"`; settings prefix `hello_world_` (one key today: `hello_world_enabled`).

## What this module does NOT do

Its job is to demonstrate the minimum viable shape of a PhoenixKit module. It deliberately omits things larger modules need, so copies start lean:

- **No context module.** There is no `PhoenixKitHelloWorld.HelloWorld` business-logic context — the module is pure presentation, and the only "operation" is logging a demo activity event from `HelloLive`. Larger modules (locations, catalogue) add one.
- **No Errors dispatcher.** Nothing returns `{:error, :something}`, so there is no atom-to-gettext `Errors` module. When a real module needs one, `phoenix_kit_locations`' `lib/phoenix_kit_locations/errors.ex` is the reference.
- **No Ecto schemas.** No DB-backed data of its own. The copyable all-comments schema template (UUIDv7 PK, `use PhoenixKit.SchemaPrefix`, naming and timestamp conventions) is `lib/phoenix_kit_hello_world/schemas/example_item.ex`, guarded by `test/schema_prefix_conformance_test.exs` — copy both when adding a first schema.
- **No migrations.** A template has no business creating a table in every host that installs it, so `migration_module/0` stays at its `nil` default. See "Database & migrations".
- **No JS hooks.** `js_sources/0` is unimplemented (default `[]`); every interactive page uses a core hook. See the JS bullet under Conventions before adding one.
- **No `actor_opts/1` keyword-list helper.** `HelloLive` uses the simpler `actor_uuid/1`, which returns the UUID directly, because `Activity.log/1` takes a map. The `actor_opts/1` form returning `[actor_uuid: uuid]` belongs in modules that thread it through context functions accepting `opts \\ []`.

Extending the template into a real module usually adds, in this order: context module → schemas (plus the migration coordinator that creates their tables) → `Errors` dispatcher → `actor_opts/1` helper. `phoenix_kit_locations` is the smallest end-to-end reference of all four.

## Commands

```bash
mix deps.get
createdb phoenix_kit_hello_world_test          # once; DB-backed tests are tagged :integration and auto-skip without it
mix test
mix precommit                # compile --warnings-as-errors + format + credo --strict + dialyzer; run before every commit
```

`phoenix_kit*` deps resolve from Hex. To run against a local checkout, export
`<APP>_PATH` (the dep's app name upper-cased plus `_PATH`); `pk_dep/3` in
`mix.exs` swaps the Hex pin for a `path:` dep at resolve time. Unset means the
Hex pin, so `mix hex.publish` is unaffected. Run `mix deps.get` with the var
exported before the first `mix test` (a stale lock aborts on the optional
`igniter` dep), and never commit a hand-edited `path:` tuple.

```bash
PHOENIX_KIT_PATH=../phoenix_kit mix deps.get && PHOENIX_KIT_PATH=../phoenix_kit mix test
```

`mix test.setup` (`ecto.create`) and `mix test.reset` (`ecto.drop` + create) wrap the test database; `test_helper.exs` builds the schema on every boot.

Repo-local aliases:

- `mix quality` — `format` + `credo --strict` + `dialyzer` (applies formatting).
- `mix quality.ci` — `format --check-formatted` + `credo --strict` + `dialyzer`: it CHECKS formatting rather than applying it, so run `mix format` first.

## Conventions

- **Module key** is lowercase with underscores (`"hello_world"`) and identical in `module_key/0`, `permission_metadata/0`'s `:key`, each tab's `:permission`, and the settings prefix. Core validates the permission key against `module_key/0` at startup.
- **Tab ids** are atoms prefixed `:admin_` and unique across every installed module (`:admin_hello_world`, `:admin_hello_world_events`, …). **URL path segments use hyphens, never underscores** (`hello-world`), and a test asserts it.
- **Never hardcode a path.** Every `href`, `navigate`, `patch` and `redirect` goes through `PhoenixKitHelloWorld.Paths`, which wraps `PhoenixKit.Utils.Routes.path/1` so the host's URL prefix and locale segment are applied. A relative path resolves differently depending on the current URL and breaks silently.
- **Routing** is `live_view:` on each tab (this module) or a `route_module/0` declaring `admin_routes/0` + `admin_locale_routes/0`; the two coexist, but never register the same path both ways. Never hand-register a plugin LiveView route in the host app's `router.ex`. See "Routing" below.
- **LiveView macro.** `hello_live.ex` and `components_live.ex` use `use PhoenixKitWeb, :live_view`, which imports core components, Gettext, layout config and HTML helpers — the recommended default. `events_live.ex`, `notifications_live.ex` and `project_hello_tab_live.ex` use `use Phoenix.LiveView` directly (as locations, sync, catalogue and newsletters do) and therefore `import` each core component explicitly. The rule is the same either way: reach for the core component, not raw HTML; only the import mechanics differ. Admin LiveViews never wrap their template in `LayoutWrapper` — core applies the admin layout inside `live_session :phoenix_kit_admin`.
- **Gettext** is core's backend: `Gettext.gettext(PhoenixKitWeb.Gettext, "…")`. This module ships no `priv/gettext` and no backend of its own; user-facing strings (including `page_title`, `page_subtitle`, flashes, button labels and empty-state copy) are wrapped, while code samples inside `<pre>` blocks are not.
- **JS hooks ship as a prebuilt bundle declared by `js_sources/0`**, never registered from an inline `<script>`. Prefer a core hook first — core's hooks are in the host's `LiveSocket` at construction, so they work however the page is reached (`<.load_more infinite>`/`InfiniteScroll` is the one this module uses). When core has none, ship your own `priv/static/assets/<app>.js` and return `[%{app: :your_app, file: "static/assets/your_app.js", global: "YourAppHooks"}]` from `js_sources/0`; the `:phoenix_kit_js_sources` compiler folds the global into `window.PhoenixKitHooks`. The `:global` must be unique (the compiler fails on a collision) and hook names inside the bundle must be namespaced, because the final fold is last-write-wins on hook names and would silently override a core hook. An inline `<script>` in `render/1` is the broken pattern: morphdom does not execute inserted script tags, so the hook binds to nothing after `navigate/2` with no error.
- **`enabled?/0` must never raise.** It reads a DB-backed setting, so it `rescue`s any exception *and* catches `:exit` (pool checkout can exit around startup or after a test sandbox owner stops), returning `false` from every branch so callers need no startup-ordering special cases.
- **Activity logging** uses the canonical pattern below — guarded, rescued, actor threaded from the socket. Never put PII in `metadata`; it is a queryable audit trail, so pass uuids and short machine-readable keys.
- **`css_sources/0` returns the OTP app atom list** (`[:phoenix_kit_hello_world]`) for any module whose templates carry Tailwind classes. Discovery is automatic at compile time: the `:phoenix_kit_css_sources` compiler scans discovered modules and writes `assets/css/_phoenix_kit_sources.css`, which the host's `app.css` imports.
- **Keep the core pin two-segment** (`~> 2.0`). A three-segment `~> 2.0.x` expands to `< 2.1.0` and makes `mix deps.get` unsolvable for any host running a newer core minor — breakage that lands only on consumers. `test/core_pin_conformance_test.exs` fails the build on a narrowed pin and on a committed `path:` dep.
- **No soft-delete sentinel** — the module owns no records.

### Landmines

- **A plugin route hand-written in the host router** loses the admin layout and crashes navigation with "navigate event failed because you are redirecting across live_sessions". Fix: `live_view:` on a tab, or a route module. Redeclaring `live_session :phoenix_kit_admin` in the host router does not work either (Phoenix raises on duplicate names), and `:phoenix_kit_ensure_admin` is an `on_mount` hook, not a Plug, so putting it in `pipe_through` silently does nothing.
- **Building the test schema with `Ecto.Migrator.run(TestRepo, [{0, PhoenixKit.Migration}], :up, all: true)`** goes stale in silence: once `0` sits in `schema_migrations` the inner runner never re-runs, so newly shipped core versions stop applying and tests fail against a schema nobody notices is old. Fix: `PhoenixKit.Migration.ensure_current/2`, which `test_helper.exs` already calls.
- **Integration tests hang and fail as pool timeouts that look like flakes** when the Postgres role does not exist. `config/test.exs` defaults `PGUSER` to `postgres`; on an install whose superuser role is your login name, export `PGUSER=<role>` (and `PGDATABASE`/`PGPOOL` for a shared instance).
- **Flash assertions after a click event return nothing** unless the test layout renders flashes. `PhoenixKitHelloWorld.Test.Layouts.app/1` renders them deliberately — do not simplify it away.
- **`ProjectHelloTabLive` must stay off-router-mountable**: the projects hub renders it via `live_render`, so adding a `handle_params/3` breaks the embed. `test/phoenix_kit_hello_world/project_extension_test.exs` pins this.

### Routing

Two patterns, both compiled into core's `live_session :phoenix_kit_admin`:

**Tabs with `live_view:`** (what this module uses). Each tab in `admin_tabs/0` carries its own `live_view: {Module, :action}` and core generates one route per tab. Dynamic path segments are fully supported — the `path` string is spliced verbatim into the generated `live` route, so `path: "hello-world/:id/edit"` works. CRUD sub-pages that should not appear in the sidebar are extra tabs with `visible: false` and `parent:` set:

```elixir
%Tab{
  id: :admin_hello_world_edit,
  label: "Edit Hello",
  path: "hello-world/:id/edit",
  parent: :admin_hello_world,
  visible: false,
  live_view: {PhoenixKitHelloWorld.Web.HelloFormLive, :edit}
}
```

`phoenix_kit_posts` and `phoenix_kit_catalogue` are real-world references for hidden tabs with dynamic segments.

**Route module.** Use `route_module/0` when tabs are not expressive enough: many `live` routes without enumerating each as a Tab, separate localized and non-localized variants with distinct `:as` aliases, or a mix of both (`phoenix_kit_ai` is the hybrid reference). To enable it here: uncomment the routes in `lib/phoenix_kit_hello_world/routes.ex`, uncomment `route_module/0` in the main module, keep or drop `live_view:` on tabs as needed, and define each admin route in **both** `admin_locale_routes/0` (localized, `:locale` prefix) and `admin_routes/0` (non-localized), giving every route a unique `:as` name (`_localized` suffix on the localized side).

Constraints that bite:

- **`admin_routes/0` and `admin_locale_routes/0` may contain only `live` declarations.** Their quoted blocks are spliced inside Phoenix's `live_session` block, and the macro rejects controllers (`get`, `post`, …), `forward`, nested `scope` and `pipe_through` at compile time. Controllers, API endpoints, WebSocket forwards and public catch-all pages go in `generate/1` or `public_routes/1`, which splice outside any `live_session` (`phoenix_kit_sync`'s routes module is the controller/`forward` reference).
- **Catch-all public routes** (`/:slug`, `/:group/*path`) go in `public_routes/1`, never `generate/1` — `generate/1` routes are placed early and would intercept `/admin/*`.

Discovery is automatic: `use PhoenixKit.Module` persists a `@phoenix_kit_module` marker in the `.beam`, core's `ModuleDiscovery` scans beam files of deps that depend on `:phoenix_kit`, calls `route_module/0`, and compiles admin and public routes into the host router through the `phoenix_kit_routes()` macro. The host router recompiles when module deps are added or removed (a `__mix_recompile__?/0` hash comparison).

### UI & Layout Conventions

- **No page-level width cap.** The page-root `<div>` gets spacing only (`flex flex-col px-4 py-6 gap-6`). No `container`, no page-level `max-w-*`. The admin layout owns page width — capping it again produces a narrow column floating in a wide shell. A `max-w-*` scoped to a single form card is fine; a page-root cap is not.
- **One header, from `page_title`.** Set `page_title` (and optionally `page_subtitle`) in `mount/3`; the admin layout renders them in the page header. Do **not** also render an in-body `<h1>`/`<h2>` for the page — that puts two titles on screen, usually with different wording. Card titles (`<h2 class="card-title">`) inside a card are not page headers and are fine.
- **Prefer core components over hand-rolled markup.** `<.table_default>` over a raw `<table>`, `<.pagination>` / `<.load_more>` over hand-built join buttons, `<.empty_state>` over a bespoke "nothing here" panel, and the core form primitives over raw inputs. `ComponentsLive` pairs each raw daisyUI section with its core counterpart after the divider so the difference is visible.
- **Wrap user-facing strings in gettext**, including `page_title`, `page_subtitle`, flash messages, button labels and empty-state copy. Code samples inside `<pre>` blocks are not user-facing copy; leave them alone.

### Core form primitives

`use PhoenixKitWeb, :live_view` auto-imports `<.input>`, `<.select>`, `<.textarea>`, `<.checkbox>` and `<.simple_form>` from `PhoenixKitWeb.Components.Core.{Input, Select, Textarea, Checkbox, SimpleForm}`. Use these in every form rather than raw HTML — they handle label wiring, error rendering via `phx-feedback-for`, and daisyUI styling (including daisyUI 5's `<label class="select">` wrapper). `ComponentsLive`'s `form_helpers_section/1` demonstrates the pattern end to end. LiveViews that `use Phoenix.LiveView` directly import what they need explicitly:

```elixir
import PhoenixKitWeb.Components.Core.EmptyState, only: [empty_state: 1]
import PhoenixKitWeb.Components.Core.Icon, only: [icon: 1]
import PhoenixKitWeb.Components.Core.Pagination, only: [load_more: 1]
import PhoenixKitWeb.Components.Core.Select, only: [select: 1]
```

### daisyUI version

PhoenixKit's UI targets **daisyUI 5**, minimum **5.6.0**. The minimum is asserted in core at `PhoenixKit.Install.DaisyUI.minimum_version/0`; `mix phoenix_kit.install`, `mix phoenix_kit.update` and `mix phoenix_kit.doctor` warn when the host's vendored `assets/vendor/daisyui.js` is older. daisyUI lives in the **host app**, not in PhoenixKit — core ships themes (`phoenix_kit_daisyui5.css`) only.

daisyUI 5 removed a number of v4 class names ([upgrade guide](https://daisyui.com/docs/upgrade/)). Do not use:

| Retired (v4) | Use instead |
|---|---|
| `btn-group` | `join` + `join-item` |
| `label-text` | plain text inside `<label class="label">` |
| `input-bordered`, `select-bordered`, `textarea-bordered`, `file-input-bordered` | nothing — these elements have a border by default in v5 |

daisyUI 5 also requires the wrapper `<label class="select">` pattern around a bare `<select>`; the core `<.select>` component already does this.

### Activity logging pattern

The canonical shape for external modules (`HelloLive.log_demo_event/1`):

```elixir
defp log_demo_event(socket) do
  if Code.ensure_loaded?(PhoenixKit.Activity) do
    PhoenixKit.Activity.log(%{
      action: "hello_world.demo_event",
      module: "hello_world",
      mode: "manual",
      actor_uuid: actor_uuid(socket),
      resource_type: "hello_world",
      metadata: %{"source" => "showcase_button"}
    })
  else
    :activity_unavailable
  end
rescue
  e ->
    Logger.warning("[HelloWorld] Activity logging error: #{Exception.message(e)}")
    {:error, e}
end

defp actor_uuid(socket) do
  case socket.assigns[:phoenix_kit_current_user] do
    %{uuid: uuid} -> uuid
    _ -> nil
  end
end
```

- **Guard with `Code.ensure_loaded?/1`** so the module works on hosts without activity logging.
- **Rescue every exception** — a logging failure must never crash the primary operation.
- **Thread the actor** from `socket.assigns[:phoenix_kit_current_user]`.
- **Action format** is `"resource.verb"` (`"hello_world.demo_event"`).
- **Mode** is `"manual"` for user-triggered and `"auto"` for system or background work.

## Architecture

A `PhoenixKit.Module` implementation, discovered from its `.beam` marker at host startup. It depends on the host PhoenixKit app for Repo, Endpoint and Settings; it has no supervision tree, no endpoint and no router of its own.

```
lib/phoenix_kit_hello_world.ex                    # PhoenixKit.Module implementation + widget/extension catalogs
lib/phoenix_kit_hello_world/
├── paths.ex                                      # Path helpers over PhoenixKit.Utils.Routes.path/1
├── routes.ex                                     # Route-module scaffold (commented out by default)
├── migrations.ex                                 # All-comments migration-coordinator template (compiles to nothing)
├── schemas/example_item.ex                       # All-comments schema template (compiles to nothing)
└── web/
    ├── hello_live.ex                             # Overview: module info + activity-logging demo
    ├── events_live.ex                            # Activity feed, infinite scroll
    ├── notifications_live.ex                     # Notification send / customize / manage tour
    ├── components_live.ex                        # Core-component showcase
    ├── hello_widget.ex                           # Reference dashboard widget (LiveComponent)
    └── project_hello_tab_live.ex                 # Reference project-extension tab
lib/mix/tasks/phoenix_kit_hello_world.audit_migrations.ex   # Read-only audit of installed coordinators
```

Key modules:

- **`PhoenixKitHelloWorld`** — the behaviour implementation. Required callbacks (`module_key/0`, `module_name/0`, `enabled?/0`, `enable_system/0`, `disable_system/0`) plus `version/0`, `permission_metadata/0`, `admin_tabs/0`, `css_sources/0`, `notification_types/0`, `resolve_comment_resources/1`, and the two duck-typed catalogs below. Registers five tabs: the parent plus four subtabs.
- **`PhoenixKitHelloWorld.Paths`** — `index/0`, `events/0`, `components/0`, `notifications/0`.
- **`Web.HelloLive`** — landing page; Scope API demonstration and the activity-logging button.
- **`Web.EventsLive`** — activity feed using core's `<.load_more infinite>` and `InfiniteScroll` hook (no page-local JS), action filtering via core's `<.select>`, and graceful degradation when `PhoenixKit.Activity` is absent. Near-identical to `phoenix_kit_catalogue`'s events tab; this is the universal pattern.
- **`Web.NotificationsLive`** — sends plain and custom-display notifications, reads unread counts, marks seen, dismisses, and subscribes to live updates via `PhoenixKit.Notifications.Events.subscribe/1`. Every core call is guarded with `Code.ensure_loaded?/1`.
- **`Web.ComponentsLive`** — showcase of core components with copy-paste snippets; `render/1` is a flat dispatch over per-section function components (see Feature notes).

**Data model:** none. No schemas, no tables, no PubSub topics of its own — it only subscribes to core's notification topic.

**Settings keys:** `hello_world_enabled` (boolean, written through `Settings.update_boolean_setting_with_module/3` so core records which module owns the key).

**Permissions:** one key, `"hello_world"`, declared by `permission_metadata/0` and carried as `:permission` on every tab; checked with `Scope.has_module_access?(scope, "hello_world")`. No sub-permissions.

**Assigns core injects into admin LiveViews:** `@phoenix_kit_current_scope`, `@phoenix_kit_current_user`, `@current_locale`, `@url_path`.

### Reference dashboard widget

`Web.HelloWidget` plus the `phoenix_kit_widgets/0` definition in the main module are the copy-from reference for contributing widgets to `phoenix_kit_dashboards`. The contract is **duck-typed and one-way**: a zero-arity function returning plain maps, no behaviour, no `@impl`, and no dependency on the dashboards package — its Registry finds the function at runtime. The single definition uses every field (key, name/description/icon, `module_key` gating, component, category, default/min sizes, `refresh_interval`, three `views` each with its own `min_size`, and a `settings_schema` exercising every field type including both select-option shapes). The component demonstrates the render side: the `settings` / `view` / `size` / `scope` assigns, live-refresh state that survives host ticks, scope-driven personalization, compact single-row rendering, and a `"contract"` debug view that prints the received assigns verbatim. **A widget must never crash the host dashboard** — read every assign defensively. `hello_widget_test.exs` is pure `render_component` with no DB, which is also why this widget skips the in-component `enabled?/0` guard that data-querying widgets need.

### Reference project extension

`phoenix_kit_project_extensions/0` plus `Web.ProjectHelloTabLive` are the copy-from reference for plugging a module into individual projects in the `phoenix_kit_projects` hub. Same duck-typed one-way shape as the widget catalog. The catalog entry exercises every contract field: `key`, `name`/`description`/`icon`, `module_key` gating, `tabs` (each `%{key, label, icon, lv}`), `config_schema` (writes are whitelisted to these keys), `feature_flags` (with `requires`), `permission_actions`, `notification_types`, `on_enable`/`on_disable` (`{module, function}` arity-2, best-effort — failures log and never abort), and `default_enabled` (kept `false` so a demo tab never appears unbidden).

The hub renders the tab LV with `live_render` and this session contract:

| Session key | Meaning |
|---|---|
| `project_uuid` | The project being viewed |
| `ext_key` | The extension entry's `key` |
| `config` | The per-project values collected by `config_schema` |
| `current_user_uuid` | Viewer identity (identity only — authorize separately) |
| `locale` | Gettext locale to set on mount, when present |

The tab LV mounts **off-router**, so it must not define `handle_params/3`.

## Database & migrations

**None of its own.** `migration_module/0` stays at its `nil` default: a demo module that creates a table in every host that installs it is exactly the wrong example. What the template ships instead is the copyable shape.

| File | Role |
|------|------|
| `lib/phoenix_kit_hello_world/migrations.ex` | All-comments coordinator template — `current_version/0`, `up/1`, `down/1`, `migrated_version_runtime/1`, per-version `up_vN/1` steps, `COMMENT ON TABLE` version tracking, test-wrapper notes. Compiles to nothing |
| `lib/phoenix_kit_hello_world/schemas/example_item.ex` | All-comments schema template for the table that coordinator would create |
| `README.md` → "Versioned migrations" | The same material as prose, with the V2 / prefix-safety / testing sections |
| `lib/mix/tasks/phoenix_kit_hello_world.audit_migrations.ex` | Runnable audit of every installed module's coordinator against the rules below. Read-only, exits non-zero on failure |

**A module owns the DDL for its own tables.** The migrations for a module's tables live in that module's repo and ship with that module's package, never as a new `Vxxx` appended to core `phoenix_kit`'s chain. Core's chain stays about core's tables; putting module tables there couples every module's schema to a core release and bloats the core package for hosts that never install the module. Some first-party tables still sit in core's chain — that is history, not the pattern to copy. Working live references for a module-owned chain: `phoenix_kit_web_analytics` (two tables with indexes) and `phoenix_kit_boards` (single table).

Registering one is a single callback:

```elixir
@impl PhoenixKit.Module
def migration_module, do: MyModule.Migrations
```

Schemas backed by a table use UUIDv7 primary keys named `uuid` and `use PhoenixKit.SchemaPrefix`, so queries follow a host installed into a named Postgres schema.

### How a host installs and upgrades it

`mix phoenix_kit.update`, run in the host app, scans beam files for registered modules, calls `migration_module/0` on each, compares `migrated_version_runtime(prefix: prefix)` against `current_version()`, and for each module that is behind writes a migration into the host's `priv/repo/migrations/` that calls back into the coordinator:

```elixir
def up, do: MyModule.Migrations.up(prefix: "public", version: 1)
def down, do: MyModule.Migrations.down(prefix: "public", version: 0)
```

then runs `mix ecto.migrate`. The host never hand-writes migration SQL for your module, needs no install task from you, and the generated migration honours the host's `--prefix`.

### Adopting a table core already creates (extraction)

Tables born in core — because the module once lived there, or the table predates the protocol — are extracted by **adoption**, in phases:

1. The module's V1 re-asserts core's exact shape idempotently and stamps a namespaced marker. No core change, no ordering hazard.
2. The first shape-changing version (V2+) requires core's manifest generator `@excluded_exact` plus regeneration **before** the module releases.
3. Creation itself leaves core only at the next baseline squash.

Never write a conditional "module absent → drop" migration: it is nondeterministic and destroys data when a host merely removes a package. The full protocol with rationale is the "Adopting a table core already creates" section of `lib/phoenix_kit_hello_world/migrations.ex`; the live reference is `phoenix_kit_legal`'s `PhoenixKit.Modules.Legal.Migrations` and the consent-logs extraction report in that repo's `dev_docs/reports/`.

### Rules

- **Version steps are immutable once shipped.** A host already at V1 never re-runs V1, so editing `up_v1/1` only forks fresh installs from upgraded ones. Add `up_v2/1` plus its `apply_step/3` clauses and bump `@current_version`.
- **The version lives in a `COMMENT ON TABLE`**, not in "does the table exist" — the latter cannot distinguish "not installed" from "installed at V1", so it reports the target version for every host and core skips the delta while printing a success line.
- **Read the marker with `Integer.parse/1`, never `String.to_integer/1`.** The slot may already hold prose (core gives `phoenix_kit_consent_logs` a description) and `String.to_integer/1` raises on it. A non-numeric comment on an existing table means V1.
- **A reader that cannot determine the version must not answer 0.** Zero means "not installed here" and sends the updater off to install a schema over live data. Re-raise `ArgumentError` (invalid prefix) the way core's reader does.
- **`down(version: N)` returns to N.** Only `version: 0` drops the table. Fix this in the same change as the version marker: while the marker is inferred no host is ever handed an upgrade migration, so an always-dropping `down/1` is unreachable — repairing the marker alone arms it.
- **Check that core's chain does not already create your table** (`grep -rn "<table>" deps/phoenix_kit/lib/phoenix_kit/migrations/postgres/`). Core's migrations run first, so if it does, your `up/1` is dead code and the two DDLs drift. Your first real version then has to *reconcile* both shapes, adopting one index-naming scheme rather than creating a parallel set.
- **Ship both readers** — `migrated_version/1` (migration context) and `migrated_version_runtime/1` (Mix-task context, the one core calls).
- **Export `version_table/0`** so `mix phoenix_kit_hello_world.audit_migrations` can verify the marker is numeric without hard-coding your table name.
- **Stay prefix-safe.** Pass `prefix:` to every table and index, keep index names bare on `CREATE INDEX` (Postgres rejects a qualified name there), and anchor existence checks to the target schema. Use `PhoenixKit.Migrations.Postgres.Helpers` (`qualify_table/2`, `uuid_v7_call/1`, `ensure_uuid_v7_function/1`, `validate_prefix!/1`) instead of hand-rolling those strings.
- **Table names are prefixed `phoenix_kit_<module_key>_`** so modules and the parent app cannot collide.
- **Do not assume core's chain ran first.** Call `Helpers.ensure_extension!/1` for `"pgcrypto"` *and* `Helpers.ensure_uuid_v7_function/1` before using `uuid_generate_v7()` as a column default. The function is built on pgcrypto's `gen_random_bytes` and `ensure_uuid_v7_function/1` installs no extensions, so skipping the first call creates a function that fails on the first insert.
- **Audit a live host before believing any of this works.** `mix phoenix_kit_hello_world.audit_migrations [--prefix auth]` checks every installed module's coordinator against these rules, read-only, and exits non-zero on failure. Every defect it looks for is silent when broken and invisible to a database-less test suite.
- **Test the coordinator.** `up/1` uses `Ecto.Migration` macros and cannot be called directly; wrap it in a static `use Ecto.Migration` module and run that through `Ecto.Migrator.up/4` in `test_helper.exs`, after `PhoenixKit.Migration.ensure_current/2`. Pass `:os.system_time(:microsecond)` as the version, never a fixed `0` — once `0` is in `schema_migrations` the wrapper is never invoked again and later versions silently stop applying.

## Testing

The suite owns its own database, `phoenix_kit_hello_world_test`. Unit tests always run; DB-backed tests carry the `:integration` tag and `test_helper.exs` excludes them automatically when Postgres is unreachable or the database is missing (it probes with `psql -lqt`, then tries a real connection).

`test_helper.exs` builds the schema by calling `PhoenixKit.Migration.ensure_current(Repo, log: false)` — core's versioned migrations, applied on every boot with a fresh version number on purpose, so schema drift is impossible by construction. It also starts `PhoenixKit.PubSub.Manager` and `PhoenixKit.ModuleRegistry`, forces core's URL-prefix cache to `"/"` via `:persistent_term` so `Paths.*` produce URLs the test router matches (admin paths always carry the default `en` locale prefix, so the router scope is `/en/admin/hello-world`), and starts the test Endpoint only when the DB is available. Support modules are loaded with explicit `Code.require_file/2` calls, because Elixir 1.19's `mix test` no longer auto-loads modules from the test `:elixirc_paths`.

`config/test.exs` wires `config :phoenix_kit, repo: PhoenixKitHelloWorld.Test.Repo`. Without that line every call through `PhoenixKit.RepoHelper` crashes with "No repository configured". It also honours `PGUSER`, `PGPASSWORD`, `PGHOST`, `PGDATABASE` (point the suite at a database the role may not `CREATE`), `PGPOOL` (bound the pool on a shared instance; the default is `schedulers_online() * 2`) and `MIX_TEST_PARTITION`.

Support modules:

| Module | Role |
|---|---|
| `Test.Repo` (`test/support/test_repo.ex`) | Ecto repo for tests |
| `DataCase` (`data_case.ex`) | Sandbox setup, auto-tags `:integration` |
| `LiveCase` (`live_case.ex`) | Thin wrapper over `Phoenix.LiveViewTest` with router and endpoint wiring; `put_test_scope/2` seeds the session scope |
| `Test.Hooks` (`hooks.ex`) | `on_mount :assign_scope` — replicates core's admin `live_session` by mirroring the session scope onto `:phoenix_kit_current_scope` / `:phoenix_kit_current_user` |
| `Test.Endpoint` / `Test.Router` / `Test.Layouts` | Minimal Phoenix plumbing so LiveViews render under `Phoenix.LiveViewTest.live/2`. `Test.Layouts.app/1` renders flashes, which flash assertions depend on |
| `ActivityLogAssertions` | `assert_activity_logged/2` and `refute_activity_logged/2`, querying `phoenix_kit_activities` directly with action / actor_uuid / metadata-subset matching |

Conformance tests worth knowing about: `test/phoenix_kit_hello_world_test.exs` (behaviour callbacks, tab shape, path helpers, `version/0` against `Mix.Project.config()[:version]`), `test/core_pin_conformance_test.exs` (the `:phoenix_kit` requirement), `test/schema_prefix_conformance_test.exs` (scans `lib/` and fails when a table-backed schema omits `use PhoenixKit.SchemaPrefix`), and `test/phoenix_kit_hello_world/project_extension_test.exs` (the extension catalog and the off-router tab LV).

```bash
mix test                                          # all tests (:integration excluded without a DB)
mix test test/phoenix_kit_hello_world_test.exs    # module behaviour only
mix test test/phoenix_kit_hello_world/web         # LiveView smoke tests only
for i in $(seq 1 10); do mix test; done           # stability check — catches sandbox / activity-log flakes
```

## Feature notes

| Feature | Constraint | Guide |
|---|---|---|
| Section decomposition in `ComponentsLive` | A section that reads LiveView state declares an `attr` for each value it reads; sections stay in the same module as `render/1`, and no section renders a page header (the admin layout owns it) | [`dev_docs/guides/section-decomposition.md`](dev_docs/guides/section-decomposition.md) |
| The `AGENTS.md` skeleton every module follows | Eleven headings in a fixed order, all present; Conventions before Architecture; rules and pointers here, paragraph-length feature narrative in `dev_docs/guides/`; no chronology; the Versioning and Pull-requests blocks byte-identical across repos | [`dev_docs/guides/agents-md-skeleton.md`](dev_docs/guides/agents-md-skeleton.md) |

Everything else is documented in `@moduledoc`s and in `README.md`, which is the long-form module-authoring guide this repo exists to carry.

## Versioning & releases

SemVer. The version is single-sourced in `mix.exs` (`@version`); `version/0`
reads it at compile time and the behaviour test asserts against
`Mix.Project.config()[:version]`, so nothing else needs bumping.

Release procedure (the steps the maintainer runs):

1. Bump `@version` in `mix.exs`; add a `CHANGELOG.md` entry headed `## x.y.z - YYYY-MM-DD`.
2. `mix precommit` clean.
3. Commit (`"Bump version to x.y.z"`) and push; verify the push landed.
4. `mix hex.publish`.
5. Tag, matching the form of the newest existing tag (`git tag --sort=-creatordate | head -1` shows it), and push the tag.
6. GitHub release via `gh release create` if the repo does those (`gh release list` shows whether it does).

Tags are immutable pointers: never tag before the commit is pushed and the
publish has succeeded.

## Pull requests & commits

- Commit messages start with an action verb (`Add`, `Update`, `Fix`, `Remove`, `Merge`). No AI attribution and no `Co-Authored-By` trailers.
- Version bumps and CHANGELOG entries land with the release commit on upstream, not in feature PRs.
- Review files live in `dev_docs/pull_requests/{year}/{pr_number}-{slug}/{AGENT}_REVIEW.md`, one file per reviewing agent, never edited by another agent; `FOLLOW_UP.md` records how each finding was resolved. Severities: `BUG - CRITICAL/HIGH/MEDIUM`, `IMPROVEMENT - HIGH/MEDIUM`, `NITPICK`.

## TODOs

- **`README.md`'s JS-hooks section still teaches inline `<script>` and compile-time base64 delivery.** The ecosystem rule is a prebuilt bundle declared by `js_sources/0`; the README needs rewriting onto it, and this template is what other modules copy. Trigger: the next README pass, or the first time this module ships a hook of its own.

## Unreleased

### Fixed

- `mix phoenix_kit_hello_world.audit_migrations` no longer fails coordinators
  that follow the documented namespaced marker convention for adopted tables
  (`pkl_schema:1`, `pkb_schema:4`, `pkp_schema:14`, ...). The check —
  previously "version marker is numeric", now "version marker is a version" —
  accepts both a bare number and a `<namespace>:<number>` marker.
- The `absent schema reports 0` check's own fixture prefix was 22 bytes,
  over core's `validate_prefix!/1` 20-byte ceiling, so a coordinator that
  correctly delegates prefix validation to core raised `ArgumentError` and
  the check reported a false failure. Shortened the fixture to 15 bytes.
- The `protocol` check always blamed `mix phoenix_kit.update` for a missing
  function, even when the only function missing was `migrated_version/1` —
  which `mix phoenix_kit.update` never calls directly (it is read by the
  coordinator's own `up/1` to re-read the version mid-migration). The
  message now names the accurate consequence for whichever function is
  actually missing.

## 0.2.2 - 2026-08-11

### Changed

- Dependency updates: `phoenix_kit` 2.2.0 and the transitive set it pulls
  (`phoenix` 1.8.10, `hackney` 4.7.3). No source changes in this package.

## 0.2.1 - 2026-08-11

### Added

- **The core-table adoption protocol** (#36) — the missing chapter of the
  migration template: how a module extracts a table that core already creates.
  Phase 0, the module's V1 adopts and changes nothing (shape-identical
  `CREATE TABLE IF NOT EXISTS` with core's exact object names plus a namespaced
  marker), so core's `ExpectedSchema` stays accurate and no core release is
  needed. Phase 1, the first shape change is when core moves. Phase 2, creation
  leaves core at the next baseline squash. Documented in all three of the
  repo's canonical places, with `phoenix_kit_legal` 0.4.0 as the live reference.

  Called out as forbidden: a conditional "module absent → drop the table"
  migration. It is nondeterministic against the manifest, the chain hash and the
  squash oracles, and it destroys data on a host that merely removed the package.

### Changed

- Carries core's rustler escape hatch (`{:rustler, ">= 0.0.0", optional: true}`)
  so MDEx's NIF builds from source on OTP versions shipping no compatible
  precompiled NIF.

## 0.2.0 - 2026-08-10

### Changed

- **⚠️ Requires `phoenix_kit ~> 2.0`.** The core pin moved to `~> 2.0`, so this
  release no longer resolves against core 1.7.

  Core 2.0.0 squashes the migration chain into a single `V135` baseline and makes
  V135 the chain's floor: `mix ecto.migrate` now *refuses* on a database below it
  rather than migrating. Check `mix phoenix_kit.status` **before** upgrading. A
  host below V135 must install `phoenix_kit 1.7.236` — the migration bridge, the
  last release carrying the full pre-squash chain — migrate until the reported
  version is at least V135, and only then move to 2.0.

  This package does not call migration internals, so the change is the pin
  itself.

### Added

- **`mix phoenix_kit_hello_world.audit_migrations` (PR #34)** — audits a module
  migration coordinator against the rules this template documents, on a live
  database.
- **Reference project-extension provider (PR #33)** —
  `phoenix_kit_project_extensions/0` plus `Web.ProjectHelloTabLive`, the
  canonical minimal implementation of the projects-hub extension contract, with
  a test pinning the contributed shape.

### Fixed

Three bugs in the migration-coordinator template every module was copied from
(PR #34). Each disguised itself as a healthy reading:

- **`String.to_integer/1` on the version comment raises** on a non-numeric
  comment, and the raise landed in a blanket `rescue _ -> 0` — so a populated
  table reported **"not installed"**. The comment slot is not always free: core
  V43 puts a prose description on `phoenix_kit_consent_logs`. Now
  `Integer.parse/1` with an `@initial_version` fallback.
- **`migrated_version_runtime/1` swallowed everything into `0`**, so an invalid
  `--prefix` read as a fresh install and the updater generated DDL against live
  data. Now re-raises `ArgumentError`, matching core.
- **`up_v1/1` ensured the uuid function but not pgcrypto**, so
  `uuid_generate_v7()` was created and then failed on the first insert.

Also on `main`, fixing gate failures in PR #34 itself: extracted a too-deeply
nested `case` out of the auditor's `check_version_marker/2` (credo --strict),
and added `:mix` to `plt_add_apps` — the auditor is this package's first Mix
task, and dialyzer could not resolve `Mix.shell/0` without it.

## 0.1.9 - 2026-08-02

Documents the current policy for module database tables: **a module ships the
migrations for its own tables.** They live in the module's repo and version
with its package — they are not added as a new `Vxxx` to core `phoenix_kit`'s
migration chain, which would couple every module's schema to a core release and
grow the core package for hosts that never install the module. AGENTS.md
previously stated the opposite; the README described the new pattern only in
prose, with snippets that could not compile.

hello_world itself still owns no tables — it is the template, and a demo module
has no business creating a table in every host that installs it. Nothing here
changes what a host's database looks like.

### Added
- `lib/phoenix_kit_hello_world/migrations.ex` — all-comments versioned
  migration coordinator template (compiles to nothing, same convention as
  `schemas/example_item.ex`). Covers the four functions `mix
  phoenix_kit.update` calls, `COMMENT ON TABLE` version tracking, immutable
  version steps, prefix safety, and how to test a coordinator.
- README "Versioned migrations" gained V2, prefix-safety, and
  testing-your-migration sections; AGENTS.md gained a rewritten "Database &
  Migrations" section stating the policy and pointing at the working live
  references (`phoenix_kit_boards`, `phoenix_kit_web_analytics`).

### Fixed
- README migration snippets called `PhoenixKit.Config.get_repo/0`, which does
  not exist — the runtime repo lookup is `PhoenixKit.RepoHelper.repo/0`.
- README schema example aliased `PhoenixKit.Schemas.UUIDv7` (also nonexistent;
  it is the top-level `UUIDv7` from the `uuidv7` package) and omitted
  `use PhoenixKit.SchemaPrefix`, contradicting the section directly above it.
- README test-helper template hand-rolled `uuid_generate_v7()` instead of
  letting core's chain create it, and suggested `Ecto.Migrator.up(repo, 0, ...)`
  — a fixed version `0` stops applying newly shipped migrations once it lands
  in `schema_migrations`.
- `schemas/example_item.ex` said migrations live "in core's versioned chain for
  first-party modules"; it now points at the module-owned coordinator template,
  and spells out that a schema's `timestamps/1` type must match its migration's
  or writes silently truncate.

## 0.1.8 - 2026-06-22

### Fixed
- Notifications tutorial: the displayed `notification_link` example used a raw
  `"/admin/hello-world"` path; it now uses `Paths.index()` with a note that
  notification links must go through `Routes.path/1` for URL prefix + locale.
  (The live demo code was already correct.)

## 0.1.7 - 2026-06-17

### Added
- **Notifications example page** (`Web.NotificationsLive`, new "Notifications" admin subtab) — a hands-on tour of the PhoenixKit notification system: send a notification by logging an activity with a `target_uuid`, customize its display via `notification_text`/`notification_icon`/`notification_link` metadata, and read/manage it (unread count, recent list, mark-seen, dismiss) with live PubSub updates. All core calls are guarded with `Code.ensure_loaded?/1`.
- **`notification_types/0` callback** on `PhoenixKitHelloWorld`, demonstrating how a module declares its notification types so users can mute them in preferences.

### Changed
- Synced the `version/0` callback with `mix.exs` (was stale at 0.1.5).

## 0.1.6 - 2026-05-05

### Changed
- Test schema is now built via `PhoenixKit.Migration.ensure_current/2` in `test_helper.exs` (requires `phoenix_kit ≥ 1.7.105`); removed hand-rolled `test/support/postgres/migrations/` and the `ecto.migrate` step from the `test.setup` alias — schema drift impossible by construction (#15)

## 0.1.5 - 2026-04-29

### Added
- LiveView test infrastructure: in-repo `Test.Endpoint` / `Test.Router` / `Test.Layouts`, `LiveCase` with fake `%Scope{}` plumbing via session, `ActivityLogAssertions` helper, `Hooks.on_mount/4`, and a dedicated test migration creating `phoenix_kit_settings`, `phoenix_kit_activities`, and `uuid_generate_v7()`
- 25 new tests across the three LiveViews (mount, gettext-wrap regressions, `handle_info/2` catch-all smokes, demo-event end-to-end with activity row assertion)
- `mix test.setup` / `mix test.reset` aliases and `lazy_html` test-only dep
- Defensive `handle_info/2` catch-all in all three LiveViews so a stray PubSub broadcast or OTP message can't crash the page with `FunctionClauseError`
- `phx-disable-with` on the "Log demo event" button to prevent double-logging on double-click
- AGENTS.md sections: "What This Module Does NOT Have", "Code Organization: Section-Decomposition Pattern", and full Testing infrastructure walk-through

### Changed
- Decompose `ComponentsLive` 742-line `render/1` into 22 per-section `defp x_section/1` function components for easier navigation; pinned by a section-count test
- Move `enabled?/0` resolution in `HelloLive` from render-time DB call to `handle_params/3` assign — was hitting `Settings.get_boolean_setting/2` four times per page (mount × render × 2 calls), now once per navigation
- Wrap user-facing strings in all three LiveViews with `Gettext.gettext(PhoenixKitWeb.Gettext, …)` (status badges, page headings, filter labels, dt labels in the Module Info / Current User cards, next-steps copy, detail-link `title`, "View details", "All events loaded", `phx-disable-with` text)
- Add `@spec` annotations to all public functions in `PhoenixKitHelloWorld.Paths`

### Fixed
- `enabled?/0` now also `catch :exit, _` — when a sandbox-using test exits and the next test calls `enabled?/0`, the connection-pool checkout `EXIT`s with `"owner #PID<...> exited"`, which `rescue` doesn't catch (was a 1-in-10 flake)
- `test_helper.exs` no longer crashes with `ErlangError :enoent` when `psql` isn't on `$PATH` — falls through to the connect probe so integration tests are gracefully excluded
- Replace tautological "detail-link title is gettext-wrapped" test with a source-grep that actually fails on revert

## 0.1.4 - 2026-04-11

### Fixed
- Correct routing guidance: dynamic path segments ARE supported via tabs
- Add sidebar/socket-crash troubleshooting to README
- Document hidden-tab pattern for CRUD sub-pages
- Clarify route module vs tab-based coexistence

## 0.1.3 - 2026-04-11

### Added
- Add Events subtab with infinite-scroll activity feed filtered to `module: "hello_world"` — universal pattern that works as a drop-in for any module
- Add Components subtab showcasing commonly-used PhoenixKit core components (icons, badges, buttons, alerts, stat cards, form inputs, modals, tables, pagination, empty states, loading states) with copy-paste snippets
- Add "Log demo event" button on Overview page demonstrating the canonical activity logging pattern with `Code.ensure_loaded?/1` guard and rescue handling
- Add `PhoenixKitHelloWorld.Paths` module for centralized path helpers

### Changed
- Restructure `admin_tabs/0` to include parent tab + three subtabs (Overview, Events, Components)
- Bump `phoenix_live_view` dep from `~> 1.0` to `~> 1.1` for consistency with other PhoenixKit modules
- Update `HelloLive` with navigation to the new subtabs and activity logging demo
- Update AGENTS.md with activity logging pattern documentation and expanded file layout

## 0.1.2 - 2026-04-05

### Added
- Add `required_integrations/0` and `integration_providers/0` callbacks to template
- Add tests for new integration callbacks

## 0.1.1 - 2026-04-04

### Fixed
- Fix auto-discovery by adding `phoenix_kit` to `extra_applications`

### Changed
- Update AGENTS.md with standardized sections and auto CSS source compiler docs

## 0.1.0 - 2026-03-24

### Added
- Initial PhoenixKit module template with `PhoenixKit.Module` behaviour
- Admin LiveView page with status dashboard and user info
- Route module template for multi-page modules
- Implement `css_sources/0` for Tailwind CSS scanning support
- Add test infrastructure with dual-level testing (unit + integration)
- Add behaviour compliance test suite
- Comprehensive README documentation covering all PhoenixKit module patterns

# Follow-up Items for PR #34

Triaged CLAUDE_REVIEW.md against `main`. The review records two gate
failures, both fixed on `main` at review time, and confirms the three
template bugs the PR itself repaired. All re-verified against current code.

## Fixed (pre-existing)

- ~~**`mix credo --strict` failed** — function body nested too deep in
  `check_version_marker/2`~~ — the `case` lives in its own
  `inspect_version_marker/2`
  (`lib/mix/tasks/phoenix_kit_hello_world.audit_migrations.ex:229-258`).
- ~~**`mix dialyzer` failed** — `Mix.shell/0` unknown, `Mix.Task` callback
  info missing~~ — `mix.exs:23` reads
  `dialyzer: [plt_add_apps: [:phoenix_kit, :mix]]`.
- ~~**Template bug 1** — `String.to_integer/1` on the version comment~~ —
  `parse_version/1` uses `Integer.parse/1` with an `@initial_version`
  fallback (`lib/phoenix_kit_hello_world/migrations.ex:269-276`).
- ~~**Template bug 2** — `migrated_version_runtime/1` swallowing everything
  into `0`~~ — `ArgumentError` is re-raised before the blanket clause
  (`lib/phoenix_kit_hello_world/migrations.ex:139-145`).
- ~~**Template bug 3** — `up_v1/1` ensured the uuid function but not
  pgcrypto~~ — `Helpers.ensure_extension!("pgcrypto")` precedes
  `Helpers.ensure_uuid_v7_function(prefix)`
  (`lib/phoenix_kit_hello_world/migrations.ex:154-155`; the README twin at
  `README.md:1799`).

## Skipped (with rationale)

- **"Carried forward" — the `phoenix_kit_legal` coordinator conflict with
  core's V43.** Not an item for this repository: the review itself states the
  PR fixes the template, not the module copied from it, and assigns the item
  to the legal module's own sweep.

## Open

None.

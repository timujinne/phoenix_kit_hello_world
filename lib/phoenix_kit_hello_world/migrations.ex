# Example versioned migration coordinator for a PhoenixKit module —
# deliberately ALL comments.
#
# hello_world is the canonical module TEMPLATE, so it owns no database
# tables: a demo module has no business creating a table in every host that
# installs it. This file therefore compiles to nothing. It exists because
# when your module DOES need a table, this is the shape to copy — and
# because the policy it encodes is easy to get wrong:
#
#   **A module ships the DDL for its own tables.** The migrations live in
#   YOUR repo and version with YOUR package. They are NOT added as a new
#   `Vxxx` to core phoenix_kit's migration chain — that would couple your
#   schema to a core release and grow the core package for hosts that never
#   install your module.
#
# ## The contract
#
# `mix phoenix_kit.update` (run in the host app) scans beam files for
# registered modules, calls `migration_module/0` on each, and for every
# module whose database is behind:
#
#   * reads `migrated_version_runtime(prefix: prefix)` — what the host has
#   * reads `current_version/0` — what the shipped code needs
#   * writes a migration into the host's `priv/repo/migrations/` that calls
#     back into your `up/1` (and `down/1` for rollback)
#   * runs `mix ecto.migrate`
#
# So the host never hand-writes migration SQL for your module, there is no
# install task to ship, and the generated migration honors the host's
# `--prefix` (named-schema installs). Registering it is one line in your
# module:
#
#     @impl PhoenixKit.Module
#     def migration_module, do: MyModule.Migrations
#
# ## Live references
#
# Two published modules implement exactly this file: phoenix_kit_boards
# (single table) and phoenix_kit_web_analytics (two tables plus indexes).
# Read those when you want a version that actually runs.
#
# `mix phoenix_kit_hello_world.audit_migrations`, shipped by this template,
# checks a live host's modules against the rules below. Run it before
# believing your coordinator works.
#
# defmodule MyModule.Migrations do
#   @moduledoc """
#   Versioned migration coordinator for `my_module`.
#
#   Versions:
#
#     * `0` — table absent (not installed)
#     * `1` — `phoenix_kit_my_module_items`, UUIDv7 primary key
#   """
#
#   use Ecto.Migration
#
#   alias PhoenixKit.Migrations.Postgres.Helpers
#
#   @initial_version 1
#   @current_version 1
#   @default_prefix "public"
#   # The version marker lives in a COMMENT ON TABLE on this table. A
#   # boolean "does the table exist" would not do: it can't tell "not
#   # installed" apart from "installed at V1", which is exactly what a
#   # future V2 needs to know. An existence check reports "already current"
#   # for every version you ever ship, so Core skips the delta and prints a
#   # SUCCESS line while doing nothing.
#   @version_table "phoenix_kit_my_module_items"
#
#   @doc "The version this code expects the schema to be at."
#   def current_version, do: @current_version
#
#   @doc "The version a bare, freshly created table is at."
#   def initial_version, do: @initial_version
#
#   @doc """
#   The table whose COMMENT carries the version marker.
#
#   Not part of the protocol Core calls. Export it so an auditor can verify
#   your marker really carries a version (a bare number, or a namespaced
#   marker for an adopted table) without hard-coding your table name — see
#   `mix phoenix_kit_hello_world.audit_migrations`.
#   """
#   def version_table, do: @version_table
#
#   @doc "Run every step up to (and including) the target version."
#   def up(opts \\ []) do
#     opts = with_defaults(opts, @current_version)
#     initial = migrated_version(opts)
#
#     cond do
#       initial == 0 -> change(@initial_version..opts.version, :up, opts)
#       initial < opts.version -> change((initial + 1)..opts.version, :up, opts)
#       true -> :ok
#     end
#
#     :ok
#   end
#
#   @doc """
#   Roll back down to the target version (default 0 — everything).
#
#   `version: 0` drops. Any higher target KEEPS the table:
#   `down(version: 1)` means "return to V1", and Core generates exactly that
#   for a V2→V1 rollback. A coordinator whose `down/1` always drops answers
#   "return to V1" by deleting the user's data.
#   """
#   def down(opts \\ []) do
#     opts = with_defaults(opts, 0)
#     current = migrated_version(opts)
#     target = opts.version
#
#     if current > target, do: change(current..(target + 1)//-1, :down, opts)
#
#     :ok
#   end
#
#   # Migration context — reads through the `Ecto.Migration` repo() helper.
#   # No rescue: inside a migration, a version you cannot read must abort the
#   # transaction, never be guessed at.
#   def migrated_version(opts \\ []) do
#     opts = with_defaults(opts, @initial_version)
#     read_version(repo(), opts.prefix)
#   end
#
#   # Runtime context — this is the one `mix phoenix_kit.update` calls, from
#   # a Mix task with no migrator running, so it goes through PhoenixKit's
#   # configured repo instead. (`PhoenixKit.Config.get_repo/0` does NOT
#   # exist — older copies of this snippet had it wrong.)
#   #
#   # An invalid prefix is re-raised, matching Core's own reader: 0 means
#   # "this module is not installed here", so reporting it for a bad prefix
#   # tells the operator something false and sends Core off to install a
#   # schema over live data. Genuine unreachability still yields 0, which is
#   # safe only because `up/1` re-reads the version in migration context
#   # before touching anything — a wrong 0 costs a redundant migration file,
#   # never wrong DDL.
#   def migrated_version_runtime(opts \\ []) do
#     opts = with_defaults(opts, @initial_version)
#     read_version(PhoenixKit.RepoHelper.repo(), opts.prefix)
#   rescue
#     e in ArgumentError -> reraise e, __STACKTRACE__
#     _ -> 0
#   end
#
#   # ── v1 ──────────────────────────────────────────────────────────────
#
#   defp up_v1(prefix) do
#     # Don't assume core's chain ran first. `uuid_generate_v7()` is built on
#     # pgcrypto's `gen_random_bytes`, and ensure_uuid_v7_function/1 does not
#     # install extensions — without the first line the function is created
#     # and then fails on the first insert.
#     Helpers.ensure_extension!("pgcrypto")
#     Helpers.ensure_uuid_v7_function(prefix)
#
#     create_if_not_exists table(:phoenix_kit_my_module_items,
#                            primary_key: false,
#                            prefix: prefix
#                          ) do
#       add(:uuid, :uuid,
#         primary_key: true,
#         null: false,
#         default: fragment(Helpers.uuid_v7_call(prefix))
#       )
#
#       add(:name, :string, null: false)
#       add(:status, :string, size: 20, null: false, default: "active")
#       add(:data, :map, null: false, default: %{})
#
#       timestamps(type: :utc_datetime_usec)
#     end
#
#     # Bare index name — `CREATE INDEX schema.name` is a syntax error in
#     # Postgres; an index is scoped to its table's schema automatically.
#     create_if_not_exists(index(:phoenix_kit_my_module_items, [:status], prefix: prefix))
#   end
#
#   defp down_v1(prefix) do
#     drop_if_exists(table(:phoenix_kit_my_module_items, prefix: prefix))
#   end
#
#   # ── internals ───────────────────────────────────────────────────────
#
#   defp change(range, direction, opts) do
#     Enum.each(range, &apply_step(direction, &1, opts.prefix))
#
#     case direction do
#       :up -> record_version(opts, Enum.max(range))
#       :down -> record_version(opts, max(Enum.min(range) - 1, 0))
#     end
#   end
#
#   defp apply_step(:up, 1, prefix), do: up_v1(prefix)
#   defp apply_step(:down, 1, prefix), do: down_v1(prefix)
#
#   defp apply_step(direction, version, _prefix) do
#     raise ArgumentError, "no #{direction} step defined for schema version #{version}"
#   end
#
#   # Version 0 means the table is gone — nothing left to comment on.
#   defp record_version(_opts, 0), do: :ok
#
#   defp record_version(%{prefix: prefix}, version) do
#     execute("COMMENT ON TABLE #{Helpers.qualify_table(@version_table, prefix)} IS '#{version}'")
#   end
#
#   defp with_defaults(opts, version) do
#     opts = Enum.into(opts, %{})
#     prefix = Map.get(opts, :prefix) || @default_prefix
#
#     # The prefix is interpolated into the DDL above, so an invalid one has
#     # to fail here rather than reach the query text.
#     Helpers.validate_prefix!(prefix)
#
#     opts
#     |> Map.put(:prefix, prefix)
#     |> Map.put_new(:version, version)
#   end
#
#   # Reads use bound parameters, so the prefix never reaches the query text
#   # even if validation is loosened later. (Core interpolates an escaped
#   # prefix here for historical reasons; parameters are strictly better.)
#   defp read_version(repo, prefix) do
#     if table_exists?(repo, prefix) do
#       repo |> table_comment(prefix) |> parse_version()
#     else
#       0
#     end
#   end
#
#   defp table_exists?(repo, prefix) do
#     query = """
#     SELECT EXISTS (
#       SELECT FROM information_schema.tables
#       WHERE table_name = $1 AND table_schema = $2
#     )
#     """
#
#     case repo.query(query, [@version_table, prefix], log: false) do
#       {:ok, %{rows: [[exists?]]}} -> exists?
#       {:error, error} -> raise error
#     end
#   end
#
#   defp table_comment(repo, prefix) do
#     query = """
#     SELECT pg_catalog.obj_description(c.oid, 'pg_class')
#     FROM pg_class c
#     JOIN pg_namespace n ON n.oid = c.relnamespace
#     WHERE c.relname = $1 AND n.nspname = $2
#     """
#
#     case repo.query(query, [@version_table, prefix], log: false) do
#       {:ok, %{rows: [[comment]]}} -> comment
#       {:ok, %{rows: []}} -> nil
#       {:error, error} -> raise error
#     end
#   end
#
#   # A numeric comment is the marker. Anything else on a table that exists
#   # means V1: either no comment (a table this coordinator created before it
#   # recorded one) or someone else's prose. Core's own V43, for instance,
#   # creates phoenix_kit_consent_logs with a human description in that slot.
#   #
#   # `Integer.parse/1`, not `String.to_integer/1`: the latter RAISES on
#   # prose, and that raise lands in migrated_version_runtime's rescue, which
#   # converts it to 0 — "not installed" for a populated table.
#   defp parse_version(comment) when is_binary(comment) do
#     case Integer.parse(String.trim(comment)) do
#       {version, ""} -> version
#       _ -> @initial_version
#     end
#   end
#
#   defp parse_version(_), do: @initial_version
# end
#
# Notes for real modules:
#
#   * Version steps are IMMUTABLE once shipped. A host already at V1 never
#     re-runs V1, so editing `up_v1/1` only forks fresh installs from
#     upgraded ones. Add `up_v2/1` + its `apply_step/3` clauses and bump
#     `@current_version`.
#
#   * Check that core does not already create your table. If core's chain
#     also ships the DDL, core's chain runs FIRST (`phoenix_kit.update`
#     runs its own migrations before module migrations), so your table
#     always pre-exists, your `up/1` is dead code, and the two definitions
#     drift apart unnoticed — different column widths, different index
#     names, a different primary key. Grep core's `postgres/v*.ex` for your
#     table name before assuming you own it. If core does create it, your
#     first real version is the step that RECONCILES the two shapes, and it
#     must reach the same end state from either starting point.
#
#   * Reconcile, don't accumulate. When a table already exists in the wild
#     with someone else's index names, a converging step drops those and
#     creates yours — or adopts theirs. Creating a parallel set leaves every
#     host maintaining two overlapping indexes forever.
#
#   * Ship both readers. `migrated_version/1` for migration context,
#     `migrated_version_runtime/1` for Mix-task context. Core calls the
#     second; your own `up/1` calls the first.
#
#   * Fix inference and rollback TOGETHER. A coordinator that infers the
#     version from table existence never generates an upgrade migration for
#     an existing table, so its broken `down/1` is unreachable. Repair the
#     marker alone and you arm the rollback: real `down(version: N > 0)`
#     calls begin the same day.
#
#   * Stay prefix-safe. Pass `prefix:` to every table/index/alter, keep
#     index NAMES bare on CREATE, and anchor existence checks to the target
#     schema. `PhoenixKit.Migrations.Postgres.Helpers` has the pieces:
#     `qualify_table/2`, `uuid_v7_call/1`, `ensure_uuid_v7_function/1`,
#     `ensure_extension!/1`, `validate_prefix!/1`, `public_prefix?/1`.
#
#   * Verify on a live host, not by reading code. Three queries settle who
#     actually owns your table, and they disagree with the source more often
#     than you would expect:
#
#         -- is the marker a number, or someone's prose?
#         SELECT pg_catalog.obj_description(c.oid, 'pg_class')
#         FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
#         WHERE n.nspname = 'public' AND c.relname = '<your table>';
#
#         -- whose index names are these?
#         SELECT indexname FROM pg_indexes
#         WHERE schemaname = 'public' AND tablename = '<your table>';
#
#         -- whose CREATE TABLE ran? (column ORDER is the fingerprint)
#         SELECT column_name, data_type, character_maximum_length, is_nullable
#         FROM information_schema.columns
#         WHERE table_schema = 'public' AND table_name = '<your table>'
#         ORDER BY ordinal_position;
#
#     `mix phoenix_kit_hello_world.audit_migrations` runs the mechanical part
#     of this for every installed module.
#
#   * Test it. `up/1` uses `Ecto.Migration` macros, so it can't be called
#     directly — wrap it in a static `use Ecto.Migration` module and run
#     that through `Ecto.Migrator.up/4` in `test/test_helper.exs`, after
#     `PhoenixKit.Migration.ensure_current/2`. Pass
#     `:os.system_time(:microsecond)` as the version, never a fixed `0`:
#     once `0` is in `schema_migrations` the wrapper is never invoked
#     again, and versions you ship later silently stop applying. The
#     README's "Testing your migration" section has the full snippet.
#     Cover the cases a unit test cannot fake: rollback to a NON-ZERO
#     version keeps the table, a foreign prose comment reads as V1, and a
#     named-schema install resolves the uuid default.
#
# ## Adopting a table core already creates (extraction)
#
# Some module tables were born in core: the module used to live there
# (Legal — core's V43 created `phoenix_kit_consent_logs` in the commit that
# added the module), or the table simply predates the module-owned
# protocol. V43 is history, not a file: core 2.0 squashed the chain to a
# V135 floor, so the table now arrives from `v135.ex` and the shape to
# match is the one `PhoenixKit.Migrations.ExpectedSchema` records. Those
# tables ship in core's squashed baseline, so on every existing install
# the table exists BEFORE your chain first runs.
# Extraction is therefore an ADOPTION, and it unfolds in phases. The live
# reference is `phoenix_kit_legal` — `PhoenixKit.Modules.Legal.Migrations`
# plus its `dev_docs/reports/2026-08-10-consent-logs-extraction.md`, which
# records the failure modes each rule below exists to prevent.
#
# ### Phase 0 — your V1 adopts, and changes NOTHING
#
#   * V1 is `CREATE TABLE IF NOT EXISTS` + the marker stamp,
#     shape-identical to core's baseline with core's EXACT object names
#     (pkey, every index). On today's installs everything already exists
#     and only the marker is new; on a future install whose core no longer
#     creates the table (Phase 2), the same statements build it. Both
#     paths must end identical — that is what makes the later phases safe.
#   * Build the DDL from your schema module's single shape authority
#     (legal interpolates `ConsentLog.column_widths/0` into the DDL and
#     never restates a number — three disagreeing DDLs of one table is how
#     it learned that).
#   * Expose the statements as data and pin them with tests: widths equal
#     the authority, object names equal core's, every statement
#     idempotence-guarded — and for a data-bearing table, no statement in
#     EITHER direction matches DROP/TRUNCATE/DELETE. An audit-trail table
#     must survive `down/1`: unstamp the marker, keep the rows.
#   * Because V1 changes no shape, core's `ExpectedSchema` manifest stays
#     accurate: NO core change ships in this phase and there is no
#     release-ordering hazard. Your module releases alone.
#
# ### Phase 1 — the first shape change (your V2+) is when core moves
#
#   `mix phoenix_kit.repair` asserts the baseline shape of the table until
#   told otherwise. BEFORE releasing a shape-changing version:
#
#   1. add the objects your version alters to the manifest generator's
#      `@excluded_exact` in core (`dev_docs/squash/generate_baseline.exs`)
#      and regenerate `ExpectedSchema` — the maintainer-tooling step the
#      document_creator/projects chains already rely on;
#   2. raise your package's core floor to the release that ships that
#      manifest.
#
#   Skip step 1 and repair "fixes" your table back after every run.
#
# ### Phase 2 — creation leaves core at the next squash cycle
#
#   When core cuts its next baseline, module-owned tables are simply not
#   included: fresh installs from then on get the table from your V1 —
#   which is why V1 must be able to create the FULL table even though
#   today it always finds one. Existing installs are untouched; a baseline
#   only affects fresh installs and below-floor bridging.
#
# ### What must NEVER happen
#
#   * No conditional core migration of the form "module absent → drop the
#     table". A migration whose result depends on which packages are
#     compiled in at run time is nondeterministic — it breaks the
#     manifest, the chain hash and the squash verification oracles — and
#     it destroys data on the host that merely removed a package from
#     deps: dropping the package is not consent to dropping the audit
#     trail.
#   * No automatic uninstall at all. Removing the module's data is a HUMAN
#     step: ship a "removing this module" snippet in your README (drop the
#     table, remove the marker) for the operator to run deliberately.
#
# ### Marker naming for adopted tables
#
#   The template above records a bare number, which is fine for a table
#   your chain created from scratch. An ADOPTED table has lived in core
#   for years and may carry someone's prose comment already — namespace
#   your marker (`pkl_schema:1`, `dcr_schema:1`, `pkp_schema:14`) so your
#   reader can tell its own marker from a foreign comment, and treat any
#   foreign comment as version 0, never crash on it.
#
#   `mix phoenix_kit_hello_world.audit_migrations` accepts both a bare
#   number and a `<namespace>:<number>` marker, so a namespaced marker
#   never fails the audit.

# Example Ecto schema for a PhoenixKit module — deliberately ALL comments.
#
# hello_world has no database tables of its own, so this file compiles to
# nothing. It exists because hello_world is the canonical module template:
# when your module DOES need a table, copy this shape (and see the live
# references at the bottom).
#
# The conventions below are load-bearing — each one exists because a real
# module got it wrong once:
#
#   1. `use PhoenixKit.SchemaPrefix` (core >= 1.7.189) right after
#      `use Ecto.Schema`. Core supports installing into a named Postgres
#      schema (`mix phoenix_kit.install --prefix "auth"`); the migrations
#      create your module's tables INSIDE that schema. This line makes your
#      queries target it too. Without it, your schema resolves tables via
#      the connection's search_path — which works on default public installs
#      and silently breaks on prefixed ones. With no prefix configured it
#      compiles to nil (zero behavior change), so there is no reason to
#      omit it. Copy test/schema_prefix_conformance_test.exs along with it —
#      the test scans lib/ and fails if a table-backed schema misses the line.
#
#   2. UUIDv7 primary keys, named `uuid` (not `id` — integer ids are the
#      deprecated legacy convention in this ecosystem).
#
#   3. Table name prefixed `phoenix_kit_<module_key>_` (see "Database
#      conventions" in the README — generic names collide with other
#      modules and the parent app).
#
#   4. Timestamps are timestamptz (the workspace standardized on this in
#      core migration V58) and the schema's `timestamps/1` type must match
#      the one your migration used. `:utc_datetime` against `timestamptz(6)`
#      columns (what `:utc_datetime_usec` creates) silently truncates on
#      write — pick one and use it in both files.
#
# defmodule PhoenixKitHelloWorld.Schemas.Item do
#   @moduledoc """
#   One demo item. Tables are created by the module's versioned
#   migrations (see `migration_module/0` + the README's "Versioned
#   migrations" section), never by the schema.
#   """
#
#   use Ecto.Schema
#   use PhoenixKit.SchemaPrefix
#   import Ecto.Changeset
#
#   @primary_key {:uuid, UUIDv7, autogenerate: true}
#   @foreign_key_type UUIDv7
#
#   schema "phoenix_kit_hello_world_items" do
#     field :name, :string
#     field :status, :string, default: "active"
#     field :data, :map, default: %{}
#
#     # Same type as the migration's `timestamps(type: :utc_datetime_usec)`:
#     # a schema declared `:utc_datetime` over a microsecond column truncates
#     # on every write and raises on a struct that still carries microseconds.
#     timestamps(type: :utc_datetime_usec)
#   end
#
#   @doc false
#   def changeset(item, attrs) do
#     item
#     # Always cast an explicit allowlist — never all fields.
#     |> cast(attrs, [:name, :status, :data])
#     |> validate_required([:name])
#     |> validate_inclusion(:status, ~w(active archived deleted))
#   end
# end
#
# Notes for real modules:
#
#   * Soft-delete is a sentinel value on the existing `status` string column
#     ("deleted" or "trashed" depending on your lifecycle) — never a
#     `deleted_at` timestamp column. See the workspace soft-delete
#     convention in phoenix_kit_entities/lib/phoenix_kit_entities/entity_data.ex.
#   * Smallest end-to-end live reference (schemas + context + Errors +
#     activity logging): phoenix_kit_locations.
#   * The table behind a schema like this is created by YOUR module's own
#     versioned migrations — see the commented coordinator template in
#     lib/phoenix_kit_hello_world/migrations.ex and the README's "Versioned
#     migrations" section. Module tables do not go into core phoenix_kit's
#     Vxxx chain.

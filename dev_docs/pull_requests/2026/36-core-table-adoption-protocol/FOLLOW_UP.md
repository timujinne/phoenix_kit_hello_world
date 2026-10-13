# Follow-up Items for PR #36

Triaged CLAUDE_REVIEW.md against `main`. One nitpick, already resolved.

## Fixed (pre-existing)

- ~~**NITPICK** — "core's V43" sends the reader to a file that no longer
  exists~~ — the adoption section now carries the clarifying sentence: V43
  is history, the table arrives from `v135.ex`, and the shape to match is
  the one `PhoenixKit.Migrations.ExpectedSchema` records
  (`lib/phoenix_kit_hello_world/migrations.ex:353-358`).
- ~~**Note on the rustler dependency**~~ — observational, no action
  requested. The entry is present as reviewed:
  `{:rustler, ">= 0.0.0", optional: true}` in `mix.exs`.

## Open

None.

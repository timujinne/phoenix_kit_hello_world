# The module AGENTS.md skeleton

Every `phoenix_kit_*` module uses the same eleven `##` headings, in the order
below, each present even when its body is a single line saying `None.` and why.
`hello_world` is the template module, so the standard lives here; its own
`AGENTS.md` is the worked example.

Rules and pointers only. Anything that explains **how** a feature works at
paragraph length belongs in `dev_docs/guides/<topic>.md` (undated filename),
cited from Feature notes by a line that states the invariant rather than a bare
link — agents do not reliably follow links, and a rule with no *why* gets
"fixed" by the next one.

## The headings

1. **Overview** — one paragraph, then the dependency line (core pin from
   `mix.exs`, sibling deps marked hard or optional, which modules consume this
   one), the admin surface, the module key and settings prefix.
2. **What this module does NOT do** — deliberate non-features, responsibilities
   owned by core or a sibling, prohibited dependency directions. Each with the
   clause of why, so a reviewer proposing one gets an answer.
3. **Commands** — deps, test DB, `mix test`, `mix precommit`, and the
   `<APP>_PATH` cross-repo recipe.
4. **Conventions** — the rules: module key and tab ids, path helpers, routing
   pattern, which LiveView macro, gettext backend, JS hook delivery,
   `enabled?/0`, activity logging, soft-delete sentinel. Ends with a
   `### Landmines` subsection of two to five module-local traps, one line each,
   symptom then fix. Ecosystem-wide traps belong in the workspace lessons file.

   A bullet earns its place only if ALL of these hold. Fail any one and it
   does not belong:

   1. **Still true** of the code as it stands — not a fixed bug, not history.
   2. **Cannot reasonably be fixed or diagnosed in code.** If a code change
      would prevent it, or make it fail with a clear message instead of a
      confusing one, *do that instead and write nothing here.*
   3. **Project-specific.** General Elixir, Ecto or PostgreSQL knowledge is
      not a landmine; a competent developer already has it.
   4. **Costly or misleading when missed** — it wastes real debugging time,
      typically because the failure looks like something else.
   5. **Actionable as a rule or pointer**, not a story.
   6. **No personal or machine-specific detail** — no usernames, hostnames,
      local paths, dates, SHAs, or "I hit this once". These files are public
      and are read by people who are not you.

   Setup requirements a contributor must satisfy on their own machine are
   documentation, not landmines: they belong in the README or a setup guide.
5. **Architecture** — file tree, key modules, data model, PubSub topics,
   settings keys, permissions. Tables and trees over prose.
6. **Database & migrations** — whether the module owns a versioned chain, its
   marker and current version, or which core migration ships its tables.
7. **Testing** — test DB, what runs without Postgres, how the schema is built,
   the support modules, env vars, known noise.
8. **Feature notes** — one entry per guide: the constraint that must hold, then
   the link.
9. **Versioning & releases** — see below; identical in every repo.
10. **Pull requests & commits** — see below; identical in every repo.
11. **TODOs** — durable deferrals that change what an agent should do, each with
    the trigger that unblocks it. Not a task backlog.

**Conventions comes before Architecture on purpose.** An agent that stops
reading early should reach the rules, not the description.

## Why no chronology

No dates, PR or issue numbers, commit SHAs, version archaeology ("V17; V40/V58
evolve them"), attributed quotes, or "shipped/merged/completed". Git and GitHub
hold all of it and it goes stale within days. Keep the rule and the one clause
of reasoning behind it; drop the story around it.

State rules in the present tense: "auth pages bypass the host layout", never
"PR #677 changed auth pages". Anchor to a version only when it genuinely gates a
consumer, and then say what breaks below it.

## Verify before you write

Nearly every stale claim this standard replaced was a fact that used to be true.
Check against the code, not the previous file: the core pin in `mix.exs`, which
LiveView macro `lib/` actually uses, whether `migration_module/0` is set, what
`js_sources/0` and `css_sources/0` return, and what the test helper really does.
When the code and an older document disagree, the code wins and the disagreement
is worth a line in the report.

## The two shared blocks

These are byte-identical in every module. Do not reword them per repo; a diff
between two modules should show no difference here.

### Versioning & releases

```markdown
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
```

The tag step names no form on purpose. Tag style is mixed across the ecosystem
(some repos `v`-prefixed, some bare, several having flipped mid-history), and a
document that hardcodes one has already caused a wrong tag to be pushed and
deleted. "Match the newest existing tag" is self-correcting.

### Pull requests & commits

```markdown
- Commit messages start with an action verb (`Add`, `Update`, `Fix`, `Remove`, `Merge`). No AI attribution and no `Co-Authored-By` trailers.
- Version bumps and CHANGELOG entries land with the release commit on upstream, not in feature PRs.
- Review files live in `dev_docs/pull_requests/{year}/{pr_number}-{slug}/{AGENT}_REVIEW.md`, one file per reviewing agent, never edited by another agent; `FOLLOW_UP.md` records how each finding was resolved. Severities: `BUG - CRITICAL/HIGH/MEDIUM`, `IMPROVEMENT - HIGH/MEDIUM`, `NITPICK`.
```

Keep the release steps as neutral procedure. Prohibition wording ("never bump
the version", "releases are the maintainer's only") was removed from these files
because it caused the maintainer's own release tooling to refuse to cut
releases; the workspace-level policy is what governs agents.

## Two things that are not in the file but are part of the standard

- **`version/0` derives from `mix.exs`.** `@version Mix.Project.config()[:version]`
  and a behaviour test asserting `Mix.Project.config()[:version]`. A literal
  drifts silently: two modules shipped releases whose `version/0` still returned
  the previous number, and one of them had a red suite on `main` because its
  test pinned the old literal.
- **`CLAUDE.md` is a committed symlink to `AGENTS.md`.** Claude Code auto-loads
  `CLAUDE.md`; every other agent reads `AGENTS.md`. The symlink is a real git
  object (mode `120000`) so one file serves both. Check `.gitignore` is not
  hiding it — two repos ignored `CLAUDE.md` and the symlink silently never
  committed.

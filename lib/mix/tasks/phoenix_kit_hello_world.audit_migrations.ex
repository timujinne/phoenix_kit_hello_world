defmodule Mix.Tasks.PhoenixKitHelloWorld.AuditMigrations do
  @shortdoc "Audit installed PhoenixKit modules' migration coordinators"

  @moduledoc """
  Checks every installed PhoenixKit module's migration coordinator against the
  rules in `lib/phoenix_kit_hello_world/migrations.ex`.

      mix phoenix_kit_hello_world.audit_migrations
      mix phoenix_kit_hello_world.audit_migrations --prefix auth

  Run it in a **host app**, against a database that has been migrated. It reads
  the database and calls each coordinator's reader functions; it never writes.

  ## Why this exists

  The rules a module-owned migration has to follow are all silent when broken.
  A coordinator that infers its version from "does the table exist" reports
  itself up to date at every version it will ever ship, so `mix
  phoenix_kit.update` prints a green line and applies nothing. A coordinator
  whose `down/1` ignores the target version answers "roll back to V1" by
  dropping the table. Neither shows up in a test suite that has no database, and
  neither produces an error message when it goes wrong — they produce silence,
  or worse, success.

  This task turns the mechanical part of that review into something that fails
  out loud.

  ## What it checks

  For each discovered module that returns a `migration_module/0`:

    * **protocol** — `current_version/0`, `up/1`, `down/1`,
      `migrated_version/1` and `migrated_version_runtime/1` all exported.
      Missing `migrated_version_runtime/1` makes the module invisible to
      `mix phoenix_kit.update`; missing `migrated_version/1` means `up/1`
      cannot re-read the version it is about to change.
    * **absent schema reports 0** — the reader must answer 0, and only 0, for a
      schema that does not exist.
    * **invalid prefix raises** — a prefix that cannot be used must raise, not
      be reported as version 0. Zero means "not installed here" and sends the
      updater off to install a schema over live data.
    * **reported version ≤ target** — a reader claiming to be ahead of the
      shipped code is inferring rather than reading.
    * **version marker is a version** — only when the coordinator exports
      `version_table/0`. A `COMMENT ON TABLE` on an existing table must carry
      a version marker — a bare number, or a namespaced marker
      (`<namespace>:<number>`, e.g. `pkl_schema:1`) for a table adopted from
      core. Anything else means the version is not stored there, so it is
      being inferred. This is the check that catches the whole class.

  Coordinators without `version_table/0` get the marker check reported as
  unverifiable, with the query to run by hand. Exporting it is one line:

      def version_table, do: @version_table

  Exits non-zero if anything failed, so it can gate a release.
  """

  use Mix.Task

  @requirements ["app.start"]

  # Must stay within PhoenixKit.Migrations.Postgres.Helpers.validate_prefix!/1's
  # 20-byte ceiling (63 - 1 - 42, the longest embedded object name) — a
  # coordinator that correctly delegates prefix validation to core's helper
  # raises ArgumentError on a longer fixture, which is a false failure of the
  # very check meant to reward that delegation.
  @absent_schema "pk_audit_absent"
  @invalid_prefix "bad-prefix; DROP TABLE x"
  @marker_namespace_re ~r/^[a-z][a-z0-9_]*$/
  @core_called_directly [:current_version, :up, :down, :migrated_version_runtime]

  @protocol [
    {:current_version, 0},
    {:up, 1},
    {:down, 1},
    {:migrated_version, 1},
    {:migrated_version_runtime, 1}
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _rest} = OptionParser.parse!(args, strict: [prefix: :string])
    prefix = opts[:prefix] || "public"

    coordinators = discover()

    if coordinators == [] do
      Mix.shell().info("No installed PhoenixKit module declares a migration_module/0.")
      Mix.shell().info("Nothing to audit — modules without their own tables return nil.")
    else
      Mix.shell().info("Auditing #{length(coordinators)} coordinator(s) in schema #{prefix}\n")

      results = Enum.map(coordinators, &audit(&1, prefix))

      report(results)
    end
  end

  defp discover do
    PhoenixKit.ModuleDiscovery.discover_external_modules()
    |> Enum.flat_map(fn mod ->
      with true <- Code.ensure_loaded?(mod),
           true <- function_exported?(mod, :migration_module, 0),
           coordinator when not is_nil(coordinator) <- mod.migration_module() do
        [{module_label(mod), coordinator}]
      else
        _ -> []
      end
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp module_label(mod) do
    if function_exported?(mod, :module_name, 0), do: mod.module_name(), else: inspect(mod)
  rescue
    _ -> inspect(mod)
  end

  defp audit({label, coordinator}, prefix) do
    Mix.shell().info("#{label} — #{inspect(coordinator)}")

    checks =
      if Code.ensure_loaded?(coordinator) do
        missing = Enum.reject(@protocol, fn {f, a} -> function_exported?(coordinator, f, a) end)

        case missing do
          [] -> [protocol_ok() | behaviour_checks(coordinator, prefix)]
          _ -> [protocol_missing(missing)]
        end
      else
        [{:fail, "module does not load", "#{inspect(coordinator)} is not a loadable module"}]
      end

    Enum.each(checks, &print_check/1)
    Mix.shell().info("")

    {label, checks}
  end

  defp protocol_ok, do: {:ok, "protocol", "all five functions exported"}

  @doc false
  def protocol_missing(missing) do
    names = Enum.map(missing, fn {f, _a} -> f end)
    list = Enum.map_join(missing, ", ", fn {f, a} -> "#{f}/#{a}" end)

    consequence =
      if Enum.any?(names, &(&1 in @core_called_directly)) do
        "mix phoenix_kit.update cannot drive this coordinator"
      else
        "up/1 cannot re-read the version it is about to change"
      end

    {:fail, "protocol", "not exported: #{list} — #{consequence}"}
  end

  @doc false
  def absent_schema, do: @absent_schema

  defp behaviour_checks(coordinator, prefix) do
    [
      check_absent_schema(coordinator),
      check_invalid_prefix(coordinator),
      check_reported_version(coordinator, prefix),
      check_version_marker(coordinator, prefix)
    ]
  end

  defp check_absent_schema(coordinator) do
    case safe(fn -> coordinator.migrated_version_runtime(prefix: @absent_schema) end) do
      {:ok, 0} ->
        {:ok, "absent schema reports 0", "correct"}

      {:ok, other} ->
        {:fail, "absent schema reports 0",
         "reported #{inspect(other)} for a schema that does not exist — the reader is not " <>
           "looking at the database, or is looking in the wrong schema"}

      {:raised, e} ->
        {:fail, "absent schema reports 0",
         "raised #{inspect(e.__struct__)} instead of reporting 0: #{Exception.message(e)}"}
    end
  end

  defp check_invalid_prefix(coordinator) do
    case safe(fn -> coordinator.migrated_version_runtime(prefix: @invalid_prefix) end) do
      {:raised, %ArgumentError{}} ->
        {:ok, "invalid prefix raises", "ArgumentError, as it should"}

      {:raised, e} ->
        {:warn, "invalid prefix raises",
         "raised #{inspect(e.__struct__)} rather than ArgumentError — it does fail, but " <>
           "callers matching on ArgumentError (Core's reader does) will not catch it"}

      {:ok, version} ->
        {:warn, "invalid prefix raises",
         "reported version #{version} for an unusable prefix instead of raising. 0 means " <>
           "\"not installed here\", so an operator typo reads as a fresh install"}
    end
  end

  defp check_reported_version(coordinator, prefix) do
    with {:ok, target} <- safe(fn -> coordinator.current_version() end),
         {:ok, reported} <- safe(fn -> coordinator.migrated_version_runtime(prefix: prefix) end) do
      cond do
        not (is_integer(target) and target > 0) ->
          {:fail, "current_version/0", "returned #{inspect(target)}, expected a positive integer"}

        reported > target ->
          {:fail, "reported version <= target",
           "database reports V#{pad(reported)} but the shipped code targets V#{pad(target)} — " <>
             "a reader cannot legitimately be ahead of its own code"}

        reported == target ->
          {:ok, "reported version <= target", "V#{pad(reported)} (up to date)"}

        true ->
          {:ok, "reported version <= target",
           "V#{pad(reported)} of V#{pad(target)} — mix phoenix_kit.update has work to do here"}
      end
    else
      {:raised, e} ->
        {:fail, "reported version <= target",
         "reader raised #{inspect(e.__struct__)}: #{Exception.message(e)}"}
    end
  end

  defp check_version_marker(coordinator, prefix) do
    if function_exported?(coordinator, :version_table, 0) do
      inspect_version_marker(coordinator.version_table(), prefix)
    else
      {:warn, "version marker is a version",
       "unverifiable: #{inspect(coordinator)} does not export version_table/0. Add " <>
         "`def version_table, do: @version_table`, or check by hand with: SELECT " <>
         "pg_catalog.obj_description(c.oid,'pg_class') FROM pg_class c JOIN pg_namespace n " <>
         "ON n.oid=c.relnamespace WHERE n.nspname='#{prefix}' AND c.relname='<your table>';"}
    end
  end

  defp inspect_version_marker(table, prefix) do
    case safe(fn -> read_comment(table, prefix) end) do
      {:ok, :no_table} ->
        {:ok, "version marker is a version",
         "#{table} does not exist in #{prefix} — nothing installed, nothing to mark"}

      {:ok, nil} ->
        {:warn, "version marker is a version",
         "#{table} exists with no COMMENT at all. Readable as V1 by convention, but the " <>
           "marker is not being written — check that record_version/2 runs after each step"}

      {:ok, comment} ->
        classify_comment(table, comment)

      {:raised, e} ->
        {:warn, "version marker is a version", "could not read: #{Exception.message(e)}"}
    end
  end

  @doc false
  def parse_marker(comment) do
    trimmed = String.trim(comment)

    case String.split(trimmed, ":", parts: 2) do
      [namespace, version_str] ->
        if namespace != "" and Regex.match?(@marker_namespace_re, namespace) do
          parse_version_str(version_str, namespace)
        else
          :error
        end

      [bare] ->
        parse_version_str(bare, nil)
    end
  end

  defp parse_version_str(str, namespace) do
    case Integer.parse(str) do
      {version, ""} -> {:ok, version, namespace}
      _ -> :error
    end
  end

  @doc false
  def classify_comment(table, comment) do
    case parse_marker(comment) do
      {:ok, version, nil} ->
        {:ok, "version marker is a version", "#{table} is marked V#{pad(version)}"}

      {:ok, version, namespace} ->
        {:ok, "version marker is a version",
         "#{table} is marked V#{pad(version)} (marker `#{namespace}:#{version}`)"}

      :error ->
        {:fail, "version marker is a version",
         "#{table} carries prose, not a version: #{inspect(String.slice(comment, 0, 60))}. " <>
           "The version is therefore being inferred — most likely from the table existing, " <>
           "which reports \"current\" at every version you ship and skips every delta"}
    end
  end

  defp read_comment(table, prefix) do
    repo = PhoenixKit.RepoHelper.repo()

    exists_query = """
    SELECT EXISTS (
      SELECT FROM information_schema.tables
      WHERE table_name = $1 AND table_schema = $2
    )
    """

    case repo.query!(exists_query, [table, prefix], log: false).rows do
      [[false]] ->
        :no_table

      [[true]] ->
        comment_query = """
        SELECT pg_catalog.obj_description(c.oid, 'pg_class')
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = $1 AND n.nspname = $2
        """

        case repo.query!(comment_query, [table, prefix], log: false).rows do
          [[comment]] -> comment
          [] -> nil
        end
    end
  end

  defp report(results) do
    checks = Enum.flat_map(results, fn {_label, checks} -> checks end)
    failed = Enum.count(checks, &(elem(&1, 0) == :fail))
    warned = Enum.count(checks, &(elem(&1, 0) == :warn))

    Mix.shell().info(String.duplicate("─", 72))

    Mix.shell().info(
      "#{length(checks)} checks across #{length(results)} coordinator(s): " <>
        "#{failed} failed, #{warned} warned"
    )

    if failed > 0 do
      Mix.shell().info("")

      Mix.shell().error(
        "Migration contract violated. See lib/phoenix_kit_hello_world/migrations.ex for the " <>
          "rules and the shape that satisfies them."
      )

      exit({:shutdown, 1})
    end
  end

  defp print_check({level, name, detail}) do
    tag =
      case level do
        :ok -> "[ ok ]"
        :warn -> "[warn]"
        :fail -> "[FAIL]"
      end

    Mix.shell().info("  #{tag} #{name}: #{detail}")
  end

  defp safe(fun) do
    {:ok, fun.()}
  rescue
    e -> {:raised, e}
  end

  defp pad(version) when version < 10, do: "0#{version}"
  defp pad(version), do: "#{version}"
end

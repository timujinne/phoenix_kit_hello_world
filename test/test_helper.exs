# Test helper for PhoenixKitHelloWorld test suite.
#
# Level 1: Unit tests (schemas, changesets, pure functions) always run.
# Level 2: Integration tests require PostgreSQL — automatically excluded
#          when the database is unavailable (`:integration` tag).
#
# To enable integration tests:
#
#     mix test.setup           # createdb + migrate
#     mix test
#
# The test endpoint runs with `server: false` (no port opened); LiveView
# tests drive it via `Phoenix.LiveViewTest.live/2` only.

# The support modules in test/support (the repo, endpoint, router, case
# templates) are compiled by `elixirc_paths(:test)` in mix.exs and are in the
# code path before this file runs — referencing one loads it. Do not also
# `Code.require_file/2` them here: that compiles each a second time and
# prints a "redefining module" warning per file.

# Check if the test database exists
db_name =
  Application.get_env(:phoenix_kit_hello_world, PhoenixKitHelloWorld.Test.Repo)[:database] ||
    "phoenix_kit_hello_world_test"

# One classified connection attempt, with the repo's OWN credentials and
# transport, before anything starts the pool. Core ships the preflight
# (`PhoenixKit.TestSupport.PostgresPreflight`) and this module's core floor
# carries it, so it is called directly.
#
# Asking the repo's own question matters: a database listing run as the
# shell's user over a unix socket reports "the database is there" and says
# nothing about whether the CONFIGURED role can reach it over TCP. When it
# cannot, the answer otherwise arrives minutes later as a pool checkout
# timeout that reads like a flaky test.
db_check =
  case PhoenixKit.TestSupport.PostgresPreflight.check(
         Application.get_env(:phoenix_kit_hello_world, PhoenixKitHelloWorld.Test.Repo, [])
       ) do
    :ok ->
      :exists

    {:error, _reason, message} ->
      IO.puts(:stderr, "\n" <> message)
      :not_found
  end

repo_available =
  if db_check == :not_found do
    IO.puts("""
    \n⚠  Cannot reach test database "#{db_name}" — integration tests will be excluded.
       The reason is printed above.
    """)

    false
  else
    try do
      {:ok, _} = PhoenixKitHelloWorld.Test.Repo.start_link()

      # Build the schema by running core's versioned migrations directly:
      # `phoenix_kit_settings`, `phoenix_kit_activities`, the
      # `uuid_generate_v7()` function and everything else core owns come
      # from core's own chain, so the test schema cannot drift from it.
      PhoenixKit.Migration.ensure_current(PhoenixKitHelloWorld.Test.Repo, log: false)

      Ecto.Adapters.SQL.Sandbox.mode(PhoenixKitHelloWorld.Test.Repo, :manual)
      true
    rescue
      e ->
        IO.puts("""
        \n⚠  Could not connect to test database — integration tests will be excluded.
           The reason is printed above.
           Error: #{Exception.message(e)}
        """)

        false
    catch
      :exit, reason ->
        IO.puts("""
        \n⚠  Could not connect to test database — integration tests will be excluded.
           The reason is printed above.
           Error: #{inspect(reason)}
        """)

        false
    end
  end

Application.put_env(:phoenix_kit_hello_world, :test_repo_available, repo_available)

# Start minimal PhoenixKit services so the module's runtime dependencies
# (PubSub topics, ModuleRegistry) resolve during tests.
{:ok, _pid} = PhoenixKit.PubSub.Manager.start_link([])
{:ok, _pid} = PhoenixKit.ModuleRegistry.start_link([])

# Exclude integration tests when DB is not available
exclude = if repo_available, do: [], else: [:integration]

# Force PhoenixKit's URL prefix cache to an empty string for tests so
# `Paths.index()` etc. produce paths the test router can match. Admin
# paths always get the default locale ("en") prefix, so our router
# scope is `/en/admin/hello-world`.
:persistent_term.put({PhoenixKit.Config, :url_prefix}, "/")

# Start the test Endpoint so Phoenix.LiveViewTest can drive our
# LiveViews via `live/2` with real URLs. Runs with `server: false`, so
# no port is opened. Only starts when the test DB is available —
# without DB, LiveView tests are excluded anyway and an endpoint start
# would fail on missing Phoenix/Plug deps in a DB-less smoke run.
if repo_available do
  {:ok, _} = PhoenixKitHelloWorld.Test.Endpoint.start_link()
end

ExUnit.start(exclude: exclude)

defmodule PhoenixKitHelloWorld.LiveCase do
  @moduledoc """
  Test case for LiveView tests. Wires up the test Endpoint, imports
  `Phoenix.LiveViewTest` helpers, and sets up an Ecto SQL sandbox
  connection.

  Tests using this case are tagged `:integration` automatically and
  get excluded when the test DB isn't available, matching the rest of
  the suite.

  ## Example

      defmodule PhoenixKitHelloWorld.Web.HelloLiveTest do
        use PhoenixKitHelloWorld.LiveCase

        test "renders the overview page", %{conn: conn} do
          {:ok, _view, html} = live(conn, "/admin/hello-world")
          assert html =~ "Hello World Plugin"
        end
      end

  ## Scope assigns

  Hello World's LiveViews read `socket.assigns[:phoenix_kit_current_scope]`
  and `socket.assigns[:phoenix_kit_current_user]` to decide what UI to
  show (the "Log demo event" button is hidden for users without the
  `hello_world` permission). Build a scope with `fake_scope/1` and put it in
  the session with `put_test_scope/2`; the test router's `:assign_scope`
  `on_mount` hook mirrors it onto the socket, the way core's admin
  `live_session` does in production.

  A page whose rows have a foreign key to `phoenix_kit_users` (notifications)
  needs a real user: `user_fixture/1` inserts one, and
  `fake_scope(user_uuid: user.uuid, email: user.email)` signs it in.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :integration
      @endpoint PhoenixKitHelloWorld.Test.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import PhoenixKitHelloWorld.ActivityLogAssertions
      import PhoenixKitHelloWorld.LiveCase
    end
  end

  alias Ecto.Adapters.SQL.Sandbox
  alias PhoenixKit.Users.Auth.User
  alias PhoenixKitHelloWorld.Test.Repo, as: TestRepo

  setup tags do
    pid = Sandbox.start_owner!(TestRepo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    conn =
      Phoenix.ConnTest.build_conn()
      |> Plug.Test.init_test_session(%{})

    {:ok, conn: conn}
  end

  @doc """
  Returns a real `PhoenixKit.Users.Auth.Scope` struct for testing.

  Hello World's LiveView calls `Scope.has_module_access?(scope,
  "hello_world")` and `Scope.can_access_admin_area?(scope)` — both are pattern-matched
  on `%PhoenixKit.Users.Auth.Scope{}`, so a plain map won't satisfy
  them. The struct's `:cached_permissions` field is a `MapSet` that
  `has_module_access?/2` checks via membership, and `:cached_roles` /
  `:authenticated?` drive `admin?/1`.

  ## Options

    * `:user_uuid` — defaults to a fresh UUIDv4 (good enough for tests)
    * `:email` — defaults to a unique-suffix string
    * `:roles` — list of role atoms; `[:owner]` makes `admin?/1` true
    * `:permissions` — list of module-key strings; `["hello_world"]`
      grants the demo button
    * `:authenticated?` — defaults to `true`

  ## Example

      conn = put_test_scope(conn, fake_scope(permissions: ["hello_world"]))
      {:ok, _view, html} = live(conn, "/admin/hello-world")
      assert html =~ "Log demo event"
  """
  def fake_scope(opts \\ []) do
    user_uuid = Keyword.get(opts, :user_uuid, Ecto.UUID.generate())
    email = Keyword.get(opts, :email, "test-#{System.unique_integer([:positive])}@example.com")
    roles = Keyword.get(opts, :roles, [:owner])
    permissions = Keyword.get(opts, :permissions, ["hello_world"])
    authenticated? = Keyword.get(opts, :authenticated?, true)

    user = %{uuid: user_uuid, email: email}

    %PhoenixKit.Users.Auth.Scope{
      user: user,
      authenticated?: authenticated?,
      cached_roles: MapSet.new(roles),
      cached_permissions: MapSet.new(permissions)
    }
  end

  @doc """
  Inserts a real `phoenix_kit_users` row through core's registration
  changeset and returns it. Needed wherever a row references a user by
  foreign key — a made-up uuid violates the constraint.
  """
  def user_fixture(opts \\ []) do
    email = Keyword.get(opts, :email, "user-#{System.unique_integer([:positive])}@example.com")

    %User{}
    |> User.registration_changeset(%{
      email: email,
      password: "ValidPassword123!"
    })
    |> TestRepo.insert!()
  end

  @doc """
  Plugs a fake scope into the test conn's session so the test
  `:assign_scope` `on_mount` hook can put it on socket assigns at
  mount time. Pair with `fake_scope/1`.

  ## Example

      conn = put_test_scope(conn, fake_scope())
      {:ok, view, _} = live(conn, "/admin/hello-world")
  """
  def put_test_scope(conn, scope) do
    Plug.Test.init_test_session(conn, %{"phoenix_kit_test_scope" => scope})
  end
end

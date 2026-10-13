defmodule PhoenixKitHelloWorld.Web.HelloLiveTest do
  @moduledoc """
  Smoke + delta-pinning tests for the Hello World overview page.

  The "Log demo event" button gates on `Scope.has_module_access?(scope,
  "hello_world")`, which checks `cached_permissions`. Tests that need
  the button visible call `put_test_scope(conn, fake_scope(...))`
  before `live/2`.
  """
  use PhoenixKitHelloWorld.LiveCase

  alias PhoenixKitHelloWorld.Web.HelloLive

  describe "mount" do
    test "renders the landing page", %{conn: conn} do
      conn = put_test_scope(conn, fake_scope())

      {:ok, _view, html} = live(conn, "/en/admin/hello-world")

      assert html =~ "Hello World Plugin"
      assert html =~ "Module Info"
      assert html =~ "Current User"
    end

    test "without scope, the demo button is hidden and a permission warning shows",
         %{conn: conn} do
      {:ok, _view, html} = live(conn, "/en/admin/hello-world")

      refute html =~ "Log demo event"
      assert html =~ "permission to log events"
    end

    test "with module access, the demo button is rendered", %{conn: conn} do
      conn = put_test_scope(conn, fake_scope(permissions: ["hello_world"]))

      {:ok, _view, html} = live(conn, "/en/admin/hello-world")

      assert html =~ "Log demo event"
    end
  end

  describe "phx-disable-with attr (C5 delta)" do
    test "Log demo event button has phx-disable-with set", %{conn: conn} do
      conn = put_test_scope(conn, fake_scope(permissions: ["hello_world"]))

      {:ok, _view, html} = live(conn, "/en/admin/hello-world")

      # The button must carry phx-disable-with so double-clicks don't
      # double-log activity. This regex pins C5's fix on the button —
      # if the attr is removed, this test fails.
      assert html =~ ~r/phx-click="log_demo_event"[^>]*phx-disable-with/s or
               html =~ ~r/phx-disable-with=[^>]*phx-click="log_demo_event"/s
    end
  end

  describe "log demo event flow" do
    test "click logs an activity row with the canonical action + actor", %{conn: conn} do
      scope = fake_scope(permissions: ["hello_world"])
      user_uuid = scope.user.uuid

      conn = put_test_scope(conn, scope)
      {:ok, view, _html} = live(conn, "/en/admin/hello-world")

      rendered = render_click(view, "log_demo_event", %{})

      # Flash text appears (verifies C7 flash rendering + C5 gettext-wrap)
      assert rendered =~ "Event logged — check the Events tab!"

      # Activity row landed with the right shape (pins canonical pattern + C9 helper)
      assert_activity_logged("hello_world.demo_event",
        actor_uuid: user_uuid,
        metadata_has: %{"source" => "showcase_button"}
      )
    end

    test "click without module access flashes the permission error", %{conn: conn} do
      # No scope — the button is hidden in the template, but we can still
      # trigger the event (it's a server-side handler) to verify the gate
      # behaves correctly under hostile input.
      {:ok, view, _html} = live(conn, "/en/admin/hello-world")

      rendered = render_click(view, "log_demo_event", %{})

      assert rendered =~ "permission to log events"
      refute_activity_logged("hello_world.demo_event")
    end
  end

  describe "sub-permission: hello_world.moderate" do
    # enable_system/0 writes a setting with no settings cache running here.
    @describetag :capture_log

    # `Scope.can?/2` needs three things: the role holds the dotted key, it
    # holds the base key, and the module behind the key is enabled. The
    # module is registered and enabled here the way a host has it at runtime.
    setup do
      unless PhoenixKitHelloWorld in PhoenixKit.ModuleRegistry.all_modules() do
        :ok = PhoenixKit.ModuleRegistry.register(PhoenixKitHelloWorld)
        on_exit(fn -> PhoenixKit.ModuleRegistry.unregister(PhoenixKitHelloWorld) end)
      end

      {:ok, _} = PhoenixKitHelloWorld.enable_system()
      :ok
    end

    @moderation ~s|button[phx-click="log_moderation_event"]|

    test "granted: the button is rendered and logs a moderation event", %{conn: conn} do
      scope = fake_scope(permissions: ["hello_world", "hello_world.moderate"])
      {:ok, view, _html} = conn |> put_test_scope(scope) |> live("/en/admin/hello-world")

      assert has_element?(view, @moderation <> "[phx-disable-with]")
      assert has_element?(view, ~s|[data-can-moderate="true"]|)

      html = view |> element(@moderation) |> render_click()

      assert html =~ "Event logged — check the Events tab!"

      assert_activity_logged("hello_world.moderation_event",
        actor_uuid: scope.user.uuid,
        metadata_has: %{"source" => "moderation_button"}
      )
    end

    test "base key only: no button, and a crafted event is refused", %{conn: conn} do
      scope = fake_scope(permissions: ["hello_world"])
      {:ok, view, html} = conn |> put_test_scope(scope) |> live("/en/admin/hello-world")

      # The base-key control is still there; only the sub-gated one is not.
      assert has_element?(view, ~s|button[phx-click="log_demo_event"]|)
      refute has_element?(view, @moderation)
      assert has_element?(view, ~s|[data-can-moderate="false"]|)
      assert html =~ "sub-permission"

      html = render_click(view, "log_moderation_event", %{})

      assert html =~ "permission to log moderation events"
      refute_activity_logged("hello_world.moderation_event")
    end

    test "the sub key without its base grants nothing", %{conn: conn} do
      scope = fake_scope(permissions: ["hello_world.moderate"])
      {:ok, view, _html} = conn |> put_test_scope(scope) |> live("/en/admin/hello-world")

      refute has_element?(view, @moderation)
      render_click(view, "log_moderation_event", %{})
      refute_activity_logged("hello_world.moderation_event")
    end

    test "granted but the module is disabled: the sub-permission is not effective", %{
      conn: conn
    } do
      {:ok, _} = PhoenixKitHelloWorld.disable_system()

      scope = fake_scope(permissions: ["hello_world", "hello_world.moderate"])
      {:ok, view, _html} = conn |> put_test_scope(scope) |> live("/en/admin/hello-world")

      refute has_element?(view, @moderation)
      render_click(view, "log_moderation_event", %{})
      refute_activity_logged("hello_world.moderation_event")
    end

    test "no scope: refused", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/en/admin/hello-world")

      refute has_element?(view, @moderation)
      assert render_click(view, "log_moderation_event", %{}) =~ "permission to log moderation"
      refute_activity_logged("hello_world.moderation_event")
    end
  end

  describe "sentences with inline markup" do
    test "each sentence renders whole, with its link or code span in place", %{conn: conn} do
      {:ok, view, html} = live(conn, "/en/admin/hello-world")

      text = html |> LazyHTML.from_fragment() |> LazyHTML.text() |> String.replace(~r/\s+/, " ")

      assert text =~
               "Click a button below to log an activity event, then visit the Events tab to see it appear in the feed."

      assert text =~ "Edit lib/phoenix_kit_hello_world/web/hello_live.ex — this file"
      assert text =~ "Log all mutations via PhoenixKit.Activity.log/3 — see the demo button above"
      assert text =~ "Browse Components to see what's available"
      assert text =~ "See README.md for the full guide"
      assert text =~ "via @phoenix_kit_current_scope"

      # The placeholder marker never reaches the page.
      refute html =~ HelloLive.slot_marker()
      refute html =~ "Activity.log/1"

      assert has_element?(view, ~s|a[href="/en/admin/hello-world/events"]|, "Events tab")
      assert has_element?(view, ~s|a[href="/en/admin/hello-world/components"]|, "Components")
    end

    test "the last-logged time is one sentence with the time inside", %{conn: conn} do
      conn = put_test_scope(conn, fake_scope(permissions: ["hello_world"]))
      {:ok, view, _html} = live(conn, "/en/admin/hello-world")

      assert render_click(view, "log_demo_event", %{}) =~ ~r/Last logged at \d\d:\d\d:\d\d/
    end
  end

  describe "navigation" do
    test "renders links to Events and Components subpages", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/en/admin/hello-world")

      assert html =~ "Events feed"
      assert html =~ "Components showcase"
    end
  end

  describe "Module Info / Current User cards (Batch 2 i18n delta)" do
    test "renders gettext-wrapped dt labels in both info cards", %{conn: conn} do
      conn = put_test_scope(conn, fake_scope(permissions: ["hello_world"]))

      {:ok, _view, html} = live(conn, "/en/admin/hello-world")

      # Every dt label should appear inside a `<dt …>…</dt>` tag with
      # the exact text the gettext extractor sees as a literal. Long
      # labels wrap onto their own line, so allow surrounding
      # whitespace inside the tag.
      for dt_label <- [
            "Module",
            "Key",
            "Version",
            "Enabled",
            "Email",
            "Roles",
            "Admin?",
            "Module access?",
            "Can moderate?"
          ] do
        regex = Regex.compile!("<dt[^>]*>\\s*#{Regex.escape(dt_label)}\\s*</dt>")

        assert html =~ regex,
               "expected dt label #{inspect(dt_label)} rendered inside a <dt> tag"
      end

      # Card titles
      assert html =~ "Module Info"
      assert html =~ "Current User"
      assert html =~ "Next Steps"
      assert html =~ "Explore the showcase"
    end
  end

  describe "handle_info catch-all (Batch 2 — defensive)" do
    test "swallows unknown OTP messages without crashing", %{conn: conn} do
      conn = put_test_scope(conn, fake_scope(permissions: ["hello_world"]))

      {:ok, view, _html} = live(conn, "/en/admin/hello-world")

      # If the catch-all is removed, this raises FunctionClauseError
      # inside the LV process and the next render/1 call returns an
      # error. With the catch-all in place, the LV stays alive and
      # render returns the same HTML.
      send(view.pid, :unknown_pubsub_event)
      send(view.pid, {:something, :random, "payload"})

      html = render(view)
      assert is_binary(html)
      assert html =~ "Hello World Plugin"
    end
  end
end

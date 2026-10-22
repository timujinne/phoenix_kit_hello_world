defmodule PhoenixKitHelloWorld.Web.EventsLiveTest do
  @moduledoc """
  Tests for the Hello World events feed.

  EventsLive reads `phoenix_kit_activities` through
  `PhoenixKit.Activity.list/1`. `LiveCase` checks the sandbox out in shared
  mode, so rows the test process writes are visible to the LiveView process:
  the populated list, the filter, load-more and clear are all driven for real.
  """
  use PhoenixKitHelloWorld.LiveCase

  alias PhoenixKitHelloWorld.Test.Repo

  @path "/admin/hello-world/events"

  defp log!(action, metadata \\ %{}) do
    {:ok, entry} =
      PhoenixKit.Activity.log("hello_world", action,
        resource_type: "hello_world",
        metadata: Map.merge(%{"source" => "test"}, metadata)
      )

    entry
  end

  defp rows(view),
    do: view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query("#events-feed > div")

  defp row_count(view), do: view |> rows() |> Enum.count()

  defp option_values(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#filter-action option")
    |> LazyHTML.attribute("value")
  end

  describe "empty feed" do
    test "renders the total counter and the empty state", %{conn: conn} do
      {:ok, view, html} = live(conn, @path)

      assert html =~ "0 events"
      assert html =~ "No events recorded yet"
      assert html =~ "Head back to the Overview page"
      assert row_count(view) == 0
    end

    test "renders no page-level header or width cap", %{conn: conn} do
      {:ok, _view, html} = live(conn, @path)

      # `page_title` is rendered once by the admin layout. The page must not
      # render a second in-body title, and must not cap the page-level wrapper.
      refute html =~ "Activity Events"
      refute html =~ "<h2"
      assert html =~ ~s|<div class="flex flex-col px-4 py-6 gap-4">|
    end
  end

  describe "populated feed" do
    test "lists this module's entries with action, mode, details and a detail link", %{
      conn: conn
    } do
      mine = log!("hello_world.demo_event", %{"source" => "showcase_button"})

      {:ok, other} =
        PhoenixKit.Activity.log("some_other_module", "other.thing", resource_type: "thing")

      {:ok, view, _html} = live(conn, @path)

      assert has_element?(view, "#entry-#{mine.uuid}", "hello_world.demo_event")
      assert has_element?(view, "#entry-#{mine.uuid}", "source: showcase_button")
      assert has_element?(view, "#entry-#{mine.uuid} .badge-accent")
      assert has_element?(view, "#entry-#{mine.uuid}", "System")
      assert has_element?(view, "#entry-#{mine.uuid}", "just now")

      assert has_element?(
               view,
               ~s|#entry-#{mine.uuid} a[href="/admin/activity/#{mine.uuid}"][title="View details"]|
             )

      # Scoped to module: "hello_world" — another module's entry is not listed.
      refute has_element?(view, "#entry-#{other.uuid}")
      assert render(view) =~ "1 event"
      refute render(view) =~ "No events recorded yet"
    end

    test "the page reads only on the connected render", %{conn: conn} do
      entry = log!("hello_world.demo_event")

      dead = conn |> get(@path) |> html_response(200)
      refute dead =~ "entry-#{entry.uuid}"

      {:ok, view, _html} = live(conn, @path)
      assert has_element?(view, "#entry-#{entry.uuid}")
    end
  end

  describe "filter" do
    setup %{conn: conn} do
      demo = log!("hello_world.demo_event")
      greeting = log!("hello.greeting")
      {:ok, view, _html} = live(conn, @path)
      {:ok, view: view, demo: demo, greeting: greeting}
    end

    test "choosing an action in the form narrows the list and the count", %{
      view: view,
      demo: demo,
      greeting: greeting
    } do
      assert row_count(view) == 2

      html =
        view
        |> form("#events-filter-form", %{"filter" => %{"action" => "hello.greeting"}})
        |> render_change()

      assert_patched(view, @path <> "?action=hello.greeting")
      assert has_element?(view, "#entry-#{greeting.uuid}")
      refute has_element?(view, "#entry-#{demo.uuid}")
      assert html =~ "1 event"
      assert has_element?(view, ~s|#filter-action option[value="hello.greeting"][selected]|)
    end

    test "an action with no entries shows the filter's own empty state", %{view: view} do
      html =
        view
        |> form("#events-filter-form", %{"filter" => %{"action" => "hello.custom"}})
        |> render_change()

      assert html =~ "No events match this filter."
      refute html =~ "No events recorded yet"
      assert row_count(view) == 0
    end

    test "Clear returns to the unfiltered list", %{view: view, demo: demo, greeting: greeting} do
      view
      |> form("#events-filter-form", %{"filter" => %{"action" => "hello.greeting"}})
      |> render_change()

      refute has_element?(view, "#entry-#{demo.uuid}")

      view |> element(~s|button[phx-click="clear_filters"]|, "Clear") |> render_click()

      assert_patched(view, @path)
      assert has_element?(view, "#entry-#{demo.uuid}")
      assert has_element?(view, "#entry-#{greeting.uuid}")
      refute has_element?(view, "#filter-action option[selected][value^=hello]")
    end

    test "the filter is addressable: the URL alone applies it", %{
      conn: conn,
      demo: demo,
      greeting: greeting
    } do
      {:ok, view, _html} = live(conn, @path <> "?action=hello_world.demo_event")

      assert has_element?(view, "#entry-#{demo.uuid}")
      refute has_element?(view, "#entry-#{greeting.uuid}")
    end

    test "an action outside the module's vocabulary in the URL is no filter", %{
      conn: conn,
      demo: demo,
      greeting: greeting
    } do
      {:ok, view, _html} = live(conn, @path <> "?action=users.%25")

      assert has_element?(view, "#entry-#{demo.uuid}")
      assert has_element?(view, "#entry-#{greeting.uuid}")
    end

    test "the form is core's <.select> inside a form with an id", %{view: view} do
      assert has_element?(view, ~s|form#events-filter-form[phx-change="filter"]|)

      assert has_element?(
               view,
               ~s|#events-filter-form select#filter-action[name="filter[action]"]|
             )

      assert has_element?(view, "#filter-action option", "All Actions")
      assert render(view) =~ ~r/<span[^>]*>\s*Action\s*<\/span>/
    end
  end

  describe "filter options" do
    # enable_system/0 writes a setting with no settings cache running here.
    @tag :capture_log
    test "every action the module's own pages log can be filtered on", %{conn: conn} do
      # Drive the real senders rather than listing actions here: an action
      # added to a page and not to the filter fails this test.
      unless PhoenixKitHelloWorld in PhoenixKit.ModuleRegistry.all_modules() do
        :ok = PhoenixKit.ModuleRegistry.register(PhoenixKitHelloWorld)
        on_exit(fn -> PhoenixKit.ModuleRegistry.unregister(PhoenixKitHelloWorld) end)
      end

      {:ok, _} = PhoenixKitHelloWorld.enable_system()
      user = user_fixture()

      scope =
        fake_scope(
          user_uuid: user.uuid,
          email: user.email,
          permissions: ["hello_world", "hello_world.moderate"]
        )

      conn = put_test_scope(conn, scope)

      {:ok, overview, _html} = live(conn, "/admin/hello-world")
      render_click(overview, "log_demo_event", %{})
      render_click(overview, "log_moderation_event", %{})

      {:ok, notifications, _html} = live(conn, "/admin/hello-world/notifications")
      render_click(notifications, "send_basic", %{})
      render_click(notifications, "send_custom", %{})

      logged =
        Repo.query!(
          "SELECT DISTINCT action FROM phoenix_kit_activities WHERE module = 'hello_world'"
        ).rows
        |> List.flatten()
        |> Enum.sort()

      assert length(logged) == 4

      {:ok, view, _html} = live(conn, @path)
      assert Enum.sort(option_values(view) -- [""]) == logged
    end
  end

  describe "load more" do
    setup %{conn: conn} do
      for n <- 1..25, do: log!("hello_world.demo_event", %{"n" => n})
      {:ok, view, _html} = live(conn, @path)
      {:ok, view: view}
    end

    test "the first page shows 20 of 25 and offers more through core's footer", %{view: view} do
      assert row_count(view) == 20
      assert render(view) =~ "25 events"

      # Core's InfiniteScroll hook, from core's bundle — no page-local script.
      assert has_element?(view, ~s|#events-load-more[phx-hook="InfiniteScroll"]|)
      refute render(view) =~ "<script"
    end

    test "Load more appends the rest and then stops offering", %{view: view} do
      view |> element(~s|#events-load-more button[phx-click="load_more"]|) |> render_click()

      assert row_count(view) == 25
      refute has_element?(view, ~s|#events-load-more button[phx-click="load_more"]|)

      # Nothing left: a further event (a late scroll, a crafted push) is a no-op.
      render_click(view, "load_more", %{})
      assert row_count(view) == 25
    end

    test "changing the filter starts again from the first page", %{view: view} do
      view |> element(~s|#events-load-more button[phx-click="load_more"]|) |> render_click()
      assert row_count(view) == 25

      view
      |> form("#events-filter-form", %{"filter" => %{"action" => "hello_world.demo_event"}})
      |> render_change()

      assert row_count(view) == 20
    end
  end

  describe "handle_info catch-all" do
    test "an unrelated message leaves the feed as it was", %{conn: conn} do
      entry = log!("hello_world.demo_event")
      {:ok, view, _html} = live(conn, @path)

      send(view.pid, :unknown_pubsub_event)
      send(view.pid, {:something, :random, "payload"})

      assert has_element?(view, "#entry-#{entry.uuid}")
      assert render(view) =~ "1 event"
    end
  end
end

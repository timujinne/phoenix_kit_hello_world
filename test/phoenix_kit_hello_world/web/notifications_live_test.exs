defmodule PhoenixKitHelloWorld.Web.NotificationsLiveTest do
  @moduledoc """
  The notifications tour sends through the activity log, the way it tells
  a module to: an entry from the demo actor aimed at the viewer.

  The viewer is a real user row (`user_fixture/0`) because a notification's
  recipient is a foreign key — with a made-up uuid the activity is logged but
  no notification is ever created, and the list stays empty.
  """
  use PhoenixKitHelloWorld.LiveCase

  import ExUnit.CaptureLog

  alias PhoenixKit.Notifications
  alias PhoenixKitHelloWorld.Test.Repo

  @path "/en/admin/hello-world/notifications"
  @custom_text "A fully custom notification from Hello World!"

  setup %{conn: conn} do
    user = user_fixture()
    scope = fake_scope(user_uuid: user.uuid, email: user.email)
    {:ok, conn: put_test_scope(conn, scope), user: user}
  end

  defp unread_badge(view), do: view |> element(".badge-primary") |> render()

  describe "sending" do
    test "Send logs a greeting from the demo actor, aimed at the viewer", %{
      conn: conn,
      user: user
    } do
      {:ok, view, _html} = live(conn, @path)

      html = render_click(view, "send_basic", %{})

      assert_activity_logged("hello.greeting",
        actor_uuid: "00000000-0000-7000-8000-000000000b07",
        metadata_has: %{"greeting" => "Hello there!"}
      )

      [row] =
        Repo.query!(
          "SELECT module, resource_type, target_uuid::text FROM phoenix_kit_activities WHERE action = 'hello.greeting'"
        ).rows

      assert row == ["hello_world", "hello_world_greeting", user.uuid]
      assert html =~ "Sent — check the bell"
      assert Notifications.count_unread(user.uuid) == 1
      assert unread_badge(view) =~ "1 unread"
    end

    test "Send with custom display renders the metadata text in the list", %{conn: conn} do
      {:ok, view, html} = live(conn, @path)
      refute html =~ @custom_text

      html = render_click(view, "send_custom", %{})

      assert html =~ "Sent a custom-display notification."
      assert html =~ @custom_text

      assert_activity_logged("hello.custom",
        metadata_has: %{"notification_icon" => "hero-sparkles"}
      )
    end

    test "without a signed-in viewer nothing is logged and the flash says so" do
      conn = Phoenix.ConnTest.build_conn() |> Plug.Test.init_test_session(%{})
      {:ok, view, _html} = live(conn, @path)

      {html, log} =
        with_log(fn -> render_click(view, "send_basic", %{}) end)

      assert html =~ "Could not send the notification."
      refute html =~ "Sent — check the bell"
      assert log =~ "Demo notification not sent"
      refute_activity_logged("hello.greeting")
    end

    test "the send and bulk buttons disable themselves while the event is in flight", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, @path)

      for event <- ~w(send_basic send_custom mark_all_seen dismiss_all) do
        assert has_element?(view, ~s|button[phx-click="#{event}"][phx-disable-with]|),
               "#{event} has no phx-disable-with"
      end
    end
  end

  describe "managing" do
    setup %{conn: conn} do
      {:ok, view, _html} = live(conn, @path)
      render_click(view, "send_basic", %{})
      render_click(view, "send_custom", %{})
      {:ok, view: view}
    end

    test "Seen marks one notification read and leaves the other unread", %{
      view: view,
      user: user
    } do
      assert unread_badge(view) =~ "2 unread"
      [first | _] = Notifications.recent_for_user(user.uuid, 5)

      view
      |> element(~s|button[phx-click="mark_seen"][phx-value-uuid="#{first.uuid}"]|)
      |> render_click()

      assert unread_badge(view) =~ "1 unread"
      refute has_element?(view, ~s|button[phx-click="mark_seen"][phx-value-uuid="#{first.uuid}"]|)
      assert Notifications.count_unread(user.uuid) == 1
    end

    test "the row's dismiss button removes that notification from the list", %{
      view: view,
      user: user
    } do
      [first | _] = Notifications.recent_for_user(user.uuid, 5)
      selector = ~s|button[phx-click="dismiss"][phx-value-uuid="#{first.uuid}"]|

      view |> element(selector) |> render_click()

      refute has_element?(view, selector)
      assert length(Notifications.recent_for_user(user.uuid, 5)) == 1
    end

    test "Mark all seen clears the unread count but keeps the rows", %{view: view, user: user} do
      view |> element(~s|button[phx-click="mark_all_seen"]|) |> render_click()

      assert unread_badge(view) =~ "0 unread"
      refute has_element?(view, ~s|button[phx-click="mark_seen"]|)
      assert length(Notifications.recent_for_user(user.uuid, 5)) == 2
    end

    test "Dismiss all empties the list and shows the empty state", %{view: view, user: user} do
      html = view |> element(~s|button[phx-click="dismiss_all"]|) |> render_click()

      assert html =~ "No notifications yet"
      refute html =~ @custom_text
      assert Notifications.recent_for_user(user.uuid, 5) == []
    end
  end

  describe "live updates" do
    # Each clause is driven in isolation: the row is written or changed with
    # the Repo directly (no core broadcast), so the page is provably stale
    # until the message under test arrives. The page showing the new state
    # proves that clause re-read — handing it to the catch-all instead leaves
    # the stale render.
    setup %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, @path)
      assert html =~ "No notifications yet"
      n = insert_notification(user)
      assert render(view) =~ "No notifications yet"
      {:ok, view: view, notification: n}
    end

    test ":notification_created shows a notification made elsewhere", %{
      view: view,
      notification: n
    } do
      send(view.pid, {:notification_created, n})
      assert unread_badge(view) =~ "1 unread"
      assert has_element?(view, ~s|button[phx-click="dismiss"][phx-value-uuid="#{n.uuid}"]|)
    end

    test ":notification_updated re-reads the list", %{view: view, notification: n} do
      send(view.pid, {:notification_updated, n})
      assert unread_badge(view) =~ "1 unread"
      assert has_element?(view, ~s|button[phx-click="dismiss"][phx-value-uuid="#{n.uuid}"]|)
    end

    test ":notification_seen drops the unread count", %{view: view, notification: n} do
      send(view.pid, {:notification_created, n})
      assert unread_badge(view) =~ "1 unread"

      stamp(n, :seen_at)
      assert unread_badge(view) =~ "1 unread"
      send(view.pid, {:notification_seen, n})

      assert unread_badge(view) =~ "0 unread"
    end

    test ":notification_dismissed removes the row", %{view: view, notification: n} do
      send(view.pid, {:notification_created, n})
      assert has_element?(view, ~s|button[phx-value-uuid="#{n.uuid}"]|)

      stamp(n, :dismissed_at)
      assert has_element?(view, ~s|button[phx-value-uuid="#{n.uuid}"]|)
      send(view.pid, {:notification_dismissed, n})

      refute has_element?(view, ~s|button[phx-value-uuid="#{n.uuid}"]|)
      assert render(view) =~ "No notifications yet"
    end

    test ":notifications_bulk_updated re-reads after a bulk change", %{
      view: view,
      notification: n
    } do
      send(view.pid, {:notification_created, n})
      assert unread_badge(view) =~ "1 unread"

      stamp(n, :seen_at)
      send(view.pid, {:notifications_bulk_updated, :seen})

      assert unread_badge(view) =~ "0 unread"
    end

    test "an unrelated message is logged at debug and changes nothing", %{view: view} do
      Logger.put_module_level(PhoenixKitHelloWorld.Web.NotificationsLive, :debug)
      on_exit(fn -> Logger.delete_module_level(PhoenixKitHelloWorld.Web.NotificationsLive) end)

      log =
        capture_log([level: :debug], fn ->
          send(view.pid, {:something_else, :entirely})
          # The row inserted in setup is still unknown to the page: the
          # catch-all must not re-read.
          assert render(view) =~ "No notifications yet"
        end)

      assert log =~ "Unhandled info: {:something_else, :entirely}"
    end
  end

  test "a notification core creates elsewhere reaches the page over PubSub", %{
    conn: conn,
    user: user
  } do
    {:ok, view, html} = live(conn, @path)
    assert html =~ "No notifications yet"

    {:ok, _entry} = log_greeting(user.uuid)

    assert unread_badge(view) =~ "1 unread"
  end

  test "the dead render reads nothing; the connected render loads the list", %{
    conn: conn,
    user: user
  } do
    insert_notification(user)

    dead = conn |> get(@path) |> html_response(200)
    assert dead =~ "0 unread"

    {:ok, view, _html} = live(conn, @path)
    assert unread_badge(view) =~ "1 unread"
  end

  test "the notification_types snippet shows the sub_types shape the module declares", %{
    conn: conn
  } do
    {:ok, _view, html} = live(conn, @path)

    for %{sub_types: subs} <- PhoenixKitHelloWorld.notification_types(), sub <- subs do
      assert html =~ ~s|key: &quot;#{sub.key}&quot;|
      assert html =~ ~s|actions: [&quot;#{hd(sub.actions)}&quot;]|
    end

    assert html =~ "sub_types: ["
  end

  defp log_greeting(target_uuid) do
    PhoenixKit.Activity.log("hello_world", "hello.greeting",
      actor_uuid: "00000000-0000-7000-8000-000000000b07",
      resource_type: "hello_world_greeting",
      resource_uuid: Ecto.UUID.generate(),
      target_uuid: target_uuid,
      metadata: %{"actor_role" => "system", "greeting" => "seeded"}
    )
  end

  # A notification row written with the Repo, so core broadcasts nothing: the
  # activity targets nobody (no fan-out), then the row is inserted by hand.
  defp insert_notification(user) do
    {:ok, entry} = log_greeting(nil)

    %Notifications.Notification{}
    |> Notifications.Notification.changeset(%{
      activity_uuid: entry.uuid,
      recipient_uuid: user.uuid
    })
    |> Repo.insert!()
  end

  defp stamp(notification, field) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    notification |> Ecto.Changeset.change([{field, now}]) |> Repo.update!()
  end
end

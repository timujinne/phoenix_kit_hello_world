defmodule PhoenixKitHelloWorld.Web.NotificationsLiveTest do
  @moduledoc """
  The notifications tour sends through the activity log, the way it tells
  a module to: an entry from the demo actor aimed at the viewer.
  """
  use PhoenixKitHelloWorld.LiveCase

  alias PhoenixKitHelloWorld.Test.Repo

  test "Send logs a greeting from the demo actor, aimed at the viewer", %{conn: conn} do
    scope = fake_scope()
    conn = put_test_scope(conn, scope)
    {:ok, view, _html} = live(conn, "/en/admin/hello-world/notifications")

    render_click(view, "send_basic", %{})

    assert_activity_logged("hello.greeting",
      actor_uuid: "00000000-0000-7000-8000-000000000b07",
      metadata_has: %{"greeting" => "Hello there!"}
    )

    [row] =
      Repo.query!(
        "SELECT module, target_uuid::text FROM phoenix_kit_activities WHERE action = 'hello.greeting'"
      ).rows

    assert row == ["hello_world", scope.user.uuid]
  end
end

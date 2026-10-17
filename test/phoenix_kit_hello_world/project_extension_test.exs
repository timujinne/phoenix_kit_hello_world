defmodule PhoenixKitHelloWorld.ProjectExtensionTest do
  @moduledoc """
  Pins the reference `phoenix_kit_project_extensions/0` contract entry.

  This module is the ecosystem's copyable example of the projects-hub
  extension contract (the analogue of the `phoenix_kit_widgets/0` reference
  above it) — these tests keep the reference honest: every field the hub's
  normalizer reads is present, and there is NO dependency on
  `phoenix_kit_projects` (the contract is duck-typed one-way). The tab
  LiveView is mounted for real in `ProjectHelloTabLiveTest` below.
  """

  use ExUnit.Case, async: true

  # The fields `PhoenixKitProjects.Extensions.Extension.from_map/2` reads.
  # `data_retention` is absent on purpose: the hub fixes it to `:keep`.
  @contract_fields [
    :key,
    :name,
    :description,
    :icon,
    :category,
    :module_key,
    :permission,
    :tabs,
    :config_schema,
    :feature_flags,
    :permission_actions,
    :notification_types,
    :on_enable,
    :on_disable,
    :api,
    :default_enabled
  ]

  test "exports the duck-typed provider with a full-contract entry" do
    assert function_exported?(PhoenixKitHelloWorld, :phoenix_kit_project_extensions, 0)

    assert [ext] = PhoenixKitHelloWorld.phoenix_kit_project_extensions()

    for field <- @contract_fields do
      assert Map.has_key?(ext, field), "reference entry is missing #{inspect(field)}"
    end

    assert Map.keys(ext) -- @contract_fields == [],
           "the entry carries a field the hub does not read"

    assert ext.key == "hello_world_tab"
    assert ext.module_key == "hello_world"
    assert ext.default_enabled == false
  end

  test "category names one of the hub's groups" do
    assert [%{category: category}] = PhoenixKitHelloWorld.phoenix_kit_project_extensions()
    assert category in ~w(collaborate documents clients data more)
  end

  test "a write action is declared, so the hub can resolve can_write for the tab" do
    assert [%{permission_actions: actions}] =
             PhoenixKitHelloWorld.phoenix_kit_project_extensions()

    assert :view in actions
    assert Enum.find(actions, &(&1 != :view)) == :greet
  end

  test "the tab key is not one of the project page's own URL segments" do
    reserved = ~w(edit files activity members modules api board gantt calendar tasks comments new)
    assert [%{tabs: [%{key: key}]}] = PhoenixKitHelloWorld.phoenix_kit_project_extensions()
    refute key in reserved
  end

  test "the tab LV exports no handle_params/3 (an off-router mount refuses one)" do
    assert [%{tabs: [%{lv: lv}]}] = PhoenixKitHelloWorld.phoenix_kit_project_extensions()
    assert Code.ensure_loaded?(lv)
    refute function_exported?(lv, :handle_params, 3)
  end

  test "the provider does not depend on phoenix_kit_projects" do
    deps = Mix.Project.config()[:deps] |> Enum.map(&elem(&1, 0))
    refute :phoenix_kit_projects in deps
  end
end

defmodule PhoenixKitHelloWorld.Web.ProjectHelloTabLiveTest do
  @moduledoc """
  Mounts the tab the way the projects hub does: `live_render` off-router,
  everything from the session (`live_isolated/3` is that mount).
  """
  use PhoenixKitHelloWorld.LiveCase

  alias PhoenixKitHelloWorld.Web.ProjectHelloTabLive

  @project "0190aaaa-bbbb-7ccc-8ddd-eeeeeeeeeeee"
  @viewer "0190ffff-bbbb-7ccc-8ddd-eeeeeeeeeeee"

  # The session the hub builds in `ProjectShowLive` for a contributed tab.
  defp hub_session(overrides) do
    Map.merge(
      %{
        "project_uuid" => @project,
        "ext_key" => "hello_world_tab",
        "instance_key" => "default",
        "config" => %{"greeting" => "Ahoy"},
        "can_write" => false,
        "locale" => "en",
        "wrapper_class" => "",
        "current_user_uuid" => @viewer,
        "mode" => :navigate,
        "pubsub_topic" => nil,
        "frame_ref" => nil,
        "host_paths" => %{"new_task" => "/en/admin/projects/#{@project}/assignments/new"}
      },
      overrides
    )
  end

  defp mount_tab(conn, overrides \\ %{}) do
    live_isolated(conn, ProjectHelloTabLive, session: hub_session(overrides))
  end

  test "mounts off-router and shows every session key it was handed", %{conn: conn} do
    {:ok, _view, html} = mount_tab(conn)

    assert html =~ "Hello from a project extension tab"
    assert html =~ @project
    assert html =~ "hello_world_tab / default"
    assert html =~ @viewer
    assert html =~ "greeting"
    assert html =~ "Ahoy"
    assert html =~ "en / navigate"
    assert html =~ "new_task"
  end

  test "mounts from project_uuid alone — every other key is optional", %{conn: conn} do
    {:ok, _view, html} =
      live_isolated(conn, ProjectHelloTabLive, session: %{"project_uuid" => @project})

    assert html =~ @project
    assert html =~ "anonymous"
    assert html =~ "— / default"
    assert html =~ ~s|data-can-write="false"|
  end

  describe "can_write" do
    test "true: the write control is rendered and works", %{conn: conn} do
      {:ok, view, html} = mount_tab(conn, %{"can_write" => true})

      assert html =~ ~s|data-can-write="true"|
      assert html =~ "You can make changes here"

      html = view |> element(~s|button[phx-click="greet"]|) |> render_click()
      assert html =~ "Greeted 1 time"

      html = view |> element(~s|button[phx-click="greet"]|) |> render_click()
      assert html =~ "Greeted 2 times"
    end

    test "false: no write control, and a crafted event is ignored", %{conn: conn} do
      {:ok, view, html} = mount_tab(conn, %{"can_write" => false})

      assert html =~ ~s|data-can-write="false"|
      assert html =~ "Read-only"
      refute has_element?(view, ~s|button[phx-click="greet"]|)

      refute render_click(view, "greet", %{}) =~ "Greeted"
    end

    test "only a real true grants it — absent, nil and \"true\" are read-only", %{conn: conn} do
      for value <- [nil, "true", 1, :absent] do
        overrides = if value == :absent, do: %{}, else: %{"can_write" => value}
        session = hub_session(overrides)
        session = if value == :absent, do: Map.delete(session, "can_write"), else: session

        {:ok, view, html} = live_isolated(conn, ProjectHelloTabLive, session: session)

        assert html =~ ~s|data-can-write="false"|, "can_write #{inspect(value)} granted writes"
        refute render_click(view, "greet", %{}) =~ "Greeted"
      end
    end
  end

  describe "locale" do
    test "a binary locale is set on mount, so the tab renders translated", %{conn: conn} do
      {:ok, _view, html} = mount_tab(conn, %{"locale" => "et"})

      assert html =~ "Tere projekti laienduse vahekaardilt"
      refute html =~ "Hello from a project extension tab"
    end

    test "without a locale the tab renders in the default language", %{conn: conn} do
      for locale <- [nil, ""] do
        {:ok, _view, html} = mount_tab(conn, %{"locale" => locale})
        assert html =~ "Hello from a project extension tab"
      end
    end
  end
end

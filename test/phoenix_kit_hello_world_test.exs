defmodule PhoenixKitHelloWorldTest do
  use ExUnit.Case

  alias PhoenixKit.Dashboard.Tab
  alias PhoenixKit.Users.Permissions

  # `function_exported?/3` answers FALSE for a module that is merely not
  # loaded, not only for one that lacks the function, so a bare callback
  # assertion fails intermittently under a random seed and never when the file
  # runs alone -- the shape that reads as flaky infrastructure and gets re-run
  # instead of fixed. Reproduced in two sibling modules before this went in.
  setup_all do
    Code.ensure_loaded!(PhoenixKitHelloWorld)
    :ok
  end

  # These tests verify that the module correctly implements the
  # PhoenixKit.Module behaviour. Copy and adapt them for your own module.

  describe "behaviour implementation" do
    test "implements PhoenixKit.Module" do
      behaviours =
        PhoenixKitHelloWorld.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert PhoenixKit.Module in behaviours
    end

    test "has @phoenix_kit_module attribute for auto-discovery" do
      attrs = PhoenixKitHelloWorld.__info__(:attributes)
      assert Keyword.get(attrs, :phoenix_kit_module) == [true]
    end
  end

  describe "required callbacks" do
    test "module_key/0 returns a non-empty string" do
      key = PhoenixKitHelloWorld.module_key()
      assert is_binary(key)
      assert key == "hello_world"
    end

    test "module_name/0 returns a non-empty string" do
      name = PhoenixKitHelloWorld.module_name()
      assert is_binary(name)
      assert name == "Hello World"
    end

    test "enabled?/0 returns a boolean" do
      # In test env without DB, this returns false (the rescue fallback)
      assert is_boolean(PhoenixKitHelloWorld.enabled?())
    end

    test "enable_system/0 is exported" do
      assert function_exported?(PhoenixKitHelloWorld, :enable_system, 0)
    end

    test "disable_system/0 is exported" do
      assert function_exported?(PhoenixKitHelloWorld, :disable_system, 0)
    end
  end

  describe "permission_metadata/0" do
    test "returns a map with required fields" do
      meta = PhoenixKitHelloWorld.permission_metadata()
      assert %{key: key, label: label, icon: icon, description: desc} = meta
      assert is_binary(key)
      assert is_binary(label)
      assert is_binary(icon)
      assert is_binary(desc)
    end

    test "key matches module_key" do
      meta = PhoenixKitHelloWorld.permission_metadata()
      assert meta.key == PhoenixKitHelloWorld.module_key()
    end

    test "icon uses hero- prefix" do
      meta = PhoenixKitHelloWorld.permission_metadata()
      assert String.starts_with?(meta.icon, "hero-")
    end
  end

  describe "admin_tabs/0" do
    test "returns a non-empty list of Tab structs" do
      tabs = PhoenixKitHelloWorld.admin_tabs()
      assert is_list(tabs)
      assert length(tabs) >= 4
    end

    test "main tab has all required fields" do
      [main | _] = PhoenixKitHelloWorld.admin_tabs()
      assert main.id == :admin_hello_world
      assert main.label == "Hello World"
      # Tab paths can be relative ("hello-world") or absolute ("/admin/hello-world").
      # PhoenixKit's Tab.resolve_path/2 prepends /admin/ for relative paths at registration.
      assert is_binary(main.path)
      assert main.level == :admin
      assert main.permission == PhoenixKitHelloWorld.module_key()
      assert main.group == :admin_modules
    end

    test "main tab has live_view for route generation" do
      [main | _] = PhoenixKitHelloWorld.admin_tabs()
      assert {PhoenixKitHelloWorld.Web.HelloLive, :index} = main.live_view
    end

    test "all tab paths use hyphens not underscores" do
      for tab <- PhoenixKitHelloWorld.admin_tabs() do
        refute String.contains?(tab.path, "_")
      end
    end

    test "all tabs share the same permission (module_key)" do
      for tab <- PhoenixKitHelloWorld.admin_tabs() do
        assert tab.permission == PhoenixKitHelloWorld.module_key()
      end
    end

    test "all subtabs reference the main tab as parent" do
      [main | subtabs] = PhoenixKitHelloWorld.admin_tabs()

      for tab <- subtabs do
        assert tab.parent == main.id
      end
    end

    test "includes Events subtab pointing to EventsLive" do
      tabs = PhoenixKitHelloWorld.admin_tabs()
      events = Enum.find(tabs, &(&1.id == :admin_hello_world_events))

      assert events != nil
      assert events.label == "Events"
      assert events.path == "hello-world/events"
      assert events.live_view == {PhoenixKitHelloWorld.Web.EventsLive, :index}
    end

    test "includes Components subtab pointing to ComponentsLive" do
      tabs = PhoenixKitHelloWorld.admin_tabs()
      components = Enum.find(tabs, &(&1.id == :admin_hello_world_components))

      assert components != nil
      assert components.label == "Components"
      assert components.path == "hello-world/components"
      assert components.live_view == {PhoenixKitHelloWorld.Web.ComponentsLive, :index}
    end
  end

  describe "version/0" do
    test "returns a version string" do
      version = PhoenixKitHelloWorld.version()
      assert is_binary(version)
      # Compare against mix.exs so version bumps can't silently break this test.
      assert version == Mix.Project.config()[:version]
    end
  end

  describe "css_sources/0" do
    test "returns a list with the OTP app atom" do
      sources = PhoenixKitHelloWorld.css_sources()
      assert sources == [:phoenix_kit_hello_world]
    end
  end

  describe "optional callbacks have defaults" do
    test "get_config/0 returns a map" do
      config = PhoenixKitHelloWorld.get_config()
      assert is_map(config)
      assert Map.has_key?(config, :enabled)
    end

    test "settings_tabs/0 returns empty list" do
      assert PhoenixKitHelloWorld.settings_tabs() == []
    end

    test "user_dashboard_tabs/0 returns empty list" do
      assert PhoenixKitHelloWorld.user_dashboard_tabs() == []
    end

    test "children/0 returns empty list" do
      assert PhoenixKitHelloWorld.children() == []
    end

    test "route_module/0 returns nil" do
      assert PhoenixKitHelloWorld.route_module() == nil
    end

    test "required_integrations/0 returns empty list" do
      assert PhoenixKitHelloWorld.required_integrations() == []
    end

    test "integration_providers/0 returns empty list" do
      assert PhoenixKitHelloWorld.integration_providers() == []
    end
  end

  describe "sub-permission" do
    test "one sub-permission is declared under the base key" do
      assert %{sub_permissions: [sub]} = PhoenixKitHelloWorld.permission_metadata()
      assert %{key: "moderate", label: "Moderate", description: description} = sub
      assert description != ""

      # The key callers hand to Scope.can?/2 is the composed one.
      assert PhoenixKitHelloWorld.moderate_permission() == "hello_world.moderate"
    end

    test "core accepts the declaration and resolves the composed key to this module" do
      registered? = PhoenixKitHelloWorld in PhoenixKit.ModuleRegistry.all_modules()
      unless registered?, do: :ok = PhoenixKit.ModuleRegistry.register(PhoenixKitHelloWorld)

      on_exit(fn ->
        unless registered?, do: PhoenixKit.ModuleRegistry.unregister(PhoenixKitHelloWorld)
      end)

      assert [%{key: "hello_world.moderate"}] =
               Permissions.sub_permissions_for("hello_world")

      assert Permissions.parent_key("hello_world.moderate") == "hello_world"
    end
  end

  describe "translated labels" do
    setup do
      previous = Gettext.get_locale(PhoenixKitHelloWorld.Gettext)
      on_exit(fn -> Gettext.put_locale(PhoenixKitHelloWorld.Gettext, previous) end)
      :ok
    end

    test "every tab and the permission entry name this module's backend" do
      for tab <- PhoenixKitHelloWorld.admin_tabs() do
        assert tab.gettext_backend == PhoenixKitHelloWorld.Gettext, "#{tab.id} has no backend"
        assert tab.gettext_domain == "default"
      end

      meta = PhoenixKitHelloWorld.permission_metadata()
      assert meta.gettext_backend == PhoenixKitHelloWorld.Gettext
      assert meta.gettext_domain == "default"
    end

    test "every label declared as data is pinned for the extractor" do
      meta = PhoenixKitHelloWorld.permission_metadata()

      declared =
        Enum.map(PhoenixKitHelloWorld.admin_tabs(), & &1.label) ++
          [meta.label | Enum.map(meta.sub_permissions, & &1.label)]

      assert Enum.sort(Enum.uniq(declared)) ==
               Enum.sort(PhoenixKitHelloWorld.translatable_labels())
    end

    test "every pinned label has a real et and ru translation" do
      # Each label core translates at render must come back changed in each
      # shipped locale. "Hello World" is the module's name and stays as it is.
      for locale <- ~w(et ru),
          label <- PhoenixKitHelloWorld.translatable_labels() -- ["Hello World"] do
        Gettext.put_locale(PhoenixKitHelloWorld.Gettext, locale)

        translated = Gettext.dgettext(PhoenixKitHelloWorld.Gettext, "default", label)
        assert translated != label, "#{inspect(label)} is untranslated in #{locale}"
      end
    end

    test "core's tab renderer translates a sidebar label through this backend" do
      events = Enum.find(PhoenixKitHelloWorld.admin_tabs(), &(&1.id == :admin_hello_world_events))

      Gettext.put_locale(PhoenixKitHelloWorld.Gettext, "et")
      assert Tab.localized_label(events) == "Sündmused"

      Gettext.put_locale(PhoenixKitHelloWorld.Gettext, "ru")
      assert Tab.localized_label(events) == "События"

      Gettext.put_locale(PhoenixKitHelloWorld.Gettext, "en")
      assert Tab.localized_label(events) == "Events"
    end

    test "every extracted msgid resolves to a translation in et and ru" do
      # Enumerate from the template the extractor wrote, then ask the real
      # backend. `lgettext/5` answers `{:default, _}` for a msgid with no
      # translation — an empty msgstr, or a fuzzy one, which Gettext ignores —
      # and `{:ok, _}` / `{:missing_bindings, _, _}` for one that has it.
      backend = PhoenixKitHelloWorld.Gettext
      messages = Expo.PO.parse_file!("priv/gettext/default.pot").messages
      assert length(messages) > 300

      untranslated =
        for locale <- ~w(et ru), message <- messages, reduce: [] do
          acc ->
            msgid = IO.iodata_to_binary(message.msgid)

            result =
              case message do
                %Expo.Message.Plural{msgid_plural: plural} ->
                  backend.lngettext(
                    locale,
                    "default",
                    nil,
                    msgid,
                    IO.iodata_to_binary(plural),
                    5,
                    %{}
                  )

                %Expo.Message.Singular{} ->
                  backend.lgettext(locale, "default", nil, msgid, %{})
              end

            if match?({:default, _}, result), do: [{locale, msgid} | acc], else: acc
        end

      assert untranslated == []
    end

    test "the package ships its catalogue" do
      assert "priv" in Mix.Project.config()[:package][:files]
    end
  end

  describe "resource_links/0" do
    test "declares a raw path for the resource type the module logs with a uuid" do
      assert PhoenixKitHelloWorld.resource_links() ==
               %{"hello_world_greeting" => "/admin/hello-world/notifications"}
    end

    test "core's resolver turns a logged greeting into a link to the notifications page" do
      registered? = PhoenixKitHelloWorld in PhoenixKit.ModuleRegistry.all_modules()
      unless registered?, do: :ok = PhoenixKit.ModuleRegistry.register(PhoenixKitHelloWorld)

      on_exit(fn ->
        unless registered?, do: PhoenixKit.ModuleRegistry.unregister(PhoenixKitHelloWorld)
      end)

      uuid = "0190aaaa-bbbb-7ccc-8ddd-eeeeeeeeeeee"
      entry = %{resource_type: "hello_world_greeting", resource_uuid: uuid, metadata: %{}}

      context = PhoenixKit.ResourceLinks.resolve([entry])
      info = PhoenixKit.ResourceLinks.info_for(context, "hello_world_greeting", uuid)

      # `prefixed: true` — an internal route; the renderer applies the URL
      # prefix and locale once.
      assert %{path: "/admin/hello-world/notifications", prefixed: true} = info

      assert PhoenixKit.ResourceLinks.url(info) ==
               PhoenixKitHelloWorld.Paths.notifications()
    end

    test "the rich resolver exists and is empty for a module with no records" do
      assert PhoenixKitHelloWorld.resolve_comment_resources([
               "0190aaaa-bbbb-7ccc-8ddd-eeeeeeeeeeee"
             ]) ==
               %{}
    end
  end

  describe "Paths" do
    alias PhoenixKitHelloWorld.Paths

    test "index/0 returns a path string pointing to the Hello World module" do
      path = Paths.index()
      assert is_binary(path)
      assert String.contains?(path, "hello-world")
    end

    test "events/0 returns the events subpath" do
      path = Paths.events()
      assert is_binary(path)
      assert String.ends_with?(path, "hello-world/events")
    end

    test "components/0 returns the components subpath" do
      path = Paths.components()
      assert is_binary(path)
      assert String.ends_with?(path, "hello-world/components")
    end

    test "all Paths helpers return prefix-aware strings" do
      # Paths.index should be a prefix of sub-paths, but index ends with
      # "hello-world" while events ends with "hello-world/events", so the
      # index path is a prefix of the events path.
      assert String.starts_with?(Paths.events(), Paths.index())
      assert String.starts_with?(Paths.components(), Paths.index())
    end
  end
end

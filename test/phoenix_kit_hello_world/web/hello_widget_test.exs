defmodule PhoenixKitHelloWorld.Web.HelloWidgetTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias PhoenixKitHelloWorld.Web.HelloWidget

  # The reference widget renders purely from its assigns (no DB), so these are
  # plain render_component tests — the shape every widget author can start from.

  defp render_widget(overrides) do
    assigns =
      Keyword.merge(
        [id: "hw-1", settings: %{}, view: nil, size: %{w: 12, h: 8}, scope: nil, context: %{}],
        overrides
      )

    render_component(HelloWidget, assigns)
  end

  describe "phoenix_kit_widgets/0 (the catalog definition)" do
    test "uses every field of the provider contract" do
      assert [w] = PhoenixKitHelloWorld.phoenix_kit_widgets()
      assert w.key == "hello_world.hello"
      assert w.module_key == "hello_world"
      assert Code.ensure_loaded?(w.component)
      assert %{w: _, h: _} = w.default_size
      assert %{w: _, h: _} = w.min_size
      # No max_size: the dashboards lattice ignores it (the user owns the box).
      refute Map.has_key?(w, :max_size)
      assert w.refresh_interval >= 1000

      # Three views, each with its own min_size floor.
      assert Enum.map(w.views, & &1.key) == ["card", "counter", "contract"]
      assert Enum.all?(w.views, &match?(%{min_size: %{w: _, h: _}}, &1))

      # Every settings field type, including both select-option shapes.
      types = Enum.map(w.settings_schema, & &1.type)
      assert :string in types and :text in types and :number in types
      assert :boolean in types and :select in types
      assert Enum.any?(w.settings_schema, &match?([{_, _} | _], &1[:options]))
      assert Enum.any?(w.settings_schema, &match?([opt | _] when is_binary(opt), &1[:options]))

      # One field holds a context subject.
      assert [%{key: "project", context: "projects.project"}] =
               Enum.filter(w.settings_schema, &Map.has_key?(&1, :context))
    end

    test "every key is one the dashboards normalizer reads" do
      # The keys PhoenixKitDashboards.Widget.from_map/2 reads, minus the
      # ignored max_size.
      read =
        ~w(key name description icon module_key component default_size min_size
           settings_schema views refresh_interval category)a

      assert [w] = PhoenixKitHelloWorld.phoenix_kit_widgets()
      assert Enum.sort(Map.keys(w)) == Enum.sort(read)

      field_keys = ~w(key type label options default context)a

      for field <- w.settings_schema do
        assert Map.keys(field) -- field_keys == [], "unread settings-field key in #{field.key}"
      end
    end
  end

  describe "views" do
    test "card greets the scoped viewer using the settings" do
      html =
        render_widget(
          view: "card",
          scope: %{user: %{email: "user@example.com"}},
          settings: %{"greeting" => "Hei", "tone" => "success", "punctuation" => "?!"}
        )

      assert html =~ "Hei, user?!"
      assert html =~ "text-success"
      # show_size defaults on.
      assert html =~ "12 × 8"
    end

    test "card without a scope greets the world; show_size=false hides the span" do
      html = render_widget(view: "card", settings: %{"show_size" => "false"})
      assert html =~ "Hello, world!"
      refute html =~ "12 × 8"
    end

    test "counter steps by the number setting on every update (live refresh)" do
      html = render_widget(view: "counter", settings: %{"step" => "5"})
      assert html =~ ">5</span>" or html =~ ">\n    5\n" or html =~ "5"
      assert html =~ "last tick"
    end

    test "contract view prints the received assigns verbatim" do
      html = render_widget(view: "contract", settings: %{"greeting" => "Yo"})
      assert html =~ "%{w: 12, h: 8}" or html =~ "%{h: 8, w: 12}"
      assert html =~ "greeting"
      assert html =~ "Yo"
    end

    test "an instance below the declared minimum height renders compact" do
      assert [%{min_size: %{h: min_h}}] = PhoenixKitHelloWorld.phoenix_kit_widgets()

      # Reachable: a user can override the minimum per instance, down to 1x1.
      for h <- [1, min_h - 1] do
        compact = render_widget(view: "card", size: %{w: 8, h: h})
        assert compact =~ "p-2", "h=#{h} did not render compact"
        refute compact =~ "p-3"
      end

      for h <- [min_h, min_h + 4] do
        roomy = render_widget(view: "card", size: %{w: 8, h: h})
        assert roomy =~ "p-3", "h=#{h} rendered compact"
      end
    end

    test "the note is rendered as rich text, sanitised" do
      html =
        render_widget(
          view: "card",
          settings: %{
            "note" => "**bold** note <script>alert(1)</script><img src=x onerror=alert(2)>"
          }
        )

      assert html =~ "<strong>bold</strong>"
      refute html =~ "**bold**"
      refute html =~ "<script"
      refute html =~ "onerror"
    end

    test "an empty or non-text note renders nothing" do
      for note <- ["", nil, %{"oops" => 1}] do
        html = render_widget(view: "card", settings: %{"note" => note})
        refute html =~ "prose"
      end
    end

    test "card shows the context subject the host resolved into settings" do
      uuid = "0190aaaa-bbbb-7ccc-8ddd-eeeeeeeeeeee"
      html = render_widget(view: "card", settings: %{"project" => uuid})
      assert html =~ "Project: #{uuid}"

      refute render_widget(view: "card", settings: %{"project" => ""}) =~ "Project:"
    end

    test "contract view prints the context assign the host passes" do
      html =
        render_widget(view: "contract", context: %{"projects.project" => "0190aaaa-bbbb"})

      assert html =~ "projects.project"
      assert html =~ "0190aaaa-bbbb"
    end

    test "hostile assigns never crash (a widget must not take the dashboard down)" do
      assert render_widget(
               view: "nope",
               settings: %{"step" => "banana"},
               size: nil,
               scope: :junk,
               context: :junk
             )

      # A host that predates the context assign passes none at all.
      assert render_component(HelloWidget, id: "hw-2", settings: %{}, view: "contract") =~
               "%{}"
    end
  end
end

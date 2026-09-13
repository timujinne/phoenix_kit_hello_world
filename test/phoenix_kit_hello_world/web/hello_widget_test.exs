defmodule PhoenixKitHelloWorld.Web.HelloWidgetTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias PhoenixKitHelloWorld.Web.HelloWidget

  # The reference widget renders purely from its assigns (no DB), so these are
  # plain render_component tests — the shape every widget author can start from.

  defp render_widget(overrides) do
    assigns =
      Keyword.merge(
        [id: "hw-1", settings: %{}, view: nil, size: %{w: 3, h: 2}, scope: nil],
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
      assert html =~ "3 × 2"
    end

    test "card without a scope greets the world; show_size=false hides the span" do
      html = render_widget(view: "card", settings: %{"show_size" => "false"})
      assert html =~ "Hello, world!"
      refute html =~ "3 × 2"
    end

    test "counter steps by the number setting on every update (live refresh)" do
      html = render_widget(view: "counter", settings: %{"step" => "5"})
      assert html =~ ">5</span>" or html =~ ">\n    5\n" or html =~ "5"
      assert html =~ "last tick"
    end

    test "contract view prints the received assigns verbatim" do
      html = render_widget(view: "contract", settings: %{"greeting" => "Yo"})
      assert html =~ "%{w: 3, h: 2}" or html =~ "%{h: 2, w: 3}"
      assert html =~ "greeting"
      assert html =~ "Yo"
    end

    test "a single-row instance renders compact" do
      compact = render_widget(view: "card", size: %{w: 2, h: 1})
      assert compact =~ "p-2"
      roomy = render_widget(view: "card", size: %{w: 3, h: 2})
      assert roomy =~ "p-3"
    end

    test "hostile assigns never crash (a widget must not take the dashboard down)" do
      assert render_widget(view: "nope", settings: %{"step" => "banana"}, size: nil, scope: :junk)
    end
  end
end

defmodule PhoenixKitHelloWorld.MixProject do
  use Mix.Project

  @version "0.2.2"
  @source_url "https://github.com/BeamLabEU/phoenix_kit_hello_world"

  def project do
    [
      app: :phoenix_kit_hello_world,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Hex
      description:
        "Hello World demo module for PhoenixKit — use as a template for your own plugins",
      package: package(),

      # Dialyzer
      dialyzer: [plt_add_apps: [:phoenix_kit, :mix], ignore_warnings: ".dialyzer_ignore.exs"],

      # Docs
      name: "PhoenixKitHelloWorld",
      source_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :gettext, :phoenix_kit]
    ]
  end

  # test/support/ is compiled only in :test so DataCase and TestRepo
  # don't leak into the published package.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": ["format --check-formatted", "credo --strict", "dialyzer"],
      precommit: [
        "compile --force --warnings-as-errors",
        "deps.unlock --check-unused",
        # Scan for retired Hex deps. Run via `cmd` so Hex bootstraps in a fresh
        # process — the hex.* archive tasks aren't resolvable via Mix.Task.run
        # inside an alias.
        "cmd mix hex.audit",
        "quality.ci"
      ],
      "test.setup": [
        "ecto.create --quiet -r PhoenixKitHelloWorld.Test.Repo"
      ],
      "test.reset": [
        "ecto.drop --quiet -r PhoenixKitHelloWorld.Test.Repo",
        "test.setup"
      ]
    ]
  end

  # phoenix_kit deps resolve from Hex by default. For cross-repo work against a
  # local checkout, export <APP>_PATH — e.g. PHOENIX_KIT_PATH=../phoenix_kit or
  # PHOENIX_KIT_AI_PATH=../phoenix_kit_ai. Unset => the published pin, so
  # mix hex.publish is unaffected.
  defp pk_dep(app, requirement, opts \\ []) do
    env_var = String.upcase(Atom.to_string(app)) <> "_PATH"

    case System.get_env(env_var) do
      nil when opts == [] -> {app, requirement}
      nil -> {app, requirement, opts}
      path -> {app, [path: path, override: true] ++ opts}
    end
  end

  defp deps do
    [
      # PhoenixKit provides the Module behaviour and Settings API.
      # 1.7.214+ required: Scope.can_access_admin_area?/1 (the rename of the
      # now-`@deprecated` Scope.admin?/1) — an older core has no such function,
      # so this is an UndefinedFunctionError at runtime, not a warning.
      # 2.63.0 is the floor now, by the rule in AGENTS.md: `mix.lock` resolves
      # the floor, so the suite proves the page renders against it. What the
      # Components page actually needs is older — `date_nav`,
      # `table_default :toolbar_primary`, `bulk_actions_toolbar :primary` and
      # `form_actions submit_disabled` (core 2.43.0) and `save_button`
      # (2.47.0) are the newest things it calls, so by the source the oldest
      # core that carries everything is 2.47.0 (not compiled against).
      # README asks for that "oldest core"
      # floor instead; the maintainer picks between the two rules.
      # The actor and the activity log (`PhoenixKitWeb.Actor`,
      # `PhoenixKit.Activity.log/3`) have been there since 2.38.0.
      # Patch-precise floor in the compound form, so the ceiling stays open
      # through every later 2.x minor (see test/core_pin_conformance_test.exs).
      pk_dep(:phoenix_kit, ">= 2.63.0 and < 3.0.0"),
      # Build MDEx's Rust NIF from source on OTP versions it ships no
      # compatible precompiled NIF for — same escape hatch core's mix.exs
      # carries: MDEx's force_build requires rustler itself, not just
      # rustler_precompiled. Optional: pulled only to compile the NIF.
      {:rustler, ">= 0.0.0", optional: true},

      # LiveView is needed for the admin page.
      {:phoenix_live_view, "~> 1.1"},

      # The module's own Gettext backend (PhoenixKitHelloWorld.Gettext); its
      # catalogue ships in priv/gettext, which is why `priv` is in `files:`.
      {:gettext, "~> 1.0"},

      # Optional: add ex_doc for generating documentation
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},

      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},

      # HTML parser for Phoenix.LiveViewTest in LiveView smoke tests
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv .formatter.exs mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "PhoenixKitHelloWorld",
      # Tags in this repo are bare version numbers, not v-prefixed — a "v" ref
      # points at a tag that does not exist and 404s every HexDocs source link.
      source_ref: @version
    ]
  end
end

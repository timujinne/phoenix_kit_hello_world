defmodule PhoenixKitHelloWorld.Web.HelloWidget do
  @moduledoc """
  The **reference dashboard widget** — a live example of every capability in the
  `phoenix_kit_dashboards` widget API, in one component. If you're writing a
  widget for your own module, copy this file and the definition in
  `PhoenixKitHelloWorld.phoenix_kit_widgets/0`.

  ## What a widget IS

  A plain `Phoenix.LiveComponent`. The dashboards host renders it as:

      <.live_component
        module={HelloWidget}
        id={instance_id}
        settings={%{"greeting" => "Hi", ...}}  # this instance's saved settings
        view={"card" | "counter" | "contract"} # the selected render variant
        size={%{w: 12, h: 8}}                  # the instance's current span, in
                                               # lattice cells (25px nominal squares)
        scope={@phoenix_kit_current_scope}     # the viewer — personalize with it
        context={%{"projects.project" => id}}  # what the page is about; %{} on
                                               # a context-free dashboard
      />

  `settings` arrives already resolved: for a settings field declared with
  `context:` the host writes the page's (or the viewer's) subject id into that
  field before render, so a widget reads its subject from `settings` like any
  other value. The `context` assign is the whole bag, for a widget that wants
  more than its own fields; nothing requires reading it.

  It runs inside the host LiveView's process (LiveComponents have no process of
  their own). When the catalog entry declares a `refresh_interval`, the host
  re-`send_update/2`s the component on that cadence — `update/2` runs again and
  any state kept in the socket persists between ticks (the counter view uses
  exactly that).

  ## The three views (each declares its own `min_size` in the catalog entry)

  - `"card"` — a greeting card built from the settings (the simple case).
  - `"counter"` — proves live refresh: counts host ticks and shows the last
    tick time, stepping by the `"step"` setting.
  - `"contract"` — the living documentation: prints the exact assigns this
    component received, so you can SEE the contract on a real dashboard.

  ## Notes for widget authors

  - No DB guard here on purpose: this widget renders purely from its assigns.
    The dashboards Registry already gates visibility on `module_key` (module
    enabled + permission), so an in-component `enabled?/0` guard is only needed
    when the widget queries data of its own (see the projects widgets).
  - Render defensively: every setting read uses a default, `size`/`view`/`scope`
    may be nil, and a widget must NEVER crash the host dashboard.
  - `min_size` is a recommendation, not a guarantee: a user may override it
    per instance down to 1×1. An instance shorter than this widget's declared
    minimum height renders compact — tighter paddings, smaller text — so
    the undersized box still shows its content without scrollbars.
  - A `:text` setting is edited in the host's rich editor, so its value is
    rich content (Markdown or HTML). Render it through core's `<.markdown>`,
    which sanitises by default — never `raw/1` a user's text.
  """
  use Phoenix.LiveComponent
  use Gettext, backend: PhoenixKitHelloWorld.Gettext

  import PhoenixKitWeb.Components.Core.Markdown, only: [markdown: 1]

  # The `min_size.h` this widget declares in `phoenix_kit_widgets/0`. Keep the
  # two in step: below it the instance is undersized and renders compact.
  @min_height 4

  @impl true
  def update(assigns, socket) do
    settings = assigns[:settings] || %{}
    size = assigns[:size]

    # Live-refresh state: `update/2` runs on every host tick; assigns kept in
    # the socket persist between ticks, so this is a real counter.
    ticks = (socket.assigns[:ticks] || 0) + step(settings)

    {:ok,
     socket
     |> assign(:id, assigns.id)
     |> assign(:settings, settings)
     |> assign(:view, assigns[:view] || "card")
     |> assign(:size, size)
     |> assign(:scope, assigns[:scope])
     |> assign(:context, context(assigns[:context]))
     |> assign(:greeting, Map.get(settings, "greeting", "Hello"))
     |> assign(:note, text(Map.get(settings, "note")))
     |> assign(:project, text(Map.get(settings, "project")))
     |> assign(:tone, tone_class(Map.get(settings, "tone", "")))
     |> assign(:punctuation, Map.get(settings, "punctuation", "!"))
     |> assign(:show_size, Map.get(settings, "show_size", true) in [true, "true"])
     |> assign(:who, viewer_name(assigns[:scope]))
     |> assign(:ticks, ticks)
     |> assign(:ticked_at, DateTime.utc_now())
     |> assign(:compact, compact?(size))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "card h-full overflow-hidden bg-base-100",
      "flex flex-col",
      if(@compact, do: "p-2", else: "p-3")
    ]}>
      <div class={["flex items-center gap-2", if(@compact, do: "mb-1", else: "mb-2")]}>
        <span aria-hidden="true">👋</span>
        <h3 class={["truncate font-semibold", if(@compact, do: "text-xs", else: "text-sm")]}>
          {gettext("Hello world")}
        </h3>
        <span class="ml-auto badge badge-ghost badge-xs">{@view}</span>
      </div>

      <div class="min-h-0 flex-1 overflow-hidden">
        <%!-- view "card": settings-driven greeting (string/text/select settings) --%>
        <div :if={@view == "card"} class="flex h-full flex-col items-center justify-center gap-1 text-center">
          <p class={["font-semibold", @tone, if(@compact, do: "text-lg", else: "text-2xl")]}>
            {@greeting}, {@who}{@punctuation}
          </p>
          <%!-- A :text setting is rich content from the host's editor:
          core's <.markdown> renders it and sanitises the result. --%>
          <.markdown :if={@note != ""} content={@note} compact class="text-xs text-base-content/60" />
          <%!-- The `context:` field: on a page about a project the host has
          already written that project's id into settings["project"]. --%>
          <p :if={@project != ""} class="text-[11px] text-base-content/40 break-all">
            {gettext("Project: %{id}", id: @project)}
          </p>
          <p :if={@show_size and @size} class="text-[11px] text-base-content/40 tabular-nums">
            {gettext("%{w} × %{h} cells", w: @size.w, h: @size.h)}
          </p>
        </div>

        <%!-- view "counter": proves refresh_interval — host ticks re-run update/2
        and socket assigns persist, so the count climbs while you watch --%>
        <div :if={@view == "counter"} class="flex h-full flex-col items-center justify-center gap-1 text-center">
          <span class={["font-bold tabular-nums", @tone, if(@compact, do: "text-2xl", else: "text-4xl")]}>
            {@ticks}
          </span>
          <p class="text-[11px] text-base-content/40 tabular-nums">
            {gettext("last tick %{time}", time: Calendar.strftime(@ticked_at, "%H:%M:%S"))}
          </p>
        </div>

        <%!-- view "contract": the living documentation — the assigns this
        component actually received from the host, verbatim --%>
        <dl :if={@view == "contract"} class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 font-mono text-xs">
          <dt class="text-base-content/50">view</dt>
          <dd class="truncate">{inspect(@view)}</dd>
          <dt class="text-base-content/50">size</dt>
          <dd class="truncate">{inspect(@size)}</dd>
          <dt class="text-base-content/50">scope</dt>
          <dd class="truncate">
            {if @who == default_who(), do: "(none)", else: "user: " <> @who}
          </dd>
          <dt class="text-base-content/50">context</dt>
          <dd class="whitespace-pre-wrap break-all">{inspect(@context, pretty: true)}</dd>
          <dt class="text-base-content/50">settings</dt>
          <dd class="whitespace-pre-wrap break-all">{inspect(@settings, pretty: true)}</dd>
        </dl>
      </div>
    </div>
    """
  end

  # `step` demonstrates a :number setting — form values arrive as strings.
  defp step(settings) do
    case Integer.parse(to_string(settings["step"] || "")) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  # `tone` demonstrates a :select with {label, value} tuples — the stored value
  # is the machine key, the label is what the settings form shows.
  defp tone_class("primary"), do: "text-primary"
  defp tone_class("success"), do: "text-success"
  defp tone_class("warning"), do: "text-warning"
  defp tone_class(_default), do: "text-base-content"

  # `scope` is the personalization hook: the host passes the viewer's scope, so
  # a widget can address the current user. Always pattern-match defensively.
  defp viewer_name(%{user: %{email: email}}) when is_binary(email) do
    email |> String.split("@") |> List.first()
  end

  defp viewer_name(_scope), do: default_who()

  defp default_who, do: gettext("world")

  defp compact?(%{h: h}) when is_integer(h), do: h < @min_height
  defp compact?(_size), do: false

  # A settings value is whatever was stored — read it as text or as nothing.
  defp text(value) when is_binary(value), do: value
  defp text(_value), do: ""

  # The host passes a map of context kind => id; anything else is no context.
  defp context(%{} = context), do: context
  defp context(_other), do: %{}
end

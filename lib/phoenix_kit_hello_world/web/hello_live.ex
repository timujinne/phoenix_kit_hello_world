defmodule PhoenixKitHelloWorld.Web.HelloLive do
  @moduledoc """
  Admin LiveView for the Hello World plugin module — the "landing page" of the showcase.

  This is the page users see when they click the "Hello World" tab in the admin sidebar.
  PhoenixKit wraps it in the admin layout automatically — you get the sidebar, header,
  and theme for free.

  ## How routing works

  You do NOT need to add routes manually. The `live_view` field in
  `PhoenixKitHelloWorld.admin_tabs/0` tells PhoenixKit to generate:

      live "/admin/hello-world", PhoenixKitHelloWorld.Web.HelloLive, :index

  at compile time, inside the admin `live_session` with the admin layout applied.

  ## Activity logging demo

  The "Log demo event" button below shows the canonical PhoenixKit activity logging
  pattern. Every mutating operation in your module should log an activity so actions
  are auditable in the Events tab and the global /admin/activity page.

  See `log_demo_event/1` for the pattern: core's `PhoenixKit.Activity.log/3`
  (module key, action, options — it never raises) with the acting user read
  by `PhoenixKitWeb.Actor`.

  ## Two permission checks, side by side

  "Log demo event" is gated on the module's **base** permission
  (`Scope.has_module_access?/2`): whoever may enter the module may use it.
  "Log moderation event" is gated on the module's **sub-permission**
  `"hello_world.moderate"` with `Scope.can?/2`: a role needs that extra grant.
  Both controls are hidden without the permission AND both event handlers
  check again, because a hidden button does not stop a crafted event.

  ## Sentences with a link or a code span inside

  A sentence is ONE translatable string, placeholder included — word order
  differs between languages, so a sentence assembled from translated
  fragments around a link cannot be translated correctly. `<.inline>` (below)
  renders such a sentence with markup in the placeholder's position.

  ## Assigns available

  PhoenixKit's `on_mount` hooks inject these assigns into every admin LiveView:

  - `@phoenix_kit_current_scope` — the authenticated user's scope (role, permissions)
  - `@phoenix_kit_current_user` — the authenticated user struct (has `.uuid`, `.email`, etc.)
  - `@current_locale` — the current locale string
  - `@url_path` — the current URL path (used for active nav highlighting)
  """
  use PhoenixKitWeb, :live_view
  use Gettext, backend: PhoenixKitHelloWorld.Gettext

  require Logger

  alias PhoenixKit.Users.Auth.Scope
  alias PhoenixKitHelloWorld.Paths

  @demo_event_snippet """
  PhoenixKit.Activity.log(
    "hello_world",
    "hello_world.demo_event",
    PhoenixKitWeb.Actor.opts(socket) ++
      [resource_type: "hello_world", metadata: %{"source" => "showcase_button"}]
  )
  """

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns[:phoenix_kit_current_scope]

    {:ok,
     assign(socket,
       page_title: gettext("Hello World"),
       user_email: scope && scope.user && scope.user.email,
       user_roles: scope && Scope.user_roles(scope),
       is_admin: scope && Scope.can_access_admin_area?(scope),
       # Base key: a lookup in the scope's cached permission set.
       module_access: scope && Scope.has_module_access?(scope, "hello_world"),
       can_moderate: false,
       module_enabled: false,
       last_logged_at: nil,
       demo_event_snippet: @demo_event_snippet
     )}
  end

  # `enabled?/0` reads from the settings table, and so does `Scope.can?/2`
  # (a sub-permission is only effective while its module is enabled) — keep
  # both out of `mount/3` (which fires on both HTTP and WebSocket) and resolve
  # them once here.
  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply,
     assign(socket,
       module_enabled: PhoenixKitHelloWorld.enabled?(),
       can_moderate: can_moderate?(socket)
     )}
  end

  @impl true
  def handle_event("log_demo_event", _params, socket) do
    if socket.assigns[:module_access] do
      log_and_report(socket, "hello_world.demo_event", "showcase_button")
    else
      {:noreply, put_flash(socket, :error, gettext("You do not have permission to log events."))}
    end
  end

  # Re-checked against the live scope, not the `can_moderate` assign: the
  # assign decides what is rendered, the check here decides what is allowed.
  def handle_event("log_moderation_event", _params, socket) do
    if can_moderate?(socket) do
      log_and_report(socket, "hello_world.moderation_event", "moderation_button")
    else
      {:noreply,
       put_flash(
         socket,
         :error,
         gettext("You need the \"Moderate\" permission to log moderation events.")
       )}
    end
  end

  # Defensive catch-all so a stray PubSub broadcast or OTP message can't
  # crash this LiveView with a FunctionClauseError. Logs at :debug so it
  # never spams in production but stays grep-able during development.
  @impl true
  def handle_info(msg, socket) do
    Logger.debug("[#{inspect(__MODULE__)}] Unhandled info: #{inspect(msg)}")
    {:noreply, socket}
  end

  # Sub-permission check. `Scope.can?/2` is false for a nil scope, for a role
  # without the grant, and while the module is disabled.
  defp can_moderate?(socket) do
    Scope.can?(
      socket.assigns[:phoenix_kit_current_scope],
      PhoenixKitHelloWorld.moderate_permission()
    )
  end

  defp log_and_report(socket, action, source) do
    case log_event(socket, action, source) do
      {:ok, _entry} ->
        {:noreply,
         socket
         |> assign(:last_logged_at, DateTime.utc_now())
         |> put_flash(:info, gettext("Event logged — check the Events tab!"))}

      {:error, reason} ->
        Logger.warning("[HelloWorld] Failed to log #{action}: #{inspect(reason)}")

        {:noreply,
         put_flash(socket, :error, gettext("Failed to log event. Check the server logs."))}
    end
  end

  # ── Activity logging ────────────────────────────────────────────

  # Canonical activity logging for external modules: core's
  # `PhoenixKit.Activity.log/3` takes the module key, the action and options
  # and never raises (a failure is logged there and returned as
  # `{:error, _}`); `PhoenixKitWeb.Actor` reads who is acting.
  defp log_event(socket, action, source) do
    PhoenixKit.Activity.log(
      "hello_world",
      action,
      PhoenixKitWeb.Actor.opts(socket) ++
        [
          resource_type: "hello_world",
          metadata: %{
            "source" => source,
            "triggered_at" => DateTime.to_iso8601(DateTime.utc_now())
          }
        ]
    )
  end

  # ── Inline markup inside a translated sentence ───────────────────

  # Stands in for the placeholder while the sentence is translated; the
  # translated text is split on it and the slot rendered in its place.
  @slot_marker "\u2063"

  @doc false
  def slot_marker, do: @slot_marker

  attr(:text, :string, required: true)
  slot(:inner_block, required: true)

  # Renders a translated sentence with markup (a link, a `<code>` span) where
  # its placeholder is:
  #
  #     <.inline text={gettext("Browse %{link} to see what's available", link: slot_marker())}>
  #       <.link navigate={...}>{gettext("Components")}</.link>
  #     </.inline>
  #
  # The translator sees one whole sentence and may move `%{link}` anywhere in
  # it. Both halves stay ordinary escaped text — no HTML in a msgid, no raw/1.
  defp inline(assigns) do
    {before_slot, after_slot} =
      case String.split(assigns.text, @slot_marker, parts: 2) do
        [before_slot, after_slot] -> {before_slot, after_slot}
        [whole] -> {whole, ""}
      end

    assigns = assign(assigns, before_slot: before_slot, after_slot: after_slot)

    ~H"""
    {@before_slot}{render_slot(@inner_block)}{@after_slot}
    """
  end

  # ── Render ───────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col px-4 py-6 gap-6">
      <%!-- Status card --%>
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body items-center text-center">
          <h2 class="card-title text-3xl">
            {gettext("Hello World Plugin")}
          </h2>
          <p class="text-base-content/70 mt-1">
            {gettext("This is an external PhoenixKit plugin module. Everything below confirms it's working."
            )}
          </p>

          <div class="flex flex-wrap justify-center gap-2 mt-4">
            <div class="badge badge-success gap-1">
              <.icon name="hero-check-circle-mini" class="w-3 h-3" />
              {gettext("Auto-discovery")}
            </div>
            <div class="badge badge-success gap-1">
              <.icon name="hero-check-circle-mini" class="w-3 h-3" />
              {gettext("Routing")}
            </div>
            <div class="badge badge-success gap-1">
              <.icon name="hero-check-circle-mini" class="w-3 h-3" />
              {gettext("Permissions")}
            </div>
            <div class="badge badge-success gap-1">
              <.icon name="hero-check-circle-mini" class="w-3 h-3" />
              {gettext("Admin layout")}
            </div>
            <div class="badge badge-success gap-1">
              <.icon name="hero-check-circle-mini" class="w-3 h-3" />
              {gettext("Sidebar tab")}
            </div>
            <div class="badge badge-success gap-1">
              <.icon name="hero-check-circle-mini" class="w-3 h-3" />
              {gettext("Activity logging")}
            </div>
          </div>
        </div>
      </div>

      <%!-- Activity logging demo --%>
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h3 class="card-title text-lg">
            <.icon name="hero-bolt" class="w-5 h-5" />
            {gettext("Activity Logging Demo")}
          </h3>
          <p class="text-base-content/70 text-sm">
            <.inline text={
              gettext(
                "Click a button below to log an activity event, then visit the %{link} to see it appear in the feed.",
                link: slot_marker()
              )
            }>
              <.link navigate={Paths.events()} class="link link-primary">{gettext("Events tab")}</.link>
            </.inline>
          </p>

          <div class="flex flex-wrap items-center gap-3 mt-3">
            <%!-- Base permission: anyone who may enter the module. --%>
            <button
              :if={@module_access}
              type="button"
              phx-click="log_demo_event"
              phx-disable-with={gettext("Logging…")}
              class="btn btn-primary btn-sm"
            >
              <.icon name="hero-play" class="w-4 h-4" />
              {gettext("Log demo event")}
            </button>

            <%!-- Sub-permission: an additive grant on top of the base key. --%>
            <button
              :if={@can_moderate}
              type="button"
              phx-click="log_moderation_event"
              phx-disable-with={gettext("Logging…")}
              class="btn btn-secondary btn-sm"
            >
              <.icon name="hero-shield-check" class="w-4 h-4" />
              {gettext("Log moderation event")}
            </button>

            <div :if={!@module_access} class="alert alert-warning py-2">
              <.icon name="hero-lock-closed" class="w-4 h-4" />
              <span class="text-xs">
                {gettext("You need the 'hello_world' permission to log events.")}
              </span>
            </div>

            <span :if={@last_logged_at} class="text-xs text-base-content/60">
              {gettext("Last logged at %{time}",
                time: Calendar.strftime(@last_logged_at, "%H:%M:%S")
              )}
            </span>
          </div>

          <p :if={@module_access && !@can_moderate} class="text-xs text-base-content/60 mt-2">
            <.icon name="hero-lock-closed" class="w-3 h-3" />
            {gettext(
              "A second button, \"Log moderation event\", appears for roles granted the \"Moderate\" sub-permission while the module is enabled."
            )}
          </p>

          <details class="mt-3" phx-mounted={Phoenix.LiveView.JS.ignore_attributes(["open"])}>
            <summary class="text-xs text-base-content/60 cursor-pointer">
              {gettext("Show the code pattern")}
            </summary>
            <pre class="text-xs bg-base-200 p-3 rounded mt-2 overflow-x-auto"><code>{@demo_event_snippet}</code></pre>
          </details>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <%!-- Module info --%>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h3 class="card-title text-lg">
              {gettext("Module Info")}
            </h3>
            <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm mt-2">
              <dt class="text-base-content/70">{gettext("Module")}</dt>
              <dd class="font-mono text-xs">{inspect(PhoenixKitHelloWorld)}</dd>
              <dt class="text-base-content/70">{gettext("Key")}</dt>
              <dd class="font-mono">{PhoenixKitHelloWorld.module_key()}</dd>
              <dt class="text-base-content/70">{gettext("Version")}</dt>
              <dd class="font-mono">{PhoenixKitHelloWorld.version()}</dd>
              <dt class="text-base-content/70">{gettext("Enabled")}</dt>
              <dd>
                <span class={[
                  "badge badge-sm",
                  if(@module_enabled, do: "badge-success", else: "badge-error")
                ]}>
                  {to_string(@module_enabled)}
                </span>
              </dd>
            </dl>
          </div>
        </div>

        <%!-- Current user info (demonstrates Scope API) --%>
        <div class="card bg-base-100 shadow-xl">
          <div class="card-body">
            <h3 class="card-title text-lg">
              {gettext("Current User")}
            </h3>
            <p class="text-base-content/60 text-xs">
              <.inline text={gettext("via %{assign}", assign: slot_marker())}>
                <code class="bg-base-200 px-1 rounded">@phoenix_kit_current_scope</code>
              </.inline>
            </p>
            <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm mt-2">
              <dt class="text-base-content/70">{gettext("Email")}</dt>
              <dd class="font-mono text-xs">{@user_email || "—"}</dd>
              <dt class="text-base-content/70">{gettext("Roles")}</dt>
              <dd>
                <div class="flex flex-wrap gap-1">
                  <span
                    :for={role <- @user_roles || []}
                    class="badge badge-sm badge-outline"
                  >
                    {role}
                  </span>
                </div>
              </dd>
              <dt class="text-base-content/70">{gettext("Admin?")}</dt>
              <dd class="font-mono">{to_string(@is_admin)}</dd>
              <dt class="text-base-content/70">
                {gettext("Module access?")}
              </dt>
              <dd class="font-mono">{to_string(@module_access)}</dd>
              <dt class="text-base-content/70">
                {gettext("Can moderate?")}
              </dt>
              <dd class="font-mono" data-can-moderate={to_string(@can_moderate)}>
                {to_string(@can_moderate)}
              </dd>
            </dl>
          </div>
        </div>
      </div>

      <%!-- Explore more --%>
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h3 class="card-title text-lg">
            <.icon name="hero-map" class="w-5 h-5" />
            {gettext("Explore the showcase")}
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mt-2">
            <.link navigate={Paths.events()} class="btn btn-outline btn-sm justify-start">
              <.icon name="hero-clock" class="w-4 h-4" />
              <span>{gettext("Events feed")}</span>
              <.icon name="hero-arrow-right" class="w-4 h-4 ml-auto" />
            </.link>
            <.link navigate={Paths.components()} class="btn btn-outline btn-sm justify-start">
              <.icon name="hero-squares-2x2" class="w-4 h-4" />
              <span>{gettext("Components showcase")}</span>
              <.icon name="hero-arrow-right" class="w-4 h-4 ml-auto" />
            </.link>
          </div>
        </div>
      </div>

      <%!-- Next steps --%>
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h3 class="card-title text-lg">{gettext("Next Steps")}</h3>
          <p class="text-base-content/70 text-sm">
            {gettext("This page is your starting point. Replace it with your own content."
            )}
          </p>
          <ul class="text-sm space-y-2 mt-2 list-none">
            <li class="flex gap-2">
              <span class="text-base-content/40">1.</span>
              <span>
                <.inline text={gettext("Edit %{file} — this file", file: slot_marker())}>
                  <code class="bg-base-200 px-1 rounded text-xs">lib/phoenix_kit_hello_world/web/hello_live.ex</code>
                </.inline>
              </span>
            </li>
            <li class="flex gap-2">
              <span class="text-base-content/40">2.</span>
              <span>
                <.inline text={
                  gettext("Update callbacks in %{file} — module key, name, tabs", file: slot_marker())
                }>
                  <code class="bg-base-200 px-1 rounded text-xs">lib/phoenix_kit_hello_world.ex</code>
                </.inline>
              </span>
            </li>
            <li class="flex gap-2">
              <span class="text-base-content/40">3.</span>
              <span>
                <.inline text={
                  gettext("Log all mutations via %{function} — see the demo button above",
                    function: slot_marker()
                  )
                }>
                  <code class="bg-base-200 px-1 rounded text-xs">PhoenixKit.Activity.log/3</code>
                </.inline>
              </span>
            </li>
            <li class="flex gap-2">
              <span class="text-base-content/40">4.</span>
              <span>
                <.inline text={gettext("Browse %{link} to see what's available", link: slot_marker())}>
                  <.link navigate={Paths.components()} class="link link-primary">{gettext("Components")}</.link>
                </.inline>
              </span>
            </li>
            <li class="flex gap-2">
              <span class="text-base-content/40">5.</span>
              <span>
                <.inline text={gettext("See %{file} for the full guide", file: slot_marker())}>
                  <code class="bg-base-200 px-1 rounded text-xs">README.md</code>
                </.inline>
              </span>
            </li>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end

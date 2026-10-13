defmodule PhoenixKitHelloWorld.Web.ProjectHelloTabLive do
  @moduledoc """
  The reference **project-extension tab** — the render side of the
  `phoenix_kit_project_extensions/0` contract (see that function in
  `PhoenixKitHelloWorld` for the catalog side; copy the pair when adding a
  project tab to your module).

  The projects hub renders contributed tabs via `live_render` with an
  embed-session contract, so a tab LV must be mountable **off-router**
  (`:not_mounted_at_router`): read everything from `session`, export no
  `handle_params/3`, and never assume router assigns — core's admin
  `on_mount` does not run here, so there is no `@phoenix_kit_current_scope`.

  Session keys the hub supplies:

    * `"project_uuid"` — the host project. The ONLY required key.
    * `"ext_key"` / `"instance_key"` — which enablement row this render is
      (`instance_key` is `"default"` while the hub runs one instance per
      extension per project).
    * `"config"` — the instance's config map (whitelisted to the entry's
      `config_schema`, admin-edited in the project's Modules panel).
    * `"can_write"` — a boolean the HOST resolved: whether the viewer may
      perform the extension's write action (the first `permission_actions`
      entry other than `:view`) on this project. The host holds the scope and
      the tab does not, so this is the tab's only write authorization — gate
      every mutating control AND its event handler on it. `false` whenever the
      extension declares no write action or the viewer is unidentified.
    * `"current_user_uuid"` — viewer identity for user-aware behavior, as a
      string uuid. Identity only, never authorization. May be absent; degrade
      to anonymous, never crash.
    * `"locale"` — the content locale of the page. Gettext keeps its locale in
      the process dictionary and this LiveView is its own process, so mount
      sets it; without that the tab renders in the default locale inside a
      translated page.
    * `"wrapper_class"` — the class for the tab's outermost element. The hub
      passes `""` because the project page already pads the content area.
    * `"mode"`, `"pubsub_topic"`, `"frame_ref"` — the hub's emit contract.
      `mode` is `"navigate"` (default), `"emit"` or `"popup"`; in the last two
      a tab reports saves and closes on `pubsub_topic` instead of navigating,
      echoing `frame_ref`. A tab that never navigates or opens a dialog can
      ignore all three, as this one does.
    * `"host_paths"` — where the hub's own pages are (`%{"new_task" => path}`),
      so a tab can link to them without naming the hub's routes.

  This demo renders the received contract verbatim — the "contract debug"
  card for hub tabs, mirroring what `HelloWidget`'s contract view does for
  dashboard widgets — plus one write-gated button.
  """

  use Phoenix.LiveView
  use Gettext, backend: PhoenixKitHelloWorld.Gettext

  @impl true
  def mount(_params, session, socket) do
    put_locale(session["locale"])

    {:ok,
     assign(socket,
       project_uuid: session["project_uuid"],
       ext_key: session["ext_key"],
       instance_key: session["instance_key"] || "default",
       config: session["config"] || %{},
       # Strictly `true`: anything else — absent, nil, a string — is read-only.
       can_write: session["can_write"] == true,
       current_user_uuid: session["current_user_uuid"],
       locale: session["locale"],
       wrapper_class: session["wrapper_class"] || "",
       mode: session["mode"] || "navigate",
       host_paths: session["host_paths"] || %{},
       greetings: 0
     )}
  end

  # The button is not rendered without `can_write`, but a hidden control is
  # not authorization: a crafted event still arrives here, so the handler
  # checks again and ignores it.
  @impl true
  def handle_event("greet", _params, %{assigns: %{can_write: true}} = socket) do
    {:noreply, update(socket, :greetings, &(&1 + 1))}
  end

  def handle_event("greet", _params, socket), do: {:noreply, socket}

  # Both backends: this module's own strings, and core's — any core component
  # rendered inside the tab translates through `PhoenixKitWeb.Gettext`.
  defp put_locale(locale) when is_binary(locale) and locale != "" do
    Gettext.put_locale(PhoenixKitHelloWorld.Gettext, locale)
    Gettext.put_locale(PhoenixKitWeb.Gettext, locale)
  end

  defp put_locale(_absent), do: :ok

  @impl true
  def render(assigns) do
    ~H"""
    <div class={@wrapper_class}>
      <div class="card bg-base-100 border border-base-200">
        <div class="card-body gap-3">
          <h3 class="card-title text-base">{gettext("Hello from a project extension tab")}</h3>
          <p class="text-sm opacity-70">
            {gettext(
              "This tab was contributed by the Hello World module through the project-extension contract and is rendered by the projects hub."
            )}
          </p>

          <div class="flex flex-wrap items-center gap-3">
            <span :if={@can_write} class="badge badge-success badge-sm">
              {gettext("You can make changes here")}
            </span>
            <span :if={!@can_write} class="badge badge-ghost badge-sm">
              {gettext("Read-only")}
            </span>
            <button
              :if={@can_write}
              type="button"
              phx-click="greet"
              phx-disable-with={gettext("Greeting…")}
              class="btn btn-primary btn-sm"
            >
              {Map.get(@config, "greeting") || gettext("Hello")}
            </button>
            <span :if={@greetings > 0} class="text-sm opacity-70">
              {ngettext("Greeted %{count} time", "Greeted %{count} times", @greetings)}
            </span>
          </div>

          <%!-- The session contract, verbatim. Keys are identifiers, not copy. --%>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm">
            <div class="bg-base-200 rounded-lg p-3">
              <div class="font-semibold opacity-60 text-xs uppercase">project_uuid</div>
              <code class="break-all">{@project_uuid || "—"}</code>
            </div>
            <div class="bg-base-200 rounded-lg p-3">
              <div class="font-semibold opacity-60 text-xs uppercase">ext_key / instance_key</div>
              <code>{@ext_key || "—"} / {@instance_key}</code>
            </div>
            <div class="bg-base-200 rounded-lg p-3">
              <div class="font-semibold opacity-60 text-xs uppercase">current_user_uuid</div>
              <code class="break-all">{@current_user_uuid || gettext("anonymous")}</code>
            </div>
            <div class="bg-base-200 rounded-lg p-3">
              <div class="font-semibold opacity-60 text-xs uppercase">can_write</div>
              <code data-can-write={to_string(@can_write)}>{to_string(@can_write)}</code>
            </div>
            <div class="bg-base-200 rounded-lg p-3">
              <div class="font-semibold opacity-60 text-xs uppercase">locale / mode</div>
              <code>{@locale || "—"} / {@mode}</code>
            </div>
            <div class="bg-base-200 rounded-lg p-3">
              <div class="font-semibold opacity-60 text-xs uppercase">config</div>
              <code class="break-all">{inspect(@config)}</code>
            </div>
            <div class="bg-base-200 rounded-lg p-3 sm:col-span-2">
              <div class="font-semibold opacity-60 text-xs uppercase">host_paths</div>
              <code class="break-all">{inspect(@host_paths)}</code>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

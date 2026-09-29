defmodule PhoenixKitHelloWorld.Web.NotificationsLive do
  @moduledoc """
  A hands-on tour of the PhoenixKit notification system.

  This page is the canonical example for **how a module should send and manage
  notifications**. Copy the patterns below into your own module.

  ## The one rule: notifications are driven by the activity log

  You **never** insert into `phoenix_kit_notifications` directly. Instead you log
  a business activity with `PhoenixKit.Activity.log/3`, and core's activity hook
  fans it out into a per-user notification automatically:

      PhoenixKit.Activity.log("hello_world", "post.created",  # module_key(), "resource.verb"
        actor_uuid: actor.uuid,        # who did it
        target_uuid: recipient.uuid,   # who should be notified
        ...
      )

  A notification row is created **only when `target_uuid != actor_uuid`** — you
  don't notify someone about their own action. Admins reading `/admin/activity`
  get the audit trail; the `target_uuid` user gets the inbox notification.

  ## What you'll see here

  - **Send** a plain notification (the activity drives it).
  - **Send with custom display** — override the icon / text / link via metadata.
  - **Read / manage** — unread count, recent list, mark-seen, dismiss.
  - **Declare** notification types from your module (see `notification_types/0`
    in `PhoenixKitHelloWorld`) so users can mute them in their settings.
  - **Live updates** over PubSub via `PhoenixKit.Notifications.Events.subscribe/1`.

  Core's notifications and activity contexts are called directly — the core
  floor carries both, so nothing here is guarded with `Code.ensure_loaded?/1`.
  """

  use Phoenix.LiveView

  import PhoenixKitWeb.Components.Core.EmptyState, only: [empty_state: 1]
  import PhoenixKitWeb.Components.Core.Icon, only: [icon: 1]

  alias PhoenixKit.Notifications.{Events, Render}
  alias PhoenixKitHelloWorld.Paths
  alias PhoenixKitWeb.Actor

  # A throwaway "Hello Bot" actor so the demo notification targets *you* while
  # keeping `actor_uuid != target_uuid` (otherwise core skips the fan-out — you
  # never get notified about your own actions). In real code this is the uuid of
  # whoever performed the action.
  @demo_actor_uuid "00000000-0000-7000-8000-000000000b07"

  @impl true
  def mount(_params, _session, socket) do
    user_uuid = Actor.uuid(socket)

    if connected?(socket) and is_binary(user_uuid) do
      # One line to receive {:notification_created | :notification_seen |
      # :notification_dismissed, notification} and {:notifications_bulk_updated, _}.
      Events.subscribe(user_uuid)
    end

    {:ok,
     socket
     |> assign(
       page_title: Gettext.gettext(PhoenixKitWeb.Gettext, "Notifications"),
       page_section: Gettext.gettext(PhoenixKitWeb.Gettext, "Hello World"),
       page_section_path: Paths.index(),
       page_subtitle:
         Gettext.gettext(
           PhoenixKitWeb.Gettext,
           "How to send, customize, and manage notifications"
         ),
       user_uuid: user_uuid,
       available: true,
       unread: 0,
       recent: []
     )
     |> refresh()}
  end

  # ── Sending ────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("send_basic", _params, socket) do
    log_demo_activity(socket, "hello.greeting", %{
      "actor_role" => "system",
      "greeting" => "Hello there!"
    })

    {:noreply,
     socket
     |> put_flash(
       :info,
       Gettext.gettext(PhoenixKitWeb.Gettext, "Sent — check the bell (and the list below).")
     )
     |> refresh()}
  end

  def handle_event("send_custom", _params, socket) do
    # The three `notification_*` metadata keys fully control how the row renders
    # in the inbox. Any one can be omitted — Render falls back to the action.
    log_demo_activity(socket, "hello.custom", %{
      "actor_role" => "system",
      "notification_text" => "👋 A fully custom notification from Hello World!",
      "notification_icon" => "hero-sparkles",
      "notification_link" => Paths.notifications()
    })

    {:noreply,
     socket
     |> put_flash(
       :info,
       Gettext.gettext(PhoenixKitWeb.Gettext, "Sent a custom-display notification.")
     )
     |> refresh()}
  end

  # ── Managing (mark seen / dismiss) ───────────────────────────────────────────

  def handle_event("mark_seen", %{"uuid" => uuid}, socket) do
    with_user(socket, &PhoenixKit.Notifications.mark_seen(&1, uuid))
    {:noreply, refresh(socket)}
  end

  def handle_event("dismiss", %{"uuid" => uuid}, socket) do
    with_user(socket, &PhoenixKit.Notifications.dismiss(&1, uuid))
    {:noreply, refresh(socket)}
  end

  def handle_event("mark_all_seen", _params, socket) do
    with_user(socket, &PhoenixKit.Notifications.mark_all_seen/1)
    {:noreply, refresh(socket)}
  end

  def handle_event("dismiss_all", _params, socket) do
    with_user(socket, &PhoenixKit.Notifications.dismiss_all/1)
    {:noreply, refresh(socket)}
  end

  # ── Live updates ─────────────────────────────────────────────────────────────
  # Core broadcasts on the per-user topic; we just refresh on any of them.

  @impl true
  def handle_info({:notification_created, _n}, socket), do: {:noreply, refresh(socket)}
  def handle_info({:notification_seen, _n}, socket), do: {:noreply, refresh(socket)}
  def handle_info({:notification_dismissed, _n}, socket), do: {:noreply, refresh(socket)}
  def handle_info({:notifications_bulk_updated, _kind}, socket), do: {:noreply, refresh(socket)}
  def handle_info(_msg, socket), do: {:noreply, socket}

  # ── Render ───────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col px-4 py-6 space-y-6">
      <div :if={not @available} class="alert alert-warning">
        <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
        <span>
          {Gettext.gettext(
            PhoenixKitWeb.Gettext,
            "This host doesn't have PhoenixKit.Notifications loaded, so the live demo is disabled. The code patterns below still apply."
          )}
        </span>
      </div>

      <%!-- Intro --%>
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title">
            <.icon name="hero-bell-alert" class="w-5 h-5" />
            {Gettext.gettext(PhoenixKitWeb.Gettext, "Notifications, the PhoenixKit way")}
          </h2>
          <p class="text-base-content/70">
            {Gettext.gettext(
              PhoenixKitWeb.Gettext,
              "You never write to phoenix_kit_notifications directly. You log a business activity with a target_uuid, and core turns it into that user's notification — when target_uuid != actor_uuid."
            )}
          </p>
          <pre phx-no-curly-interpolation class="bg-base-200 rounded-lg p-3 text-xs overflow-x-auto"><code>PhoenixKit.Activity.log("hello_world", "post.created",  # module_key(), "resource.verb"
      actor_uuid: actor.uuid,       # who did it
      resource_type: "post",
      resource_uuid: post.uuid,
      target_uuid: recipient.uuid,  # who gets notified
      metadata: %{"actor_role" =&gt; "user"}
    )</code></pre>
        </div>
      </div>

      <%!-- Live state + send buttons --%>
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <div class="flex items-center justify-between flex-wrap gap-2">
            <h2 class="card-title">{Gettext.gettext(PhoenixKitWeb.Gettext, "Try it")}</h2>
            <div class="badge badge-lg badge-primary gap-2">
              <.icon name="hero-bell" class="w-4 h-4" />
              {Gettext.gettext(PhoenixKitWeb.Gettext, "%{count} unread", count: @unread)}
            </div>
          </div>

          <div class="flex flex-wrap gap-2 mt-2">
            <button class="btn btn-primary btn-sm" phx-click="send_basic" disabled={not @available}>
              <.icon name="hero-paper-airplane" class="w-4 h-4" />
              {Gettext.gettext(PhoenixKitWeb.Gettext, "Send a notification")}
            </button>
            <button class="btn btn-secondary btn-sm" phx-click="send_custom" disabled={not @available}>
              <.icon name="hero-sparkles" class="w-4 h-4" />
              {Gettext.gettext(PhoenixKitWeb.Gettext, "Send with custom display")}
            </button>
          </div>

          <div class="mt-4 grid md:grid-cols-2 gap-3">
            <div>
              <p class="text-xs font-semibold text-base-content/60 uppercase mb-1">
                {Gettext.gettext(PhoenixKitWeb.Gettext, "Plain")}
              </p>
              <pre phx-no-curly-interpolation class="bg-base-200 rounded-lg p-3 text-xs overflow-x-auto"><code>PhoenixKit.Activity.log("hello_world", "hello.greeting",
      actor_uuid: actor_uuid,
      target_uuid: you.uuid,
      metadata: %{"greeting" =&gt; "Hello there!"}
    )</code></pre>
            </div>
            <div>
              <p class="text-xs font-semibold text-base-content/60 uppercase mb-1">
                {Gettext.gettext(PhoenixKitWeb.Gettext, "Custom display")}
              </p>
              <pre phx-no-curly-interpolation class="bg-base-200 rounded-lg p-3 text-xs overflow-x-auto"><code>metadata: %{
      "notification_text" =&gt; "👋 Custom!",
      "notification_icon" =&gt; "hero-sparkles",
      # ALWAYS build the link via Routes.path/1 so it carries the
      # URL prefix + locale — never a raw "/admin/..." path.
      "notification_link" =&gt; Paths.index()
    }</code></pre>
            </div>
          </div>
        </div>
      </div>

      <%!-- Recent + manage --%>
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <div class="flex items-center justify-between flex-wrap gap-2">
            <h2 class="card-title">
              {Gettext.gettext(PhoenixKitWeb.Gettext, "Your recent notifications")}
            </h2>
            <div class="flex gap-2">
              <button class="btn btn-ghost btn-xs" phx-click="mark_all_seen" disabled={not @available}>
                {Gettext.gettext(PhoenixKitWeb.Gettext, "Mark all seen")}
              </button>
              <button class="btn btn-ghost btn-xs" phx-click="dismiss_all" disabled={not @available}>
                {Gettext.gettext(PhoenixKitWeb.Gettext, "Dismiss all")}
              </button>
            </div>
          </div>

          <.empty_state
            :if={@recent == []}
            icon="hero-bell-slash"
            class="py-6"
            title={
              Gettext.gettext(
                PhoenixKitWeb.Gettext,
                "No notifications yet — hit \"Send a notification\" above."
              )
            }
          />

          <ul class="divide-y divide-base-200">
            <li :for={n <- @recent} class="flex items-center gap-3 py-2">
              <.icon name={n.icon} class="w-5 h-5 text-base-content/60 shrink-0" />
              <div class="flex flex-col min-w-0 flex-1">
                <span class={["text-sm truncate", n.seen_at && "text-base-content/50"]}>{n.text}</span>
                <span :if={not n.seen_at} class="text-xs text-primary">
                  {Gettext.gettext(PhoenixKitWeb.Gettext, "unread")}
                </span>
              </div>
              <button
                :if={not n.seen_at}
                class="btn btn-ghost btn-xs"
                phx-click="mark_seen"
                phx-value-uuid={n.uuid}
              >
                {Gettext.gettext(PhoenixKitWeb.Gettext, "Seen")}
              </button>
              <button class="btn btn-ghost btn-xs" phx-click="dismiss" phx-value-uuid={n.uuid}>
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </li>
          </ul>

          <pre phx-no-curly-interpolation class="bg-base-200 rounded-lg p-3 text-xs overflow-x-auto mt-3"><code># Read &amp; manage (all take the recipient's user_uuid)
    PhoenixKit.Notifications.count_unread(user_uuid)
    PhoenixKit.Notifications.recent_for_user(user_uuid, 10)
    PhoenixKit.Notifications.mark_seen(user_uuid, notification_uuid)
    PhoenixKit.Notifications.mark_all_seen(user_uuid)
    PhoenixKit.Notifications.dismiss(user_uuid, notification_uuid)
    PhoenixKit.Notifications.dismiss_all(user_uuid)</code></pre>
        </div>
      </div>

      <%!-- Module-level wiring --%>
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title">
            {Gettext.gettext(PhoenixKitWeb.Gettext, "Declare your module's notification types")}
          </h2>
          <p class="text-base-content/70">
            {Gettext.gettext(
              PhoenixKitWeb.Gettext,
              "Implement the optional notification_types/0 callback on your module so its notifications show up as a toggle in each user's notification preferences. This module already does — see PhoenixKitHelloWorld.notification_types/0."
            )}
          </p>
          <pre phx-no-curly-interpolation class="bg-base-200 rounded-lg p-3 text-xs overflow-x-auto"><code>@impl PhoenixKit.Module
    def notification_types do
      [%{key: "hello_world", label: "Hello World",
         description: "Greetings from the Hello World module",
         actions: ["hello.greeting", "hello.custom"], default: true}]
    end</code></pre>
          <p class="text-base-content/70 mt-2">
            {Gettext.gettext(
              PhoenixKitWeb.Gettext,
              "To show the inbox bell in your layout, render the embeddable nested LiveView:"
            )}
          </p>
          <pre phx-no-curly-interpolation class="bg-base-200 rounded-lg p-3 text-xs overflow-x-auto"><code>&lt;%= Phoenix.Component.live_render(@socket, PhoenixKitWeb.Live.NotificationsBell,
          id: "pk-notifications-bell", sticky: true,
          session: %{"user_uuid" =&gt; @current_user.uuid}) %&gt;</code></pre>
        </div>
      </div>
    </div>
    """
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp refresh(socket) do
    uuid = socket.assigns[:user_uuid]

    if is_binary(uuid) do
      socket
      |> assign(:unread, PhoenixKit.Notifications.count_unread(uuid))
      |> assign(:recent, load_recent(uuid))
    else
      socket
    end
  end

  # Map each notification through Render so we get a display-ready {icon, text,
  # link}, while keeping uuid + seen_at for the per-row actions.
  defp load_recent(uuid) do
    uuid
    |> PhoenixKit.Notifications.recent_for_user(5)
    |> Enum.map(fn n ->
      rendered = Render.render(n)

      %{
        uuid: n.uuid,
        seen_at: n.seen_at,
        icon: rendered.icon,
        text: rendered.text,
        link: rendered.link
      }
    end)
  end

  # `log/3` never raises; the demo actor is a fixed uuid so the notification
  # lands in YOUR inbox (a row is created only when target != actor).
  defp log_demo_activity(socket, action, metadata) do
    uuid = socket.assigns[:user_uuid]

    if is_binary(uuid) do
      PhoenixKit.Activity.log("hello_world", action,
        actor_uuid: @demo_actor_uuid,
        resource_type: "greeting",
        resource_uuid: Ecto.UUID.generate(),
        target_uuid: uuid,
        metadata: metadata
      )
    end
  end

  defp with_user(socket, fun) do
    uuid = socket.assigns[:user_uuid]
    if is_binary(uuid), do: fun.(uuid)
  end
end

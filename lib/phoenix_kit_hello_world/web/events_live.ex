defmodule PhoenixKitHelloWorld.Web.EventsLive do
  @moduledoc """
  Activity events feed for the Hello World module.

  Shows a filterable, infinite-scroll list of activity entries scoped to
  `module: "hello_world"`. This is a generic pattern — every PhoenixKit
  module that logs activities can drop in a near-identical LiveView by
  changing the module filter and the path.

  ## Pattern walkthrough

  1. Uses `stream/4` with a custom `dom_id:` because `PhoenixKit.Activity.Entry`
     uses `:uuid` as the primary key (not `:id`).
  2. Reloads on filter change via `stream(..., reset: true)`.
  3. Infinite scroll via core's `<.load_more infinite>` footer, which renders
     the `InfiniteScroll` hook plus a manual "Load more" fallback button. The
     hook ships in PhoenixKit's own JS bundle, so it is registered on every
     page load — unlike a per-page inline `<script>`, which never executes
     when the page is reached through `navigate/2`.
  4. `PhoenixKit.Activity` is called directly — the core floor carries it, so
     no `Code.ensure_loaded?/1` guard; a failing read is logged and leaves the
     page as it was.
  5. The action filter's options are the module's own action vocabulary, a
     compile-time list — a module knows which actions it logs. Core's
     `PhoenixKit.Activity.list_action_types/0` is site-wide (every module's
     actions), and deriving the list by reading the module's rows costs a
     query that grows with the log.
  """

  use Phoenix.LiveView
  use Gettext, backend: PhoenixKitHelloWorld.Gettext

  require Logger

  import PhoenixKitWeb.Components.Core.EmptyState, only: [empty_state: 1]
  import PhoenixKitWeb.Components.Core.Icon, only: [icon: 1]
  import PhoenixKitWeb.Components.Core.Pagination, only: [load_more: 1]
  import PhoenixKitWeb.Components.Core.Select, only: [select: 1]

  alias PhoenixKit.Utils.Routes
  alias PhoenixKitHelloWorld.Paths

  @per_page 20

  # Every action this module logs (`Web.HelloLive`, `Web.NotificationsLive`).
  # Add an action there and it is added here, or it cannot be filtered on;
  # `events_live_test.exs` drives the real senders and fails on a missing one.
  @action_types ~w(
    hello.custom
    hello.greeting
    hello_world.demo_event
    hello_world.moderation_event
  )

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: gettext("Events"),
       page_section: gettext("Hello World"),
       page_section_path: Paths.index(),
       page_subtitle:
         gettext(
           "Events logged by the Hello World module. Click the \"Log demo event\" button on the Overview page to add entries."
         ),
       total: 0,
       loaded: 0,
       page: 1,
       has_more: false,
       loading: false,
       filter_action: nil,
       action_types: @action_types
     )
     |> stream(:entries, [], dom_id: &"entry-#{&1.uuid}")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      if connected?(socket) do
        socket
        |> apply_params(params)
        |> assign(:page, 1)
        |> reset_and_load()
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filter = Map.get(params, "filter", %{})

    query_params =
      %{}
      |> maybe_put("action", filter["action"])

    path =
      case URI.encode_query(query_params) do
        "" -> Paths.events()
        query -> Paths.events() <> "?#{query}"
      end

    {:noreply, push_patch(socket, to: path)}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply, push_patch(socket, to: Paths.events())}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    if socket.assigns.has_more and not socket.assigns.loading do
      {:noreply, socket |> assign(:loading, true) |> load_next_page()}
    else
      {:noreply, socket}
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

  # ── Private ──────────────────────────────────────────────────────

  # The URL is client input: an action outside the module's vocabulary is
  # treated as no filter rather than passed to the query.
  defp apply_params(socket, params) do
    action = blank_to_nil(params["action"])
    assign(socket, :filter_action, if(action in @action_types, do: action))
  end

  defp reset_and_load(socket) do
    socket
    |> assign(page: 1, loaded: 0)
    |> stream(:entries, [], reset: true, dom_id: &"entry-#{&1.uuid}")
    |> load_next_page()
  end

  defp load_next_page(socket) do
    result =
      PhoenixKit.Activity.list(
        module: "hello_world",
        page: socket.assigns.page,
        per_page: @per_page,
        action: socket.assigns.filter_action,
        preload: [:actor]
      )

    socket
    |> stream(:entries, result.entries)
    |> assign(
      total: result.total,
      # `<.load_more>` needs the number of rows actually rendered. The stream
      # is append-only between resets, so accumulate rather than deriving it
      # from `page * @per_page` (which overshoots on a short final page).
      loaded: socket.assigns.loaded + length(result.entries),
      page: socket.assigns.page + 1,
      has_more: result.page < result.total_pages,
      loading: false
    )
  rescue
    # A read that fails (database unavailable, schema behind) must not take
    # the page down — but it must leave a trace, or an empty feed looks like
    # "no events" forever.
    e ->
      Logger.warning(
        "[HelloWorld] Loading events page #{socket.assigns.page} " <>
          "(action: #{inspect(socket.assigns.filter_action)}) failed: #{Exception.message(e)}"
      )

      assign(socket, loading: false)
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(val), do: val

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  @action_color_keywords [
    {"created", "badge-success"},
    {"restored", "badge-info"},
    {"deleted", "badge-error"},
    {"trashed", "badge-error"},
    {"updated", "badge-warning"},
    {"changed", "badge-warning"},
    {"moved", "badge-info"},
    {"demo", "badge-accent"}
  ]

  defp action_badge_color(action) do
    Enum.find_value(@action_color_keywords, "badge-ghost", fn {keyword, color} ->
      if String.contains?(action, keyword), do: color
    end)
  end

  defp mode_badge_class(mode) do
    case mode do
      "manual" -> "badge-warning"
      "auto" -> "badge-info"
      "cron" -> "badge-secondary"
      _ -> "badge-ghost"
    end
  end

  defp summarize_metadata(nil), do: nil

  defp summarize_metadata(meta) do
    meta
    |> Map.drop(["actor_role"])
    |> Enum.reject(fn {_k, v} -> v == nil or v == "" end)
    |> case do
      [] -> nil
      entries -> Enum.map_join(entries, ", ", fn {k, v} -> "#{k}: #{v}" end)
    end
  end

  defp format_time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 ->
        gettext("just now")

      diff < 3600 ->
        gettext("%{count}m ago", count: div(diff, 60))

      diff < 86_400 ->
        gettext("%{count}h ago", count: div(diff, 3600))

      diff < 604_800 ->
        gettext("%{count}d ago", count: div(diff, 86_400))

      true ->
        Calendar.strftime(datetime, "%b %d, %Y")
    end
  end

  # ── Render ───────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col px-4 py-6 gap-4">
      <%!-- Filters --%>
      <div class="bg-base-200 rounded-lg p-3">
        <.form
          for={%{}}
          id="events-filter-form"
          phx-change="filter"
          class="flex flex-wrap gap-3 items-end"
        >
          <div class="w-56">
            <.select
              id="filter-action"
              name="filter[action]"
              label={gettext("Action")}
              value={@filter_action}
              options={@action_types}
              prompt={gettext("All Actions")}
              class="select-sm"
            />
          </div>

          <button type="button" phx-click="clear_filters" class="btn btn-ghost btn-sm">
            {gettext("Clear")}
          </button>

          <div class="ml-auto text-sm text-base-content/60">
            {ngettext("%{count} event", "%{count} events", @total)}
          </div>
        </.form>
      </div>

      <%!-- Events Feed --%>
      <div id="events-feed" phx-update="stream" class="flex flex-col gap-2">
        <div
          :for={{dom_id, entry} <- @streams.entries}
          id={dom_id}
          class="card card-compact bg-base-100 shadow-sm border border-base-200"
        >
          <div class="card-body flex-row items-center gap-3 py-2 px-4">
            <%!-- Action badge --%>
            <div class="min-w-[180px]">
              <span class={"badge badge-sm #{action_badge_color(entry.action)}"}>
                {entry.action}
              </span>
            </div>

            <%!-- Mode --%>
            <div class="min-w-[60px]">
              <%= if entry.mode do %>
                <span class={"badge badge-xs #{mode_badge_class(entry.mode)}"}>
                  {entry.mode}
                </span>
              <% end %>
            </div>

            <%!-- Details --%>
            <div class="flex-1 min-w-0">
              <% summary = summarize_metadata(entry.metadata) %>
              <%= if summary do %>
                <span
                  class="text-xs text-base-content/60 truncate inline-block max-w-[300px] align-bottom"
                  title={summary}
                >
                  {summary}
                </span>
              <% end %>
            </div>

            <%!-- Actor --%>
            <div class="text-sm text-base-content/70 hidden sm:block">
              <%= if entry.actor do %>
                {entry.actor.email}
              <% else %>
                <span class="text-base-content/40">{gettext("System")}</span>
              <% end %>
            </div>

            <%!-- Time --%>
            <div class="text-xs text-base-content/50 min-w-[70px] text-right">
              {format_time_ago(entry.inserted_at)}
            </div>

            <%!-- Detail link --%>
            <.link
              navigate={Routes.path("/admin/activity/#{entry.uuid}")}
              class="btn btn-ghost btn-xs btn-square"
              title={gettext("View details")}
            >
              <.icon name="hero-arrow-top-right-on-square" class="w-3.5 h-3.5" />
            </.link>
          </div>
        </div>
      </div>

      <%!-- Empty states: nothing logged yet vs. nothing matching the filter --%>
      <.empty_state
        :if={@total == 0 and not @loading and is_nil(@filter_action)}
        icon="hero-bell-slash"
        title={gettext("No events recorded yet")}
        description={gettext("Head back to the Overview page and click \"Log demo event\".")}
      />
      <.empty_state
        :if={@total == 0 and not @loading and not is_nil(@filter_action)}
        icon="hero-funnel"
        title={gettext("No events match this filter.")}
      />

      <%!-- Auto-load on scroll (core's InfiniteScroll hook) + manual fallback.
           The hook lives in PhoenixKit's own JS bundle, so it is registered
           whether this page is reached by full page load or by `navigate/2`. --%>
      <.load_more
        id="events-load-more"
        loaded={@loaded}
        total={@total}
        infinite
        noun_plural={gettext("events")}
      />
    </div>
    """
  end
end

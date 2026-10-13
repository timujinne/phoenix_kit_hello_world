defmodule PhoenixKitHelloWorld.Web.ComponentsLive do
  @moduledoc """
  Showcase of PhoenixKit core components.

  This page demonstrates how to use components from `PhoenixKitWeb.Components.Core.*`
  so you can copy-paste the patterns into your own modules. Every section includes a
  live example plus the source snippet in a `<details>` block.

  ## Page structure

  The page has two halves separated by `<.section_divider>`: raw daisyUI markup
  first, then the PhoenixKit core components. Several are deliberate pairs —
  `buttons_section` → `button_section`, `badges_section` →
  `status_badge_section`, `form_inputs_section` → `form_helpers_section`,
  `tables_section` → `table_default_section`, `pagination_section` →
  `pagination_component_section`, `empty_states_section` →
  `empty_state_section`. Read a pair top-to-bottom to see what the core
  component buys you.

  The page title and subtitle come from the `page_title` / `page_subtitle`
  assigns — the admin layout renders them. This page renders no header of its
  own; see the "UI & Layout Conventions" section in `AGENTS.md`.

  ## Categories

  - **Typography & feedback** — badges, `status_badge`, alerts, stat cards,
    number formatter
  - **Buttons & icons** — raw variants, `button`, `pk_link_button`
  - **Navigation** — `nav_tabs` (variants, `:trailing`), collapse and
    `accordion`, `pk_link`
  - **Forms** — input, select, textarea, checkbox, `simple_form`,
    `form_section` + `form_actions`, `search_picker`
  - **Tables & lists** — raw table, `table_default` with `sort_header_cell`,
    `search_toolbar` and `table_row_menu`, bulk selection, draggable list
  - **Modals & overlays** — `modal` (drawer placement, unsaved-input guard),
    `confirm_modal`, `popover_panel`
  - **Pagination** — raw join buttons, `pagination`, `load_more`
  - **Time & files** — time_ago, age_badge, file_size, file_mtime, page_status_badge
  - **Empty / loading states** — raw markup, `empty_state` (with `:cta`)

  ## Import pattern

  `use PhoenixKitWeb, :live_view` imports every core component used on this
  page, so there is not one explicit component import below. A LiveView that
  does `use Phoenix.LiveView` directly imports what it uses:

      import PhoenixKitWeb.Components.Core.Icon, only: [icon: 1]
      import PhoenixKitWeb.Components.Core.Modal, only: [modal: 1, confirm_modal: 1]

  Every component and attribute on this page exists in the `phoenix_kit`
  release this module's `mix.exs` floor names. Newer core releases add more —
  `<.table_default fit>` with column priorities (core 2.54) and
  `<.save_button>` (core 2.47); raise the floor before using either.

  ## Events from the client are input

  Every handler below validates what it receives against a server-side list —
  a sort field, a tab id, a row id, a list of selected ids — before using it.
  A `phx-value-*` or a hook payload is whatever the browser sends.

  ## File organization

  The render function is a flat list of `<.x_section />` calls. Each section is a
  private function component defined below. To find or modify a section, jump to
  its `defp <name>_section/1` definition — they appear in the same order as the
  render. New sections: add a `<.your_section />` to render and define the
  matching `defp your_section/1` below (`dev_docs/guides/section-decomposition.md`).
  """
  use PhoenixKitWeb, :live_view
  use Gettext, backend: PhoenixKitHelloWorld.Gettext

  require Logger

  alias PhoenixKitHelloWorld.Paths

  @valid_demo_tabs ~w(overview activity settings)

  # Sample rows for the table, bulk-select and picker sections. Plain maps —
  # these components take whatever shape you hand them. Names, roles and
  # statuses are data, not copy, so they are not translated.
  @demo_people [
    %{id: "alice", name: "Alice", role: "admin", status: "active"},
    %{id: "bob", name: "Bob", role: "user", status: "active"},
    %{id: "carol", name: "Carol", role: "user", status: "inactive"},
    %{id: "dave", name: "Dave", role: "user", status: "pending"},
    %{id: "erin", name: "Erin", role: "admin", status: "suspended"}
  ]

  @people_by_id Map.new(@demo_people, &{&1.id, &1})

  # The sort fields a client may ask for. A hardcoded map, never
  # `String.to_existing_atom/1` on the parameter.
  @sortable %{"name" => :name, "role" => :role, "status" => :status}

  @row_actions ~w(view archive)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: gettext("Components"),
       page_section: gettext("Hello World"),
       page_section_path: Paths.index(),
       page_subtitle:
         gettext(
           "A live showcase of commonly-used components from PhoenixKitWeb.Components.Core.*. Copy the snippets into your own module."
         ),
       show_modal: false,
       modal_placement: :center,
       note_form: note_form(""),
       note_dirty: false,
       saved_note: nil,
       show_confirm: false,
       counter: 0,
       active_tab: "overview",
       draggable_items: Enum.map(1..6, &%{id: &1, label: "Item #{&1}"}),
       demo_form: demo_form(),
       profile_form: profile_form(""),
       profile_saved: nil,
       demo_people: @demo_people,
       table_sort: %{by: :name, dir: :asc},
       table_search: "",
       last_row_action: nil,
       selected: MapSet.new(),
       bulk_result: nil,
       picked: []
     )
     |> assign_table_rows()}
  end

  # The `<.pagination>` showcase renders real `<.link patch>` targets pointing
  # back at this page, so clicking one round-trips through `handle_params/3`.
  # There is nothing to read from the URL here — the demo pager is display-only
  # — but the callback has to exist for the patch to resolve.
  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # ── Modal ────────────────────────────────────────────────────────

  @impl true
  def handle_event("open_modal", params, socket) do
    placement = if params["placement"] == "end", do: :end, else: :center

    {:noreply,
     assign(socket,
       show_modal: true,
       modal_placement: placement,
       note_form: note_form(""),
       note_dirty: false
     )}
  end

  # Esc and the backdrop arrive here. The server is the authority on whether
  # unsaved input may be dropped, so a close while the form is dirty is
  # refused — `close_guard` only covers the moment before this process knows.
  def handle_event("close_modal", _, %{assigns: %{note_dirty: true}} = socket),
    do: {:noreply, socket}

  def handle_event("close_modal", _, socket), do: {:noreply, assign(socket, :show_modal, false)}

  def handle_event("validate_note", %{"note" => %{"text" => text}}, socket) do
    {:noreply, assign(socket, note_form: note_form(text), note_dirty: String.trim(text) != "")}
  end

  def handle_event("discard_note", _, socket) do
    {:noreply, assign(socket, show_modal: false, note_form: note_form(""), note_dirty: false)}
  end

  def handle_event("save_note", %{"note" => %{"text" => text}}, socket) do
    case String.trim(text) do
      "" ->
        {:noreply, put_flash(socket, :error, gettext("Write a note before saving."))}

      note ->
        {:noreply,
         socket
         |> assign(
           show_modal: false,
           saved_note: note,
           note_form: note_form(""),
           note_dirty: false
         )
         |> put_flash(:info, gettext("Note saved."))}
    end
  end

  def handle_event("open_confirm", _, socket), do: {:noreply, assign(socket, :show_confirm, true)}

  def handle_event("cancel_confirm", _, socket),
    do: {:noreply, assign(socket, :show_confirm, false)}

  def handle_event("confirmed", _, socket) do
    new_counter = socket.assigns.counter + 1

    {:noreply,
     socket
     |> assign(:show_confirm, false)
     |> assign(:counter, new_counter)
     |> put_flash(:info, gettext("Confirmed! Counter is now %{count}", count: new_counter))}
  end

  def handle_event("bump_counter", _, socket), do: {:noreply, update(socket, :counter, &(&1 + 1))}

  # ── Tabs ─────────────────────────────────────────────────────────

  # Only a known tab id is accepted — never trust a client-supplied string.
  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in @valid_demo_tabs do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # ── Table: sort, search, row menu ────────────────────────────────

  def handle_event("toggle_sort", %{"by" => by}, socket) when is_map_key(@sortable, by) do
    field = Map.fetch!(@sortable, by)

    {:noreply,
     socket
     |> assign(:table_sort, next_sort(socket.assigns.table_sort, field))
     |> assign_table_rows()}
  end

  def handle_event("search_people", %{"search" => query}, socket) when is_binary(query) do
    {:noreply, socket |> assign(:table_search, query) |> assign_table_rows()}
  end

  def handle_event("row_action", %{"action" => action, "id" => id}, socket)
      when action in @row_actions and is_map_key(@people_by_id, id) do
    person = Map.fetch!(@people_by_id, id)
    {:noreply, assign(socket, :last_row_action, {action, person.name})}
  end

  # ── Bulk selection ───────────────────────────────────────────────

  # Server-owned selection (`<.bulk_actions_bar>`): each checkbox is an event.
  def handle_event("toggle_select", %{"id" => id}, socket) when is_map_key(@people_by_id, id) do
    selected = socket.assigns.selected

    selected =
      if MapSet.member?(selected, id),
        do: MapSet.delete(selected, id),
        else: MapSet.put(selected, id)

    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("deselect_all", _, socket),
    do: {:noreply, assign(socket, :selected, MapSet.new())}

  def handle_event("bulk_action", %{"action" => "archive"}, socket) do
    count = MapSet.size(socket.assigns.selected)
    {:noreply, assign(socket, selected: MapSet.new(), bulk_result: {:server, count})}
  end

  # Client-owned selection (`<.bulk_select_scope>`): the server hears about
  # the selection only now, as a list of ids — keep the ones it knows.
  def handle_event("bulk_archive", %{"uuids" => ids}, socket) when is_list(ids) do
    known = ids |> Enum.filter(&is_map_key(@people_by_id, &1)) |> Enum.uniq()
    {:noreply, assign(socket, :bulk_result, {:client, length(known)})}
  end

  # ── Search picker ────────────────────────────────────────────────

  # The picker's dropdown is rendered by core's `SearchPicker` hook; the
  # server only answers the search. Reply on the results event, echoing `q`
  # so the hook can drop an answer to a query the user has typed past.
  def handle_event("picker_search", %{"q" => query}, socket) when is_binary(query) do
    needle = query |> String.trim() |> String.downcase()
    picked = MapSet.new(socket.assigns.picked, & &1.id)

    results =
      for person <- @demo_people,
          not MapSet.member?(picked, person.id),
          needle == "" or String.contains?(String.downcase(person.name), needle) do
        %{kind: "person", uuid: person.id, label: person.name, sublabel: person.role}
      end

    {:noreply,
     push_event(socket, "picker_results", %{q: query, results: results, has_more: false})}
  end

  def handle_event("picker_pick", %{"uuid" => id}, socket) when is_map_key(@people_by_id, id) do
    if Enum.any?(socket.assigns.picked, &(&1.id == id)) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> update(:picked, &(&1 ++ [Map.fetch!(@people_by_id, id)]))
       # Confirms the pick, so the hook clears the input for the next one.
       |> push_event("picker_staged", %{})}
    end
  end

  def handle_event("picker_remove", %{"id" => id}, socket) do
    {:noreply, update(socket, :picked, fn picked -> Enum.reject(picked, &(&1.id == id)) end)}
  end

  # ── Form section ─────────────────────────────────────────────────

  def handle_event("validate_profile", %{"profile" => %{"display_name" => name}}, socket) do
    {:noreply, assign(socket, :profile_form, profile_form(name))}
  end

  def handle_event("save_profile", %{"profile" => %{"display_name" => name}}, socket) do
    {:noreply, assign(socket, profile_form: profile_form(name), profile_saved: String.trim(name))}
  end

  def handle_event("reset_profile", _, socket) do
    {:noreply, assign(socket, profile_form: profile_form(""), profile_saved: nil)}
  end

  # ── Draggable list ───────────────────────────────────────────────

  def handle_event("reorder_items", %{"ordered_ids" => ids}, socket) when is_list(ids) do
    items_map = Map.new(socket.assigns.draggable_items, &{to_string(&1.id), &1})

    # Only accept a reorder that is exactly a permutation of the known ids.
    # Comparing the sorted lists rejects all three ways it can be wrong at
    # once — a missing id, an unknown id, and a duplicate (which has the right
    # length and only known ids, and would silently drop another item).
    if Enum.sort(ids) == Enum.sort(Map.keys(items_map)) do
      {:noreply, assign(socket, :draggable_items, Enum.map(ids, &items_map[&1]))}
    else
      Logger.warning(
        "[ComponentsLive] reorder_items rejected: #{inspect(ids)} is not a permutation of #{map_size(items_map)} known ids"
      )

      {:noreply, socket}
    end
  end

  # Everything the clauses above did not match: a known event carrying a
  # value outside its whitelist or a payload of the wrong shape (a stale page,
  # a crafted push), and the demo forms' "noop". Ignored rather than crashed
  # on — a FunctionClauseError here takes the page down for its user.
  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # Defensive catch-all so a stray PubSub broadcast or OTP message can't
  # crash this LiveView with a FunctionClauseError. Logs at :debug so it
  # never spams in production but stays grep-able during development.
  @impl true
  def handle_info(msg, socket) do
    Logger.debug("[#{inspect(__MODULE__)}] Unhandled info: #{inspect(msg)}")
    {:noreply, socket}
  end

  # ── Helpers ──────────────────────────────────────────────────────

  # Demo forms use a plain map + to_form so we don't need a changeset/schema.
  defp demo_form do
    to_form(%{"name" => "", "email" => "", "bio" => "", "role" => "", "agree" => false})
  end

  defp note_form(text), do: to_form(%{"text" => text}, as: :note)
  defp profile_form(name), do: to_form(%{"display_name" => name}, as: :profile)

  # Same column again flips the direction; a new column starts ascending.
  defp next_sort(%{by: field, dir: :asc}, field), do: %{by: field, dir: :desc}
  defp next_sort(_sort, field), do: %{by: field, dir: :asc}

  defp assign_table_rows(socket) do
    %{demo_people: people, table_search: search, table_sort: %{by: by, dir: dir}} = socket.assigns
    needle = search |> String.trim() |> String.downcase()

    rows =
      people
      |> Enum.filter(&(needle == "" or String.contains?(String.downcase(&1.name), needle)))
      |> Enum.sort_by(&Map.fetch!(&1, by), dir)

    assign(socket, :table_rows, rows)
  end

  # ── Render ───────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col px-4 py-6 gap-6">
      <.icons_section />
      <.badges_section />
      <.buttons_section />
      <.alerts_section />
      <.stat_cards_section />
      <.form_inputs_section />
      <.tables_section />
      <.pagination_section />
      <.empty_states_section />
      <.loading_states_section />

      <.section_divider label={gettext("PhoenixKit Core Components")} />

      <.button_section />
      <.status_badge_section />
      <.collapsible_section />
      <.nav_tabs_section active_tab={@active_tab} />
      <.stat_card_section />
      <.number_formatter_section />
      <.time_display_section />
      <.file_display_section />
      <.language_switcher_section current_locale={assigns[:current_locale]} />
      <.pk_links_section />
      <.form_helpers_section demo_form={@demo_form} />
      <.form_section_section profile_form={@profile_form} profile_saved={@profile_saved} />
      <.modals_section
        show_modal={@show_modal}
        placement={@modal_placement}
        note_form={@note_form}
        note_dirty={@note_dirty}
        saved_note={@saved_note}
        show_confirm={@show_confirm}
        counter={@counter}
      />
      <.popover_panel_section counter={@counter} />
      <.table_default_section
        rows={@table_rows}
        sort={@table_sort}
        search={@table_search}
        last_row_action={@last_row_action}
      />
      <.bulk_select_section people={@demo_people} selected={@selected} bulk_result={@bulk_result} />
      <.search_picker_section picked={@picked} />
      <.pagination_component_section />
      <.empty_state_section />
      <.draggable_list_section items={@draggable_items} />

      <.section_divider label={gettext("Context-dependent components")} />

      <.context_components_section />
      <.footer_link />
    </div>
    """
  end

  # ── Section components ───────────────────────────────────────────
  #
  # One function per showcase section, in the same order as the render.
  # All take `assigns` and return a `<.showcase_section>` block. Sections
  # that need LiveView state declare `attr` for each value passed in.

  defp icons_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Icons")}
      description={gettext("Heroicons via the icon component, imported by the live_view macro.")}
    >
      <div class="flex flex-wrap items-center gap-4">
        <.icon name="hero-sparkles" class="w-6 h-6" />
        <.icon name="hero-bolt" class="w-6 h-6 text-warning" />
        <.icon name="hero-check-circle" class="w-6 h-6 text-success" />
        <.icon name="hero-x-circle" class="w-6 h-6 text-error" />
        <.icon name="hero-information-circle" class="w-6 h-6 text-info" />
        <.icon name="hero-exclamation-triangle" class="w-6 h-6 text-warning" />
        <.icon name="hero-heart-solid" class="w-6 h-6 text-error" />
        <.icon name="hero-star-mini" class="w-4 h-4" />
      </div>
      <:snippet>
        <code>{~s|<.icon name="hero-sparkles" class="w-6 h-6" />|}</code>
        <code>{~s|<.icon name="hero-bolt" class="w-6 h-6 text-warning" />|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  defp badges_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Badges")}
      description={gettext("daisyUI badges for status, labels, and counts.")}
    >
      <div class="flex flex-wrap items-center gap-2">
        <span class="badge">{gettext("Default")}</span>
        <span class="badge badge-primary">{gettext("Primary")}</span>
        <span class="badge badge-secondary">{gettext("Secondary")}</span>
        <span class="badge badge-accent">{gettext("Accent")}</span>
        <span class="badge badge-success">{gettext("Success")}</span>
        <span class="badge badge-warning">{gettext("Warning")}</span>
        <span class="badge badge-error">{gettext("Error")}</span>
        <span class="badge badge-info">{gettext("Info")}</span>
        <span class="badge badge-ghost">{gettext("Ghost")}</span>
        <span class="badge badge-outline">{gettext("Outline")}</span>
      </div>
      <div class="flex flex-wrap items-center gap-2 mt-2">
        <span class="badge badge-xs badge-success">xs</span>
        <span class="badge badge-sm badge-success">sm</span>
        <span class="badge badge-success">md</span>
        <span class="badge badge-lg badge-success">lg</span>
      </div>
      <:snippet>
        <code>{~s|<span class="badge badge-primary">Primary</span>|}</code>
        <code>{~s|<span class="badge badge-sm badge-success">sm</span>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "For a record's status, prefer the status_badge component below the divider — it picks the colour from the status."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp buttons_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Buttons")}
      description={gettext("daisyUI buttons — various colors, sizes, and states.")}
    >
      <div class="flex flex-wrap items-center gap-2">
        <button class="btn btn-primary">{gettext("Primary")}</button>
        <button class="btn btn-secondary">{gettext("Secondary")}</button>
        <button class="btn btn-accent">{gettext("Accent")}</button>
        <button class="btn btn-ghost">{gettext("Ghost")}</button>
        <button class="btn btn-outline">{gettext("Outline")}</button>
        <button class="btn btn-primary" disabled>{gettext("Disabled")}</button>
      </div>
      <div class="flex flex-wrap items-center gap-2 mt-2">
        <button class="btn btn-xs btn-primary">xs</button>
        <button class="btn btn-sm btn-primary">sm</button>
        <button class="btn btn-primary">md</button>
        <button class="btn btn-lg btn-primary">lg</button>
      </div>
      <div class="flex flex-wrap items-center gap-2 mt-2">
        <button class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" /> {gettext("With icon")}
        </button>
        <button class="btn btn-ghost btn-sm btn-square" title={gettext("Icon-only")}>
          <.icon name="hero-pencil-square" class="w-4 h-4" />
        </button>
      </div>
      <:snippet>
        <code>{~s|<button class="btn btn-primary">Primary</button>|}</code>
        <code>{~s|<button class="btn btn-primary"><.icon name="hero-plus" class="w-4 h-4" /> With icon</button>|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  defp alerts_section(assigns) do
    ~H"""
    <.showcase_section title={gettext("Alerts")} description={gettext("Inline messages and notices.")}>
      <div class="flex flex-col gap-2">
        <div class="alert alert-info">
          <.icon name="hero-information-circle" class="w-5 h-5" />
          <span>{gettext("Heads up — this is an info message.")}</span>
        </div>
        <div class="alert alert-success">
          <.icon name="hero-check-circle" class="w-5 h-5" />
          <span>{gettext("Nice — you did the thing.")}</span>
        </div>
        <div class="alert alert-warning">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <span>{gettext("Careful — double-check before proceeding.")}</span>
        </div>
        <div class="alert alert-error">
          <.icon name="hero-x-circle" class="w-5 h-5" />
          <span>{gettext("Something went wrong.")}</span>
        </div>
      </div>
      <:snippet>
        <code>{~s|<div class="alert alert-info"><.icon name="hero-information-circle" class="w-5 h-5" /><span>Info</span></div>|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  defp stat_cards_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Stat cards")}
      description={gettext("Summary cards showing a metric with an icon and label.")}
    >
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex items-center gap-3">
              <div class="p-2 bg-primary/10 rounded-lg">
                <.icon name="hero-users" class="w-6 h-6 text-primary" />
              </div>
              <div>
                <p class="text-xs text-base-content/60">{gettext("Users")}</p>
                <p class="text-2xl font-bold">1,234</p>
              </div>
            </div>
          </div>
        </div>
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex items-center gap-3">
              <div class="p-2 bg-success/10 rounded-lg">
                <.icon name="hero-currency-dollar" class="w-6 h-6 text-success" />
              </div>
              <div>
                <p class="text-xs text-base-content/60">{gettext("Revenue")}</p>
                <p class="text-2xl font-bold">$8,456</p>
              </div>
            </div>
          </div>
        </div>
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex items-center gap-3">
              <div class="p-2 bg-warning/10 rounded-lg">
                <.icon name="hero-shopping-cart" class="w-6 h-6 text-warning" />
              </div>
              <div>
                <p class="text-xs text-base-content/60">{gettext("Orders")}</p>
                <p class="text-2xl font-bold">89</p>
              </div>
            </div>
          </div>
        </div>
      </div>
      <:snippet>
        <code>{~s|<div class="card bg-base-100 shadow"><div class="card-body">...</div></div>|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  defp form_inputs_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Form inputs")}
      description={gettext("daisyUI form controls — text, textarea, select, checkbox.")}
    >
      <.form
        for={%{}}
        id="demo-raw-inputs-form"
        phx-change="noop"
        phx-submit="noop"
        class="grid grid-cols-1 md:grid-cols-2 gap-4"
      >
        <div class="fieldset">
          <label class="label"><span class="fieldset-legend">{gettext("Text input")}</span></label>
          <input type="text" placeholder={gettext("Type here")} class="input input-sm" />
        </div>
        <div class="fieldset">
          <label class="label"><span class="fieldset-legend">{gettext("Select")}</span></label>
          <label class="select select-sm">
            <select>
              <option>{gettext("Option A")}</option>
              <option>{gettext("Option B")}</option>
              <option>{gettext("Option C")}</option>
            </select>
          </label>
        </div>
        <div class="fieldset md:col-span-2">
          <label class="label"><span class="fieldset-legend">{gettext("Textarea")}</span></label>
          <textarea class="textarea" rows="3" placeholder={gettext("Multi-line...")}></textarea>
        </div>
        <div class="fieldset">
          <label class="label cursor-pointer justify-start gap-2">
            <input type="checkbox" class="checkbox checkbox-primary checkbox-sm" checked />
            <span class="fieldset-legend">{gettext("Checkbox")}</span>
          </label>
        </div>
        <div class="fieldset">
          <label class="label cursor-pointer justify-start gap-2">
            <input type="radio" name="radio-demo" class="radio radio-primary radio-sm" checked />
            <span class="fieldset-legend">{gettext("Radio")}</span>
          </label>
        </div>
      </.form>
      <:snippet>
        <code>{~s|<input type="text" class="input input-sm" />|}</code>
        <code>{~s|<label class="select select-sm"><select>...</select></label>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "daisyUI 5 styles a select through a wrapping label that carries the select class. A form with phx-change needs an id, or LiveView cannot recover it after a reconnect."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp tables_section(assigns) do
    ~H"""
    <.showcase_section title={gettext("Tables")} description={gettext("A standard daisyUI table.")}>
      <div class="overflow-x-auto">
        <table class="table table-sm table-zebra">
          <thead>
            <tr>
              <th>{gettext("Name")}</th>
              <th>{gettext("Role")}</th>
              <th>{gettext("Status")}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Alice</td>
              <td><span class="badge badge-warning badge-xs">admin</span></td>
              <td><span class="badge badge-success badge-xs">active</span></td>
              <td>
                <button class="btn btn-ghost btn-xs btn-square">
                  <.icon name="hero-pencil-square" class="w-4 h-4" />
                </button>
              </td>
            </tr>
            <tr>
              <td>Bob</td>
              <td><span class="badge badge-ghost badge-xs">user</span></td>
              <td><span class="badge badge-success badge-xs">active</span></td>
              <td>
                <button class="btn btn-ghost btn-xs btn-square">
                  <.icon name="hero-pencil-square" class="w-4 h-4" />
                </button>
              </td>
            </tr>
            <tr>
              <td>Carol</td>
              <td><span class="badge badge-ghost badge-xs">user</span></td>
              <td><span class="badge badge-error badge-xs">inactive</span></td>
              <td>
                <button class="btn btn-ghost btn-xs btn-square">
                  <.icon name="hero-pencil-square" class="w-4 h-4" />
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <:snippet>
        <code>{~s|<table class="table table-sm table-zebra">...</table>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "Prefer the wrapped counterpart below the divider — table_default adds the scroll wrapper, a toolbar, sortable headers, a row menu and a mobile card view."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp pagination_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Pagination")}
      description={gettext("Page navigation using daisyUI joined buttons.")}
    >
      <div class="flex justify-center">
        <div class="join">
          <button class="join-item btn btn-sm">«</button>
          <button class="join-item btn btn-sm">1</button>
          <button class="join-item btn btn-sm btn-active">2</button>
          <button class="join-item btn btn-sm">3</button>
          <button class="join-item btn btn-sm">4</button>
          <button class="join-item btn btn-sm">»</button>
        </div>
      </div>
      <:snippet>
        <code>{~s|<div class="join"><button class="join-item btn btn-sm">1</button>...</div>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "Prefer the wrapped counterpart below the divider — pagination builds the page URLs for you and preserves the existing query string."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp empty_states_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Empty states")}
      description={gettext("What to show when there's no data.")}
    >
      <div class="text-center py-8 text-base-content/60 border border-dashed border-base-300 rounded-lg">
        <.icon name="hero-inbox" class="w-12 h-12 mx-auto mb-2 opacity-50" />
        <p class="font-semibold">{gettext("Nothing here yet")}</p>
        <p class="text-xs mt-1">{gettext("Create your first item to get started.")}</p>
        <button class="btn btn-primary btn-sm mt-4">
          <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Create")}
        </button>
      </div>
      <:snippet>
        <code>{~s|<div class="text-center py-8"><.icon name="hero-inbox" class="w-12 h-12 mx-auto" />...</div>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "Prefer the wrapped counterpart below the divider — empty_state ships three variants and keeps every list view's empty panel identical."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp loading_states_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Loading states")}
      description={gettext("Spinners and skeleton placeholders.")}
    >
      <div class="flex flex-wrap items-center gap-4">
        <span class="loading loading-spinner loading-sm"></span>
        <span class="loading loading-spinner"></span>
        <span class="loading loading-spinner loading-lg text-primary"></span>
        <span class="loading loading-dots loading-md"></span>
        <span class="loading loading-bars loading-md"></span>
      </div>
      <div class="flex flex-col gap-2 mt-4">
        <div class="skeleton h-4 w-full"></div>
        <div class="skeleton h-4 w-3/4"></div>
        <div class="skeleton h-4 w-1/2"></div>
      </div>
      <:snippet>
        <code>{~s|<span class="loading loading-spinner loading-sm"></span>|}</code>
        <code>{~s|<div class="skeleton h-4 w-full"></div>|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  defp button_section(assigns) do
    assigns = assign(assigns, :self_path, Paths.components())

    ~H"""
    <.showcase_section
      title={gettext("Button — core button")}
      description={
        gettext(
          "The wrapped counterpart to the raw buttons above. The variant replaces the base colour instead of fighting it, and a navigate, patch or href attribute renders a link styled as a button."
        )
      }
    >
      <div class="flex flex-wrap items-center gap-2" id="demo-core-buttons">
        <.button>{gettext("Primary")}</.button>
        <.button variant="secondary">{gettext("Secondary")}</.button>
        <.button variant="outline">{gettext("Outline")}</.button>
        <.button variant="ghost">{gettext("Ghost")}</.button>
        <.button variant="success">{gettext("Success")}</.button>
        <.button variant="warning">{gettext("Warning")}</.button>
        <.button variant="error">{gettext("Error")}</.button>
        <.button disabled>{gettext("Disabled")}</.button>
      </div>
      <div class="flex flex-wrap items-center gap-2 mt-2">
        <.button size="xs">xs</.button>
        <.button size="sm">sm</.button>
        <.button size="md">md</.button>
        <.button size="lg">lg</.button>
        <.button size="sm" variant="outline" patch={@self_path} id="demo-button-link">
          <.icon name="hero-arrow-path" class="w-4 h-4" /> {gettext("A link, styled as a button")}
        </.button>
      </div>
      <:snippet>
        <code>{~s|<.button phx-click="save">Save</.button>|}</code>
        <code>{~s|<.button variant="ghost" size="sm">Cancel</.button>|}</code>
        <code>{~s|<.button variant="error" phx-click="delete" phx-disable-with="Deleting…">Delete</.button>|}</code>
        <code>{~s|<.button navigate={Paths.new_item()}>New item</.button>|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  defp status_badge_section(assigns) do
    assigns =
      assign(assigns, :statuses, ~w(active inactive draft published pending in_progress
        completed failed suspended archived deleted))

    ~H"""
    <.showcase_section
      title={gettext("Status badge — core status_badge")}
      description={
        gettext(
          "One badge for a record's status. The colour comes from the status string, so every list in every module shows the same status the same way."
        )
      }
    >
      <div class="flex flex-wrap items-center gap-2" id="demo-status-badges">
        <.status_badge :for={status <- @statuses} status={status} />
      </div>
      <div class="flex flex-wrap items-center gap-2 mt-2">
        <.status_badge status="active" size={:xs} />
        <.status_badge status="active" size={:sm} />
        <.status_badge status="active" size={:md} />
        <.status_badge status="active" size={:lg} />
        <.status_badge status="something_else" />
      </div>
      <:snippet>
        <code>{~s|<.status_badge status={item.status} />|}</code>
        <code>{~s|<.status_badge status="in_progress" size={:xs} />|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "An unknown status renders as a neutral badge rather than raising. The label is the status string with underscores as spaces."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp collapsible_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Collapsible sections")}
      description={
        gettext(
          "daisyUI's collapse, and core's accordion — a native details element that keeps the state the user left it in."
        )
      }
    >
      <div class="flex flex-col gap-2">
        <div tabindex="0" class="collapse collapse-arrow bg-base-100 border border-base-300">
          <div class="collapse-title font-medium">{gettext("What is PhoenixKit?")}</div>
          <div class="collapse-content text-sm">
            <p>
              {gettext(
                "A modular framework for Elixir/Phoenix apps — auth, admin dashboard, activity logging, role-based access, and more."
              )}
            </p>
          </div>
        </div>
        <.accordion id="demo-accordion">
          <:title>{gettext("How do I add a module?")}</:title>
          <:content>
            <p class="text-sm">
              {gettext(
                "Implement the PhoenixKit.Module behaviour and list your module as a dependency. Auto-discovery handles the rest."
              )}
            </p>
          </:content>
        </.accordion>
      </div>
      <:snippet>
        <code>{~s|<div tabindex="0" class="collapse collapse-arrow bg-base-100 border">|}</code>
        <code>{~s|  <div class="collapse-title">Title</div>|}</code>
        <code>{~s|  <div class="collapse-content">Content</div>|}</code>
        <code>{~s|</div>|}</code>
        <code>{~s|<.accordion id="advanced" open>|}</code>
        <code>{~s|  <:title>Advanced</:title>|}</code>
        <code>{~s|  <:content>...</:content>|}</code>
        <code>{~s|</.accordion>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "The accordion's open attribute is the initial state only: after mount the browser owns it, so a section the user opened survives LiveView re-renders. There is no server event for a toggle."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:active_tab, :string, required: true)

  defp nav_tabs_section(assigns) do
    assigns =
      assign(assigns, :tabs, [
        %{id: "overview", label: gettext("Overview"), icon: "hero-home"},
        %{id: "activity", label: gettext("Activity"), icon: "hero-clock", badge: 3},
        %{id: "settings", label: gettext("Settings"), icon: "hero-cog-6-tooth"}
      ])

    ~H"""
    <.showcase_section
      title={gettext("Nav tabs")}
      description={
        gettext(
          "Horizontal tabs in three variants. A tab with a link key navigates; a tab without one fires the on_change event."
        )
      }
    >
      <div class="flex flex-col gap-4">
        <div id="demo-tabs-boxed">
          <p class="text-xs text-base-content/60 mb-1">
            {gettext("boxed (default), with a trailing slot for a control that belongs to the strip:")}
          </p>
          <.nav_tabs active_tab={@active_tab} on_change="switch_tab" tabs={@tabs}>
            <:trailing>
              <span class="text-xs text-base-content/60">{gettext("3 new")}</span>
            </:trailing>
          </.nav_tabs>
        </div>
        <div id="demo-tabs-border">
          <p class="text-xs text-base-content/60 mb-1">
            {gettext("border — the underline look, for show pages and settings:")}
          </p>
          <.nav_tabs variant={:border} active_tab={@active_tab} on_change="switch_tab" tabs={@tabs} />
        </div>
        <div id="demo-tabs-plain">
          <p class="text-xs text-base-content/60 mb-1">
            {gettext("plain — no frame, for tabs inside an already framed container:")}
          </p>
          <.nav_tabs variant={:plain} active_tab={@active_tab} on_change="switch_tab" tabs={@tabs} />
        </div>
      </div>
      <div class="mt-4 p-4 bg-base-200 rounded text-sm">
        {gettext("Active tab:")} <strong>{@active_tab}</strong>
      </div>
      <:snippet>
        <code>{~s|<.nav_tabs active_tab={@tab} on_change="switch_tab" tabs={[%{id: "x", label: "X", badge: 3}]} />|}</code>
        <code>{~s|<.nav_tabs variant={:border} active_tab={@tab} tabs={[%{id: "x", label: "X", patch: Paths.x()}]}>|}</code>
        <code>{~s|  <:trailing>...</:trailing>|}</code>
        <code>{~s|</.nav_tabs>|}</code>
        <code>{~s|def handle_event("switch_tab", %{"tab" => id}, socket) when id in @valid_tabs|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  defp stat_card_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Stat card")}
      description={gettext("Core's stat_card with color variants and an icon slot.")}
    >
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <.stat_card
          value={42}
          title={gettext("Users")}
          subtitle={gettext("Total registered")}
          color="primary"
        >
          <:icon><.icon name="hero-users" class="w-6 h-6" /></:icon>
        </.stat_card>
        <.stat_card
          value={17}
          title={gettext("Active sessions")}
          subtitle={gettext("Last 5 minutes")}
          color="success"
        >
          <:icon><.icon name="hero-signal" class="w-6 h-6" /></:icon>
        </.stat_card>
        <.stat_card
          value={3}
          title={gettext("Pending issues")}
          subtitle={gettext("Require attention")}
          color="warning"
        >
          <:icon>
            <.icon name="hero-exclamation-triangle" class="w-6 h-6" />
          </:icon>
        </.stat_card>
      </div>
      <:snippet>
        <code>{~s|<.stat_card value={42} title="Users" subtitle="..." color="primary"><:icon>...</:icon></.stat_card>|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  defp number_formatter_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Number formatter")}
      description={gettext("Format numbers as grouped (1,234,567) or short (1.2M).")}
    >
      <div class="flex flex-col gap-2 text-sm">
        <div>
          {gettext("Grouped:")} <.formatted_number number={1_234_567} class="font-mono font-bold" />
        </div>
        <div>
          {gettext("Short:")}
          <.formatted_number number={1_234_567} format={:short} class="font-mono font-bold" />
        </div>
      </div>
      <:snippet>
        <code>{~s|<.formatted_number number={1234567} />|}</code>
        <code>{~s|<.formatted_number number={1234567} format={:short} />|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  defp time_display_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Time display")}
      description={gettext("time_ago, which updates itself in the browser, and age_badge.")}
    >
      <div class="flex flex-wrap items-center gap-4 text-sm">
        <.time_ago datetime={DateTime.utc_now()} class="font-mono" />
        <.time_ago datetime={DateTime.add(DateTime.utc_now(), -300, :second)} class="font-mono" />
        <.time_ago datetime={DateTime.add(DateTime.utc_now(), -3, :day)} class="font-mono" />
      </div>
      <div class="flex flex-wrap items-center gap-2 mt-3">
        <span class="text-sm text-base-content/60">{gettext("Age badges:")}</span>
        <.age_badge days={0} />
        <.age_badge days={3} />
        <.age_badge days={15} />
        <.age_badge days={45} />
      </div>
      <:snippet>
        <code>{~s|<.time_ago datetime={@record.inserted_at} />|}</code>
        <code>{~s|<.age_badge days={5} />|}</code>
        <p class="text-xs text-base-content/50">
          {gettext("time_ago uses core's TimeAgo hook for live updates.")}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp file_display_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("File display")}
      description={gettext("Helpers for file size, modification time, and page status.")}
    >
      <div class="flex flex-col gap-3 text-sm">
        <div class="flex flex-wrap items-center gap-3">
          <span class="text-base-content/60">{gettext("File sizes:")}</span>
          <.file_size bytes={512} class="badge badge-ghost badge-sm" />
          <.file_size bytes={2_048} class="badge badge-ghost badge-sm" />
          <.file_size bytes={1_048_576} class="badge badge-ghost badge-sm" />
          <.file_size bytes={52_428_800} class="badge badge-ghost badge-sm" />
        </div>
        <div class="flex flex-wrap items-center gap-3">
          <span class="text-base-content/60">{gettext("Modification time:")}</span>
          <.file_mtime mtime={~N[2025-01-15 10:00:00]} class="font-mono text-xs" />
        </div>
        <div class="flex flex-wrap items-center gap-3">
          <span class="text-base-content/60">{gettext("Page status:")}</span>
          <.page_status_badge status="published" />
          <.page_status_badge status="draft" />
          <.page_status_badge status="archived" />
        </div>
      </div>
      <:snippet>
        <code>{~s|<.file_size bytes={1_048_576} />  # → 1.0 MB|}</code>
        <code>{~s|<.file_mtime mtime={stat.mtime} />|}</code>
        <code>{~s|<.page_status_badge status="published" />|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:current_locale, :string, default: nil)

  defp language_switcher_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Language switcher")}
      description={
        gettext(
          "Locale pickers in three variants. Languages is part of core: each variant lists the languages enabled under Settings → Languages."
        )
      }
    >
      <div class="flex flex-col gap-4">
        <div>
          <p class="text-xs text-base-content/60 mb-2">
            {gettext("Dropdown — compact, for headers and navbars:")}
          </p>
          <.language_switcher_dropdown current_locale={@current_locale} />
        </div>
        <div>
          <p class="text-xs text-base-content/60 mb-2">
            {gettext("Buttons — one visible button per language:")}
          </p>
          <.language_switcher_buttons current_locale={@current_locale} class="flex-wrap" />
        </div>
        <div>
          <p class="text-xs text-base-content/60 mb-2">
            {gettext("Inline — plain text links, for footers:")}
          </p>
          <.language_switcher_inline current_locale={@current_locale} class="flex-wrap" />
        </div>
      </div>
      <:snippet>
        <code>{~s|<.language_switcher_dropdown current_locale={@current_locale} />|}</code>
        <code>{~s|<.language_switcher_buttons current_locale={@current_locale} class="flex-wrap" />|}</code>
        <code>{~s|<.language_switcher_inline current_locale={@current_locale} class="flex-wrap" />|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  defp pk_links_section(assigns) do
    assigns = assign(assigns, :self_path, "/admin/hello-world/components")

    ~H"""
    <.showcase_section
      title={gettext("PhoenixKit links")}
      description={
        gettext(
          "Prefix-aware links: they prepend the host's PhoenixKit URL prefix and the current locale. The links below all point back to this page."
        )
      }
    >
      <div class="flex flex-wrap items-center gap-2">
        <.pk_link navigate={@self_path} class="link link-primary">
          {gettext("Regular link")}
        </.pk_link>
        <.pk_link_button navigate={@self_path} variant="primary">
          {gettext("Primary")}
        </.pk_link_button>
        <.pk_link_button navigate={@self_path} variant="outline">
          {gettext("Outline")}
        </.pk_link_button>
        <.pk_link_button navigate={@self_path} variant="ghost">
          {gettext("Ghost")}
        </.pk_link_button>
      </div>
      <:snippet>
        <code>{~s|<.pk_link navigate="/dashboard">Dashboard</.pk_link>|}</code>
        <code>{~s|<.pk_link_button navigate="/admin/users" variant="primary">Manage</.pk_link_button>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "These take a raw path starting with a slash and apply the prefix themselves. A path that already went through Routes.path — every Paths helper — goes to a plain link or to the button component instead, or it is prefixed twice."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:demo_form, :any, required: true)

  defp form_helpers_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Form helpers")}
      description={
        gettext(
          "simple_form with input, select, textarea and checkbox: each wires its label and error display to the form field."
        )
      }
    >
      <.simple_form for={@demo_form} id="demo-helpers-form" phx-change="noop" phx-submit="noop">
        <.input field={@demo_form[:name]} type="text" label={gettext("Name")} placeholder="Alice" />
        <.input field={@demo_form[:email]} type="email" label={gettext("Email")} />
        <.select
          field={@demo_form[:role]}
          label={gettext("Role")}
          options={[{gettext("Admin"), "admin"}, {gettext("User"), "user"}, {gettext("Guest"), "guest"}]}
          prompt={gettext("Choose one")}
        />
        <.textarea field={@demo_form[:bio]} label={gettext("Bio")} rows="3" />
        <.checkbox field={@demo_form[:agree]} label={gettext("I agree to the terms")} />
        <:actions>
          <button type="submit" class="btn btn-primary btn-sm">{gettext("Save")}</button>
        </:actions>
      </.simple_form>
      <:snippet>
        <code>{~s|<.simple_form for={@form} id="item-form" phx-change="validate" phx-submit="save">|}</code>
        <code>{~s|  <.input field={@form[:email]} type="email" label="Email" />|}</code>
        <code>{~s|  <.select field={@form[:role]} options={[{"A", "a"}]} />|}</code>
        <code>{~s|  <.textarea field={@form[:bio]} label="Bio" />|}</code>
        <code>{~s|  <.checkbox field={@form[:agree]} label="Agree" />|}</code>
        <code>{~s|  <:actions><button>Save</button></:actions>|}</code>
        <code>{~s|</.simple_form>|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:profile_form, :any, required: true)
  attr(:profile_saved, :string, default: nil)

  defp form_section_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Form section and form actions")}
      description={
        gettext(
          "The two pieces every edit page is built from: form_section is the titled card around a group of fields, form_actions is the Cancel and Submit footer."
        )
      }
    >
      <.form
        for={@profile_form}
        id="demo-profile-form"
        phx-change="validate_profile"
        phx-submit="save_profile"
        class="flex flex-col gap-4 max-w-xl"
      >
        <.form_section title={gettext("Profile")} icon="hero-user-circle" body_class="space-y-4">
          <:subtitle>{gettext("Shown next to everything you post.")}</:subtitle>
          <.input field={@profile_form[:display_name]} type="text" label={gettext("Display name")} />
        </.form_section>
        <.form_actions
          cancel_click="reset_profile"
          submit_label={gettext("Save profile")}
          submit_icon="hero-check"
        />
      </.form>
      <p :if={@profile_saved} class="text-sm mt-3" id="demo-profile-saved">
        {gettext("Saved display name: %{name}", name: @profile_saved)}
      </p>
      <:snippet>
        <code>{~s|<.form for={@form} id="profile-form" phx-change="validate" phx-submit="save">|}</code>
        <code>{~s|  <.form_section title="Profile" icon="hero-user-circle" body_class="space-y-4">|}</code>
        <code>{~s|    <:subtitle>Shown next to everything you post.</:subtitle>|}</code>
        <code>{~s|    <.input field={@form[:display_name]} label="Display name" />|}</code>
        <code>{~s|  </.form_section>|}</code>
        <code>{~s|  <.form_actions cancel_to={Paths.index()} submit_label="Save" submit_icon="hero-check" />|}</code>
        <code>{~s|</.form>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "Cancel is a link with cancel_to, an event with cancel_click (add cancel_target inside a LiveComponent), or your own markup in the cancel slot — one of the three."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:show_modal, :boolean, required: true)
  attr(:placement, :atom, required: true)
  attr(:note_form, :any, required: true)
  attr(:note_dirty, :boolean, required: true)
  attr(:saved_note, :string, default: nil)
  attr(:show_confirm, :boolean, required: true)
  attr(:counter, :integer, required: true)

  defp modals_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Modals")}
      description={
        gettext(
          "Core's modal opens as a real top-layer dialog: Esc and the backdrop close it, focus is trapped, and it can open as a drawer. confirm_modal is the ready-made confirmation."
        )
      }
    >
      <div class="flex flex-wrap gap-2">
        <button type="button" phx-click="open_modal" class="btn btn-primary btn-sm">
          {gettext("Open modal")}
        </button>
        <button
          type="button"
          phx-click="open_modal"
          phx-value-placement="end"
          class="btn btn-outline btn-sm"
        >
          {gettext("Open as drawer")}
        </button>
        <button type="button" phx-click="open_confirm" class="btn btn-error btn-sm">
          {gettext("Open confirm (counter: %{count})", count: @counter)}
        </button>
      </div>
      <p :if={@saved_note} class="text-sm mt-3" id="demo-saved-note">
        {gettext("Saved note: %{note}", note: @saved_note)}
      </p>

      <%!-- `closeable` is the server's answer to "may this close now"; with
           unsaved input it is false. `close_guard={:input}` covers the gap
           before the server has heard of the first keystroke. --%>
      <.modal
        id="demo-modal"
        show={@show_modal}
        on_close="close_modal"
        placement={@placement}
        max_width="lg"
        closeable={not @note_dirty}
        close_guard={:input}
      >
        <:title>
          <.icon name="hero-pencil-square" class="w-5 h-5" />
          {gettext("Leave a note")}
        </:title>
        <.form for={@note_form} id="demo-note-form" phx-change="validate_note" phx-submit="save_note">
          <.input field={@note_form[:text]} type="text" label={gettext("Note")} />
        </.form>
        <p class="text-xs text-base-content/60 mt-3">
          {gettext(
            "Type something, then press Esc or click outside: the dialog stays open, because closing would discard what you typed. Use Discard or Save."
          )}
        </p>
        <:actions>
          <button type="button" phx-click="discard_note" class="btn btn-ghost btn-sm">
            {gettext("Discard")}
          </button>
          <button
            type="submit"
            form="demo-note-form"
            phx-disable-with={gettext("Saving…")}
            class="btn btn-primary btn-sm"
          >
            {gettext("Save")}
          </button>
        </:actions>
      </.modal>

      <.confirm_modal
        show={@show_confirm}
        title={gettext("Confirm action")}
        prompt={gettext("Are you sure you want to increment the counter?")}
        confirm_text={gettext("Yes, increment")}
        cancel_text={gettext("Cancel")}
        on_confirm="confirmed"
        on_cancel="cancel_confirm"
      />

      <:snippet>
        <code>{~s|<.modal id="note-modal" show={@show} on_close="close_modal" placement={:end}|}</code>
        <code>{~s|  closeable={not @dirty} close_guard={:input}>|}</code>
        <code>{~s|  <:title>Leave a note</:title>|}</code>
        <code>{~s|  <.form for={@form} id="note-form" phx-change="validate" phx-submit="save">...</.form>|}</code>
        <code>{~s|  <:actions><button type="submit" form="note-form" class="btn btn-primary">Save</button></:actions>|}</code>
        <code>{~s|</.modal>|}</code>
        <code>{~s|<.confirm_modal show={@show} title="..." prompt="..." on_confirm="..." on_cancel="..." />|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "The submit button lives in the actions slot, outside the form, and is tied to it by the form attribute. Never build a modal from a raw dialog element with the modal-open class: it is not in the top layer, so it has no focus trap and Esc does nothing."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:counter, :integer, required: true)

  defp popover_panel_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Popover panel")}
      description={
        gettext(
          "An anchored panel for rich content — filters, pickers, small forms. It opens in the browser with no round-trip, and stays open while its content talks to the server."
        )
      }
    >
      <div class="relative inline-block">
        <button type="button" phx-click={toggle_popover("demo-popover")} class="btn btn-sm btn-outline">
          <.icon name="hero-funnel" class="w-4 h-4" /> {gettext("Open panel")}
        </button>

        <.popover_panel id="demo-popover" align="start" width_class="sm:w-80">
          <div class="card-body gap-3">
            <p class="text-sm">
              {gettext("This button asks the server; the panel stays open through the re-render.")}
            </p>
            <button type="button" phx-click="bump_counter" class="btn btn-sm">
              {gettext("Counter: %{count}", count: @counter)}
            </button>
            <button type="button" phx-click={hide_popover("demo-popover")} class="btn btn-sm btn-ghost">
              {gettext("Done")}
            </button>
          </div>
        </.popover_panel>
      </div>
      <:snippet>
        <code>{~s|<div class="relative">|}</code>
        <code>{~s|  <button type="button" phx-click={toggle_popover("filters")} class="btn btn-sm">Filters</button>|}</code>
        <code>{~s|  <.popover_panel id="filters" align="start">|}</code>
        <code>{~s|    <button phx-click={hide_popover("filters")}>Done</button>|}</code>
        <code>{~s|  </.popover_panel>|}</code>
        <code>{~s|</div>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "Render the panel inside a relative wrapper, next to its trigger. For a short list of row actions use table_row_menu instead."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:rows, :list, required: true)
  attr(:sort, :map, required: true)
  attr(:search, :string, required: true)
  attr(:last_row_action, :any, default: nil)

  defp table_default_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Table — core table_default")}
      description={
        gettext(
          "The wrapped counterpart to the raw table above, as a list page uses it: a search box in the toolbar, sortable headers, a row menu, and a card view on small screens."
        )
      }
    >
      <.table_default
        id="demo-people-table"
        toggleable
        variant="zebra"
        size="sm"
        items={@rows}
        item_id={& &1.id}
        card_title={& &1.name}
        card_fields={
          &[
            %{label: gettext("Role"), value: &1.role},
            %{label: gettext("Status"), value: &1.status}
          ]
        }
      >
        <:toolbar_title>
          <.search_toolbar
            id="demo-people-search"
            value={@search}
            on_change="search_people"
            placeholder={gettext("Search by name…")}
          />
        </:toolbar_title>
        <:toolbar_actions>
          <span class="text-sm text-base-content/60" id="demo-people-count">
            {ngettext("%{count} person", "%{count} people", length(@rows))}
          </span>
        </:toolbar_actions>
        <.table_default_header>
          <.table_default_row>
            <.sort_header_cell field={:name} sort={@sort}>{gettext("Name")}</.sort_header_cell>
            <.sort_header_cell field={:role} sort={@sort}>{gettext("Role")}</.sort_header_cell>
            <.sort_header_cell field={:status} sort={@sort}>{gettext("Status")}</.sort_header_cell>
            <.table_default_header_cell class="w-10" />
          </.table_default_row>
        </.table_default_header>
        <.table_default_body>
          <.table_default_row :for={person <- @rows} id={"demo-person-#{person.id}"}>
            <.table_default_cell>{person.name}</.table_default_cell>
            <.table_default_cell>
              <span class="badge badge-ghost badge-xs">{person.role}</span>
            </.table_default_cell>
            <.table_default_cell><.status_badge status={person.status} size={:xs} /></.table_default_cell>
            <.table_default_cell>
              <.table_row_menu id={"demo-person-menu-#{person.id}"} label={gettext("Actions")}>
                <.table_row_menu_button
                  phx-click="row_action"
                  phx-value-action="view"
                  phx-value-id={person.id}
                  icon="hero-eye"
                  label={gettext("View")}
                />
                <.table_row_menu_divider />
                <.table_row_menu_button
                  phx-click="row_action"
                  phx-value-action="archive"
                  phx-value-id={person.id}
                  icon="hero-archive-box"
                  label={gettext("Archive")}
                  variant="warning"
                />
              </.table_row_menu>
            </.table_default_cell>
          </.table_default_row>
        </.table_default_body>
      </.table_default>

      <.empty_state
        :if={@rows == []}
        icon="hero-funnel"
        title={gettext("No people match this search.")}
        class="py-8"
      />
      <p :if={@last_row_action} class="text-sm mt-3" id="demo-row-action">
        {row_action_text(@last_row_action)}
      </p>
      <:snippet>
        <code>{~s|<.table_default id="people" toggleable items={@people} item_id={& &1.uuid} card_title={& &1.name}>|}</code>
        <code>{~s|  <:toolbar_title><.search_toolbar value={@search} on_change="search" /></:toolbar_title>|}</code>
        <code>{~s|  <.table_default_header><.table_default_row>|}</code>
        <code>{~s|    <.sort_header_cell field={:name} sort={@sort}>Name</.sort_header_cell>|}</code>
        <code>{~s|  </.table_default_row></.table_default_header>|}</code>
        <code>{~s|  <.table_default_body>|}</code>
        <code>{~s|    <.table_default_row :for={p <- @people}>|}</code>
        <code>{~s|      <.table_default_cell>{p.name}</.table_default_cell>|}</code>
        <code>{~s|      <.table_default_cell>|}</code>
        <code>{~s|        <.table_row_menu id={"menu-" <> p.uuid}>|}</code>
        <code>{~s|          <.table_row_menu_link navigate={Paths.edit(p)} icon="hero-pencil" label="Edit" />|}</code>
        <code>{~s|          <.table_row_menu_button phx-click="delete" phx-value-id={p.uuid} label="Delete" variant="error" />|}</code>
        <code>{~s|        </.table_row_menu>|}</code>
        <code>{~s|      </.table_default_cell>|}</code>
        <code>{~s|    </.table_default_row>|}</code>
        <code>{~s|  </.table_default_body>|}</code>
        <code>{~s|</.table_default>|}</code>
        <code>{~s|def handle_event("toggle_sort", %{"by" => by}, socket)  # map `by` through a fixed whitelist|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "sort is a map with by and dir; a header click sends toggle_sort with the field name. The search box sends its event with the text under the search key, debounced. The card and table toggle is remembered in the browser."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp row_action_text({"view", name}), do: gettext("Viewed %{name}.", name: name)

  defp row_action_text({"archive", name}),
    do: gettext("Archived %{name} (a demo: nothing changed).", name: name)

  attr(:people, :list, required: true)
  attr(:selected, :any, required: true)
  attr(:bulk_result, :any, default: nil)

  defp bulk_select_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Bulk selection")}
      description={
        gettext(
          "Two ways to select rows. Client-owned: the selection lives in the browser and the server hears about it only when an action fires. Server-owned: every checkbox is an event and the server holds the set."
        )
      }
    >
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div>
          <p class="text-xs text-base-content/60 mb-2">
            {gettext(
              "Client-owned — bulk_select_scope with its header and row cells. Instant on any connection."
            )}
          </p>
          <.bulk_select_scope id="demo-bulk-scope" total_count={length(@people)}>
            <div class="flex flex-wrap items-center gap-2 bg-base-200 rounded-lg px-3 py-2 text-sm mb-2">
              <span>{gettext("Selected:")} <span data-bulk-count>0</span></span>
              <button
                type="button"
                class="btn btn-sm btn-warning ml-auto"
                data-bulk-action="bulk_archive"
                data-bulk-show="has-selection"
                style="display: none;"
              >
                <.icon name="hero-archive-box" class="w-4 h-4" /> {gettext("Archive")}
              </button>
              <button
                type="button"
                class="btn btn-sm btn-ghost"
                data-bulk-clear="true"
                data-bulk-show="has-selection"
                style="display: none;"
              >
                {gettext("Clear")}
              </button>
            </div>
            <.table_default id="demo-bulk-client-table" size="sm">
              <.table_default_header>
                <.table_default_row>
                  <.bulk_select_header_cell
                    id="demo-bulk-select-all"
                    aria_label={gettext("Select all people")}
                  />
                  <.table_default_header_cell>{gettext("Name")}</.table_default_header_cell>
                </.table_default_row>
              </.table_default_header>
              <.table_default_body>
                <.table_default_row :for={person <- @people}>
                  <.bulk_select_cell value={person.id} />
                  <.table_default_cell>{person.name}</.table_default_cell>
                </.table_default_row>
              </.table_default_body>
            </.table_default>
          </.bulk_select_scope>
        </div>

        <div>
          <p class="text-xs text-base-content/60 mb-2">
            {gettext(
              "Server-owned — bulk_actions_bar over a set the LiveView keeps. Use it when the page must know the selection as it changes."
            )}
          </p>
          <.bulk_actions_bar count={MapSet.size(@selected)} clear_event="deselect_all">
            <button
              type="button"
              phx-click="bulk_action"
              phx-value-action="archive"
              phx-disable-with={gettext("Archiving…")}
              class="btn btn-warning btn-sm"
            >
              <.icon name="hero-archive-box" class="w-4 h-4" /> {gettext("Archive")}
            </button>
          </.bulk_actions_bar>
          <.table_default id="demo-bulk-server-table" size="sm">
            <.table_default_header>
              <.table_default_row>
                <.table_default_header_cell class="w-8" />
                <.table_default_header_cell>{gettext("Name")}</.table_default_header_cell>
              </.table_default_row>
            </.table_default_header>
            <.table_default_body>
              <.table_default_row :for={person <- @people}>
                <.table_default_cell class="w-8">
                  <input
                    type="checkbox"
                    id={"demo-select-#{person.id}"}
                    class="checkbox checkbox-sm"
                    checked={MapSet.member?(@selected, person.id)}
                    phx-click="toggle_select"
                    phx-value-id={person.id}
                    aria-label={gettext("Select %{name}", name: person.name)}
                  />
                </.table_default_cell>
                <.table_default_cell>{person.name}</.table_default_cell>
              </.table_default_row>
            </.table_default_body>
          </.table_default>
        </div>
      </div>
      <p :if={@bulk_result} class="text-sm mt-3" id="demo-bulk-result">
        {bulk_result_text(@bulk_result)}
      </p>
      <:snippet>
        <code>{~s|<.bulk_select_scope id="items-bulk" total_count={length(@items)}>|}</code>
        <code>{~s|  <button data-bulk-action="bulk_archive" data-bulk-show="has-selection">Archive</button>|}</code>
        <code>{~s|  <.table_default id="items">|}</code>
        <code>{~s|    ... <.bulk_select_header_cell id="items-select-all" /> ...|}</code>
        <code>{~s|    ... <.bulk_select_cell value={item.uuid} /> ...|}</code>
        <code>{~s|  </.table_default>|}</code>
        <code>{~s|</.bulk_select_scope>|}</code>
        <code>{~s|def handle_event("bulk_archive", %{"uuids" => uuids}, socket)|}</code>
        <code>{~s|<.bulk_actions_bar count={MapSet.size(@selected)} clear_event="deselect_all">|}</code>
        <code>{~s|  <button phx-click="bulk_action" phx-value-action="archive" class="btn btn-sm">Archive</button>|}</code>
        <code>{~s|</.bulk_actions_bar>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "The ids a bulk action receives come from the browser: load the records they name through your own scoped query before acting on them. Core also ships bulk_actions_toolbar, a ready-made bar for the client-owned scope with Reorder, Delete and Clear."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp bulk_result_text({:client, count}),
    do:
      ngettext(
        "The server received %{count} selected id from the browser.",
        "The server received %{count} selected ids from the browser.",
        count
      )

  defp bulk_result_text({:server, count}),
    do:
      ngettext(
        "Archived %{count} row from the server-held selection (a demo: nothing changed).",
        "Archived %{count} rows from the server-held selection (a demo: nothing changed).",
        count
      )

  attr(:picked, :list, required: true)

  defp search_picker_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Search picker")}
      description={
        gettext(
          "A typeahead for search-and-pick fields. The dropdown is drawn in the browser; the server only answers the search, here from the five sample people."
        )
      }
    >
      <div class="max-w-md flex flex-col gap-2">
        <div class="flex flex-wrap gap-1 min-h-6" id="demo-picked">
          <span :for={person <- @picked} class="badge badge-primary gap-1">
            {person.name}
            <button
              type="button"
              phx-click="picker_remove"
              phx-value-id={person.id}
              aria-label={gettext("Remove %{name}", name: person.name)}
            >
              <.icon name="hero-x-mark-mini" class="w-3 h-3" />
            </button>
          </span>
        </div>
        <.search_picker
          id="demo-picker"
          dropdown_id="demo-picker-dropdown"
          search_on_focus
          placeholder={gettext("Type a name…")}
          searching_label={gettext("Searching…")}
          no_matches_label={gettext("No matches")}
        />
      </div>
      <:snippet>
        <code>{~s|<.search_picker id="party-search" dropdown_id="party-dropdown" placeholder="Type a name…" />|}</code>
        <code>{~s|def handle_event("picker_search", %{"q" => q}, socket) do|}</code>
        <code>{~s|  rows = for r <- search(q), do: %{kind: "person", uuid: r.uuid, label: r.name}|}</code>
        <code>{~s|  {:noreply, push_event(socket, "picker_results", %{q: q, results: rows, has_more: false})}|}</code>
        <code>{~s|end|}</code>
        <code>{~s|def handle_event("picker_pick", %{"uuid" => uuid}, socket) do|}</code>
        <code>{~s|  {:noreply, socket \|> stage(uuid) \|> push_event("picker_staged", %{})}|}</code>
        <code>{~s|end|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "The chips are yours to render. Two pickers in one view need distinct event names, or each receives the other's results."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp pagination_component_section(assigns) do
    assigns = assign(assigns, :self_path, Paths.components())

    ~H"""
    <.showcase_section
      title={gettext("Pagination — core pagination")}
      description={
        gettext(
          "The wrapped counterpart to the hand-rolled join buttons above. It builds the page URLs from base_path and params, preserving your query string. The links below patch back to this page."
        )
      }
    >
      <.pagination current_page={2} total_pages={5} base_path={@self_path} params={%{"demo" => "1"}} />

      <p class="text-xs text-base-content/60 mt-2">
        {gettext(
          "Load-more lists (streams, infinite scroll) use load_more instead — see the Events page."
        )}
      </p>
      <:snippet>
        <code>{~s|<.pagination current_page={@page} total_pages={@total_pages}|}</code>
        <code>{~s|  base_path={Paths.items()} params={%{"search" => @search}} />|}</code>
        <code>{~s|<.load_more id="items" loaded={@loaded} total={@total} infinite />|}</code>
        <p class="text-xs text-base-content/50">
          {gettext("pagination renders patch links, so the page needs a handle_params callback.")}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp empty_state_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Empty state — core empty_state")}
      description={
        gettext(
          "The wrapped counterpart to the hand-rolled empty panel above. Three variants share one shape: compact, card, and featured."
        )
      }
    >
      <div class="flex flex-col gap-4">
        <div>
          <p class="text-xs text-base-content/60 mb-1">
            {gettext("compact — nothing matches a filter, inside an existing section:")}
          </p>
          <.empty_state icon="hero-funnel" title={gettext("No items match this filter.")} class="py-8" />
        </div>

        <div id="demo-empty-card">
          <p class="text-xs text-base-content/60 mb-1">
            {gettext("card — stands alone in the page body, with a call to action:")}
          </p>
          <.empty_state
            variant="card"
            icon="hero-inbox"
            title={gettext("Nothing here yet")}
            description={gettext("Items you create will show up in this list.")}
          >
            <:cta>
              <.button size="sm" phx-click="noop">
                <.icon name="hero-plus" class="w-4 h-4" /> {gettext("Create")}
              </.button>
            </:cta>
          </.empty_state>
        </div>

        <div id="demo-empty-featured">
          <p class="text-xs text-base-content/60 mb-1">
            {gettext("featured — the first-run state of a whole page:")}
          </p>
          <.empty_state
            variant="featured"
            icon="hero-sparkles"
            title={gettext("No items yet")}
            description={gettext("Create your first item to see it appear here.")}
          >
            <:cta>
              <.button phx-click="noop">
                <.icon name="hero-plus" class="w-5 h-5" /> {gettext("Create first item")}
              </.button>
            </:cta>
          </.empty_state>
        </div>
      </div>
      <:snippet>
        <code>{~s|<.empty_state icon="hero-funnel" title="No items match this filter." />|}</code>
        <code>{~s|<.empty_state variant="featured" icon="hero-sparkles" title="..." description="...">|}</code>
        <code>{~s|  <:cta><.button navigate={Paths.new_item()}>Create first item</.button></:cta>|}</code>
        <code>{~s|</.empty_state>|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:items, :list, required: true)

  defp draggable_list_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Draggable list")}
      description={gettext("A reorderable list. Dropping an item sends an event with the new order.")}
    >
      <.draggable_list
        id="demo-draggable"
        items={@items}
        on_reorder="reorder_items"
        layout={:list}
        cols={1}
      >
        <:item :let={item}>
          <div class="flex items-center gap-2 p-3 bg-base-100 rounded border border-base-300 cursor-move">
            <.icon name="hero-bars-3" class="w-4 h-4 text-base-content/40" />
            <span>{item.label}</span>
          </div>
        </:item>
      </.draggable_list>
      <:snippet>
        <code>{~s|<.draggable_list id="..." items={@items} on_reorder="reorder" layout={:list} cols={1}>|}</code>
        <code>{~s|  <:item :let={item}>...</:item>|}</code>
        <code>{~s|</.draggable_list>|}</code>
        <code>{~s|def handle_event("reorder", %{"ordered_ids" => ids}, socket)|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "Accept a reorder only when the ids are exactly a permutation of the ones you rendered. The drag behaviour comes from a core hook."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp context_components_section(assigns) do
    assigns =
      assign(assigns, :components, [
        {"<.theme_controller />", gettext("The daisyUI theme dropdown of the admin header.")},
        {"<.user_avatar />, <.primary_role />",
         gettext("User helpers. They need a user with preloaded roles.")},
        {"<.integration_picker />",
         gettext("Picks a connected integration. Needs integrations to choose from.")},
        {"<.file_upload />",
         gettext("LiveView file upload. Needs allow_upload configured in mount.")},
        {"<.markdown />",
         gettext(
           "Renders Markdown with MDEx and sanitises the result — see the dashboard widget's note."
         )},
        {"MarkdownEditor",
         gettext("A Markdown editor. A LiveComponent: render it with live_component and an id.")},
        {"<.event_timeline_item />", gettext("One entry of an email event timeline.")},
        {"<.oauth_provider_* />, <.aws_region_select />, <.aws_credentials_verify />",
         gettext("Provider credential forms used by core's own settings pages.")},
        {"<.module_card />", gettext("The card on the admin Modules page.")}
      ])

    ~H"""
    <.showcase_section
      title={gettext("Components not shown here")}
      description={
        gettext(
          "These need runtime context a generic template cannot supply — a user, an upload, a configured integration. They are in core and ready to use where that context exists."
        )
      }
    >
      <dl class="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-3 text-sm">
        <div :for={{name, description} <- @components}>
          <dt class="font-semibold">
            <code class="text-xs bg-base-200 px-1 rounded">{name}</code>
          </dt>
          <dd class="text-xs text-base-content/60">{description}</dd>
        </div>
      </dl>
    </.showcase_section>
    """
  end

  defp footer_link(assigns) do
    ~H"""
    <div class="text-xs text-base-content/50 text-center pt-4 border-t">
      {gettext(
        "Every core component lives in phoenix_kit's lib/phoenix_kit_web/components/core directory. Each one declares its attributes and slots — read them for the options this page does not show."
      )}
    </div>
    """
  end

  attr(:label, :string, required: true)

  defp section_divider(assigns) do
    ~H"""
    <div class="divider mt-4">
      <span class="text-xs font-bold tracking-wider">{@label}</span>
    </div>
    """
  end

  # ── Internal showcase wrapper ────────────────────────────────────

  attr(:title, :string, required: true)
  attr(:description, :string, default: nil)
  slot(:inner_block, required: true)
  slot(:snippet)

  defp showcase_section(assigns) do
    ~H"""
    <section class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h3 class="card-title text-lg">{@title}</h3>
        <p :if={@description} class="text-sm text-base-content/60">{@description}</p>
        <div class="mt-3">
          {render_slot(@inner_block)}
        </div>
        <details :if={@snippet != []} class="mt-4" phx-mounted={Phoenix.LiveView.JS.ignore_attributes(["open"])}>
          <summary class="text-xs text-base-content/60 cursor-pointer">{gettext("Show snippet")}</summary>
          <div class="bg-base-200 p-3 rounded mt-2 text-xs flex flex-col gap-1 font-mono overflow-x-auto">
            {render_slot(@snippet)}
          </div>
        </details>
      </div>
    </section>
    """
  end
end

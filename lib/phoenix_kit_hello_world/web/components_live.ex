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

  - **Typography & feedback** — badges, `status_badge`, `status_dot`, alerts,
    stat cards, `hero_stat_card`, number formatter
  - **Buttons & icons** — raw variants, `button`, `pk_link_button`
  - **Navigation** — `nav_tabs` (variants, `:trailing`), collapse and
    `accordion`, `pk_link`, `date_nav`
  - **Forms** — input, select, textarea, checkbox, `simple_form`,
    `form_section` + `form_actions`, `section_header`, `decimal_input`,
    `save_button`, `search_picker`
  - **Tables & lists** — raw table, `table_default` with `sort_header_cell`,
    `search_toolbar`, `sort_selector`, `table_row_menu` and `toolbar_primary`;
    `tree_name_cell` and `row_link`; bulk selection with `bulk_actions_toolbar`;
    `sortable_tbody`/`sortable_row` with drag handles; `column_settings_modal`
    over `PhoenixKitWeb.TableColumns`; draggable list
  - **Charts** — `line_chart`, `bar_chart`, `sparkline`, `chart_lanes`
  - **Modals & overlays** — `modal` (drawer placement, unsaved-input guard),
    `confirm_modal`, `alert_modal`, `popover_panel`
  - **Pagination** — raw join buttons, `pagination` with `pagination_info`
    and `page_size_selector`, `load_more`
  - **Time & files** — time_ago, age_badge, file_size, file_mtime, page_status_badge
  - **Empty / loading states** — raw markup, `empty_state` (with `:cta`)
  - **Layout** — when you need `admin_page_header` (this page does not: the
    admin layout draws the header)

  Components that need runtime context a template cannot supply (a user, an
  upload, stored media, a record to translate) are listed in the last section
  with what each one needs.

  ## Import pattern

  `use PhoenixKitWeb, :live_view` imports almost every core component used on
  this page. The few core keeps out of that list are imported explicitly at the
  top — `date_nav`, `hero_stat_card`, `row_link` and `save_button`. A LiveView
  that does `use Phoenix.LiveView` directly imports everything it uses:

      import PhoenixKitWeb.Components.Core.Icon, only: [icon: 1]
      import PhoenixKitWeb.Components.Core.Modal, only: [modal: 1, confirm_modal: 1]

  Every component and attribute on this page exists in the `phoenix_kit`
  release this module's `mix.exs` floor names (2.63.0). Newer core releases may
  add more — read the component's own `attr` declarations — and raising the
  floor is part of the change that starts using one.

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

  # Not in `use PhoenixKitWeb, :live_view`'s import list — core imports these
  # only where a page asks for them (see each module's own docs).
  import PhoenixKitWeb.Components.Core.DateNav, only: [date_nav: 1]
  import PhoenixKitWeb.Components.Core.HeroStatCard, only: [hero_stat_card: 1]
  import PhoenixKitWeb.Components.Core.RowLink, only: [row_link: 1]
  import PhoenixKitWeb.Components.Core.SaveButton, only: [save_button: 1]

  alias PhoenixKit.Utils.Number
  alias PhoenixKitHelloWorld.Paths
  alias PhoenixKitWeb.Actor
  alias PhoenixKitWeb.Components.Core.DateNav
  alias PhoenixKitWeb.TableColumns

  @valid_demo_tabs ~w(overview activity settings)
  @alert_types %{
    "info" => :info,
    "success" => :success,
    "warning" => :warning,
    "error" => :error
  }
  @page_sizes [10, 25, 50, 100]
  @column_events ~w(add_column remove_column reorder_columns reset_columns)

  # Sample rows for the table, bulk-select and picker sections. Plain maps —
  # these components take whatever shape you hand them. Names, roles and
  # statuses are data, not copy, so they are not translated.
  @demo_people [
    %{id: "alice", name: "Alice", role: "admin", status: "active", joined: "2024-03-12"},
    %{id: "bob", name: "Bob", role: "user", status: "active", joined: "2024-07-01"},
    %{id: "carol", name: "Carol", role: "user", status: "inactive", joined: "2025-01-20"},
    %{id: "dave", name: "Dave", role: "user", status: "pending", joined: "2025-09-05"},
    %{id: "erin", name: "Erin", role: "admin", status: "suspended", joined: "2026-02-14"}
  ]

  @people_by_id Map.new(@demo_people, &{&1.id, &1})

  # The sort fields a client may ask for. A hardcoded map, never
  # `String.to_existing_atom/1` on the parameter.
  @sortable %{"name" => :name, "role" => :role, "status" => :status}

  @sort_dirs %{"asc" => :asc, "desc" => :desc}

  @row_actions ~w(view archive)

  # A small folder tree for `tree_name_cell`: `parent` nil is a root. Children
  # come after their parent in the list; `tree_rows/3` walks it into the
  # `{node, depth}` rows the table draws.
  @demo_tree [
    %{id: "docs", name: "Documents", parent: nil, folder?: true},
    %{id: "docs-specs", name: "Specs", parent: "docs", folder?: true},
    %{id: "docs-specs-api", name: "api.md", parent: "docs-specs", folder?: false},
    %{id: "docs-readme", name: "README.md", parent: "docs", folder?: false},
    %{id: "photos", name: "Photos", parent: nil, folder?: true},
    %{id: "photos-trip", name: "trip.jpg", parent: "photos", folder?: false},
    %{id: "notes", name: "notes.txt", parent: nil, folder?: false}
  ]

  @chart_values [12, 18, 15, 24, 21, 30, 27]

  # The nodes that have children — the only ones a toggle may name.
  @expandable_ids @demo_tree |> Enum.map(& &1.parent) |> Enum.reject(&is_nil/1) |> Enum.uniq()

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
       picked: [],
       alert: nil,
       tree_expanded: MapSet.new(["docs"]),
       manual_people: @demo_people,
       manual_result: nil,
       show_columns: false,
       per_page: 10,
       measure_form: measure_form(%{"qty" => "2,5", "weight" => "1.25"}),
       measure: measure_parse(%{"qty" => "2,5", "weight" => "1.25"}),
       measure_dirty: false,
       measure_saved: false,
       today: Date.utc_today(),
       date: Date.utc_today()
     )
     |> assign(:columns, TableColumns.load(Actor.uuid(socket), columns_spec()))
     |> assign_table_rows()
     |> assign_tree_rows()}
  end

  # The `<.pagination>` showcase renders real `<.link patch>` targets pointing
  # back at this page, so clicking one round-trips through `handle_params/3`.
  # The demo pager is display-only; the one URL parameter that matters is the
  # day `<.date_nav>` keeps in `?date=`, parsed by core and clamped to today.
  @impl true
  def handle_params(params, _uri, socket) do
    today = socket.assigns.today

    {:noreply,
     assign(socket, :date, DateNav.parse_param(params["date"], today: today, max: today))}
  end

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

  def handle_event("validate_profile", %{"profile" => %{"display_name" => name}}, socket)
      when is_binary(name) do
    {:noreply, assign(socket, :profile_form, profile_form(name))}
  end

  def handle_event("save_profile", %{"profile" => %{"display_name" => name}}, socket)
      when is_binary(name) do
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

  # ── Alert modal ──────────────────────────────────────────────────

  def handle_event("open_alert", %{"type" => type}, socket) when is_map_key(@alert_types, type) do
    {:noreply, assign(socket, :alert, Map.fetch!(@alert_types, type))}
  end

  def handle_event("close_alert", _, socket), do: {:noreply, assign(socket, :alert, nil)}

  # ── Table: sort selector, page size ──────────────────────────────

  # `<.sort_selector>` sends only the control that changed; the other half
  # comes from the assigns, never from the DOM.
  def handle_event("sort_form", params, socket) do
    %{by: by, dir: dir} = socket.assigns.table_sort
    by_param = params["sort_by"] || Atom.to_string(by)
    dir_param = params["sort_dir"] || Atom.to_string(dir)

    with %{^by_param => field} <- @sortable,
         %{^dir_param => direction} <- @sort_dirs do
      {:noreply,
       socket |> assign(:table_sort, %{by: field, dir: direction}) |> assign_table_rows()}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("change_per_page", %{"per_page" => value}, socket) when is_binary(value) do
    case Integer.parse(value) do
      {size, ""} when size in @page_sizes -> {:noreply, assign(socket, :per_page, size)}
      _ -> {:noreply, socket}
    end
  end

  # ── Table: tree rows ─────────────────────────────────────────────

  def handle_event("toggle_node", %{"uuid" => id}, socket) when id in @expandable_ids do
    expanded = socket.assigns.tree_expanded

    expanded =
      if MapSet.member?(expanded, id),
        do: MapSet.delete(expanded, id),
        else: MapSet.put(expanded, id)

    {:noreply, socket |> assign(:tree_expanded, expanded) |> assign_tree_rows()}
  end

  # ── Table: manual order, bulk toolbar, columns ───────────────────

  def handle_event("reorder_people", %{"ordered_ids" => ids}, socket) when is_list(ids) do
    people = Map.new(socket.assigns.manual_people, &{&1.id, &1})

    # Same rule as the draggable list: exactly a permutation of the rows shown.
    if Enum.sort(ids) == Enum.sort(Map.keys(people)) do
      {:noreply, assign(socket, :manual_people, Enum.map(ids, &Map.fetch!(people, &1)))}
    else
      {:noreply, socket}
    end
  end

  # Both toolbar buttons send the selected ids; the browser's list is input,
  # so only ids the server knows are counted.
  def handle_event("open_reorder", %{"uuids" => ids}, socket) when is_list(ids),
    do: {:noreply, assign(socket, :manual_result, {:reorder, known_count(ids)})}

  def handle_event("bulk_delete", %{"uuids" => ids}, socket) when is_list(ids),
    do: {:noreply, assign(socket, :manual_result, {:delete, known_count(ids)})}

  def handle_event("show_column_modal", _, socket),
    do: {:noreply, assign(socket, :show_columns, true)}

  def handle_event("hide_column_modal", _, socket),
    do: {:noreply, assign(socket, :show_columns, false)}

  # The modal's four editing events are answered by core: it validates the
  # ids against the spec and saves the choice for the signed-in user.
  def handle_event(event, params, socket) when event in @column_events do
    {:noreply, TableColumns.handle_event(event, params, socket, columns_spec(), :columns)}
  end

  # ── Form extras ──────────────────────────────────────────────────

  # The form's own two fields, as text: a map or a list in their place is a
  # crafted push and falls through to the catch-all.
  def handle_event(
        "validate_measure",
        %{"measure" => %{"qty" => qty, "weight" => weight}},
        socket
      )
      when is_binary(qty) and is_binary(weight) do
    params = %{"qty" => qty, "weight" => weight}

    {:noreply,
     assign(socket,
       measure_form: measure_form(params),
       measure: measure_parse(params),
       measure_dirty: true,
       measure_saved: false
     )}
  end

  # Saving needs numbers the server could read: text it refused stays unsaved.
  def handle_event("save_measure", %{"measure" => %{"qty" => qty, "weight" => weight}}, socket)
      when is_binary(qty) and is_binary(weight) do
    params = %{"qty" => qty, "weight" => weight}
    measure = measure_parse(params)
    valid? = match?({:ok, _}, measure.qty) and match?({:ok, _}, measure.weight)

    {:noreply,
     assign(socket,
       measure_form: measure_form(params),
       measure: measure,
       measure_dirty: not valid?,
       measure_saved: valid?
     )}
  end

  # ── Date navigation ──────────────────────────────────────────────

  # The date picker only reaches the server inside a form, so it sends an
  # event; the page answers with a patch and the URL stays the one source.
  def handle_event("date_nav_pick", %{"date" => value}, socket) do
    date = DateNav.parse_param(value, today: socket.assigns.today, max: socket.assigns.today)
    {:noreply, push_patch(socket, to: "#{Paths.components()}?date=#{date}")}
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

  defp known_count(ids),
    do: ids |> Enum.filter(&is_map_key(@people_by_id, &1)) |> Enum.uniq() |> length()

  defp blank_name?(profile_form), do: String.trim(profile_form[:display_name].value || "") == ""

  defp measure_form(params), do: to_form(params, as: :measure)

  # What the server makes of the typed text: `parse_decimal/2` takes a comma
  # or a dot and refuses anything else.
  defp measure_parse(params) do
    %{
      qty: Number.parse_decimal(params["qty"], min: 0),
      weight: Number.parse_decimal(params["weight"], min: 0)
    }
  end

  # The optional columns of the manual-order table; Name and the row handle
  # are always on, so they are not in the catalog.
  defp columns_spec do
    %{
      key: "hello_world.components_demo_people",
      columns: [
        %{id: "role", label: fn -> gettext("Role") end},
        %{id: "status", label: fn -> gettext("Status") end},
        %{id: "joined", label: fn -> gettext("Joined") end}
      ],
      defaults: ["role", "status"]
    }
  end

  # The tree walked into `{node, depth}` rows in display order, the children
  # of a collapsed node skipped.
  defp assign_tree_rows(socket) do
    assign(socket, :tree_rows, tree_rows(socket.assigns.tree_expanded))
  end

  defp tree_rows(expanded, parent \\ nil, depth \\ 0) do
    for node <- @demo_tree, node.parent == parent do
      [{node, depth}] ++
        if MapSet.member?(expanded, node.id),
          do: tree_rows(expanded, node.id, depth + 1),
          else: []
    end
    |> Enum.concat()
  end

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
      <.status_dot_section />
      <.collapsible_section />
      <.nav_tabs_section active_tab={@active_tab} />
      <.stat_card_section />
      <.hero_stat_card_section />
      <.number_formatter_section />
      <.time_display_section />
      <.file_display_section />
      <.language_switcher_section current_locale={assigns[:current_locale]} />
      <.pk_links_section />
      <.form_helpers_section demo_form={@demo_form} />
      <.form_section_section profile_form={@profile_form} profile_saved={@profile_saved} />
      <.form_extras_section
        form={@measure_form}
        measure={@measure}
        dirty={@measure_dirty}
        saved={@measure_saved}
      />
      <.modals_section
        show_modal={@show_modal}
        placement={@modal_placement}
        note_form={@note_form}
        note_dirty={@note_dirty}
        saved_note={@saved_note}
        show_confirm={@show_confirm}
        counter={@counter}
        alert={@alert}
      />
      <.popover_panel_section counter={@counter} />
      <.table_default_section
        rows={@table_rows}
        sort={@table_sort}
        search={@table_search}
        last_row_action={@last_row_action}
      />
      <.tree_table_section rows={@tree_rows} expanded={@tree_expanded} />
      <.manual_table_section
        people={@manual_people}
        columns={@columns}
        show_columns={@show_columns}
        result={@manual_result}
      />
      <.bulk_select_section people={@demo_people} selected={@selected} bulk_result={@bulk_result} />
      <.search_picker_section picked={@picked} />
      <.pagination_component_section per_page={@per_page} />
      <.empty_state_section />
      <.draggable_list_section items={@draggable_items} />
      <.charts_section />
      <.date_nav_section date={@date} today={@today} />
      <.admin_page_header_section />

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
      <%!-- The typed badges of badge.ex take what their domain has, not a
           status string: a role map, two user fields, a code map, a category
           string, an enabled boolean. --%>
      <p class="text-xs text-base-content/60 mt-4 mb-2">
        {gettext("Typed badges — each takes the data of its own domain:")}
      </p>
      <div class="flex flex-wrap items-center gap-2" id="demo-typed-badges">
        <.role_badge role={%{name: "Owner", is_system_role: true}} size={:sm} />
        <.role_badge role={%{name: "Editor", is_system_role: false}} size={:sm} />
        <.user_status_badge is_active={true} confirmed_at={~U[2026-01-01 00:00:00Z]} size={:sm} />
        <.user_status_badge is_active={true} confirmed_at={nil} size={:sm} />
        <.user_status_badge is_active={false} size={:sm} />
        <.code_status_badge
          code={%{number_of_uses: 1, max_uses: 5, expiration_date: nil}}
          size={:sm}
        />
        <.code_status_badge
          code={%{number_of_uses: 5, max_uses: 5, expiration_date: nil}}
          size={:sm}
        />
        <.category_badge category="system" />
        <.category_badge category="marketing" />
        <.category_badge category="transactional" />
        <.enabled_badge enabled={true} />
        <.enabled_badge enabled={false} />
      </div>
      <:snippet>
        <code>{~s|<.status_badge status={item.status} />|}</code>
        <code>{~s|<.status_badge status="in_progress" size={:xs} />|}</code>
        <code>{~s|<.role_badge role={user.role} size={:sm} />|}</code>
        <code>{~s|<.user_status_badge is_active={user.is_active} confirmed_at={user.confirmed_at} />|}</code>
        <code>{~s|<.code_status_badge code={referral_code} />|}</code>
        <code>{~s|<.category_badge category="marketing" />|}</code>
        <code>{~s|<.enabled_badge enabled={endpoint.enabled} />|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "An unknown status renders as a neutral badge rather than raising. The label is the status string with underscores as spaces. The typed badges take what their domain has: a role map with name and is_system_role, the two user fields is_active and confirmed_at, a referral-code map with number_of_uses, max_uses and expiration_date, a category string, an enabled boolean."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp status_dot_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Status dot")}
      description={
        gettext(
          "A coloured dot with an optional label, for online or offline, connected, syncing — the little circle that keeps being hand-rolled."
        )
      }
    >
      <div class="flex flex-wrap items-center gap-x-6 gap-y-2" id="demo-status-dots">
        <.status_dot variant={:success} label={gettext("online")} />
        <.status_dot variant={:error} label={gettext("offline")} />
        <.status_dot variant={:warning} label={gettext("degraded")} />
        <.status_dot variant={:info} label={gettext("syncing")} pulse />
        <.status_dot variant={:neutral} label={gettext("idle")} size={:sm} />
        <.status_dot up={true} label={gettext("up is true")} />
      </div>
      <:snippet>
        <code>{~s|<.status_dot variant={:success} label="online" />|}</code>
        <code>{~s|<.status_dot variant={:info} label="syncing" pulse />|}</code>
        <code>{~s|<.status_dot up={@device.online} label={if @device.online, do: "online", else: "offline"} />|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "The default announced state is generic (online, offline); for a payment or a job pass state_label so a screen reader hears what it is."
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

  defp hero_stat_card_section(assigns) do
    assigns =
      assign(assigns,
        people_count: length(@demo_people),
        admin_count: Enum.count(@demo_people, &(&1.role == "admin"))
      )

    ~H"""
    <.showcase_section
      title={gettext("Hero stat card")}
      description={gettext("A large card for the one or two numbers a dashboard leads with.")}
    >
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4" id="demo-hero-stats">
        <.hero_stat_card
          value={@people_count}
          title={gettext("People")}
          subtitle={gettext("In the sample table above")}
        >
          <:icon><.icon name="hero-users" class="w-6 h-6" /></:icon>
        </.hero_stat_card>
        <.hero_stat_card
          value={@admin_count}
          title={gettext("Administrators")}
          subtitle={gettext("A link to the report behind the number")}
          navigate={Paths.components()}
        >
          <:icon><.icon name="hero-shield-check" class="w-6 h-6" /></:icon>
        </.hero_stat_card>
      </div>
      <:snippet>
        <code>{~s|import PhoenixKitWeb.Components.Core.HeroStatCard, only: [hero_stat_card: 1]|}</code>
        <code>{~s|<.hero_stat_card value={@count} title="People" subtitle="Registered" navigate={Paths.people()}>|}</code>
        <code>{~s|  <:icon><.icon name="hero-users" class="w-6 h-6" /></:icon>|}</code>
        <code>{~s|</.hero_stat_card>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext("With navigate the whole card is a link; pass a path already built through Paths.")}
        </p>
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
          submit_label={
            if blank_name?(@profile_form),
              do: gettext("Enter a name to save"),
              else: gettext("Save profile")
          }
          submit_disabled={blank_name?(@profile_form)}
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
        <code>{~s|  <.form_actions cancel_to={Paths.index()} submit_label={if @valid?, do: "Save", else: "Enter a name to save"}|}</code>
        <code>{~s|    submit_disabled={not @valid?} submit_icon="hero-check" />|}</code>
        <code>{~s|</.form>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "Cancel is a link with cancel_to, an event with cancel_click (add cancel_target inside a LiveComponent), or your own markup in the cancel slot — one of the three. submit_disabled greys the submit button; say why in submit_label, as the empty name does here."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:form, :any, required: true)
  attr(:measure, :map, required: true)
  attr(:dirty, :boolean, required: true)
  attr(:saved, :boolean, required: true)

  defp form_extras_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Form extras — section_header, decimal_input, save_button")}
      description={
        gettext(
          "A quieter section heading for fields inside one card, a number field that accepts a comma and a dot, and a Save button that says whether there is anything to save."
        )
      }
    >
      <.form
        for={@form}
        id="demo-measure-form"
        phx-change="validate_measure"
        phx-submit="save_measure"
        phx-auto-recover="recover"
        class="flex flex-col gap-3 max-w-md"
      >
        <.section_header icon="hero-scale" title={gettext("Measurements")}>
          <:actions>
            <span class="text-xs text-base-content/50">{gettext("comma or dot")}</span>
          </:actions>
        </.section_header>
        <.decimal_input field={@form[:qty]} label={gettext("Quantity")} />
        <.decimal_input field={@form[:weight]} label={gettext("Weight")} unit="kg" />
        <.save_button dirty={@dirty} saved={@saved} />
      </.form>
      <ul class="text-sm mt-3 flex flex-col gap-1" id="demo-measure-parsed">
        <li>{gettext("Quantity:")} {measure_text(@measure.qty)}</li>
        <li>{gettext("Weight:")} {measure_text(@measure.weight)}</li>
      </ul>
      <div class="mt-4">
        <p class="text-xs text-base-content/60 mb-1">
          {gettext("bare — the control alone, as an item of your own group:")}
        </p>
        <div class="join">
          <.decimal_input
            bare
            id="demo-bare-qty"
            name="bare_qty"
            value="3"
            label={gettext("Pieces")}
            class="join-item w-24 text-center"
          />
          <span class="btn join-item pointer-events-none">{gettext("pcs")}</span>
        </div>
      </div>
      <:snippet>
        <code>{~s|<.section_header icon="hero-scale" title="Measurements"><:actions>...</:actions></.section_header>|}</code>
        <code>{~s|<.decimal_input field={@form[:qty]} label="Quantity" />|}</code>
        <code>{~s|<.decimal_input field={@form[:weight]} label="Weight" unit="kg" />|}</code>
        <code>{~s|<.decimal_input bare name="qty" value={@qty} class="join-item w-20" />|}</code>
        <code>{~s|import PhoenixKitWeb.Components.Core.SaveButton, only: [save_button: 1]|}</code>
        <code>{~s|<.save_button dirty={@dirty} saved={@saved} />|}</code>
        <code>{~s|case PhoenixKit.Utils.Number.parse_decimal(params["qty"], min: 0) do {:ok, qty} -> ...; {:error, reason} -> ... end|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "decimal_input renders a text field, so the server decides what the text means: parse_decimal takes a comma or a dot and refuses the rest. save_button only draws; the form keeps the dirty and saved flags, and needs phx-auto-recover so a reconnect does not mark it unsaved."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp measure_text({:ok, decimal}), do: Decimal.to_string(decimal, :normal)
  defp measure_text({:error, :empty}), do: gettext("empty")
  defp measure_text({:error, :below_min}), do: gettext("below the minimum")
  defp measure_text({:error, :above_max}), do: gettext("above the maximum")
  defp measure_text({:error, _reason}), do: gettext("not a number")

  attr(:show_modal, :boolean, required: true)
  attr(:placement, :atom, required: true)
  attr(:note_form, :any, required: true)
  attr(:note_dirty, :boolean, required: true)
  attr(:saved_note, :string, default: nil)
  attr(:show_confirm, :boolean, required: true)
  attr(:counter, :integer, required: true)
  attr(:alert, :atom, default: nil)

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
        <button
          :for={{type, label} <- [
                info: gettext("Info alert"),
                success: gettext("Success alert"),
                warning: gettext("Warning alert"),
                error: gettext("Error alert")
              ]}
          type="button"
          id={"demo-alert-#{type}"}
          phx-click="open_alert"
          phx-value-type={type}
          class="btn btn-outline btn-sm"
        >
          {label}
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

      <%!-- The acknowledge-only modal: one message, one OK button. --%>
      <.alert_modal
        show={@alert != nil}
        on_close="close_alert"
        type={@alert || :info}
        message={alert_message(@alert)}
      />

      <:snippet>
        <code>{~s|<.modal id="note-modal" show={@show} on_close="close_modal" placement={:end}|}</code>
        <code>{~s|  closeable={not @dirty} close_guard={:input}>|}</code>
        <code>{~s|  <:title>Leave a note</:title>|}</code>
        <code>{~s|  <.form for={@form} id="note-form" phx-change="validate" phx-submit="save">...</.form>|}</code>
        <code>{~s|  <:actions><button type="submit" form="note-form" class="btn btn-primary">Save</button></:actions>|}</code>
        <code>{~s|</.modal>|}</code>
        <code>{~s|<.confirm_modal show={@show} title="..." prompt="..." on_confirm="..." on_cancel="..." />|}</code>
        <code>{~s|<.alert_modal show={@alert != nil} on_close="close_alert" type={:warning} message="Quota almost used." />|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "The submit button lives in the actions slot, outside the form, and is tied to it by the form attribute. Never build a modal from a raw dialog element with the modal-open class: it is not in the top layer, so it has no focus trap and Esc does nothing."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp alert_message(:warning),
    do: gettext("This is a warning: the action is allowed, but check it first.")

  defp alert_message(:success), do: gettext("This is a success: the action went through.")
  defp alert_message(:error), do: gettext("This is an error: the action did not go through.")
  defp alert_message(_info_or_nil), do: gettext("This is a notice. Press OK to acknowledge it.")

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
        <:toolbar_primary>
          <.button size="sm" phx-click="noop">
            <.icon name="hero-plus" class="w-4 h-4" /> {gettext("New person")}
          </.button>
        </:toolbar_primary>
        <:sort_bar>
          <.sort_selector
            id="demo-sort-selector"
            sort_by={@sort.by}
            sort_dir={@sort.dir}
            options={[name: gettext("Name"), role: gettext("Role"), status: gettext("Status")]}
            label
          />
        </:sort_bar>
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
        <code>{~s|  <:toolbar_primary><.button size="sm" navigate={Paths.new_person()}>New person</.button></:toolbar_primary>|}</code>
        <code>{~s|  <:sort_bar><.sort_selector sort_by={@sort.by} sort_dir={@sort.dir} options={[name: "Name"]} /></:sort_bar>|}</code>
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
            "sort is a map with by and dir; a header click sends toggle_sort with the field name. The sort selector above the table sends sort_form with only the control that changed — read the other half from your assigns. The search box sends its event with the text under the search key, debounced. toolbar_primary holds the page's create button in the far-right corner. The card and table toggle is remembered in the browser."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp row_action_text({"view", name}), do: gettext("Viewed %{name}.", name: name)

  defp row_action_text({"archive", name}),
    do: gettext("Archived %{name} (a demo: nothing changed).", name: name)

  attr(:rows, :list, required: true)
  attr(:expanded, :any, required: true)

  defp tree_table_section(assigns) do
    assigns = assign(assigns, :people, @demo_people)

    ~H"""
    <.showcase_section
      title={gettext("Table — tree rows and clickable rows")}
      description={
        gettext(
          "Two cell-level pieces for a table_default. tree_name_cell turns the name cell into a collapsible tree row; row_link makes a whole row one real link."
        )
      }
    >
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div id="demo-tree">
          <p class="text-xs text-base-content/60 mb-2">
            {gettext("tree_name_cell — you walk the data into {node, depth} rows and keep the expanded set.")}
          </p>
          <.table_default id="demo-tree-table" size="sm">
            <.table_default_header>
              <.table_default_row>
                <.table_default_header_cell>{gettext("Name")}</.table_default_header_cell>
              </.table_default_row>
            </.table_default_header>
            <.table_default_body>
              <.table_default_row :for={{node, depth} <- @rows} id={"demo-tree-#{node.id}"}>
                <.tree_name_cell
                  depth={depth}
                  expandable={expandable?(node.id)}
                  expanded={MapSet.member?(@expanded, node.id)}
                  toggle_event="toggle_node"
                  value={node.id}
                  toggle_label={gettext("Expand or collapse %{name}", name: node.name)}
                  icon={if node.folder?, do: "hero-folder", else: "hero-document-text"}
                  icon_class={node.folder? && "w-4 h-4 text-warning shrink-0"}
                >
                  {node.name}
                </.tree_name_cell>
              </.table_default_row>
            </.table_default_body>
          </.table_default>
        </div>

        <div>
          <p class="text-xs text-base-content/60 mb-2">
            {gettext("row_link — click anywhere on a row. Its menu stays clickable above the link.")}
          </p>
          <.table_default id="demo-row-link-table" size="sm">
            <.table_default_header>
              <.table_default_row>
                <.table_default_header_cell>{gettext("Name")}</.table_default_header_cell>
                <.table_default_header_cell class="w-10" />
              </.table_default_row>
            </.table_default_header>
            <.table_default_body>
              <%!-- `relative transform-gpu` on the row: the link paints an overlay
                   across it, and Safari ignores `relative` on a <tr> without it. --%>
              <.table_default_row
                :for={person <- @people}
                id={"demo-linked-#{person.id}"}
                class="relative transform-gpu cursor-pointer hover:bg-base-200"
              >
                <.table_default_cell>
                  <.row_link
                    navigate={Paths.components()}
                    label={gettext("Open %{name}", name: person.name)}
                  />
                  {person.name}
                </.table_default_cell>
                <.table_default_cell class="relative z-10">
                  <.table_row_menu id={"demo-linked-menu-#{person.id}"} label={gettext("Actions")}>
                    <.table_row_menu_link
                      navigate={Paths.events()}
                      icon="hero-clock"
                      label={gettext("Open events")}
                    />
                  </.table_row_menu>
                </.table_default_cell>
              </.table_default_row>
            </.table_default_body>
          </.table_default>
        </div>
      </div>
      <:snippet>
        <code>{~s|<.tree_name_cell depth={depth} expandable={node.children != []} expanded={MapSet.member?(@expanded, node.uuid)}|}</code>
        <code>{~s|  toggle_event="toggle_node" value={node.uuid} icon="hero-folder">{node.name}</.tree_name_cell>|}</code>
        <code>{~s|def handle_event("toggle_node", %{"uuid" => uuid}, socket)  # only ids you rendered as expandable|}</code>
        <code>{~s|import PhoenixKitWeb.Components.Core.RowLink, only: [row_link: 1]|}</code>
        <code>{~s|<.table_default_row class="relative transform-gpu cursor-pointer">|}</code>
        <code>{~s|  <.table_default_cell><.row_link navigate={Paths.show(item)} label="Open item" />{item.name}</.table_default_cell>|}</code>
        <code>{~s|  <.table_default_cell class="relative z-10"><.table_row_menu ...>...</.table_row_menu></.table_default_cell>|}</code>
        <code>{~s|</.table_default_row>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "The tree walk and the expanded set are yours: skip the children of a collapsed node when you build the rows. row_link is not in the global import list; every control in the row that must stay clickable needs relative z-10."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp expandable?(id), do: id in @expandable_ids

  attr(:people, :list, required: true)
  attr(:columns, :list, required: true)
  attr(:show_columns, :boolean, required: true)
  attr(:result, :any, default: nil)

  defp manual_table_section(assigns) do
    assigns = assign(assigns, :spec, columns_spec())

    ~H"""
    <.showcase_section
      title={gettext("Table — manual order, columns and bulk toolbar")}
      description={
        gettext(
          "One table with the pieces a managed list needs: drag handles with sortable rows, a bulk selection toolbar with the page's primary action, and a column editor that remembers each user's choice."
        )
      }
    >
      <.bulk_select_scope id="demo-manual-scope" total_count={length(@people)}>
        <.bulk_actions_toolbar
          on_open_reorder="open_reorder"
          on_bulk_delete="bulk_delete"
          reorder_gate={:multi}
        >
          <:leading>
            <button type="button" phx-click="show_column_modal" class="btn btn-sm btn-ghost" id="demo-columns-open">
              <.icon name="hero-view-columns" class="w-4 h-4" /> {gettext("Columns")}
            </button>
          </:leading>
          <:primary>
            <.button size="sm" phx-click="noop">
              <.icon name="hero-plus" class="w-4 h-4" /> {gettext("New person")}
            </.button>
          </:primary>
        </.bulk_actions_toolbar>

        <.table_default id="demo-manual-table" size="sm">
          <.table_default_header>
            <.table_default_row>
              <.drag_handle_header_cell />
              <.bulk_select_header_cell
                id="demo-manual-select-all"
                aria_label={gettext("Select all people")}
              />
              <.table_default_header_cell>{gettext("Name")}</.table_default_header_cell>
              <.table_default_header_cell :for={id <- @columns}>
                {column_label(@spec, id)}
              </.table_default_header_cell>
            </.table_default_row>
          </.table_default_header>
          <.sortable_tbody id="demo-manual-body" event="reorder_people">
            <.sortable_row :for={person <- @people} item_id={person.id} id={"demo-manual-#{person.id}"}>
              <.drag_handle_cell />
              <.bulk_select_cell value={person.id} />
              <.table_default_cell>{person.name}</.table_default_cell>
              <.table_default_cell :for={id <- @columns}>
                <.status_badge :if={id == "status"} status={person.status} size={:xs} />
                <span :if={id == "role"} class="badge badge-ghost badge-xs">{person.role}</span>
                <span :if={id == "joined"} class="text-sm text-base-content/70">{person.joined}</span>
              </.table_default_cell>
            </.sortable_row>
          </.sortable_tbody>
        </.table_default>
      </.bulk_select_scope>

      <p class="text-xs text-base-content/60 mt-2" id="demo-manual-order">
        {gettext("Order:")} {Enum.map_join(@people, ", ", & &1.name)}
      </p>
      <p :if={@result} class="text-sm mt-1" id="demo-manual-result">{manual_result_text(@result)}</p>

      <.column_settings_modal
        show={@show_columns}
        columns={@spec.columns}
        selected={@columns}
      />
      <:snippet>
        <code>{~s|<.bulk_select_scope id="people-bulk" total_count={length(@people)}>|}</code>
        <code>{~s|  <.bulk_actions_toolbar on_open_reorder="open_reorder" on_bulk_delete="bulk_delete" reorder_gate={:multi}>|}</code>
        <code>{~s|    <:primary><.button size="sm" navigate={Paths.new_person()}>New person</.button></:primary>|}</code>
        <code>{~s|  </.bulk_actions_toolbar>|}</code>
        <code>{~s|  <.table_default id="people"> ... <.drag_handle_header_cell /> <.bulk_select_header_cell id="all" /> ...|}</code>
        <code>{~s|    <.sortable_tbody id="people-body" event="reorder_people">|}</code>
        <code>{~s|      <.sortable_row :for={p <- @people} item_id={p.uuid}><.drag_handle_cell /><.bulk_select_cell value={p.uuid} /> ...</.sortable_row>|}</code>
        <code>{~s|    </.sortable_tbody>|}</code>
        <code>{~s|  </.table_default>|}</code>
        <code>{~s|</.bulk_select_scope>|}</code>
        <code>{~s|<.column_settings_modal show={@show_columns} columns={spec().columns} selected={@columns} />|}</code>
        <code>{~s|def handle_event(event, params, socket) when event in ~w(add_column remove_column reorder_columns reset_columns) do|}</code>
        <code>{~s|  {:noreply, PhoenixKitWeb.TableColumns.handle_event(event, params, socket, spec(), :columns)}|}</code>
        <code>{~s|end|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "Name and the row handle are always on, so they are not in the column catalog. TableColumns saves a signed-in user's choice (their view preferences), and Reset takes it back out so they follow the default again. A table_default also takes its own toolbar_primary slot; the bulk toolbar's primary slot plays the same role. The reorder ids, like every id a handler gets, are checked against the rows you rendered."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp column_label(spec, id) do
    spec.columns
    |> Enum.find(&(&1.id == id))
    |> then(fn column -> column.label.() end)
  end

  defp manual_result_text({:reorder, count}),
    do:
      ngettext(
        "Reorder asked for %{count} selected person (a demo: nothing changed).",
        "Reorder asked for %{count} selected people (a demo: nothing changed).",
        count
      )

  defp manual_result_text({:delete, count}),
    do:
      ngettext(
        "Delete asked for %{count} selected person (a demo: nothing changed).",
        "Delete asked for %{count} selected people (a demo: nothing changed).",
        count
      )

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

  attr(:per_page, :integer, required: true)

  defp pagination_component_section(assigns) do
    total = 47
    total_pages = max(div(total + assigns.per_page - 1, assigns.per_page), 1)

    assigns =
      assign(assigns,
        self_path: Paths.components(),
        total: total,
        total_pages: total_pages,
        page: min(2, total_pages),
        page_sizes: @page_sizes
      )

    ~H"""
    <.showcase_section
      title={gettext("Pagination — core pagination")}
      description={
        gettext(
          "The wrapped counterpart to the hand-rolled join buttons above. It builds the page URLs from base_path and params, preserving your query string. The links below patch back to this page."
        )
      }
    >
      <.pagination
        current_page={@page}
        total_pages={@total_pages}
        base_path={@self_path}
        params={%{"demo" => "1"}}
      />
      <div class="flex flex-wrap items-center justify-between gap-3 mt-3">
        <.pagination_info
          page={@page}
          per_page={@per_page}
          total_count={@total}
          noun_plural={gettext("people")}
        />
        <.page_size_selector id="demo-page-size" value={@per_page} options={@page_sizes} />
      </div>

      <p class="text-xs text-base-content/60 mt-2">
        {gettext(
          "Load-more lists (streams, infinite scroll) use load_more instead — see the Events page."
        )}
      </p>
      <:snippet>
        <code>{~s|<.pagination current_page={@page} total_pages={@total_pages}|}</code>
        <code>{~s|  base_path={Paths.items()} params={%{"search" => @search}} />|}</code>
        <code>{~s|<.pagination_info page={@page} per_page={@per_page} total_count={@total} noun_plural="people" />|}</code>
        <code>{~s|<.page_size_selector value={@per_page} on_change="change_per_page" />|}</code>
        <code>{~s|<.load_more id="items" loaded={@loaded} total={@total} infinite />|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "pagination renders patch links, so the page needs a handle_params callback. A real list keeps the page size in the URL and resets to page 1 when it changes (core's UrlState does both); this demo holds it in assigns."
          )}
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

  defp charts_section(assigns) do
    assigns =
      assign(assigns,
        points: Enum.with_index(@chart_values, fn value, day -> {day, value} end),
        bars:
          Enum.with_index(@chart_values, fn value, day ->
            %{label: "D#{day + 1}", value: value}
          end),
        lanes: [
          %{
            id: "release",
            label: gettext("Release"),
            bands: [
              %{from: 1, to: 3, variant: :soft, class: "text-info", title: gettext("Planned")}
            ]
          },
          %{
            id: "freeze",
            label: gettext("Freeze"),
            bands: [
              %{
                from: 4,
                to: 5,
                variant: :fill,
                class: "text-warning",
                title: gettext("Code freeze")
              }
            ]
          }
        ]
      )

    ~H"""
    <.showcase_section
      title={gettext("Charts — line_chart, bar_chart, sparkline, chart_lanes")}
      description={
        gettext(
          "Server-rendered SVG: no JavaScript and no chart library. They re-draw whenever the assigns change and take their colour from the text colour you set."
        )
      }
    >
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div>
          <p class="text-xs text-base-content/60 mb-1">{gettext("line_chart, with a hover readout and lanes under it")}</p>
          <div class="h-40 w-full">
            <.line_chart
              id="demo-line-chart"
              data={@points}
              x_domain={{0, 6}}
              hover
              class="text-primary"
              aria_label={gettext("Sample values over seven days")}
            />
          </div>
          <.chart_lanes
            id="demo-chart-lanes"
            rows={@lanes}
            x_domain={{0, 6}}
            aria_label={gettext("Planned work over the same seven days")}
          />
        </div>
        <div>
          <p class="text-xs text-base-content/60 mb-1">{gettext("bar_chart, measured from a zero baseline")}</p>
          <div class="h-40 w-full">
            <.bar_chart
              id="demo-bar-chart"
              data={@bars}
              show_labels
              class="text-secondary"
              aria_label={gettext("Sample values per day")}
            />
          </div>
          <p class="text-xs text-base-content/60 mt-3 mb-1">{gettext("sparkline, inline")}</p>
          <.sparkline
            values={Enum.map(@points, &elem(&1, 1))}
            class="w-40 h-10 text-accent"
            aria_label={gettext("Sample values, trend")}
          />
        </div>
      </div>
      <:snippet>
        <code>{~s|<div class="h-48 w-full"><.line_chart id="signups" data={@points} x_domain={{0, 6}} hover class="text-primary" aria_label="Signups" /></div>|}</code>
        <code>{~s|<.chart_lanes id="plan" rows={@rows} x_domain={{0, 6}} />|}</code>
        <code>{~s|<div class="h-48 w-full"><.bar_chart id="sales" data={[%{label: "Mon", value: 12}]} show_labels /></div>|}</code>
        <code>{~s|<.sparkline values={@values} class="w-40 h-10 text-accent" />|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "Give the wrapper a height, or the chart takes the shape of its viewBox. Points are plain numbers: map time, money or rank to x and y first; Decimal values are converted. chart_lanes takes the same x_domain as the chart above it, so its bands line up with the chart's x. Pass aria_label to name the chart, or it is marked decorative."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:date, Date, required: true)
  attr(:today, Date, required: true)

  defp date_nav_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("Date navigation")}
      description={
        gettext(
          "Previous, next and today over a date kept in the URL — the header of a page that shows one day at a time. The buttons patch back to this page with ?date=."
        )
      }
    >
      <.date_nav
        id="demo-date-nav"
        date={@date}
        today={@today}
        max={@today}
        path={&"#{Paths.components()}?date=#{&1}"}
      />
      <p class="text-sm mt-3" id="demo-date-current">
        {gettext("Showing %{date}", date: Date.to_iso8601(@date))}
      </p>
      <:snippet>
        <code>{~s|import PhoenixKitWeb.Components.Core.DateNav, only: [date_nav: 1]|}</code>
        <code>{~s|<.date_nav date={@date} today={@today} max={@today} path={&"\#{Paths.items()}?date=\#{&1}"} />|}</code>
        <code>{~s|def handle_params(params, _uri, socket) do|}</code>
        <code>{~s|  {:noreply, assign(socket, :date, DateNav.parse_param(params["date"], today: socket.assigns.today, max: socket.assigns.today))}|}</code>
        <code>{~s|end|}</code>
        <code>{~s|def handle_event("date_nav_pick", %{"date" => value}, socket)  # the native picker: answer with a patch|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "parse_param reads the URL value and clamps it to min and max, so a hand-edited ?date= cannot take the page outside the range. A view with no URL of its own passes event instead of path, and step={7} moves a week at a time."
          )}
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp admin_page_header_section(assigns) do
    ~H"""
    <.showcase_section
      title={gettext("admin_page_header — when you need it")}
      description={
        gettext(
          "Not rendered here on purpose: the admin layout already draws the page header, from the page_title, page_subtitle and breadcrumb assigns this page sets in mount."
        )
      }
    >
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
        <div>
          <h4 class="font-semibold mb-1">{gettext("You do not need it")}</h4>
          <p class="text-base-content/70">
            {gettext(
              "On an admin page that core's layout wraps: set page_title (and page_section, page_crumbs, page_subtitle) and render no header of your own — a second one would stack under the bar."
            )}
          </p>
        </div>
        <div>
          <h4 class="font-semibold mb-1">{gettext("You do")}</h4>
          <p class="text-base-content/70">
            {gettext(
              "Where no layout draws one: a page of your own outside the admin shell, or a panel with its own title and a back link and actions on its right."
            )}
          </p>
        </div>
      </div>
      <:snippet>
        <code>{~s|<.admin_page_header title="Invoice" subtitle="Draft" back={Paths.invoices()} back_label="Invoices">|}</code>
        <code>{~s|  <:actions><.button size="sm">Send</.button></:actions>|}</code>
        <code>{~s|</.admin_page_header>|}</code>
        <p class="text-xs text-base-content/50">
          {gettext(
            "back must already be a resolved path (Paths, not a literal). The subtitle shows only when the site's show_page_descriptions setting is on."
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
        {"<.module_card />", gettext("The card on the admin Modules page.")},
        {"TreePicker",
         gettext(
           "A searchable tree for picking one record or several out of a nested set. A LiveComponent that needs a tree built with PhoenixKit.Utils.Tree."
         )},
        {"<.translatable_field />, <.multilang_tabs />, <.multilang_fields_wrapper />",
         gettext(
           "Language tabs and translatable fields (PhoenixKitWeb.Components.MultilangForm). They need the multilang setup of a real record and form."
         )},
        {"<.activity_list />",
         gettext("A slice of the Activity log as a table. It needs entries from Activity.list/1.")},
        {"<.preview_card />",
         gettext(
           "A read-only modal card with a carousel of a record's photos and files. It needs stored media."
         )},
        {"<.change_marker />",
         gettext(
           "The Updated marker of an accordion with cue set. It lives inside accordion, which pushes the highlight from the server."
         )},
        {"<.connect_account_button />",
         gettext(
           "Runs an OAuth authorization in a popup. It needs the app's OAuth start and callback routes."
         )},
        {"<.folder_explorer />",
         gettext(
           "The folder tree of the media browser. The consumer implements its navigation events."
         )}
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
        "Most core components live in phoenix_kit's lib/phoenix_kit_web/components/core directory; the larger ones (TreePicker, MultilangForm, FolderExplorer, the media browser, the dashboard and admin navigation) sit beside it in components/. Each one declares its attributes and slots — read them for the options this page does not show."
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

defmodule PhoenixKitHelloWorld.Web.ComponentsLiveTest do
  @moduledoc """
  Tests for the Components showcase.

  Two kinds: structural pins (every section in `render/1` is rendered, every
  `phx-change` form has an id, the retired wording is gone) and behaviour —
  each interactive demo is driven through the control a user would use, and
  each handler is also sent the value its whitelist exists to refuse.
  """
  use PhoenixKitHelloWorld.LiveCase

  @path "/admin/hello-world/components"

  setup %{conn: conn} do
    {:ok, view, html} = live(conn, @path)
    {:ok, view: view, html: html}
  end

  defp doc(view), do: view |> render() |> LazyHTML.from_fragment()

  defp texts(view, selector) do
    view
    |> doc()
    |> LazyHTML.query(selector)
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))
  end

  # The desktop table's first column, in row order.
  defp people_names(view), do: texts(view, "#demo-people-table table tbody tr td:first-child")

  describe "structure" do
    test "renders every showcase section", %{html: html} do
      # `<.showcase_section>` renders `<section class="card bg-base-100
      # shadow-xl">`. Ten raw daisyUI sections, twenty-eight core-component
      # sections and the "not shown here" list. Removing a section from
      # `render/1` (or its `defp`) drops the count.
      sections =
        html |> String.split(~s|<section class="card bg-base-100 shadow-xl">|) |> length()

      assert sections - 1 == 39
    end

    test "renders no page-level header or width cap", %{html: html} do
      # `page_title` is rendered once by the admin layout — no in-body title,
      # no page-root `max-w-*` or `container`.
      refute html =~ "PhoenixKit Components"
      assert html =~ ~s|<div class="flex flex-col px-4 py-6 gap-6">|
    end

    test "every section title is rendered", %{view: view} do
      titles = texts(view, "section > .card-body > h3.card-title")

      for title <- [
            "Icons",
            "Badges",
            "Buttons",
            "Alerts",
            "Stat cards",
            "Form inputs",
            "Tables",
            "Pagination",
            "Empty states",
            "Loading states",
            "Button — core button",
            "Status badge — core status_badge",
            "Collapsible sections",
            "Nav tabs",
            "Stat card",
            "Number formatter",
            "Time display",
            "File display",
            "Language switcher",
            "PhoenixKit links",
            "Form helpers",
            "Form section and form actions",
            "Modals",
            "Popover panel",
            "Table — core table_default",
            "Bulk selection",
            "Search picker",
            "Pagination — core pagination",
            "Empty state — core empty_state",
            "Draggable list",
            "Status dot",
            "Hero stat card",
            "Form extras — section_header, decimal_input, save_button",
            "Table — tree rows and clickable rows",
            "Table — manual order, columns and bulk toolbar",
            "Charts — line_chart, bar_chart, sparkline, chart_lanes",
            "Date navigation",
            "admin_page_header — when you need it",
            "Components not shown here"
          ] do
        assert title in titles, "no section titled #{inspect(title)}"
      end

      assert length(titles) == 39
    end

    test "section dividers render", %{html: html} do
      assert html =~ "PhoenixKit Core Components"
      assert html =~ "Context-dependent components"
    end

    test "every form that sends phx-change or phx-submit has an id", %{view: view} do
      forms = view |> doc() |> LazyHTML.query("form")
      assert Enum.count(forms) >= 4

      for form <- forms do
        [attrs] = LazyHTML.attributes(form)
        attrs = Map.new(attrs)

        if Map.has_key?(attrs, "phx-change") or Map.has_key?(attrs, "phx-submit") do
          assert attrs["id"] not in [nil, ""], "form without id: #{inspect(attrs)}"
        end
      end

      ids = view |> doc() |> LazyHTML.query("form[id]") |> LazyHTML.attribute("id")
      assert ids == Enum.uniq(ids)
    end

    test "the retired wording is gone", %{html: html} do
      refute html =~ "server-tracked mode"
      refute html =~ "Earmark"
      refute html =~ "52+"
      refute html =~ "Languages module not loaded"
      refute html =~ "not configured in the host app"
      assert html =~ "MDEx"
      assert html =~ "A LiveComponent"
      assert html =~ "Languages is part of core"
    end

    test "there is no raw dialog: every dialog on the page is core's", %{view: view} do
      render_click(view, "open_modal", %{})
      render_click(view, "open_confirm", %{})

      hooks = view |> doc() |> LazyHTML.query("dialog") |> LazyHTML.attribute("phx-hook")
      assert hooks != []
      assert Enum.all?(hooks, &(&1 == "PkDialog"))
    end

    test "file_mtime, listed in the moduledoc, is on the page", %{html: html} do
      assert html =~ "Modified:"
    end
  end

  describe "modal with a form" do
    test "is not in the DOM until opened", %{view: view} do
      refute has_element?(view, "#demo-modal")
    end

    test "opens centred, with the unsaved-input guard armed", %{view: view} do
      view
      |> element(~s|button[phx-click="open_modal"]:not([phx-value-placement])|)
      |> render_click()

      assert has_element?(view, ~s|dialog#demo-modal.modal[data-show="true"]|)
      refute has_element?(view, "dialog#demo-modal.modal-end")
      assert has_element?(view, ~s|#demo-modal[data-close-guard="input"][data-closeable="true"]|)
      assert has_element?(view, ~s|#demo-modal[data-close-event="close_modal"]|)
      assert has_element?(view, ~s|#demo-modal form#demo-note-form[phx-submit="save_note"]|)
      # The submit button is outside the form, tied to it by `form=`.
      assert has_element?(view, ~s|#demo-modal button[type="submit"][form="demo-note-form"]|)
    end

    test "placement end opens the same modal as a drawer", %{view: view} do
      view
      |> element(~s|button[phx-click="open_modal"][phx-value-placement="end"]|)
      |> render_click()

      assert has_element?(view, "dialog#demo-modal.modal.modal-end")
    end

    test "an unknown placement falls back to centred", %{view: view} do
      render_click(view, "open_modal", %{"placement" => "sideways"})
      assert has_element?(view, "dialog#demo-modal")
      refute has_element?(view, "dialog#demo-modal.modal-end")
    end

    test "typing makes the dialog non-closeable, and a close is refused", %{view: view} do
      render_click(view, "open_modal", %{})

      view
      |> form("#demo-note-form", %{"note" => %{"text" => "half a thought"}})
      |> render_change()

      assert has_element?(view, ~s|#demo-modal[data-closeable="false"]|)

      # What Esc or the backdrop would push.
      render_click(view, "close_modal", %{})
      assert has_element?(view, "#demo-modal")
      assert has_element?(view, ~s|#demo-note-form input[value="half a thought"]|)
    end

    test "whitespace is not input: the dialog still closes", %{view: view} do
      render_click(view, "open_modal", %{})
      view |> form("#demo-note-form", %{"note" => %{"text" => "   "}}) |> render_change()

      assert has_element?(view, ~s|#demo-modal[data-closeable="true"]|)
      render_click(view, "close_modal", %{})
      refute has_element?(view, "#demo-modal")
    end

    test "a clean dialog closes on the close event", %{view: view} do
      render_click(view, "open_modal", %{})
      render_click(view, "close_modal", %{})
      refute has_element?(view, "#demo-modal")
    end

    test "Discard closes a dirty dialog and drops the text", %{view: view} do
      render_click(view, "open_modal", %{})
      view |> form("#demo-note-form", %{"note" => %{"text" => "throw away"}}) |> render_change()

      view |> element(~s|#demo-modal button[phx-click="discard_note"]|) |> render_click()

      refute has_element?(view, "#demo-modal")
      refute has_element?(view, "#demo-saved-note")

      # Reopening starts clean.
      render_click(view, "open_modal", %{})
      assert has_element?(view, ~s|#demo-modal[data-closeable="true"]|)
      refute render(view) =~ "throw away"
    end

    test "Save submits the form, closes the dialog and shows the note", %{view: view} do
      render_click(view, "open_modal", %{})

      html =
        view
        |> form("#demo-note-form", %{"note" => %{"text" => "  ship it  "}})
        |> render_submit()

      assert html =~ "Note saved."
      refute has_element?(view, "#demo-modal")
      assert has_element?(view, "#demo-saved-note", "Saved note: ship it")
    end

    test "an empty note is not saved and the dialog stays", %{view: view} do
      render_click(view, "open_modal", %{})

      html = view |> form("#demo-note-form", %{"note" => %{"text" => " "}}) |> render_submit()

      assert html =~ "Write a note before saving."
      assert has_element?(view, "#demo-modal")
      refute has_element?(view, "#demo-saved-note")
    end
  end

  describe "confirm modal" do
    test "confirming increments the counter and flashes", %{view: view, html: html} do
      assert html =~ "counter: 0"

      assert render_click(view, "open_confirm", %{}) =~ "Confirm action"

      rendered = render_click(view, "confirmed", %{})
      assert rendered =~ "counter: 1"
      assert rendered =~ "Confirmed! Counter is now 1"
    end

    test "cancelling leaves the counter alone", %{view: view} do
      render_click(view, "open_confirm", %{})
      rendered = render_click(view, "cancel_confirm", %{})
      assert rendered =~ "counter: 0"
      refute rendered =~ "Are you sure you want to increment"
    end
  end

  describe "nav tabs" do
    test "the three variants render their own tablist classes", %{view: view} do
      assert has_element?(view, ~s|#demo-tabs-boxed [role="tablist"].tabs-box|)
      assert has_element?(view, ~s|#demo-tabs-border [role="tablist"].tabs-border|)
      refute has_element?(view, ~s|#demo-tabs-plain [role="tablist"].tabs-box|)
      refute has_element?(view, ~s|#demo-tabs-plain [role="tablist"].tabs-border|)
    end

    test "the trailing slot sits inside the strip, and a badge on its tab", %{view: view} do
      assert has_element?(view, ~s|#demo-tabs-boxed [role="tablist"] .ml-auto|, "3 new")
      assert has_element?(view, ~s|#demo-tabs-boxed [role="tab"] .badge|, "3")
    end

    test "clicking a tab switches every strip", %{view: view, html: html} do
      assert html =~ "Active tab: <strong>overview"

      rendered =
        view |> element(~s|#demo-tabs-border button[phx-value-tab="settings"]|) |> render_click()

      assert rendered =~ "Active tab: <strong>settings"
      assert has_element?(view, ~s|#demo-tabs-boxed button.tab-active[phx-value-tab="settings"]|)
      assert has_element?(view, ~s|#demo-tabs-plain button.tab-active[phx-value-tab="settings"]|)
    end

    test "an unknown tab id is ignored", %{view: view} do
      rendered = render_click(view, "switch_tab", %{"tab" => "evil"})
      assert rendered =~ "Active tab: <strong>overview"
      refute rendered =~ "evil"
    end
  end

  describe "core button and status badge" do
    test "variant replaces the base colour; a navigation attr renders a link", %{view: view} do
      assert has_element?(view, "#demo-core-buttons button.btn.btn-primary", "Primary")
      assert has_element?(view, "#demo-core-buttons button.btn.btn-ghost", "Ghost")
      refute has_element?(view, "#demo-core-buttons button.btn-ghost.btn-primary")
      assert has_element?(view, "#demo-core-buttons button.btn[disabled]", "Disabled")

      assert has_element?(
               view,
               ~s|a#demo-button-link.btn.btn-outline.btn-sm[href="#{PhoenixKitHelloWorld.Paths.components()}"]|
             )
    end

    test "status picks the colour and humanises the label", %{view: view} do
      assert has_element?(view, "#demo-status-badges .badge.badge-success", "Active")
      assert has_element?(view, "#demo-status-badges .badge.badge-info", "In progress")
      assert has_element?(view, "#demo-status-badges .badge.badge-error", "Deleted")
      # Unknown status: neutral, never a crash.
      assert has_element?(view, ".badge.badge-ghost", "Something else")
    end
  end

  describe "table: search, sort, row menu" do
    test "starts sorted by name, ascending, with every person", %{view: view} do
      assert people_names(view) == ~w(Alice Bob Carol Dave Erin)
      assert has_element?(view, "#demo-people-count", "5 people")
      assert has_element?(view, ~s|#demo-people-table th[aria-sort="ascending"]|, "Name")
    end

    test "clicking a sorted header flips it; another header sorts ascending by it", %{view: view} do
      view |> element(~s|#demo-people-table th button[phx-value-by="name"]|) |> render_click()
      assert people_names(view) == ~w(Erin Dave Carol Bob Alice)
      assert has_element?(view, ~s|#demo-people-table th[aria-sort="descending"]|, "Name")

      view |> element(~s|#demo-people-table th button[phx-value-by="status"]|) |> render_click()
      # active, active, inactive, pending, suspended — ties keep name order.
      assert people_names(view) == ~w(Bob Alice Carol Dave Erin) or
               people_names(view) == ~w(Alice Bob Carol Dave Erin)

      assert Enum.drop(people_names(view), 2) == ~w(Carol Dave Erin)
      assert has_element?(view, ~s|#demo-people-table th[aria-sort="ascending"]|, "Status")
    end

    test "a sort field outside the whitelist changes nothing", %{view: view} do
      for by <- ["id", "__struct__", "", "name; drop"] do
        render_click(view, "toggle_sort", %{"by" => by})
        assert people_names(view) == ~w(Alice Bob Carol Dave Erin)
      end

      render_click(view, "toggle_sort", %{})
      assert people_names(view) == ~w(Alice Bob Carol Dave Erin)
    end

    test "the search box filters by name, case-insensitively", %{view: view} do
      view |> element("#demo-people-search input") |> render_change(%{"search" => "AR"})

      assert people_names(view) == ~w(Carol)
      assert has_element?(view, "#demo-people-count", "1 person")
      assert has_element?(view, ~s|#demo-people-search input[value="AR"]|)
    end

    test "a search with no match shows the empty state; clearing it restores the rows", %{
      view: view
    } do
      html = view |> element("#demo-people-search input") |> render_change(%{"search" => "zzz"})
      assert html =~ "No people match this search."
      assert people_names(view) == []

      view |> element("#demo-people-search input") |> render_change(%{"search" => ""})
      assert people_names(view) == ~w(Alice Bob Carol Dave Erin)
      refute render(view) =~ "No people match this search."
    end

    test "search and sort compose", %{view: view} do
      view |> element("#demo-people-search input") |> render_change(%{"search" => "a"})
      view |> element(~s|#demo-people-table th button[phx-value-by="name"]|) |> render_click()

      assert people_names(view) == ~w(Dave Carol Alice)
    end

    test "a row menu item acts on its own row", %{view: view} do
      refute has_element?(view, "#demo-row-action")

      view
      |> element(~s|#demo-person-menu-bob-content button[phx-value-action="archive"]|)
      |> render_click()

      assert has_element?(view, "#demo-row-action", "Archived Bob")

      view
      |> element(~s|#demo-person-menu-erin-content button[phx-value-action="view"]|)
      |> render_click()

      assert has_element?(view, "#demo-row-action", "Viewed Erin.")
    end

    test "a row action with an unknown action or id is ignored", %{view: view} do
      render_click(view, "row_action", %{"action" => "delete", "id" => "bob"})
      render_click(view, "row_action", %{"action" => "view", "id" => "mallory"})
      render_click(view, "row_action", %{"action" => "view"})

      refute has_element?(view, "#demo-row-action")
    end

    test "each row menu uses core's RowMenu hook under a unique id", %{view: view} do
      ids = view |> doc() |> LazyHTML.query(~s|[phx-hook="RowMenu"]|) |> LazyHTML.attribute("id")
      # Five in the people table, five more in the row-link table.
      assert length(ids) == 10
      assert ids == Enum.uniq(ids)
    end

    test "the sort selector sends one control's half; the other comes from the assigns", %{
      view: view
    } do
      assert has_element?(view, ~s|#demo-sort-selector select[name="sort_by"]|)

      view |> element("#demo-sort-selector") |> render_change(%{"sort_by" => "role"})
      assert people_names(view) == ~w(Alice Erin Bob Carol Dave)

      render_click(view, "sort_form", %{"sort_dir" => "desc"})
      assert people_names(view) == ~w(Bob Carol Dave Alice Erin)
    end

    test "a sort field or direction outside the whitelist changes nothing", %{view: view} do
      before = people_names(view)

      render_click(view, "sort_form", %{"sort_by" => "password"})
      render_click(view, "sort_form", %{"sort_dir" => "sideways"})
      render_click(view, "sort_form", %{"sort_by" => %{"x" => 1}})

      assert people_names(view) == before
    end

    test "toolbar_primary holds the create button", %{view: view} do
      assert has_element?(view, "#demo-people-table button.btn", "New person")
    end
  end

  describe "alert modal" do
    test "each type opens an acknowledge-only dialog and OK closes it", %{view: view} do
      refute has_element?(view, "dialog[data-show=\"true\"]")

      view |> element("#demo-alert-warning") |> render_click()
      assert render(view) =~ "This is a warning"

      view |> element("#demo-alert-error") |> render_click()
      assert render(view) =~ "This is an error"
      refute render(view) =~ "This is a warning"

      render_click(view, "close_alert", %{})
      refute render(view) =~ "This is an error"
    end

    test "the success alert is one of the buttons", %{view: view} do
      view |> element("#demo-alert-success") |> render_click()
      assert render(view) =~ "This is a success"
    end

    test "the info alert has an OK button that closes it", %{view: view} do
      view |> element("#demo-alert-info") |> render_click()
      assert render(view) =~ "This is a notice"
      assert has_element?(view, "dialog button", "OK")

      view |> element(~s|dialog button[phx-click="close_alert"]|, "OK") |> render_click()
      refute render(view) =~ "This is a notice"
    end

    test "an alert type outside the list opens nothing", %{view: view} do
      render_click(view, "open_alert", %{"type" => "fatal"})
      render_click(view, "open_alert", %{})

      refute render(view) =~ "Press OK to acknowledge"
    end
  end

  describe "tree rows and clickable rows" do
    defp tree_names(view), do: texts(view, "#demo-tree table tbody tr")

    test "starts with Documents open; a chevron expands and collapses", %{view: view} do
      assert tree_names(view) == ["Documents", "Specs", "README.md", "Photos", "notes.txt"]

      view
      |> element(~s|#demo-tree-docs-specs button[phx-value-uuid="docs-specs"]|)
      |> render_click()

      assert "api.md" in tree_names(view)
      assert has_element?(view, ~s|#demo-tree-docs-specs button[aria-expanded="true"]|)

      view |> element(~s|#demo-tree-docs button[phx-value-uuid="docs"]|) |> render_click()
      assert tree_names(view) == ["Documents", "Photos", "notes.txt"]
    end

    test "a toggle for a leaf or an unknown node changes nothing", %{view: view} do
      before = tree_names(view)

      render_click(view, "toggle_node", %{"uuid" => "notes"})
      render_click(view, "toggle_node", %{"uuid" => "nope"})
      render_click(view, "toggle_node", %{})

      assert tree_names(view) == before
    end

    test "depth indents the name", %{view: view} do
      assert has_element?(
               view,
               ~s|#demo-tree-docs-specs div[style*="padding-left: calc(1 * 1.5rem)"]|
             )

      refute has_element?(view, ~s|#demo-tree-docs div[style*="padding-left"]|)
    end

    test "row_link is one real link per row, named for the row, above a clickable menu", %{
      view: view
    } do
      href = PhoenixKitHelloWorld.Paths.components()

      for name <- ~w(Alice Bob Carol Dave Erin) do
        assert has_element?(
                 view,
                 ~s|#demo-linked-#{String.downcase(name)} a[href="#{href}"] .sr-only|,
                 "Open #{name}"
               )
      end

      for id <- ~w(alice bob carol dave erin) do
        assert has_element?(view, "#demo-linked-#{id}.relative.transform-gpu")
        assert has_element?(view, "#demo-linked-#{id} td.relative.z-10")
      end
    end
  end

  describe "manual order, bulk toolbar and columns" do
    defp manual_order(view), do: texts(view, "#demo-manual-body tr td:nth-child(3)")
    defp manual_headers(view), do: texts(view, "#demo-manual-scope table thead th")

    test "rows are sortable rows with a handle and a checkbox each", %{view: view} do
      assert manual_order(view) == ~w(Alice Bob Carol Dave Erin)

      assert has_element?(
               view,
               ~s|#demo-manual-body[phx-hook="SortableGrid"][data-sortable-event="reorder_people"]|
             )

      assert has_element?(
               view,
               ~s|#demo-manual-bob.sortable-item[data-id="bob"] td.pk-drag-handle|
             )

      assert has_element?(view, ~s|#demo-manual-bob input[data-bulk-role="row"][data-uuid="bob"]|)
    end

    test "the toolbar carries the primary action and the contextual buttons", %{view: view} do
      assert has_element?(view, ~s|#demo-manual-scope button[data-bulk-action="open_reorder"]|)
      assert has_element?(view, ~s|#demo-manual-scope button[data-bulk-action="bulk_delete"]|)
      assert has_element?(view, "#demo-manual-scope button.btn", "New person")
    end

    test "a drop reorders; anything but a permutation is refused", %{view: view} do
      render_click(view, "reorder_people", %{"ordered_ids" => ~w(erin dave carol bob alice)})
      assert manual_order(view) == ~w(Erin Dave Carol Bob Alice)

      for ids <- [
            ~w(erin dave),
            ~w(erin erin carol bob alice),
            ~w(erin dave carol bob mallory),
            "x"
          ] do
        render_click(view, "reorder_people", %{"ordered_ids" => ids})
        assert manual_order(view) == ~w(Erin Dave Carol Bob Alice), "accepted #{inspect(ids)}"
      end

      assert has_element?(view, "#demo-manual-order", "Erin, Dave, Carol, Bob, Alice")
    end

    test "reorder and delete count only the ids the server knows", %{view: view} do
      render_click(view, "open_reorder", %{"uuids" => ~w(alice bob bob mallory)})
      assert has_element?(view, "#demo-manual-result", "Reorder asked for 2 selected people")

      render_click(view, "bulk_delete", %{"uuids" => ["carol"]})
      assert has_element?(view, "#demo-manual-result", "Delete asked for 1 selected person ")

      render_click(view, "bulk_delete", %{"uuids" => "carol"})
      assert has_element?(view, "#demo-manual-result", "Delete asked for 1 selected person ")
    end

    test "the column editor opens, adds, removes and resets", %{view: view} do
      assert manual_headers(view) == ["", "", "Name", "Role", "Status"]
      refute has_element?(view, "#pk-column-settings-modal")

      view |> element("#demo-columns-open") |> render_click()
      assert has_element?(view, "#pk-column-settings-modal")

      view
      |> element(
        ~s|#pk-column-settings-modal button[phx-click="add_column"][phx-value-column_id="joined"]|
      )
      |> render_click()

      assert manual_headers(view) == ["", "", "Name", "Role", "Status", "Joined"]
      assert has_element?(view, "#demo-manual-alice td", "2024-03-12")

      view
      |> element(
        ~s|#pk-column-settings-modal button[phx-click="remove_column"][phx-value-column_id="role"]|
      )
      |> render_click()

      assert manual_headers(view) == ["", "", "Name", "Status", "Joined"]

      render_click(view, "reorder_columns", %{"ordered_ids" => ~w(joined status)})
      assert manual_headers(view) == ["", "", "Name", "Joined", "Status"]

      render_click(view, "reset_columns", %{})
      assert manual_headers(view) == ["", "", "Name", "Role", "Status"]

      render_click(view, "hide_column_modal", %{})
      refute has_element?(view, "#pk-column-settings-modal")
    end

    test "a column id outside the catalog changes nothing", %{view: view} do
      render_click(view, "show_column_modal", %{})

      render_click(view, "add_column", %{"column_id" => "password_hash"})
      render_click(view, "add_column", %{"column_id" => %{"x" => 1}})
      render_click(view, "remove_column", %{"column_id" => "joined"})
      render_click(view, "reorder_columns", %{"ordered_ids" => "role"})

      assert manual_headers(view) == ["", "", "Name", "Role", "Status"]
    end

    test "the events the page answers are the ones core's TableColumns names" do
      assert Enum.sort(PhoenixKitWeb.TableColumns.events()) ==
               Enum.sort(~w(add_column remove_column reorder_columns reset_columns))
    end

    test "a signed-in user's column choice is kept for their next visit", %{conn: conn} do
      user = user_fixture()
      scope = fake_scope(user_uuid: user.uuid, email: user.email)

      {:ok, view, _html} = conn |> put_test_scope(scope) |> live(@path)
      render_click(view, "show_column_modal", %{})
      render_click(view, "add_column", %{"column_id" => "joined"})
      assert manual_headers(view) == ["", "", "Name", "Role", "Status", "Joined"]

      {:ok, again, _html} = conn |> put_test_scope(scope) |> live(@path)
      assert manual_headers(again) == ["", "", "Name", "Role", "Status", "Joined"]
    end
  end

  describe "form extras" do
    test "decimal_input takes a comma or a dot, and the server parses it", %{view: view} do
      assert has_element?(view, "#demo-measure-parsed", "Quantity: 2.5")
      assert has_element?(view, ~s|#demo-measure-form input[inputmode="decimal"][type="text"]|)

      view
      |> form("#demo-measure-form", measure: %{qty: "1 234,5", weight: "0.25"})
      |> render_change()

      assert has_element?(view, "#demo-measure-parsed", "Quantity: 1234.5")
      assert has_element?(view, "#demo-measure-parsed", "Weight: 0.25")
    end

    test "text that is not a non-negative number is named, not guessed at", %{view: view} do
      view
      |> form("#demo-measure-form", measure: %{qty: "-3", weight: "abc"})
      |> render_change()

      assert has_element?(view, "#demo-measure-parsed", "Quantity: below the minimum")
      assert has_element?(view, "#demo-measure-parsed", "Weight: not a number")

      view |> form("#demo-measure-form", measure: %{qty: "", weight: "1"}) |> render_change()
      assert has_element?(view, "#demo-measure-parsed", "Quantity: empty")
    end

    test "a payload that is not the form's two text fields changes nothing", %{view: view} do
      before = render(view)

      render_change(view, "validate_measure", %{
        "measure" => %{"qty" => %{"a" => "1"}, "weight" => "1"}
      })

      render_change(view, "validate_measure", %{"measure" => "x"})
      render_change(view, "validate_measure", %{"measure" => %{"qty" => ["1"], "weight" => "1"}})
      render_submit(view, "save_measure", %{"measure" => %{"qty" => "1"}})

      assert render(view) == before
    end

    test "text the server refused is not reported as saved", %{view: view} do
      view |> form("#demo-measure-form", measure: %{qty: "abc"}) |> render_change()
      view |> form("#demo-measure-form") |> render_submit()

      refute has_element?(view, "#demo-measure-form", "Saved")
      refute has_element?(view, "#demo-measure-form button[type=submit][disabled]")
    end

    test "save_button is idle, then live once something changed, then confirms", %{view: view} do
      assert has_element?(view, "#demo-measure-form button[type=submit][disabled]")

      view |> form("#demo-measure-form", measure: %{qty: "3"}) |> render_change()
      refute has_element?(view, "#demo-measure-form button[type=submit][disabled]")
      assert has_element?(view, "#demo-measure-form button.btn-primary", "Save")
      assert has_element?(view, "#demo-measure-form", "Unsaved changes")

      view |> form("#demo-measure-form") |> render_submit()
      assert has_element?(view, "#demo-measure-form button[type=submit][disabled]")
      assert has_element?(view, "#demo-measure-form", "Saved")
    end

    test "the bare control is the input alone", %{view: view} do
      assert has_element?(view, ~s|.join input#demo-bare-qty.join-item[inputmode="decimal"]|)
      refute has_element?(view, ".join .label")
    end
  end

  describe "pagination info and page size" do
    test "the info line and the selector follow the page size", %{view: view} do
      assert render(view) =~ "Showing 11 to 20 of 47 people"
      assert has_element?(view, ~s|#demo-page-size option[value="10"][selected]|)

      view |> element("#demo-page-size-form") |> render_change(%{"per_page" => "25"})
      assert render(view) =~ "Showing 26 to 47 of 47 people"
      assert has_element?(view, ~s|#demo-page-size option[value="25"][selected]|)

      view |> element("#demo-page-size-form") |> render_change(%{"per_page" => "100"})
      assert render(view) =~ "Showing 1 to 47 people"
    end

    test "a page size outside the options is ignored", %{view: view} do
      for value <- ["7", "ten", "", "25abc"] do
        render_click(view, "change_per_page", %{"per_page" => value})
        assert render(view) =~ "Showing 11 to 20 of 47 people", "accepted #{inspect(value)}"
      end

      render_click(view, "change_per_page", %{"per_page" => [25]})
      assert render(view) =~ "Showing 11 to 20 of 47 people"
    end
  end

  describe "typed badges" do
    test "each takes its record and shows its own state", %{view: view} do
      for text <-
            ~w(Owner Editor Active Unconfirmed Inactive Expired System Marketing Transactional Disabled) do
        assert has_element?(view, "#demo-typed-badges .badge", text), "no #{text} badge"
      end

      assert has_element?(view, "#demo-typed-badges .badge-error", "Owner")
      assert has_element?(view, "#demo-typed-badges .badge-primary", "Editor")
      assert has_element?(view, "#demo-typed-badges .badge-warning", "Unconfirmed")
      assert has_element?(view, "#demo-typed-badges .badge-neutral", "Disabled")
    end
  end

  describe "under a locale prefix" do
    test "the page mounts and renders its sections under /en", %{conn: conn} do
      {:ok, view, html} = live(conn, "/en" <> @path)

      assert html =~ "PhoenixKit Core Components"
      assert has_element?(view, "section h3.card-title", "Date navigation")

      # All 39 sections, not just the two probed above.
      sections =
        html |> String.split(~s|<section class="card bg-base-100 shadow-xl">|) |> length()

      assert sections - 1 == 39
    end
  end

  describe "status dot, hero stat card, charts" do
    test "status_dot renders each variant with its label", %{view: view} do
      for label <- ~w(online offline degraded syncing idle) do
        assert has_element?(view, "#demo-status-dots", label)
      end

      # Each variant is a different colour, not the same dot under five labels.
      html = view |> element("#demo-status-dots") |> render()
      for color <- ~w(success error warning info), do: assert(html =~ color)
    end

    test "hero_stat_card shows the value; navigate turns the card into a link", %{view: view} do
      assert has_element?(view, "#demo-hero-stats", "People")
      # The values come from the five sample people, two of them admins.
      assert texts(view, "#demo-hero-stats .text-7xl") == ["5", "2"]
      assert has_element?(view, "#demo-hero-stats", "Administrators")

      assert has_element?(
               view,
               ~s|#demo-hero-stats a[href="#{PhoenixKitHelloWorld.Paths.components()}"]|
             )
    end

    test "the charts are labelled SVG, drawn without JavaScript", %{view: view} do
      for label <- [
            "Sample values over seven days",
            "Sample values per day",
            "Sample values, trend"
          ] do
        assert has_element?(view, ~s|svg[aria-label="#{label}"]|), "no chart labelled #{label}"
      end

      assert has_element?(view, "#demo-chart-lanes li", "Release")
      assert has_element?(view, "#demo-chart-lanes li", "Freeze")
    end
  end

  describe "date navigation" do
    test "starts on today, with no way forward", %{view: view} do
      today = Date.to_iso8601(Date.utc_today())
      assert has_element?(view, "#demo-date-current", "Showing #{today}")

      refute has_element?(
               view,
               ~s|#demo-date-nav a[href*="date=#{Date.add(Date.utc_today(), 1)}"]|
             )
    end

    test "the date comes from the URL; garbage and the future are clamped", %{conn: conn} do
      {:ok, view, _html} = live(conn, @path <> "?date=2020-01-15")
      assert has_element?(view, "#demo-date-current", "Showing 2020-01-15")
      assert has_element?(view, ~s|#demo-date-nav a[href$="date=2020-01-14"]|)

      today = Date.to_iso8601(Date.utc_today())

      for value <- ["not-a-date", "2999-01-01", ""] do
        {:ok, view, _html} = live(conn, @path <> "?date=" <> value)

        assert has_element?(view, "#demo-date-current", "Showing #{today}"),
               "took #{inspect(value)}"
      end
    end

    test "the picker answers with a patch that keeps the date in the URL", %{view: view} do
      render_click(view, "date_nav_pick", %{"date" => "2021-06-01"})
      assert_patch(view, @path <> "?date=2021-06-01")
      assert has_element?(view, "#demo-date-current", "Showing 2021-06-01")
    end
  end

  describe "admin_page_header section" do
    test "explains the header and renders none of its own", %{view: view} do
      assert has_element?(view, "section", "admin_page_header — when you need it")
      refute has_element?(view, "main header, header.mb-3")
    end
  end

  describe "bulk selection, server-owned" do
    test "the bar appears with the count and clears", %{view: view} do
      refute render(view) =~ "1 selected"

      html = view |> element("#demo-select-bob") |> render_click()
      assert html =~ "1 selected"
      assert has_element?(view, "#demo-select-bob[checked]")

      html = view |> element("#demo-select-erin") |> render_click()
      assert html =~ "2 selected"

      # Toggling again deselects.
      html = view |> element("#demo-select-bob") |> render_click()
      assert html =~ "1 selected"
      refute has_element?(view, "#demo-select-bob[checked]")

      html = view |> element(~s|button[phx-click="deselect_all"]|) |> render_click()
      refute html =~ "1 selected"
      refute has_element?(view, "#demo-select-erin[checked]")
    end

    test "the action reports the selection and empties it", %{view: view} do
      view |> element("#demo-select-alice") |> render_click()
      view |> element("#demo-select-carol") |> render_click()

      view
      |> element(~s|button[phx-click="bulk_action"][phx-value-action="archive"]|)
      |> render_click()

      assert has_element?(view, "#demo-bulk-result", "Archived 2 rows")
      refute has_element?(view, ~s|input[phx-click="toggle_select"][checked]|)
      refute has_element?(view, ~s|button[phx-click="bulk_action"]|)
    end

    test "an id the server does not know is never selected", %{view: view} do
      html = render_click(view, "toggle_select", %{"id" => "mallory"})
      refute html =~ "1 selected"
    end
  end

  describe "bulk selection, client-owned" do
    test "the scope is wired for core's BulkSelectScope hook", %{view: view} do
      assert has_element?(
               view,
               ~s|#demo-bulk-scope[phx-hook="BulkSelectScope"][data-bulk-total="5"]|
             )

      assert has_element?(
               view,
               ~s|#demo-bulk-scope input#demo-bulk-select-all[data-bulk-role="select-all"]|
             )

      assert has_element?(
               view,
               ~s|#demo-bulk-scope input[data-bulk-role="row"][data-uuid="dave"]|
             )

      assert has_element?(view, ~s|#demo-bulk-scope button[data-bulk-action="bulk_archive"]|)
      assert has_element?(view, ~s|#demo-bulk-scope button[data-bulk-clear]|)
    end

    test "the action receives the ids from the hook and keeps the ones it knows", %{view: view} do
      # The payload the hook pushes: `%{uuids: [...]}`, to the scope element.
      view
      |> element("#demo-bulk-scope")
      |> render_hook("bulk_archive", %{"uuids" => ["alice", "bob", "mallory", "bob"]})

      assert has_element?(view, "#demo-bulk-result", "received 2 selected ids")

      view |> element("#demo-bulk-scope") |> render_hook("bulk_archive", %{"uuids" => ["erin"]})
      assert has_element?(view, "#demo-bulk-result", "received 1 selected id from")
    end

    test "a malformed payload is ignored", %{view: view} do
      view |> element("#demo-bulk-scope") |> render_hook("bulk_archive", %{"uuids" => "alice"})
      view |> element("#demo-bulk-scope") |> render_hook("bulk_archive", %{})
      refute has_element?(view, "#demo-bulk-result")
    end
  end

  describe "search picker" do
    defp search(view, q) do
      view |> element("#demo-picker") |> render_hook("picker_search", %{"q" => q, "limit" => 10})
    end

    test "is core's SearchPicker hook with its dropdown container", %{view: view} do
      assert has_element?(view, ~s|input#demo-picker[phx-hook="SearchPicker"]|)
      assert has_element?(view, ~s|#demo-picker[data-dropdown="demo-picker-dropdown"]|)
      assert has_element?(view, "#demo-picker-dropdown")
    end

    test "a search answers on the results event with matching rows, echoing the query", %{
      view: view
    } do
      search(view, "aR")

      assert_push_event(view, "picker_results", %{q: "aR", results: results, has_more: false})
      assert [%{kind: "person", uuid: "carol", label: "Carol", sublabel: "user"}] = results
    end

    test "an empty query browses everyone", %{view: view} do
      search(view, "")
      assert_push_event(view, "picker_results", %{q: "", results: results})
      assert Enum.map(results, & &1.uuid) == ~w(alice bob carol dave erin)
    end

    test "picking stages a chip, confirms to the hook, and drops the row from later results", %{
      view: view
    } do
      view
      |> element("#demo-picker")
      |> render_hook("picker_pick", %{"kind" => "person", "uuid" => "bob", "label" => "Bob"})

      assert_push_event(view, "picker_staged", %{})
      assert has_element?(view, "#demo-picked .badge", "Bob")

      search(view, "")
      assert_push_event(view, "picker_results", %{results: results})
      refute "bob" in Enum.map(results, & &1.uuid)
    end

    test "picking the same person twice, or an unknown one, stages nothing new", %{view: view} do
      pick = fn uuid ->
        view |> element("#demo-picker") |> render_hook("picker_pick", %{"uuid" => uuid})
      end

      pick.("bob")
      pick.("bob")
      pick.("mallory")

      assert texts(view, "#demo-picked .badge") == ["Bob"]
    end

    test "a chip's remove button unstages it", %{view: view} do
      view |> element("#demo-picker") |> render_hook("picker_pick", %{"uuid" => "dave"})
      assert has_element?(view, "#demo-picked .badge", "Dave")

      view |> element(~s|#demo-picked button[phx-value-id="dave"]|) |> render_click()
      refute has_element?(view, "#demo-picked .badge")
    end
  end

  describe "form section and form actions" do
    test "renders the titled card, its subtitle and the footer", %{view: view} do
      assert has_element?(view, "#demo-profile-form .card .card-title", "Profile")
      assert has_element?(view, "#demo-profile-form", "Shown next to everything you post.")

      # An empty name cannot be saved, and the label says why.
      assert has_element?(
               view,
               ~s|#demo-profile-form button[type="submit"][phx-disable-with][disabled]|,
               "Enter a name to save"
             )

      assert has_element?(
               view,
               ~s|#demo-profile-form button[type="button"][phx-click="reset_profile"]|
             )
    end

    test "submitting saves; Cancel resets", %{view: view} do
      view
      |> form("#demo-profile-form", %{"profile" => %{"display_name" => " Grace "}})
      |> render_submit()

      assert has_element?(view, "#demo-profile-saved", "Saved display name: Grace")
      assert has_element?(view, ~s|#demo-profile-form input[value=" Grace "]|)

      view |> element(~s|#demo-profile-form button[phx-click="reset_profile"]|) |> render_click()

      refute has_element?(view, "#demo-profile-saved")
      refute has_element?(view, ~s|#demo-profile-form input[value=" Grace "]|)
    end

    test "submit_disabled follows the name: typing enables Save, clearing disables it", %{
      view: view
    } do
      view
      |> form("#demo-profile-form", %{"profile" => %{"display_name" => "Gr"}})
      |> render_change()

      assert has_element?(view, ~s|#demo-profile-form button[type="submit"]|, "Save profile")
      refute has_element?(view, ~s|#demo-profile-form button[type="submit"][disabled]|)

      view
      |> form("#demo-profile-form", %{"profile" => %{"display_name" => "  "}})
      |> render_change()

      assert has_element?(view, ~s|#demo-profile-form button[type="submit"][disabled]|)
    end

    test "a profile payload whose name is not text changes nothing", %{view: view} do
      before = render(view)

      render_change(view, "validate_profile", %{"profile" => %{"display_name" => %{"a" => 1}}})
      render_submit(view, "save_profile", %{"profile" => %{"display_name" => ["x"]}})

      assert render(view) == before
    end

    test "typing keeps the value across the change round-trip", %{view: view} do
      view
      |> form("#demo-profile-form", %{"profile" => %{"display_name" => "Gr"}})
      |> render_change()

      assert has_element?(view, ~s|#demo-profile-form input[value="Gr"]|)
    end
  end

  describe "popover panel" do
    test "is rendered hidden next to its trigger, and its content talks to the server", %{
      view: view
    } do
      assert has_element?(view, ~s|#demo-popover.hidden[role="dialog"]|)
      assert has_element?(view, "#demo-popover", "Counter: 0")

      view |> element(~s|#demo-popover button[phx-click="bump_counter"]|) |> render_click()

      assert has_element?(view, "#demo-popover", "Counter: 1")
      # The panel is the same element after the re-render — nothing closes it.
      assert has_element?(view, ~s|#demo-popover[role="dialog"]|)
    end
  end

  describe "empty state" do
    test "the cta slot renders inside the card and featured variants", %{view: view} do
      assert has_element?(view, "#demo-empty-card .card button.btn", "Create")

      assert has_element?(
               view,
               "#demo-empty-featured .card.border-dashed button.btn",
               "Create first item"
             )
    end
  end

  describe "draggable list" do
    defp item_labels(view),
      do: texts(view, "#demo-draggable span") |> Enum.filter(&(&1 =~ "Item"))

    @tag :capture_log
    test "a reorder that is not a permutation of the items is rejected", %{view: view} do
      original = for n <- 1..6, do: "Item #{n}"
      assert item_labels(view) == original

      for ids <- [["1", "2"], ["1", "1", "2", "3", "4", "5"], ~w(1 2 3 4 5 9), "123456"] do
        render_click(view, "reorder_items", %{"ordered_ids" => ids})
        assert item_labels(view) == original, "accepted #{inspect(ids)}"
      end
    end

    test "a valid permutation reorders", %{view: view} do
      render_click(view, "reorder_items", %{"ordered_ids" => ~w(6 5 4 3 2 1)})
      assert item_labels(view) == for(n <- 6..1//-1, do: "Item #{n}")
    end
  end

  describe "robustness" do
    test "an unknown event, or a known one with a bad payload, changes nothing", %{view: view} do
      before = people_names(view)

      render_click(view, "no_such_event", %{})
      render_click(view, "search_people", %{"search" => %{"nested" => "map"}})
      render_click(view, "save_note", %{"oops" => 1})
      render_click(view, "picker_search", %{"q" => 5})

      assert people_names(view) == before
      assert render(view) =~ "PhoenixKit Core Components"
    end

    test "an unrelated process message is ignored", %{view: view} do
      send(view.pid, :unknown_pubsub_event)
      send(view.pid, {:something, :random, "payload"})

      assert render(view) =~ "PhoenixKit Core Components"
      assert people_names(view) == ~w(Alice Bob Carol Dave Erin)
    end
  end
end

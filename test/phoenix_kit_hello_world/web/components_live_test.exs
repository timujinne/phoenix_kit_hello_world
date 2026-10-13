defmodule PhoenixKitHelloWorld.Web.ComponentsLiveTest do
  @moduledoc """
  Tests for the Components showcase.

  Two kinds: structural pins (every section in `render/1` is rendered, every
  `phx-change` form has an id, the retired wording is gone) and behaviour —
  each interactive demo is driven through the control a user would use, and
  each handler is also sent the value its whitelist exists to refuse.
  """
  use PhoenixKitHelloWorld.LiveCase

  @path "/en/admin/hello-world/components"

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
      # shadow-xl">`. Ten raw daisyUI sections, twenty core-component
      # sections and the "not shown here" list. Removing a section from
      # `render/1` (or its `defp`) drops the count.
      sections =
        html |> String.split(~s|<section class="card bg-base-100 shadow-xl">|) |> length()

      assert sections - 1 == 31
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
            "Components not shown here"
          ] do
        assert title in titles, "no section titled #{inspect(title)}"
      end

      assert length(titles) == 31
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
      refute html =~ "toggle_event"
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
      assert has_element?(view, ~s|a#demo-button-link.btn.btn-outline.btn-sm[href="#{@path}"]|)
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
      assert length(ids) == 5
      assert ids == Enum.uniq(ids)
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

      assert has_element?(
               view,
               ~s|#demo-profile-form button[type="submit"][phx-disable-with]|,
               "Save profile"
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

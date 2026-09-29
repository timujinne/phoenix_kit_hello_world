defmodule PhoenixKitHelloWorld.Web.ComponentsLive do
  @moduledoc """
  Showcase of PhoenixKit core components.

  This page demonstrates how to use components from `PhoenixKitWeb.Components.Core.*`
  so you can copy-paste the patterns into your own modules. Every section includes a
  live example plus the source snippet in a `<details>` block.

  ## Page structure

  The page has two halves separated by `<.section_divider>`: raw daisyUI markup
  first, then the PhoenixKit core component that wraps it. The pairs are
  deliberate — `form_inputs_section` → `form_helpers_section`,
  `tables_section` → `table_default_section`, `pagination_section` →
  `pagination_component_section`, `empty_states_section` → `empty_state_section`.
  Read a pair top-to-bottom to see what the core component buys you.

  The page title and subtitle come from the `page_title` / `page_subtitle`
  assigns — the admin layout renders them. This page renders no header of its
  own; see the "UI & Layout Conventions" section in `AGENTS.md`.

  ## Categories

  - **Typography & feedback** — badges, alerts, stat cards, number formatter
  - **Buttons & icons** — all variants, pk_link_button
  - **Navigation** — nav tabs, collapse (daisyUI), pk_link
  - **Forms** — input, select, textarea, checkbox, simple_form
  - **Tables & lists** — raw table, `table_default`, draggable list
  - **Modals & overlays** — base modal, confirm modal
  - **Pagination** — raw join buttons, `pagination`, `load_more`
  - **Time & files** — time_ago, age_badge, file_size, file_mtime, page_status_badge
  - **Module display** — module_card
  - **Empty / loading states** — raw markup, `empty_state`

  ## Import pattern

  PhoenixKit core components are in `PhoenixKitWeb.Components.Core.*`. LiveViews
  that `use PhoenixKitWeb, :live_view` get `icon/1`, form helpers (input, select,
  textarea, checkbox, simple_form), pk_link, and draggable_list automatically.
  For anything else, import the specific module you need:

      import PhoenixKitWeb.Components.Core.FileDisplay
      import PhoenixKitWeb.Components.Core.LanguageSwitcher
      import PhoenixKitWeb.Components.Core.Modal, only: [confirm_modal: 1]
      import PhoenixKitWeb.Components.Core.NavTabs
      import PhoenixKitWeb.Components.Core.NumberFormatter
      import PhoenixKitWeb.Components.Core.StatCard, only: [stat_card: 1]
      import PhoenixKitWeb.Components.Core.TimeDisplay

  ## File organization

  The render function is a flat list of `<.x_section />` calls. Each section is a
  private function component defined below. To find or modify a section, jump to
  its `defp <name>_section/1` definition — they appear in the same order as the
  render. New sections: add a `<.your_section />` to render and define the
  matching `defp your_section/1` below.
  """
  use PhoenixKitWeb, :live_view

  require Logger

  # Note: `use PhoenixKitWeb, :live_view` already imports these core components:
  # Input, Select, Textarea, Checkbox, SimpleForm, PkLink, DraggableList,
  # FormFieldLabel, FormFieldError, Icon. The imports below add the rest.
  import PhoenixKitWeb.Components.Core.FileDisplay
  import PhoenixKitWeb.Components.Core.LanguageSwitcher
  import PhoenixKitWeb.Components.Core.Modal, only: [confirm_modal: 1]
  import PhoenixKitWeb.Components.Core.NavTabs
  import PhoenixKitWeb.Components.Core.NumberFormatter
  import PhoenixKitWeb.Components.Core.StatCard, only: [stat_card: 1]
  import PhoenixKitWeb.Components.Core.TimeDisplay

  alias PhoenixKitHelloWorld.Paths

  @valid_demo_tabs ~w(overview activity settings)

  # Sample rows for the `<.table_default>` / `<.pagination>` / `<.empty_state>`
  # sections. Plain maps — these components take whatever shape you hand them.
  @demo_people [
    %{id: 1, name: "Alice", role: "admin", status: "active"},
    %{id: 2, name: "Bob", role: "user", status: "active"},
    %{id: 3, name: "Carol", role: "user", status: "inactive"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: Gettext.gettext(PhoenixKitWeb.Gettext, "Components"),
       page_section: Gettext.gettext(PhoenixKitWeb.Gettext, "Hello World"),
       page_section_path: Paths.index(),
       page_subtitle:
         Gettext.gettext(
           PhoenixKitWeb.Gettext,
           "A live showcase of commonly-used components from PhoenixKitWeb.Components.Core.*. Copy the snippets into your own module."
         ),
       show_modal: false,
       show_confirm: false,
       counter: 0,
       active_tab: "overview",
       draggable_items: Enum.map(1..6, &%{id: &1, label: "Item #{&1}"}),
       demo_form: demo_form(),
       demo_people: @demo_people,
       languages_available: Code.ensure_loaded?(PhoenixKit.Modules.Languages)
     )}
  end

  # The `<.pagination>` showcase renders real `<.link patch>` targets pointing
  # back at this page, so clicking one round-trips through `handle_params/3`.
  # There is nothing to read from the URL here — the demo pager is display-only
  # — but the callback has to exist for the patch to resolve.
  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("open_modal", _, socket), do: {:noreply, assign(socket, :show_modal, true)}

  def handle_event("close_modal", _, socket), do: {:noreply, assign(socket, :show_modal, false)}

  def handle_event("open_confirm", _, socket), do: {:noreply, assign(socket, :show_confirm, true)}

  def handle_event("cancel_confirm", _, socket),
    do: {:noreply, assign(socket, :show_confirm, false)}

  def handle_event("confirmed", _, socket) do
    new_counter = socket.assigns.counter + 1

    {:noreply,
     socket
     |> assign(:show_confirm, false)
     |> assign(:counter, new_counter)
     |> put_flash(
       :info,
       Gettext.gettext(PhoenixKitWeb.Gettext, "Confirmed! Counter is now %{count}",
         count: new_counter
       )
     )}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in @valid_demo_tabs do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("switch_tab", _params, socket) do
    # Silently ignore unknown tab IDs — never trust client-supplied strings.
    {:noreply, socket}
  end

  def handle_event("reorder_items", %{"ordered_ids" => ids}, socket) when is_list(ids) do
    items_map = Map.new(socket.assigns.draggable_items, &{to_string(&1.id), &1})
    known_count = map_size(items_map)

    # Only accept a reorder that is exactly a permutation of known IDs.
    # Anything else (missing items, duplicates, unknown IDs) is rejected and logged.
    cond do
      length(ids) != known_count ->
        Logger.warning(
          "[ComponentsLive] reorder_items rejected: expected #{known_count} ids, got #{length(ids)}"
        )

        {:noreply, socket}

      not Enum.all?(ids, &Map.has_key?(items_map, &1)) ->
        Logger.warning(
          "[ComponentsLive] reorder_items rejected: unknown ids #{inspect(ids -- Map.keys(items_map))}"
        )

        {:noreply, socket}

      true ->
        reordered = Enum.map(ids, &items_map[&1])
        {:noreply, assign(socket, :draggable_items, reordered)}
    end
  end

  def handle_event("reorder_items", _params, socket), do: {:noreply, socket}

  def handle_event("noop", _params, socket), do: {:noreply, socket}

  # Defensive catch-all so a stray PubSub broadcast or OTP message can't
  # crash this LiveView with a FunctionClauseError. Logs at :debug so it
  # never spams in production but stays grep-able during development.
  @impl true
  def handle_info(msg, socket) do
    Logger.debug("[#{inspect(__MODULE__)}] Unhandled info: #{inspect(msg)}")
    {:noreply, socket}
  end

  # Demo form uses a plain map + to_form so we don't need a changeset/schema.
  defp demo_form do
    to_form(%{"name" => "", "email" => "", "bio" => "", "role" => "", "agree" => false})
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
      <.modals_section show_modal={@show_modal} show_confirm={@show_confirm} counter={@counter} />
      <.tables_section />
      <.pagination_section />
      <.empty_states_section />
      <.loading_states_section />

      <.section_divider label={Gettext.gettext(PhoenixKitWeb.Gettext, "PhoenixKit Core Components")} />

      <.collapsible_section />
      <.nav_tabs_section active_tab={@active_tab} />
      <.stat_card_section />
      <.number_formatter_section />
      <.time_display_section />
      <.file_display_section />
      <.language_switcher_section
        languages_available={@languages_available}
        current_locale={assigns[:current_locale]}
      />
      <.pk_links_section />
      <.form_helpers_section demo_form={@demo_form} />
      <.table_default_section people={@demo_people} />
      <.pagination_component_section />
      <.empty_state_section />
      <.draggable_list_section items={@draggable_items} />

      <.section_divider label={Gettext.gettext(PhoenixKitWeb.Gettext, "Context-dependent components")} />

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
    <.showcase_section title="Icons" description="Heroicons via the <.icon> component. Available through `use PhoenixKitWeb, :live_view` automatically.">
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
    <.showcase_section title="Badges" description="daisyUI badges for status, labels, and counts.">
      <div class="flex flex-wrap items-center gap-2">
        <span class="badge">Default</span>
        <span class="badge badge-primary">Primary</span>
        <span class="badge badge-secondary">Secondary</span>
        <span class="badge badge-accent">Accent</span>
        <span class="badge badge-success">Success</span>
        <span class="badge badge-warning">Warning</span>
        <span class="badge badge-error">Error</span>
        <span class="badge badge-info">Info</span>
        <span class="badge badge-ghost">Ghost</span>
        <span class="badge badge-outline">Outline</span>
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
      </:snippet>
    </.showcase_section>
    """
  end

  defp buttons_section(assigns) do
    ~H"""
    <.showcase_section title="Buttons" description="daisyUI buttons — various colors, sizes, and states.">
      <div class="flex flex-wrap items-center gap-2">
        <button class="btn btn-primary">Primary</button>
        <button class="btn btn-secondary">Secondary</button>
        <button class="btn btn-accent">Accent</button>
        <button class="btn btn-ghost">Ghost</button>
        <button class="btn btn-outline">Outline</button>
        <button class="btn btn-primary" disabled>Disabled</button>
      </div>
      <div class="flex flex-wrap items-center gap-2 mt-2">
        <button class="btn btn-xs btn-primary">xs</button>
        <button class="btn btn-sm btn-primary">sm</button>
        <button class="btn btn-primary">md</button>
        <button class="btn btn-lg btn-primary">lg</button>
      </div>
      <div class="flex flex-wrap items-center gap-2 mt-2">
        <button class="btn btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" /> With icon
        </button>
        <button class="btn btn-ghost btn-sm btn-square" title="Icon-only">
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
    <.showcase_section title="Alerts" description="Inline messages and notices.">
      <div class="flex flex-col gap-2">
        <div class="alert alert-info">
          <.icon name="hero-information-circle" class="w-5 h-5" />
          <span>Heads up — this is an info message.</span>
        </div>
        <div class="alert alert-success">
          <.icon name="hero-check-circle" class="w-5 h-5" />
          <span>Nice — you did the thing.</span>
        </div>
        <div class="alert alert-warning">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <span>Careful — double-check before proceeding.</span>
        </div>
        <div class="alert alert-error">
          <.icon name="hero-x-circle" class="w-5 h-5" />
          <span>Something went wrong.</span>
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
    <.showcase_section title="Stat cards" description="Summary cards showing a metric with an icon and label.">
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex items-center gap-3">
              <div class="p-2 bg-primary/10 rounded-lg">
                <.icon name="hero-users" class="w-6 h-6 text-primary" />
              </div>
              <div>
                <p class="text-xs text-base-content/60">Users</p>
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
                <p class="text-xs text-base-content/60">Revenue</p>
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
                <p class="text-xs text-base-content/60">Orders</p>
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
    <.showcase_section title="Form inputs" description="daisyUI form controls — text, textarea, select, checkbox.">
      <.form for={%{}} phx-change="noop" phx-submit="noop" class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="fieldset">
          <label class="label"><span class="fieldset-legend">Text input</span></label>
          <input type="text" placeholder="Type here" class="input input-sm" />
        </div>
        <div class="fieldset">
          <label class="label"><span class="fieldset-legend">Select</span></label>
          <label class="select select-sm">
            <select>
              <option>Option A</option>
              <option>Option B</option>
              <option>Option C</option>
            </select>
          </label>
        </div>
        <div class="fieldset md:col-span-2">
          <label class="label"><span class="fieldset-legend">Textarea</span></label>
          <textarea class="textarea" rows="3" placeholder="Multi-line..."></textarea>
        </div>
        <div class="fieldset">
          <label class="label cursor-pointer justify-start gap-2">
            <input type="checkbox" class="checkbox checkbox-primary checkbox-sm" checked />
            <span class="fieldset-legend">Checkbox</span>
          </label>
        </div>
        <div class="fieldset">
          <label class="label cursor-pointer justify-start gap-2">
            <input type="radio" name="radio-demo" class="radio radio-primary radio-sm" checked />
            <span class="fieldset-legend">Radio</span>
          </label>
        </div>
      </.form>
      <:snippet>
        <code>{~s|<input type="text" class="input input-sm" />|}</code>
        <code>{~s|<label class="select select-sm"><select>...</select></label>|}</code>
        <p class="text-xs text-base-content/50">
          Note: daisyUI 5 requires the wrapper <code>&lt;label class="select"&gt;</code> pattern around <code>&lt;select&gt;</code>.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:show_modal, :boolean, required: true)
  attr(:show_confirm, :boolean, required: true)
  attr(:counter, :integer, required: true)

  defp modals_section(assigns) do
    ~H"""
    <.showcase_section title="Modals" description="Dialog windows for focused interactions. PhoenixKit provides `<.confirm_modal>` for destructive actions.">
      <div class="flex flex-wrap gap-2">
        <button type="button" phx-click="open_modal" class="btn btn-primary btn-sm">
          Open modal
        </button>
        <button type="button" phx-click="open_confirm" class="btn btn-error btn-sm">
          Open confirm (counter: {@counter})
        </button>
      </div>

      <%!-- Base modal using daisyUI dialog --%>
      <dialog class={["modal", @show_modal && "modal-open"]}>
        <div class="modal-box">
          <h3 class="font-bold text-lg">Hello!</h3>
          <p class="py-4">This is a basic daisyUI modal. Close it to continue.</p>
          <div class="modal-action">
            <button type="button" phx-click="close_modal" class="btn btn-sm">
              Close
            </button>
          </div>
        </div>
        <div class="modal-backdrop" phx-click="close_modal"></div>
      </dialog>

      <%!-- PhoenixKit confirm_modal --%>
      <.confirm_modal
        show={@show_confirm}
        title="Confirm action"
        prompt="Are you sure you want to increment the counter?"
        confirm_text="Yes, increment"
        cancel_text="Cancel"
        on_confirm="confirmed"
        on_cancel="cancel_confirm"
      />

      <:snippet>
        <code>{~s|<dialog class={["modal", @show && "modal-open"]}>...</dialog>|}</code>
        <code>{~s|<.confirm_modal show={@show} title="..." prompt="..." on_confirm="..." on_cancel="..." />|}</code>
        <p class="text-xs text-base-content/50">
          Import with: <code>{~s|import PhoenixKitWeb.Components.Core.Modal, only: [confirm_modal: 1]|}</code>
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp tables_section(assigns) do
    ~H"""
    <.showcase_section title="Tables" description="Standard daisyUI table. PhoenixKit also provides `TableDefault` for responsive tables with mobile card fallback.">
      <div class="overflow-x-auto">
        <table class="table table-sm table-zebra">
          <thead>
            <tr>
              <th>Name</th>
              <th>Role</th>
              <th>Status</th>
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
          Prefer the wrapped counterpart below the divider — <code>&lt;.table_default&gt;</code>
          adds the scroll wrapper, a toolbar, and a mobile card view.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp pagination_section(assigns) do
    ~H"""
    <.showcase_section title="Pagination" description="Page navigation using daisyUI joined buttons (the same pattern the activity feed uses).">
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
          Prefer the wrapped counterpart below the divider — <code>&lt;.pagination&gt;</code>
          builds the page URLs for you and preserves the existing query string.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp empty_states_section(assigns) do
    ~H"""
    <.showcase_section title="Empty states" description="What to show when there's no data.">
      <div class="text-center py-8 text-base-content/60 border border-dashed border-base-300 rounded-lg">
        <.icon name="hero-inbox" class="w-12 h-12 mx-auto mb-2 opacity-50" />
        <p class="font-semibold">Nothing here yet</p>
        <p class="text-xs mt-1">Create your first item to get started.</p>
        <button class="btn btn-primary btn-sm mt-4">
          <.icon name="hero-plus" class="w-4 h-4" /> Create
        </button>
      </div>
      <:snippet>
        <code>{~s|<div class="text-center py-8"><.icon name="hero-inbox" class="w-12 h-12 mx-auto" />...</div>|}</code>
        <p class="text-xs text-base-content/50">
          Prefer the wrapped counterpart below the divider — <code>&lt;.empty_state&gt;</code>
          ships three variants and keeps every list view's empty panel identical.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp loading_states_section(assigns) do
    ~H"""
    <.showcase_section title="Loading states" description="Spinners and skeleton placeholders.">
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

  defp collapsible_section(assigns) do
    ~H"""
    <.showcase_section title="Collapsible sections (daisyUI collapse)" description="Expandable content sections using daisyUI's native collapse component — works out of the box with no custom CSS.">
      <div class="flex flex-col gap-2">
        <div tabindex="0" class="collapse collapse-arrow bg-base-100 border border-base-300">
          <div class="collapse-title font-medium">What is PhoenixKit?</div>
          <div class="collapse-content text-sm">
            <p>PhoenixKit is a modular SaaS framework for Elixir/Phoenix apps — auth, admin dashboard, activity logging, role-based access, and more.</p>
          </div>
        </div>
        <div tabindex="0" class="collapse collapse-arrow bg-base-100 border border-base-300">
          <div class="collapse-title font-medium">How do I add a module?</div>
          <div class="collapse-content text-sm">
            <p>
              Implement the <code>PhoenixKit.Module</code> behaviour and list your module as a dep. Auto-discovery handles the rest.
            </p>
          </div>
        </div>
        <div tabindex="0" class="collapse collapse-arrow bg-base-100 border border-base-300">
          <div class="collapse-title font-medium">Click to expand</div>
          <div class="collapse-content text-sm">
            <p>This content is hidden until you click the header.</p>
          </div>
        </div>
      </div>
      <:snippet>
        <code>{~s|<div tabindex="0" class="collapse collapse-arrow bg-base-100 border">|}</code>
        <code>{~s|  <div class="collapse-title">Title</div>|}</code>
        <code>{~s|  <div class="collapse-content">Content</div>|}</code>
        <code>{~s|</div>|}</code>
        <p class="text-xs text-base-content/50">
          PhoenixKit also ships <code>&lt;.accordion&gt;</code> (<code>PhoenixKitWeb.Components.Core.Accordion</code>) on this same native-details pattern, with an optional server-tracked mode (<code>open</code> + <code>toggle_event</code>) so a section the user opened survives LiveView re-renders.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:active_tab, :string, required: true)

  defp nav_tabs_section(assigns) do
    ~H"""
    <.showcase_section title="Nav tabs" description="Horizontal tab navigation. Works with routes (path) or events (on_change).">
      <.nav_tabs
        active_tab={@active_tab}
        on_change="switch_tab"
        tabs={[
          %{id: "overview", label: "Overview", icon: "hero-home"},
          %{id: "activity", label: "Activity", icon: "hero-clock"},
          %{id: "settings", label: "Settings", icon: "hero-cog-6-tooth"}
        ]}
      />
      <div class="mt-4 p-4 bg-base-200 rounded text-sm">
        Active tab: <strong>{@active_tab}</strong>
      </div>
      <:snippet>
        <code>{~s|<.nav_tabs active_tab={@tab} on_change="switch_tab" tabs={[%{id: "x", label: "X"}]} />|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  defp stat_card_section(assigns) do
    ~H"""
    <.showcase_section title="Stat card" description="PhoenixKit's stat_card with color variants and icon slot.">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
        <.stat_card value={42} title="Users" subtitle="Total registered" color="primary">
          <:icon><.icon name="hero-users" class="w-6 h-6" /></:icon>
        </.stat_card>
        <.stat_card
          value={17}
          title="Active sessions"
          subtitle="Last 5 minutes"
          color="success"
        >
          <:icon><.icon name="hero-signal" class="w-6 h-6" /></:icon>
        </.stat_card>
        <.stat_card
          value={3}
          title="Pending issues"
          subtitle="Require attention"
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
    <.showcase_section title="Number formatter" description="Format numbers as grouped (1,234,567) or short (1.2M).">
      <div class="flex flex-col gap-2 text-sm">
        <div>Grouped: <.formatted_number number={1_234_567} class="font-mono font-bold" /></div>
        <div>Short: <.formatted_number number={1_234_567} format={:short} class="font-mono font-bold" /></div>
        <div>Grouped: <.formatted_number number={89} class="font-mono font-bold" /></div>
        <div>Short: <.formatted_number number={2_500} format={:short} class="font-mono font-bold" /></div>
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
    <.showcase_section title="Time display" description="time_ago (with JS auto-update), age_badge, and duration_display helpers.">
      <div class="flex flex-wrap items-center gap-4 text-sm">
        <div>
          <span class="text-base-content/60">Just now:</span>
          <.time_ago datetime={DateTime.utc_now()} class="font-mono" />
        </div>
        <div>
          <span class="text-base-content/60">5 min ago:</span>
          <.time_ago
            datetime={DateTime.add(DateTime.utc_now(), -300, :second)}
            class="font-mono"
          />
        </div>
        <div>
          <span class="text-base-content/60">3 days ago:</span>
          <.time_ago
            datetime={DateTime.add(DateTime.utc_now(), -3, :day)}
            class="font-mono"
          />
        </div>
      </div>
      <div class="flex flex-wrap items-center gap-2 mt-3">
        <span class="text-sm text-base-content/60">Age badges:</span>
        <.age_badge days={0} />
        <.age_badge days={3} />
        <.age_badge days={15} />
        <.age_badge days={45} />
      </div>
      <:snippet>
        <code>{~s|<.time_ago datetime={@record.inserted_at} />|}</code>
        <code>{~s|<.age_badge days={5} />|}</code>
        <p class="text-xs text-base-content/50">
          <code>time_ago</code> uses the <code>TimeAgo</code> JS hook for live updates.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp file_display_section(assigns) do
    ~H"""
    <.showcase_section title="File display" description="Pre-built helpers for file size, modification time, and page status.">
      <div class="flex flex-col gap-3 text-sm">
        <div class="flex items-center gap-3">
          <span class="text-base-content/60">File sizes:</span>
          <.file_size bytes={512} class="badge badge-ghost badge-sm" />
          <.file_size bytes={2_048} class="badge badge-ghost badge-sm" />
          <.file_size bytes={1_048_576} class="badge badge-ghost badge-sm" />
          <.file_size bytes={52_428_800} class="badge badge-ghost badge-sm" />
        </div>
        <div class="flex items-center gap-3">
          <span class="text-base-content/60">Page status:</span>
          <.page_status_badge status="published" />
          <.page_status_badge status="draft" />
          <.page_status_badge status="archived" />
        </div>
      </div>
      <:snippet>
        <code>{~s|<.file_size bytes={1_048_576} />  # → 1.0 MB|}</code>
        <code>{~s|<.page_status_badge status="published" />|}</code>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:languages_available, :boolean, required: true)
  attr(:current_locale, :string, default: nil)

  defp language_switcher_section(assigns) do
    ~H"""
    <.showcase_section title="Language switcher (3 variants)" description="Locale picker backed by the Languages module. Dropdown, button group, and inline variants. Requires the Languages module to be configured in the host app.">
      <%= if @languages_available do %>
        <div class="flex flex-col gap-4">
          <div>
            <p class="text-xs text-base-content/60 mb-2">
              <strong>Dropdown</strong> — compact, good for headers and navbars. Auto-groups by continent when >7 languages:
            </p>
            <.language_switcher_dropdown current_locale={@current_locale} />
          </div>

          <div>
            <p class="text-xs text-base-content/60 mb-2">
              <strong>Buttons</strong> — visible flag/code buttons. Pass <code>class="flex-wrap"</code> to wrap onto multiple lines with many languages:
            </p>
            <.language_switcher_buttons
              current_locale={@current_locale}
              class="flex-wrap"
            />
          </div>

          <div>
            <p class="text-xs text-base-content/60 mb-2">
              <strong>Inline</strong> — plain text links separated by dividers, good for footers:
            </p>
            <.language_switcher_inline current_locale={@current_locale} class="flex-wrap" />
          </div>
        </div>
      <% else %>
        <div class="alert alert-warning">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <div>
            <p class="font-semibold">Languages module not loaded</p>
            <p class="text-xs">
              The <code>PhoenixKit.Modules.Languages</code>
              module is not configured in the host app. The three language switcher variants cannot be demonstrated without it.
            </p>
          </div>
        </div>
      <% end %>
      <:snippet>
        <code>{~s|<.language_switcher_dropdown current_locale={@current_locale} />|}</code>
        <code>{~s|<.language_switcher_buttons current_locale={@current_locale} class="flex-wrap" />|}</code>
        <code>{~s|<.language_switcher_inline current_locale={@current_locale} class="flex-wrap" />|}</code>
        <p class="text-xs text-base-content/50">
          All three variants auto-fetch the enabled locales from <code>PhoenixKit.Modules.Languages</code>. Dropdown auto-groups by continent when there are more than 7 languages (configurable via <code>continent_threshold</code>). Pass <code>group_by_continent={false}</code> to force a flat list. Both buttons and inline accept a <code>class</code> prop that merges into the internal flex container — use <code>"flex-wrap"</code> to wrap items onto multiple lines.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp pk_links_section(assigns) do
    assigns = assign(assigns, :self_path, "/admin/hello-world/components")

    ~H"""
    <.showcase_section title="PhoenixKit links" description="Prefix-aware link components — they automatically prepend the configured PhoenixKit URL prefix. The links below all point back to this Components page, so clicking them is harmless.">
      <div class="flex flex-wrap items-center gap-2">
        <.pk_link navigate={@self_path} class="link link-primary">
          Regular link
        </.pk_link>
        <.pk_link_button navigate={@self_path} variant="primary">
          Primary button
        </.pk_link_button>
        <.pk_link_button navigate={@self_path} variant="outline">
          Outline button
        </.pk_link_button>
        <.pk_link_button navigate={@self_path} variant="ghost">
          Ghost button
        </.pk_link_button>
        <.pk_link_button navigate={@self_path} variant="secondary">
          Secondary
        </.pk_link_button>
      </div>
      <:snippet>
        <code>{~s|<.pk_link navigate="/dashboard">Dashboard</.pk_link>|}</code>
        <code>{~s|<.pk_link_button navigate="/admin/users" variant="primary">Manage</.pk_link_button>|}</code>
        <p class="text-xs text-base-content/50">
          Always prefer these over hardcoded paths — they respect the configurable PhoenixKit prefix (e.g. when the parent app mounts at <code>/admin</code> vs <code>/backend</code>) and the current locale. Accepted props: <code>navigate</code>, <code>patch</code>, <code>href</code> — all must start with <code>/</code>.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:demo_form, :any, required: true)

  defp form_helpers_section(assigns) do
    ~H"""
    <.showcase_section title="Form helpers (simple_form + input + select + textarea + checkbox)" description="PhoenixKit wraps Phoenix.HTML.FormField in themed components. Each form primitive has its own component.">
      <.simple_form for={@demo_form} phx-change="noop" phx-submit="noop">
        <.input field={@demo_form[:name]} type="text" label="Name" placeholder="Alice" />
        <.input field={@demo_form[:email]} type="email" label="Email" />
        <.select
          field={@demo_form[:role]}
          label="Role"
          options={[{"Admin", "admin"}, {"User", "user"}, {"Guest", "guest"}]}
          prompt="Choose one"
        />
        <.textarea field={@demo_form[:bio]} label="Bio" rows="3" />
        <.checkbox field={@demo_form[:agree]} label="I agree to the terms" />
        <:actions>
          <button type="submit" class="btn btn-primary btn-sm">Save</button>
        </:actions>
      </.simple_form>
      <:snippet>
        <code>{~s|<.simple_form for={@form} phx-submit="save">|}</code>
        <code>{~s|  <.input field={@form[:email]} type="email" label="Email" />|}</code>
        <code>{~s|  <.select field={@form[:role]} options={[{"A", "a"}]} />|}</code>
        <code>{~s|  <.textarea field={@form[:bio]} label="Bio" />|}</code>
        <code>{~s|  <.checkbox field={@form[:agree]} label="Agree" />|}</code>
        <code>{~s|  <:actions><button>Save</button></:actions>|}</code>
        <code>{~s|</.simple_form>|}</code>
        <p class="text-xs text-base-content/50">
          <code>&lt;.input&gt;</code> handles HTML input types (text, email, number, date...). Use <code>&lt;.select&gt;</code>, <code>&lt;.textarea&gt;</code>, <code>&lt;.checkbox&gt;</code> for those primitives.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:people, :list, required: true)

  defp table_default_section(assigns) do
    ~H"""
    <.showcase_section
      title="Table — core table_default"
      description="The wrapped counterpart to the raw daisyUI table above. Same rows, but the component adds the scroll wrapper, a toolbar, and a mobile card view driven by `card_title` / `card_fields`."
    >
      <.table_default
        id="demo-people-table"
        toggleable
        variant="zebra"
        size="sm"
        items={@people}
        card_title={& &1.name}
        card_fields={&[%{label: "Role", value: &1.role}, %{label: "Status", value: &1.status}]}
      >
        <:toolbar_title>
          <span class="text-sm text-base-content/60">{length(@people)} people</span>
        </:toolbar_title>
        <.table_default_header>
          <.table_default_row>
            <.table_default_header_cell>Name</.table_default_header_cell>
            <.table_default_header_cell>Role</.table_default_header_cell>
            <.table_default_header_cell>Status</.table_default_header_cell>
          </.table_default_row>
        </.table_default_header>
        <.table_default_body>
          <.table_default_row :for={person <- @people}>
            <.table_default_cell>{person.name}</.table_default_cell>
            <.table_default_cell>
              <span class="badge badge-ghost badge-xs">{person.role}</span>
            </.table_default_cell>
            <.table_default_cell>
              <span class={[
                "badge badge-xs",
                person.status == "active" && "badge-success",
                person.status != "active" && "badge-error"
              ]}>
                {person.status}
              </span>
            </.table_default_cell>
          </.table_default_row>
        </.table_default_body>
      </.table_default>
      <:snippet>
        <code>{~s|<.table_default id="people" toggleable items={@people}|}</code>
        <code>{~s|  card_title={& &1.name} card_fields={&[%{label: "Role", value: &1.role}]}>|}</code>
        <code>{~s|  <.table_default_header><.table_default_row>|}</code>
        <code>{~s|    <.table_default_header_cell>Name</.table_default_header_cell>|}</code>
        <code>{~s|  </.table_default_row></.table_default_header>|}</code>
        <code>{~s|  <.table_default_body>|}</code>
        <code>{~s|    <.table_default_row :for={p <- @people}>|}</code>
        <code>{~s|      <.table_default_cell>{p.name}</.table_default_cell>|}</code>
        <code>{~s|    </.table_default_row>|}</code>
        <code>{~s|  </.table_default_body>|}</code>
        <code>{~s|</.table_default>|}</code>
        <p class="text-xs text-base-content/50">
          Auto-imported by <code>{~s|use PhoenixKitWeb, :live_view|}</code>. Drop <code>toggleable</code>/<code>items</code>
          for a plain table. The desktop card/table toggle persists in localStorage.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp pagination_component_section(assigns) do
    assigns = assign(assigns, :self_path, Paths.components())

    ~H"""
    <.showcase_section
      title="Pagination — core pagination"
      description="The wrapped counterpart to the hand-rolled join buttons above. Builds the page URLs itself from `base_path` + `params`, preserving your existing query string. The links below patch back to this page, so clicking them is harmless."
    >
      <.pagination current_page={2} total_pages={5} base_path={@self_path} params={%{"demo" => "1"}} />

      <p class="text-xs text-base-content/60 mt-2">
        Load-more lists (streams, infinite scroll) use
        <code>&lt;.load_more&gt;</code>
        from the same module instead — see the Events page.
      </p>
      <:snippet>
        <code>{~s|<.pagination current_page={@page} total_pages={@total_pages}|}</code>
        <code>{~s|  base_path={Paths.items()} params={%{"search" => @search}} />|}</code>
        <code>{~s|<.load_more id="items" loaded={@loaded} total={@total} infinite />|}</code>
        <p class="text-xs text-base-content/50">
          Both are in <code>PhoenixKitWeb.Components.Core.Pagination</code>, auto-imported by
          <code>{~s|use PhoenixKitWeb, :live_view|}</code>. <code>&lt;.pagination&gt;</code>
          renders <code>patch</code> links, so the page needs a <code>handle_params/3</code>.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp empty_state_section(assigns) do
    ~H"""
    <.showcase_section
      title="Empty state — core empty_state"
      description="The wrapped counterpart to the hand-rolled empty panel above. Three variants share one attr shape: `compact` (default, no chrome), `card`, and `featured` (dashed-border first-run hero)."
    >
      <div class="flex flex-col gap-4">
        <div>
          <p class="text-xs text-base-content/60 mb-1">
            <strong>compact</strong> — "no rows match this filter", inside an existing section:
          </p>
          <.empty_state icon="hero-funnel" title="No items match this filter." class="py-8" />
        </div>

        <div>
          <p class="text-xs text-base-content/60 mb-1">
            <strong>card</strong> — stands alone in the page body:
          </p>
          <.empty_state
            variant="card"
            icon="hero-inbox"
            title="Nothing here yet"
            description="Items you create will show up in this list."
          />
        </div>

        <div>
          <p class="text-xs text-base-content/60 mb-1">
            <strong>featured</strong> — first-run "here's how to get started" state, with a CTA:
          </p>
          <.empty_state
            variant="featured"
            icon="hero-sparkles"
            title="No items yet"
            description="Create your first item to see it appear here."
          >
            <button type="button" phx-click="noop" class="btn btn-primary">
              <.icon name="hero-plus" class="w-5 h-5 mr-2" /> Create first item
            </button>
          </.empty_state>
        </div>
      </div>
      <:snippet>
        <code>{~s|<.empty_state icon="hero-funnel" title="No items match this filter." />|}</code>
        <code>{~s|<.empty_state variant="card" icon="hero-inbox" title="..." description="..." />|}</code>
        <code>{~s|<.empty_state variant="featured" icon="hero-sparkles" title="..." description="...">|}</code>
        <code>{~s|  <button class="btn btn-primary">Create first item</button>|}</code>
        <code>{~s|</.empty_state>|}</code>
        <p class="text-xs text-base-content/50">
          Auto-imported by <code>{~s|use PhoenixKitWeb, :live_view|}</code>. LiveViews that
          <code>{~s|use Phoenix.LiveView|}</code>
          directly need <code>{~s|import PhoenixKitWeb.Components.Core.EmptyState|}</code>
          — the Events and Notifications pages do exactly that.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  attr(:items, :list, required: true)

  defp draggable_list_section(assigns) do
    ~H"""
    <.showcase_section title="Draggable list" description="Reorderable list via SortableJS. Fires an event with the new order.">
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
      <p class="text-xs text-base-content/60 mt-2">
        Drag items above to reorder. The list state is persisted in LiveView assigns.
      </p>
      <:snippet>
        <code>{~s|<.draggable_list id="..." items={@items} on_reorder="reorder" layout={:list} cols={1}>|}</code>
        <code>{~s|  <:item :let={item}>...</:item>|}</code>
        <code>{~s|</.draggable_list>|}</code>
        <p class="text-xs text-base-content/50">
          Event receives {~s|%{"ordered_ids" => [...]}|} — requires SortableJS hook (loaded by PhoenixKit).
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp context_components_section(assigns) do
    ~H"""
    <.showcase_section
      title="Components not shown here"
      description="These components require specific runtime context (a user, a configured module, an integration, etc.) that doesn't fit a generic template. They exist in PhoenixKit core and are ready to use in the right contexts."
    >
      <dl class="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-3 text-sm">
        <div>
          <dt class="font-semibold">
            <code class="text-xs bg-base-200 px-1 rounded">&lt;.theme_controller/&gt;</code>
          </dt>
          <dd class="text-xs text-base-content/60">
            daisyUI theme dropdown. Requires <code>PhoenixKit.ThemeConfig</code>.
          </dd>
        </div>
        <div>
          <dt class="font-semibold">
            <code class="text-xs bg-base-200 px-1 rounded">&lt;.user_avatar/&gt;, &lt;.primary_role/&gt;</code>
          </dt>
          <dd class="text-xs text-base-content/60">
            User-facing helpers. Need a user struct with preloaded roles. <code>user_avatar</code> uses Storage for uploaded avatars.
          </dd>
        </div>
        <div>
          <dt class="font-semibold">
            <code class="text-xs bg-base-200 px-1 rounded">&lt;.integration_picker/&gt;</code>
          </dt>
          <dd class="text-xs text-base-content/60">
            Picker for OAuth/API integrations. Requires the Integrations module.
          </dd>
        </div>
        <div>
          <dt class="font-semibold">
            <code class="text-xs bg-base-200 px-1 rounded">&lt;.file_upload/&gt;</code>
          </dt>
          <dd class="text-xs text-base-content/60">
            LiveView file upload. Needs <code>allow_upload/3</code> configured in mount.
          </dd>
        </div>
        <div>
          <dt class="font-semibold">
            <code class="text-xs bg-base-200 px-1 rounded">&lt;.markdown/&gt;, &lt;.markdown_editor/&gt;</code>
          </dt>
          <dd class="text-xs text-base-content/60">
            Markdown rendering and live editor. Require <code>Earmark</code> (available via PhoenixKit).
          </dd>
        </div>
        <div>
          <dt class="font-semibold">
            <code class="text-xs bg-base-200 px-1 rounded">&lt;.event_timeline_item/&gt;</code>
          </dt>
          <dd class="text-xs text-base-content/60">
            Email event timeline item. Specific to the Emails module's event tracking.
          </dd>
        </div>
        <div>
          <dt class="font-semibold">
            <code class="text-xs bg-base-200 px-1 rounded">&lt;.oauth_provider_*/&gt;</code>
          </dt>
          <dd class="text-xs text-base-content/60">
            OAuth provider credentials UI. Used in admin settings pages.
          </dd>
        </div>
        <div>
          <dt class="font-semibold">
            <code class="text-xs bg-base-200 px-1 rounded">&lt;.aws_credentials_verify/&gt;, &lt;.aws_region_select/&gt;</code>
          </dt>
          <dd class="text-xs text-base-content/60">
            AWS-specific credentials + region picker. Used in the Email module config.
          </dd>
        </div>
        <div>
          <dt class="font-semibold">
            <code class="text-xs bg-base-200 px-1 rounded">&lt;.module_card/&gt;</code>
          </dt>
          <dd class="text-xs text-base-content/60">
            Card used on the admin Modules page to toggle PhoenixKit modules. Not typically reused in custom module UIs.
          </dd>
        </div>
      </dl>
      <:snippet>
        <p class="text-xs text-base-content/50">
          Browse <code>phoenix_kit/lib/phoenix_kit_web/components/core/</code> for all 52+ components including email, OAuth, storage, admin, and more.
        </p>
      </:snippet>
    </.showcase_section>
    """
  end

  defp footer_link(assigns) do
    ~H"""
    <div class="text-xs text-base-content/50 text-center pt-4 border-t">
      See <code class="bg-base-200 px-1 rounded">phoenix_kit/lib/phoenix_kit_web/components/core/</code>
      for the complete source. Every component has <code>attr</code> declarations you can reference for available options.
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
        <details :if={@snippet != []} class="mt-4">
          <summary class="text-xs text-base-content/60 cursor-pointer">Show snippet</summary>
          <div class="bg-base-200 p-3 rounded mt-2 text-xs flex flex-col gap-1 font-mono overflow-x-auto">
            {render_slot(@snippet)}
          </div>
        </details>
      </div>
    </section>
    """
  end
end

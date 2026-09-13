# Section-decomposition pattern

How `ComponentsLive` splits a large `render/1` into per-section function components.

Rules for this live in [AGENTS.md](../../AGENTS.md) → Conventions.

`ComponentsLive` demonstrates a pattern worth copying for any LiveView whose render function would otherwise grow past ~150 lines: **flat dispatch from `render/1` to per-section private function components**.

```elixir
def render(assigns) do
  ~H"""
  <div class="...">
    <.icons_section />
    <.badges_section />
    <.modals_section show_modal={@show_modal} show_confirm={@show_confirm} counter={@counter} />
    <.section_divider label="..." />
    <.draggable_list_section items={@draggable_items} />
  </div>
  """
end

defp icons_section(assigns), do: ~H"""<.showcase_section title="Icons" ...>...</.showcase_section>"""
defp badges_section(assigns), do: ~H"""<.showcase_section title="Badges" ...>...</.showcase_section>"""

attr(:show_modal, :boolean, required: true)
attr(:show_confirm, :boolean, required: true)
attr(:counter, :integer, required: true)
defp modals_section(assigns), do: ~H"""..."""
```

Rules:

- **One function per section, in render order.** Lets you jump to a section by name and modify it without scrolling 700 lines of HEEX.
- **Sections that need LV state declare `attr` for each value.** Don't pass the whole `assigns` — be explicit about what the section reads.
- **Stateless sections take no attrs** — they're called as `<.icons_section />`.
- **Stay in one file.** The "single-file showcase" value of a template page (everything visible at once when copy-pasting from the source) is preserved by keeping all sections in the same module. The only thing the decomposition changes is per-function navigability.
- **Small inline helpers like `<.section_divider label="...">` belong with the sections** — they're part of the same dispatch shape. Note there is deliberately no `<.page_header>` helper: the page title comes from the `page_title` assign and is rendered once by the admin layout (see "UI & Layout Conventions").

Total source lines grow, because each section gains function-component plumbing; per-function size drops from one 700-line render to ~30 (render) and ~25–50 (each section). The win is in maintainability, not in source-line count.

In `ComponentsLive` the sections are also deliberately paired across the divider — a raw daisyUI section, then the core component that wraps it (`form_inputs`/`form_helpers`, `tables`/`table_default`, `pagination`/`pagination_component`, `empty_states`/`empty_state`) — so a reader can see the difference between hand-rolled markup and the core component.

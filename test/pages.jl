# CATServe's DOM vocabulary, in one place: the bits of markup the tests
# address, named so the tests read as user actions.

using Playwright

# The <option> order comes from iterating a Dict, so it is not stable -- always
# pick the dataset by value. `set_value!` refuses a <select>, so set the value
# and fire the listener ourselves.
function select_dataset!(page, value)
    evaluate(
        page,
        """(v) => {
          const s = document.querySelector('select[name=test]');
          s.value = v;
          s.dispatchEvent(new Event('change', {bubbles: true}));
        }""",
        value,
    )
    expect(locator(page, "select[name=test]"); to_have_value = value)
    return
end

inspect_button(page) = locator(page, "button[formaction='/inspect']")
update_button(page) = locator(page, "button[type=submit]")
# The index form has a second submit button, the one going to /inspect.
ok_button(page) = locator(page, "button[type=submit]:not([formaction])")

# 98.css hides the native checkbox and radio (`opacity: 0; position: fixed`)
# and draws the control on the label instead, so a click has to go to the
# label; the input itself is only good for reading state.
item_checkbox(page, item) = locator(page, "#item-$item")
outcome_radio(page, item, outcome) = locator(page, "#item-$item-$outcome")
toggle_item!(page, item) = click!(locator(page, "label[for=item-$item]"))
choose_outcome!(page, item, outcome) =
    click!(locator(page, "label[for=item-$item-$outcome]"))

# The only hx-get links on the inspect items page are the per-item previews.
preview_link(page, item) = nth(locator(page, "a[hx-get]"; strict = false), item)

outcomes_tab(page) = locator(page, "a[href*='/inspect/outcomes']")

# The two submit buttons the CAT sends for a bare-string question. "Answer" is
# scored correct, anything else incorrect.
answer_button(page) = locator(page, "#response input[name=action][value=Answer]")
dont_know_button(page) =
    locator(page, """#response input[name=action][value="I don't know"]""")

summary_tab(page, label) = locator(page, "menu[role=tablist] a[href='#$label']")
summary_panel(page, name) = locator(page, "div[name=$name]")

"""
    abilities(text) -> Vector{Float64}

Every number in the summary's `Ability: …` line. The estimate is a scalar for a
unidimensional bank and a vector for a MIRT one, so read whatever is there.
"""
function abilities(text::AbstractString)
    m = match(r"Ability:\s*(.*)", text)
    m === nothing && return Float64[]
    return [
        parse(Float64, x.match) for
        x in eachmatch(r"[-+]?\d+\.?\d*(?:[eE][-+]?\d+)?", m.captures[1])
    ]
end

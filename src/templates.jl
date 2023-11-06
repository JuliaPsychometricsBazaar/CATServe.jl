const validate_choose_exact_snippet = @htl("""
<script>
addEventListener("load", (event) => {
  let forms = document.querySelectorAll("form");
  for (let form of forms) {
    form.addEventListener("htmx:validation:validate", (event) => {
      
    })
  }
});
</script>
""")

const restart_on_disconnect_snippet = @htl("""
<script>
htmx.on(
  "htmx:wsClose",
  function(evt) {
    if (!evt.detail.event.wasClean) {
      location.reload();
    }
  }
);
</script>
""")

# XXX doctype
page_base(title, body, extra_heads=[]) =  @htl("""
<html>
  <head>
    <title>$(title)</title>
    <link rel="stylesheet" href="https://unpkg.com/98.css" />
    <script src="https://unpkg.com/htmx.org@1.9.4"></script>
    <script src="https://unpkg.com/htmx.org@1.9.4/dist/ext/ws.js"></script>
    <script src="https://unpkg.com/alpinejs@3.13.2" defer></script>
    <style>
    .mt-1 {
      margin-top: 1em;
    }
    .min-h-5 {
      min-height: 5em;
    }
    </style>
    $(validate_choose_exact_snippet)
    $((extra_head for extra_head in extra_heads))
  </head>
  <body>
    $(body)
  </body>
</html>
""")

window(title, body, width="250px") = @htl("""
  <div class="window" style="margin: 32px; width: $(width)">
    <div class="title-bar">
      <div class="title-bar-text">
        $(title)
      </div>

      <div class="title-bar-controls">
        <button aria-label="Minimize"></button>
        <button aria-label="Maximize"></button>
        <button aria-label="Close"></button>
      </div>
    </div>
    <div class="window-body">
      $(body)
    </div>
  </div>
""")

option(opt) = @htl("""
  <option value="$(opt.value)">$(opt.name)</option>
""")

index_tmpl() = page_base(
  "Computer-Adaptive Test Demo Configuration",
  window(
    "Computer-Adaptive Test Demo Configuration",
    @htl("""
      <form name="catconfig" action="/test" method="get" x-data="{f: {}}">
        <fieldset>
          <legend>Test selection</legend>
          <select name="test">
            <optgroup label="Synthetic">
              <option>Guassian generator</option>
              <option>Clumpy generator</option>
            </optgroup>
            <optgroup label="Datasets">
              $( render_options(datasets) )
            </optgroup>
          </select>
        </fieldset>
        <fieldset class="mt-1">
          <legend>CAT Procedure</legend>
          <fieldset>
            <legend>Ability estimation</legend>
            $( render_stacked(ability_estimation_distribution) )
            $( render_stacked(ability_estimation) )
            $( render_stacked(form.lower_bound) )
            $( render_stacked(form.upper_bound) )
            $( render_stacked(integrators) )
            <div class="field-row-stacked" x-show="f.integrator == 'evengrid'">
              <label for="abiltrack">
                Ability tracker
              </label>
              <select name="abiltrack">
                $( render_options(ability_tracker) )
              </select>
            </div>
            $( render_stacked(form.integrator_order) )
            $( render_stacked(optimizers) )
          </fieldset>
          <fieldset class="mt-1">
            <legend>Next item</legend>
            $( render_stacked(next_item_rules) )
          </fieldset>
          <fieldset class="mt-1">
            <legend>Termination</legend>
            $( render_stacked(termination_conditions) )
            $( render_stacked(form.nitems) )
          </fieldset>
        </fieldset>
        <fieldset class="mt-1">
          <legend>Display</legend>
          $( render_row(form.ability_end) )
          $( render_row(form.results_end) )
          $( render_row(form.record) )
          $( render_row(form.results_cont) )
          $( render_row(form.answer_cont) )
        </fieldset>
        <section class="field-row" class="mt-1" style="justify-content: flex-end">
          <input value="OK" type="submit">
          <button>Cancel</button>
        </section>
      </form>
    """),
    "500px"
  )
)

test_tmpl(query) = page_base(
  "Running Computer-Adaptive Test Demo",
  window(
    "Running Computer-Adaptive Test Demo",
    @htl("""
      <div hx-ext="ws" ws-connect="/test-ws?$(query)" id="window" class="min-h-5">
        <form id="form" ws-send>
          <div id="progress"></div>
          <div id="info"></div>
          <div id="question"></div>
          <div id="response"></div>
        </form>
      </div>
    """),
    "500px"
  ),
  [restart_on_disconnect_snippet]
)

labelled_checkbox(name, option, label) = @htl(
  "<input name='$(name)' value='$(option)' id='$(name)__$(option)' type='checkbox'> <label for='$(name)__$(option)'>$(label)</label>"
)

bare_checkboxes(name, options) = @htl(
  """$((labelled_checkbox(name, option, option) for option in options))"""
)

exact_checkboxes(name, options) = @htl(
  "<fieldset>$(bare_checkboxes(name, options))</fieldset>"
)

partial_checkboxes(name, options) = @htl(
  "<fieldset>$(bare_checkboxes(name, options))</fieldset>"
)

const submit_cancel_buttons = @htl(
  """
    <div>
      <input name="action" value="Answer" type="submit">
      <input name="action" value="I don't know" type="submit">
    </div>
  """
)

function tds(contents...)
    @htl """$(((@htl "<td>$(cell)</td>") for cell in contents))"""
end

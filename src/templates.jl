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

page_base(title, body, extra_heads=[]) =  @htl("""
<html>
  <head>
    <title>$(title)</title>
    <link rel="stylesheet" href="https://unpkg.com/98.css" />
    <script src="https://unpkg.com/htmx.org@1.9.4"></script>
    <script src="https://unpkg.com/htmx.org@1.9.4/dist/ext/ws.js"></script>
    <style>
    .mt-1 {
      margin-top: 1em;
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
  "wats ur fav cat?",
  window(
    "wats ur fav cat?",
    @htl("""
      <form action="/test" method="get">
        <fieldset>
          <legend>Test selection</legend>
          <select name="test">
            <optgroup label="Synthetic">
              <option>Guassian generator</option>
              <option>Clumpy generator</option>
            </optgroup>
            <optgroup label="Datasets">
              $((option(dataset) for dataset in datasets))
            </optgroup>
          </select>
        </fieldset>
        <fieldset class="mt-1">
          <legend>CAT setup</legend>
          <fieldset>
            <legend>Ability estimation</legend>
            <div class="field-row-stacked">
              <label for="abildist">
                Distribution
              </label>
              <select name="abildist">
                $((option(distribution) for distribution in ability_estimation_distribution))
              </select>
            </div>
            <div class="field-row-stacked">
              <label for="abilest">
                Estimation
              </label>
              <select name="abilest">
                $((option(estimation) for estimation in ability_estimation))
              </select>
            </div>
            <div class="field-row-stacked">
              <label for="lower_bound">
                Integrator / optimizer lower bound
              </label>
              <input type="number" name="lower_bound">
            </div>
            <div class="field-row-stacked">
              <label for="upper_bound">
                Integrator / optimizer upper bound
              </label>
              <input type="number" name="upper_bound">
            </div>
            <div class="field-row-stacked">
              <label for="integrator">
                Integrator
              </label>
              <select name="integrator">
                $((option(integrator) for integrator in integrators))
              </select>
            </div>
            <div class="field-row-stacked">
              <label for="integrator_order">
                Integrator order
              </label>
              <input type="number" name="integrator_order">
            </div>
            <div class="field-row-stacked">
              <label for="optimizer">
                Optimizer
              </label>
              <select name="optimizer">
                $((option(optimizer) for optimizer in optimizers))
              </select>
            </div>
          </fieldset>
          <fieldset class="mt-1">
            <legend>Next item</legend>
            <div class="field-row-stacked">
              <label for="nextitem">
                Next item rule
              </label>
              <select name="nextitem">
                $((option(next_item_rule) for next_item_rule in next_item_rules))
              </select>
            </div>
          </fieldset>
          <fieldset class="mt-1">
            <legend>Termination</legend>
            <div class="field-row-stacked">
              <label for="termcond">
                Termination condition
              </label>
              <select name="termcond">
                $((option(termination_condition) for termination_condition in termination_conditions))
              </select>
            </div>
            <div class="field-row-stacked">
              <label for="nitems">
                Number of items
              </label>
              <input type="number" name="nitems">
            <div>
          </fieldset>
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
  "doin tha cat",
  window(
    "doin tha cat",
    @htl("""
      <div hx-ext="ws" ws-connect="/test-ws?$(query)" id="window">
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

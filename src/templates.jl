const restart_on_disconnect_snippet = ("""
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
page_base(title, body, extra_heads=[]) =  ("""
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
    $(join(extra_heads, "\n"))
  </head>
  <body>
    $(body)
  </body>
</html>
""")

window(title, body, width="250px") = ("""
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

option(opt) = """
  <option value="$(opt.value)">$(opt.name)</option>
"""

labelled_checkbox(name, option, label) = (
  "<input name='$(name)' value='$(option)' id='$(name)__$(option)' type='checkbox'> <label for='$(name)__$(option)'>$(label)</label>"
)

bare_checkboxes(name, options) = (
  join((labelled_checkbox(name, option, option) for option in options), "\n")
)

exact_checkboxes(name, options) = (
  "<fieldset>$(bare_checkboxes(name, options))</fieldset>"
)

partial_checkboxes(name, options) = (
  "<fieldset>$(bare_checkboxes(name, options))</fieldset>"
)

const submit_cancel_buttons = (
  """
    <div>
      <input name="action" value="Answer" type="submit">
      <input name="action" value="I don't know" type="submit">
    </div>
  """
)

function tds(contents...)
    join((("<td>$(cell)</td>") for cell in contents), "\n")
end

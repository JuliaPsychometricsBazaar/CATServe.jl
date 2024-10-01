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

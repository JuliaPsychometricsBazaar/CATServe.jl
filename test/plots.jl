# Looking at WGLMakie plots from the outside.
#
# A canvas has no queryable state: the element exists long before any pixel is
# painted, and its contents are invisible to the DOM. So these helpers work on
# two levels -- the identity of the Bonito (sub)session that owns the plot,
# which says a swap happened, and the pixels themselves, which say the plot
# actually rendered and actually changed.

using PNGFiles
using Playwright

# Bonito publishes its connection on the window; driving a plot before that is
# a silent no-op.
bonito_ready(page; timeout = plot_timeout()) =
    wait_for_function(page, "() => window.Bonito?.can_send_to_julia() === true"; timeout)

# The 98.css window chrome, the item form and the tab strips are noise for a
# pixel comparison -- and worse, changing a checkbox would change the
# screenshot all by itself. Take them out of the layout for the duration of
# the shot, which also floats the plot up into the viewport.
const HIDE_CHROME_JS = """
(hide) => {
  for (const el of document.querySelectorAll('form, menu, .title-bar')) {
    el.style.display = hide ? 'none' : '';
  }
}
"""

"""
    plot_fingerprint(page) -> Vector{UInt8}

A PNG of the page with everything but the plot hidden. Equal bytes mean the
plot did not change; different bytes mean it did.
"""
function plot_fingerprint(page)
    evaluate(page, HIDE_CHROME_JS, true)
    try
        return screenshot_bytes(page)
    finally
        evaluate(page, HIDE_CHROME_JS, false)
    end
end

distinct_colours(png::Vector{UInt8}) = length(Set(vec(PNGFiles.load(IOBuffer(png)))))

# Measured on the Bonnie/Playwright examples: ~120 distinct colours while
# Bonito is still loading, well over a thousand once a Makie figure is up.
const PAINTED_COLOURS = 500

"""
    wait_painted(page; timeout) -> (painted::Bool, colours::Int)

Poll until the plot has really painted -- there is no DOM event for "WebGL has
drawn something", so count colours until the picture stops being a blank panel
or a spinner.
"""
function wait_painted(page; timeout = plot_timeout(), min_colours = PAINTED_COLOURS)
    colours = Ref(0)
    painted = retry_until(; timeout, interval = 500, on_timeout = :false) do
        colours[] = distinct_colours(plot_fingerprint(page))
        colours[] > min_colours
    end
    return painted, colours[]
end

"""
    plot_marker(page) -> Union{String,Nothing}

Identity of the Bonito session rendering into `#plot-panel`. An htmx `Update`
swaps a freshly rendered sub-session in, so this string changes exactly when
the plot was re-rendered by the server.
"""
plot_marker(page) = evaluate(
    page,
    """() => {
      const el = document.querySelector('#plot-panel > div');
      return el ? el.id : null;
    }""",
)

"""
    wait_swapped(page, before; timeout) -> Bool

Wait for `#plot-panel` to be owned by a different Bonito session than `before`.
"""
wait_swapped(page, before; timeout = plot_timeout()) =
    retry_until(; timeout, interval = 200, on_timeout = :false) do
        marker = plot_marker(page)
        marker !== nothing && marker != before
    end

# Zoom the plot under the cursor. WGLMakie's canvas listeners forward `wheel`
# to Julia as a scroll and `mousemove` as the cursor position, and Makie's
# scroll zoom needs both: it zooms around the last cursor position it was
# told about. The wheel is repeated because one notch of zoom can be too
# little to shift a pixel.
const ZOOM_JS = """
(el) => {
  const r = el.getBoundingClientRect();
  const x = r.left + r.width / 2, y = r.top + r.height * 0.35;
  el.dispatchEvent(new MouseEvent('mousemove', {bubbles: true, clientX: x, clientY: y}));
  setTimeout(() => {
    for (let i = 0; i < 6; i++) {
      setTimeout(() => el.dispatchEvent(new WheelEvent('wheel', {
        bubbles: true, cancelable: true, clientX: x, clientY: y,
        deltaY: -120, deltaMode: 0,
      })), 60 * i);
    }
  }, 120);
}
"""

"""
    check_plot_update!(act!, page; label)

Run `act!()` -- something that makes the server re-render `#plot-panel` -- and
assert the plot really was replaced: a new Bonito session owns the panel, the
new canvas paints, and the picture is not the one from before.
"""
function check_plot_update!(act!, page; label::AbstractString)
    before_marker = plot_marker(page)
    before_shot = plot_fingerprint(page)
    act!()
    @test wait_swapped(page, before_marker)
    painted, colours = wait_painted(page)
    painted || @warn "plot did not paint after update" label colours
    @test painted
    changed = plot_fingerprint(page) != before_shot
    changed || @warn "plot pixels did not change after update" label colours
    @test changed
    return
end

"""
    interact_with_plot!(page, before; timeout) -> Bool

Drive the plot like a user would and report whether the picture changed.
`before` is a fingerprint taken while the plot was at rest.
"""
function interact_with_plot!(page, before; timeout = 20_000)
    canvas = first(locator(page, "canvas"; strict = false))
    # A real click first, so a real pointer is over the canvas.
    click!(canvas)
    evaluate(canvas, ZOOM_JS)
    return retry_until(; timeout, interval = 400, on_timeout = :false) do
        plot_fingerprint(page) != before
    end
end

"""
    plot_is_stable(page, before; timeout) -> Bool

Whether the picture stays put when nothing touches it. The control for
`interact_with_plot!`: without it, a plot that redraws on its own would look
like a plot that responded.
"""
plot_is_stable(page, before; timeout = 6000) =
    !retry_until(; timeout, interval = 400, on_timeout = :false) do
        plot_fingerprint(page) != before
    end

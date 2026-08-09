# Browser fixture, on top of Playwright.jl. Playwright manages the driver and
# the browsers itself, so the same tests run on either engine:
# CATSERVE_E2E_BROWSER=firefox drives them through Gecko.

using Playwright

# Which engine to drive: chromium (default) or firefox.
e2e_browser() = Symbol(get(ENV, "CATSERVE_E2E_BROWSER", "chromium"))

# Firefox's `--headless` disables WebGL; xvfb plus headless=false gives it a
# software GL stack via mesa. Chromium keeps SwiftShader either way.
e2e_headless() = get(ENV, "CATSERVE_E2E_HEADLESS", "true") != "false"

# How long an action or an assertion may take before it is a failure. Set once
# on the context, so every locator, expect and retry_until inherits it.
e2e_timeout() = parse(Int, get(ENV, "CATSERVE_E2E_TIMEOUT", "15000"))

# Plot budgets are separate: a cold WGLMakie first paint (Bonito bundle +
# shader compile) is tens of seconds on a CI runner, warm renders are seconds.
plot_timeout() = parse(Int, get(ENV, "CATSERVE_E2E_PLOT_TIMEOUT", "120000"))

# One option set drives both engines: Playwright ignores what the engine it is
# launching does not understand.
const LAUNCH_OPTIONS = (;
    # What containerised CI running as root needs.
    chromium_sandbox = false,
    args = ["--disable-dev-shm-usage"],
    # WGLMakie's first frame can outlast Firefox's 10 s slow-script limit,
    # which kills the script and leaves the Bonito spinner up forever. 0
    # disables the limit.
    firefox_user_prefs = Dict("dom.max_script_run_time" => 0),
)

"""
    with_browser(f)

Launch the configured engine, call `f(browser)`, and shut the browser and the
Playwright driver down afterwards, exception or not.
"""
function with_browser(f)
    playwright() do pw
        browser = launch(getfield(pw, e2e_browser()); headless = e2e_headless(), LAUNCH_OPTIONS...)
        try
            f(browser)
        finally
            close!(browser)
        end
    end
end

"""
    with_test_page(f, browser, url; name)

Open `url` in a fresh page in its own context, run `f(page)`, and assert on the
way out that the app produced no uncaught page errors. The context is disposed
afterwards.

`CATSERVE_E2E_ARTIFACTS` names a directory to dump a screenshot, the console
log and the page errors into, one subdirectory per `name`.
"""
function with_test_page(f, browser, url::AbstractString; name::AbstractString)
    ctx = new_context(browser)
    set_default_timeout!(ctx, e2e_timeout())
    # A cold server renders its first page slowly; navigation gets its own,
    # longer budget.
    set_default_navigation_timeout!(ctx, plot_timeout())
    dir = get(ENV, "CATSERVE_E2E_ARTIFACTS", "")
    # The dump is unconditional when asked for: the assertions here are
    # `@test`s, which record a failure without throwing, so :failure alone
    # would miss most red runs.
    artifacts = isempty(dir) ? nothing : joinpath(dir, replace(name, r"[^A-Za-z0-9]" => "_"))
    artifacts_on = artifacts === nothing ? :failure : :always
    try
        with_page(ctx, url; artifacts, artifacts_on) do page
            result = f(page)
            check_clean(page, name)
            return result
        end
    finally
        close!(ctx)
    end
end

# Uncaught page errors are failures. Console errors are only logged: the pages
# pull htmx and Alpine off unpkg, which is noisy and not ours to fix.
function check_clean(page, name)
    errors = page_errors(page)
    isempty(errors) || @warn "uncaught page errors" name errors = [e.message for e in errors]
    @test isempty(errors)
    console = filter(m -> m.type == "error", console_messages(page))
    isempty(console) || @warn "console errors" name errors = [m.text for m in console]
    return
end

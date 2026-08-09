# What does not work today, and why.
#
# Every entry here was reproduced against the library directly, without a
# browser, so these are statements about CATServe and its dependencies rather
# than about the tests. The tests still drive the same path, but record the
# outcome with `@test_broken` and wait only briefly, because they are waiting
# for something that is not going to happen. Delete an entry when its cause is
# fixed and the testset turns back into a real one.

const KNOWN_BROKEN = Dict(
    # FittedItemBanks: item_domain(::ItemResponse{<:NominalItemBank}) demands a
    # `reference_point` keyword that its own caller does not pass, so plotting
    # any polytomous bank throws UndefKeywordError.
    ("dummy8_gpcm", :items) =>
        "FittedItemBanks item_domain(::NominalItemBank) needs a reference_point keyword",
    # CATServe itself: src/inspect.jl builds BareResponses with Bool values,
    # which a polytomous bank rejects, so the page is a 500.
    ("dummy8_gpcm", :outcomes) =>
        "/inspect/outcomes 500s: BareResponses built with Bool values on a polytomous bank",
    # AdaptiveTestPlots.draw_likelihood indexes a scalar ability as if it were
    # a vector on a VectorContinuousDomain: BoundsError on a MIRT bank.
    ("dummy8_4pl_mirt_dimd", :outcomes) =>
        "AdaptiveTestPlots draw_likelihood does not handle a VectorContinuousDomain",
    # No integrator, ability estimator or next-item rule the configuration form
    # offers can run a CAT on these banks -- all 32 reachable combinations
    # throw. Polytomous banks index a response category at 0; multidimensional
    # banks reach integrators that only support ncomp == 0.
    # The polytomous run does put its first question on the screen and then
    # dies, so the test waits for the summary rather than for a question.
    ("dummy8_gpcm", :cat) =>
        "no configuration runs a CAT on a polytomous bank (BoundsError at category 0)",
    ("dummy8_4pl_mirt_dimd", :cat) =>
        "no configuration runs a CAT on a multidimensional bank (integrators need ncomp == 0)",
)

known_broken(value, feature) = get(KNOWN_BROKEN, (value, feature), nothing)

# The summary's playback plot renders correctly but ignores input, on every
# bank: the inspect plots, rendered inside a request, zoom on scroll, while
# this one -- a root session built inside the CAT websocket handler, after
# which that handler returns -- never redraws. Not dataset-specific, so it is
# its own flag rather than a KNOWN_BROKEN entry.
const PLAYBACK_INTERACTION_BROKEN =
    "the summary playback plot's Bonito session does not respond to input"

# A known-broken path is waited on only briefly: the full plot budget would be
# two minutes of watching nothing happen.
broken_timeout() = parse(Int, get(ENV, "CATSERVE_E2E_BROKEN_TIMEOUT", "20000"))

"""
    plot_appears(page; timeout) -> Bool

Whether a plot turns up and paints, as a plain predicate rather than an
assertion, so a known-broken case can be recorded with `@test_broken`.
"""
function plot_appears(page; timeout = broken_timeout())
    showed = retry_until(; timeout, interval = 500, on_timeout = :false, on_error = :retry) do
        count(locator(page, "canvas"; strict = false)) == 1
    end
    showed || return false
    return first(wait_painted(page; timeout))
end

"""
    cat_reaches_summary(page; timeout) -> Bool

Whether the run got all the way to the summary. Reaching the summary is the
claim under test: dummy8_gpcm does put its first question on the screen, and
only then does the websocket die, so "a question appeared" is not enough.
"""
cat_reaches_summary(page; timeout = broken_timeout()) =
    retry_until(; timeout, interval = 500, on_timeout = :false, on_error = :retry) do
        count(summary_tab(page, "model")) == 1
    end

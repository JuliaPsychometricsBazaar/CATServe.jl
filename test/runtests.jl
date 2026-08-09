# End-to-end browser tests: a real CATServe server, driven through a real
# browser by Playwright.jl. Run with `julia --project=. -e 'using Pkg;
# Pkg.test()'` from the repository root; CATSERVE_E2E_BROWSER=firefox runs the
# same tests on Gecko.

using Test

const ROOT = dirname(@__DIR__)

# CATServe resolves `datasets/` and `static/` relative to the working
# directory, and reads the datasets at load time -- so both have to be settled
# before `using CATServe`.
cd(ROOT)
include("datasets.jl")
ensure_datasets(ROOT)

using CATServe

include("fixtures.jl")
include("browser.jl")
include("pages.jl")
include("plots.jl")
include("known_broken.jl")

# One server and one browser for the whole suite; each test still gets its own
# browser context and page.
@testset "CATServe e2e ($(e2e_browser()))" begin
    with_server() do base
        global BASE = base
        with_browser() do browser
            global BROWSER = browser
            include("test_inspect.jl")
            include("test_cat.jl")
        end
    end
end

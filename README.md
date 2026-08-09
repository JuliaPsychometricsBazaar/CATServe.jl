CATServe
========

CATServe is a web demo for the `ComputerAdaptiveTesting.jl`. It can be used to
interactively take a Computer-Adaptive Test (CAT) and see the results.

Tests
-----

The test suite drives a real CATServe server in a real browser through
[Playwright.jl](https://github.com/frankier/playwright-julia). It needs the
`dummy8` item banks, which it generates itself if `datasets/` does not have
them, and a Playwright browser, which Playwright downloads on first use:

```
julia --project=. -e 'using Pkg; Pkg.test()'
```

Environment variables:

| Variable | Default | Meaning |
| --- | --- | --- |
| `CATSERVE_E2E_BROWSER` | `chromium` | Engine to drive: `chromium` or `firefox` |
| `CATSERVE_E2E_TIMEOUT` | `15000` | Budget in ms for an ordinary action or assertion |
| `CATSERVE_E2E_PLOT_TIMEOUT` | `120000` | Budget in ms for a WGLMakie plot to paint |
| `CATSERVE_E2E_ARTIFACTS` | unset | Directory to dump screenshots and console logs into |
| `CATSERVE_E2E_DATASETS` | `dummy8_gpcm,dummy8_4pl_mirt_dimd` | Item banks to drive |

Several things do not work on those two banks today. The tests still drive
them and record the result with `@test_broken`; `test/known_broken.jl` lists
each one with its cause. `CATSERVE_E2E_DATASETS=dummy8_4pl_dimd` runs the same
tests against a unidimensional bank, where everything except the playback
plot's interactivity passes.

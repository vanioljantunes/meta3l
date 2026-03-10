# Stack Research

**Domain:** R package for three-level meta-analysis with grid-based forest plots
**Researched:** 2026-03-10
**Confidence:** HIGH (all versions verified against CRAN as of research date)

## Recommended Stack

### Core Runtime Dependencies (DESCRIPTION: Imports)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| metafor | >= 3.4-0 | Model fitting (`rma.mv`), effect size calculation (`escalc`), variance construction (`vcalc`), forest plot primitives | The authoritative meta-analysis package for R. `vcalc` (needed for correlated effects) was introduced in 3.4-0 (2022-04-21). Current version 4.8-0 (2025-01-28). Requires R >= 4.0 — matches project constraint exactly. |
| clubSandwich | >= 0.5.0 | Cluster-robust (sandwich) variance estimators with small-sample Satterthwaite corrections for `rma.mv` objects | Provides `coef_test()` and `conf_int()` that work natively with metafor's `rma.mv`. The only CRAN package providing CR2/CR3 corrections for multilevel meta-analysis. Current version 0.6.2 (2026-02-02). |
| readxl | >= 1.4.0 | Import multi-sheet Excel files into named list of data frames (one per outcome/sheet) | No Java dependency (unlike xlsx/XLConnect), ships a vendored libxls, works on all platforms. Current version 1.4.5 (2025-03-07). R >= 3.6 required. |
| grid | (base R) | Forest plot rendering via viewports, layout, grobs | Ships with R — zero install cost. Used by `meta::forest.meta` (the reference implementation) and `forestplot` package. The only graphics system with the fine-grained layout control needed for publication-quality, annotated forest plots. |

### Development Tools (not in DESCRIPTION)

| Tool | Version | Purpose | Notes |
|------|---------|---------|-------|
| devtools | >= 2.4.6 | `load_all()`, `check()`, `build()`, `install()` — the core dev loop | Wraps pkgbuild, pkgload, rcmdcheck. Current version 2.4.6 (2025-10-03). Requires R >= 4.1, so use only for development (package itself targets R >= 4.0). |
| usethis | >= 3.2.1 | Scaffold DESCRIPTION, NAMESPACE, R/, tests/, vignettes/, GitHub Actions CI | `use_package()`, `use_test()`, `use_vignette()`, `use_github_action()`. Current version 3.2.1 (2025-09-06). Also requires R >= 4.1 — development only. |
| roxygen2 | >= 7.3.3 | Inline `#'` documentation → man/ pages and NAMESPACE | The only CRAN-standard documentation system. `@importFrom` in roxygen blocks generates NAMESPACE entries automatically, preventing `:::` violations. Current version 7.3.3 (2025-09-03). |
| testthat | >= 3.3.2 | Unit tests in tests/testthat/ | 3rd edition (`edition: 3` in DESCRIPTION) enables snapshot testing and parallel test execution. Current version 3.3.2 (2026-01-11). |
| pkgdown | >= 2.1.3 | Build static documentation website from roxygen + vignettes | Needed for CRAN-adjacent polish and for sharing with lab members. Current version 2.1.3 (2025-06-08). |
| rcmdcheck | (via devtools) | Run `R CMD check --as-cran` programmatically | Invoked by `devtools::check()`. Direct use for CI scripts. |
| covr | current CRAN | Test coverage reporting (2025-11-09 PDF on CRAN) | `covr::package_coverage()` + `covr::report()`. Integrate with GitHub Actions for coverage badges. |
| lintr | >= 3.3.0 | Static analysis: style, syntax, semantic issues | Version 3.3.0-1 on CRAN as of 2025-11-27. Catches `:::` usage, missing imports, and other CRAN-failing patterns before submission. |

### Supporting Libraries (DESCRIPTION: Suggests, used in vignettes/tests)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| knitr | current CRAN | Vignette engine | Required in DESCRIPTION `VignetteBuilder:` field when using `.Rmd` vignettes |
| rmarkdown | current CRAN | Render vignettes to HTML | Used with knitr for `vignette("meta3L-intro")` etc. |
| ggplot2 | current CRAN | Meta-regression bubble plots | Only needed for bubble plots — keep as Suggests, not Imports, since it's not required for core forest plot functionality |

## DESCRIPTION File Fields

```r
Package: meta3L
Version: 0.0.1
Depends: R (>= 4.0.0)
Imports:
    metafor (>= 3.4-0),
    clubSandwich (>= 0.5.0),
    readxl (>= 1.4.0),
    grid
Suggests:
    testthat (>= 3.0.0),
    knitr,
    rmarkdown,
    ggplot2
VignetteBuilder: knitr
```

**Why this split:**
- `Imports` = must be present for the package to work at all; auto-installed with the package
- `Suggests` = only needed for tests, vignettes, or optional features; not auto-installed
- `grid` is a base package — always present, no version pin needed
- Keeping `ggplot2` in Suggests avoids pulling tidyverse as a hard dependency for users who only need forest plots

## Installation (Development Setup)

```r
# Install runtime dependencies
install.packages(c("metafor", "clubSandwich", "readxl"))

# Install development toolchain
install.packages(c("devtools", "usethis", "roxygen2", "testthat",
                   "pkgdown", "covr", "lintr"))

# Bootstrap the package skeleton (run once)
usethis::create_package("path/to/meta3L")
usethis::use_roxygen_md()        # Enable markdown in roxygen docs
usethis::use_testthat(edition = 3)
usethis::use_vignette("meta3L-intro")
usethis::use_github_actions()    # Set up R-CMD-check CI
```

## Alternatives Considered

| Category | Recommended | Alternative | When Alternative Makes Sense |
|----------|-------------|-------------|------------------------------|
| Forest plots | `grid` (base R) | `forestplot` package (3rd party) | When you need a quick interactive plot and don't need a custom multi-level layout; `forestplot` doesn't support three-level I² annotations in the summary polygon |
| Forest plots | `grid` (base R) | `ggplot2` + `ggforestplot` | When the team is already fluent in ggplot2 and exact layout control is less critical; however, ggplot2 forest plots are harder to align multi-column ilab annotations precisely |
| Excel import | `readxl` | `openxlsx2` | When you also need to *write* Excel files or need `.xlsm` macros; `openxlsx2` is heavier and not needed for read-only import |
| Excel import | `readxl` | `rio` | When the project needs to import many file formats; `rio` is a wrapper that adds a dependency layer; prefer the direct tool |
| Documentation | `roxygen2` | Manual `.Rd` files | Never — manual `.Rd` editing is error-prone and CRAN maintainers expect roxygen2 workflows |
| Testing | `testthat` edition 3 | `RUnit`, `tinytest` | `tinytest` is useful for zero-dependency packages that need to avoid heavy test infrastructure; for CRAN polish with snapshot tests, `testthat` 3rd edition is standard |
| CI | GitHub Actions (`usethis::use_github_actions()`) | Travis CI, R-hub | Travis CI is effectively deprecated for open-source R packages; R-hub is a complement (multi-platform check), not a replacement |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `meta` package functions in the implementation | Creates a circular dependency / version coupling; `meta` is a consumer of `metafor`, not a building block | Implement grid forest plot logic directly, using `meta::forest.meta` source as *reference architecture* only |
| Native pipe `\|>` or `\(x)` lambda syntax | Breaks R 4.0 compatibility (native pipe arrived in R 4.1) — project requirement is R >= 4.0 | Use `function(x)` and no pipe in package code; pipes are fine in vignettes which can declare R >= 4.1 |
| `magrittr` in Imports | Adds a dependency just for `%>%`; package code should avoid pipes entirely for R 4.0 compatibility | Write explicit nested calls or intermediate assignments in package source |
| `:::` (triple-colon) | Violates CRAN policy — accessing non-exported functions from other packages is forbidden | File a feature request or copy the needed logic under proper attribution |
| `Depends:` for packages other than R version | Attaches the package to the user's search path on `library(meta3L)`, polluting their namespace | Use `Imports:` and call functions with `package::function()` |
| `xlsx` or `XLConnect` | Both require Java (rJava), which is fragile to install on macOS/Linux and causes `R CMD check` issues | `readxl` — no Java, ships its own C parser |
| `ggplot2` in Imports | Pulls in 10+ tidyverse dependencies for a feature (bubble plots) that is secondary | Put in Suggests; make the bubble plot function fail gracefully with `requireNamespace("ggplot2")` |

## Stack Patterns by Variant

**If targeting CRAN submission (immediate goal):**
- Pin minimum versions in DESCRIPTION (`metafor (>= 3.4-0)` for vcalc, `clubSandwich (>= 0.5.0)` for `rma.mv` support)
- Run `devtools::check(cran = TRUE)` before submission
- Use `usethis::use_cran_badge()` once accepted
- Test on Windows via `devtools::check_win_devel()`

**If keeping as lab-internal package (pre-CRAN phase):**
- Skip pkgdown initially
- Use `devtools::install_github()` for distribution
- GitHub Actions R-CMD-check still recommended to catch regressions

**If adding bubble plots (meta-regression visualization):**
- Use `ggplot2` in Suggests, gate behind `requireNamespace("ggplot2", quietly = TRUE)`
- Do not use grid for bubble plots — ggplot2 is appropriate here since it does not need the custom multi-column forest plot layout

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| metafor 4.8-0 | R >= 4.0.0 | Exact match with project R constraint |
| clubSandwich 0.6.2 | R >= 3.0.0 | `coef_test.rma.mv` and `conf_int.rma.mv` methods present since ~0.3.0 |
| readxl 1.4.5 | R >= 3.6 | API stable since 1.3.0; `read_excel(path, sheet = n)` is the stable interface |
| devtools 2.4.6 | R >= 4.1 | Development-only; does not affect package runtime requirements |
| usethis 3.2.1 | R >= 4.1 | Development-only |
| roxygen2 7.3.3 | R >= 3.6 | Markdown support (`@md` tag / `Roxygen: list(markdown = TRUE)`) stable since 7.x |
| testthat 3.3.2 | R >= 3.6 | 3rd edition features (snapshots, parallelism) require `testthat >= 3.0.0` in DESCRIPTION Suggests |

## Sources

- CRAN metafor index — version 4.8-0, R >= 4.0 requirement (verified 2026-03-10): https://cran.r-project.org/web/packages/metafor/index.html
- metafor project changelog — vcalc added in 3.4-0 (2022-04-21): https://www.metafor-project.org/doku.php/updates
- CRAN clubSandwich — version 0.6.2 published 2026-02-02, R >= 3.0: https://cran.r-project.org/web/packages/clubSandwich/index.html
- CRAN readxl — version 1.4.5 published 2025-03-07, R >= 3.6: https://cran.r-project.org/web/packages/readxl/index.html
- CRAN devtools — version 2.4.6 published 2025-10-03, R >= 4.1: https://cran.r-project.org/web/packages/devtools/index.html
- CRAN usethis — version 3.2.1 published 2025-09-06, R >= 4.1: https://cran.r-project.org/web/packages/usethis/index.html
- CRAN roxygen2 — version 7.3.3 published 2025-09-03, R >= 3.6: https://cran.r-project.org/web/packages/roxygen2/index.html
- CRAN testthat PDF — version 3.3.2 (2026-01-11): https://cran.r-project.org/web/packages/testthat/testthat.pdf
- CRAN pkgdown — version 2.1.3 (2025-06-08): https://cran.r-project.org/package=pkgdown
- CRAN lintr PDF — version 3.3.0-1 (2025-11-27): https://cran.r-project.org/web/packages/lintr/lintr.pdf
- R Packages (2e), Hadley Wickham & Jenny Bryan — DESCRIPTION, dependencies, CRAN release: https://r-pkgs.org
- grid package manual (2025): https://cran.r-project.org/doc/manuals/r-release/packages/grid/vignettes/grid.pdf

---
*Stack research for: meta3L — R package for three-level meta-analysis with grid forest plots*
*Researched: 2026-03-10*

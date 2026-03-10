# Architecture Research

**Domain:** R pipeline package for three-level meta-analysis
**Researched:** 2026-03-10
**Confidence:** HIGH (R package conventions are stable; three-level workflow follows established metafor patterns)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         User API Layer                              │
│  meta3l()      subgroup_meta3l()    metareg_meta3l()   loo_meta3l() │
│  forest_meta3l()                                                    │
└────────────┬───────────────────────────────────────────────────────┘
             │ calls
┌────────────▼───────────────────────────────────────────────────────┐
│                      Core Pipeline Layer                           │
│                                                                    │
│  ┌──────────────┐  ┌─────────────┐  ┌──────────────────────────┐  │
│  │  Model Fit   │  │    I²       │  │  Back-transform          │  │
│  │  (rma.mv +   │  │ Computation │  │  Dispatch                │  │
│  │   vcalc +    │  │ (between /  │  │  (measure → transf fn)   │  │
│  │   clubSand.) │  │  within)    │  │                          │  │
│  └──────┬───────┘  └──────┬──────┘  └──────────┬───────────────┘  │
│         └────────────────┬┘──────────────────── ┘                  │
│                          │ produces meta3l_result S3 object        │
└──────────────────────────┼─────────────────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────────────────┐
│                      Output Layer                                  │
│                                                                    │
│  ┌───────────────────┐   ┌───────────────────┐                    │
│  │  Forest Plot      │   │  Tabular Output   │                    │
│  │  (grid graphics)  │   │  (print method,   │                    │
│  │                   │   │   data frames)    │                    │
│  │  - Layout compute │   │                   │                    │
│  │  - Viewport setup │   │  - LOO tables     │                    │
│  │  - Draw elements  │   │  - Model summaries│                    │
│  │  - File save      │   │                   │                    │
│  └───────────────────┘   └───────────────────┘                    │
└────────────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────────────────┐
│                    Data Ingestion Layer                            │
│                                                                    │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │  read_excel_sheets()  — readxl multi-sheet → named list   │    │
│  └───────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────────────────┐
│                   External Dependencies                            │
│                                                                    │
│   metafor (rma.mv, vcalc, escalc)   clubSandwich (coef_test)      │
│   grid (viewport, gpar, unit)       readxl (read_excel)           │
└────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Talks To |
|-----------|----------------|----------|
| `read_excel_sheets()` | Convert multi-sheet Excel to named list of data frames | readxl (external) |
| Model fit core | Call `vcalc` for correlated effects, `rma.mv` with `~ 1 \| cluster / effect_id`, then `clubSandwich::coef_test` for robust variance | metafor, clubSandwich (external) |
| I² computation | Compute total, between-cluster, within-cluster I² from `rma.mv` sigma2 components using the Viechtbauer projection matrix formula | metafor result object |
| Back-transform dispatch | Map measure string (PLO, PAS, SMD, MD, RR, OR) to the correct `transf.*` function; allow user override via `transf` argument | metafor::transf.* functions |
| `meta3l_result` S3 class | Container holding model fit, I² values, back-transform info, original data, call | returned by model fit core |
| Forest plot engine | Compute layout dimensions → open grid viewport → draw study rows, CI bars, summary diamond, I² label, ilab columns, zebra shading | grid (external), meta3l_result |
| Subgroup forest plot | Iterate over subgroup levels, run model fit core for each, assemble per-group polygons, run omnibus Q-test, hand off to forest plot engine | model fit core, forest plot engine |
| Meta-regression component | Fit `rma.mv` with `mods`, produce bubble plot (scatter + regression line + CI band) with back-transformed axes | model fit core, grid/base graphics |
| LOO (cluster level) | Loop: drop each cluster → refit model → collect estimate + I² → assemble table + influence plot | model fit core |
| LOO (within-cluster level) | Loop: drop each individual effect size → refit → collect → assemble | model fit core |
| File save utility | Wrap graphics device open/close (png, pdf, svg) with auto-sized defaults and user overrides | grid (external) |

## Recommended Project Structure

```
meta3L/
├── DESCRIPTION               # Package metadata, dependencies, R >= 4.0
├── NAMESPACE                 # Auto-generated by roxygen2 — do not edit
├── R/
│   ├── read_data.R           # read_excel_sheets() — data ingestion
│   ├── fit_model.R           # fit_meta3l() — rma.mv + vcalc + clubSandwich
│   ├── compute_i2.R          # compute_i2_multilevel() — I² formula
│   ├── backtransform.R       # get_transf_fn() dispatch + measure map
│   ├── forest_plot.R         # forest_meta3l() — main forest plot
│   ├── forest_helpers.R      # Internal grid drawing primitives (rows, diamond, shading)
│   ├── subgroup.R            # subgroup_meta3l() — per-group fits + omnibus Q
│   ├── metareg.R             # metareg_meta3l() + bubble_meta3l()
│   ├── loo_cluster.R         # loo_cluster_meta3l() — leave-one-out at cluster level
│   ├── loo_effect.R          # loo_effect_meta3l() — leave-one-out at effect-size level
│   ├── s3_methods.R          # print.meta3l_result, summary.meta3l_result
│   ├── file_output.R         # open_device() / close_device() helpers
│   └── utils.R               # Shared internal helpers (arg checking, dimension estimation)
├── man/                      # Auto-generated .Rd files (do not edit)
├── tests/
│   └── testthat/
│       ├── test-read_data.R
│       ├── test-fit_model.R
│       ├── test-compute_i2.R
│       ├── test-backtransform.R
│       ├── test-subgroup.R
│       └── test-loo.R
├── vignettes/
│   └── meta3L-workflow.Rmd   # End-to-end worked example
└── data-raw/
    └── example_data.xlsx     # Bundled example dataset for vignette + tests
```

### Structure Rationale

- **One file per logical component:** Mirrors the `meta` package's per-function-family file organization (108 R files), which makes navigation predictable. For a smaller package, one file per major exported function family is appropriate.
- **`forest_helpers.R` separate from `forest_plot.R`:** The grid drawing primitives (draw a row, draw a diamond, compute column widths) are internal helpers reused by both the standard forest plot and the subgroup forest plot variant. Separating them avoids duplication.
- **`utils.R` for shared internals:** Argument validation (checking that `cluster` column exists, `rho` is numeric 0-1, etc.) is needed across multiple exported functions. Centralizing prevents drift.
- **`s3_methods.R` for all generics:** Keeps S3 dispatch registration in one place, consistent with how `meta` and `metafor` handle their result objects.
- **`data-raw/`** not shipped in package (in `.Rbuildignore`) — only the processed `data/example_data.rda` is included for vignette use.

## Architectural Patterns

### Pattern 1: S3 Result Object as Pipeline Hub

**What:** `fit_meta3l()` returns a named list with S3 class `meta3l_result`. Every downstream function (forest plot, subgroup analysis, LOO) accepts this object as its first argument. The object carries the fitted model, I² values, back-transform function, original data, and the original call.

**When to use:** Always. This is the pattern used by `meta` (returns `meta` objects), `metafor` (returns `rma` objects), and `lm` (returns `lm` objects). It enables S3 dispatch for `print`, `summary`, and `forest` generics.

**Trade-offs:** Slightly more upfront work to define the class and its contract. Pays off immediately when writing downstream functions because the interface is stable.

**Example:**
```r
fit_meta3l <- function(data, measure, cluster = "studlab", rho = 0.5, ...) {
  # ... fitting logic ...
  result <- list(
    model    = fit,          # rma.mv object
    i2       = i2_vals,      # named numeric: total, between, within
    transf   = transf_fn,    # function for back-transformation
    measure  = measure,
    data     = data,
    call     = match.call()
  )
  class(result) <- "meta3l_result"
  result
}
```

### Pattern 2: Grid Graphics — Compute Layout Then Draw

**What:** Forest plot construction in two phases. Phase 1 computes all geometry (column widths in character units, row heights, viewport coordinates) without opening a graphics device. Phase 2 opens the device, sets up viewports, draws elements. This matches how `forest.meta` (~12k lines) is organized internally.

**When to use:** Any time the plot must auto-size or adapt to variable numbers of studies or ilab columns.

**Trade-offs:** More code than base R plot, but necessary for publication quality. The `grid` package is always available (base R), so no additional dependency.

**Example:**
```r
forest_meta3l <- function(x, ilab = NULL, width = NULL, height = NULL, file = NULL, ...) {
  # Phase 1: layout computation (no device open yet)
  n_rows   <- nrow(x$data) + 3        # studies + header + diamond + footer
  col_widths <- compute_col_widths(x, ilab)  # character-unit estimates
  dev_width  <- width  %||% estimate_width(col_widths)
  dev_height <- height %||% estimate_height(n_rows)

  # Phase 2: open device, draw
  dev <- open_device(file, dev_width, dev_height)
  on.exit(dev.off())
  grid::grid.newpage()
  vp <- grid::viewport(...)
  draw_forest_rows(x, vp, col_widths)
  draw_summary_diamond(x, vp)
  draw_i2_label(x$i2, vp)
}
```

### Pattern 3: Back-Transform Dispatch Table

**What:** A named list mapping measure strings to transformation functions, looked up once during `fit_meta3l()`. The resolved function is stored in the result object so downstream components (forest plot y-axis labels, bubble plots) can call it without repeating the dispatch logic.

**When to use:** Whenever a function must behave differently based on a string argument. Avoids long `if/else` chains scattered across the codebase.

**Trade-offs:** Requires maintaining the dispatch table as new measures are added.

**Example:**
```r
.transf_map <- list(
  PLO = metafor::transf.ilogit,   # log-odds proportion → proportion
  PAS = metafor::transf.iarcsin,  # arcsine → proportion
  SMD = identity,
  MD  = identity,
  RR  = exp,
  OR  = exp
)

get_transf_fn <- function(measure, user_transf = NULL) {
  if (!is.null(user_transf)) return(user_transf)
  fn <- .transf_map[[measure]]
  if (is.null(fn)) stop("Unknown measure: ", measure)
  fn
}
```

### Pattern 4: LOO as a Loop + Collect

**What:** Leave-one-out sensitivity at either the cluster or the within-cluster level is implemented as a plain `for` loop (or `lapply`) that calls `fit_meta3l()` internally with a filtered dataset. Results are accumulated into a data frame. This keeps LOO code simple and avoids inventing a separate fitting path.

**When to use:** Both LOO variants (cluster-level and effect-size-level). The metafor `influence.rma.mv` function exists but does not expose the multilevel I² breakdown the package needs, so reimplementing the loop is necessary.

**Trade-offs:** Slower than vectorized approaches for large k, but meta-analysis datasets are rarely large enough for this to matter (k < 500 is typical). Parallelism via `parallel::mclapply` can be added later if needed without changing the interface.

## Data Flow

### Standard Analysis Flow

```
Excel file (multi-sheet)
    |
    v read_excel_sheets()
Named list of data frames  [one per outcome/sheet]
    |
    v fit_meta3l(df, measure = "PLO", cluster = "studlab", rho = 0.5)
        |
        +-- vcalc()            [sampling variances for correlated effects]
        +-- rma.mv()           [three-level REML fit]
        +-- coef_test()        [clubSandwich robust SE]
        +-- compute_i2()       [between / within / total I²]
        +-- get_transf_fn()    [resolve back-transform]
        |
        v
meta3l_result object
    |
    +---------> forest_meta3l()    --> PNG/PDF file
    |               |
    |               +-- Phase 1: col widths, row heights
    |               +-- Phase 2: grid viewport draw
    |
    +---------> subgroup_meta3l()  --> PNG/PDF file
    |               |
    |               +-- per-group fit_meta3l() calls
    |               +-- omnibus Q-test
    |               +-- subgroup forest draw
    |
    +---------> metareg_meta3l()   --> model summary + bubble PNG
    |
    +---------> loo_cluster_meta3l()   --> table + influence plot
    |
    +---------> loo_effect_meta3l()    --> table + influence plot
```

### Key Data Flows

1. **Excel → model:** `readxl::read_excel()` per sheet → named list → user passes one data frame to `fit_meta3l()`. The named list is the multi-outcome container; the package operates on one outcome at a time.

2. **Model → forest plot:** The `meta3l_result` object carries everything the forest plot needs: effect sizes, CIs (back-transformed via stored `transf` function), I² values for the summary label, cluster labels. No global state; the object is self-contained.

3. **Model → LOO:** `loo_cluster_meta3l()` receives the result, extracts the original data (`x$data`), loops over unique cluster values, subsets the data, calls `fit_meta3l()` again. The fresh `fit_meta3l()` calls are independent — no shared state.

4. **I² → all outputs:** Computed once in `fit_meta3l()` and stored. Forest plot summary label, LOO tables, and print method all read from `x$i2` rather than recomputing.

## Build Order (Phase Dependencies)

Components must be built in this order because later components depend on earlier ones:

```
1. utils.R           — arg checking helpers (no deps inside package)
   |
2. backtransform.R   — get_transf_fn() (uses utils)
   |
3. compute_i2.R      — compute_i2_multilevel() (uses metafor internals)
   |
4. fit_model.R       — fit_meta3l() / meta3l_result class (uses 2+3)
   |
5. s3_methods.R      — print/summary for meta3l_result (uses 4)
   |
6. read_data.R       — read_excel_sheets() (standalone, but needs 4's class to be testable end-to-end)
   |
7. file_output.R     — open/close device (standalone utility)
   |
8. forest_helpers.R  — internal grid primitives (uses 4, 7)
   |
9. forest_plot.R     — forest_meta3l() (uses 4, 7, 8)
   |
10. subgroup.R       — subgroup_meta3l() (uses 4, 9)
    |
11. metareg.R        — metareg_meta3l() + bubble (uses 4, 7)
    |
12. loo_cluster.R    — loo_cluster_meta3l() (uses 4, 7)
    |
13. loo_effect.R     — loo_effect_meta3l() (uses 4, 7)
```

This ordering maps directly to build phases: **core model (1-6) → forest plot (7-9) → extensions (10-13)**.

## Anti-Patterns

### Anti-Pattern 1: Calling `rma.mv` Directly in Forest Plot Code

**What people do:** Embed the `rma.mv` call inside `forest_meta3l()` or `subgroup_meta3l()` so it "just works" in one call.

**Why it's wrong:** The model fit is expensive and now happens invisibly every time a plot is redrawn. The user can't inspect the model or save it. Subgroup and LOO functions end up duplicating fit logic, diverging over time.

**Do this instead:** Always separate `fit_meta3l()` from `forest_meta3l()`. The user fits once, plots many times. The result object is the contract between layers.

### Anti-Pattern 2: Using `:::` to Access metafor Internals

**What people do:** Use `metafor:::some_internal_fn()` to reuse unexported helper code from metafor.

**Why it's wrong:** CRAN policy prohibits `:::` calls to other packages. These internal functions can change without notice between metafor versions.

**Do this instead:** Use only metafor's exported API (`rma.mv`, `vcalc`, `transf.*`). Implement any needed helper logic (e.g., the I² projection matrix formula) directly in the package, citing the source in comments.

### Anti-Pattern 3: Global State for Plot Configuration

**What people do:** Use `options()` or a package-level environment to store "current" plot settings (column labels, shading colors), then read them in the drawing code.

**Why it's wrong:** Makes functions non-reproducible (different calls produce different output depending on invisible global state). Hard to test. Hard to understand from reading a script.

**Do this instead:** Pass all configuration through function arguments with sensible defaults. If argument lists become unwieldy, use a single named list argument (e.g., `plot_opts = list(...)`) following the pattern of `forest.meta`'s `...` forwarding.

### Anti-Pattern 4: One Monolithic R File

**What people do:** Put all functions in a single `functions.R` or `meta3L.R` file.

**Why it's wrong:** Impossible to navigate once the package grows beyond a few hundred lines. The meta package has 108 files for good reason. devtools/roxygen2 work fine with many files; R sources them all.

**Do this instead:** One file per function family (see Recommended Project Structure above). File names should match the primary exported function they contain.

### Anti-Pattern 5: Reimplementing the Full Forest Plot from Scratch Each Variant

**What people do:** Copy-paste `forest_meta3l()` to create `subgroup_forest_meta3l()`, diverging immediately.

**Why it's wrong:** Bug fixes must be applied in multiple places. Code drift is guaranteed.

**Do this instead:** Extract shared drawing primitives to `forest_helpers.R` (draw a single study row, draw a diamond, draw a CI bar). Both `forest_meta3l()` and `subgroup_meta3l()` call the same primitives. Only the data assembly and loop logic differ.

## Integration Points

### External Dependencies

| Dependency | Integration Pattern | Notes |
|------------|--------------------|----|
| `metafor::rma.mv` | Call directly; store result in `meta3l_result$model` | Do NOT store intermediate internal metafor objects like `res$M` — unstable |
| `metafor::vcalc` | Call before `rma.mv`; result passed as `V` arg | Requires sampling variance column in data |
| `metafor::transf.*` | Resolved once in `get_transf_fn()`; stored as a function reference | User can supply any function matching `f(x)` signature |
| `clubSandwich::coef_test` | Call on `rma.mv` result with `vcov = "CR2"` | Returns robust SE and p-value; store alongside model summary |
| `readxl::read_excel` | One call per sheet; iterated in `read_excel_sheets()` | Sheet names become list names; no other readxl internals needed |
| `grid` (base R) | Viewport + gpar + unit system throughout forest plot | Always available; no import declaration needed beyond `@importFrom grid ...` |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|--------------|-------|
| Data ingestion ↔ Model fit | Plain data frame (standard R contract) | No special class; user can supply any data frame, not just Excel-sourced ones |
| Model fit ↔ All outputs | `meta3l_result` S3 object | This is the central contract; changing its structure is a breaking change |
| Forest plot ↔ Forest helpers | Direct function calls (internal, not exported) | Helpers use `@keywords internal` + no `@export` in roxygen |
| LOO ↔ Model fit | LOO calls `fit_meta3l()` re-using the public API | This ensures LOO is always consistent with the main fit |
| Any component ↔ File output | `open_device()` / `close_device()` | Decouples plot logic from graphics device management |

## Scaling Considerations

This is a scripting/analysis package, not a server. "Scale" means: how does the package hold up as dataset size, number of subgroups, or number of outcomes grows?

| Concern | Small (k < 50 studies) | Medium (k 50-500) | Large (k > 500) |
|---------|----------------------|-------------------|-----------------|
| LOO computation | Negligible (< 1 sec) | Acceptable (seconds to ~1 min) | May need `parallel::mclapply` — add as option |
| Forest plot height | Auto-estimate works fine | Auto-estimate may undersize; user sets `height` manually | Same |
| Multi-outcome (many sheets) | Simple loop over list | Same | Same — no global state means parallelism is safe |
| Memory | Trivial | Trivial | Trivial — meta-analysis data is small |

## Sources

- R package structure conventions: [R Packages (2e), Wickham & Bryan](https://r-pkgs.org/whole-game.html)
- roxygen2 NAMESPACE management: [roxygen2 CRAN vignette](https://cran.r-project.org/web//packages/roxygen2/vignettes/namespace.html)
- `forest.meta` internal organization (grid phases): [meta source R/forest.R via rdrr.io](https://rdrr.io/cran/meta/src/R/forest.R)
- meta package file structure (108 R files): [guido-s/meta on GitHub](https://github.com/guido-s/meta)
- Multilevel I² formula (projection matrix approach): [metafor-project.org tips](https://www.metafor-project.org/doku.php/tips:i2_multilevel_multivariate)
- Three-level rma.mv model structure: [Doing Meta-Analysis in R, Chapter 10](https://bookdown.org/MathiasHarrer/Doing_Meta_Analysis_in_R/multilevel-ma.html)
- Back-transformation functions: [metafor::transf documentation](https://rdrr.io/cran/metafor/man/transf.html)
- Influence diagnostics for rma.mv: [metafor::influence.rma.mv](https://rdrr.io/cran/metafor/man/influence.rma.mv.html)
- Grid-based forest plot packages: [forestplot CRAN vignette](https://cran.r-project.org/web/packages/forestplot/vignettes/forestplot.html)
- meta package on CRAN: [meta CRAN page](https://cran.r-project.org/package=meta)
- metafor package website: [metafor-project.org](https://wviechtb.github.io/metafor/)

---
*Architecture research for: R three-level meta-analysis pipeline package (meta3L)*
*Researched: 2026-03-10*

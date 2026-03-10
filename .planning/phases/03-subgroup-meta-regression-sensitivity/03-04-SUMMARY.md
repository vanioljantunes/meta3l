---
phase: 03-subgroup-meta-regression-sensitivity
plan: "04"
subsystem: sensitivity-analysis
tags: [loo, leave-one-out, influence-analysis, grid-graphics, s3-dispatch, metafor]

# Dependency graph
requires:
  - phase: 03-01-subgroup-meta-regression-sensitivity
    provides: "meta3l_result S3 object with $data, $V, $cluster, $transf, $model, $slab, resolve_file() suffix support"
  - phase: 02-02-forest-plot-file-output
    provides: "draw_square, draw_diamond, draw_ci_line, draw_zebra_rect, auto_dims, auto_refline, auto_xlim grid drawing primitives"
provides:
  - "loo_cluster.meta3l_result(): cluster-level LOO — drops each study, refits, returns influence table + grid plot"
  - "loo_effect.meta3l_result(): effect-level LOO — drops each effect size row, refits, returns influence table + grid plot"
  - "Both functions return list($table, $plot_file) with 7-column influence table (omitted, estimate, ci.lb, ci.ub, i2_between, i2_within, pval)"
  - ".draw_loo_plot() internal shared helper for LOO influence plots using grid layout"
  - "All studies baseline row always at bottom of table"
affects:
  - phase-03-05-report-generation

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "S3 method named *.meta3l_result (not *.meta3L) to match actual class of meta3l_result objects — UseMethod dispatch requires class name match"
    - "Sequential lapply for LOO loops (not mclapply) — Windows-safe per locked project decision"
    - "V-matrix subsetting uses identical logical index as data subsetting: V_loo <- x$V[keep, keep, drop=FALSE]"
    - "Guard check: n_clust <- length(unique(dat_loo[[x$cluster]])); if (n_clust < 2L) warn + return NA row"
    - "tryCatch around each rma.mv refit — convergence failures return NA row with warning, never crash"
    - "Full model I2 computed via fresh rma.mv call (not from robust object) — compute_i2 needs sigma2 from raw fit"
    - ".draw_loo_plot() shared between loo_cluster and loo_effect — single layout: label col | gap | CI panel | gap | I2_B | I2_W | pval"

key-files:
  created:
    - meta3l/R/loo_cluster.meta3L.R
    - meta3l/R/loo_effect.meta3L.R
    - meta3l/tests/testthat/test-loo.R
    - meta3l/man/loo_cluster.Rd
    - meta3l/man/loo_cluster.meta3l_result.Rd
    - meta3l/man/loo_effect.Rd
    - meta3l/man/loo_effect.meta3l_result.Rd
    - meta3l/man/dot-loo_effect_label.Rd
    - meta3l/man/dot-draw_loo_plot.Rd
  modified:
    - meta3l/NAMESPACE

key-decisions:
  - "S3 methods named loo_cluster.meta3l_result and loo_effect.meta3l_result — UseMethod(\"loo_cluster\") looks up class attribute which is \"meta3l_result\", not \"meta3L\"; plan's *.meta3L naming would silently fail dispatch"
  - ".draw_loo_plot() extracted as shared internal function rather than duplicating 50-line layout in both files"
  - "Full-model I2 for baseline row computed via fresh rma.mv call (not x$model which is a robust.rma object) — compute_i2 requires sigma2 from the underlying rma.mv fit"
  - "loo_effect label format: 'StudyLabel [row_index]' — slab value provides identity, row index disambiguates repeated study names"

requirements-completed: [SENS-01, SENS-02]

# Metrics
duration: ~9min
completed: 2026-03-10
---

# Phase 3 Plan 04: LOO Sensitivity Analysis Summary

**Cluster-level and effect-level leave-one-out sensitivity analysis using sequential lapply, grid influence plots reusing Phase 2 drawing primitives, with S3 dispatch on meta3l_result class — 265 tests pass, 0 failures**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-03-10T22:14:28Z
- **Completed:** 2026-03-10T22:23:28Z
- **Tasks:** 2 (TDD: RED commit + GREEN commit per task)
- **Files modified:** 1 modified, 10 created

## Accomplishments

- `loo_cluster.meta3l_result()`: drops each unique cluster, refits with `rma.mv + robust`, returns 7-column influence table (n_clusters+1 rows) and grid plot
- `loo_effect.meta3l_result()`: drops each effect size row, refits, returns 7-column table (n_effects+1 rows) and grid plot
- Both functions follow identical pattern: guard (< 2 clusters check), `tryCatch` for convergence resilience, sequential `lapply`, `All studies` baseline at table bottom
- `.draw_loo_plot()` shared internal function with 7-column grid layout reusing `draw_ci_line`, `draw_square`, `draw_diamond`, `draw_zebra_rect` from Phase 2
- Full test coverage: 14 loo_cluster tests + 10 loo_effect tests, all 265 package tests pass

## Task Commits

Each task committed atomically with TDD RED+GREEN:

1. **Task 1 RED — Failing LOO test file** - `b1b1226` (test)
2. **Task 1 GREEN — loo_cluster.meta3l_result() implementation** - `b09c111` (feat)
3. **Task 2 GREEN — loo_effect.meta3l_result() implementation** - `26c5b62` (feat)

## Files Created/Modified

- `meta3l/R/loo_cluster.meta3L.R` — S3 generic `loo_cluster()`, method `loo_cluster.meta3l_result()`, shared `.draw_loo_plot()` helper
- `meta3l/R/loo_effect.meta3L.R` — S3 generic `loo_effect()`, method `loo_effect.meta3l_result()`, `.loo_effect_label()` helper
- `meta3l/tests/testthat/test-loo.R` — 24 tests covering both LOO functions (table dimensions, column names, All studies baseline, PNG output, file naming)
- `meta3l/NAMESPACE` — S3method and export entries for both LOO generics and methods
- `meta3l/man/` — 5 new Rd documentation files

## Decisions Made

- **S3 method names use `.meta3l_result` suffix** — `UseMethod("loo_cluster")` looks up the object's class attribute, which is `"meta3l_result"`, not `"meta3L"`. The plan specified `loo_cluster.meta3L` but this would fail S3 dispatch silently. Fixed to `loo_cluster.meta3l_result` with `@method loo_cluster meta3l_result` roxygen annotation.
- **`.draw_loo_plot()` extracted as shared function** — both LOO functions use the identical 7-column grid layout; sharing avoids duplication and ensures visual consistency.
- **Baseline row I2 computed via fresh `rma.mv` call** — `compute_i2()` requires `fit$sigma2` which exists on `rma.mv` objects but not on `robust.rma` wrappers. `x$model` is the robust object, so a fresh full-data fit is needed for the baseline I2 values.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] S3 method naming: loo_cluster.meta3L → loo_cluster.meta3l_result**
- **Found during:** Task 1 GREEN phase (after implementing loo_cluster.meta3L as specified in plan)
- **Issue:** `UseMethod("loo_cluster")` dispatches on the class attribute `"meta3l_result"`, not `"meta3L"`. The plan specified naming the method `loo_cluster.meta3L`, but that name would only be found if the object's class were `"meta3L"`. The meta3l_result objects have class `"meta3l_result"`.
- **Fix:** Renamed method from `loo_cluster.meta3L` to `loo_cluster.meta3l_result`. Updated roxygen `@method` annotation to `@method loo_cluster meta3l_result`. Re-ran `roxygenise()` to update NAMESPACE from `S3method(loo_cluster,meta3L)` to `S3method(loo_cluster,meta3l_result)`. Applied same pattern to `loo_effect.meta3l_result`.
- **Files modified:** `meta3l/R/loo_cluster.meta3L.R`, `meta3l/NAMESPACE`
- **Verification:** `loo_cluster(res)` dispatch confirmed working, 14/14 tests pass
- **Committed in:** `b09c111`

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug: S3 dispatch naming mismatch)
**Impact on plan:** Required fix — without it, S3 dispatch fails silently at runtime. No scope creep. All plan intent preserved.

## Issues Encountered

- The `pretty()` function is a base R function, not a `stats` export — `@importFrom stats pretty` caused a roxygen warning. Removed from `@importFrom`. (auto-fixed during GREEN phase)

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `loo_cluster(result)` and `loo_effect(result)` ready for use in Phase 3 plan 05 (report generation)
- Both functions return consistent `list($table, $plot_file)` structure for programmatic use
- Sequential LOO is slow for large datasets (O(n_clusters) or O(n_effects) model refits) — documented as expected behavior per locked project decision

## Self-Check: PASSED

- `meta3l/R/loo_cluster.meta3L.R` — exists with correct S3 method name
- `meta3l/R/loo_effect.meta3L.R` — exists with correct S3 method name
- `meta3l/tests/testthat/test-loo.R` — exists, 24 tests
- `meta3l/NAMESPACE` — has `S3method(loo_cluster,meta3l_result)` and `S3method(loo_effect,meta3l_result)`
- Commits `b1b1226`, `b09c111`, `26c5b62` — all present in git log
- Full test suite: 265 pass, 0 fail

---
*Phase: 03-subgroup-meta-regression-sensitivity*
*Completed: 2026-03-10*

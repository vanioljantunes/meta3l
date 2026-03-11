---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: completed
stopped_at: Completed 03-05 Task 1 (TDD); awaiting human-verify checkpoint Task 2
last_updated: "2026-03-10T00:00:00.000Z"
last_activity: 2026-03-10 — quick-1 CRAN vignette for meta3l (DESCRIPTION + introduction.Rmd, 2 tasks, 2 min)
progress:
  total_phases: 3
  completed_phases: 3
  total_plans: 9
  completed_plans: 9
  percent: 56
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-10)

**Core value:** Make three-level meta-analysis accessible through a clean API that handles multilevel modeling complexity while producing publication-quality forest plots.
**Current focus:** Phase 3 — Subgroup Analysis, Meta-Regression, Sensitivity

## Current Position

Phase: 3 of 3 (Subgroup Analysis, Meta-Regression, Sensitivity) — IN PROGRESS
Plan: 03-03 complete — bubble.meta3L() meta-regression bubble plot with robust p-value (266 tests pass)
Status: 03-03 done; MREG-01 through MREG-04 complete
Last activity: 2026-03-10 — 03-03 bubble.meta3L() meta-regression bubble plot with clubSandwich robust p-value (266 tests pass, 0 failures)

Progress: [█████░░░░░] 56%

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: 7.3 min
- Total execution time: 22 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-core-model-pipeline | 2/2 | 17 min | 8.5 min |
| 02-forest-plot-file-output | 1/2 | 5 min | 5 min |

**Recent Trend:**
- Last 5 plans: 01-01 (5 min), 01-02 (12 min), 02-01 (5 min)
- Trend: Phase 2 in progress

*Updated after each plan completion*
| Phase 01-core-model-pipeline P01 | 5min | 2 tasks | 17 files |
| Phase 01-core-model-pipeline P02 | 12min | 2 tasks | 11 files |
| Phase 02-forest-plot-file-output P01 | 5min | 2 tasks | 6 files |
| Phase 02-forest-plot-file-output P02 | 15min | 3 tasks | 7 files |
| Phase 03-subgroup-meta-regression-sensitivity P01 | 10min | 2 tasks | 8 files |
| Phase 03-subgroup-meta-regression-sensitivity P03 | 11min | 1 task (TDD) | 4 files |
| Phase 03-subgroup-meta-regression-sensitivity P04 | 9 | 2 tasks | 11 files |
| Phase 03-subgroup-meta-regression-sensitivity P02 | 12 | 1 tasks | 7 files |
| Phase 03-subgroup-meta-regression-sensitivity P05 | 4 | 2 tasks | 4 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Grid graphics for forest plots (not ggplot2) — better layout control, matches meta package quality
- Default cluster = studlab with override — covers most use cases without sacrificing flexibility
- Auto-detect back-transformation from measure argument — reduces user error burden
- Separate subgroup fits vs. moderator models — distinct functions for descriptive vs. formal hypothesis testing
- Two-level leave-one-out (cluster + within-cluster) — unique to three-level structure, not in existing packages
- R >= 4.0 compat enforced: no native pipe (|>) or lambda (\(x)) in any R/ source (01-01)
- REQUIRED_COLS list in utils.R is single source of truth for per-measure escalc column requirements (01-01)
- SMD/MD use two-group form m1i/sd1i/n1i/m2i/sd2i/n2i per locked CONTEXT.md decision (01-01)
- compute_i2 uses solve(V) as precision matrix — V from vcalc is non-diagonal (01-01)
- [Phase 01-core-model-pipeline]: Dynamic rma.mv formula uses as.formula(paste0('~ 1 | ', cluster, ' / TE_id')) — cluster always resolved at runtime
- [Phase 01-core-model-pipeline]: Column renaming strategy before do.call(escalc, ...) avoids escalc pitfall 4 (vector vs. column name confusion)
- [Phase 01-core-model-pipeline]: clubSandwich in Imports declared via @importFrom clubSandwich vcovCR; meta3L always calls robust(clubSandwich=TRUE)
- [Phase 02-forest-plot-file-output]: resolve_file uses character(0) sentinel for auto-name (NULL=display-only, string=explicit path)
- [Phase 02-forest-plot-file-output]: draw_* primitives are viewport-context-free — callers push/pop viewports; forest.meta3L() has full layout control
- [Phase 02-forest-plot-file-output]: options(meta3l.mwd) set with normalizePath(mustWork=TRUE) inside read_multisheet_excel() for safe path resolution
- [Phase 02-forest-plot-file-output]: import metafor::forest as S3 generic source — required for S3method(forest, meta3L) dispatch to work correctly
- [Phase 02-forest-plot-file-output]: grDevices functions declared via @importFrom (not explicit grDevices:: prefix) — CRAN check requires explicit import declarations
- [Phase 02-forest-plot-file-output]: nullfile() is a base function, not grDevices export — @importFrom grDevices nullfile must not be used
- [Phase 03-subgroup-meta-regression-sensitivity]: META_COL_MAP placed at file top (before docstring) — when placed after @examples closing brace, roxygen2 absorbed the full function docstring into META_COL_MAP.Rd and exported it
- [Phase 03-subgroup-meta-regression-sensitivity]: For RR/OR meta-style API, n.e/n.c map to internal bi/di derivation (not n1i/n2i) — escalc for RR/OR requires ai, bi, ci, di (2x2 cells), not totals
- [Phase 03-subgroup-meta-regression-sensitivity]: resolve_file fallback base_name changed from "forest_plot" to "meta3l_plot" — more generic for Phase 3 plot types beyond forest plots
- [Phase 03-subgroup-meta-regression-sensitivity]: S3 methods named loo_cluster.meta3l_result and loo_effect.meta3l_result — UseMethod dispatch requires class name match; meta3l_result objects have class meta3l_result not meta3L
- [Phase 03-subgroup-meta-regression-sensitivity]: Sequential lapply for LOO loops (not mclapply/parLapply) — Windows-safe; compute_i2 needs rma.mv sigma2 so baseline I2 requires fresh rma.mv call (not the robust wrapper in x$model)
- [Phase 03-subgroup-meta-regression-sensitivity]: bubble.meta3L method named with .meta3L suffix (not .meta3l_result) — consistent with forest.meta3L pattern; tests call method directly
- [Phase 03-subgroup-meta-regression-sensitivity]: bubble.meta3L uses stats::predict() for prediction grid — S3 dispatch to predict.rma works without NAMESPACE import of metafor::predict.rma
- [Phase 03-subgroup-meta-regression-sensitivity]: bubble.meta3L back-transformed estimate at mean moderator (not intercept) — predict(fit_full, newmods=mean) more interpretable on back-transformed scale
- [Phase 03-subgroup-meta-regression-sensitivity]: moderator.meta3l_result S3 dispatch: class-based dispatch requires method named after the class (meta3l_result), not the constructor function (meta3L)
- [Phase 03-subgroup-meta-regression-sensitivity]: LRT for moderator uses ML-fitted models (method='ML'): REML not valid for comparing models with different fixed effects — metafor requirement
- [Phase 03-subgroup-meta-regression-sensitivity]: bobyqa optimizer fallback: tryCatch around rma.mv retries with control=list(optimizer='bobyqa') on convergence failure — handles small/borderline datasets
- [Phase 03-subgroup-meta-regression-sensitivity]: forest_subgroup S3 generic dispatches to .meta3L method (not .meta3l_result) — consistent with forest.meta3L and bubble.meta3L naming pattern
- [Phase 03-subgroup-meta-regression-sensitivity]: Row layout for forest_subgroup uses incremental current_row counter (not pre-computed ranges) — simpler for variable-length subgroup sections

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 3: Subgroup API design (exact function signatures for `forest_subgroup.meta3L()` vs. `moderator.meta3L()`) is underspecified — address during Phase 3 planning with a research step on current metafor API behavior for omnibus Q-test (QM vs. QE statistics).
- Phase 3: Parallel LOO on Windows — `parallel::mclapply` does not fork on Windows; may need `parLapply` with explicit cluster if research group uses Windows. Measure LOO runtime empirically in Phase 3 before deciding.

## Session Continuity

Last session: 2026-03-10T00:00:00.000Z
Stopped at: Completed quick-1 (CRAN vignette documentation)
Resume file: None

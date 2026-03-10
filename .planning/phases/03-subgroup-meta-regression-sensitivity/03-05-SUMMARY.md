---
phase: 03-subgroup-meta-regression-sensitivity
plan: 05
subsystem: visualization
tags: [r, grid-graphics, forest-plot, subgroup-analysis, metafor, rma.mv, three-level]

# Dependency graph
requires:
  - phase: 03-01
    provides: subgroup fixture data, compute_i2, resolve_file, format_mlab
  - phase: 03-02
    provides: moderator.meta3l_result for omnibus test pattern (QM/QMp)
  - phase: 02-02
    provides: forest.meta3L layout pattern, draw_* primitives, auto_dims/auto_xlim

provides:
  - "forest_subgroup.meta3L() — grouped subgroup forest plot with per-subgroup diamonds, omnibus Q-test footer"
  - "S3 generic forest_subgroup() dispatching on meta3L class"

affects: [checkpoint-verification, phase-3-complete]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "V-matrix subsetting: idx <- which(dat[[subgroup]] == gv); V_g <- V[idx, idx]"
    - "Per-subgroup rma.mv with robust() + compute_i2() for heterogeneity decomposition"
    - "Omnibus Q-test via rma.mv(mods=~factor(subgroup)) — extracts QM, m, QMp"
    - "bobyqa fallback for per-subgroup fits: tryCatch retry on convergence failure"
    - "Row counter pattern: current_row incremented after each drawn row section"
    - "Single-cluster subgroup: warning() + rma() fallback, diamond skipped"

key-files:
  created:
    - meta3l/R/forest_subgroup.meta3L.R
    - meta3l/tests/testthat/test-forest_subgroup.R
    - meta3l/man/forest_subgroup.Rd
  modified:
    - meta3l/NAMESPACE

key-decisions:
  - "forest_subgroup S3 generic uses .meta3L suffix for method (consistent with forest.meta3L, bubble.meta3L pattern)"
  - "Row layout uses current_row integer counter (not pre-computed ranges) — simpler for variable-length subgroup sections"
  - "V-matrix reordered when sortvar applied — same index used for both dat and V subsetting to avoid Pitfall 2"
  - "Omnibus Q-test text row rendered only when qtest_text is non-empty — gracefully skipped on model failure"
  - "Subgroup diamond clipped to xlim at draw time (max/min) to prevent overflow artefacts"

patterns-established:
  - "TDD: test file committed first (RED 9 failures), then implementation (GREEN 11 passes)"
  - "@rdname forest_subgroup on method docblock — avoids 'no name/title' roxygen warning"

requirements-completed: [SUBG-01, SUBG-02, SUBG-03]

# Metrics
duration: 4min
completed: 2026-03-10
---

# Phase 3 Plan 05: forest_subgroup.meta3L() Subgroup Forest Plot Summary

**Grouped subgroup forest plot with per-subgroup three-level fits, I-squared decomposition, omnibus Q-test footer via rma.mv(mods=~factor(subgroup)), and overall diamond — 277 tests pass**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-10T22:10:29Z
- **Completed:** 2026-03-10T22:14:00Z
- **Tasks:** 1 of 2 automated (Task 2 = human-verify checkpoint)
- **Files modified:** 4

## Accomplishments

- Implemented `forest_subgroup.meta3L()` — the most complex Phase 3 deliverable
- Per-subgroup three-level model fits with V-matrix subsetting, robust standard errors, and I-squared decomposition
- Omnibus Q-test for subgroup differences displayed in footer
- Single-cluster subgroup handling: warning issued, diamond skipped gracefully
- Full TDD cycle: 9 failing RED tests → 11 GREEN tests; 277 total tests, 0 failures

## Task Commits

Each task was committed atomically:

1. **TDD RED — test-forest_subgroup.R** - `8457d95` (test)
2. **TDD GREEN — forest_subgroup.meta3L.R + NAMESPACE** - `0a2779c` (feat)

## Files Created/Modified

- `meta3l/R/forest_subgroup.meta3L.R` — S3 generic + meta3L method for grouped subgroup forest plot
- `meta3l/tests/testthat/test-forest_subgroup.R` — 11 smoke tests covering file output, overall=FALSE, error handling, ilab, auto-naming, display-only mode
- `meta3l/man/forest_subgroup.Rd` — Generated roxygen documentation
- `meta3l/NAMESPACE` — Added S3method(forest_subgroup,meta3L) and export(forest_subgroup), importFrom(stats,qnorm)

## Decisions Made

- `forest_subgroup` S3 generic dispatches to `.meta3L` method (not `.meta3l_result`) — consistent with `forest.meta3L` and `bubble.meta3L` naming pattern in this codebase
- Row layout uses an incremental `current_row` counter rather than pre-computing row ranges — simpler for variable-length subgroup sections where diamond presence varies per group
- V-matrix reordered in parallel with data reorder when `sortvar` is applied — required to avoid Pitfall 2 (misaligned V rows/cols vs. data rows)
- `@rdname forest_subgroup` on method docblock avoids the "no name and/or title" roxygen2 warning
- `bobyqa` optimizer fallback wraps each `rma.mv` call — handles borderline datasets with few observations per subgroup

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None — implementation followed plan spec cleanly.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `forest_subgroup.meta3L()` is ready for visual verification (Task 2 checkpoint)
- All 5 Phase 3 exported functions are implemented and unit-tested
- Visual verification checkpoint (Task 2) requires user to run `devtools::load_all()` and manually inspect all 5 Phase 3 functions

---
*Phase: 03-subgroup-meta-regression-sensitivity*
*Completed: 2026-03-10*

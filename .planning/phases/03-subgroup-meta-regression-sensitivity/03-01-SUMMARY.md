---
phase: 03-subgroup-meta-regression-sensitivity
plan: "01"
subsystem: core-api
tags: [meta-style-api, column-names, auto-detection, fixtures, resolve_file, r-cmd-check]

# Dependency graph
requires:
  - phase: 02-02-forest-plot-file-output
    provides: "meta3l_result S3 object, forest.meta3L(), resolve_file(), draw_* primitives"
  - phase: 01-02-core-model-pipeline
    provides: "meta3L(), escalc/rma.mv pipeline, REQUIRED_COLS, validate_columns()"
provides:
  - "META_COL_MAP: escalc canonical -> meta-style column name mapping for all 6 measures"
  - "meta3L() accepts meta-style column names (event, n, event.e, n.e, event.c, n.c, mean.e, sd.e, mean.c, sd.c)"
  - "meta3L() auto-detects standard meta-style columns from data when no col args supplied"
  - "bi/di computed internally from n.e - event.e and n.c - event.c for RR/OR"
  - "Backward compat: all escalc-style names (xi, ni, ai, bi, ci, di, etc.) still work"
  - "resolve_file() has suffix parameter for Phase 3 filename patterns"
  - "Test fixtures expanded to 3 studies (9 rows) with subgroup and dose columns"
affects:
  - phase-03-02-subgroup-analysis
  - phase-03-03-meta-regression
  - phase-03-04-sensitivity

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "META_COL_MAP placed at file top (before docstring) to prevent roxygen2 accidental export"
    - "Sentinel strings (.meta3l_bi_derived, .meta3l_di_derived) used for internally-computed cols during validation"
    - "validate_columns() skips bi/di when they equal their canonical sentinel names (derived cols)"
    - "Auto-detection checks all meta-style cols present in data before activating; falls back to error if not"
    - "resolve_file suffix appended with underscore separator: {name}_{suffix}.{format}"

key-files:
  created: []
  modified:
    - meta3l/R/meta3L.R
    - meta3l/R/utils.R
    - meta3l/R/forest_helpers.R
    - meta3l/tests/testthat/helper-fixtures.R
    - meta3l/tests/testthat/test-meta3L.R
    - meta3l/tests/testthat/test-forest-helpers.R
    - meta3l/NAMESPACE
    - meta3l/man/meta3L.Rd

key-decisions:
  - "META_COL_MAP is internal (not exported) — placed before the function docstring so roxygen2 does not treat it as an exported dataset"
  - "For RR/OR, n.e and n.c translate to bi/di via subtraction (n.e - event.e) — not passed as n1i/n2i because escalc for RR/OR needs ai, bi, ci, di (not totals)"
  - "resolve_file fallback changed from forest_plot to meta3l_plot — more generic for Phase 3 plot types"
  - "Test fallback name updated from forest_plot to meta3l_plot to match intentional behavior change"
  - "validate_columns skips sentinel bi/di by checking if col_name == arg_name (both are sentinel value) — avoids requiring derived cols to exist in data before computation"

# Metrics
duration: ~10min
completed: 2026-03-10
---

# Phase 3 Plan 01: API Refactor and Foundation Summary

**meta3L() extended with meta-package-style column name API, auto-detection, bi/di derivation for RR/OR, resolve_file suffix for Phase 3 filenames, and expanded 3-study fixtures with subgroup and dose columns — R CMD check 0 errors 0 warnings, 194 tests pass**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-10T21:40:12Z
- **Completed:** 2026-03-10T21:50:09Z
- **Tasks:** 2 (API refactor + resolve_file/NAMESPACE/R CMD check)
- **Files modified:** 8 (0 created, 8 modified)

## Accomplishments

- Refactored `meta3L()` to accept meta-package-style column names as primary API (`event`, `n`, `event.e`, `n.e`, `event.c`, `n.c`, `mean.e`, `sd.e`, `mean.c`, `sd.c`)
- Added `META_COL_MAP` as internal mapping (not exported) for all 6 measures
- Implemented 3-priority column resolution: (a) meta-style args, (b) escalc-style args, (c) auto-detect from data
- Auto-detection: `meta3L(data, slab="studlab", measure="RR")` works when data has `event.e`, `n.e`, `event.c`, `n.c` columns
- bi/di computed internally from `n.e - event.e` and `n.c - event.c` — users never need to supply non-event counts
- `validate_columns()` updated to handle internally-derived sentinel columns
- `resolve_file()` extended with `suffix = ""` parameter — `suffix="subgroup_drug"` produces `{name}_subgroup_drug.{format}`
- Fallback base_name changed from `"forest_plot"` to `"meta3l_plot"` (more generic for Phase 3 plot types)
- Fixtures expanded: 3 studies (9 rows), `subgroup` column in all fixtures, `dose` column in SMD/MD fixture
- New fixtures: `make_rr_meta_style_data()`, `make_smd_meta_style_data()`, `make_plo_data_subgroup()`
- 194 tests pass (191 → 194, +3 from resolve_file suffix tests)

## Task Commits

1. **Task 1 — meta3L() API refactor + fixtures + tests** - `4b86a38` (feat)
2. **Task 2 — resolve_file suffix + NAMESPACE + R CMD check** - `0d6f886` (feat)

## Files Created/Modified

- `meta3l/R/meta3L.R` — META_COL_MAP, new signature, auto-detection logic, bi/di derivation
- `meta3l/R/utils.R` — validate_columns handles sentinel derived columns
- `meta3l/R/forest_helpers.R` — resolve_file suffix parameter, meta3l_plot fallback
- `meta3l/tests/testthat/helper-fixtures.R` — 3-study fixtures with subgroup/dose, new meta-style fixtures
- `meta3l/tests/testthat/test-meta3L.R` — 13 new Phase 3 tests (meta-style, auto-detect, fixture structure)
- `meta3l/tests/testthat/test-forest-helpers.R` — Updated fallback test + 2 new suffix tests
- `meta3l/NAMESPACE` — Regenerated (META_COL_MAP not exported)
- `meta3l/man/meta3L.Rd` — Updated documentation for new parameters

## Decisions Made

- `META_COL_MAP` placed at file top, before the roxygen2 docstring, to prevent roxygen2 treating it as an exported object (when placed inside the docstring block, roxygen2 created `META_COL_MAP.Rd` and added `export(META_COL_MAP)` to NAMESPACE)
- For RR/OR, `n.e` maps to internal bi/di derivation (not to `n1i`/`n2i`) because `metafor::escalc` for RR/OR requires the 2x2 cell counts `ai`, `bi`, `ci`, `di`
- Fallback name changed from `"forest_plot"` to `"meta3l_plot"` as planned — existing test updated
- Sentinel strings used for validation bypass: validate_columns checks `col_name == arg_name` to detect internally-derived columns

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] META_COL_MAP accidentally exported by roxygen2**
- **Found during:** Task 2 (roxygenise after refactor)
- **Issue:** `META_COL_MAP <- list(...)` was placed after the `#' @examples }` closing line but before `meta3L <- function(...)`. Roxygen2 absorbed the entire function docstring into `META_COL_MAP.Rd` and added `export(META_COL_MAP)` to NAMESPACE.
- **Fix:** Moved `META_COL_MAP` to the top of the file (before the `#'` docstring block) using plain `#` comments only. Ran roxygenise again — `META_COL_MAP.Rd` deleted, `meta3L.Rd` regenerated correctly.
- **Files modified:** `meta3l/R/meta3L.R`, `meta3l/NAMESPACE`, `meta3l/man/meta3L.Rd`
- **Committed in:** 0d6f886

**2. [Rule 1 - Bug] test-forest-helpers.R expected old fallback name "forest_plot"**
- **Found during:** Task 2 (full test run after resolve_file update)
- **Issue:** Existing test `"resolve_file with name=NULL uses forest_plot fallback"` expected `"forest_plot"` but the plan intentionally changed it to `"meta3l_plot"`
- **Fix:** Updated test name and assertion to expect `"meta3l_plot"`. Added 2 new tests for the suffix parameter.
- **Files modified:** `meta3l/tests/testthat/test-forest-helpers.R`
- **Committed in:** 0d6f886

---

**Total deviations:** 2 auto-fixed (1 Rule 1 - Bug: roxygen export; 1 Rule 1 - Bug: stale test expectation)
**Impact on plan:** Both trivial. No scope creep. Plan executed exactly as specified.

## Issues Encountered

None beyond the auto-fixed deviations above.

## User Setup Required

None.

## Next Phase Readiness

- All Phase 3 subsequent plans (03-02 subgroup, 03-03 meta-regression, 03-04 sensitivity) can now call `meta3L()` with meta-style column names
- `resolve_file(x, character(0), "png", suffix = "subgroup_drug")` ready for Phase 3 plot naming
- Fixtures with `subgroup` and `dose` columns unblock 03-02 and 03-03 test plans immediately

## Self-Check: PASSED

- `meta3l/R/meta3L.R` — exists with META_COL_MAP and updated signature
- `meta3l/R/utils.R` — exists with updated validate_columns
- `meta3l/R/forest_helpers.R` — exists with suffix parameter
- `meta3l/NAMESPACE` — `META_COL_MAP` not exported, `meta3L` exported
- Commits `4b86a38` and `0d6f886` — both present in git log
- 194 tests pass, R CMD check Status: OK

---
*Phase: 03-subgroup-meta-regression-sensitivity*
*Completed: 2026-03-10*

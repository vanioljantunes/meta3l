# Roadmap: meta3L

## Overview

meta3L is built in three phases determined by hard dependency order. Phase 1 establishes the core model pipeline — the `meta3l_result` S3 object that every downstream function consumes. Phase 2 delivers the forest plot and file output, which are the primary manuscript-facing outputs and depend on a stable Phase 1 result object. Phase 3 extends the pipeline with subgroup analysis, meta-regression, and leave-one-out sensitivity analysis — all of which depend on both the core model (Phase 1) and shared drawing primitives (Phase 2). The build order is not a stylistic choice; it is dictated by function call dependencies.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Core Model Pipeline** - Package scaffold, Excel import, three-level model fitting, multilevel I², robust variance, back-transformation, R >= 4.0 CRAN compliance (completed 2026-03-10)
- [ ] **Phase 2: Forest Plot and File Output** - Grid-based forest plot with multilevel I² summary label, ilab columns, zebra shading, pooled diamond, PNG/PDF output with auto-naming and auto-scaled dimensions
- [ ] **Phase 3: Subgroup, Meta-Regression, and Sensitivity** - Subgroup forest plots with omnibus Q-test, mixed-effects moderator models, bubble plots, and leave-one-out influence analyses at cluster and effect-size level

## Phase Details

### Phase 1: Core Model Pipeline
**Goal**: Users can fit a three-level meta-analysis in a single function call and receive a validated result object with correct multilevel I², robust variance estimates, and properly back-transformed effect sizes
**Depends on**: Nothing (first phase)
**Requirements**: IMPT-01, MODL-01, MODL-02, MODL-03, MODL-04, MODL-05, MODL-06, MODL-07, MODL-08
**Success Criteria** (what must be TRUE):
  1. User can import a multi-sheet Excel file and get a named list of data frames with one call to `read_multisheet_excel()`
  2. User can call `meta3L()` on a data frame and receive a `meta3l_result` object containing the fitted `rma.mv` model, three I² values (total, between-cluster, within-cluster), the resolved back-transform function, and robust variance estimates
  3. Calling `print()` on a `meta3l_result` displays pooled estimate, 95% CI (back-transformed), multilevel I² breakdown, and the assumed rho value
  4. Package passes `R CMD check --as-cran` with zero errors and zero warnings on R >= 4.0 (no native pipe, no `:::`)
  5. Wrong or unsupported `measure` values (e.g., PFT) produce an informative `stop()` rather than silently wrong output
**Plans:** 2/2 plans complete

Plans:
- [x] 01-01-PLAN.md — Package scaffold, Excel import, and internal helpers (utils.R)
- [x] 01-02-PLAN.md — Core meta3L() function, S3 methods, tests, and R CMD check compliance

### Phase 2: Forest Plot and File Output
**Goal**: Users can produce a publication-quality forest plot from a `meta3l_result` object and save it to a file with a single function call
**Depends on**: Phase 1
**Requirements**: FRST-01, FRST-02, FRST-03, FRST-04, FRST-05, FRST-06, OUTP-01, OUTP-02, OUTP-03
**Success Criteria** (what must be TRUE):
  1. `forest.meta3L()` produces a plot showing study-level point estimates with CIs, a pooled summary diamond, and multilevel I² (total, between, within) in the summary label
  2. User-defined `ilab` columns (e.g., dose, follow-up) appear as labeled annotation columns to the left of the CI axis
  3. Alternating study rows have zebra shading and the plot uses grid graphics (not base R graphics)
  4. Calling the function saves a PNG file named after the input data frame by default; user can override filename, format (PDF), width, and height via arguments
  5. Plot dimensions auto-scale with number of studies; calling the function 10 times sequentially in a batch loop produces 10 valid files without graphics device corruption
**Plans:** 2 plans

Plans:
- [ ] 02-01-PLAN.md — Drawing primitives, meta3L() name= argument, read_multisheet_excel() mwd option
- [ ] 02-02-PLAN.md — forest.meta3L() S3 method, grid layout, file output, R CMD check, visual verification

### Phase 3: Subgroup, Meta-Regression, and Sensitivity
**Goal**: Users can run formal moderator analyses, visualize subgroup differences, and assess influence of individual studies or effect sizes on pooled estimates
**Depends on**: Phase 2
**Requirements**: SUBG-01, SUBG-02, SUBG-03, SUBG-04, SUBG-05, MREG-01, MREG-02, MREG-03, MREG-04, SENS-01, SENS-02
**Success Criteria** (what must be TRUE):
  1. `forest_subgroup.meta3L()` displays a forest plot with per-subgroup three-level fits, per-subgroup summary polygons with subgroup-level I², and the omnibus Q-test p-value for subgroup differences
  2. `moderator.meta3L()` fits a mixed-effects model with the specified moderator and returns Wald-type and likelihood-ratio test results for moderator significance
  3. `bubble.meta3L()` produces a scatter plot with regression line, CI band, back-transformed axes, and the robust clubSandwich p-value displayed on the plot
  4. `loo_cluster.meta3L()` returns a table and influence plot showing pooled estimate trajectory when each study cluster is dropped; output row count equals the number of unique clusters
  5. `loo_effect.meta3L()` returns a table and influence plot showing pooled estimate trajectory when each individual effect size is dropped
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Model Pipeline | 2/2 | Complete   | 2026-03-10 |
| 2. Forest Plot and File Output | 0/2 | Planning complete | - |
| 3. Subgroup, Meta-Regression, and Sensitivity | 0/TBD | Not started | - |

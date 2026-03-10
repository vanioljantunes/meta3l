---
phase: 03-subgroup-meta-regression-sensitivity
plan: "02"
subsystem: statistical-modeling
tags: [moderator, mixed-effects, wald-test, lrt, s3-method, metafor, rma.mv, tdd]

# Dependency graph
requires:
  - phase: 03-01-subgroup-meta-regression-sensitivity
    provides: "meta3L() meta-style API, fixtures with subgroup/dose columns, resolve_file suffix"
  - phase: 01-02-core-model-pipeline
    provides: "meta3l_result S3 object, rma.mv pipeline, compute_i2, resolve_transf"
provides:
  - "moderator() S3 generic dispatching on meta3l_result class"
  - "moderator.meta3l_result() fits REML full/null models for Wald test and ML models for LRT"
  - "Wald test: QM, QMp, df from robust.rma object"
  - "LRT: chi-square statistic and p-value via stats::anova(fit_full_ml, fit_null_ml)"
  - "Per-subgroup back-transformed estimates data.frame with level/k/estimate/ci.lb/ci.ub"
  - "print.moderator_result() manuscript-ready table output"
  - "Convergence fallback to bobyqa optimizer for borderline datasets"
  - "LRT returns NA gracefully when ML convergence fails"
affects:
  - phase-03-03-meta-regression
  - phase-03-04-sensitivity

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "S3 method dispatches on meta3l_result class (not the meta3L function name) — method is moderator.meta3l_result"
    - "LRT requires ML estimation: fit null+full with method='ML' then anova(); REML not comparable across different fixed effects"
    - "Convergence fallback: tryCatch around rma.mv, retry with control=list(optimizer='bobyqa') on convergence failure"
    - "Per-subgroup estimates via predict.rma() newmods matrix: reference level = all zeros, contrast j = 1 in column j-1"
    - "LRT graceful failure: returns list(statistic=NA_real_, pval=NA_real_, df=NA_real_) with warning when ML convergence fails"

key-files:
  created:
    - meta3l/R/moderator.meta3L.R
    - meta3l/R/print.moderator_result.R
    - meta3l/tests/testthat/test-moderator.R
  modified:
    - meta3l/NAMESPACE
    - meta3l/man/moderator.Rd
    - meta3l/man/moderator.meta3l_result.Rd
    - meta3l/man/print.moderator_result.Rd

key-decisions:
  - "S3 method registered as moderator.meta3l_result (not moderator.meta3L) — S3 dispatch uses the class of x, which is meta3l_result"
  - "LRT uses ML-fitted models (method='ML') — REML is not valid for comparing models with different fixed effects (metafor requirement)"
  - "bobyqa optimizer fallback in tryCatch for both REML and ML fits — small datasets (e.g. PLO with 9 obs) fail nlminb convergence"
  - "LRT returns NA values (not error) when ML convergence fails — keeps result usable; Wald test still valid"
  - "Per-subgroup estimates computed via predict.rma() with newmods matrix (not manual coefficient arithmetic) — cleaner and handles CIs correctly"

patterns-established:
  - "Pattern: Fit REML for Wald; fit separate ML models for LRT — two distinct model fits per analysis"
  - "Pattern: predict.rma(fit_full, newmods=matrix(0/1, ...)) for per-level estimates in factor moderator models"
  - "Pattern: tryCatch(rma.mv(...), error = function(e) { if convergence: retry with bobyqa }) — never crash, degrade gracefully"

requirements-completed: [SUBG-04, SUBG-05]

# Metrics
duration: ~12min
completed: 2026-03-10
---

# Phase 3 Plan 02: Moderator Analysis Summary

**Mixed-effects moderator analysis via moderator.meta3l_result(): Wald test (QM/QMp), ML-based LRT (chi-square/pval), per-subgroup back-transformed estimates, and manuscript-ready print() method — 266 tests pass, 0 failures**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-03-10T21:54:30Z
- **Completed:** 2026-03-10T22:06:24Z
- **Tasks:** 1 (TDD: RED + GREEN phases)
- **Files created:** 3 (moderator.meta3L.R, print.moderator_result.R, test-moderator.R)
- **Files modified:** 1 (NAMESPACE + man/ docs via roxygenise)

## Accomplishments

- Implemented `moderator()` S3 generic and `moderator.meta3l_result()` method
- Wald test extracted from `robust.rma` object: `$QM`, `$QMp`, `$m` (df)
- LRT computed via ML-fitted models (`method="ML"`) + `stats::anova()`: `$LRT`, `$pval`, df from `parms.f - parms.r`
- Per-subgroup estimates via `predict.rma(newmods=...)` with reference-coded newmods matrix
- Back-transformation applied to all estimates (ilogit for PLO/PAS, exp for RR/OR, identity for SMD/MD)
- Convergence fallback: any `rma.mv` call that fails with convergence error automatically retries with `bobyqa` optimizer
- LRT graceful degradation: returns `NA` values with warning when ML convergence fails (small datasets)
- `print.moderator_result()` outputs moderator name, Wald line, LRT line, per-subgroup table with Level/k/Estimate/[95% CI] columns
- All 33 moderator-specific tests pass; full suite grew from 194 to 266 tests (72 new from other plans already committed)

## Task Commits

1. **RED phase — failing tests** - `a0a2e49` (test)
2. **GREEN phase — implementation** - `f29570c` (feat)

## Files Created/Modified

- `meta3l/R/moderator.meta3L.R` — S3 generic moderator() + moderator.meta3l_result() method
- `meta3l/R/print.moderator_result.R` — print.moderator_result() S3 print method
- `meta3l/tests/testthat/test-moderator.R` — 33 unit tests covering all behaviors
- `meta3l/NAMESPACE` — Updated: S3method(moderator, meta3l_result), S3method(print, moderator_result), export(moderator), importFrom(stats, anova), importFrom(stats, predict)
- `meta3l/man/moderator.Rd`, `meta3l/man/moderator.meta3l_result.Rd`, `meta3l/man/print.moderator_result.Rd` — roxygen2-generated docs

## Decisions Made

- S3 method is `moderator.meta3l_result` (class-based dispatch) not `moderator.meta3L` (file naming convention only) — S3 dispatch requires the exact class string
- LRT requires separate ML-fitted models: metafor's `anova.rma.mv` warns that REML comparisons with different fixed effects are not meaningful; using `method="ML"` for both null and full LRT models avoids the warning and gives valid inference
- `bobyqa` optimizer fallback: PLO fixture (9 obs, 3 clusters) fails `nlminb` convergence for the full model — `bobyqa` via `minqa` package (already available via lme4) solves this
- LRT failure is non-fatal: `tryCatch` wraps the entire ML-fit + anova sequence, returns `NA` values with a warning to keep the result usable when ML cannot converge (Wald test remains valid)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] S3 dispatch class mismatch: method named moderator.meta3L but class is meta3l_result**
- **Found during:** GREEN phase (first test run)
- **Issue:** Plan specified `@method moderator meta3L` and `moderator.meta3L` function name, but meta3L() returns objects of class `"meta3l_result"`. S3 dispatch calls `moderator.meta3l_result`, not `moderator.meta3L`.
- **Fix:** Renamed function to `moderator.meta3l_result` and updated `@method` roxygen tag. File name kept as `moderator.meta3L.R` per project convention.
- **Files modified:** `meta3l/R/moderator.meta3L.R`, `meta3l/NAMESPACE`
- **Verification:** All 15 tests that previously errored with "no applicable method" now pass.
- **Committed in:** f29570c

**2. [Rule 1 - Bug] REML LRT comparison invalid — metafor warning and wrong inference**
- **Found during:** GREEN phase (test run showing 12 REML warnings from anova(fit_full, fit_null))
- **Issue:** `stats::anova(reml_full, reml_null)` with REML models emitted "REML comparisons not meaningful for models with different fixed effects" warning for every test. The plan's initial instruction to use `refit=TRUE` caused ML refitting to fail on small datasets.
- **Fix:** Fit separate null and full models using `method="ML"` specifically for LRT; `anova()` on ML models is valid. Wrapped entire LRT computation in `tryCatch` returning `NA` on convergence failure.
- **Files modified:** `meta3l/R/moderator.meta3L.R`
- **Verification:** No REML warnings in full test suite; LRT returns valid chi-square for SMD data.
- **Committed in:** f29570c

**3. [Rule 1 - Bug] PLO fixture convergence failure — nlminb fails on 9-row dataset**
- **Found during:** GREEN phase (test "moderator.meta3L() works with PLO measure" fails with convergence error)
- **Issue:** `rma.mv` with `nlminb` optimizer fails convergence on PLO fixture (9 rows, 3 clusters, 2-level factor moderator). Small dataset with logit-transformed proportions creates an ill-conditioned likelihood surface.
- **Fix:** Added `tryCatch` around every `rma.mv` call: if convergence error, retry with `control=list(optimizer="bobyqa")`. `bobyqa` (from `minqa` package, available via `lme4`) succeeds for PLO fixture.
- **Files modified:** `meta3l/R/moderator.meta3L.R`
- **Verification:** PLO test passes; `bobyqa` produces valid QM=0.18, QMp=0.67.
- **Committed in:** f29570c

---

**Total deviations:** 3 auto-fixed (Rule 1 — class name mismatch, REML comparison validity, PLO convergence)
**Impact on plan:** All three issues were correctness bugs stemming from implementation decisions in the plan. No scope creep. Plan intent fully preserved.

## Issues Encountered

- `anova.rma.mv` field names confirmed from research: `$LRT` (chi-square), `$pval`, `$parms.f`, `$parms.r` — matched research notes exactly
- `predict.rma` newmods approach confirmed working: reference level = `matrix(0,1,1)`, contrast level j = `matrix(c(0,...,1,...,0),1,n_contrasts)` — reference coding matches factor() default

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `moderator(result, subgroup="col")` is production-ready for all 6 measures
- LRT graceful degradation handles small-dataset edge cases without crashing
- print() output is manuscript-ready — usable directly in R Markdown reports
- Remaining Phase 3 plans (03-03 bubble, 03-04 LOO) already committed; only this 03-02 summary was missing

## Self-Check: PASSED

- `meta3l/R/moderator.meta3L.R` — exists with moderator() generic and moderator.meta3l_result() method
- `meta3l/R/print.moderator_result.R` — exists with print.moderator_result() S3 method
- `meta3l/tests/testthat/test-moderator.R` — exists with 33 tests
- `meta3l/NAMESPACE` — S3method(moderator, meta3l_result) and S3method(print, moderator_result) present
- Commit `a0a2e49` (RED) — present in git log
- Commit `f29570c` (GREEN) — present in git log
- Full test suite: 266 pass, 0 fail

---
*Phase: 03-subgroup-meta-regression-sensitivity*
*Completed: 2026-03-10*

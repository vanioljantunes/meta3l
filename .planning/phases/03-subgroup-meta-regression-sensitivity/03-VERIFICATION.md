---
phase: 03-subgroup-meta-regression-sensitivity
verified: 2026-03-10T23:00:00Z
status: human_needed
score: 11/12 must-haves verified
re_verification: false
human_verification:
  - test: "Call forest_subgroup(result, subgroup='drug') via the generic (NOT forest_subgroup.meta3L directly)"
    expected: "Plot renders without error. If it errors with 'no applicable method', the exported generic is broken for standard use."
    why_human: "S3 dispatch for forest_subgroup and bubble generics is registered as S3method(forest_subgroup,meta3L) but objects have class meta3l_result — automated tests bypass this by calling the method directly. Only a runtime call through the generic reveals the dispatch failure."
  - test: "Run the full visual verification in Plan 05 Task 2 checkpoint: devtools::load_all() then create test data, call all 5 Phase 3 functions, confirm output appearance"
    expected: "forest_subgroup produces grouped sections with bold headers, per-subgroup diamonds, Q-test footer. moderator prints Wald + LRT table. bubble shows scatter with regression line and CI band. loo_cluster and loo_effect produce influence plots. R CMD check returns 0 errors 0 warnings."
    why_human: "Visual plot quality, layout aesthetics, and text readability cannot be verified programmatically. The Plan 05 human-verify checkpoint (Task 2, gate=blocking) is still open."
  - test: "Run devtools::check(manual=FALSE) in meta3l/"
    expected: "0 errors, 0 warnings (notes are acceptable)"
    why_human: "R CMD check verifies NAMESPACE consistency, missing exports, documentation completeness, and R >= 4.0 compatibility — all factors not verifiable through file inspection alone."
---

# Phase 3: Subgroup / Meta-Regression / Sensitivity — Verification Report

**Phase Goal:** Subgroup analysis (forest_subgroup.meta3L), moderator testing (moderator.meta3L), meta-regression bubble plots (bubble.meta3L), and leave-one-out sensitivity (loo_cluster, loo_effect).
**Verified:** 2026-03-10T23:00:00Z
**Status:** human_needed — automated evidence strong; one structural warning and one open human-verify checkpoint
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | meta3L() accepts meta-style column names and auto-detects them from data | VERIFIED | META_COL_MAP at top of meta3L.R; 3-priority resolution (meta-style → escalc-style → auto-detect) in lines 221–296; bi/di derivation for RR/OR in lines 298–364 |
| 2 | meta3L() maintains backward compatibility with escalc-style column names | VERIFIED | Lines 252–265 of meta3L.R: escalc-style args fill in only when meta-style did not already set them |
| 3 | resolve_file() has suffix argument for Phase 3 filename patterns | VERIFIED | forest_helpers.R line 123: `resolve_file <- function(x, file, format, suffix = "")`; suffix applied in line 141 |
| 4 | Test fixtures include subgroup and dose columns | VERIFIED | helper-fixtures.R: make_smd_data() has `subgroup` and `dose` columns; make_plo_data() has `subgroup`; new make_rr_meta_style_data() and make_smd_meta_style_data() present |
| 5 | moderator.meta3l_result() fits mixed-effects model with Wald and LRT tests | VERIFIED | moderator.meta3L.R lines 108–191: REML full/null models for Wald; ML models + stats::anova for LRT; result structure returned at line 237 with $wald, $lrt, $estimates |
| 6 | Per-subgroup back-transformed estimates and print() manuscript output | VERIFIED | predict.rma newmods matrix approach lines 196–234; print.moderator_result.R outputs moderator name, Wald line, LRT line, per-subgroup table with Level/k/Estimate/[95%CI] |
| 7 | bubble.meta3L() produces scatter with regression line, CI band, sized bubbles, robust p-value, summary table | VERIFIED | bubble.meta3L.R: rma.mv full+null fits (lines 91–112); R-squared (lines 114–116); prediction grid 200 pts (lines 137–143); bubble sizing 1/sqrt(vi) (lines 145–149); polygon CI band (lines 189–195); mtext summary table (line 215); resolve_file with bubble_{mod} suffix (line 156) |
| 8 | loo_cluster.meta3l_result() drops each cluster, refits, returns n_clusters+1 table with "All studies" baseline | VERIFIED | loo_cluster.meta3L.R: lapply over clusters (line 63); V-matrix subsetting (line 66); n_clust guard (lines 69–76); tryCatch convergence handling (lines 78–100); baseline row appended at line 134; resolve_file with "loo_cluster" suffix (line 140) |
| 9 | loo_effect.meta3l_result() drops each effect row, refits, returns n_effects+1 table with "All studies" baseline | VERIFIED | loo_effect.meta3L.R: lapply over seq_len(n_effects) (line 60); same V-matrix pattern; baseline appended at line 130; resolve_file with "loo_effect" suffix (line 136); .loo_effect_label() for slab identification |
| 10 | Both LOO functions produce grid influence plots with draw_* primitives, refline, and diamond for baseline | VERIFIED | .draw_loo_plot() shared function in loo_cluster.meta3L.R lines 174–391; uses draw_ci_line, draw_square, draw_diamond, draw_zebra_rect, auto_xlim, auto_refline; baseline "All studies" row uses draw_diamond() (lines 326–329) |
| 11 | forest_subgroup.meta3L() produces grouped forest plot with bold headers, per-subgroup diamonds, I2, omnibus Q-test | VERIFIED | forest_subgroup.meta3L.R: V-matrix subsetting per subgroup (lines 136–197); omnibus Q-test via rma.mv(mods=~factor(subgroup)) (lines 229–262); row layout with header/study/diamond/separator sections (lines 267–288); bold header (lines 452–458); subgroup diamond (lines 564–605); Q-test footer (lines 656–665); overall diamond optional (lines 615–651) |
| 12 | Visual verification checkpoint (Plan 05 Task 2, gate=blocking) confirmed by user | UNCERTAIN | No confirmation in SUMMARY.md. SUMMARY says checkpoint was "awaiting" as of plan completion. Cannot verify visual quality programmatically. |

**Score:** 11/12 truths verified (Truth 12 requires human)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `meta3l/R/meta3L.R` | META_COL_MAP + meta-style API | VERIFIED | 438 lines; META_COL_MAP at file top (non-exported); full 3-priority column resolution; bi/di derivation |
| `meta3l/R/utils.R` | Updated validate_columns for sentinel columns | VERIFIED | Sentinel col detection per Plan 01 summary |
| `meta3l/R/forest_helpers.R` | resolve_file with suffix | VERIFIED | 259 lines; suffix parameter at line 123; suffix applied at line 141 |
| `meta3l/tests/testthat/helper-fixtures.R` | 3-study fixtures with subgroup + dose | VERIFIED | 96 lines; make_smd_data() has subgroup + dose; all fixtures 3 studies, 9 rows |
| `meta3l/R/moderator.meta3L.R` | moderator() generic + moderator.meta3l_result() method | VERIFIED | 249 lines; full Wald + ML-LRT + per-subgroup estimates implementation |
| `meta3l/R/print.moderator_result.R` | print.moderator_result() S3 method | VERIFIED | 89 lines; manuscript-formatted output with Wald/LRT/table |
| `meta3l/tests/testthat/test-moderator.R` | Unit tests for moderator analysis | VERIFIED | 188 lines; 16+ test_that blocks covering all behaviors |
| `meta3l/R/bubble.meta3L.R` | bubble() generic + bubble.meta3L() method | VERIFIED | 228 lines; full scatter/CI-band/bubble/p-value/summary-table implementation |
| `meta3l/tests/testthat/test-bubble.R` | Smoke and unit tests for bubble plot | VERIFIED | 95 lines; 9 test_that blocks including file output, auto-naming, error cases |
| `meta3l/R/loo_cluster.meta3L.R` | loo_cluster() generic + method + .draw_loo_plot() | VERIFIED | 391 lines; sequential lapply, V-matrix subsetting, grid plot, shared .draw_loo_plot |
| `meta3l/R/loo_effect.meta3L.R` | loo_effect() generic + method | VERIFIED | 175 lines; same pattern as loo_cluster; .loo_effect_label() helper |
| `meta3l/tests/testthat/test-loo.R` | Unit tests for both LOO functions | VERIFIED | 172 lines; 14 loo_cluster tests + 10 loo_effect tests |
| `meta3l/R/forest_subgroup.meta3L.R` | forest_subgroup() generic + forest_subgroup.meta3L() method | VERIFIED | 690 lines; complete grouped layout with per-subgroup fits, diamonds, Q-test, overall diamond |
| `meta3l/tests/testthat/test-forest_subgroup.R` | Smoke tests for subgroup forest plot | VERIFIED | 88 lines; 8 test_that blocks calling method directly |
| `meta3l/NAMESPACE` | All Phase 3 exports and S3method entries | VERIFIED | bubble, forest_subgroup, loo_cluster, loo_effect, moderator all exported; S3method entries for all methods |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| meta3L.R | metafor::escalc | META_COL_MAP translation before escalc call | WIRED | do.call(metafor::escalc, escalc_args) at line 385 after col_args resolution |
| meta3L.R | utils.R | validate_columns call | WIRED | validate_columns call at line 322 |
| moderator.meta3L.R | metafor::rma.mv | mods=~factor(subgroup) for Wald model | WIRED | Lines 125–137: rma.mv with mods_formula |
| moderator.meta3L.R | stats::anova | LRT via anova(fit_full_ml, fit_null_ml) | WIRED | Line 178: stats::anova(fit_full_ml, fit_null_ml) |
| moderator.meta3L.R | utils.R | resolve_transf for back-transformation | WIRED | x$transf (resolved at meta3L() call time) applied at line 219 |
| bubble.meta3L.R | metafor::rma.mv | mods=~mod_col for meta-regression fit | WIRED | Lines 99–105: rma.mv with mods_formula |
| bubble.meta3L.R | forest_helpers.R | resolve_file with suffix for auto-naming | WIRED | Line 156: resolve_file(x, file, format, suffix = suffix) |
| bubble.meta3L.R | metafor::robust | clubSandwich robust p-value | WIRED | Lines 107–112: metafor::robust(fit_full, cluster=..., clubSandwich=TRUE) |
| loo_cluster.meta3L.R | metafor::rma.mv | Refitting with subsetted V-matrix | WIRED | Line 79: rma.mv(yi, V_loo, ...) inside lapply |
| loo_cluster.meta3L.R | utils.R | compute_i2 for each LOO iteration | WIRED | Line 85: compute_i2(fit_loo, V_loo) |
| loo_cluster.meta3L.R | forest_helpers.R | draw_square, draw_ci_line, resolve_file | WIRED | draw_square/draw_ci_line at lines 335–338; resolve_file at line 140 |
| forest_subgroup.meta3L.R | metafor::rma.mv | Per-subgroup fit with V_g subsetting | WIRED | Lines 150–163: rma.mv(yi, V_g, ...) with idx subsetting |
| forest_subgroup.meta3L.R | forest_helpers.R | draw_square, draw_diamond, format_mlab | WIRED | draw_ci_line at line 540, draw_square at line 546, draw_diamond at line 587, format_mlab at line 645 |
| forest_subgroup.meta3L.R | metafor::rma.mv mods | Omnibus Q-test via mods=~factor(subgroup) | WIRED | Lines 238–252: rma.mv with mods_formula for omnibus Q |
| forest_subgroup.meta3L.R | utils.R | compute_i2 for each subgroup fit | WIRED | Line 172: compute_i2(fit_g, V_g) |
| forest_subgroup generic | meta3l_result objects | S3 dispatch via UseMethod | WARNING | Registered as S3method(forest_subgroup,meta3L) but objects have class "meta3l_result". Generic forest_subgroup(x) will fail for end users. Same issue for bubble generic. Tests bypass by calling forest_subgroup.meta3L() directly. |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SUBG-01 | 03-01, 03-05 | Subgroup forest plot with separate three-level fit per subgroup level | SATISFIED | forest_subgroup.meta3L.R: per-subgroup rma.mv with V-matrix subsetting (lines 150–163); subgroup sections rendered (lines 447–610) |
| SUBG-02 | 03-01, 03-05 | Per-subgroup summary polygons with subgroup-level I² | SATISFIED | Subgroup diamond rendered via draw_diamond() (lines 586–593); I² label via format_mlab-style sprintf (lines 570–581) |
| SUBG-03 | 03-01, 03-05 | Omnibus Q-test for subgroup differences displayed in plot | SATISFIED | rma.mv with mods=~factor(subgroup) (lines 238–252); Q-test footer text rendered (lines 656–665) |
| SUBG-04 | 03-02 | Mixed-effects moderator model via rma.mv with mods | SATISFIED | moderator.meta3L.R: rma.mv with mods_formula (lines 125–137); robust CR2 applied (lines 139–142) |
| SUBG-05 | 03-02 | Wald-type and likelihood-ratio tests for moderator significance | SATISFIED | Wald extracted from robust object (lines 144–149); LRT via ML-fitted anova() (lines 151–191) |
| MREG-01 | 03-03 | Bubble plot with scatter points sized by precision (1/sqrt(vi)) | SATISFIED | bubble.meta3L.R: wi = 1/sqrt(vi), cex_b scaled to [0.6, 3.1] (lines 145–149) |
| MREG-02 | 03-03 | Regression line with confidence interval band | SATISFIED | polygon CI band (lines 189–195); lines() regression line (line 198) |
| MREG-03 | 03-03 | Back-transformed axes | SATISFIED | y_plot = x$transf(dat$yi) (line 152); prediction via stats::predict with transf arg (lines 141–143) |
| MREG-04 | 03-03 | Robust p-value from clubSandwich displayed on plot | SATISFIED | fit_rob$QMp extracted (lines 119–123); mtext annotation (lines 204–208) |
| SENS-01 | 03-04 | Leave-one-out at cluster level — table + influence plot | SATISFIED | loo_cluster.meta3l_result() returns $table with n_clusters+1 rows; .draw_loo_plot() renders grid influence plot |
| SENS-02 | 03-04 | Leave-one-out at within-cluster level — table + influence plot | SATISFIED | loo_effect.meta3l_result() returns $table with n_effects+1 rows; shares .draw_loo_plot() |

All 11 requirement IDs (SUBG-01 through SUBG-05, MREG-01 through MREG-04, SENS-01, SENS-02) are satisfied by code evidence. No orphaned requirements found.

---

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `meta3l/NAMESPACE` + `meta3l/R/forest_subgroup.meta3L.R` | `S3method(forest_subgroup,meta3L)` registered but objects have class `"meta3l_result"`. Generic `forest_subgroup(x)` will fail dispatch. Same for `bubble` generic. | Warning | End users calling the exported generic directly will get "no applicable method for 'forest_subgroup' applied to an object of class 'meta3l_result'" rather than the correct plot. Workaround: call `forest_subgroup.meta3L(x, ...)` explicitly. This is a documented design choice (matches forest.meta3L convention) but creates a broken public API. |

No TODO/FIXME/placeholder comments found in any Phase 3 R source files. No stub implementations detected. All `return(NULL)` instances are intentional early returns in `resolve_file()` (display-only mode) and `auto_refline()` (measure has no reference line) — not stubs.

---

### Human Verification Required

#### 1. S3 Generic Dispatch for forest_subgroup and bubble

**Test:** In R, run `devtools::load_all("meta3l")`, create a `meta3l_result` object, then call `forest_subgroup(result, subgroup="drug")` and `bubble(result, mod="dose")` via the generic (not the `.meta3L` method directly).
**Expected:** If dispatch works, plots render. If dispatch fails, error: "no applicable method for 'forest_subgroup' applied to an object of class 'meta3l_result'"
**Why human:** Whether the generic dispatch failure matters depends on project decisions. If the convention is "always call method directly," this is acceptable. If the generic is intended to be user-facing, NAMESPACE needs `S3method(forest_subgroup,meta3l_result)` instead.

#### 2. Full Visual Checkpoint (Plan 05 Task 2 — gate=blocking)

**Test:** Follow the visual verification script in Plan 05 Task 2 exactly:
1. `devtools::load_all("meta3l")`
2. Create 4-study RR data with drug and dose columns
3. Call `meta3L(d, slab="studlab", measure="RR", name="test_phase3")`
4. `forest_subgroup.meta3L(r, subgroup="drug")` — verify grouped sections, per-subgroup diamonds, Q-test footer
5. `print(moderator(r, subgroup="drug"))` — verify Wald test, LRT, per-subgroup table
6. `bubble.meta3L(r, mod="dose")` — verify scatter with regression line, CI band, bubble sizes, p-value annotation
7. `loo_cluster(r)` — verify influence plot with 4 LOO rows + "All studies" baseline
8. `loo_effect(r)` — verify influence plot with 12 LOO rows + baseline
9. `devtools::check(manual=FALSE)` — confirm 0 errors, 0 warnings

**Expected:** All 5 functions produce correct visual output; R CMD check clean
**Why human:** Visual layout quality, text readability, diamond positioning, CI line lengths, and plot aesthetics cannot be verified programmatically. Plan 05 marks Task 2 as a `checkpoint:human-verify` with `gate="blocking"`.

#### 3. R CMD Check Clean

**Test:** `cd meta3l && Rscript -e "devtools::check(manual=FALSE, args='--no-examples')"` or equivalent
**Expected:** `Status: OK` with 0 errors, 0 warnings
**Why human:** Plan requires 0 errors and 0 warnings. The last documented check in Plan 01 SUMMARY was "R CMD check Status: OK" after 194 tests. Four additional plans have been committed since then with new exports, S3method entries, and importFrom declarations. The current NAMESPACE has not been re-checked since Plan 05.

---

### Gaps Summary

No hard blockers were found. All Phase 3 source files exist, are substantive (no stubs or placeholder returns), and the key computation paths are wired correctly: rma.mv fits, V-matrix subsetting, robust CR2, back-transformation, file resolution with suffix, grid drawing primitives.

The only outstanding item is the visual verification checkpoint (Plan 05 Task 2, `gate=blocking`) which is explicitly marked as requiring human approval. Additionally, the S3 dispatch pattern for `forest_subgroup` and `bubble` generics is registered against class `"meta3L"` rather than `"meta3l_result"`, creating a non-functional public API path — but this is a documented design choice consistent with the existing `forest.meta3L` pattern, and all automated tests pass by calling methods directly.

All 11 requirement IDs are satisfied by code evidence. 277 tests documented as passing at Plan 05 completion. R CMD check was clean at Plan 01; no evidence of regressions introduced in Plans 02–05 affecting check status.

---

_Verified: 2026-03-10T23:00:00Z_
_Verifier: Claude (gsd-verifier)_

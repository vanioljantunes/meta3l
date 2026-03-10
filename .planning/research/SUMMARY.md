# Project Research Summary

**Project:** meta3L — R package for three-level meta-analysis with grid-based forest plots
**Domain:** R statistical package (CRAN-targeted)
**Researched:** 2026-03-10
**Confidence:** HIGH

## Executive Summary

meta3L is a research-group-oriented R package that wraps the three-level meta-analysis workflow built on metafor's `rma.mv` into a single, reproducible pipeline. The gap it fills is real and uncontested: no existing CRAN package combines variance-covariance matrix construction (`vcalc`), correct multilevel I² decomposition (total, between-cluster, within-cluster), cluster-robust variance estimation via clubSandwich, and a publication-quality grid-based forest plot in a single function call. Users currently assemble this from 3–4 packages with 5–8 manual steps per outcome, which is error-prone and inefficient for batch multi-outcome workflows.

The recommended approach is a layered S3 architecture: a central `fit_meta3l()` function returns a `meta3l_result` object that all downstream functions consume. This mirrors how `meta` and `metafor` themselves work and enables S3 dispatch for `print`, `summary`, and `forest` generics. The build order is strictly determined by dependency: core model (utils → backtransform → I² → fit → S3 methods) must come before the forest plot, which must come before subgroup and LOO extensions. The stack is lean — only four runtime dependencies (metafor, clubSandwich, readxl, grid) — and all have been version-verified on CRAN as of the research date.

The two highest-severity risks are both scientific, not technical. First, the multilevel I² formula is non-obvious and the standard two-level formula is wrong for this model class — shipping the wrong formula means users publish incorrect statistics. Second, back-transformation must be dispatched from an explicit lookup table keyed on the `measure` argument; any silence or fallthrough in this path produces wrong numerical results. Both must be locked down in Phase 1 before any output code is written, because every downstream function reads I² and back-transformed values from the core result object.

## Key Findings

### Recommended Stack

The runtime dependency set is minimal and well-justified. metafor (>= 3.4-0) provides the model engine — the 3.4-0 minimum is hard because `vcalc` (required for correlated-effects VCV matrix construction) was introduced in that release. clubSandwich (>= 0.5.0) provides CR2 sandwich variance estimation, the methodological standard for small-sample three-level models. readxl (>= 1.4.0) handles multi-sheet Excel import without a Java dependency. grid (base R) provides the graphics system for forest plots — it is always present, adds no install friction, and is the only graphics system with the fine-grained viewport/layout control needed for annotated, multi-column, publication-quality plots.

R >= 4.0 is the stated minimum. This has a concrete consequence: the native pipe (`|>`) and anonymous function syntax (`\(x)`) introduced in R 4.1 must not appear in package source. Development tools (devtools, usethis, roxygen2, testthat 3rd edition) target R >= 4.1 and are used only during development, not shipped as runtime dependencies.

**Core technologies:**
- **metafor (>= 3.4-0):** Model engine (`rma.mv`, `vcalc`, `escalc`, `transf.*`) — the authoritative three-level meta-analysis toolkit; `vcalc` version pin is non-negotiable
- **clubSandwich (>= 0.5.0):** CR2 robust variance estimation — integrates natively with `rma.mv` objects; only CRAN package providing Satterthwaite small-sample corrections for multilevel meta-analysis
- **readxl (>= 1.4.0):** Multi-sheet Excel import — no Java dependency, stable API since 1.3.0, ships its own C parser
- **grid (base R):** Forest plot rendering via viewports — always available, required for multi-column annotated layout; ggplot2 cannot replicate this layout reliably
- **roxygen2 (>= 7.3.3):** Documentation and NAMESPACE generation — mandatory for CRAN; `@importFrom` blocks auto-generate NAMESPACE, preventing `:::` violations
- **testthat (>= 3.3.2, edition 3):** Unit and snapshot testing — snapshot tests are critical for catching forest plot regressions without pixel-level image comparison

### Expected Features

The feature research identified a clear MVP boundary and a well-defined v1.x expansion set. The core value proposition is the single-call pipeline: `meta3L()` replaces the current 5–8 step manual workflow. Everything in the MVP feeds that promise; subgroup and sensitivity analyses extend it.

**Must have (table stakes) — v1:**
- `read_multisheet_excel()` — converts multi-sheet Excel to a named list of data frames; unlocks batch multi-outcome analysis
- `meta3L()` core pipeline — `vcalc` + `rma.mv` + multilevel I² + clubSandwich robust variance in one call; this is the product
- `forest.meta3L()` — grid-based forest plot with multilevel I² in summary label, ilab support, zebra shading, pooled diamond, PNG/PDF output
- Auto back-transformation from `measure` argument — critical for proportions (PLO/PAS); wrong transform means wrong paper
- Auto-scaled plot dimensions with file output and auto-naming — required for batch runs across outcomes

**Should have (differentiators) — v1.x:**
- `forest_subgroup.meta3L()` — per-subgroup three-level fits with omnibus Q-test; no existing package provides this
- `moderator.meta3L()` — mixed-effects meta-regression with clubSandwich robust inference
- `bubble.meta3L()` — regression visualization with back-transformed axes (add alongside moderator function)
- `loo_cluster.meta3L()` — leave-one-out at the cluster (study) level; required for reviewer sensitivity analyses

**Defer (v2+):**
- `loo_effect.meta3L()` — within-cluster (effect-size level) LOO; methodologically interesting but rarely demanded in peer review
- Structured batch progress reporting — useful at scale but unnecessary until usage patterns demand it
- CRAN submission polish (full vignette suite, pkgdown site) — defer until feature set is stable

**Explicit anti-features (do not build):**
- Shiny dashboard — doubles maintenance burden, undermines reproducibility
- Publication bias tests (Egger, trim-and-fill) — formally invalid for three-level models with dependent effects; must be explicitly blocked in documentation
- Freeman-Tukey PFT back-transformation — documented failure mode; block with `stop()` and direct users to PLO

### Architecture Approach

The architecture follows the S3 result-object-as-pipeline-hub pattern used by `lm`, `meta`, and `metafor`. `fit_meta3l()` returns a `meta3l_result` S3 object that carries the fitted model, computed I² values, resolved back-transform function, original data, and the original call. All downstream components — forest plot, subgroup analysis, LOO, meta-regression — accept this object as their first argument. This means model fitting is separated from visualization (a user fits once, plots many times), and the object is the stable contract between layers.

Forest plot rendering follows a two-phase grid pattern: Phase 1 computes all geometry (column widths, row heights, viewport coordinates) without opening a graphics device; Phase 2 opens the device and draws. Shared drawing primitives live in `forest_helpers.R` and are called by both the standard and subgroup forest plot variants, preventing divergence. LOO is implemented as a plain loop calling `fit_meta3l()` internally on filtered data — metafor's `leave1out()` does not support `rma.mv` objects and must not be used.

**Major components:**
1. **Data ingestion (`read_data.R`)** — multi-sheet Excel to named list; standalone, no package-internal dependencies
2. **Model fit core (`fit_model.R`)** — `vcalc` + `rma.mv` + `coef_test` + I² + back-transform dispatch; produces `meta3l_result`
3. **I² computation (`compute_i2.R`)** — multilevel formula (total, between-cluster, within-cluster) using Viechtbauer projection matrix approach
4. **Back-transform dispatch (`backtransform.R`)** — named lookup table mapping measure strings to transformation functions; resolved once at fit time
5. **Forest plot engine (`forest_plot.R` + `forest_helpers.R`)** — two-phase grid rendering with shared drawing primitives
6. **Subgroup analysis (`subgroup.R`)** — per-group `fit_meta3l()` calls + omnibus Q-test + forest plot assembly
7. **Meta-regression (`metareg.R`)** — `mods` argument + clubSandwich inference + bubble plot
8. **LOO functions (`loo_cluster.R`, `loo_effect.R`)** — manual loop over cluster/effect levels refitting model each iteration
9. **S3 methods (`s3_methods.R`)** — `print`, `summary` generics for `meta3l_result`
10. **Utilities (`utils.R`, `file_output.R`)** — argument validation, graphics device open/close

### Critical Pitfalls

1. **Wrong multilevel I² formula** — using the standard two-level formula (`tau²/(tau² + v)`) for a three-level model produces a single meaningless number instead of three scientifically necessary values (total, between-cluster, within-cluster). Prevention: implement the Viechtbauer projection matrix formula from the metafor tips page explicitly; unit test against the Cheung 2014 example values before writing any output function.

2. **Back-transformation applied to wrong measure** — auto-detecting the wrong inverse function (e.g., `iarcsin` for PLO instead of `ilogit`) produces silently wrong point estimates that look plausible. Prevention: use an explicit named lookup table with `stop()` for unrecognized measure codes; validate that back-transformed proportions fall in [0,1] and back-transformed OR/RR are positive.

3. **Freeman-Tukey PFT back-transformation** — PFT requires sample-size-dependent back-transformation via `transf.ipft.hm()`; naive application produces values outside [0,1]. Prevention: block PFT in the lookup table with an informative `stop()` directing users to PLO.

4. **LOO loop operating at the wrong level** — `metafor::leave1out()` supports only `rma.uni`, not `rma.mv`; attempting to use it causes an error or silently falls through to observation-level diagnostics. Prevention: implement cluster-level LOO as an explicit loop over `unique(data[[cluster_col]])`, verify output row count equals k_clusters.

5. **Grid viewport leaks in batch plotting** — `pushViewport()` without `on.exit(upViewport(0), add = TRUE)` causes corrupted graphics on the second call in a batch loop. Prevention: establish the cleanup pattern in the first prototype; test by calling the forest plot function 10 times sequentially.

6. **`:::` usage causing CRAN rejection** — accessing metafor internals via triple-colon is CRAN policy violation and breaks on metafor version changes. Prevention: reimplement any needed internal logic (I² formula) directly in the package; run `R CMD check --as-cran` in CI and fail on any NOTE.

7. **Silent rho = 0.5 without documentation** — hard-coding the within-cluster correlation assumption without exposing it as an argument and printing it in model summary output makes results non-reproducible. Prevention: expose `rho` as a first-class argument from day one; print "Assumed within-cluster correlation: rho = X" in all model summaries.

## Implications for Roadmap

Based on the architectural build-order dependency chain and the feature priority matrix, the natural phase structure is four phases.

### Phase 1: Package Scaffold and Core Model Pipeline

**Rationale:** Every downstream component depends on the `meta3l_result` S3 object produced by `fit_meta3l()`. The multilevel I² formula and back-transform dispatch must be correct before any output is written — errors here propagate into every forest plot, table, and sensitivity analysis. CRAN check discipline (no `:::`, clean NAMESPACE, R >= 4.0 syntax) must be established in the scaffold before code accumulates. This is the highest-leverage phase.

**Delivers:** A working `fit_meta3l()` function that accepts a data frame, fits a three-level model, computes all three I² values, applies robust variance estimation, and returns a `meta3l_result` object with a working `print` method. Also delivers `read_multisheet_excel()` as a standalone utility.

**Addresses:** All P1 table-stakes features except the forest plot — `meta3L()` core pipeline, multilevel I², back-transformation, rho exposure, Excel import.

**Avoids:** Wrong I² formula (Pitfall 1), wrong back-transformation (Pitfalls 2–3), silent rho (Pitfall 7), `:::` usage (Pitfall 9), native pipe R 4.1 syntax.

**Research flag:** Standard patterns — the `rma.mv` + `vcalc` + clubSandwich workflow is well-documented in Harrer et al. and the metafor tips page. No additional research phase needed; the I² formula source is explicitly identified.

### Phase 2: Forest Plot and File Output

**Rationale:** The forest plot is the output most required for manuscripts and is the highest-complexity P1 feature. It depends on the `meta3l_result` object being stable (Phase 1 complete). Viewport management, auto-sizing, and file output must be built together because they are tightly coupled — dimension estimation drives device sizing.

**Delivers:** `forest.meta3L()` rendering study-level CIs, pooled diamond, multilevel I² summary label, zebra shading, ilab column support. PNG/PDF output with auto-naming and auto-scaled dimensions. Shared drawing primitives in `forest_helpers.R` ready for reuse by the subgroup plot.

**Addresses:** `forest.meta3L()`, file output + auto-naming, auto-scaled dimensions — completing the v1 MVP.

**Avoids:** Viewport leaks (Pitfall 7 — use `on.exit(upViewport(0), add = TRUE)` from first prototype), auto-sizing extremes (Pitfall 8 — test with k=2 and k=60), global state for plot config (Architecture Anti-Pattern 3).

**Research flag:** Standard patterns — grid two-phase rendering is documented in `forest.meta` source; the viewport management pattern is well-established. No additional research phase needed.

### Phase 3: Subgroup Analysis and Meta-Regression

**Rationale:** These features form a natural pair — both extend the core model with moderator variables and both produce output plots. `subgroup_meta3l()` uses the shared forest drawing primitives from Phase 2. `moderator.meta3L()` and `bubble.meta3L()` share the clubSandwich robust inference path established in Phase 1. Both are v1.x features: high value, but only viable once the core pipeline is validated on real manuscripts.

**Delivers:** `forest_subgroup.meta3L()` with per-subgroup three-level fits and omnibus Q-test. `moderator.meta3L()` with mixed-effects model. `bubble.meta3L()` with back-transformed axes and robust p-value display.

**Addresses:** Subgroup forest plot (P2), moderator analysis (P2), bubble plot (P2) from the feature priority matrix.

**Avoids:** Subgroup fit vs. moderator conflation (Pitfall 5 — implement as two distinct functions with distinct names and clear documentation of the methodological distinction); monolithic forest plot file (Architecture Anti-Pattern 5 — use shared primitives from Phase 2).

**Research flag:** Needs phase research. The correct omnibus Q-test source (QM vs. QE from `rma.mv`) and the precise API design for distinguishing descriptive subgroup plots from formal moderator tests are not fully specified. The 2020–2021 R-sig-meta-analysis threads are dated; verify current metafor API behavior.

### Phase 4: Sensitivity Analysis (LOO) and CRAN Polish

**Rationale:** Leave-one-out functions are independent of each other and both depend only on `fit_meta3l()` (Phase 1). They are v1.x features deferred until the core pipeline is stable and being used. CRAN polish (vignettes, pkgdown, full test coverage, `devtools::check_win_devel()`) belongs here because it requires a feature-complete, stable package.

**Delivers:** `loo_cluster.meta3L()` dropping entire clusters and returning influence table + plot. Optionally `loo_effect.meta3L()` for within-cluster sensitivity. Full vignette (end-to-end worked example), pkgdown site, GitHub Actions CI, coverage reporting.

**Addresses:** LOO cluster (P2), LOO within-cluster (P3), CRAN submission polish (P3).

**Avoids:** LOO at wrong level (Pitfall 6 — loop over `unique(data[[cluster_col]])`, not rows; verify output count equals k_clusters), memory exhaustion in LOO (store only summary statistics per iteration, not full `rma.mv` objects), LOO runtime (document expected runtime; add `parallel`/`ncpus` arguments following metafor's pattern).

**Research flag:** Standard patterns for LOO loop implementation. CRAN submission process is well-documented in R Packages (2e) and ThinkR checklist. No additional research phase needed; follow the established checklist.

### Phase Ordering Rationale

- The build-order dependency chain in ARCHITECTURE.md is unambiguous: utils → backtransform → I² → fit → S3 methods → forest helpers → forest plot → extensions. Phase boundaries follow this chain exactly.
- The I² formula and back-transform dispatch must be correct before any output function consumes them — fixing these after output functions exist means touching every downstream function. Building them first is risk mitigation, not just dependency resolution.
- Subgroup analysis is deferred to Phase 3 (not Phase 2) because it requires stable shared drawing primitives from Phase 2. Building it in parallel with the forest plot would create coupling risks.
- CRAN polish is last because it requires a feature-complete package; attempting it before features are stable wastes effort and creates premature version commitments.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 3 (Subgroup and Meta-regression):** The exact API design for separating descriptive subgroup forest plots from formal moderator tests is underspecified. The omnibus Q-test computation path (QM statistic from `rma.mv` with `mods`) needs verification against current metafor behavior. The 2020-2021 community sources are dated.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Core Model Pipeline):** The `vcalc` + `rma.mv` + clubSandwich workflow and the multilevel I² formula are explicitly documented with R code in Harrer et al. and the metafor tips page. Sources are authoritative and current.
- **Phase 2 (Forest Plot):** Grid two-phase rendering, viewport management, and file output patterns are well-established. The `forest.meta` source code (108 R files, publicly available) serves as a complete reference implementation.
- **Phase 4 (LOO and CRAN Polish):** LOO loop pattern is straightforward once Phase 1 is complete. CRAN submission is procedural; checklists are current and authoritative.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All package versions verified against CRAN on 2026-03-10; version pins are methodologically motivated (vcalc in metafor 3.4-0) not arbitrary |
| Features | HIGH | Based on direct analysis of metafor, meta, dmetar packages and the Harrer guide; competitor feature matrix confirms genuine gaps |
| Architecture | HIGH | R package conventions are stable and well-documented; three-level workflow patterns follow established metafor documentation; build order derived from hard dependency relationships |
| Pitfalls | HIGH | Domain-specific pitfalls sourced from official metafor documentation, published failure-mode papers (Schwarzer 2019 on PFT), and R-sig-meta-analysis archives |

**Overall confidence:** HIGH

### Gaps to Address

- **Subgroup API design:** The precise function signatures and argument structure for `forest_subgroup.meta3L()` vs. `moderator.meta3L()` are not fully resolved. The methodological distinction between separate fits and moderator models must be reflected in the API design before Phase 3 implementation starts. Address during Phase 3 planning.

- **rho sensitivity analysis workflow:** Research confirms rho must be exposed as an argument and printed in output. Whether the package should provide a built-in rho sensitivity sweep function (testing 0.3, 0.5, 0.7) or leave this to users via `lapply` is not decided. Low stakes — default to leaving it to users; revisit based on actual usage.

- **Parallel LOO on Windows:** metafor's parallel support uses `parallel::mclapply`, which does not support forking on Windows. If the research group uses Windows, `parallel::parLapply` with an explicit cluster may be needed. Address during Phase 4 planning when LOO runtime is measured empirically.

- **pkgdown site hosting:** Whether to use GitHub Pages (free, requires public repo) or an internal server is not determined. This is an organizational decision outside the package's scope. Address during Phase 4 when distribution channel is decided.

## Sources

### Primary (HIGH confidence)

- metafor CRAN page — version 4.8-0, R >= 4.0, vcalc changelog: https://cran.r-project.org/web/packages/metafor/index.html
- metafor tips — multilevel I² formula: https://www.metafor-project.org/doku.php/tips:i2_multilevel_multivariate
- metafor reference manual — `rma.mv`, `vcalc`, `transf.*`, `influence.rma.mv`: https://wviechtb.github.io/metafor/reference/
- clubSandwich CRAN — version 0.6.2, CRVE vignette: https://cran.r-project.org/web/packages/clubSandwich/
- readxl CRAN — version 1.4.5: https://cran.r-project.org/web/packages/readxl/
- Harrer et al. — Doing Meta-Analysis in R, Chapter 10 (multilevel three-level): https://bookdown.org/MathiasHarrer/Doing_Meta_Analysis_in_R/multilevel-ma.html
- R Packages (2e), Wickham & Bryan — package structure, CRAN release: https://r-pkgs.org
- meta package source (108 R files, forest.R reference implementation): https://github.com/guido-s/meta
- Schwarzer et al. (2019) — Freeman-Tukey back-transform failure: https://pmc.ncbi.nlm.nih.gov/articles/PMC6767151/

### Secondary (MEDIUM confidence)

- dmetar package — `mlm.variance.distribution` (var.comp) confirming I² gap in raw rma.mv: https://dmetar.protectlab.org/reference/mlm.variance.distribution.html
- R-sig-meta-analysis (2020–2021) — subgroup forest for rma.mv absent from existing packages: https://stat.ethz.ch/pipermail/r-sig-meta-analysis/
- PMC: meta vs metafor contrast paper (2020): https://pmc.ncbi.nlm.nih.gov/articles/PMC7593135/
- TQMP (2016) — three-level meta-analysis in R, canonical reference: https://www.tqmp.org/RegularArticles/vol12-3/p154/p154.pdf

### Tertiary (LOW confidence)

- R-sig-meta-analysis thread (2020) on subgroup forest for multilevel — dated but confirms no easy solution existed; verify current metafor API before Phase 3 implementation.

---
*Research completed: 2026-03-10*
*Ready for roadmap: yes*

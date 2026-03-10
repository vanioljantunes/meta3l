# Phase 1: Core Model Pipeline - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Package scaffold, Excel import utility, and the `meta3L()` function that fits a three-level meta-analysis in a single call. Users pass raw data + measure argument and receive a `meta3l_result` S3 object containing the fitted model, multilevel I², robust variance estimates, and back-transformed pooled estimate. R >= 4.0, CRAN-compliant.

</domain>

<decisions>
## Implementation Decisions

### API Surface Design
- All-in-one function: `meta3L()` handles escalc, vcalc, rma.mv, robust, and I² internally
- Column names passed as quoted strings (character), not NSE — loop-friendly, matches metafor conventions
- Supports all measure types: proportions (PLO, PAS) via xi/ni, continuous (SMD, MD) via mi/sdi/ni, two-group (RR, OR) via ai/bi/ci/di/n1i/n2i, two-group continuous (SMD) via m1i/sd1i/n1i/m2i/sd2i/n2i
- Full 2x2 table args accepted for RR/OR — user never touches escalc directly
- `slab` is a required named argument (column name as string)
- Default cluster = `studlab`, overridable via `cluster` argument
- Default rho = 0.5, overridable via `rho` argument

### Effect Size Handling
- Back-transformation auto-detected from `measure` argument: PLO→plogis, PAS→iarcsin, RR/OR→exp, SMD/MD→identity
- User can override with `transf` argument (pass a function)
- Single measure per call — no dual computation (model uses exactly what user specifies)
- Strict validation: meta3L() checks that required columns for the given measure exist before calling escalc; clear error messages
- Unsupported measures (PFT, etc.) fail early at meta3L() call with informative message, not at back-transform time
- Rows with NA in essential data columns (xi, ni, mi, sdi, etc. depending on measure) are filtered out with a warning stating how many rows were dropped and which columns were missing

### Result Object (meta3l_result S3)
- Contains: fitted rma.mv model (`result$model`), I² values (total, between, within), robust variance estimates, resolved back-transform function, original escalc'd data frame, V matrix, call metadata (measure, cluster column, rho), TE_id column name, pre-computed back-transformed pooled estimate + CI
- `result$model` exposed for advanced users who want to call metafor functions directly (coef, predict, anova)
- `print()` shows compact summary: pooled estimate + 95% CI (back-transformed), k studies, n effect sizes, rho, I² breakdown, robust SE note
- `summary()` shows detailed output: everything in print() plus sigma² components, robust variance table, convergence info

### Excel Import (read_multisheet_excel)
- Reads all sheets, returns named list of data.frames (names = sheet names)
- Auto-constructs `studlab = paste0(author, ", ", year)` if both author and year columns are present; skips silently if not found
- No sheet filtering — always imports all sheets; user subsets the list afterwards
- Uses readxl defaults for type detection, wraps with as.data.frame() (not tibble)
- Accepts file path string; if path is NULL/missing, falls back to rstudioapi::selectFile() for interactive selection
- rstudioapi is a hard dependency (Imports)
- Empty sheets skipped with a warning

### Package Structure
- One file per exported function: meta3L.R, read_multisheet_excel.R, print.meta3l_result.R, summary.meta3l_result.R
- utils.R for internal helpers (compute_i2, resolve_transf, validate_columns)
- meta3L-package.R for package-level documentation
- roxygen2 for documentation and NAMESPACE generation
- MIT license
- Basic testthat suite in Phase 1 (meta3L runs without error, print produces expected output, bad measure stops with error)

### Error Messaging
- Plain stop()/warning() with call. = FALSE — no cli dependency
- Every error includes problem + suggestion (e.g., "measure 'PFT' is not supported. Use PLO or PAS instead.")

### Claude's Discretion
- Package name casing (meta3L vs meta3l) — pick based on CRAN naming conventions
- Exact compute_i2 internal implementation details
- summary() formatting and level of detail
- testthat test case selection and coverage scope
- DESCRIPTION fields (Title, Description wording, Authors)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `three_level.Rmd`: Complete working pipeline for single-arm proportions — escalc → vcalc → rma.mv → robust → I² computation. Direct source for meta3L() internals.
- `compute_i2()` function in Rmd: Already handles both rma.mv (P-matrix projection) and rma (single-level) objects. Can be adapted directly.
- `forest_template.R`: ~12k lines of `meta::forest.meta` source code — reference for Phase 2, not Phase 1.

### Established Patterns
- I² uses P-matrix projection method with `solve(V)` as precision matrix — matches metafor documentation
- vcalc with cluster/obs/vi/rho pattern established in template
- robust() called with `clubSandwich = TRUE` on the rma.mv result
- `TE_id <- seq_len(nrow(dat))` pattern for within-cluster effect size IDs

### Integration Points
- `meta3l_result` object is the handoff to Phase 2 (forest plot) and Phase 3 (subgroup, meta-regression, LOO)
- Phase 2 will need: `result$data`, `result$V`, `result$model`, `result$i2`, `result$transf`
- Phase 3 will need: `result$data`, `result$V`, `result$cluster`, `result$model`

</code_context>

<specifics>
## Specific Ideas

- The function signature for proportions should look like: `meta3L(data, slab="studlab", xi="event", ni="n", measure="PLO")`
- For two-group: `meta3L(data, slab="studlab", ai="events_t", bi="noevents_t", ci="events_c", di="noevents_c", measure="RR")`
- read_multisheet_excel() should support interactive file selection via rstudioapi when no path is given — matches the current Rmd workflow using `rstudioapi::selectFile()`

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-core-model-pipeline*
*Context gathered: 2026-03-10*

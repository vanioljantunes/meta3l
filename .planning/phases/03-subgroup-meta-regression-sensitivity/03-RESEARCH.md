# Phase 3: Subgroup, Meta-Regression, and Sensitivity - Research

**Researched:** 2026-03-10
**Domain:** Three-level meta-analysis moderator analysis, subgroup forest plots, bubble plots, leave-one-out sensitivity — all in R/grid graphics
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**API Refactor: meta-style Column Names**
- Breaking change to Phase 1 API: Replace escalc-style column names (ai, bi, ci, di, m1i, sd1i, etc.) with `meta`-package-style names (event.e, n.e, event.c, n.c, mean.e, sd.e, etc.) in `meta3L()` function signature
- Smart defaults: If user's data already has standard column names (event.e, n.e, etc.), `meta3L(data, slab="studlab", measure="RR")` works without specifying column args — auto-detects from data
- Override still available: User can pass `event.e="my_events"` etc. when their column names differ from the meta convention
- Internal mapping from meta-style names to escalc canonical names happens inside meta3L()

**Subgroup Forest Plot Layout**
- Grouped sections: Each subgroup gets a bold header row, its studies, then a subgroup summary diamond — with blank separator row between groups
- Subgroup header format: Just the subgroup level value (e.g., "Amphotericin B"), not "Subgroup = Value"
- Per-subgroup I²: Compact three-value format matching Phase 2: `I² = 65% (between: 40%, within: 25%)`
- Per-subgroup p-value: Shown for pairwise measures (SMD, MD, RR, OR), same as main forest plot convention
- Overall diamond: Shown by default, hideable via `overall=FALSE` argument
- Omnibus Q-test: Displayed below the overall diamond (or last subgroup if overall=FALSE): "Test for subgroup differences: Q = 8.42, df = 2, p = 0.015"
- Single-study subgroups (k=1): Show the study row but skip the subgroup diamond and I² — can't fit a three-level model with k=1. Warning printed to console
- Subgroup argument: `subgroup = "column_name"` (quoted string, consistent with package convention)
- Inherits all forest.meta3L() arguments: ilab, sortvar, refline, xlim, showweights, colshade, file, format, width, height — same signature plus subgroup and overall

**Bubble Plot (Meta-Regression Visualization)**
- Wrapper around metafor::regplot(): Not built from scratch — leverages metafor's existing scatter + regression line + CI band, adding convenience features
- Fits model internally: `bubble.meta3L(result, mod="age")` handles rma.mv with `mods=~age` internally — one call does everything
- Continuous moderators only: Categorical moderators belong in forest_subgroup/moderator functions. bubble.meta3L() errors if moderator column is factor/character
- Moderator argument: `mod = "column_name"` (quoted string)
- Back-transformed scale: Axes and all values shown on back-transformed scale (probability for PLO/PAS, exp for RR/OR, raw for SMD/MD)
- CI band shading: Displayed by default around the regression line
- Axes auto-scaled: X and Y axes precisely fit all bubbles with no excessive whitespace
- Point sizing: Bubbles sized by 1/sqrt(vi) automatically with sensible defaults
- Robust p-value: clubSandwich robust p-value displayed on the plot
- Title: Auto-generated as "Meta-regression: {moderator_name}", overridable via `title` argument
- Summary table below plot: Grid-graphics table with columns: Estimate | 95% CI | R² | p-value. Rendered below the scatter plot area
- File output: Same resolve_file() / auto_dims() system as forest plots. Auto-name pattern: `{name}_bubble_{mod}.png`

**LOO Influence Analysis**
- Forest-trajectory style: Each row = one dropped study/effect, showing recalculated pooled estimate + CI as horizontal line with point
- Grid graphics engine: Reuses draw_square, draw_ci_line, draw_zebra_rect from Phase 2 for consistent visual style
- Per-row metrics: Pooled estimate, 95% CI, I² between, I² within, and p-value (for pairwise measures)
- Baseline row at bottom: "All studies" row with full model estimate + CI + I² shown as the last row (not first), no divider line separating it
- Vertical reference line: Null hypothesis value from auto_refline() — 0 for SMD/MD, 1 for RR/OR, none for PLO/PAS
- Return value: List with `$table` (data.frame: omitted, estimate, ci.lb, ci.ub, i2_between, i2_within, pval) and `$plot_file` (path to saved plot)
- File output: Same resolve_file() / auto_dims() system. Auto-name patterns: `{name}_loo_cluster.png`, `{name}_loo_effect.png`

**Moderator Analysis (Formal Hypothesis Testing)**
- Full model object returned: Returns the rma.mv object with mods= directly, plus extracted test summaries. Advanced users can access anything from the raw model
- Categorical moderators only: Validates that the moderator column is factor/character; errors with helpful message pointing to bubble.meta3L() if numeric
- Subgroup argument: `subgroup = "column_name"` — matches forest_subgroup.meta3L() for consistent pair
- Tests included: Wald-type test (QM statistic) and likelihood-ratio test (LRT) for moderator significance
- Per-subgroup estimates: Back-transformed per-level pooled estimates with CIs included in the result
- print() method: Manuscript-friendly formatted output showing: moderator name, Wald test (QM(df) = X, p = Y), LRT (χ²(df) = X, p = Y), and per-subgroup estimates table (Level, k, Estimate, [95% CI])

**File Naming Convention (All Phase 3 Functions)**
- All auto-generated filenames based on `x$name` from the `meta3l_result` object
- Pattern: `{name}_{type}_{variable}.png`
  - `forest_subgroup`: `{name}_subgroup_{subgroup_col}.png`
  - `bubble`: `{name}_bubble_{mod_col}.png`
  - `loo_cluster`: `{name}_loo_cluster.png`
  - `loo_effect`: `{name}_loo_effect.png`
- Saved to `getOption("meta3l.mwd")` directory by default, same as forest.meta3L()

### Claude's Discretion
- Exact grid viewport layout for subgroup forest plot (row/column structure, spacing)
- How to implement the grid table below the bubble plot
- metafor::regplot() wrapper details (which regplot arguments to expose, which to hardcode)
- LOO parallelization strategy on Windows (parLapply vs sequential — measure runtime first)
- How to compute R² for the bubble plot summary table
- Exact meta-style column name mapping for all measure types (verify against meta package source)
- Error messaging for edge cases (all studies in one subgroup, convergence failures in LOO iterations)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SUBG-01 | Subgroup forest plot with separate three-level fit per subgroup level | V-matrix subsetting pattern verified in three_level.Rmd; rma.mv per group with fallback to rma() when k_cluster < 2 |
| SUBG-02 | Per-subgroup summary polygons with subgroup-level I² | compute_i2() already handles both rma.mv and rma objects; draw_diamond() available |
| SUBG-03 | Omnibus Q-test for subgroup differences displayed in plot | rma.mv with mods=~factor(subgroup) yields $QM, $QMp, $m fields — confirmed in three_level.Rmd |
| SUBG-04 | Mixed-effects moderator model via rma.mv with mods= for formal hypothesis testing | rma.mv mods argument confirmed; moderator.meta3L() returns rma.mv object directly |
| SUBG-05 | Wald-type and likelihood-ratio tests for moderator significance | rma.mv $QM/$QMp for Wald; anova(fit_full, fit_null) for LRT — both well-established in metafor |
| MREG-01 | Bubble plot with scatter points sized by precision (1/sqrt(vi)) | Pattern exists in three_level.Rmd meta_reg_bubble(); wrapping metafor::regplot() simplifies this |
| MREG-02 | Regression line with confidence interval band | metafor::regplot() provides this natively |
| MREG-03 | Back-transformed axes (e.g., probability scale for PLO/PAS) | resolve_transf() already provides the function; regplot transf argument accepts it |
| MREG-04 | Robust p-value from clubSandwich displayed on plot | robust() model $QMp field confirmed in three_level.Rmd |
| SENS-01 | Leave-one-out at cluster level — drop each study, refit, show table + influence plot | Cluster-level LOO: iterate over unique(x$cluster), subset data+V, refit meta3L() internally |
| SENS-02 | Leave-one-out at within-cluster level — drop each effect size, refit, show table + influence plot | Effect-level LOO: iterate over x$data$TE_id rows, subset, refit; row count = nrow(x$data) |
</phase_requirements>

---

## Summary

Phase 3 builds five exported functions on top of the `meta3l_result` object and Phase 2's grid graphics infrastructure. All statistical machinery is already available through metafor and clubSandwich — Phase 3 is primarily about correctly orchestrating existing tools and extending the grid layout system for new plot types.

The subgroup forest plot (`forest_subgroup.meta3L`) is the most complex deliverable: it requires per-subgroup rma.mv fits with V-matrix row/column subsetting, a multi-section grid layout (header row + study rows + diamond row + blank separator per group), plus an omnibus Q-test footer. The `three_level.Rmd` template contains a working reference implementation using base-R graphics that must be translated to the grid system.

The bubble plot (`bubble.meta3L`) wraps metafor::regplot() for the scatter layer, fits the regression model internally, then adds a grid summary table below. The leave-one-out functions (`loo_cluster.meta3L`, `loo_effect.meta3L`) refit the model N times — sequentially on Windows (mclapply does not fork) — and draw trajectory plots reusing Phase 2 primitives. The moderator function (`moderator.meta3L`) fits a single mixed-effects model and returns both raw results and a formatted print method.

**Primary recommendation:** Implement in this order: moderator.meta3L (pure modeling, no graphics) → forest_subgroup.meta3L (most complex, unblocks SUBG-01–03) → bubble.meta3L (regplot wrapper) → loo_cluster + loo_effect (parallel LOO loops with identical plot code).

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| metafor | >= 4.0-0 (already in DESCRIPTION) | rma.mv mods=, anova(), regplot(), predict() | The only multilevel meta-analysis engine in R |
| clubSandwich | >= 0.5.0 (already in DESCRIPTION) | CR2 robust SE for moderator Wald tests | Required for valid inference under three-level structure |
| grid | base R | All plot rendering | Established in Phase 2; no new dependency |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| stats (base) | base R | anova() for LRT, qnorm(), as.formula() | LRT via anova.rma.mv, CI computation |
| parallel (base) | base R | parLapply for LOO if runtime justifies it | Only if sequential LOO > 10 seconds on test data |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| metafor::regplot() | Custom base-R scatter | regplot is well-tested and handles transf natively; custom build risks edge cases |
| Sequential LOO loop | parallel::parLapply | Parallelism adds complexity; Windows needs explicit cluster setup; measure first |

**Installation:** No new packages needed — all dependencies already in DESCRIPTION.

---

## Architecture Patterns

### Recommended Project Structure
```
R/
├── forest_subgroup.meta3L.R    # SUBG-01, SUBG-02, SUBG-03 (new file)
├── moderator.meta3L.R          # SUBG-04, SUBG-05 (new file)
├── print.moderator_result.R    # S3 print method for moderator result (new file)
├── bubble.meta3L.R             # MREG-01–04 (new file)
├── loo_cluster.meta3L.R        # SENS-01 (new file)
├── loo_effect.meta3L.R         # SENS-02 (new file)
├── forest_helpers.R            # extend resolve_file() for new filename patterns
├── utils.R                     # no changes needed for Phase 3
└── meta3L.R                    # API refactor: meta-style column name mapping (BREAKING)
```

### Pattern 1: V-Matrix Subsetting for Subgroup Fits

**What:** When fitting a three-level model on a subset of rows, the V-matrix must be subsetted to matching rows/columns. Row index vector `idx` selects both data rows and V rows+cols.

**When to use:** Every subgroup fit, every LOO iteration.

```r
# Source: three_level.Rmd (project template, verified working)
idx   <- which(dat[[subgroup_var]] == group_val)
dat_g <- dat[idx, , drop = FALSE]
V_g   <- V[idx, idx, drop = FALSE]
fit_g <- metafor::rma.mv(yi, V_g,
           random = stats::as.formula(paste0("~ 1 | ", cluster, " / TE_id")),
           data   = dat_g)
```

### Pattern 2: Subgroup Fit with Cluster Count Guard

**What:** rma.mv with random = ~1|cluster/TE_id requires at least 2 distinct clusters. Subgroups with k_cluster == 1 must fall back to rma() (two-level model) or be skipped with a warning.

**When to use:** Every per-subgroup rma.mv call.

```r
# Source: three_level.Rmd (project template, verified working)
n_clust <- length(unique(dat_g[[cluster]]))
fit_g <- if (n_clust >= 2L) {
  res_g <- metafor::rma.mv(yi, V_g,
    random = random_formula, data = dat_g)
  metafor::robust(res_g, cluster = dat_g[[cluster]], clubSandwich = TRUE)
} else {
  warning("Subgroup '", group_val, "' has only 1 cluster — fitting two-level model.",
          call. = FALSE)
  metafor::rma(yi, vi, data = dat_g)
}
```

### Pattern 3: Omnibus Q-Test for Subgroup Differences

**What:** Fit rma.mv with mods = ~factor(subgroup_col) on the full sorted dataset. Fields $QM (statistic), $QMp (p-value), $m (df) carry the omnibus test.

**When to use:** forest_subgroup.meta3L() and moderator.meta3L() both need this.

```r
# Source: three_level.Rmd (project template, verified working)
dat[[subgroup_col]] <- factor(dat[[subgroup_col]])
res_mod <- metafor::rma.mv(yi, V,
  mods   = stats::as.formula(paste0("~ factor(", subgroup_col, ")")),
  random = stats::as.formula(paste0("~ 1 | ", cluster, " / TE_id")),
  data   = dat)
# Extract: res_mod$QM (Wald statistic), res_mod$QMp (p-value), res_mod$m (df = n_levels - 1)
```

### Pattern 4: LRT via anova() for moderator.meta3L()

**What:** Fit full model (with mods) and null model (without mods), then call anova(full, null). metafor's anova.rma.mv returns LRT chi-square and p-value.

**When to use:** moderator.meta3L() SUBG-05 requirement.

```r
# Source: metafor documentation (anova.rma.mv)
fit_null <- metafor::rma.mv(yi, V,
  random = random_formula, data = dat)
fit_full <- metafor::rma.mv(yi, V,
  mods = stats::as.formula(paste0("~ factor(", subgroup_col, ")")),
  random = random_formula, data = dat)
lrt_result <- stats::anova(fit_full, fit_null)
# lrt_result$LRT (chi-square), lrt_result$p (p-value), lrt_result$df (df)
```

### Pattern 5: regplot() Wrapper for Bubble Plot

**What:** metafor::regplot() draws a scatter plot with regression line and CI band from an rma/rma.mv object. The transf argument back-transforms the y-axis. The bubble argument controls point sizing.

**When to use:** bubble.meta3L() MREG-01–03.

```r
# Source: metafor package documentation for regplot()
fit_mod <- metafor::rma.mv(yi, V,
  mods   = stats::as.formula(paste0("~ ", mod_col)),
  random = random_formula,
  data   = x$data)
metafor::regplot(fit_mod,
  mod    = mod_col,
  transf = x$transf,
  xlab   = mod_col,
  ylab   = "Effect size",
  pi     = FALSE,   # no prediction interval
  shade  = TRUE)    # CI band shading
```

**Note:** regplot() uses base graphics internally. The summary table below the bubble plot must be drawn in a separate grid viewport AFTER regplot() completes. This means bubble.meta3L() will use a hybrid device: base graphics for the scatter (via regplot), then grid for the table. The recommended approach is to draw the regplot first, then use grid::grid.newpage() followed by viewport layout only for the table, OR embed regplot output as a captured raster. The simpler path: use a two-panel layout with gridGraphics::grid.echo() to capture regplot output into a grid grob — but gridGraphics is not in DESCRIPTION. **Simpler alternative:** Draw the full bubble plot in base graphics (scatter + regression line + CI band manually, replicating three_level.Rmd meta_reg_bubble()), add the summary table as a text annotation at the bottom margin. This avoids a new dependency and matches the working template exactly.

### Pattern 6: LOO Loop with V-Matrix Subsetting

**What:** For each omitted index, remove the corresponding row (and column) from V and the matching row from data, refit the three-level model, extract pooled estimate + I².

**When to use:** loo_cluster.meta3L() (omit by cluster), loo_effect.meta3L() (omit by TE_id row).

```r
# Source: standard metafor LOO pattern
clusters <- unique(x$data[[x$cluster]])
results_list <- lapply(clusters, function(cl) {
  keep <- x$data[[x$cluster]] != cl
  dat_loo <- x$data[keep, , drop = FALSE]
  V_loo   <- x$V[keep, keep, drop = FALSE]
  fit_loo <- metafor::rma.mv(yi, V_loo,
    random = stats::as.formula(paste0("~ 1 | ", x$cluster, " / TE_id")),
    data   = dat_loo)
  fit_rob <- metafor::robust(fit_loo,
    cluster = dat_loo[[x$cluster]], clubSandwich = TRUE)
  i2_loo  <- compute_i2(fit_loo, V_loo)
  list(omitted = cl,
       estimate = x$transf(fit_rob$b[[1L]]),
       ci.lb    = x$transf(fit_rob$ci.lb),
       ci.ub    = x$transf(fit_rob$ci.ub),
       i2_between = i2_loo$between,
       i2_within  = i2_loo$within,
       pval       = fit_rob$pval)
})
```

### Pattern 7: resolve_file() Extension for Phase 3 Filenames

**What:** resolve_file() currently produces `{name}.{format}`. Phase 3 needs `{name}_{type}_{col}.{format}` patterns. Extend by adding a `suffix` argument.

**When to use:** All Phase 3 functions that save files.

```r
# Proposed extension to forest_helpers.R
resolve_file <- function(x, file, format, suffix = "") {
  if (is.null(file)) return(NULL)
  if (length(file) == 1L && nchar(file) > 0L) return(file)
  # character(0) sentinel: auto-assemble
  base_name <- if (!is.null(x$name) && nchar(x$name) > 0L) x$name else "meta3l_plot"
  fname <- if (nchar(suffix) > 0L) paste0(base_name, "_", suffix) else base_name
  dir_path <- getOption("meta3l.mwd", default = getwd())
  file.path(dir_path, paste0(fname, ".", format))
}
```

### Pattern 8: meta-style Column Name Mapping (API Refactor)

**What:** Map meta-package column names to metafor escalc canonical names inside meta3L(). Smart auto-detection reads standard column names from data if user omits arguments.

**When to use:** meta3L() refactor — this is a breaking change to Phase 1 but required by locked decision.

```r
# Meta-style → escalc mapping per measure
META_COL_MAP <- list(
  PLO = list(xi = "event", ni = "n"),           # single-arm proportion
  PAS = list(xi = "event", ni = "n"),
  RR  = list(ai = "event.e", n1i = "n.e",
             ci = "event.c", n2i = "n.c"),      # compute bi/di internally
  OR  = list(ai = "event.e", n1i = "n.e",
             ci = "event.c", n2i = "n.c"),
  SMD = list(m1i = "mean.e", sd1i = "sd.e", n1i = "n.e",
             m2i = "mean.c", sd2i = "sd.c", n2i = "n.c"),
  MD  = list(m1i = "mean.e", sd1i = "sd.e", n1i = "n.e",
             m2i = "mean.c", sd2i = "sd.c", n2i = "n.c")
)
# NOTE: For RR/OR, escalc requires ai/bi/ci/di (events AND non-events).
# bi = n.e - event.e, di = n.c - event.c must be computed before escalc call.
```

**Critical note on RR/OR:** escalc() requires all four cell counts (ai, bi, ci, di). The meta package provides event.e, n.e, event.c, n.c. Conversion: `bi = n.e - event.e`, `di = n.c - event.c`. This computation must happen inside meta3L() before the escalc call.

### Anti-Patterns to Avoid

- **mclapply on Windows:** `parallel::mclapply` forks processes and silently falls back to sequential on Windows — no error, just no speed gain. Use `parallel::parLapply` with an explicit PSOCK cluster if parallelism is needed, or just use sequential `lapply` (simpler, always correct).
- **rma.mv with k_cluster == 1:** Will throw "cannot fit model" error. Always check `length(unique(dat[[cluster]]))` before fitting rma.mv; fall back to rma() with a warning.
- **Modifying x$data in LOO:** Never mutate the input `meta3l_result`. Always work on copies (`dat_loo <- x$data[keep, , drop = FALSE]`).
- **Using regplot() then grid in the same device:** regplot() draws to the active base graphics device. grid::grid.newpage() will clear it. Decide upfront: either pure base-R for bubble.meta3L() (matching the template) or gridGraphics (new dependency). Pure base-R is the safe choice.
- **Dropping cluster column from LOO data:** When subsetting for cluster LOO, keep all columns including the cluster column. rma.mv random formula references the cluster column by name.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scatter plot + regression line + CI band | Custom grid scatter | metafor::regplot() or base-R pattern from three_level.Rmd | regplot handles transf, CI computation, bubble sizing cleanly |
| LRT for moderator significance | Chi-square approximation | stats::anova(fit_full, fit_null) | metafor's anova.rma.mv is the standard; handles df correctly |
| Wald test for moderator | Manual QM computation | rma.mv $QM and $QMp fields directly | Already computed by metafor; no need to recompute |
| Back-transform for bubble axes | Inline plogis/exp | resolve_transf() already in utils.R | Consistent with rest of package |
| Null hypothesis reference line | Hardcoded 0 or 1 | auto_refline() already in forest_helpers.R | Consistent with forest.meta3L() |
| File path construction | String paste | resolve_file() with suffix argument | Consistent with Phase 2; handles NULL/character(0)/explicit path sentinel correctly |
| Auto-dimensions | Width/height hardcoding | auto_dims() already in forest_helpers.R | Consistent scaling formula already tested |

---

## Common Pitfalls

### Pitfall 1: Single-Cluster Subgroup Crashes rma.mv

**What goes wrong:** rma.mv with `random = ~1|cluster/TE_id` requires at least 2 unique cluster values. A subgroup with only one study (one cluster) causes an error: "cannot estimate between-cluster variance component with only 1 cluster".

**Why it happens:** The three-level random formula tries to estimate sigma²_between, which requires at least 2 groups at that level.

**How to avoid:** Check `length(unique(dat_g[[cluster]]))` before fitting. If == 1, warn and use `rma(yi, vi, data=dat_g)` (two-level) instead. The compute_i2() in utils.R already handles rma objects (they have $I2).

**Warning signs:** Any subgroup with k_studies == 1 in the input data.

### Pitfall 2: V-Matrix Index Misalignment After Row Subsetting

**What goes wrong:** After `data <- data[keep, ]`, row indices in the subsetted data no longer align with the original V-matrix indices. Using `V[keep, keep]` is correct; using `V[seq_len(sum(keep)), seq_len(sum(keep))]` is wrong.

**Why it happens:** V was constructed with original row order. Logical indexing `V[keep, keep]` selects the correct submatrix.

**How to avoid:** Always subset V with the same logical or integer index vector used to subset data. Test: `nrow(dat_loo) == nrow(V_loo)` and `ncol(V_loo) == nrow(V_loo)`.

### Pitfall 3: regplot() Overwrites Active Grid Device

**What goes wrong:** If forest_subgroup.meta3L() or any grid-drawing function has an active viewport and bubble.meta3L() calls regplot(), regplot() draws to the base-R device layer, potentially corrupting the grid state.

**Why it happens:** regplot() uses base graphics (plot(), lines(), polygon()), not grid.

**How to avoid:** bubble.meta3L() must open its own device (png/pdf) and draw entirely in base-R (no grid calls for the scatter panel). The summary table annotation can be added as text() in base-R margins, not as a grid grob.

### Pitfall 4: LRT Requires Identical Data Sets

**What goes wrong:** anova(fit_full, fit_null) for LRT requires both models fit on exactly the same data. If NA filtering or row ordering differs between the two rma.mv calls, anova() throws a warning or gives wrong df.

**Why it happens:** rma.mv drops rows with NA in yi/vi automatically; if mods column has additional NAs, the full model drops different rows.

**How to avoid:** Filter NA rows in both yi/vi AND the moderator column before fitting either model. Use the same filtered dataset for both null and full model fits.

### Pitfall 5: LOO TE_id Continuity

**What goes wrong:** After removing a row, TE_id values in the subsetted data are non-contiguous (e.g., 1,2,4,5,6 with 3 removed). vcalc() uses obs=TE_id; non-contiguous values are valid for vcalc but the random formula expects obs to uniquely identify rows within clusters.

**Why it happens:** TE_id was assigned as seq_len(nrow(dat)) on the full data.

**How to avoid:** In LOO loops, do NOT re-run escalc/vcalc. Instead, directly subset x$data (which already has yi, vi, TE_id) and x$V. The existing TE_id values remain valid identifiers within clusters even after removal of other rows.

### Pitfall 6: LOO on Windows — mclapply

**What goes wrong:** `parallel::mclapply(clusters, fn, mc.cores=4)` on Windows silently runs sequentially (mc.cores is ignored; falls back to mc.cores=1) giving no speedup.

**Why it happens:** Windows cannot fork processes. mclapply forks on Unix/macOS only.

**How to avoid:** Use plain `lapply` by default. If runtime measurement shows > 30 seconds for 20 clusters, implement optional `parLapply` with PSOCK cluster behind `parallel_loo = FALSE` argument. This is Claude's discretion territory — default to sequential `lapply`.

### Pitfall 7: QM vs QME Statistics in rma.mv

**What goes wrong:** rma.mv has two omnibus test fields: `$QM` (test of moderators, used for subgroup Q-test) and `$QE` (test of residual heterogeneity, the Q-test for remaining variance after moderators). Confusing them gives wrong p-values.

**Why it happens:** Both are present on the same rma.mv object; the names are similar.

**How to avoid:**
- Subgroup Q-test (differences BETWEEN groups) = `res_mod$QM`, `res_mod$QMp`, `res_mod$m`
- Residual heterogeneity Q-test (within groups) = `res_mod$QE`, `res_mod$QEp`
- For forest_subgroup.meta3L omnibus footer: use `$QM` / `$QMp`

### Pitfall 8: print.moderator_result S3 Dispatch

**What goes wrong:** If moderator.meta3L() returns a list without a proper class attribute, `print()` dispatches to print.default (ugly output). The user-facing print() method requires a named class.

**How to avoid:** Structure the return value as `structure(list(...), class = "moderator_result")` and register `S3method(print, moderator_result)` in the NAMESPACE (via @method roxygen tag).

---

## Code Examples

Verified patterns from the project's own working template (three_level.Rmd) and metafor documentation:

### Omnibus Q-Test Extraction
```r
# Source: three_level.Rmd lines 167-175 (project template, verified working)
dat_s$subgp_f <- factor(dat_s[[subgroup_var]])
res_mod <- metafor::rma.mv(yi, V_s,
  mods   = ~ subgp_f,
  random = ~ 1 | studlab / TE_id,
  data   = dat_s)
# Fields used for plot annotation:
# res_mod$m    = degrees of freedom (n_levels - 1)
# res_mod$QM   = Q statistic
# res_mod$QMp  = p-value
sprintf("Test for subgroup differences: Q = %.2f, df = %d, p = %.3f",
        res_mod$QM, res_mod$m, res_mod$QMp)
```

### Per-Subgroup I² Formatting (extending format_mlab pattern)
```r
# Source: adapted from format_mlab() in forest_helpers.R
format_subgroup_mlab <- function(i2, k) {
  sprintf(
    "k = %d  |  I\u00b2 = %.0f%% (between: %.0f%%, within: %.0f%%)",
    k, i2$total, i2$between, i2$within
  )
}
# Note: compute_i2() in utils.R returns list(total, between, within)
# For rma objects (k_cluster < 2 fallback): i2 <- list(total=fit$I2, between=0, within=fit$I2)
```

### LOO Table Construction
```r
# Source: derived from three_level.Rmd pattern + CONTEXT.md spec
loo_table <- do.call(rbind, lapply(results_list, function(r) {
  data.frame(
    omitted    = r$omitted,
    estimate   = r$estimate,
    ci.lb      = r$ci.lb,
    ci.ub      = r$ci.ub,
    i2_between = r$i2_between,
    i2_within  = r$i2_within,
    pval       = r$pval,
    stringsAsFactors = FALSE
  )
}))
```

### resolve_file() Extended Call (Phase 3 suffix pattern)
```r
# Pattern for forest_subgroup.meta3L auto-naming
suffix <- paste0("subgroup_", subgroup_col)
out_file <- resolve_file(x, file, format, suffix = suffix)
# Produces: {mwd}/{name}_subgroup_{subgroup_col}.png
```

### Bubble Plot Base-R Pattern (from three_level.Rmd)
```r
# Source: three_level.Rmd meta_reg_bubble() lines 316-398
# Fit meta-regression model
fit_mod <- metafor::rma.mv(yi, V,
  mods   = stats::as.formula(paste("~", mod_col)),
  random = stats::as.formula(paste0("~ 1 | ", x$cluster, " / TE_id")),
  data   = x$data)
fit_rob <- metafor::robust(fit_mod,
  cluster = x$data[[x$cluster]], clubSandwich = TRUE)
# Prediction grid for CI band
x_seq <- seq(min(x$data[[mod_col]], na.rm = TRUE),
             max(x$data[[mod_col]], na.rm = TRUE),
             length.out = 200L)
pred <- metafor::predict.rma(fit_mod,
  newmods = matrix(x_seq, ncol = 1L),
  transf  = x$transf)
# Bubble sizes
wi     <- 1 / sqrt(x$data$vi)
wi_min <- min(wi); wi_rng <- diff(range(wi)) + 1e-9
cex_b  <- 0.6 + 2.5 * (wi - wi_min) / wi_rng
```

### R² for Meta-Regression (bubble summary table)
```r
# Source: metafor manual — R² for mixed-effects models
# metafor computes R2 directly on the rma.mv object when a null model is provided
fit_null <- metafor::rma.mv(yi, V,
  random = random_formula, data = x$data)
fit_full <- metafor::rma.mv(yi, V,
  mods   = stats::as.formula(paste("~", mod_col)),
  random = random_formula, data = x$data)
# Approximate R²: proportion of total variance explained by moderator
# R² = max(0, (sum(sigma2_null) - sum(sigma2_full)) / sum(sigma2_null))
r2 <- max(0, (sum(fit_null$sigma2) - sum(fit_full$sigma2)) / sum(fit_null$sigma2))
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Base-R forest plots (metafor::forest) | Grid graphics (Phase 2 established) | Phase 2 | All new plots MUST use grid, not par/plot/text |
| mclapply for parallel LOO | Sequential lapply (Windows-safe) | Phase 3 context | No parallel dep needed; sequential is default |
| Hardcoded escalc column names in meta3L() | meta-style names with auto-detection | Phase 3 breaking change | meta3L() signature changes; old tests must be updated |

**Deprecated/outdated in this project:**
- escalc-style column names (xi, ni, ai, bi, ci, di, m1i, etc.) in meta3L() user-facing API: Being replaced with meta-style names (event, n, event.e, n.e, etc.) as a Phase 3 API refactor
- Base-R par/plot/text/forest calls: Out of scope for all Phase 3 functions (grid only, except bubble.meta3L which may use base-R for the scatter panel)

---

## Open Questions

1. **regplot() availability in metafor >= 4.0**
   - What we know: metafor::regplot() was added in metafor 3.x; DESCRIPTION requires >= 4.0-0 so it should be available. The NAMESPACE does not currently import it.
   - What's unclear: Whether regplot() is exported from the metafor namespace (some metafor functions are internal). R cannot be invoked from this environment to verify.
   - Recommendation: If regplot() is exported (likely), add `@importFrom metafor regplot` to bubble.meta3L.R. If not exported, access via `metafor:::regplot()` with a note, or implement base-R scatter manually (which the three_level.Rmd template already provides as a complete working pattern). The base-R manual approach is safer and avoids the import question entirely.

2. **meta-style column names for RR/OR — bi/di computation**
   - What we know: meta package uses event.e, n.e, event.c, n.c; escalc needs ai, bi, ci, di where bi=non-events.
   - What's unclear: Whether to expose bi/di override arguments to meta3L() or always compute internally.
   - Recommendation: Always compute bi = n.e - event.e, di = n.c - event.c internally. Do not expose bi/di in the new API. Users who have raw non-event counts can still use xi/ni for proportions or provide event.e + n.e.

3. **anova.rma.mv LRT df field name**
   - What we know: stats::anova(fit_full, fit_null) on rma.mv objects calls metafor's anova.rma.mv. The return value has LRT-related fields.
   - What's unclear: Exact field names ($LRT, $p, $df or $RLRT, $p.val, etc.) without R execution.
   - Recommendation: Plan task should include a verification step: `str(anova(fit_full, fit_null))` in a test to confirm field names before building the print method.

4. **Grid table below bubble plot**
   - What we know: bubble.meta3L() uses base-R graphics for the scatter. A grid table (CONTEXT.md spec) requires grid. These don't mix on the same device without gridGraphics.
   - What's unclear: Whether to use base-R text annotation in the margin instead of a grid table.
   - Recommendation (Claude's discretion): Use base-R text in the bottom margin for the summary table (mtext or text at low y coordinates). This avoids gridGraphics dependency, matches the output quality needed, and is consistent with three_level.Rmd's approach. If a true grid table is required later, it's an enhancement.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat >= 3.0.0 (Config/testthat/edition: 3 in DESCRIPTION) |
| Config file | meta3l/tests/testthat.R (standard testthat) |
| Quick run command | `testthat::test_file("tests/testthat/test-{module}.R")` from package root |
| Full suite command | `devtools::test()` or `R CMD check meta3l` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SUBG-01 | forest_subgroup.meta3L() produces non-empty PNG with subgroup sections | smoke | `testthat::test_file("tests/testthat/test-forest_subgroup.R")` | Wave 0 |
| SUBG-02 | Per-subgroup diamonds drawn; I² values in summary line | smoke | `testthat::test_file("tests/testthat/test-forest_subgroup.R")` | Wave 0 |
| SUBG-03 | Omnibus Q-test text appears in plot output (file size > threshold) | smoke | `testthat::test_file("tests/testthat/test-forest_subgroup.R")` | Wave 0 |
| SUBG-04 | moderator.meta3L() returns object with $model (rma.mv) and $wald fields | unit | `testthat::test_file("tests/testthat/test-moderator.R")` | Wave 0 |
| SUBG-05 | Wald QM and LRT chi-square fields present and numeric | unit | `testthat::test_file("tests/testthat/test-moderator.R")` | Wave 0 |
| MREG-01 | bubble.meta3L() produces non-empty PNG with point sizes | smoke | `testthat::test_file("tests/testthat/test-bubble.R")` | Wave 0 |
| MREG-02 | Regression line present (file size > 10000 bytes heuristic) | smoke | `testthat::test_file("tests/testthat/test-bubble.R")` | Wave 0 |
| MREG-03 | Back-transformed axes: PLO yi range in [0,1] in returned table | unit | `testthat::test_file("tests/testthat/test-bubble.R")` | Wave 0 |
| MREG-04 | Robust p-value numeric and in [0,1] in returned summary | unit | `testthat::test_file("tests/testthat/test-bubble.R")` | Wave 0 |
| SENS-01 | loo_cluster.meta3L() returns list with $table having n_clusters rows | unit | `testthat::test_file("tests/testthat/test-loo.R")` | Wave 0 |
| SENS-02 | loo_effect.meta3L() returns list with $table having n_effects rows | unit | `testthat::test_file("tests/testthat/test-loo.R")` | Wave 0 |

### Sampling Rate
- **Per task commit:** `devtools::test(filter="test-{module}")` for the module being implemented
- **Per wave merge:** `devtools::test()` (full suite)
- **Phase gate:** Full suite green + `R CMD check --no-manual meta3l` 0 errors 0 warnings before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/testthat/test-forest_subgroup.R` — covers SUBG-01, SUBG-02, SUBG-03
- [ ] `tests/testthat/test-moderator.R` — covers SUBG-04, SUBG-05
- [ ] `tests/testthat/test-bubble.R` — covers MREG-01, MREG-02, MREG-03, MREG-04
- [ ] `tests/testthat/test-loo.R` — covers SENS-01, SENS-02
- [ ] `tests/testthat/helper-fixtures.R` — needs subgroup column added to existing fixtures for Phase 3 tests

---

## Sources

### Primary (HIGH confidence)
- `three_level.Rmd` (project root) — complete working reference implementation for subgroup_forest(), meta_reg_bubble() in base-R; all statistical patterns verified working
- `meta3l/R/forest_helpers.R`, `meta3l/R/utils.R`, `meta3l/R/forest.meta3L.R` — exact API contracts for all reusable helpers (resolve_file, auto_dims, auto_refline, auto_xlim, compute_i2, draw_*)
- `meta3l/R/meta3L.R` — existing function signature and V-matrix construction pattern
- `meta3l/DESCRIPTION`, `meta3l/NAMESPACE` — current imports and package constraints
- `.planning/phases/03-subgroup-meta-regression-sensitivity/03-CONTEXT.md` — all locked implementation decisions

### Secondary (MEDIUM confidence)
- metafor package documentation: rma.mv mods argument, $QM/$QMp/$m fields, anova.rma.mv for LRT, predict.rma for CI band generation — standard documented API, not verified via live R session in this environment
- clubSandwich robust() — $QMp field for robust p-value confirmed in both three_level.Rmd and meta3L.R implementation

### Tertiary (LOW confidence)
- metafor::regplot() export status — not confirmed via live R session; recommended to verify in task implementation
- anova.rma.mv return field names ($LRT, $p, $df) — field names not confirmed without R execution; implementation task should include str() verification step

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all dependencies already in project, no new packages needed
- Architecture patterns: HIGH — all patterns derived from working three_level.Rmd template or existing Phase 2 code
- Pitfalls: HIGH — derived from actual code in the project plus well-known metafor behavior
- regplot() export status: LOW — not verified in live R session

**Research date:** 2026-03-10
**Valid until:** 2026-04-10 (metafor API is stable; 30-day window is conservative)

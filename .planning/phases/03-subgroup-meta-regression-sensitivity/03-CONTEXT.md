# Phase 3: Subgroup, Meta-Regression, and Sensitivity - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can run formal moderator analyses (subgroup comparisons, meta-regression), visualize subgroup differences in forest plots, produce bubble plots for continuous moderators, and assess influence of individual studies or effect sizes via leave-one-out analyses — all building on the `meta3l_result` object from Phase 1 and the grid drawing primitives from Phase 2.

Functions: `forest_subgroup.meta3L()`, `moderator.meta3L()`, `bubble.meta3L()`, `loo_cluster.meta3L()`, `loo_effect.meta3L()`.

</domain>

<decisions>
## Implementation Decisions

### API Refactor: meta-style Column Names
- **Breaking change to Phase 1 API**: Replace escalc-style column names (ai, bi, ci, di, m1i, sd1i, etc.) with `meta`-package-style names (event.e, n.e, event.c, n.c, mean.e, sd.e, etc.) in `meta3L()` function signature
- **Smart defaults**: If user's data already has standard column names (event.e, n.e, etc.), `meta3L(data, slab="studlab", measure="RR")` works without specifying column args — auto-detects from data
- **Override still available**: User can pass `event.e="my_events"` etc. when their column names differ from the meta convention
- Internal mapping from meta-style names to escalc canonical names happens inside meta3L()

### Subgroup Forest Plot Layout
- **Grouped sections**: Each subgroup gets a bold header row, its studies, then a subgroup summary diamond — with blank separator row between groups
- **Subgroup header format**: Just the subgroup level value (e.g., "Amphotericin B"), not "Subgroup = Value"
- **Per-subgroup I²**: Compact three-value format matching Phase 2: `I² = 65% (between: 40%, within: 25%)`
- **Per-subgroup p-value**: Shown for pairwise measures (SMD, MD, RR, OR), same as main forest plot convention
- **Overall diamond**: Shown by default, hideable via `overall=FALSE` argument
- **Omnibus Q-test**: Displayed below the overall diamond (or last subgroup if overall=FALSE): "Test for subgroup differences: Q = 8.42, df = 2, p = 0.015"
- **Single-study subgroups (k=1)**: Show the study row but skip the subgroup diamond and I² — can't fit a three-level model with k=1. Warning printed to console
- **Subgroup argument**: `subgroup = "column_name"` (quoted string, consistent with package convention)
- **Inherits all forest.meta3L() arguments**: ilab, sortvar, refline, xlim, showweights, colshade, file, format, width, height — same signature plus subgroup and overall

### Bubble Plot (Meta-Regression Visualization)
- **Wrapper around metafor::regplot()**: Not built from scratch — leverages metafor's existing scatter + regression line + CI band, adding convenience features
- **Fits model internally**: `bubble.meta3L(result, mod="age")` handles rma.mv with `mods=~age` internally — one call does everything
- **Continuous moderators only**: Categorical moderators belong in forest_subgroup/moderator functions. bubble.meta3L() errors if moderator column is factor/character
- **Moderator argument**: `mod = "column_name"` (quoted string)
- **Back-transformed scale**: Axes and all values shown on back-transformed scale (probability for PLO/PAS, exp for RR/OR, raw for SMD/MD)
- **CI band shading**: Displayed by default around the regression line
- **Axes auto-scaled**: X and Y axes precisely fit all bubbles with no excessive whitespace
- **Point sizing**: Bubbles sized by 1/sqrt(vi) automatically with sensible defaults
- **Robust p-value**: clubSandwich robust p-value displayed on the plot
- **Title**: Auto-generated as "Meta-regression: {moderator_name}", overridable via `title` argument
- **Summary table below plot**: Grid-graphics table with columns: Estimate | 95% CI | R² | p-value. Rendered below the scatter plot area
- **File output**: Same resolve_file() / auto_dims() system as forest plots. Auto-name pattern: `{name}_bubble_{mod}.png`

### LOO Influence Analysis
- **Forest-trajectory style**: Each row = one dropped study/effect, showing recalculated pooled estimate + CI as horizontal line with point
- **Grid graphics engine**: Reuses draw_square, draw_ci_line, draw_zebra_rect from Phase 2 for consistent visual style
- **Per-row metrics**: Pooled estimate, 95% CI, I² between, I² within, and p-value (for pairwise measures)
- **Baseline row at bottom**: "All studies" row with full model estimate + CI + I² shown as the **last** row (not first), no divider line separating it
- **Vertical reference line**: Null hypothesis value from auto_refline() — 0 for SMD/MD, 1 for RR/OR, none for PLO/PAS
- **Return value**: List with `$table` (data.frame: omitted, estimate, ci.lb, ci.ub, i2_between, i2_within, pval) and `$plot_file` (path to saved plot)
- **File output**: Same resolve_file() / auto_dims() system. Auto-name patterns: `{name}_loo_cluster.png`, `{name}_loo_effect.png`

### Moderator Analysis (Formal Hypothesis Testing)
- **Full model object returned**: Returns the rma.mv object with mods= directly, plus extracted test summaries. Advanced users can access anything from the raw model
- **Categorical moderators only**: Validates that the moderator column is factor/character; errors with helpful message pointing to bubble.meta3L() if numeric
- **Subgroup argument**: `subgroup = "column_name"` — matches forest_subgroup.meta3L() for consistent pair
- **Tests included**: Wald-type test (QM statistic) and likelihood-ratio test (LRT) for moderator significance
- **Per-subgroup estimates**: Back-transformed per-level pooled estimates with CIs included in the result
- **print() method**: Manuscript-friendly formatted output showing: moderator name, Wald test (QM(df) = X, p = Y), LRT (χ²(df) = X, p = Y), and per-subgroup estimates table (Level, k, Estimate, [95% CI])

### File Naming Convention (All Phase 3 Functions)
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

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `draw_square()`, `draw_diamond()`, `draw_ci_line()`, `draw_zebra_rect()` in R/forest_helpers.R: Reusable for subgroup forest plot and LOO influence plot
- `resolve_file()` in R/forest_helpers.R: File output with auto-naming — extend for new filename patterns
- `auto_dims()` in R/forest_helpers.R: Auto-scaling dimensions — reusable for all plot types
- `auto_refline()` in R/forest_helpers.R: Null hypothesis reference line — reusable for LOO influence plot
- `auto_xlim()` in R/forest_helpers.R: Axis limits computation — reusable
- `format_mlab()` in R/forest_helpers.R: I² formatting — reusable for subgroup summary lines
- `resolve_transf()` in R/utils.R: Back-transform function resolution — needed for bubble plot axes
- `compute_i2()` in R/utils.R: Multilevel I² computation — called for each subgroup fit and each LOO iteration
- `meta3l_result` S3 object: Contains `$model`, `$data`, `$V`, `$cluster`, `$measure`, `$transf`, `$name`, `$slab` — all needed by Phase 3 functions

### Established Patterns
- Column names as quoted strings (character), not NSE — all new functions follow this
- `stop()/warning()` with `call. = FALSE` — no cli dependency
- R >= 4.0 compatibility — no native pipe `|>` or lambda `\(x)`
- One file per exported function
- S3 method dispatch on `meta3l_result` class
- `on.exit(dev.off())` for safe device cleanup in batch loops
- `resolve_file()` uses `character(0)` sentinel for auto-name, `NULL` for display-only

### Integration Points
- `forest_subgroup.meta3L()` fits separate `rma.mv` per subgroup level using same V-matrix subsetting
- `moderator.meta3L()` fits `rma.mv` with `mods = ~subgroup_col` on the full dataset
- `bubble.meta3L()` fits `rma.mv` with `mods = ~mod_col` then wraps `metafor::regplot()`
- `loo_cluster/loo_effect` refit `meta3L()` internally for each omission (or call rma.mv directly for speed)
- All functions consume `meta3l_result` and produce file output via the Phase 2 resolve_file/auto_dims system

</code_context>

<specifics>
## Specific Ideas

- The `meta` package column naming convention (event.e, n.e, mean.e, sd.e, etc.) should replace escalc naming in the core meta3L() API — users' Excel files typically already have these standard column names
- Smart defaults mean `meta3L(data, slab="studlab", measure="RR")` just works when data has event.e, n.e, event.c, n.c columns
- Bubble plot wraps metafor::regplot() because "it's really good" — don't rebuild from scratch
- LOO baseline row goes at the bottom (not top), with no dividing line — the vertical reference line marks the null hypothesis
- Per-subgroup and per-LOO-row displays must always show I² for within and between clusters, plus p-value for pairwise measures

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-subgroup-meta-regression-sensitivity*
*Context gathered: 2026-03-10*

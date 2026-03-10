# Phase 2: Forest Plot and File Output - Context

**Gathered:** 2026-03-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Publication-quality forest plot from a `meta3l_result` object (Phase 1 output) and file saving (PNG/PDF). Users call `forest.meta3L()` to produce a grid-graphics forest plot mimicking `meta::forest.meta` style, with multilevel I² in the summary label, user-defined annotation columns (ilab), zebra shading, and auto-scaled dimensions. The function saves to file by default and also displays in RStudio viewer when available. Subgroup forest plots, bubble plots, and LOO analyses are Phase 3.

</domain>

<decisions>
## Implementation Decisions

### Plot Engine
- Build a custom grid-graphics forest plot from scratch using grid::viewport/grob system
- Visual style mimics `meta::forest.meta` (from `forest_template.R` reference) — squares proportional to weight, horizontal CI lines, diamond for pooled
- NOT wrapping metafor::forest() (which is base R graphics) — building native grid
- Axis always shows back-transformed values: PLO/PAS → probability scale (0-1), RR/OR → exp scale, SMD/MD → raw scale
- Weight column shown by default, hideable via `showweights=FALSE` argument

### Summary Label and Pooled Display
- Pooled diamond display mimics `meta::forest.meta` — diamond with "Random effects model" label and heterogeneity stats on a separate line below
- I² format in heterogeneity line: `RE Model | I² = 85% (between: 60%, within: 25%)`
- Numeric pooled estimate + CI shown as text to the right of the diamond (e.g., `0.42 [0.35; 0.49]`)
- For comparison measures (SMD, MD, RR, OR): also show p-value next to the pooled estimate
- Individual study rows show per-study effect size estimates as text on the right (e.g., `0.35 [0.28; 0.42]`)

### ilab Columns (Annotation)
- User specifies columns as character vector of column names: `ilab = c("dose", "regimen", "follow.up")`
- Optional `ilab.lab` for display labels; if omitted, column names used as headers
- ilab columns always appear to the LEFT of the CI axis (standard convention)
- Positions auto-calculated — no `ilab.xpos` argument; if layout needs adjustment, user changes plot width
- Consistent with Phase 1's quoted-string column name pattern

### File Output and Device Management
- Both modes: auto-saves to file AND displays in RStudio viewer when available
- `file=NULL` to skip saving (display only)
- Default filename from stored data frame name (see below)
- PNG by default; `format="pdf"` for PDF output
- User can override filename via `file` argument
- `on.exit(dev.off())` used internally to guarantee device cleanup — essential for batch loops (10+ sequential calls)
- Width and height settable via arguments; auto-scaled by default (Claude tunes the formula during planning based on grid graphics sizing)

### Working Directory and Naming
- `read_multisheet_excel()` sets `options(meta3l.mwd = dirname(path))` — globally stores the Excel file's directory
- `forest.meta3L()` reads `getOption("meta3l.mwd")` as default output directory
- `meta3L()` needs modification to accept/store a `name` argument (the sheet/outcome name) for auto-naming output files
- Default filename: `{name}.png` in the `meta3l.mwd` directory

### Zebra Shading
- Alternating study rows have zebra shading (FRST-05)
- Default color: `rgb(0.92, 0.92, 0.92)` (light gray, proven in working Rmd)
- Customizable via `colshade` argument

### Reference Line
- Auto-detected from measure: PLO/PAS → no refline, SMD/MD → refline at 0, RR/OR → refline at 1 (on exp scale)
- User can override with explicit `refline` argument

### Sort Order
- Default: rows appear in data frame order (original order)
- User can pass `sortvar` argument (column name as string) to reorder studies (e.g., `sortvar="year"` or `sortvar="yi"`)

### Claude's Discretion
- Exact grid viewport layout and coordinate calculations
- Typography (font sizes, families) within grid graphics
- Auto-scale formula tuning for dimensions (base + nrow * per_row pattern from Rmd as starting point)
- Loading skeleton / progress messaging for batch operations
- Internal helper function decomposition (draw_square, draw_diamond, draw_ci_line, etc.)
- Spacing between ilab columns and axis area
- How to handle studies with CIs extending beyond xlim (arrows/truncation)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `meta3l_result` S3 object (R/meta3L.R): Contains `$model`, `$data`, `$V`, `$i2`, `$transf`, `$slab`, `$cluster`, `$measure`, `$estimate`, `$ci.lb`, `$ci.ub` — all needed for forest plot
- `resolve_transf()` in R/utils.R: Already maps measure → back-transform function; reusable for axis labeling
- `REQUIRED_COLS` in R/utils.R: Measure validation already centralized
- `forest_template.R` (~12k lines): `meta::forest.meta` source code — reference implementation for grid-based forest plot architecture
- `three_level.Rmd`: Working forest plot code using metafor::forest() with ilab, shade, and I² label — reference for expected output

### Established Patterns
- Column names as quoted strings (character), not NSE — Phase 1 convention
- `stop()/warning()` with `call. = FALSE` — no cli dependency for errors
- R >= 4.0 compatibility — no native pipe `|>` or lambda `\(x)`
- One file per exported function pattern
- roxygen2 for documentation and NAMESPACE

### Integration Points
- `forest.meta3L()` dispatches on `meta3l_result` class via S3 method dispatch
- `read_multisheet_excel()` needs minor modification: set `options(meta3l.mwd = dirname(path))`
- `meta3L()` needs minor modification: accept and store a `name` argument for auto-naming
- Phase 3 will reuse drawing primitives (diamond, CI line, square grobs) for subgroup forest plots

</code_context>

<specifics>
## Specific Ideas

- Mimic `meta::forest.meta` visual style as closely as possible — it's the gold standard for R meta-analysis forest plots
- The working Rmd (three_level.Rmd) is the functional reference for expected behavior — same ilab columns, same I² format, same zebra shading
- For comparison measures, p-value should appear with the pooled estimate (reviewer expectation)
- Batch loop safety is critical — the research group runs 10-20+ outcomes sequentially; device corruption would break the entire pipeline

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-forest-plot-file-output*
*Context gathered: 2026-03-10*

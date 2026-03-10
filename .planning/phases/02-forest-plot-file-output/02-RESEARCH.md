# Phase 2: Forest Plot and File Output - Research

**Researched:** 2026-03-10
**Domain:** Grid graphics forest plot for three-level meta-analysis results in R
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Plot Engine**
- Build a custom grid-graphics forest plot from scratch using grid::viewport/grob system
- Visual style mimics `meta::forest.meta` (from `forest_template.R` reference) — squares proportional to weight, horizontal CI lines, diamond for pooled
- NOT wrapping metafor::forest() (which is base R graphics) — building native grid
- Axis always shows back-transformed values: PLO/PAS → probability scale (0-1), RR/OR → exp scale, SMD/MD → raw scale
- Weight column shown by default, hideable via `showweights=FALSE` argument

**Summary Label and Pooled Display**
- Pooled diamond display mimics `meta::forest.meta` — diamond with "Random effects model" label and heterogeneity stats on a separate line below
- I² format in heterogeneity line: `RE Model | I² = 85% (between: 60%, within: 25%)`
- Numeric pooled estimate + CI shown as text to the right of the diamond (e.g., `0.42 [0.35; 0.49]`)
- For comparison measures (SMD, MD, RR, OR): also show p-value next to the pooled estimate
- Individual study rows show per-study effect size estimates as text on the right (e.g., `0.35 [0.28; 0.42]`)

**ilab Columns (Annotation)**
- User specifies columns as character vector of column names: `ilab = c("dose", "regimen", "follow.up")`
- Optional `ilab.lab` for display labels; if omitted, column names used as headers
- ilab columns always appear to the LEFT of the CI axis (standard convention)
- Positions auto-calculated — no `ilab.xpos` argument; if layout needs adjustment, user changes plot width
- Consistent with Phase 1's quoted-string column name pattern

**File Output and Device Management**
- Both modes: auto-saves to file AND displays in RStudio viewer when available
- `file=NULL` to skip saving (display only)
- Default filename from stored data frame name (see below)
- PNG by default; `format="pdf"` for PDF output
- User can override filename via `file` argument
- `on.exit(dev.off())` used internally to guarantee device cleanup — essential for batch loops (10+ sequential calls)
- Width and height settable via arguments; auto-scaled by default (Claude tunes the formula during planning based on grid graphics sizing)

**Working Directory and Naming**
- `read_multisheet_excel()` sets `options(meta3l.mwd = dirname(path))` — globally stores the Excel file's directory
- `forest.meta3L()` reads `getOption("meta3l.mwd")` as default output directory
- `meta3L()` needs modification to accept/store a `name` argument (the sheet/outcome name) for auto-naming output files
- Default filename: `{name}.png` in the `meta3l.mwd` directory

**Zebra Shading**
- Alternating study rows have zebra shading (FRST-05)
- Default color: `rgb(0.92, 0.92, 0.92)` (light gray, proven in working Rmd)
- Customizable via `colshade` argument

**Reference Line**
- Auto-detected from measure: PLO/PAS → no refline, SMD/MD → refline at 0, RR/OR → refline at 1 (on exp scale)
- User can override with explicit `refline` argument

**Sort Order**
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

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FRST-01 | Forest plot displays study-level point estimates with confidence intervals | grid::grid.rect (squares) + grid::grid.segments (CI lines); sizes proportional to weight from model |
| FRST-02 | Pooled effect shown as summary diamond | grid::grid.polygon with 4-point diamond geometry; row below last study |
| FRST-03 | Multilevel I² (total, between, within) displayed in summary label | `x$i2` list already computed by meta3L(); formatted as `RE Model | I² = X% (between: Y%, within: Z%)` |
| FRST-04 | User-defined `ilab` columns supported (e.g., dose, regimen, follow-up) | Auto-computed x-positions in left region; grid::grid.text per cell + header row |
| FRST-05 | Zebra shading for alternating study rows | grid::grid.rect across full plot width for even/odd rows; default rgb(0.92,0.92,0.92) |
| FRST-06 | Grid graphics system (not base R) for publication-quality output | grid package (base R distribution, no install needed); viewport/layout architecture from forest_template.R |
| OUTP-01 | PNG output by default, PDF supported via argument | png()/pdf() device open, draw, on.exit(dev.off()); format="pdf" switch |
| OUTP-02 | Filename defaults to data frame name (from Excel sheet), overridable | getOption("meta3l.mwd") + x$name; user override via file= argument |
| OUTP-03 | Image dimensions settable via arguments with auto-estimation based on number of studies | width defaults to fixed value (~3000px); height = max(800, base_px + nrow*row_px) pattern from Rmd |
</phase_requirements>

---

## Summary

Phase 2 builds a custom grid-graphics forest plot function `forest.meta3L()` that dispatches as an S3 method on the `meta3l_result` class produced by Phase 1. The technical challenge is building a multi-region grid layout from scratch (study labels, ilab annotation columns, CI axis panel, text results panel) without relying on metafor's base-R `forest()` function or the meta package's 12,000-line `forest.meta` implementation.

The `grid` package (part of R's base distribution — no additional install required) provides the viewport/grob system needed. The architecture involves a single `grid.layout()` call that allocates columns for: study labels, ilab columns, the CI axis viewport, and the results text panel. Each row maps to a `unit(..., "lines")` height in the layout. Individual elements (squares, CI lines, diamonds, zebra rects, text) are drawn by pushing into the appropriate sub-viewport and calling `grid.rect`, `grid.segments`, `grid.polygon`, and `grid.text`.

The three existing assets that directly inform the implementation are: (1) `forest_template.R` — the full `meta::forest.meta` source, which reveals the exact grid layout pattern, the `col.forest` list structure, and how `draw.forest()`/`draw.lines()`/`draw.axis()` helpers are organized; (2) `three_level.Rmd` — the working metafor-based pipeline confirming the exact `mlab` format, `shade`, `colshade`, `ilab`, and `ilab.lab` patterns and the PNG auto-scale formula `max(800, 200 + nrow(dat) * 80)` at 300 dpi; (3) `meta3l_result` S3 object — already carries every field the plot needs (`$model`, `$data`, `$V`, `$i2`, `$transf`, `$slab`, `$measure`, `$estimate`, `$ci.lb`, `$ci.ub`).

**Primary recommendation:** Use a flat `grid.layout` with `unit("lines")` heights and `unit("null")` / `unit("cm")` widths; push a dedicated viewport for each panel region; draw all graphical primitives with `grid.*` functions inside those viewports using native plot-scale (`xscale`) coordinates.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| grid | base R | Viewport layout, grob drawing (rect, polygon, segments, text, xaxis) | Ships with R >= 4.0; only system that gives full layout control for multi-column forest plots |
| grDevices | base R | png()/pdf() device open/close, rgb() color spec | Ships with R; required for file output |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| metafor | >= 4.0 | Already a dependency; `predict.rma.mv()` needed if we want per-study fitted values vs. using `$data$yi` directly | Use `x$data$yi` and `x$data$vi` — already escalc output, no extra predict() call needed |
| rstudioapi | >= 0.13 | Already a dependency; detect RStudio viewer for display-only mode | `rstudioapi::isAvailable()` before attempting viewer display |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom grid layout | Wrap metafor::forest() | metafor::forest() is base R graphics — cannot mix with grid, cannot achieve FRST-06 |
| Custom grid layout | Wrap meta::forest.meta() | Would require adding `meta` to Imports (heavy dependency), and meta objects differ from meta3l_result structure |
| png()/pdf() devices | ragg::agg_png() | ragg provides better font rendering but adds a dependency; base png() is sufficient at 300 dpi |

**Installation:** No additional packages required. `grid` and `grDevices` are base R.

---

## Architecture Patterns

### Recommended Project Structure

```
meta3l/R/
├── forest.meta3L.R          # S3 method: forest.meta3L(x, ...)  [new — Phase 2]
├── forest_helpers.R         # draw_square(), draw_diamond(), draw_ci_line(),
│                            # draw_zebra(), draw_axis_panel()   [new — Phase 2]
├── meta3L.R                 # ADD: name= argument storage       [modify — Phase 2]
├── read_multisheet_excel.R  # ADD: options(meta3l.mwd=...)      [modify — Phase 2]
├── utils.R                  # Unchanged
├── print.meta3l_result.R    # Unchanged
└── summary.meta3l_result.R  # Unchanged
```

### Pattern 1: Grid Layout — Multi-Column Forest Plot

**What:** One `grid.layout()` call allocates all columns and rows. Column widths are fixed (`unit("cm")` or `unit("null")`) except the CI panel which expands to fill remaining space. Row heights are all `unit(1, "lines")` uniformly, enabling row-to-y mapping by arithmetic.

**When to use:** Whenever a plot has text columns flanking a data panel.

**Example:**
```r
# Source: grid package documentation + meta::forest.meta forest_template.R lines 11511-11516
grid.newpage()
# Layout: [studlab | ilab_1 ... ilab_n | gap | CI_panel | gap | results_text]
# Widths computed from strwidth() of longest label in each text column
col_widths <- unit(
  c(max_studlab_cm, rep(ilab_col_cm, n_ilab), gap_cm, NA, gap_cm, results_cm),
  c(rep("cm", 1 + n_ilab + 1), "null", "cm", "cm")
)
row_heights <- unit(rep(1, n_rows + n_header + n_footer), "lines")
pushViewport(viewport(
  layout = grid.layout(
    nrow    = n_rows + n_header + n_footer,
    ncol    = length(col_widths),
    widths  = col_widths,
    heights = row_heights
  )
))
```

### Pattern 2: Per-Panel Viewport with xscale

**What:** Push a viewport scoped to a single cell of the layout with `xscale` set to the data range. Draw graphical primitives using `unit(value, "native")` to map data coordinates directly.

**When to use:** For the CI axis panel — all CI lines, squares, diamonds, refline, axis ticks.

**Example:**
```r
# Source: meta::forest.meta architecture (forest_template.R lines 11999-12008)
pushViewport(viewport(
  layout.pos.row = row_i,
  layout.pos.col = ci_col,
  xscale = xlim  # e.g. c(-0.1, 1.1) for probability scale
))
# Draw CI line for study i
grid.segments(
  x0 = unit(ci_lb_bt[i], "native"),
  x1 = unit(ci_ub_bt[i], "native"),
  y0 = unit(0.5, "npc"),
  y1 = unit(0.5, "npc"),
  gp = gpar(lwd = 1)
)
popViewport()
```

### Pattern 3: Square Proportional to Weight

**What:** Square half-height = `sqrt(w_i / max(w)) * squaresize * 0.5` in "lines" units. Square is drawn as a filled rectangle centered on row midpoint.

**When to use:** Every individual study row.

**Example:**
```r
# Source: forest_template.R lines 10688-10713 (weight / information calculation)
# Weights from robust model
w <- 1 / sqrt(x$data$vi)           # precision weights
w_norm <- w / max(w, na.rm = TRUE) * squaresize  # normalized, default squaresize=1

# Draw square in CI panel viewport (already pushed with correct xscale)
half_h <- w_norm[i] * 0.4  # fraction of line height
grid.rect(
  x     = unit(yi_bt[i], "native"),
  y     = unit(0.5, "npc"),
  width = unit(half_h, "lines"),     # square: width == height
  height= unit(half_h, "lines"),
  just  = "centre",
  gp    = gpar(fill = col.square, col = col.square.lines, lwd = lwd.square)
)
```

### Pattern 4: Diamond for Pooled Estimate

**What:** A 4-vertex polygon: left tip at ci.lb, right tip at ci.ub, top and bottom tips at center x ± 0 with y offset of ±half_height. All in `"native"` x, `"npc"` y relative to row viewport.

**When to use:** Pooled estimate row only.

**Example:**
```r
# Source: meta::forest.meta type="diamond" logic (forest_template.R ~line 10664)
# Pooled estimate (back-transformed): est, lb, ub
half_h_diam <- 0.35  # fraction of line height for diamond half-height
grid.polygon(
  x  = unit(c(lb, est, ub, est), "native"),
  y  = unit(c(0.5, 0.5 + half_h_diam, 0.5, 0.5 - half_h_diam), "npc"),
  gp = gpar(fill = col.diamond, col = col.diamond.lines, lwd = lwd.diamond)
)
```

### Pattern 5: Device Lifecycle with on.exit

**What:** Open PNG/PDF device, register `on.exit(dev.off())` immediately, draw, let on.exit() clean up regardless of error.

**When to use:** Mandatory for every call that writes to file — guarantees cleanup in batch loops.

**Example:**
```r
# Source: CONTEXT.md locked decision; pattern from base R documentation
forest.meta3L <- function(x, ..., file = NULL, format = "png",
                          width = NULL, height = NULL) {
  # Compute auto-dimensions before opening device
  n_studies <- nrow(x$data)
  if (is.null(height)) height <- max(800L, 200L + n_studies * 80L)
  if (is.null(width))  width  <- 3000L

  if (!is.null(file)) {
    if (format == "pdf") {
      pdf(file, width = width / 300, height = height / 300)
    } else {
      png(file, width = width, height = height, res = 300L)
    }
    on.exit(grDevices::dev.off(), add = TRUE)
  }

  # ... all drawing code here ...
}
```

### Pattern 6: Auto-Filename from Stored Name

**What:** `meta3L()` stores a `name` field in the result; `read_multisheet_excel()` stores directory via `options(meta3l.mwd = dirname(path))`. `forest.meta3L()` assembles the default path.

**When to use:** When `file` argument is not supplied.

**Example:**
```r
# Modification to meta3L() — add name= parameter and store it
meta3L <- function(data, slab, measure, ..., name = NULL) {
  # ... existing code ...
  result$name <- name   # NULL is acceptable; forest.meta3L handles it
  result
}

# In forest.meta3L():
resolve_file <- function(x, file, format) {
  if (!is.null(file)) return(file)
  nm <- if (!is.null(x$name)) x$name else "forest_plot"
  ext <- if (format == "pdf") ".pdf" else ".png"
  mwd <- getOption("meta3l.mwd", default = getwd())
  file.path(mwd, paste0(nm, ext))
}
```

### Pattern 7: ilab Column Position Auto-Calculation

**What:** Divide the left-panel region equally among ilab columns after reserving fixed space for the study label column. No user-specified `ilab.xpos` — positions derive from column widths.

**When to use:** Whenever `ilab` argument is non-NULL.

**Implementation approach:**
```r
# Left region: studlab column (fixed width) + n_ilab equally-spaced columns
# Each ilab column gets: strwidth of longest value + padding
# Column widths computed via grid::convertWidth(stringWidth(max_label), "cm")
# These become unit("cm") entries in the layout col_widths vector
```

### Anti-Patterns to Avoid

- **Drawing in the wrong viewport:** Always push/pop explicitly; never draw after popViewport() thinking you're still in that viewport.
- **Mixing base R graphics calls (par, plot, text) with grid calls:** Once grid.newpage() is called and a device is open, all drawing must use grid::* functions. `par()` state is irrelevant to grid.
- **Opening device inside the drawing loop:** Open device once, draw all rows in a loop, close with on.exit. Opening a new device per row destroys the previous.
- **Using `dev.off()` directly without on.exit:** If drawing throws an error, the device leaks. Always `on.exit(dev.off(), add = TRUE)`.
- **Hardcoded pixel row height for all measures:** For PDF output the unit is inches, not pixels. Keep dimensions in "lines" (grid) or "cm" for device-independent layout; convert to device units only when opening the device.
- **Relying on `deparse(substitute(x))` for the name:** NSE name extraction is fragile in batch loops. Use the stored `x$name` field instead.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| String width measurement for column sizing | Custom character counting | `grid::stringWidth()` + `grid::convertWidth()` | Accounts for font metrics, cex, fontfamily; character count is wrong for proportional fonts |
| Back-transformation for axis labels | Reimplement plogis/iarcsin/exp | `x$transf` — already stored in meta3l_result | resolve_transf() is already tested; reuse it |
| Weight calculation | Custom formula | `1 / sqrt(x$data$vi)` — precision weights | Matches what metafor uses internally; simple and correct for display |
| Per-study CI extraction | Re-run predict() | `x$data$yi` and `x$data$vi` from escalc output | Data already in result; no additional computation needed |
| p-value for pooled | Re-fit model | `x$model$pval` from robust.rma object | Already computed by Phase 1 |
| I² formatting | New computation | `x$i2$total`, `x$i2$between`, `x$i2$within` | Already computed by compute_i2() in Phase 1 |
| Device-independent font size | Trial and error | `gpar(cex = 0.75)` — use consistent cex scaling | meta package uses cex=0.75 throughout; matches three_level.Rmd |

**Key insight:** All numeric inputs to the plot (yi, vi, pooled estimate, CI bounds, I² components, back-transform function) are already stored in `meta3l_result`. The forest function is purely a drawing function — it reads, formats, and renders; it does not recompute.

---

## Common Pitfalls

### Pitfall 1: Viewport Stack Corruption in Batch Loops

**What goes wrong:** If drawing code throws an error mid-render, `popViewport()` calls that follow are never executed, leaving the viewport stack in an unknown state. The next call to `grid.newpage()` may then fail or render into the wrong context.

**Why it happens:** grid maintains a mutable viewport stack; exceptions interrupt the push/pop symmetry.

**How to avoid:** Wrap the entire drawing pipeline in `tryCatch`. Alternatively, call `grid.newpage()` at the top of every `forest.meta3L()` invocation — this resets the viewport stack to the root.

**Warning signs:** Second call in a batch loop produces a blank or partially-drawn plot.

### Pitfall 2: PDF Width/Height Unit Mismatch

**What goes wrong:** `png()` takes `width` and `height` in pixels (with `res` in dpi). `pdf()` takes `width` and `height` in **inches**. Passing the same numeric value to both produces a postage-stamp PDF or a wall-sized PNG.

**Why it happens:** Different device functions use different default units.

**How to avoid:** Convert internally:
```r
if (format == "pdf") {
  pdf(file, width = width / 72, height = height / 72)  # 72 pts per inch
} else {
  png(file, width = width, height = height, res = 300L)
}
```
Use a consistent internal unit (pixels at 300 dpi) and convert at device open time.

### Pitfall 3: xlim Back-Transformation Mismatch

**What goes wrong:** For PLO/PAS measures, the axis must show probability (0–1), but `yi` values from `escalc` are on the logit/arcsine scale (can range from −4 to +4). If `xlim` is set in back-transformed units, all `unit(yi, "native")` calls will be outside the viewport.

**Why it happens:** Confusing the scale of raw yi with the display scale.

**How to avoid:** Back-transform yi before all drawing. Apply `x$transf(yi)` to individual study estimates and axis tick positions. The `xlim` argument (and `xscale` in the CI viewport) must be in back-transformed units.

```r
yi_bt  <- x$transf(x$data$yi)
ci_lb_bt <- x$transf(x$data$yi - 1.96 * sqrt(x$data$vi))
ci_ub_bt <- x$transf(x$data$yi + 1.96 * sqrt(x$data$vi))
# Default xlim for PLO/PAS:
xlim <- c(0, 1)
```

### Pitfall 4: stringsAsFactors in ilab Column Extraction

**What goes wrong:** `x$data[[ilab[j]]]` may return a factor if the data frame was created with `stringsAsFactors = TRUE` (R < 4.0 default). `as.character()` is needed before passing to `grid.text`.

**Why it happens:** Data imported from Excel via readxl is always character, but data constructed in tests may not be.

**How to avoid:** Always coerce ilab columns: `as.character(x$data[[col]])`.

### Pitfall 5: RStudio Viewer Display in Batch Mode

**What goes wrong:** In batch mode (non-interactive R), calling `rstudioapi::isAvailable()` returns FALSE, but `file` could still be NULL. The function must not attempt to open a viewer or display device when running non-interactively.

**Why it happens:** Code that works in RStudio breaks in `Rscript` or `R CMD BATCH`.

**How to avoid:**
```r
should_display <- is.null(file) || rstudioapi::isAvailable()
if (should_display && !is.null(file)) {
  # Open a separate display device
  if (rstudioapi::isAvailable()) {
    rstudioapi::viewer(file)  # display saved file
  }
}
```

### Pitfall 6: meta3L() name= Argument Breaks R CMD check if Not Documented

**What goes wrong:** Adding `name = NULL` to `meta3L()` without updating the roxygen `@param` block causes `R CMD check` to emit a NOTE (`undocumented argument`), which the project requires to be zero warnings/notes.

**Why it happens:** NAMESPACE/documentation not regenerated.

**How to avoid:** Add `@param name` to `meta3L.R` roxygen block and run `devtools::document()` before check.

---

## Code Examples

Verified patterns from official sources and project reference files:

### Grid Layout Skeleton (from forest_template.R architecture)

```r
# Source: meta::forest.meta source (forest_template.R lines 11509-11516)
grid.newpage()
pushViewport(viewport(
  layout = grid.layout(
    nrow    = total_rows,
    ncol    = n_cols,
    widths  = col_widths,   # unit() vector
    heights = unit(rep(1, total_rows), "lines")
  )
))
# Access cell (r, c):
pushViewport(viewport(layout.pos.row = r, layout.pos.col = c))
# ... draw ...
popViewport()
popViewport()  # back to root
```

### PNG Device Open/Close (from three_level.Rmd lines 265-270)

```r
# Source: three_level.Rmd (project root)
png(
  png_path,
  width  = 3000L,
  height = max(800L, 200L + nrow(dat) * 80L),
  res    = 300L
)
op <- par(no.readonly = TRUE)
# ... drawing ...
par(op)
dev.off()
```

For grid-based drawing, `par()` is not used — the equivalent is managing the viewport stack.

### I² Label Format (from three_level.Rmd lines 290-295)

```r
# Source: three_level.Rmd mlab sprintf (line 291-294)
mlab_text <- sprintf(
  "RE Model  |  I\u00b2 = %.0f%% (between: %.0f%%, within: %.0f%%)",
  x$i2$total, x$i2$between, x$i2$within
)
```

### Back-Transformation for CI (from utils.R resolve_transf)

```r
# Source: meta3l/R/utils.R resolve_transf()
# x$transf is already the correct function for the measure
yi_bt    <- x$transf(x$data$yi)
ci_lb_bt <- x$transf(x$data$yi - 1.96 * sqrt(x$data$vi))
ci_ub_bt <- x$transf(x$data$yi + 1.96 * sqrt(x$data$vi))
est_bt   <- x$estimate   # already back-transformed in meta3l_result
lb_bt    <- x$ci.lb
ub_bt    <- x$ci.ub
```

### Zebra Shading (from three_level.Rmd line 210-211)

```r
# Source: three_level.Rmd shade/colshade arguments
# In pure grid: draw a rect spanning full CI viewport width for shaded rows
shade_rows <- which(seq_len(n_studies) %% 2 == 0)  # even rows shaded
# Inside each shaded row's CI viewport:
grid.rect(
  x = unit(0.5, "npc"), y = unit(0.5, "npc"),
  width = unit(1, "npc"), height = unit(1, "npc"),
  gp = gpar(fill = colshade, col = NA)
)
```

### Weight-Proportional Square Size

```r
# Source: forest_template.R lines 10688-10713 pattern
w     <- 1 / sqrt(x$data$vi)
w_max <- max(w, na.rm = TRUE)
sizes <- (w / w_max) * squaresize  # squaresize default 1.0
# sizes[i] is the half-height of study i's square as fraction of line height
```

### S3 Method Dispatch Signature

```r
# Source: project CONTEXT.md + Phase 1 print.meta3l_result.R pattern
#' @export
forest.meta3L <- function(x,
                          ilab        = NULL,
                          ilab.lab    = NULL,
                          sortvar     = NULL,
                          refline     = NULL,
                          xlim        = NULL,
                          at          = NULL,
                          xlab        = NULL,
                          showweights = TRUE,
                          colshade    = rgb(0.92, 0.92, 0.92),
                          squaresize  = 1,
                          file        = character(0),  # sentinel: auto-name
                          format      = "png",
                          width       = NULL,
                          height      = NULL,
                          ...) {
  stopifnot(inherits(x, "meta3l_result"))
  # ...
}
```

Note: `file = character(0)` (empty character vector) as sentinel distinguishes "not supplied" (auto-name) from `file = NULL` (display only). Alternatively `file = "AUTO"` can be used — the planner should choose the sentinel convention.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| metafor::forest() with base R par/plot | grid-based custom forest plot | Locked in CONTEXT.md | Full layout control, publication quality, no base-R graphics interference |
| Hard-coded ilab.xpos positions | Auto-computed from stringWidth | Phase 2 decision | User never needs to adjust xpos; layout adapts to any ilab content |
| Separate display and save calls | Single call saves + optionally displays | Phase 2 decision | Simpler API; batch loops don't need extra display management |

**Deprecated/outdated in this project:**
- `metafor::forest()` for this package's output: base R graphics, cannot mix with grid, no zebra shading control, no multilevel I² label — NOT used.
- `meta::forest.meta()`: requires wrapping result in a meta object, introduces heavy dependency — NOT used.

---

## Open Questions

1. **file= sentinel convention for "auto-name" vs "display only"**
   - What we know: `file = NULL` means display only; we need a distinct sentinel for "auto-name from x$name"
   - What's unclear: Whether `character(0)` (empty character) or a special string "AUTO" is cleaner R idiom
   - Recommendation: Use `missing()` check on the `file` argument: `if (missing(file)) { use_auto_name }` vs `if (is.null(file)) { display_only }` — this is idiomatic R and avoids sentinel value complexity

2. **xlim auto-calculation for different measures**
   - What we know: PLO/PAS → c(0,1); RR/OR → c(exp(min_yi_raw - margin), exp(max_yi_raw + margin)); SMD/MD → symmetric around 0
   - What's unclear: Edge cases where all studies cluster near 0 or 1 for proportions
   - Recommendation: Compute data-driven xlim as `range(c(ci_lb_bt, ci_ub_bt)) + c(-0.05, 0.05) * diff(range(...))`, then override with user-supplied `xlim` if provided

3. **CI arrows for truncated estimates**
   - What we know: CONTEXT.md delegates this to Claude's discretion
   - What's unclear: Whether to draw arrows when CI extends beyond xlim (as metafor does) or simply clip silently
   - Recommendation: Draw arrows (arrowhead at xlim boundary) — this is the standard convention and matches metafor's behavior; silently clipping is misleading

4. **grid stringWidth for column sizing requires a device to be open**
   - What we know: `grid::stringWidth()` requires an active graphics device to compute text metrics
   - What's unclear: Whether column widths should be computed before or after opening the file device
   - Recommendation: Open a temporary `pdf(nullfile())` device, compute widths, close it, then open the actual file device. This avoids device-dependent sizing inconsistencies.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | testthat 3.0.0 (Config/testthat/edition: 3 in DESCRIPTION) |
| Config file | `meta3l/tests/testthat.R` |
| Quick run command | `devtools::test(filter = "forest")` (from project root inside `meta3l/`) |
| Full suite command | `devtools::test()` or `R CMD check meta3l` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FRST-01 | `forest.meta3L()` returns invisibly and produces a file; file is non-empty | smoke | `devtools::test(filter = "forest")` | Wave 0 |
| FRST-01 | Study rows contain numeric yi_bt values (spot-check via recorded data) | unit | `devtools::test(filter = "forest")` | Wave 0 |
| FRST-02 | Pooled diamond row drawn (test via mock: draw_diamond called with correct args) | unit | `devtools::test(filter = "forest")` | Wave 0 |
| FRST-03 | mlab text includes I² total, between, within from x$i2 | unit | `devtools::test(filter = "forest")` | Wave 0 |
| FRST-04 | With `ilab = c("dose")`, file produced without error; ilab column appears in layout | smoke | `devtools::test(filter = "forest")` | Wave 0 |
| FRST-05 | Zebra shading: even rows have rect drawn with colshade color | unit (mock) | `devtools::test(filter = "forest")` | Wave 0 |
| FRST-06 | No base-R graphics calls (par, plot, text) in forest.meta3L.R source | static | grep check in test | Wave 0 |
| OUTP-01 | PNG file produced by default; PDF file produced with format="pdf" | smoke | `devtools::test(filter = "forest")` | Wave 0 |
| OUTP-02 | Default filename = paste0(x$name, ".png") in meta3l.mwd directory | unit | `devtools::test(filter = "forest")` | Wave 0 |
| OUTP-03 | Auto-height = max(800, 200 + nrow * 80) when height=NULL; user height overrides | unit | `devtools::test(filter = "forest")` | Wave 0 |

**Notes on testing grid graphics:** `grid.*` drawing calls cannot easily be inspected for exact grob content in testthat without snapshot testing. The pragmatic approach is:
1. Smoke tests: call `forest.meta3L()` with a fixture, assert file is created and non-empty (file.info()$size > 1000).
2. Unit tests for helper functions: test `draw_diamond()`, `draw_square()`, `resolve_file()`, `auto_xlim()` in isolation with mock viewports (using `withr::local_pdf(tempfile())` or `pdf(nullfile())`).
3. Static test for FRST-06: `expect_false(any(grepl("^par\\(|^plot\\(|^text\\(", readLines("R/forest.meta3L.R"))))`.

### Sampling Rate
- **Per task commit:** `devtools::test(filter = "forest")` — runs only forest-related tests
- **Per wave merge:** `devtools::test()` — full suite
- **Phase gate:** `R CMD check meta3l --no-vignettes` returns 0 errors, 0 warnings before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `meta3l/tests/testthat/test-forest.meta3L.R` — covers FRST-01 through FRST-06, OUTP-01 through OUTP-03
- [ ] `meta3l/R/forest.meta3L.R` — the function itself (does not exist yet)
- [ ] `meta3l/R/forest_helpers.R` — drawing primitives (does not exist yet)

*(Existing infrastructure: `helper-fixtures.R`, `test-meta3L.R`, `test-utils.R`, `test-read_multisheet_excel.R` all exist and pass. testthat edition 3 configured.)*

---

## Sources

### Primary (HIGH confidence)

- `forest_template.R` (project root, 12,156 lines) — full `meta::forest.meta` source; confirmed grid layout architecture, `col.forest` list structure, viewport-per-column pattern, diamond type specification, `draw.forest()` call site at line 11786, `grid.newpage()` at 11509
- `three_level.Rmd` (project root) — working metafor pipeline; confirmed `max(800, 200 + nrow(dat) * 80)` PNG auto-scale formula, `rgb(0.92, 0.92, 0.92)` colshade, exact mlab sprintf format with unicode I² character, `shade = TRUE` usage
- `meta3l/R/meta3L.R` — Phase 1 output; confirmed `meta3l_result` fields: `$model`, `$data`, `$V`, `$i2`, `$transf`, `$measure`, `$slab`, `$estimate`, `$ci.lb`, `$ci.ub`
- `meta3l/R/utils.R` — confirmed `resolve_transf()` maps measure → back-transform function; reusable directly
- `meta3l/DESCRIPTION` — confirmed `grid` and `grDevices` are base R (no add to Imports); `testthat >= 3.0.0` already in Suggests
- R `grid` package documentation (base R) — viewport/layout/grob API; `unit()`, `grid.layout()`, `pushViewport()`, `popViewport()`, `grid.rect()`, `grid.polygon()`, `grid.segments()`, `grid.text()`, `stringWidth()`, `gpar()`

### Secondary (MEDIUM confidence)

- R `grDevices` documentation — `png()` uses pixels + dpi; `pdf()` uses inches — verified by reading function signatures in base R help

### Tertiary (LOW confidence)

- General R grid graphics community patterns for forest plots — not independently verified against official sources for this specific use case

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — grid and grDevices are base R; confirmed from forest_template.R and DESCRIPTION
- Architecture: HIGH — grid layout pattern directly observed in 12,156-line reference implementation; viewport/xscale pattern is line-for-line from forest_template.R
- Pitfalls: HIGH for pitfalls 1–3 (viewport leak, PDF unit mismatch, xlim scale confusion — all directly observable from code structure); MEDIUM for pitfalls 4–6 (experience-based, not formally verified in this codebase)
- Code examples: HIGH — all drawing patterns sourced from forest_template.R or three_level.Rmd project files

**Research date:** 2026-03-10
**Valid until:** 2027-03-10 (grid API is extremely stable; base R changes rarely)

# forest.meta3L.R — S3 method for forest plots of meta3l_result objects
# Uses grid graphics exclusively (no base-R plot/par/text calls).

#' Forest plot for three-level meta-analysis results
#'
#' Produces a publication-quality forest plot from a \code{meta3l_result}
#' object using grid graphics.  By default the plot is saved to a PNG file
#' whose name is derived from \code{x$name} and the \code{meta3l.mwd} option.
#' Pass \code{file = NULL} for display-only mode (renders in RStudio viewer).
#'
#' @param x A \code{meta3l_result} object returned by \code{\link{meta3L}}.
#' @param ilab Character vector of column names from \code{x$data} to display
#'   as annotation columns to the left of the CI axis.  Defaults to
#'   \code{NULL} (no annotation columns).
#' @param ilab.lab Character vector of column headers for \code{ilab} columns.
#'   If \code{NULL} (default), the column names from \code{ilab} are used.
#' @param sortvar Character string; name of a column in \code{x$data} to sort
#'   studies by (ascending).  \code{NULL} (default) preserves original order.
#' @param refline Numeric scalar; x position for a vertical reference line.
#'   \code{NULL} (default) derives the line automatically from \code{x$measure}
#'   via \code{auto_refline()}: \code{NULL} for PLO/PAS, \code{0} for SMD/MD,
#'   \code{1} for RR/OR.  Pass \code{NA} to suppress the line explicitly.
#' @param xlim Numeric vector of length 2; x-axis limits for the CI panel.
#'   \code{NULL} (default) auto-computes via \code{auto_xlim()}.
#' @param at Numeric vector of x positions for axis tick marks.  \code{NULL}
#'   (default) uses \code{pretty(xlim, n = 5)}.
#' @param xlab Character string; x-axis label.  \code{NULL} (default) omits
#'   the label.
#' @param showweights Logical; if \code{TRUE} (default) a weight column is
#'   displayed showing percentage contribution of each study.
#' @param colshade Colour used for alternating row shading (zebra stripes).
#'   Defaults to \code{rgb(0.92, 0.92, 0.92)}.
#' @param squaresize Numeric scaling factor applied to the weight-proportional
#'   study squares.  Defaults to \code{1}.
#' @param file One of: \code{character(0)} (default, auto-name from
#'   \code{x$name} and \code{meta3l.mwd} option); \code{NULL} (display only);
#'   or a character string (explicit file path).
#' @param format Character string; output format — \code{"png"} (default) or
#'   \code{"pdf"}.
#' @param width Integer; output width in pixels (PNG) or 1/300 inches (PDF).
#'   \code{NULL} auto-computes via \code{auto_dims()}.
#' @param height Integer; output height in pixels.  \code{NULL} auto-computes.
#' @param ... Currently ignored; reserved for future extension.
#'
#' @return Invisibly returns the file path (character string) of the saved
#'   plot, or \code{NULL} if \code{file = NULL} (display only).
#'
#' @examples
#' \dontrun{
#' d <- data.frame(
#'   studlab = rep(c("Smith, 2020", "Jones, 2021"), each = 3),
#'   xi = c(10, 12, 8, 15, 11, 9),
#'   ni = c(50, 55, 48, 60, 52, 47)
#' )
#' r <- meta3L(d, slab = "studlab", xi = "xi", ni = "ni",
#'             measure = "PLO", name = "my_analysis")
#' forest.meta3L(r)                                   # auto-named PNG
#' forest.meta3L(r, file = "my_plot.pdf", format = "pdf")
#' forest.meta3L(r, ilab = c("xi", "ni"),
#'               ilab.lab = c("Events", "Total"))
#' }
#'
#' @importFrom metafor forest
#' @importFrom grDevices rgb png pdf dev.off
#' @method forest meta3L
#' @export
forest.meta3L <- function(x,
                          ilab        = NULL,
                          ilab.lab    = NULL,
                          sortvar     = NULL,
                          refline     = NULL,
                          xlim        = NULL,
                          at          = NULL,
                          xlab        = NULL,
                          title       = x$name,
                          showweights = TRUE,
                          shade       = "zebra",
                          colshade    = rgb(0.92, 0.92, 0.92),
                          squaresize  = 1,
                          file        = character(0),
                          format      = "png",
                          width       = NULL,
                          height      = NULL,
                          ...) {

  # -------------------------------------------------------------------
  # 1. Validate input
  # -------------------------------------------------------------------
  stopifnot(inherits(x, "meta3l_result"))

  # -------------------------------------------------------------------
  # 2. Extract and back-transform data
  # -------------------------------------------------------------------
  yi_bt    <- x$transf(x$data$yi)
  ci_lb_bt <- x$transf(x$data$yi - stats::qnorm(0.975) * sqrt(x$data$vi))
  ci_ub_bt <- x$transf(x$data$yi + stats::qnorm(0.975) * sqrt(x$data$vi))
  slab_vals <- x$data[[x$slab]]
  n_studies <- nrow(x$data)

  # Weights (normalised to max = 1)
  w        <- 1 / sqrt(x$data$vi)
  w_max    <- max(w, na.rm = TRUE)
  w_norm   <- (w / w_max) * squaresize

  # -------------------------------------------------------------------
  # 3. Sort if requested
  # -------------------------------------------------------------------
  if (!is.null(sortvar)) {
    ord      <- order(x$data[[sortvar]])
    yi_bt    <- yi_bt[ord]
    ci_lb_bt <- ci_lb_bt[ord]
    ci_ub_bt <- ci_ub_bt[ord]
    slab_vals <- slab_vals[ord]
    w_norm   <- w_norm[ord]
    w        <- w[ord]
  }

  # -------------------------------------------------------------------
  # 4. Compute layout parameters
  # -------------------------------------------------------------------
  xlim_final    <- if (!is.null(xlim)) xlim else auto_xlim(x$measure, yi_bt, ci_lb_bt, ci_ub_bt)
  refline_final <- if (!is.null(refline)) refline else auto_refline(x$measure)
  mlab          <- format_mlab(x$i2)

  n_ilab      <- if (!is.null(ilab)) length(ilab) else 0L
  ilab_labels <- if (!is.null(ilab.lab)) ilab.lab else ilab

  # Detect intervention / control column groups for pairwise measures
  has_groups <- FALSE
  if (x$measure %in% c("SMD", "MD", "RR", "OR") && n_ilab > 0L) {
    e_idx <- which(grepl("\\.e$", ilab))
    c_idx <- which(grepl("\\.c$", ilab))
    has_groups <- length(e_idx) > 0L && length(c_idx) > 0L
  }
  group_offset <- if (has_groups) 1L else 0L

  # -------------------------------------------------------------------
  # 5. Compute text for right panel
  # -------------------------------------------------------------------
  study_text <- character(n_studies)
  for (i in seq_len(n_studies)) {
    study_text[i] <- sprintf("%.2f [%.2f; %.2f]",
                             yi_bt[i], ci_lb_bt[i], ci_ub_bt[i])
  }

  pooled_text <- sprintf("%.2f [%.2f; %.2f]",
                         x$estimate, x$ci.lb, x$ci.ub)

  weight_text <- sprintf("%.1f%%", (w / sum(w)) * 100)

  # -------------------------------------------------------------------
  # 6. Resolve file path and open device
  # -------------------------------------------------------------------
  # Pre-compute wrapped ilab values and per-column widths
  ilab_wrapped    <- list()
  ilab_col_widths <- numeric(n_ilab)
  has_wrapped     <- FALSE
  if (n_ilab > 0L) {
    for (j in seq_len(n_ilab)) {
      vals <- as.character(x$data[[ilab[j]]])
      ilab_wrapped[[j]] <- wrap_label(vals)
      if (any(grepl("\n", ilab_wrapped[[j]]))) has_wrapped <- TRUE
      lines <- unlist(strsplit(ilab_wrapped[[j]], "\n"))
      max_data_chars <- max(nchar(lines), na.rm = TRUE)
      hdr_chars <- nchar(ilab_labels[j])
      ilab_col_widths[j] <- ilab_col_cm(max(max_data_chars, hdr_chars))
    }
  }

  out_file <- resolve_file(x, file, format, suffix = "forest")

  # -------------------------------------------------------------------
  # 7. Build grid layout
  # -------------------------------------------------------------------
  grid::grid.newpage()

  # Row structure (group_offset is 1 when intervention/control headers present)
  group_row   <- if (has_groups) 1L else NA_integer_
  header_row  <- 1L + group_offset
  study_rows  <- seq(2L + group_offset, n_studies + 1L + group_offset)
  has_favours <- x$measure %in% c("SMD", "MD", "RR", "OR")
  pooled_row  <- n_studies + 2L + group_offset
  axis_row    <- n_studies + 3L + group_offset
  favours_row <- if (has_favours) axis_row + 1L else NA_integer_
  title_row   <- axis_row + if (has_favours) 2L else 1L
  total_rows  <- title_row

  # Column structure:
  #   col 1          : studlab
  #   cols 2..n_ilab+1 : ilab columns (if any)
  #   col n_ilab+2   : weight column (if showweights)
  #   col n_ilab+3   : gap
  #   col n_ilab+4   : CI panel
  #   col n_ilab+5   : gap
  #   col n_ilab+6   : result text

  studlab_col <- 1L
  ilab_cols   <- if (n_ilab > 0L) seq(2L, n_ilab + 1L) else integer(0)
  weight_col  <- if (showweights) n_ilab + 2L else NA_integer_
  gap1_col    <- if (showweights) n_ilab + 3L else n_ilab + 2L
  ci_col      <- if (showweights) n_ilab + 4L else n_ilab + 3L
  gap2_col    <- if (showweights) n_ilab + 5L else n_ilab + 4L
  results_col <- if (showweights) n_ilab + 6L else n_ilab + 5L
  pval_col    <- results_col + 1L
  n_cols      <- pval_col

  # Content-adaptive widths (in cm)
  studlab_chars <- max(nchar(as.character(slab_vals)), nchar("Study"), na.rm = TRUE)
  studlab_w  <- max(2.5, ilab_col_cm(studlab_chars))
  weight_w   <- 1.2
  gap_w      <- 0.5
  pval_w     <- 1.8
  results_chars <- max(nchar(study_text), nchar(pooled_text),
                       nchar(paste0(x$measure, " [95% CI]")), na.rm = TRUE)
  results_w  <- ilab_col_cm(results_chars)

  # CI panel takes remaining space
  col_widths_cm <- numeric(n_cols)
  col_widths_cm[studlab_col] <- studlab_w
  if (n_ilab > 0L) {
    for (j in seq_len(n_ilab)) {
      col_widths_cm[ilab_cols[j]] <- ilab_col_widths[j]
    }
  }
  if (showweights) {
    col_widths_cm[weight_col] <- weight_w
  }
  col_widths_cm[gap1_col]    <- gap_w
  col_widths_cm[gap2_col]    <- gap_w
  col_widths_cm[results_col] <- results_w
  col_widths_cm[pval_col]    <- pval_w

  # Cap CI panel: floor 4 cm, ceiling so CI <= 35% of total width
  other_cm <- sum(col_widths_cm)
  ci_cm    <- max(min(6, other_cm * 0.54), 4)

  col_units_list <- vector("list", n_cols)
  for (j in seq_len(n_cols)) {
    if (j == ci_col) {
      col_units_list[[j]] <- grid::unit(ci_cm, "cm")
    } else {
      col_units_list[[j]] <- grid::unit(col_widths_cm[j], "cm")
    }
  }
  col_widths_units <- do.call(grid::unit.c, col_units_list)

  row_height_lines <- if (has_wrapped) 1.8 else 1.2
  rh <- rep(row_height_lines, total_rows)
  rh[header_row]  <- 1.5
  rh[pooled_row]  <- 1.8
  rh[axis_row]    <- 2.0
  rh[title_row]   <- 1.5
  row_heights <- grid::unit(rh, "lines")

  # -------------------------------------------------------------------
  # 7b. Open graphics device (after column widths are known)
  # -------------------------------------------------------------------
  ilab_cm  <- sum(ilab_col_widths)
  total_cm <- studlab_w + ilab_cm +
    (if (showweights) weight_w else 0) + 2 * gap_w + ci_cm + results_w + pval_w
  auto_w   <- as.integer(total_cm * 300 / 2.54) + 300L
  dims     <- auto_dims(total_rows, width, height,
                         has_wrapped = has_wrapped)
  if (is.null(width)) dims$width <- max(dims$width, auto_w)

  if (!is.null(out_file)) {
    if (identical(format, "pdf")) {
      grDevices::pdf(out_file,
                     width  = dims$width  / 300,
                     height = dims$height / 300)
    } else {
      grDevices::png(out_file,
                     width  = dims$width,
                     height = dims$height,
                     res    = 300L)
    }
  } else {
    grDevices::pdf(nullfile(),
                   width  = dims$width  / 300,
                   height = dims$height / 300)
  }
  on.exit(grDevices::dev.off(), add = TRUE)

  root_layout <- grid::grid.layout(
    nrow    = total_rows,
    ncol    = n_cols,
    widths  = col_widths_units,
    heights = row_heights
  )
  grid::pushViewport(grid::viewport(
    layout = root_layout,
    x      = grid::unit(0.4, "cm"),
    y      = grid::unit(0, "npc"),
    width  = grid::unit(1, "npc") - grid::unit(0.4, "cm"),
    height = grid::unit(1, "npc") - grid::unit(0.4, "cm"),
    just   = c("left", "bottom")
  ))

  # Helper: push a layout viewport cell
  push_cell <- function(row, col,
                        xscale = c(0, 1),
                        clip = "off") {
    grid::pushViewport(
      grid::viewport(
        layout.pos.row = row,
        layout.pos.col = col,
        xscale = xscale,
        clip   = clip
      )
    )
  }

  # Helper: span multiple cols
  push_span <- function(row, col_from, col_to,
                        xscale = c(0, 1),
                        clip = "off") {
    grid::pushViewport(
      grid::viewport(
        layout.pos.row = row,
        layout.pos.col = col_from:col_to,
        xscale = xscale,
        clip   = clip
      )
    )
  }

  # -------------------------------------------------------------------
  # 7b. Draw method summary (two lines, centred above plot)
  # -------------------------------------------------------------------
  # 7c. Draw group header row (intervention / control)
  # -------------------------------------------------------------------
  bold_gp  <- grid::gpar(fontface = "bold", cex = 0.75)

  if (has_groups) {
    e_ilab_cols <- ilab_cols[e_idx]
    c_ilab_cols <- ilab_cols[c_idx]
    push_span(group_row, min(e_ilab_cols), max(e_ilab_cols))
    grid::grid.text(if (!is.null(x$group.e)) x$group.e else "Intervention",
                    x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
    grid::popViewport()
    push_span(group_row, min(c_ilab_cols), max(c_ilab_cols))
    grid::grid.text(if (!is.null(x$group.c)) x$group.c else "Control",
                    x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
    grid::popViewport()
  }

  # -------------------------------------------------------------------
  # 8. Draw header row
  # -------------------------------------------------------------------
  push_cell(header_row, studlab_col)
  grid::grid.text("Study",
                  x    = grid::unit(0.5, "npc"),
                  just = "centre",
                  gp   = bold_gp)
  grid::popViewport()

  if (n_ilab > 0L) {
    for (j in seq_len(n_ilab)) {
      push_cell(header_row, ilab_cols[j])
      grid::grid.text(ilab_labels[j],
                      x    = grid::unit(0.5, "npc"),
                      just = "centre",
                      gp   = bold_gp)
      grid::popViewport()
    }
  }

  if (showweights) {
    push_cell(header_row, weight_col)
    grid::grid.text("Weight",
                    x    = grid::unit(0.5, "npc"),
                    just = "centre",
                    gp   = bold_gp)
    grid::popViewport()
  }

  push_cell(header_row, results_col)
  grid::grid.text(paste0(x$measure, " [95% CI]"),
                  x    = grid::unit(0.5, "npc"),
                  just = "centre",
                  gp   = bold_gp)
  grid::popViewport()

  push_cell(header_row, pval_col)
  grid::grid.text("p-value",
                  x    = grid::unit(0.5, "npc"),
                  just = "centre",
                  gp   = bold_gp)
  grid::popViewport()

  # Method summary (in CI column of header row)
  method_gp <- grid::gpar(fontface = "bold", cex = 0.65)
  push_cell(header_row, ci_col)
  grid::grid.text(sprintf("Inverse Variance, %s", x$measure),
                  x    = grid::unit(0.5, "npc"),
                  y    = grid::unit(0.65, "npc"),
                  just = "centre",
                  gp   = method_gp)
  grid::grid.text(sprintf("Three-Level, \u03c1 = %.1f", x$rho),
                  x    = grid::unit(0.5, "npc"),
                  y    = grid::unit(0.3, "npc"),
                  just = "centre",
                  gp   = method_gp)
  grid::popViewport()

  # -------------------------------------------------------------------
  # 9. Draw study rows
  # -------------------------------------------------------------------
  norm_gp <- grid::gpar(cex = 0.75)

  # Pre-compute shade mask
  if (identical(shade, "cluster")) {
    clust_vals <- x$data[[x$cluster]]
    if (!is.null(sortvar)) clust_vals <- clust_vals[order(x$data[[sortvar]])]
    clust_ids  <- as.integer(factor(clust_vals, levels = unique(clust_vals)))
    shade_mask <- clust_ids %% 2L == 1L
  } else {
    shade_mask <- seq_len(n_studies) %% 2L == 0L
  }

  for (i in seq_len(n_studies)) {
    row_i <- study_rows[i]

    # Row shading
    if (shade_mask[i]) {
      push_span(row_i, studlab_col, pval_col)
      draw_zebra_rect(colshade)
      grid::popViewport()
    }

    # Study label
    push_cell(row_i, studlab_col)
    grid::grid.text(as.character(slab_vals[i]),
                    x    = grid::unit(0.5, "npc"),
                    just = "centre",
                    gp   = norm_gp)
    grid::popViewport()

    # ilab columns
    if (n_ilab > 0L) {
      for (j in seq_len(n_ilab)) {
        push_cell(row_i, ilab_cols[j])
        wrapped <- ilab_wrapped[[j]]
        if (!is.null(sortvar)) wrapped <- wrapped[order(x$data[[sortvar]])]
        grid::grid.text(wrapped[i],
                        x    = grid::unit(0.5, "npc"),
                        y    = grid::unit(0.5, "npc"),
                        just = "centre",
                        gp   = norm_gp)
        grid::popViewport()
      }
    }

    # Weight column
    if (showweights) {
      push_cell(row_i, weight_col)
      grid::grid.text(weight_text[i],
                      x    = grid::unit(0.5, "npc"),
                      just = "centre",
                      gp   = norm_gp)
      grid::popViewport()
    }

    # CI panel
    push_cell(row_i, ci_col, xscale = xlim_final, clip = "on")

    # Clamp CI to xlim and draw arrows if truncated
    lb_draw <- max(ci_lb_bt[i], xlim_final[1])
    ub_draw <- min(ci_ub_bt[i], xlim_final[2])
    truncated_left  <- ci_lb_bt[i] < xlim_final[1]
    truncated_right <- ci_ub_bt[i] > xlim_final[2]

    if (truncated_left || truncated_right) {
      # Draw line with potential arrows at truncation points
      arrow_ends <- if (truncated_left && truncated_right) {
        "both"
      } else if (truncated_left) {
        "first"
      } else {
        "last"
      }
      grid::grid.segments(
        x0  = grid::unit(lb_draw, "native"),
        x1  = grid::unit(ub_draw, "native"),
        y0  = grid::unit(0.5, "npc"),
        y1  = grid::unit(0.5, "npc"),
        arrow = grid::arrow(ends   = arrow_ends,
                            length = grid::unit(0.05, "inches")),
        gp  = grid::gpar(lwd = 1)
      )
    } else {
      draw_ci_line(ci_lb_bt[i], ci_ub_bt[i])
    }

    # Draw study square (only if estimate within xlim)
    if (!is.na(yi_bt[i]) &&
        yi_bt[i] >= xlim_final[1] &&
        yi_bt[i] <= xlim_final[2]) {
      draw_square(yi_bt[i], w_norm[i] * 0.8)
    }

    grid::popViewport()

    # Results text
    push_cell(row_i, results_col)
    grid::grid.text(study_text[i],
                    x    = grid::unit(0.5, "npc"),
                    just = "centre",
                    gp   = norm_gp)
    grid::popViewport()

    # p-value (empty for individual studies)
    push_cell(row_i, pval_col)
    grid::popViewport()
  }

  # -------------------------------------------------------------------
  # 11. Draw pooled row (diamond + I2 + aggregated ilab)
  # -------------------------------------------------------------------
  row_p <- pooled_row
  pool_gp <- grid::gpar(cex = 0.75, fontface = "bold")

  # "Overall" + I2 spanning studlab to gap1 (left-aligned, matching subgroup)
  n_clusters <- length(unique(x$data[[x$cluster]]))
  mlab_overall <- sprintf("k = %d | %s", n_clusters, mlab)
  push_span(row_p, studlab_col, gap1_col)
  grid::grid.text("Overall",
                  x    = grid::unit(0, "npc"),
                  y    = grid::unit(0.65, "npc"),
                  just = "left",
                  gp   = pool_gp)
  grid::grid.text(mlab_overall,
                  x    = grid::unit(0, "npc"),
                  y    = grid::unit(0.25, "npc"),
                  just = "left",
                  gp   = grid::gpar(cex = 0.65, fontface = "italic"))
  grid::popViewport()

  # Aggregated ilab values (n/events/mean/SD per cluster)
  if (n_ilab > 0L) {
    agg_data <- x$data
    if (!is.null(sortvar)) agg_data <- agg_data[order(agg_data[[sortvar]]), ]
    cluster_vals <- agg_data[[x$cluster]]
    for (j in seq_len(n_ilab)) {
      col_vals <- agg_data[[ilab[j]]]
      agg <- aggregate_ilab_col(col_vals, ilab[j], cluster_vals,
                                data = agg_data)
      if (nzchar(agg)) {
        push_cell(row_p, ilab_cols[j])
        grid::grid.text(agg,
                        x    = grid::unit(0.5, "npc"),
                        y    = grid::unit(0.65, "npc"),
                        just = "centre",
                        gp   = pool_gp)
        grid::popViewport()
      }
    }
  }

  # Overall weight (100%)
  if (showweights) {
    push_cell(row_p, weight_col)
    grid::grid.text("100.0%",
                    x    = grid::unit(0.5, "npc"),
                    y    = grid::unit(0.65, "npc"),
                    just = "centre",
                    gp   = pool_gp)
    grid::popViewport()
  }

  # Diamond in CI panel
  push_cell(row_p, ci_col, xscale = xlim_final, clip = "on")
  draw_diamond(x$ci.lb, x$estimate, x$ci.ub, y_center = 0.65)
  grid::popViewport()

  # Pooled estimate text
  push_cell(row_p, results_col)
  grid::grid.text(pooled_text,
                  x    = grid::unit(0.5, "npc"),
                  y    = grid::unit(0.65, "npc"),
                  just = "centre",
                  gp   = grid::gpar(cex = 0.75, fontface = "bold"))
  grid::popViewport()

  # Pooled p-value
  pval_overall <- x$model$pval
  pval_str <- if (is.na(pval_overall)) "" else
    if (pval_overall < 0.001) "<0.001" else sprintf("%.4f", pval_overall)
  push_cell(row_p, pval_col)
  grid::grid.text(pval_str,
                  x    = grid::unit(0.5, "npc"),
                  y    = grid::unit(0.65, "npc"),
                  just = "centre",
                  gp   = grid::gpar(cex = 0.75, fontface = "bold"))
  grid::popViewport()

  # -------------------------------------------------------------------
  # 11b. Draw reference line (on top of data, solid black)
  # -------------------------------------------------------------------
  if (!is.null(refline_final) && !is.na(refline_final)) {
    if (refline_final >= xlim_final[1] && refline_final <= xlim_final[2]) {
      push_span(study_rows[1]:axis_row, ci_col, ci_col,
                xscale = xlim_final)
      grid::grid.segments(
        x0 = grid::unit(refline_final, "native"),
        x1 = grid::unit(refline_final, "native"),
        y0 = grid::unit(0, "npc"),
        y1 = grid::unit(1, "npc"),
        gp = grid::gpar(lty = "solid", col = "black", lwd = 0.8)
      )
      grid::popViewport()
    }
  }

  # -------------------------------------------------------------------
  # 12. Draw axis at TOP of axis row (hugs diamond row)
  # -------------------------------------------------------------------
  at_final <- if (!is.null(at)) at else pretty(xlim_final, n = 5L)
  push_cell(axis_row, ci_col, xscale = xlim_final, clip = "off")
  grid::grid.segments(
    x0 = grid::unit(xlim_final[1], "native"),
    x1 = grid::unit(xlim_final[2], "native"),
    y0 = grid::unit(1, "npc"),
    y1 = grid::unit(1, "npc"),
    gp = grid::gpar(lwd = 1)
  )
  for (.tick in at_final) {
    if (.tick >= xlim_final[1] && .tick <= xlim_final[2]) {
      grid::grid.segments(
        x0 = grid::unit(.tick, "native"),
        x1 = grid::unit(.tick, "native"),
        y0 = grid::unit(1, "npc"),
        y1 = grid::unit(1, "npc") - grid::unit(0.4, "lines"),
        gp = grid::gpar(lwd = 1)
      )
      grid::grid.text(
        format(.tick),
        x  = grid::unit(.tick, "native"),
        y  = grid::unit(1, "npc") - grid::unit(0.9, "lines"),
        gp = grid::gpar(cex = 0.65)
      )
    }
  }
  grid::popViewport()

  # -------------------------------------------------------------------
  # 13. Favours labels (below tick labels in axis row)
  # -------------------------------------------------------------------
  if (x$measure %in% c("SMD", "MD", "RR", "OR")) {
    fav_left  <- paste0("Favours ",
                        if (!is.null(x$group.c)) x$group.c else "Control")
    fav_right <- paste0("Favours ",
                        if (!is.null(x$group.e)) x$group.e else "Treatment")
    fav_gp <- grid::gpar(fontface = "bold", cex = 0.75)
    push_cell(favours_row, ci_col, xscale = xlim_final, clip = "off")
    grid::grid.text(fav_left,
                    x    = grid::unit(0.25, "npc"),
                    y    = grid::unit(0.5, "npc"),
                    just = "centre",
                    gp   = fav_gp)
    grid::grid.text(fav_right,
                    x    = grid::unit(0.75, "npc"),
                    y    = grid::unit(0.5, "npc"),
                    just = "centre",
                    gp   = fav_gp)
    grid::popViewport()
  }

  # -------------------------------------------------------------------
  # 13b. Title below favours
  # -------------------------------------------------------------------
  if (!is.null(title) && nzchar(title)) {
    push_cell(title_row, ci_col)
    grid::grid.text(title,
                    x    = grid::unit(0.5, "npc"),
                    y    = grid::unit(0.5, "npc"),
                    just = "centre",
                    gp   = grid::gpar(fontface = "bold", cex = 0.85))
    grid::popViewport()
  }

  # -------------------------------------------------------------------
  # 14. Cleanup
  # -------------------------------------------------------------------
  grid::popViewport()  # pop root layout viewport

  # on.exit handles dev.off()

  # -------------------------------------------------------------------
  # 15. Return
  # -------------------------------------------------------------------
  invisible(out_file)
}

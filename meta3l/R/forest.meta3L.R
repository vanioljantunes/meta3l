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
                          showweights = TRUE,
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
  if (x$measure %in% c("SMD", "MD", "RR", "OR")) {
    pooled_text <- paste0(pooled_text,
                          sprintf("; p = %.4f", x$model$pval))
  }

  weight_text <- sprintf("%.1f%%", (w / sum(w)) * 100)

  # -------------------------------------------------------------------
  # 6. Resolve file path and open device
  # -------------------------------------------------------------------
  out_file <- resolve_file(x, file, format)
  dims     <- auto_dims(n_studies, width, height)

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
    # Display-only: open a null PDF device for drawing
    grDevices::pdf(nullfile(),
                   width  = dims$width  / 300,
                   height = dims$height / 300)
  }
  on.exit(grDevices::dev.off(), add = TRUE)

  # -------------------------------------------------------------------
  # 7. Build grid layout
  # -------------------------------------------------------------------
  grid::grid.newpage()

  # Row structure:
  #   row 1            : header
  #   rows 2 .. n+1    : studies
  #   row n+2          : blank separator
  #   row n+3          : pooled diamond
  #   row n+4          : mlab (I2 annotation)
  #   row n+5          : x-axis  (+1 if xlab present)
  header_row  <- 1L
  study_rows  <- seq(2L, n_studies + 1L)
  blank_row   <- n_studies + 2L
  pooled_row  <- n_studies + 3L
  mlab_row    <- n_studies + 4L
  axis_row    <- n_studies + 5L
  total_rows  <- if (!is.null(xlab)) n_studies + 6L else n_studies + 5L

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
  n_cols      <- results_col

  # Fixed widths for non-CI columns (in cm)
  studlab_w  <- 3.5
  ilab_w     <- 1.5   # per ilab column
  weight_w   <- 1.0
  gap_w      <- 0.2
  results_w  <- 3.5

  # CI panel takes remaining space
  col_widths_cm <- numeric(n_cols)
  col_widths_cm[studlab_col] <- studlab_w
  if (n_ilab > 0L) {
    col_widths_cm[ilab_cols] <- ilab_w
  }
  if (showweights) {
    col_widths_cm[weight_col] <- weight_w
  }
  col_widths_cm[gap1_col]    <- gap_w
  col_widths_cm[gap2_col]    <- gap_w
  col_widths_cm[results_col] <- results_w
  # CI panel: fill remaining (use NULL = 1fr analogue via relative units)
  # We express everything in cm except the CI panel which gets "1null"
  col_units_list <- vector("list", n_cols)
  for (j in seq_len(n_cols)) {
    if (j == ci_col) {
      col_units_list[[j]] <- grid::unit(1, "null")
    } else {
      col_units_list[[j]] <- grid::unit(col_widths_cm[j], "cm")
    }
  }
  col_widths_units <- do.call(grid::unit.c, col_units_list)

  row_height_lines <- 1.2
  row_heights <- grid::unit(rep(row_height_lines, total_rows), "lines")

  root_layout <- grid::grid.layout(
    nrow    = total_rows,
    ncol    = n_cols,
    widths  = col_widths_units,
    heights = row_heights
  )
  grid::pushViewport(grid::viewport(layout = root_layout))

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
  # 8. Draw header row
  # -------------------------------------------------------------------
  bold_gp  <- grid::gpar(fontface = "bold", cex = 0.75)

  push_cell(header_row, studlab_col)
  grid::grid.text("Study",
                  x    = grid::unit(0, "npc"),
                  just = "left",
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
  grid::grid.text("Estimate [95% CI]",
                  x    = grid::unit(0, "npc"),
                  just = "left",
                  gp   = bold_gp)
  grid::popViewport()

  # -------------------------------------------------------------------
  # 9. Draw reference line (behind study data)
  # -------------------------------------------------------------------
  if (!is.null(refline_final) && !is.na(refline_final)) {
    if (refline_final >= xlim_final[1] && refline_final <= xlim_final[2]) {
      push_span(study_rows[1]:pooled_row, ci_col, ci_col,
                xscale = xlim_final)
      grid::grid.segments(
        x0 = grid::unit(refline_final, "native"),
        x1 = grid::unit(refline_final, "native"),
        y0 = grid::unit(0, "npc"),
        y1 = grid::unit(1, "npc"),
        gp = grid::gpar(lty = "dashed", col = "gray50", lwd = 0.8)
      )
      grid::popViewport()
    }
  }

  # -------------------------------------------------------------------
  # 10. Draw study rows
  # -------------------------------------------------------------------
  norm_gp <- grid::gpar(cex = 0.75)

  for (i in seq_len(n_studies)) {
    row_i <- study_rows[i]

    # Zebra shading: shade even-indexed rows (i = 2, 4, ...)
    if (i %% 2L == 0L) {
      push_span(row_i, studlab_col, results_col)
      draw_zebra_rect(colshade)
      grid::popViewport()
    }

    # Study label
    push_cell(row_i, studlab_col)
    grid::grid.text(as.character(slab_vals[i]),
                    x    = grid::unit(0, "npc"),
                    just = "left",
                    gp   = norm_gp)
    grid::popViewport()

    # ilab columns
    if (n_ilab > 0L) {
      for (j in seq_len(n_ilab)) {
        push_cell(row_i, ilab_cols[j])
        val <- x$data[[ilab[j]]]
        if (!is.null(sortvar)) {
          ord_data <- order(x$data[[sortvar]])
          val <- val[ord_data]
        }
        grid::grid.text(as.character(val[i]),
                        x    = grid::unit(0.5, "npc"),
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
                    x    = grid::unit(0, "npc"),
                    just = "left",
                    gp   = norm_gp)
    grid::popViewport()
  }

  # -------------------------------------------------------------------
  # 11. Draw pooled row (diamond)
  # -------------------------------------------------------------------
  row_p <- pooled_row

  # Pooled label
  push_cell(row_p, studlab_col)
  grid::grid.text("Random effects model",
                  x    = grid::unit(0, "npc"),
                  just = "left",
                  gp   = grid::gpar(cex = 0.75, fontface = "bold"))
  grid::popViewport()

  # Diamond in CI panel
  push_cell(row_p, ci_col, xscale = xlim_final, clip = "on")
  draw_diamond(x$ci.lb, x$estimate, x$ci.ub)
  grid::popViewport()

  # Pooled estimate text
  push_cell(row_p, results_col)
  grid::grid.text(pooled_text,
                  x    = grid::unit(0, "npc"),
                  just = "left",
                  gp   = grid::gpar(cex = 0.75, fontface = "bold"))
  grid::popViewport()

  # -------------------------------------------------------------------
  # 12. Draw mlab row
  # -------------------------------------------------------------------
  mlab_col_to <- if (n_ilab > 0L) max(ilab_cols) else studlab_col
  push_span(mlab_row, studlab_col, mlab_col_to)
  grid::grid.text(mlab,
                  x    = grid::unit(0, "npc"),
                  just = "left",
                  gp   = grid::gpar(cex = 0.65, fontface = "italic"))
  grid::popViewport()

  # -------------------------------------------------------------------
  # 13. Draw axis row
  # -------------------------------------------------------------------
  at_final <- if (!is.null(at)) at else pretty(xlim_final, n = 5L)
  push_cell(axis_row, ci_col, xscale = xlim_final, clip = "off")
  grid::grid.xaxis(at = at_final,
                   gp = grid::gpar(cex = 0.65))
  grid::popViewport()

  # Optional x-axis label
  if (!is.null(xlab) && total_rows > (n_studies + 5L)) {
    xlab_row <- n_studies + 6L
    push_cell(xlab_row, ci_col)
    grid::grid.text(xlab,
                    x    = grid::unit(0.5, "npc"),
                    just = "centre",
                    gp   = grid::gpar(cex = 0.7))
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

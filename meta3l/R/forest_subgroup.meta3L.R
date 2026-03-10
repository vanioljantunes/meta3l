# forest_subgroup.meta3L.R — Grouped subgroup forest plot for meta3l_result
# Uses grid graphics exclusively (no base-R plot/par/text calls).

# ---------------------------------------------------------------------------
# S3 generic
# ---------------------------------------------------------------------------

#' Subgroup forest plot for three-level meta-analysis results
#'
#' Produces a grouped forest plot in which studies are arranged by a subgroup
#' variable.  Each subgroup section has a bold header row, study rows with
#' CI lines and weight-proportional squares, and (when the subgroup contains
#' two or more clusters) a subgroup summary diamond annotated with per-subgroup
#' I-squared.  An omnibus Q-test for subgroup differences is shown in the
#' footer.
#'
#' @param x A \code{meta3l_result} object returned by \code{\link{meta3L}}.
#' @param ... Further arguments passed to the method.
#'
#' @return Invisibly returns the file path (character string) of the saved
#'   plot, or \code{NULL} if \code{file = NULL} (display only).
#'
#' @export
forest_subgroup <- function(x, ...) UseMethod("forest_subgroup")

# ---------------------------------------------------------------------------
# S3 method
# ---------------------------------------------------------------------------

#' @param subgroup Character string; name of the column in \code{x$data} to
#'   use as the grouping variable.  The column must be present in
#'   \code{x$data}.
#' @param overall Logical; if \code{TRUE} (default) an overall summary diamond
#'   is drawn below all subgroup sections.
#' @param ilab Character vector of column names from \code{x$data} to display
#'   as annotation columns.  Defaults to \code{NULL}.
#' @param ilab.lab Character vector of column headers for \code{ilab} columns.
#'   Defaults to \code{NULL} (uses column names).
#' @param sortvar Character string; name of a column to sort studies by
#'   within each subgroup.  \code{NULL} preserves original order.
#' @param refline Numeric scalar; x position for a vertical reference line.
#'   \code{NULL} auto-derives from \code{x$measure}.
#' @param xlim Numeric vector of length 2; x-axis limits.  \code{NULL}
#'   auto-computes.
#' @param at Numeric vector; tick mark positions.  \code{NULL} uses
#'   \code{pretty(xlim, n = 5)}.
#' @param xlab Character string; x-axis label.  \code{NULL} omits.
#' @param showweights Logical; display weight column (default \code{TRUE}).
#' @param colshade Colour for alternating row shading.
#'   Defaults to \code{rgb(0.92, 0.92, 0.92)}.
#' @param squaresize Numeric scaling factor for study squares.
#'   Defaults to \code{1}.
#' @param file One of: \code{character(0)} (default, auto-name);
#'   \code{NULL} (display only); or an explicit character file path.
#' @param format Character; \code{"png"} (default) or \code{"pdf"}.
#' @param width Integer; output width in pixels.  \code{NULL} auto-computes.
#' @param height Integer; output height in pixels.  \code{NULL} auto-computes.
#' @param ... Currently ignored.
#'
#' @rdname forest_subgroup
#' @importFrom grDevices rgb png pdf dev.off
#' @importFrom metafor rma.mv robust
#' @importFrom stats qnorm
#' @method forest_subgroup meta3L
#' @export
forest_subgroup.meta3L <- function(x,
                                   subgroup,
                                   overall     = TRUE,
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

  if (!subgroup %in% names(x$data)) {
    stop("Subgroup column '", subgroup, "' not found in x$data.", call. = FALSE)
  }

  # -------------------------------------------------------------------
  # 2. Data preparation
  # -------------------------------------------------------------------
  dat       <- x$data
  V         <- x$V
  cluster   <- x$cluster
  measure   <- x$measure

  # Preserve original subgroup order
  levels_vec <- unique(dat[[subgroup]])

  # Apply sortvar within each subgroup (sort entire dataset by subgroup + sortvar)
  if (!is.null(sortvar) && sortvar %in% names(dat)) {
    ord <- order(match(dat[[subgroup]], levels_vec), dat[[sortvar]])
    dat <- dat[ord, , drop = FALSE]
    V   <- V[ord, ord, drop = FALSE]
  } else {
    ord <- order(match(dat[[subgroup]], levels_vec))
    dat <- dat[ord, , drop = FALSE]
    V   <- V[ord, ord, drop = FALSE]
  }

  # Back-transform all observations
  yi_bt    <- x$transf(dat$yi)
  ci_lb_bt <- x$transf(dat$yi - stats::qnorm(0.975) * sqrt(dat$vi))
  ci_ub_bt <- x$transf(dat$yi + stats::qnorm(0.975) * sqrt(dat$vi))
  slab_vals <- dat[[x$slab]]

  # Weights (normalised across full dataset)
  w_raw   <- 1 / sqrt(dat$vi)
  w_sum   <- sum(w_raw, na.rm = TRUE)
  w_pct   <- (w_raw / w_sum) * 100
  w_max   <- max(w_raw, na.rm = TRUE)
  w_norm  <- (w_raw / w_max) * squaresize

  # -------------------------------------------------------------------
  # 3. Per-subgroup model fits
  # -------------------------------------------------------------------
  subgroup_results <- vector("list", length(levels_vec))
  names(subgroup_results) <- levels_vec

  for (gv in levels_vec) {
    idx     <- which(dat[[subgroup]] == gv)
    dat_g   <- dat[idx, , drop = FALSE]
    V_g     <- V[idx, idx, drop = FALSE]
    k_g     <- nrow(dat_g)
    n_clust <- length(unique(dat_g[[cluster]]))

    fit_g  <- NULL
    i2_g   <- NULL
    rob_g  <- NULL

    if (n_clust >= 2L) {
      formula_g <- stats::as.formula(
        paste0("~ 1 | ", cluster, " / TE_id")
      )
      fit_g_raw <- tryCatch(
        metafor::rma.mv(yi, V_g,
                        random = formula_g,
                        data   = dat_g),
        error = function(e) {
          tryCatch(
            metafor::rma.mv(yi, V_g,
                            random  = formula_g,
                            data    = dat_g,
                            control = list(optimizer = "bobyqa")),
            error = function(e2) NULL
          )
        }
      )
      if (!is.null(fit_g_raw)) {
        rob_g <- tryCatch(
          metafor::robust(fit_g_raw, cluster = dat_g[[cluster]],
                          clubSandwich = TRUE),
          error = function(e) fit_g_raw
        )
        fit_g <- fit_g_raw
        i2_g  <- tryCatch(
          compute_i2(fit_g, V_g),
          error = function(e) list(total = 0, between = 0, within = 0)
        )
      }
    }

    if (is.null(fit_g) || n_clust < 2L) {
      if (n_clust < 2L) {
        warning("Subgroup '", gv, "' has fewer than 2 clusters; ",
                "fitting two-level model. Diamond skipped.",
                call. = FALSE)
      }
      fit_fallback <- tryCatch(
        metafor::rma(yi, vi, data = dat_g),
        error = function(e) NULL
      )
      rob_g <- fit_fallback
      fit_g <- NULL
      if (!is.null(fit_fallback)) {
        i2_g <- list(total   = fit_fallback$I2,
                     between = 0,
                     within  = fit_fallback$I2)
      } else {
        i2_g <- list(total = 0, between = 0, within = 0)
      }
    }

    # Back-transformed per-subgroup estimate
    if (!is.null(rob_g)) {
      est_g  <- x$transf(as.numeric(rob_g$b))
      lb_g   <- x$transf(as.numeric(rob_g$ci.lb))
      ub_g   <- x$transf(as.numeric(rob_g$ci.ub))
      pval_g <- as.numeric(rob_g$pval)
    } else {
      est_g  <- NA_real_
      lb_g   <- NA_real_
      ub_g   <- NA_real_
      pval_g <- NA_real_
    }

    subgroup_results[[gv]] <- list(
      idx      = idx,
      k        = k_g,
      n_clust  = n_clust,
      fit      = fit_g,
      rob      = rob_g,
      i2       = i2_g,
      est      = est_g,
      lb       = lb_g,
      ub       = ub_g,
      pval     = pval_g,
      has_diamond = (n_clust >= 2L && !is.null(fit_g))
    )
  }

  # -------------------------------------------------------------------
  # 4. Omnibus Q-test
  # -------------------------------------------------------------------
  qtest_text <- ""
  tryCatch({
    mod_formula <- stats::as.formula(
      paste0("~ 1 | ", cluster, " / TE_id")
    )
    mods_formula <- stats::as.formula(
      paste0("~ factor(", subgroup, ")")
    )
    res_mod <- tryCatch(
      metafor::rma.mv(yi, V,
                      mods   = mods_formula,
                      random = mod_formula,
                      data   = dat),
      error = function(e) {
        tryCatch(
          metafor::rma.mv(yi, V,
                          mods    = mods_formula,
                          random  = mod_formula,
                          data    = dat,
                          control = list(optimizer = "bobyqa")),
          error = function(e2) NULL
        )
      }
    )
    if (!is.null(res_mod)) {
      qtest_text <- sprintf(
        "Test for subgroup differences: Q = %.2f, df = %d, p = %.3f",
        res_mod$QM, res_mod$m, res_mod$QMp
      )
    }
  }, error = function(e) {
    qtest_text <<- ""
  })

  # -------------------------------------------------------------------
  # 5. Compute row layout
  # -------------------------------------------------------------------
  n_total_rows <- 1L   # column header

  # Per-subgroup rows
  for (gv in levels_vec) {
    sg <- subgroup_results[[gv]]
    n_total_rows <- n_total_rows + 1L          # bold header
    n_total_rows <- n_total_rows + sg$k        # study rows
    if (sg$has_diamond) {
      n_total_rows <- n_total_rows + 1L        # subgroup diamond
    }
    n_total_rows <- n_total_rows + 1L          # blank separator
  }

  if (overall) {
    n_total_rows <- n_total_rows + 1L          # overall diamond
    n_total_rows <- n_total_rows + 1L          # overall I2 label
  }
  if (nchar(qtest_text) > 0L) {
    n_total_rows <- n_total_rows + 1L          # Q-test footer
  }
  n_total_rows <- n_total_rows + 1L            # x-axis
  if (!is.null(xlab)) {
    n_total_rows <- n_total_rows + 1L          # x-axis label
  }

  # -------------------------------------------------------------------
  # 6. Column layout (mirrors forest.meta3L)
  # -------------------------------------------------------------------
  n_ilab      <- if (!is.null(ilab)) length(ilab) else 0L
  ilab_labels <- if (!is.null(ilab.lab)) ilab.lab else ilab

  studlab_col <- 1L
  ilab_cols   <- if (n_ilab > 0L) seq(2L, n_ilab + 1L) else integer(0)
  weight_col  <- if (showweights) n_ilab + 2L else NA_integer_
  gap1_col    <- if (showweights) n_ilab + 3L else n_ilab + 2L
  ci_col      <- if (showweights) n_ilab + 4L else n_ilab + 3L
  gap2_col    <- if (showweights) n_ilab + 5L else n_ilab + 4L
  results_col <- if (showweights) n_ilab + 6L else n_ilab + 5L
  n_cols      <- results_col

  studlab_w  <- 3.5
  ilab_w     <- 1.5
  weight_w   <- 1.0
  gap_w      <- 0.2
  results_w  <- 3.5

  col_widths_cm <- numeric(n_cols)
  col_widths_cm[studlab_col] <- studlab_w
  if (n_ilab > 0L) col_widths_cm[ilab_cols] <- ilab_w
  if (showweights) col_widths_cm[weight_col] <- weight_w
  col_widths_cm[gap1_col]    <- gap_w
  col_widths_cm[gap2_col]    <- gap_w
  col_widths_cm[results_col] <- results_w

  col_units_list <- vector("list", n_cols)
  for (j in seq_len(n_cols)) {
    if (j == ci_col) {
      col_units_list[[j]] <- grid::unit(1, "null")
    } else {
      col_units_list[[j]] <- grid::unit(col_widths_cm[j], "cm")
    }
  }
  col_widths_units <- do.call(grid::unit.c, col_units_list)

  # -------------------------------------------------------------------
  # 7. xlim and refline
  # -------------------------------------------------------------------
  xlim_final    <- if (!is.null(xlim)) xlim else
    auto_xlim(measure, yi_bt, ci_lb_bt, ci_ub_bt)
  refline_final <- if (!is.null(refline)) refline else auto_refline(measure)

  # -------------------------------------------------------------------
  # 8. Resolve file path and open device
  # -------------------------------------------------------------------
  suffix   <- paste0("subgroup_", subgroup)
  out_file <- resolve_file(x, file, format, suffix = suffix)
  dims     <- auto_dims(n_total_rows, width, height)

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

  # -------------------------------------------------------------------
  # 9. Build grid layout
  # -------------------------------------------------------------------
  grid::grid.newpage()

  row_height_lines <- 1.2
  row_heights <- grid::unit(rep(row_height_lines, n_total_rows), "lines")

  root_layout <- grid::grid.layout(
    nrow    = n_total_rows,
    ncol    = n_cols,
    widths  = col_widths_units,
    heights = row_heights
  )
  grid::pushViewport(grid::viewport(layout = root_layout))

  push_cell <- function(row, col, xscale = c(0, 1), clip = "off") {
    grid::pushViewport(
      grid::viewport(
        layout.pos.row = row,
        layout.pos.col = col,
        xscale = xscale,
        clip   = clip
      )
    )
  }

  push_span <- function(row, col_from, col_to, xscale = c(0, 1), clip = "off") {
    grid::pushViewport(
      grid::viewport(
        layout.pos.row = row,
        layout.pos.col = col_from:col_to,
        xscale = xscale,
        clip   = clip
      )
    )
  }

  bold_gp <- grid::gpar(fontface = "bold", cex = 0.75)
  norm_gp <- grid::gpar(cex = 0.75)

  # -------------------------------------------------------------------
  # 10. Column header row
  # -------------------------------------------------------------------
  current_row <- 1L

  push_cell(current_row, studlab_col)
  grid::grid.text("Study", x = grid::unit(0, "npc"), just = "left", gp = bold_gp)
  grid::popViewport()

  if (n_ilab > 0L) {
    for (j in seq_len(n_ilab)) {
      push_cell(current_row, ilab_cols[j])
      grid::grid.text(ilab_labels[j], x = grid::unit(0.5, "npc"),
                      just = "centre", gp = bold_gp)
      grid::popViewport()
    }
  }

  if (showweights) {
    push_cell(current_row, weight_col)
    grid::grid.text("Weight", x = grid::unit(0.5, "npc"),
                    just = "centre", gp = bold_gp)
    grid::popViewport()
  }

  push_cell(current_row, results_col)
  grid::grid.text("Estimate [95% CI]", x = grid::unit(0, "npc"),
                  just = "left", gp = bold_gp)
  grid::popViewport()

  current_row <- current_row + 1L

  # -------------------------------------------------------------------
  # 11. Reference line (drawn across all study rows — we'll use a
  #     post-layout approach via segments from top to bottom of data rows)
  # -------------------------------------------------------------------
  # We draw refline later per-row inside each CI cell.

  # -------------------------------------------------------------------
  # 12. Draw per-subgroup sections
  # -------------------------------------------------------------------
  study_row_index <- 0L   # global index for zebra shading

  for (gv in levels_vec) {
    sg  <- subgroup_results[[gv]]
    idx <- sg$idx          # indices into sorted dat

    # ---- Subgroup header row ----
    push_span(current_row, studlab_col, results_col)
    grid::grid.text(as.character(gv),
                    x    = grid::unit(0.02, "npc"),
                    just = "left",
                    gp   = bold_gp)
    grid::popViewport()
    current_row <- current_row + 1L

    # ---- Study rows ----
    for (ii in seq_along(idx)) {
      global_i <- idx[ii]     # position in sorted dat
      study_row_index <- study_row_index + 1L
      row_i <- current_row

      # Zebra shading
      if (study_row_index %% 2L == 0L) {
        push_span(row_i, studlab_col, results_col)
        draw_zebra_rect(colshade)
        grid::popViewport()
      }

      # Reference line in CI column
      if (!is.null(refline_final) && !is.na(refline_final)) {
        if (refline_final >= xlim_final[1] && refline_final <= xlim_final[2]) {
          push_cell(row_i, ci_col, xscale = xlim_final, clip = "off")
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

      # Study label
      push_cell(row_i, studlab_col)
      grid::grid.text(as.character(slab_vals[global_i]),
                      x    = grid::unit(0, "npc"),
                      just = "left",
                      gp   = norm_gp)
      grid::popViewport()

      # ilab columns
      if (n_ilab > 0L) {
        for (j in seq_len(n_ilab)) {
          push_cell(row_i, ilab_cols[j])
          grid::grid.text(as.character(dat[[ilab[j]]][global_i]),
                          x    = grid::unit(0.5, "npc"),
                          just = "centre",
                          gp   = norm_gp)
          grid::popViewport()
        }
      }

      # Weight column
      if (showweights) {
        push_cell(row_i, weight_col)
        grid::grid.text(sprintf("%.1f%%", w_pct[global_i]),
                        x    = grid::unit(0.5, "npc"),
                        just = "centre",
                        gp   = norm_gp)
        grid::popViewport()
      }

      # CI panel
      push_cell(row_i, ci_col, xscale = xlim_final, clip = "on")
      lb_i <- ci_lb_bt[global_i]
      ub_i <- ci_ub_bt[global_i]
      lb_draw <- max(lb_i, xlim_final[1])
      ub_draw <- min(ub_i, xlim_final[2])
      trunc_left  <- lb_i < xlim_final[1]
      trunc_right <- ub_i > xlim_final[2]

      if (trunc_left || trunc_right) {
        arrow_ends <- if (trunc_left && trunc_right) "both" else
          if (trunc_left) "first" else "last"
        grid::grid.segments(
          x0    = grid::unit(lb_draw, "native"),
          x1    = grid::unit(ub_draw, "native"),
          y0    = grid::unit(0.5, "npc"),
          y1    = grid::unit(0.5, "npc"),
          arrow = grid::arrow(ends   = arrow_ends,
                              length = grid::unit(0.05, "inches")),
          gp    = grid::gpar(lwd = 1)
        )
      } else {
        draw_ci_line(lb_i, ub_i)
      }

      if (!is.na(yi_bt[global_i]) &&
          yi_bt[global_i] >= xlim_final[1] &&
          yi_bt[global_i] <= xlim_final[2]) {
        draw_square(yi_bt[global_i], w_norm[global_i] * 0.8)
      }
      grid::popViewport()

      # Results text
      push_cell(row_i, results_col)
      grid::grid.text(
        sprintf("%.2f [%.2f; %.2f]",
                yi_bt[global_i], lb_i, ub_i),
        x    = grid::unit(0, "npc"),
        just = "left",
        gp   = norm_gp
      )
      grid::popViewport()

      current_row <- current_row + 1L
    }  # end study rows for this subgroup

    # ---- Subgroup diamond row (only if 2+ clusters) ----
    if (sg$has_diamond && !is.na(sg$est)) {
      row_d <- current_row

      # Subgroup label
      push_cell(row_d, studlab_col)
      i2_label <- sprintf("k = %d  |  I\u00b2 = %.0f%% (between: %.0f%%, within: %.0f%%)",
                          sg$k,
                          sg$i2$total,
                          sg$i2$between,
                          sg$i2$within)
      if (measure %in% c("SMD", "MD", "RR", "OR") && !is.na(sg$pval)) {
        i2_label <- paste0(i2_label, sprintf("; p = %.3f", sg$pval))
      }
      grid::grid.text(i2_label,
                      x    = grid::unit(0, "npc"),
                      just = "left",
                      gp   = grid::gpar(cex = 0.65, fontface = "italic"))
      grid::popViewport()

      # Diamond in CI panel
      if (!is.na(sg$lb) && !is.na(sg$ub)) {
        push_cell(row_d, ci_col, xscale = xlim_final, clip = "on")
        draw_diamond(
          max(sg$lb, xlim_final[1]),
          min(max(sg$est, xlim_final[1]), xlim_final[2]),
          min(sg$ub, xlim_final[2])
        )
        grid::popViewport()
      }

      # Estimate text
      push_cell(row_d, results_col)
      grid::grid.text(
        sprintf("%.2f [%.2f; %.2f]", sg$est, sg$lb, sg$ub),
        x    = grid::unit(0, "npc"),
        just = "left",
        gp   = grid::gpar(cex = 0.75, fontface = "bold")
      )
      grid::popViewport()

      current_row <- current_row + 1L
    }

    # ---- Blank separator row ----
    current_row <- current_row + 1L
  }  # end subgroup loop

  # -------------------------------------------------------------------
  # 13. Overall diamond row
  # -------------------------------------------------------------------
  if (overall) {
    row_ov <- current_row

    push_cell(row_ov, studlab_col)
    grid::grid.text("Overall",
                    x    = grid::unit(0, "npc"),
                    just = "left",
                    gp   = grid::gpar(cex = 0.75, fontface = "bold"))
    grid::popViewport()

    push_cell(row_ov, ci_col, xscale = xlim_final, clip = "on")
    draw_diamond(x$ci.lb, x$estimate, x$ci.ub)
    grid::popViewport()

    ov_text <- sprintf("%.2f [%.2f; %.2f]", x$estimate, x$ci.lb, x$ci.ub)
    if (measure %in% c("SMD", "MD", "RR", "OR")) {
      ov_text <- paste0(ov_text, sprintf("; p = %.4f", x$model$pval))
    }
    push_cell(row_ov, results_col)
    grid::grid.text(ov_text,
                    x    = grid::unit(0, "npc"),
                    just = "left",
                    gp   = grid::gpar(cex = 0.75, fontface = "bold"))
    grid::popViewport()

    current_row <- current_row + 1L

    # Overall I2 label
    row_mlab <- current_row
    push_span(row_mlab, studlab_col, studlab_col)
    grid::grid.text(format_mlab(x$i2),
                    x    = grid::unit(0, "npc"),
                    just = "left",
                    gp   = grid::gpar(cex = 0.65, fontface = "italic"))
    grid::popViewport()
    current_row <- current_row + 1L
  }

  # -------------------------------------------------------------------
  # 14. Q-test footer
  # -------------------------------------------------------------------
  if (nchar(qtest_text) > 0L) {
    row_qt <- current_row
    push_span(row_qt, studlab_col, results_col)
    grid::grid.text(qtest_text,
                    x    = grid::unit(0.02, "npc"),
                    just = "left",
                    gp   = grid::gpar(cex = 0.65, fontface = "italic"))
    grid::popViewport()
    current_row <- current_row + 1L
  }

  # -------------------------------------------------------------------
  # 15. X-axis row
  # -------------------------------------------------------------------
  at_final <- if (!is.null(at)) at else pretty(xlim_final, n = 5L)
  push_cell(current_row, ci_col, xscale = xlim_final, clip = "off")
  grid::grid.xaxis(at = at_final, gp = grid::gpar(cex = 0.65))
  grid::popViewport()

  if (!is.null(xlab)) {
    current_row <- current_row + 1L
    push_cell(current_row, ci_col)
    grid::grid.text(xlab, x = grid::unit(0.5, "npc"),
                    just = "centre",
                    gp = grid::gpar(cex = 0.7))
    grid::popViewport()
  }

  # -------------------------------------------------------------------
  # 16. Cleanup
  # -------------------------------------------------------------------
  grid::popViewport()  # pop root layout viewport

  invisible(out_file)
}

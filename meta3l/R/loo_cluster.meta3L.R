# loo_cluster.meta3L.R — Cluster-level leave-one-out sensitivity analysis
# Drops each unique cluster (study), refits, and returns influence table + plot.

#' Cluster-level leave-one-out sensitivity analysis (generic)
#'
#' @param x An S3 object to dispatch on.
#' @param ... Additional arguments passed to methods.
#' @return A named list; see \code{\link{loo_cluster.meta3l_result}}.
#' @export
loo_cluster <- function(x, ...) UseMethod("loo_cluster")

#' Cluster-level leave-one-out sensitivity analysis for meta3l_result objects
#'
#' Drops each unique cluster (study) in turn, refits the three-level model on
#' the remaining data, and returns a table showing how the pooled estimate and
#' heterogeneity statistics change.  Also produces a grid-based influence plot.
#'
#' @param x     A \code{meta3l_result} object returned by \code{\link{meta3L}}.
#' @param file  One of: \code{character(0)} (default, auto-name from
#'   \code{x$name} and \code{meta3l.mwd} option); \code{NULL} (display only,
#'   returns \code{NULL} for \code{plot_file}); or a character string (explicit
#'   file path).
#' @param format Character string; output format — \code{"png"} (default) or
#'   \code{"pdf"}.
#' @param width  Integer or NULL; output width in pixels.  \code{NULL}
#'   auto-computes via \code{auto_dims()}.
#' @param height Integer or NULL; output height in pixels.  \code{NULL}
#'   auto-computes.
#' @param ... Currently ignored.
#'
#' @return Invisibly returns a named list with:
#'   \describe{
#'     \item{table}{A data frame with columns \code{omitted}, \code{estimate},
#'       \code{ci.lb}, \code{ci.ub}, \code{i2_between}, \code{i2_within},
#'       \code{pval}.  The last row is the "All studies" baseline.}
#'     \item{plot_file}{File path of the saved plot (character string) or
#'       \code{NULL} if \code{file = NULL}.}
#'   }
#'
#' @importFrom metafor rma.mv robust
#' @importFrom grDevices png pdf dev.off
#' @importFrom stats as.formula
#' @method loo_cluster meta3l_result
#' @export
loo_cluster.meta3l_result <- function(x,
                                file   = character(0),
                                format = "png",
                                width  = NULL,
                                height = NULL,
                                ...) {

  stopifnot(inherits(x, "meta3l_result"))

  # -------------------------------------------------------------------
  # 1. Identify clusters and build random formula
  # -------------------------------------------------------------------
  clusters       <- unique(x$data[[x$cluster]])
  random_formula <- stats::as.formula(paste0("~ 1 | ", x$cluster, " / TE_id"))

  # -------------------------------------------------------------------
  # 2. Sequential LOO loop (Windows-safe: lapply, not mclapply)
  # -------------------------------------------------------------------
  results_list <- lapply(clusters, function(cl) {
    keep    <- x$data[[x$cluster]] != cl
    dat_loo <- x$data[keep, , drop = FALSE]
    V_loo   <- x$V[keep, keep, drop = FALSE]

    # Guard: need >= 2 clusters remaining
    n_clust <- length(unique(dat_loo[[x$cluster]]))
    if (n_clust < 2L) {
      warning("Dropping '", cl, "' leaves < 2 clusters; skipping.", call. = FALSE)
      return(list(omitted = as.character(cl), estimate = NA_real_,
                  ci.lb = NA_real_, ci.ub = NA_real_,
                  i2_between = NA_real_, i2_within = NA_real_,
                  pval = NA_real_))
    }

    tryCatch({
      fit_loo <- metafor::rma.mv(yi, V_loo,
                                 random = random_formula,
                                 data   = dat_loo)
      fit_rob <- metafor::robust(fit_loo,
                                 cluster      = dat_loo[[x$cluster]],
                                 clubSandwich = TRUE)
      i2_loo  <- compute_i2(fit_loo, V_loo)

      list(omitted    = as.character(cl),
           estimate   = x$transf(fit_rob$b[[1L]]),
           ci.lb      = x$transf(fit_rob$ci.lb),
           ci.ub      = x$transf(fit_rob$ci.ub),
           i2_between = i2_loo$between,
           i2_within  = i2_loo$within,
           pval       = fit_rob$pval)
    }, error = function(e) {
      warning("LOO iteration for '", cl, "' failed: ", e$message, call. = FALSE)
      list(omitted = as.character(cl), estimate = NA_real_,
           ci.lb = NA_real_, ci.ub = NA_real_,
           i2_between = NA_real_, i2_within = NA_real_,
           pval = NA_real_)
    })
  })

  # -------------------------------------------------------------------
  # 3. Build LOO table
  # -------------------------------------------------------------------
  tbl <- do.call(rbind, lapply(results_list, function(r) {
    as.data.frame(r, stringsAsFactors = FALSE)
  }))

  # -------------------------------------------------------------------
  # 4. Add "All studies" baseline row (full model estimates)
  # -------------------------------------------------------------------
  # x$model is the robust object; compute I2 from a fresh rma.mv on full data
  # (compute_i2 needs the raw rma.mv object's sigma2, not the robust wrapper)
  full_fit_i2 <- tryCatch({
    compute_i2(metafor::rma.mv(yi, x$V,
                               random = random_formula,
                               data   = x$data),
               x$V)
  }, error = function(e) {
    list(between = NA_real_, within = NA_real_, total = NA_real_)
  })

  baseline <- data.frame(
    omitted    = "All studies",
    estimate   = x$estimate,
    ci.lb      = x$ci.lb,
    ci.ub      = x$ci.ub,
    i2_between = full_fit_i2$between,
    i2_within  = full_fit_i2$within,
    pval       = x$model$pval,
    stringsAsFactors = FALSE
  )
  tbl <- rbind(tbl, baseline)
  rownames(tbl) <- NULL

  # -------------------------------------------------------------------
  # 5. Resolve file and open device
  # -------------------------------------------------------------------
  out_path <- resolve_file(x, file, format, suffix = "loo_cluster")
  n_rows   <- nrow(tbl)
  dims     <- auto_dims(n_rows, width, height)

  if (!is.null(out_path)) {
    if (identical(format, "pdf")) {
      grDevices::pdf(out_path,
                     width  = dims$width  / 300,
                     height = dims$height / 300)
    } else {
      grDevices::png(out_path,
                     width  = dims$width,
                     height = dims$height,
                     res    = 300L)
    }
    on.exit(grDevices::dev.off(), add = TRUE)
    .draw_loo_plot(tbl, x$measure, x$cluster)
  }

  invisible(list(table = tbl, plot_file = out_path))
}

# ---------------------------------------------------------------------------
# Internal: draw the LOO influence plot using grid graphics
# Shared by both loo_cluster and loo_effect
# ---------------------------------------------------------------------------

#' Draw a LOO influence plot (internal)
#'
#' @param tbl     Data frame with columns omitted, estimate, ci.lb, ci.ub,
#'   i2_between, i2_within, pval.  Last row is "All studies".
#' @param measure Character string; effect size measure for refline/xlim.
#' @param context Character string; label for annotation (e.g. cluster column).
#' @keywords internal
.draw_loo_plot <- function(tbl, measure, context) {
  n_rows     <- nrow(tbl)
  study_rows <- seq_len(n_rows - 1L)   # all but "All studies"
  baseline_r <- n_rows                 # "All studies" row index

  # Compute xlim from finite values
  yi_vals <- tbl$estimate
  lb_vals <- tbl$ci.lb
  ub_vals <- tbl$ci.ub
  xlim    <- auto_xlim(measure, yi_vals, lb_vals, ub_vals)
  refline <- auto_refline(measure)

  # Row structure:
  #   row 1              : header
  #   rows 2 .. n_rows   : LOO rows
  #   row n_rows + 1     : blank separator
  #   row n_rows + 2     : axis
  header_row  <- 1L
  data_rows   <- seq(2L, n_rows + 1L)
  axis_row    <- n_rows + 2L
  total_rows  <- axis_row

  # Column structure:
  #   col 1 : label (omitted study)
  #   col 2 : gap
  #   col 3 : CI panel
  #   col 4 : gap
  #   col 5 : I2 between text
  #   col 6 : I2 within text
  #   col 7 : p-value text

  label_col  <- 1L
  gap1_col   <- 2L
  ci_col     <- 3L
  gap2_col   <- 4L
  i2b_col    <- 5L
  i2w_col    <- 6L
  pval_col   <- 7L
  n_cols     <- 7L

  col_units_list <- vector("list", n_cols)
  col_units_list[[label_col]] <- grid::unit(3.5, "cm")
  col_units_list[[gap1_col]]  <- grid::unit(0.2, "cm")
  col_units_list[[ci_col]]    <- grid::unit(1,   "null")
  col_units_list[[gap2_col]]  <- grid::unit(0.2, "cm")
  col_units_list[[i2b_col]]   <- grid::unit(1.5, "cm")
  col_units_list[[i2w_col]]   <- grid::unit(1.5, "cm")
  col_units_list[[pval_col]]  <- grid::unit(1.5, "cm")
  col_widths_units <- do.call(grid::unit.c, col_units_list)

  row_height_lines <- 1.2
  row_heights      <- grid::unit(rep(row_height_lines, total_rows), "lines")

  root_layout <- grid::grid.layout(
    nrow    = total_rows,
    ncol    = n_cols,
    widths  = col_widths_units,
    heights = row_heights
  )

  grid::grid.newpage()
  grid::pushViewport(grid::viewport(layout = root_layout))

  push_cell <- function(row, col, xscale = c(0, 1), clip = "off") {
    grid::pushViewport(
      grid::viewport(
        layout.pos.row = row,
        layout.pos.col = col,
        xscale         = xscale,
        clip           = clip
      )
    )
  }

  push_span <- function(row, col_from, col_to, xscale = c(0, 1), clip = "off") {
    grid::pushViewport(
      grid::viewport(
        layout.pos.row = row,
        layout.pos.col = col_from:col_to,
        xscale         = xscale,
        clip           = clip
      )
    )
  }

  bold_gp <- grid::gpar(fontface = "bold", cex = 0.75)
  norm_gp <- grid::gpar(cex = 0.75)

  # -------------------------------------------------------------------
  # Header row
  # -------------------------------------------------------------------
  push_cell(header_row, label_col)
  grid::grid.text("Omitted", x = grid::unit(0, "npc"), just = "left", gp = bold_gp)
  grid::popViewport()

  push_cell(header_row, i2b_col)
  grid::grid.text("I\u00b2_B%", x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
  grid::popViewport()

  push_cell(header_row, i2w_col)
  grid::grid.text("I\u00b2_W%", x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
  grid::popViewport()

  push_cell(header_row, pval_col)
  grid::grid.text("p", x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
  grid::popViewport()

  # -------------------------------------------------------------------
  # Reference line (behind data rows)
  # -------------------------------------------------------------------
  if (!is.null(refline) && !is.na(refline) &&
      refline >= xlim[1] && refline <= xlim[2]) {
    push_span(data_rows[1]:data_rows[length(data_rows)],
              ci_col, ci_col,
              xscale = xlim)
    grid::grid.segments(
      x0 = grid::unit(refline, "native"),
      x1 = grid::unit(refline, "native"),
      y0 = grid::unit(0, "npc"),
      y1 = grid::unit(1, "npc"),
      gp = grid::gpar(lty = "dashed", col = "gray50", lwd = 0.8)
    )
    grid::popViewport()
  }

  # -------------------------------------------------------------------
  # Data rows
  # -------------------------------------------------------------------
  for (i in seq_len(n_rows)) {
    row_i <- data_rows[i]
    row_d <- tbl[i, ]

    # Zebra shading on even rows
    if (i %% 2L == 0L) {
      push_span(row_i, label_col, pval_col)
      draw_zebra_rect()
      grid::popViewport()
    }

    # Label
    push_cell(row_i, label_col)
    grid::grid.text(as.character(row_d$omitted),
                    x    = grid::unit(0, "npc"),
                    just = "left",
                    gp   = if (i == n_rows) grid::gpar(cex = 0.75, fontface = "bold") else norm_gp)
    grid::popViewport()

    # CI panel
    push_cell(row_i, ci_col, xscale = xlim, clip = "on")

    if (i == n_rows) {
      # "All studies" baseline: draw diamond
      if (!is.na(row_d$estimate) &&
          is.finite(row_d$ci.lb) && is.finite(row_d$ci.ub)) {
        draw_diamond(row_d$ci.lb, row_d$estimate, row_d$ci.ub)
      }
    } else {
      # LOO row: draw CI line + square
      if (!is.na(row_d$estimate)) {
        lb_draw <- max(row_d$ci.lb, xlim[1])
        ub_draw <- min(row_d$ci.ub, xlim[2])
        draw_ci_line(lb_draw, ub_draw)
        if (row_d$estimate >= xlim[1] && row_d$estimate <= xlim[2]) {
          draw_square(row_d$estimate, size = 0.8)
        }
      }
    }
    grid::popViewport()

    # I2 between
    push_cell(row_i, i2b_col)
    grid::grid.text(
      if (is.na(row_d$i2_between)) "NA" else sprintf("%.1f", row_d$i2_between),
      x    = grid::unit(0.5, "npc"),
      just = "centre",
      gp   = norm_gp
    )
    grid::popViewport()

    # I2 within
    push_cell(row_i, i2w_col)
    grid::grid.text(
      if (is.na(row_d$i2_within)) "NA" else sprintf("%.1f", row_d$i2_within),
      x    = grid::unit(0.5, "npc"),
      just = "centre",
      gp   = norm_gp
    )
    grid::popViewport()

    # p-value
    push_cell(row_i, pval_col)
    pval_str <- if (is.na(row_d$pval)) {
      "NA"
    } else if (row_d$pval < 0.001) {
      "<.001"
    } else {
      sprintf("%.3f", row_d$pval)
    }
    grid::grid.text(pval_str,
                    x    = grid::unit(0.5, "npc"),
                    just = "centre",
                    gp   = norm_gp)
    grid::popViewport()
  }

  # -------------------------------------------------------------------
  # Axis row
  # -------------------------------------------------------------------
  at_vals <- pretty(xlim, n = 5L)
  push_cell(axis_row, ci_col, xscale = xlim, clip = "off")
  grid::grid.xaxis(at = at_vals, gp = grid::gpar(cex = 0.65))
  grid::popViewport()

  # Pop root layout
  grid::popViewport()

  invisible(NULL)
}

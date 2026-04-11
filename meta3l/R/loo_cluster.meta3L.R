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
                                title  = x$name,
                                shade  = "zebra",
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
      if (x$measure == "GLMM") {
        fit_loo <- metafor::rma.glmm(
          xi = dat_loo$xi, ni = dat_loo$ni,
          measure = "PLO", slab = dat_loo[[x$slab]], data = dat_loo)
        i2_loo  <- compute_i2_glmm(fit_loo, dat_loo$vi)
        fit_rob <- fit_loo
      } else {
        fit_loo <- metafor::rma.mv(yi, V_loo,
                                   random = random_formula,
                                   data   = dat_loo)
        fit_rob <- metafor::robust(fit_loo,
                                   cluster      = dat_loo[[x$cluster]],
                                   clubSandwich = TRUE)
        i2_loo  <- compute_i2(fit_loo)
      }

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
    if (x$measure == "GLMM") {
      compute_i2_glmm(metafor::rma.glmm(
        xi = x$data$xi, ni = x$data$ni,
        measure = "PLO", slab = x$data[[x$slab]], data = x$data), x$data$vi)
    } else {
      compute_i2(metafor::rma.mv(yi, x$V,
                                 random = random_formula,
                                 data   = x$data))
    }
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
  # header + data rows + axis + favours + title = n_rows + 4
  dims     <- auto_dims(n_rows + 4L, width, height, has_wrapped = FALSE)

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
    # Use original data range for axis scale (not LOO extremes)
    orig_yi    <- x$transf(x$data$yi)
    orig_lb    <- x$transf(x$data$yi - stats::qnorm(0.975) * sqrt(x$data$vi))
    orig_ub    <- x$transf(x$data$yi + stats::qnorm(0.975) * sqrt(x$data$vi))
    xlim_ref   <- auto_xlim(x$measure, orig_yi, orig_lb, orig_ub)
    loo_title <- if (!is.null(title) && nzchar(title)) {
      paste0(title, "\nLeave-One-Out by Cluster")
    } else {
      "Leave-One-Out by Cluster"
    }
    .draw_loo_plot(tbl, x$measure, x$cluster,
                   rho = x$rho, group.e = x$group.e, group.c = x$group.c,
                   shade = shade, xlim_ref = xlim_ref, title = loo_title,
                   orig_data = x$data, orig_cluster = x$cluster)
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
.draw_loo_plot <- function(tbl, measure, context,
                          rho = 0.5, group.e = NULL, group.c = NULL,
                          ilab = NULL, ilab.lab = NULL,
                          shade = "zebra", xlim_ref = NULL,
                          title = NULL, orig_data = NULL,
                          orig_cluster = NULL) {
  n_rows     <- nrow(tbl)
  baseline_r <- n_rows

  yi_vals <- tbl$estimate
  lb_vals <- tbl$ci.lb
  ub_vals <- tbl$ci.ub
  xlim    <- if (!is.null(xlim_ref)) xlim_ref else
    auto_xlim(measure, yi_vals, lb_vals, ub_vals)
  refline <- auto_refline(measure)

  n_ilab      <- if (!is.null(ilab)) length(ilab) else 0L
  ilab_labels <- if (!is.null(ilab.lab)) ilab.lab else ilab

  # Detect intervention / control column groups for pairwise measures
  has_groups <- FALSE
  if (measure %in% c("SMD", "MD", "RR", "OR") && n_ilab > 0L) {
    e_idx <- which(grepl("\\.e$", ilab))
    c_idx <- which(grepl("\\.c$", ilab))
    has_groups <- length(e_idx) > 0L && length(c_idx) > 0L
  }
  group_offset <- if (has_groups) 1L else 0L

  # Pre-compute wrapped ilab values and per-column widths
  ilab_wrapped    <- list()
  ilab_col_widths <- numeric(n_ilab)
  has_wrapped     <- FALSE
  if (n_ilab > 0L) {
    for (j in seq_len(n_ilab)) {
      if (ilab[j] %in% names(tbl)) {
        vals <- as.character(tbl[[ilab[j]]])
      } else {
        vals <- rep("", n_rows)
      }
      ilab_wrapped[[j]] <- wrap_label(vals)
      if (any(grepl("\n", ilab_wrapped[[j]]))) has_wrapped <- TRUE
      lines <- unlist(strsplit(ilab_wrapped[[j]], "\n"))
      max_data_chars <- max(nchar(lines), na.rm = TRUE)
      hdr_chars <- nchar(ilab_labels[j])
      ilab_col_widths[j] <- ilab_col_cm(max(max_data_chars, hdr_chars))
    }
  }

  # Row structure (group_offset is 1 when intervention/control headers present)
  has_favours <- measure %in% c("SMD", "MD", "RR", "OR")
  group_row   <- if (has_groups) 1L else NA_integer_
  header_row  <- 1L + group_offset
  data_rows   <- seq(2L + group_offset, n_rows + 1L + group_offset)
  axis_row    <- n_rows + 2L + group_offset
  favours_row <- if (has_favours) axis_row + 1L else NA_integer_
  title_row   <- axis_row + if (has_favours) 2L else 1L
  total_rows  <- title_row

  # Column structure (dynamic for ilab)
  label_col  <- 1L
  ilab_cols  <- if (n_ilab > 0L) seq(2L, n_ilab + 1L) else integer(0)
  gap1_col   <- n_ilab + 2L
  ci_col     <- n_ilab + 3L
  gap2_col   <- n_ilab + 4L
  i2b_col    <- n_ilab + 5L
  i2w_col    <- n_ilab + 6L
  pval_col   <- n_ilab + 7L
  n_cols     <- pval_col

  label_chars <- max(nchar(as.character(tbl$omitted)), nchar("Omitted"), na.rm = TRUE)
  label_w     <- max(2.5, ilab_col_cm(label_chars))
  gap_w       <- 0.35

  # Cap CI panel at 40% of total width: ci / (ci + other) <= 0.4
  # Floor of 5 cm prevents cramping when few columns are present
  other_cm <- label_w + sum(ilab_col_widths) + 2 * gap_w + 2.2 + 2.2 + 1.5
  ci_cm    <- max(min(7, other_cm * 2 / 3), 5)

  col_units_list <- vector("list", n_cols)
  col_units_list[[label_col]] <- grid::unit(label_w, "cm")
  if (n_ilab > 0L) {
    for (j in seq_len(n_ilab)) col_units_list[[ilab_cols[j]]] <- grid::unit(ilab_col_widths[j], "cm")
  }
  col_units_list[[gap1_col]]  <- grid::unit(gap_w, "cm")
  col_units_list[[ci_col]]    <- grid::unit(ci_cm, "cm")
  col_units_list[[gap2_col]]  <- grid::unit(gap_w, "cm")
  col_units_list[[i2b_col]]   <- grid::unit(2.2, "cm")
  col_units_list[[i2w_col]]   <- grid::unit(2.2, "cm")
  col_units_list[[pval_col]]  <- grid::unit(1.5, "cm")
  col_widths_units <- do.call(grid::unit.c, col_units_list)

  row_height_lines <- if (has_wrapped) 1.8 else 1.2
  rh <- rep(row_height_lines, total_rows)
  rh[header_row]  <- 1.5
  rh[axis_row]    <- 2.0
  rh[title_row]   <- if (!is.null(title) && grepl("\n", title)) 3.0 else 1.5
  row_heights <- grid::unit(rh, "lines")

  root_layout <- grid::grid.layout(
    nrow = total_rows, ncol = n_cols,
    widths = col_widths_units, heights = row_heights
  )

  grid::grid.newpage()
  grid::pushViewport(grid::viewport(
    layout = root_layout,
    x = grid::unit(0.4, "cm"), y = grid::unit(0, "npc"),
    width = grid::unit(1, "npc") - grid::unit(0.4, "cm"),
    height = grid::unit(1, "npc") - grid::unit(0.4, "cm"),
    just = c("left", "bottom")
  ))

  push_cell <- function(row, col, xscale = c(0, 1), clip = "off") {
    grid::pushViewport(grid::viewport(
      layout.pos.row = row, layout.pos.col = col,
      xscale = xscale, clip = clip
    ))
  }
  push_span <- function(row, col_from, col_to, xscale = c(0, 1), clip = "off") {
    grid::pushViewport(grid::viewport(
      layout.pos.row = row, layout.pos.col = col_from:col_to,
      xscale = xscale, clip = clip
    ))
  }

  bold_gp <- grid::gpar(fontface = "bold", cex = 0.75)
  norm_gp <- grid::gpar(cex = 0.75)
  sm_gp   <- grid::gpar(cex = 0.6)

  # --- Group header (intervention / control) ---
  if (has_groups) {
    e_ilab_cols <- ilab_cols[e_idx]
    c_ilab_cols <- ilab_cols[c_idx]
    push_span(group_row, min(e_ilab_cols), max(e_ilab_cols))
    grid::grid.text(if (!is.null(group.e)) group.e else "Intervention",
                    x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
    grid::popViewport()
    push_span(group_row, min(c_ilab_cols), max(c_ilab_cols))
    grid::grid.text(if (!is.null(group.c)) group.c else "Control",
                    x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
    grid::popViewport()
  }

  # --- Header ---
  push_cell(header_row, label_col)
  grid::grid.text("Omitted", x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
  grid::popViewport()

  if (n_ilab > 0L) {
    for (j in seq_len(n_ilab)) {
      push_cell(header_row, ilab_cols[j])
      grid::grid.text(ilab_labels[j], x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
      grid::popViewport()
    }
  }

  push_cell(header_row, i2b_col)
  grid::grid.text("I\u00b2 Between", x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
  grid::popViewport()
  push_cell(header_row, i2w_col)
  grid::grid.text("I\u00b2 Within", x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
  grid::popViewport()
  push_cell(header_row, pval_col)
  grid::grid.text("p", x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
  grid::popViewport()

  # Method summary (in CI column of header row)
  method_gp <- grid::gpar(fontface = "bold", cex = 0.65)
  push_cell(header_row, ci_col)
  grid::grid.text(sprintf("Inverse Variance, %s", measure),
                  x = grid::unit(0.5, "npc"), y = grid::unit(0.65, "npc"),
                  just = "centre", gp = method_gp)
  grid::grid.text(sprintf("Three-Level, \u03c1 = %.1f", rho),
                  x = grid::unit(0.5, "npc"), y = grid::unit(0.3, "npc"),
                  just = "centre", gp = method_gp)
  grid::popViewport()

  # --- Shade mask ---
  if (identical(shade, "cluster")) {
    labels  <- tbl$omitted[-n_rows]
    grp_ids <- as.integer(factor(labels, levels = unique(labels)))
    shade_mask <- c(grp_ids %% 2L == 1L, FALSE)
  } else {
    shade_mask <- c(seq_len(n_rows - 1L) %% 2L == 0L, FALSE)
  }

  # --- Data rows ---
  for (i in seq_len(n_rows)) {
    row_i <- data_rows[i]
    row_d <- tbl[i, ]

    if (shade_mask[i]) {
      push_span(row_i, label_col, pval_col)
      draw_zebra_rect()
      grid::popViewport()
    }

    # Label
    push_cell(row_i, label_col)
    grid::grid.text(as.character(row_d$omitted),
                    x = grid::unit(0.5, "npc"), just = "centre",
                    gp = if (i == n_rows) grid::gpar(cex = 0.75, fontface = "bold") else norm_gp)
    grid::popViewport()

    # ilab columns
    if (n_ilab > 0L) {
      if (i == n_rows && !is.null(orig_data) &&
          !is.null(orig_cluster)) {
        # Baseline row: show aggregated ilab
        cl_vals <- orig_data[[orig_cluster]]
        for (j in seq_len(n_ilab)) {
          col_vals <- orig_data[[ilab[j]]]
          agg <- aggregate_ilab_col(
            col_vals, ilab[j], cl_vals,
            data = orig_data
          )
          if (nzchar(agg)) {
            push_cell(row_i, ilab_cols[j])
            grid::grid.text(
              agg,
              x = grid::unit(0.5, "npc"),
              just = "centre",
              gp = bold_gp
            )
            grid::popViewport()
          }
        }
      } else {
        for (j in seq_len(n_ilab)) {
          push_cell(row_i, ilab_cols[j])
          grid::grid.text(ilab_wrapped[[j]][i],
                          x = grid::unit(0.5, "npc"),
                          y = grid::unit(0.5, "npc"),
                          just = "centre", gp = sm_gp)
          grid::popViewport()
        }
      }
    }

    # CI panel
    push_cell(row_i, ci_col, xscale = xlim, clip = "on")
    if (i == n_rows) {
      if (!is.na(row_d$estimate) && is.finite(row_d$ci.lb) && is.finite(row_d$ci.ub))
        draw_diamond(row_d$ci.lb, row_d$estimate, row_d$ci.ub)
    } else {
      if (!is.na(row_d$estimate)) {
        draw_ci_line(max(row_d$ci.lb, xlim[1]), min(row_d$ci.ub, xlim[2]))
        if (row_d$estimate >= xlim[1] && row_d$estimate <= xlim[2])
          draw_square(row_d$estimate, size = 0.8)
      }
    }
    grid::popViewport()

    # Stats columns
    stats_gp <- if (i == n_rows) bold_gp else norm_gp
    push_cell(row_i, i2b_col)
    grid::grid.text(if (is.na(row_d$i2_between)) "NA" else sprintf("%.1f", row_d$i2_between),
                    x = grid::unit(0.5, "npc"), just = "centre", gp = stats_gp)
    grid::popViewport()
    push_cell(row_i, i2w_col)
    grid::grid.text(if (is.na(row_d$i2_within)) "NA" else sprintf("%.1f", row_d$i2_within),
                    x = grid::unit(0.5, "npc"), just = "centre", gp = stats_gp)
    grid::popViewport()
    push_cell(row_i, pval_col)
    pval_str <- if (is.na(row_d$pval)) "NA" else if (row_d$pval < 0.001) "<.001" else sprintf("%.3f", row_d$pval)
    grid::grid.text(pval_str, x = grid::unit(0.5, "npc"), just = "centre", gp = stats_gp)
    grid::popViewport()
  }

  # --- Reference line (on top, solid black) ---
  if (!is.null(refline) && !is.na(refline) &&
      refline >= xlim[1] && refline <= xlim[2]) {
    push_span(data_rows[1]:axis_row, ci_col, ci_col, xscale = xlim)
    grid::grid.segments(
      x0 = grid::unit(refline, "native"), x1 = grid::unit(refline, "native"),
      y0 = grid::unit(0, "npc"), y1 = grid::unit(1, "npc"),
      gp = grid::gpar(lty = "solid", col = "black", lwd = 0.8)
    )
    grid::popViewport()
  }

  # --- Axis (drawn at top of row to hug diamond) ---
  at_vals <- pretty(xlim, n = 5L)
  push_cell(axis_row, ci_col, xscale = xlim, clip = "off")
  grid::grid.segments(
    x0 = grid::unit(xlim[1], "native"),
    x1 = grid::unit(xlim[2], "native"),
    y0 = grid::unit(1, "npc"),
    y1 = grid::unit(1, "npc"),
    gp = grid::gpar(lwd = 1)
  )
  for (.tick in at_vals) {
    if (.tick >= xlim[1] && .tick <= xlim[2]) {
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

  # --- Favours labels ---
  if (measure %in% c("SMD", "MD", "RR", "OR")) {
    fav_gp <- grid::gpar(fontface = "bold", cex = 0.75)
    push_cell(favours_row, ci_col, xscale = xlim, clip = "off")
    grid::grid.text(paste0("Favours ", if (!is.null(group.c)) group.c else "Control"),
                    x = grid::unit(0.25, "npc"), y = grid::unit(0.5, "npc"),
                    just = "centre", gp = fav_gp)
    grid::grid.text(paste0("Favours ", if (!is.null(group.e)) group.e else "Treatment"),
                    x = grid::unit(0.75, "npc"), y = grid::unit(0.5, "npc"),
                    just = "centre", gp = fav_gp)
    grid::popViewport()
  }

  # --- Title below favours ---
  if (!is.null(title) && nzchar(title)) {
    push_cell(title_row, ci_col)
    grid::grid.text(title,
                    x    = grid::unit(0.5, "npc"),
                    y    = grid::unit(0.5, "npc"),
                    just = "centre",
                    gp   = grid::gpar(fontface = "bold", cex = 0.85))
    grid::popViewport()
  }

  grid::popViewport()
  invisible(NULL)
}

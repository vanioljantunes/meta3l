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
                                   qtest       = overall,
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

  # Single subgroup level: fall back to regular forest plot
  if (length(levels_vec) == 1L) {
    fpath <- resolve_file(x, file, format,
                          suffix = paste0("subgroup_", subgroup))
    return(forest.meta3L(x,
                         ilab        = ilab,
                         ilab.lab    = ilab.lab,
                         sortvar     = sortvar,
                         refline     = refline,
                         xlim        = xlim,
                         at          = at,
                         xlab        = xlab,
                         title       = title,
                         showweights = showweights,
                         shade       = shade,
                         colshade    = colshade,
                         squaresize  = squaresize,
                         file        = fpath,
                         format      = format,
                         width       = width,
                         height      = height))
  }

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

  # Pre-compute shade mask
  if (identical(shade, "cluster")) {
    clust_vals <- dat[[cluster]]
    clust_ids  <- as.integer(factor(clust_vals, levels = unique(clust_vals)))
    shade_mask <- clust_ids %% 2L == 1L
  } else {
    shade_mask <- seq_len(nrow(dat)) %% 2L == 0L
  }

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
      if (x$measure == "GLMM") {
        fit_g_raw <- tryCatch(
          metafor::rma.glmm(xi = dat_g$xi, ni = dat_g$ni,
                            measure = "PLO", slab = dat_g[[x$slab]],
                            data = dat_g),
          error = function(e) NULL
        )
        if (!is.null(fit_g_raw)) {
          rob_g <- fit_g_raw
          fit_g <- fit_g_raw
          i2_g  <- tryCatch(
            compute_i2_glmm(fit_g, dat_g$vi),
            error = function(e) list(total = 0, between = 0, within = 0)
          )
        }
      } else {
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
            compute_i2(fit_g),
            error = function(e) list(total = 0, between = 0, within = 0)
          )
        }
      }
    }

    if (is.null(fit_g) || n_clust < 2L) {
      if (n_clust < 2L) {
        warning("Subgroup '", gv, "' has fewer than 2 clusters; ",
                "fitting two-level model.",
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
      has_diamond = (!is.null(rob_g) && k_g >= 2L)
    )
  }

  # -------------------------------------------------------------------
  # 4. Omnibus Q-test (only when qtest = TRUE)
  # -------------------------------------------------------------------
  qtest_text <- ""
  if (qtest) {
    tryCatch({
      mod_formula <- stats::as.formula(
        paste0("~ 1 | ", cluster, " / TE_id")
      )
      mods_formula <- stats::as.formula(
        paste0("~ factor(", subgroup, ")")
      )
      if (x$measure == "GLMM") {
        # rma.glmm does not support mods; skip Q-test for GLMM
        res_mod <- NULL
      } else {
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
      }
      if (!is.null(res_mod)) {
        qtest_text <- sprintf("Test for subgroup differences: p-value = %.3f", res_mod$QMp)
      }
    }, error = function(e) {
      qtest_text <<- ""
    })
  }

  # -------------------------------------------------------------------
  # 5. Compute row layout
  # -------------------------------------------------------------------
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

  n_total_rows <- 1L + group_offset   # [group header] + column header
  diamond_rows <- integer(0)          # track diamond row indices for sizing

  # Per-subgroup rows
  for (gi in seq_along(levels_vec)) {
    gv <- levels_vec[gi]
    sg <- subgroup_results[[gv]]
    n_total_rows <- n_total_rows + 1L          # bold header
    n_total_rows <- n_total_rows + sg$k        # study rows
    if (sg$has_diamond) {
      n_total_rows <- n_total_rows + 1L        # subgroup diamond
      diamond_rows <- c(diamond_rows, n_total_rows)
    }
    if (gi < length(levels_vec)) {
      n_total_rows <- n_total_rows + 1L        # blank separator (not after last)
    }
  }

  if (overall) {
    n_total_rows <- n_total_rows + 1L          # blank separator before overall
    n_total_rows <- n_total_rows + 1L          # overall diamond (+ I2 on same row)
    diamond_rows <- c(diamond_rows, n_total_rows)
  }
  n_total_rows <- n_total_rows + 1L            # x-axis (Q-test shares this row)
  if (measure %in% c("SMD", "MD", "RR", "OR")) {
    n_total_rows <- n_total_rows + 1L          # favours labels
  }
  if (!is.null(title) && nzchar(title)) {
    n_total_rows <- n_total_rows + 1L          # title row
  }
  if (!is.null(xlab)) {
    n_total_rows <- n_total_rows + 1L          # x-axis label
  }

  # -------------------------------------------------------------------
  # 6. Column layout (mirrors forest.meta3L)
  # -------------------------------------------------------------------
  # Pre-compute wrapped ilab values, wrapped headers, and per-column widths
  ilab_wrapped     <- list()
  ilab_hdr_wrapped <- character(n_ilab)
  ilab_col_widths  <- numeric(n_ilab)
  has_wrapped      <- FALSE
  has_wrapped_hdr  <- FALSE
  if (n_ilab > 0L) {
    for (j in seq_len(n_ilab)) {
      vals <- as.character(dat[[ilab[j]]])
      ilab_wrapped[[j]] <- wrap_label(vals)
      if (any(grepl("\n", ilab_wrapped[[j]]))) has_wrapped <- TRUE
      ilab_hdr_wrapped[j] <- wrap_label(ilab_labels[j])
      if (grepl("\n", ilab_hdr_wrapped[j])) has_wrapped_hdr <- TRUE
      data_lines <- unlist(strsplit(ilab_wrapped[[j]], "\n"))
      max_data_chars <- max(nchar(data_lines), na.rm = TRUE)
      hdr_lines <- unlist(strsplit(ilab_hdr_wrapped[j], "\n"))
      hdr_chars <- max(nchar(hdr_lines), na.rm = TRUE)
      ilab_col_widths[j] <- ilab_col_cm(max(max_data_chars, hdr_chars))
    }
  }

  show_pval   <- !is_single_arm(measure)
  studlab_col <- 1L
  ilab_cols   <- if (n_ilab > 0L) seq(2L, n_ilab + 1L) else integer(0)
  weight_col  <- if (showweights) n_ilab + 2L else NA_integer_
  gap1_col    <- if (showweights) n_ilab + 3L else n_ilab + 2L
  ci_col      <- if (showweights) n_ilab + 4L else n_ilab + 3L
  gap2_col    <- if (showweights) n_ilab + 5L else n_ilab + 4L
  results_col <- if (showweights) n_ilab + 6L else n_ilab + 5L
  pval_col    <- if (show_pval) results_col + 1L else NA_integer_
  last_col    <- if (show_pval) pval_col else results_col
  n_cols      <- last_col

  studlab_chars <- max(nchar(as.character(slab_vals)), nchar("Study"), na.rm = TRUE)
  studlab_w  <- max(2.5, ilab_col_cm(studlab_chars))
  weight_w   <- 1.2
  gap_w      <- 0.5
  pval_w     <- if (show_pval) 1.8 else 0
  results_chars <- max(nchar(sprintf("%.2f [%.2f; %.2f]", yi_bt, ci_lb_bt, ci_ub_bt)),
                       nchar("Estimate [95% CI]"), na.rm = TRUE)
  results_w  <- ilab_col_cm(results_chars)

  col_widths_cm <- numeric(n_cols)
  col_widths_cm[studlab_col] <- studlab_w
  if (n_ilab > 0L) {
    for (j in seq_len(n_ilab)) {
      col_widths_cm[ilab_cols[j]] <- ilab_col_widths[j]
    }
  }
  if (showweights) col_widths_cm[weight_col] <- weight_w
  col_widths_cm[gap1_col]    <- gap_w
  col_widths_cm[gap2_col]    <- gap_w
  col_widths_cm[results_col] <- results_w
  if (show_pval) {
    col_widths_cm[pval_col]  <- pval_w
  }

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
  dims     <- auto_dims(n_total_rows, width, height,
                         has_wrapped = has_wrapped)
  ilab_cm  <- sum(ilab_col_widths)
  total_cm <- studlab_w + ilab_cm +
    (if (showweights) weight_w else 0) + 2 * gap_w + ci_cm + results_w +
    (if (show_pval) pval_w else 0)
  auto_w   <- as.integer(total_cm * 300 / 2.54) + 300L
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

  # -------------------------------------------------------------------
  # 9. Build grid layout
  # -------------------------------------------------------------------
  grid::grid.newpage()

  row_height_lines <- if (has_wrapped) 1.8 else 1.2
  rh <- rep(row_height_lines, n_total_rows)
  rh[1L + group_offset] <- if (has_wrapped_hdr) 2.6 else 1.5
  if (length(diamond_rows) > 0L) rh[diamond_rows] <- 2.0
  row_heights <- grid::unit(rh, "lines")

  root_layout <- grid::grid.layout(
    nrow    = n_total_rows,
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
  # 10a. Group header row (intervention / control)
  # -------------------------------------------------------------------
  current_row <- 1L

  if (has_groups) {
    e_ilab_cols <- ilab_cols[e_idx]
    c_ilab_cols <- ilab_cols[c_idx]
    push_span(current_row, min(e_ilab_cols), max(e_ilab_cols))
    grid::grid.text(if (!is.null(x$group.e)) x$group.e else "Intervention",
                    x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
    grid::popViewport()
    push_span(current_row, min(c_ilab_cols), max(c_ilab_cols))
    grid::grid.text(if (!is.null(x$group.c)) x$group.c else "Control",
                    x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
    grid::popViewport()
    current_row <- current_row + 1L
  }

  # -------------------------------------------------------------------
  # 10b. Column header row (with method summary in CI column)
  # -------------------------------------------------------------------
  push_cell(current_row, studlab_col)
  grid::grid.text("Study", x = grid::unit(0.5, "npc"),
                  just = "centre", gp = bold_gp)
  grid::popViewport()

  if (n_ilab > 0L) {
    for (j in seq_len(n_ilab)) {
      push_cell(current_row, ilab_cols[j])
      grid::grid.text(ilab_hdr_wrapped[j], x = grid::unit(0.5, "npc"),
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
  grid::grid.text("Estimate [95% CI]", x = grid::unit(0.5, "npc"),
                  just = "centre", gp = bold_gp)
  grid::popViewport()

  if (show_pval) {
    push_cell(current_row, pval_col)
    grid::grid.text("p-value", x = grid::unit(0.5, "npc"),
                    just = "centre", gp = bold_gp)
    grid::popViewport()
  }

  # Method summary (in CI column of header row)
  method_gp <- grid::gpar(fontface = "bold", cex = 0.65)
  push_cell(current_row, ci_col)
  grid::grid.text(sprintf("Inverse Variance, %s", measure),
                  x = grid::unit(0.5, "npc"), y = grid::unit(0.65, "npc"),
                  just = "centre", gp = method_gp)
  grid::grid.text(sprintf("Three-Level, \u03c1 = %.1f", x$rho),
                  x = grid::unit(0.5, "npc"), y = grid::unit(0.3, "npc"),
                  just = "centre", gp = method_gp)
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
  first_data_row <- current_row   # track for vertical pooled line
  study_row_index <- 0L           # global index for zebra shading

  # Helper: draw overall estimate vertical line in a CI cell (per-row,
  # so it renders in front of zebra shading but behind diamonds/squares)
  .show_ov_line <- overall && !is.na(x$estimate) &&
    x$estimate >= xlim_final[1] && x$estimate <= xlim_final[2]
  draw_ov_line <- function(row) {
    if (!.show_ov_line) return(invisible(NULL))
    push_cell(row, ci_col, xscale = xlim_final, clip = "off")
    grid::grid.segments(
      x0 = grid::unit(x$estimate, "native"),
      x1 = grid::unit(x$estimate, "native"),
      y0 = grid::unit(0, "npc"),
      y1 = grid::unit(1, "npc"),
      gp = grid::gpar(lty = "solid", col = "black", lwd = 0.8)
    )
    grid::popViewport()
  }

  for (gi in seq_along(levels_vec)) {
    gv <- levels_vec[gi]
    sg  <- subgroup_results[[gv]]
    idx <- sg$idx          # indices into sorted dat

    # ---- Subgroup header row ----
    draw_ov_line(current_row)
    push_span(current_row, studlab_col, last_col)
    grid::grid.text(as.character(gv),
                    x    = grid::unit(0, "npc"),
                    just = "left",
                    gp   = bold_gp)
    grid::popViewport()
    current_row <- current_row + 1L

    # ---- Study rows ----
    for (ii in seq_along(idx)) {
      global_i <- idx[ii]     # position in sorted dat
      study_row_index <- study_row_index + 1L
      row_i <- current_row

      # Row shading
      if (shade_mask[global_i]) {
        push_span(row_i, studlab_col, last_col)
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

      # Overall estimate vertical line (in front of zebra, behind squares)
      draw_ov_line(row_i)

      # Study label
      push_cell(row_i, studlab_col)
      grid::grid.text(as.character(slab_vals[global_i]),
                      x    = grid::unit(0.5, "npc"),
                      just = "centre",
                      gp   = norm_gp)
      grid::popViewport()

      # ilab columns
      if (n_ilab > 0L) {
        for (j in seq_len(n_ilab)) {
          push_cell(row_i, ilab_cols[j])
          grid::grid.text(ilab_wrapped[[j]][global_i],
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
        x    = grid::unit(0.5, "npc"),
        just = "centre",
        gp   = norm_gp
      )
      grid::popViewport()

      current_row <- current_row + 1L
    }  # end study rows for this subgroup

    # ---- Subgroup diamond row (only if 2+ observations) ----
    if (sg$has_diamond && !is.na(sg$est)) {
      row_d <- current_row

      # "Subgroup" label + I2 spanning studlab to gap1 (left-aligned)
      sg_mlab <- sprintf("k = %d | I\u00b2 = %.0f%% (btw: %.0f%%, wth: %.0f%%)",
                         sg$n_clust, sg$i2$total,
                         sg$i2$between, sg$i2$within)
      push_span(row_d, studlab_col, gap1_col)
      grid::grid.text("Subgroup",
                      x    = grid::unit(0, "npc"),
                      y    = grid::unit(0.65, "npc"),
                      just = "left",
                      gp   = grid::gpar(cex = 0.75, fontface = "bold"))
      grid::grid.text(sg_mlab,
                      x    = grid::unit(0, "npc"),
                      y    = grid::unit(0.25, "npc"),
                      just = "left",
                      gp   = grid::gpar(cex = 0.65, fontface = "italic"))
      grid::popViewport()

      # Aggregated ilab values for this subgroup
      if (n_ilab > 0L) {
        sg_data    <- dat[idx, , drop = FALSE]
        sg_cluster <- sg_data[[cluster]]
        for (j in seq_len(n_ilab)) {
          sg_col <- sg_data[[ilab[j]]]
          agg <- aggregate_ilab_col(sg_col, ilab[j], sg_cluster,
                                    data = sg_data)
          if (nzchar(agg)) {
            push_cell(row_d, ilab_cols[j])
            grid::grid.text(agg,
                            x    = grid::unit(0.5, "npc"),
                            y    = grid::unit(0.65, "npc"),
                            just = "centre",
                            gp   = grid::gpar(cex = 0.75, fontface = "bold"))
            grid::popViewport()
          }
        }
      }

      # Subgroup weight percentage
      if (showweights) {
        sg_weight_pct <- sum(w_pct[idx])
        push_cell(row_d, weight_col)
        grid::grid.text(sprintf("%.1f%%", sg_weight_pct),
                        x    = grid::unit(0.5, "npc"),
                        y    = grid::unit(0.65, "npc"),
                        just = "centre",
                        gp   = grid::gpar(cex = 0.75, fontface = "bold"))
        grid::popViewport()
      }

      # Overall estimate vertical line (behind diamond)
      draw_ov_line(row_d)

      # Diamond in CI panel
      if (!is.na(sg$lb) && !is.na(sg$ub)) {
        push_cell(row_d, ci_col, xscale = xlim_final, clip = "on")
        draw_diamond(
          max(sg$lb, xlim_final[1]),
          min(max(sg$est, xlim_final[1]), xlim_final[2]),
          min(sg$ub, xlim_final[2]),
          y_center = 0.65
        )
        grid::popViewport()
      }

      # Estimate text
      sg_result_text <- sprintf("%.2f [%.2f; %.2f]", sg$est, sg$lb, sg$ub)
      push_cell(row_d, results_col)
      grid::grid.text(
        sg_result_text,
        x    = grid::unit(0.5, "npc"),
        y    = grid::unit(0.65, "npc"),
        just = "centre",
        gp   = grid::gpar(cex = 0.75, fontface = "bold")
      )
      grid::popViewport()

      # p-value column
      if (show_pval && !is.na(sg$pval)) {
        sg_pval_str <- if (sg$pval < 0.001) "<0.001" else sprintf("%.4f", sg$pval)
        push_cell(row_d, pval_col)
        grid::grid.text(sg_pval_str,
                        x    = grid::unit(0.5, "npc"),
                        y    = grid::unit(0.65, "npc"),
                        just = "centre",
                        gp   = grid::gpar(cex = 0.75, fontface = "bold"))
        grid::popViewport()
      }

      current_row <- current_row + 1L
    }

    # ---- Blank separator row (not after last subgroup) ----
    if (gi < length(levels_vec)) {
      draw_ov_line(current_row)
      current_row <- current_row + 1L
    }
  }  # end subgroup loop

  # -------------------------------------------------------------------
  # 13. Overall diamond row (+ I2 on same row)
  # -------------------------------------------------------------------
  if (overall) {
    # Blank separator before overall
    draw_ov_line(current_row)
    current_row <- current_row + 1L

    row_ov <- current_row

    # "Overall" + I2 spanning studlab to gap1 (left-aligned)
    push_span(row_ov, studlab_col, gap1_col)
    grid::grid.text("Overall",
                    x    = grid::unit(0, "npc"),
                    y    = grid::unit(0.65, "npc"),
                    just = "left",
                    gp   = grid::gpar(cex = 0.75, fontface = "bold"))
    grid::grid.text(format_mlab(x$i2),
                    x    = grid::unit(0, "npc"),
                    y    = grid::unit(0.25, "npc"),
                    just = "left",
                    gp   = grid::gpar(cex = 0.65, fontface = "italic"))
    grid::popViewport()

    # Aggregated ilab values for overall
    if (n_ilab > 0L) {
      all_cluster <- dat[[cluster]]
      for (j in seq_len(n_ilab)) {
        all_col <- dat[[ilab[j]]]
        agg <- aggregate_ilab_col(all_col, ilab[j], all_cluster,
                                  data = dat)
        if (nzchar(agg)) {
          push_cell(row_ov, ilab_cols[j])
          grid::grid.text(agg,
                          x    = grid::unit(0.5, "npc"),
                          y    = grid::unit(0.65, "npc"),
                          just = "centre",
                          gp   = grid::gpar(cex = 0.75, fontface = "bold"))
          grid::popViewport()
        }
      }
    }

    # Overall weight (100%)
    if (showweights) {
      push_cell(row_ov, weight_col)
      grid::grid.text("100.0%",
                      x    = grid::unit(0.5, "npc"),
                      y    = grid::unit(0.65, "npc"),
                      just = "centre",
                      gp   = grid::gpar(cex = 0.75, fontface = "bold"))
      grid::popViewport()
    }

    draw_ov_line(row_ov)

    push_cell(row_ov, ci_col, xscale = xlim_final, clip = "on")
    draw_diamond(x$ci.lb, x$estimate, x$ci.ub, y_center = 0.65)
    grid::popViewport()

    ov_text <- sprintf("%.2f [%.2f; %.2f]", x$estimate, x$ci.lb, x$ci.ub)
    push_cell(row_ov, results_col)
    grid::grid.text(ov_text,
                    x    = grid::unit(0.5, "npc"),
                    y    = grid::unit(0.65, "npc"),
                    just = "centre",
                    gp   = grid::gpar(cex = 0.75, fontface = "bold"))
    grid::popViewport()

    # Overall p-value column
    if (show_pval) {
      pval_ov <- x$model$pval
      pval_ov_str <- if (is.na(pval_ov)) "" else
        if (pval_ov < 0.001) "<0.001" else sprintf("%.4f", pval_ov)
      push_cell(row_ov, pval_col)
      grid::grid.text(pval_ov_str,
                      x    = grid::unit(0.5, "npc"),
                      y    = grid::unit(0.65, "npc"),
                      just = "centre",
                      gp   = grid::gpar(cex = 0.75, fontface = "bold"))
      grid::popViewport()
    }

    current_row <- current_row + 1L
  }

  # -------------------------------------------------------------------
  # 14. X-axis row (immediately after overall diamond)
  #     Q-test text shares this row in the text columns
  # -------------------------------------------------------------------
  at_final <- if (!is.null(at)) at else pretty(xlim_final, n = 5L)
  # Extend overall estimate line into the axis row (top half only)
  if (.show_ov_line) {
    push_cell(current_row, ci_col, xscale = xlim_final, clip = "off")
    grid::grid.segments(
      x0 = grid::unit(x$estimate, "native"),
      x1 = grid::unit(x$estimate, "native"),
      y0 = grid::unit(1, "npc"),
      y1 = grid::unit(1, "npc"),
      gp = grid::gpar(lty = "solid", col = "black", lwd = 0.8)
    )
    grid::popViewport()
  }
  push_cell(current_row, ci_col, xscale = xlim_final, clip = "off")
  # Draw axis at top of row so it hugs the last diamond row
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

  # Q-test text in the text columns of the axis row
  if (nchar(qtest_text) > 0L) {
    push_span(current_row, studlab_col, gap1_col)
    grid::grid.text(qtest_text,
                    x    = grid::unit(0, "npc"),
                    just = "left",
                    gp   = grid::gpar(cex = 0.65, fontface = "bold"))
    grid::popViewport()
  }

  current_row <- current_row + 1L

  # -------------------------------------------------------------------
  # 15. Favours labels
  # -------------------------------------------------------------------
  if (measure %in% c("SMD", "MD", "RR", "OR")) {
    fav_left  <- paste0("Favours ",
                        if (!is.null(x$group.c)) x$group.c else "Control")
    fav_right <- paste0("Favours ",
                        if (!is.null(x$group.e)) x$group.e else "Treatment")
    fav_gp <- grid::gpar(fontface = "bold", cex = 0.75)
    push_cell(current_row, ci_col, xscale = xlim_final, clip = "off")
    grid::grid.text(fav_left,
                    x    = grid::unit(0.25, "npc"),
                    just = "centre",
                    gp   = fav_gp)
    grid::grid.text(fav_right,
                    x    = grid::unit(0.75, "npc"),
                    just = "centre",
                    gp   = fav_gp)
    grid::popViewport()
    current_row <- current_row + 1L
  }

  # -------------------------------------------------------------------
  # 15b. Title below favours
  # -------------------------------------------------------------------
  if (!is.null(title) && nzchar(title)) {
    push_cell(current_row, ci_col)
    grid::grid.text(title,
                    x    = grid::unit(0.5, "npc"),
                    just = "centre",
                    gp   = grid::gpar(fontface = "bold", cex = 0.85))
    grid::popViewport()
    current_row <- current_row + 1L
  }

  # (Q-test drawn in axis row text columns)

  if (!is.null(xlab)) {
    push_cell(current_row, ci_col)
    grid::grid.text(xlab, x = grid::unit(0.5, "npc"),
                    just = "centre",
                    gp = grid::gpar(cex = 0.7))
    grid::popViewport()
    current_row <- current_row + 1L
  }

  # -------------------------------------------------------------------
  # 17. Cleanup
  # -------------------------------------------------------------------
  grid::popViewport()  # pop root layout viewport

  invisible(out_file)
}

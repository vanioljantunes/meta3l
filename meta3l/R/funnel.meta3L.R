# funnel.meta3L.R - Funnel plot and test for funnel plot asymmetry for a
# three-level meta-analysis.  Uses grid graphics exclusively.

#' Funnel plot for three-level meta-analysis results
#'
#' @param x A \code{meta3l_result} object returned by \code{\link{meta3L}}, or
#'   a (optionally named) list of them, in which case one panel is drawn per
#'   analysis and the asymmetry tests are summarised in a single table.
#' @param ... Further arguments passed to the method.
#'
#' @return Invisibly, a list with the asymmetry test(s) and the file path.
#'
#' @export
funnel <- function(x, ...) UseMethod("funnel")

#' Test for funnel plot asymmetry in a three-level model (internal)
#'
#' Egger's regression adapted to the three-level structure: the effect sizes
#' are regressed on their standard error inside the same
#' \code{cluster / effect} random structure, and the slope is tested with
#' cluster-robust (CR2) standard errors.  A slope different from zero indicates
#' that smaller studies report systematically different effects.
#'
#' @param x A \code{meta3l_result} object.
#'
#' @return A named list with \code{slope}, \code{se}, \code{ci.lb},
#'   \code{ci.ub}, \code{pval} and \code{k_clust}, or \code{NULL} when the
#'   model cannot be fitted.
#'
#' @keywords internal
funnel_asymmetry <- function(x) {
  dat <- x$data
  dat$sei <- sqrt(dat$vi)

  random_formula <- stats::as.formula(paste0("~ 1 | ", x$cluster, " / TE_id"))
  fit <- tryCatch(
    metafor::rma.mv(yi, x$V, mods = ~ sei, random = random_formula, data = dat),
    error = function(e) {
      tryCatch(
        metafor::rma.mv(yi, x$V, mods = ~ sei, random = random_formula,
                        data = dat, control = list(optimizer = "bobyqa")),
        error = function(e2) NULL
      )
    }
  )
  if (is.null(fit)) return(NULL)

  rob <- tryCatch(
    metafor::robust(fit, cluster = dat[[x$cluster]], clubSandwich = TRUE),
    error = function(e) fit
  )

  i <- which(rownames(rob$b) == "sei")
  if (length(i) == 0L) return(NULL)

  list(
    slope   = as.numeric(rob$b[i]),
    se      = as.numeric(rob$se[i]),
    ci.lb   = as.numeric(rob$ci.lb[i]),
    ci.ub   = as.numeric(rob$ci.ub[i]),
    pval    = as.numeric(rob$pval[i]),
    k_clust = length(unique(dat[[x$cluster]]))
  )
}

#' Default x-axis label for an effect size measure (internal)
#'
#' @param measure Character string.
#' @return Character string.
#' @keywords internal
funnel_xlab <- function(measure) {
  switch(measure,
         MD  = "Mean difference",
         SMD = "Standardised mean difference",
         RR  = "Log risk ratio",
         OR  = "Log odds ratio",
         "Effect size")
}

#' Draw one funnel panel in the current viewport (internal)
#'
#' @param x     A \code{meta3l_result} object.
#' @param label Character; panel heading.
#' @param xlab  Character; x-axis label.
#' @param ylab  Character; y-axis label.
#' @param xlim  Numeric length 2 or \code{NULL}.
#' @return Invisibly \code{NULL}.
#' @keywords internal
funnel_panel <- function(x, label, xlab, ylab, xlim = NULL) {
  dat <- x$data
  yi  <- dat$yi
  sei <- sqrt(dat$vi)
  est <- as.numeric(x$model$b)

  se_max <- max(sei, na.rm = TRUE) * 1.05
  if (is.null(xlim)) {
    span <- max(abs(c(yi, est + 1.96 * se_max, est - 1.96 * se_max) - est),
                na.rm = TRUE)
    xlim <- c(est - span * 1.05, est + span * 1.05)
  }

  grid::pushViewport(grid::viewport(
    width  = grid::unit(1, "npc") - grid::unit(2.6, "cm"),
    height = grid::unit(1, "npc") - grid::unit(2.6, "cm"),
    xscale = xlim, yscale = c(se_max, 0)
  ))

  grid::grid.polygon(
    x  = grid::unit(c(est, est - 1.96 * se_max, est + 1.96 * se_max), "native"),
    y  = grid::unit(c(0, se_max, se_max), "native"),
    gp = grid::gpar(fill = rgb(0.94, 0.94, 0.94), col = "grey60", lty = "22")
  )
  grid::grid.segments(
    x0 = grid::unit(est, "native"), x1 = grid::unit(est, "native"),
    y0 = grid::unit(0, "native"),   y1 = grid::unit(se_max, "native"),
    gp = grid::gpar(col = "grey30", lwd = 0.8)
  )
  keep <- is.finite(yi) & is.finite(sei)
  grid::grid.points(
    x   = grid::unit(pmin(pmax(yi[keep], xlim[1]), xlim[2]), "native"),
    y   = grid::unit(sei[keep], "native"),
    pch = 21,
    gp  = grid::gpar(fill = rgb(0.35, 0.35, 0.35, 0.6), col = "grey15",
                     cex = 0.5)
  )
  grid::grid.rect(gp = grid::gpar(fill = NA, col = "grey40", lwd = 0.7))
  grid::grid.xaxis(gp = grid::gpar(cex = 0.6))
  grid::grid.yaxis(gp = grid::gpar(cex = 0.6))
  grid::grid.text(xlab, y = grid::unit(-2.6, "lines"),
                  gp = grid::gpar(cex = 0.7))
  grid::grid.text(ylab, x = grid::unit(-3.0, "lines"), rot = 90,
                  gp = grid::gpar(cex = 0.7))
  if (!is.null(label) && nzchar(label)) {
    grid::grid.text(label, y = grid::unit(1, "npc") + grid::unit(1, "lines"),
                    gp = grid::gpar(cex = 0.8, fontface = "bold"))
  }
  grid::popViewport()
  invisible(NULL)
}

#' Draw the asymmetry results as a table in the current viewport (internal)
#'
#' @param rows Data frame with columns \code{analysis}, \code{slope},
#'   \code{ci.lb}, \code{ci.ub}, \code{pval}, \code{k_clust}.
#' @return Invisibly \code{NULL}.
#' @keywords internal
funnel_table <- function(rows) {
  hdr <- c("Analysis", "Slope", "Lower", "Upper", "p-value", "Studies")
  body <- cbind(
    rows$analysis,
    sprintf("%.2f", rows$slope),
    sprintf("%.2f", rows$ci.lb),
    sprintf("%.2f", rows$ci.ub),
    ifelse(rows$pval < 0.001, "<0.001", sprintf("%.4f", rows$pval)),
    format(rows$k_clust)
  )
  n_rows <- nrow(body) + 1L
  widths <- grid::unit.c(
    grid::unit(max(4, ilab_col_cm(max(nchar(c(hdr[1], rows$analysis))))), "cm"),
    grid::unit(rep(1.9, 4), "cm"),
    grid::unit(1.7, "cm")
  )

  grid::pushViewport(grid::viewport(
    layout = grid::grid.layout(nrow = n_rows, ncol = 6L, widths = widths,
                               heights = grid::unit(rep(1.15, n_rows), "lines")),
    width  = grid::unit(sum(as.numeric(grid::convertWidth(widths, "cm"))), "cm")
  ))

  cell <- function(r, c, txt, gp, just = "centre") {
    grid::pushViewport(grid::viewport(layout.pos.row = r, layout.pos.col = c))
    grid::grid.text(txt, x = grid::unit(if (identical(just, "left")) 0 else 0.5,
                                        "npc"),
                    just = just, gp = gp)
    grid::popViewport()
  }

  bold_gp <- grid::gpar(cex = 0.7, fontface = "bold")
  norm_gp <- grid::gpar(cex = 0.7)

  for (j in seq_along(hdr)) {
    cell(1L, j, hdr[j], bold_gp, just = if (j == 1L) "left" else "centre")
  }
  # rule under the header
  grid::pushViewport(grid::viewport(layout.pos.row = 1L, layout.pos.col = 1:6))
  grid::grid.segments(x0 = 0, x1 = 1, y0 = 0, y1 = 0,
                      gp = grid::gpar(col = "grey40", lwd = 0.7))
  grid::popViewport()

  for (i in seq_len(nrow(body))) {
    for (j in seq_len(ncol(body))) {
      cell(i + 1L, j, body[i, j], norm_gp,
           just = if (j == 1L) "left" else "centre")
    }
  }
  grid::popViewport()
  invisible(NULL)
}

# ---------------------------------------------------------------------------
# Internal engine shared by both methods
# ---------------------------------------------------------------------------

#' Draw funnel panels and their asymmetry table (internal)
#'
#' @param objs Named list of \code{meta3l_result} objects to draw.
#' @param title,xlab,ylab,xlim,test,file,format,width,height As in
#'   \code{\link{funnel}}.
#' @return Invisibly a list with \code{test} and \code{file}.
#' @keywords internal
funnel_draw <- function(objs, title, xlab, ylab, xlim, test,
                        file, format, width, height, name_for_file) {
  n <- length(objs)
  measure <- objs[[1L]]$measure
  if (is.null(xlab)) xlab <- funnel_xlab(measure)

  res <- lapply(objs, function(o) if (isTRUE(test)) funnel_asymmetry(o) else NULL)
  tab <- NULL
  if (isTRUE(test) && any(!vapply(res, is.null, logical(1L)))) {
    keep <- !vapply(res, is.null, logical(1L))
    tab <- data.frame(
      analysis = names(objs)[keep],
      slope    = vapply(res[keep], function(r) r$slope, numeric(1L)),
      ci.lb    = vapply(res[keep], function(r) r$ci.lb, numeric(1L)),
      ci.ub    = vapply(res[keep], function(r) r$ci.ub, numeric(1L)),
      pval     = vapply(res[keep], function(r) r$pval, numeric(1L)),
      k_clust  = vapply(res[keep], function(r) r$k_clust, numeric(1L)),
      stringsAsFactors = FALSE
    )
  }

  out_file <- resolve_file(list(name = name_for_file), file, format,
                           suffix = "funnel")
  w <- if (!is.null(width))  width  else as.integer(1750 * n + 350)
  tab_lines <- if (is.null(tab)) 0 else (nrow(tab) + 1) * 1.15 + 1.5
  h <- if (!is.null(height)) height else
    as.integer(1900 + tab_lines * 60)

  if (!is.null(out_file)) {
    if (identical(format, "pdf")) {
      grDevices::pdf(out_file, width = w / 300, height = h / 300)
    } else {
      grDevices::png(out_file, width = w, height = h, res = 300L)
    }
  } else {
    grDevices::pdf(nullfile(), width = w / 300, height = h / 300)
  }
  on.exit(grDevices::dev.off(), add = TRUE)

  grid::grid.newpage()
  has_title <- !is.null(title) && nzchar(title)
  heights <- grid::unit.c(
    grid::unit(if (has_title) 2 else 0.4, "lines"),
    grid::unit(1, "null"),
    grid::unit(if (is.null(tab)) 0.4 else tab_lines, "lines")
  )
  grid::pushViewport(grid::viewport(
    layout = grid::grid.layout(nrow = 3L, ncol = 1L, heights = heights),
    width  = grid::unit(1, "npc") - grid::unit(0.6, "cm"),
    height = grid::unit(1, "npc") - grid::unit(0.6, "cm")
  ))

  if (has_title) {
    grid::pushViewport(grid::viewport(layout.pos.row = 1L))
    grid::grid.text(title, gp = grid::gpar(cex = 1.0, fontface = "bold"))
    grid::popViewport()
  }

  grid::pushViewport(grid::viewport(
    layout.pos.row = 2L,
    layout = grid::grid.layout(nrow = 1L, ncol = n)
  ))
  for (i in seq_len(n)) {
    grid::pushViewport(grid::viewport(layout.pos.col = i))
    # frame each panel, as the brain map does
    grid::grid.rect(width  = grid::unit(1, "npc") - grid::unit(0.25, "cm"),
                    height = grid::unit(1, "npc") - grid::unit(0.25, "cm"),
                    gp = grid::gpar(fill = NA, col = "grey45", lwd = 0.6))
    funnel_panel(objs[[i]], names(objs)[i], xlab, ylab, xlim)
    grid::popViewport()
  }
  grid::popViewport()

  if (!is.null(tab)) {
    grid::pushViewport(grid::viewport(layout.pos.row = 3L))
    funnel_table(tab)
    grid::popViewport()
  }
  grid::popViewport()

  invisible(list(test = if (n == 1L) res[[1L]] else res, file = out_file,
                 table = tab, skipped = FALSE))
}

# ---------------------------------------------------------------------------
# S3 methods
# ---------------------------------------------------------------------------

#' @param min.studies Integer; an analysis is only drawn when it has at least
#'   this many study clusters (default \code{10}, the usual threshold for
#'   assessing funnel plot asymmetry).  The count is of studies, not of effect
#'   sizes.
#' @param xlim Numeric vector of length 2; x-axis limits.  \code{NULL}
#'   auto-computes per panel.
#' @param xlab Character string; x-axis label.  \code{NULL} derives it from the
#'   measure.
#' @param ylab Character string; y-axis label.
#' @param title Character string; figure title drawn above the panels.
#' @param test Logical; run the asymmetry test and summarise it in a table
#'   under the panels (default \code{TRUE}).
#' @param file One of: \code{character(0)} (default, auto-name); \code{NULL}
#'   (display only); or an explicit file path.
#' @param format Character; \code{"png"} (default) or \code{"pdf"}.
#' @param width,height Integer; output size in pixels.  \code{NULL}
#'   auto-computes.
#' @param ... Currently ignored.
#'
#' @details
#' Each point is one effect size, plotted against its standard error, with the
#' pooled estimate as a vertical line and the pseudo 95\% confidence region as
#' the funnel.  Because a study can contribute several effect sizes, points
#' within a study are not independent; the asymmetry test accounts for that
#' through the same three-level structure used for the pooled estimate.
#'
#' @return Invisibly, a list with \code{test}, \code{table}, \code{file} and
#'   \code{skipped}.
#'
#' @importFrom grDevices rgb png pdf dev.off
#' @method funnel meta3l_result
#' @export
funnel.meta3l_result <- function(x,
                                 min.studies = 10L,
                                 xlim        = NULL,
                                 xlab        = NULL,
                                 ylab        = "Standard error",
                                 title       = NULL,
                                 test        = TRUE,
                                 file        = character(0),
                                 format      = "png",
                                 width       = NULL,
                                 height      = NULL,
                                 ...) {

  k_clust <- length(unique(x$data[[x$cluster]]))
  if (k_clust < min.studies) {
    message(x$name, ": ", k_clust, " studies (< ", min.studies,
            "), funnel plot skipped.")
    return(invisible(list(test = NULL, table = NULL, file = NULL,
                          skipped = TRUE)))
  }

  objs <- list(x)
  names(objs) <- if (!is.null(x$name)) x$name else "Analysis"
  if (is.null(title)) title <- paste0("Funnel plot: ", names(objs)[1L])

  funnel_draw(objs, title, xlab, ylab, xlim, test, file, format, width, height,
              name_for_file = if (!is.null(x$name)) x$name else "meta3l_plot")
}

#' @rdname funnel
#' @param name Character string; base name used when \code{file} is
#'   auto-generated.  List method only.
#' @method funnel list
#' @export
funnel.list <- function(x,
                        min.studies = 10L,
                        xlim        = NULL,
                        xlab        = NULL,
                        ylab        = "Standard error",
                        title       = NULL,
                        test        = TRUE,
                        name        = "funnel",
                        file        = character(0),
                        format      = "png",
                        width       = NULL,
                        height      = NULL,
                        ...) {

  ok <- vapply(x, inherits, logical(1L), what = "meta3l_result")
  if (!all(ok)) {
    stop("funnel() needs meta3l_result objects; offending position(s): ",
         paste(which(!ok), collapse = ", "), ".", call. = FALSE)
  }

  nm <- names(x)
  if (is.null(nm)) {
    nm <- vapply(x, function(o) if (!is.null(o$name)) o$name else "Analysis",
                 character(1L))
    names(x) <- nm
  }

  k <- vapply(x, function(o) length(unique(o$data[[o$cluster]])), numeric(1L))
  keep <- k >= min.studies
  if (any(!keep)) {
    message("Fewer than ", min.studies, " studies, funnel plot skipped for: ",
            paste(sprintf("%s (%d)", nm[!keep], k[!keep]), collapse = ", "), ".")
  }
  if (!any(keep)) {
    return(invisible(list(test = NULL, table = NULL, file = NULL,
                          skipped = TRUE)))
  }

  funnel_draw(x[keep], title, xlab, ylab, xlim, test, file, format,
              width, height, name_for_file = name)
}

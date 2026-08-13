# funnel.meta3L.R - Funnel plot and test for funnel plot asymmetry for a
# three-level meta-analysis.  Uses grid graphics exclusively.

#' Funnel plot for three-level meta-analysis results
#'
#' @param x A \code{meta3l_result} object returned by \code{\link{meta3L}}.
#' @param ... Further arguments passed to the method.
#'
#' @return Invisibly, a list with the asymmetry test and the file path.
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

# ---------------------------------------------------------------------------
# S3 method
# ---------------------------------------------------------------------------

#' @param min.studies Integer; the plot is only produced when the analysis has
#'   at least this many study clusters (default \code{10}, the usual threshold
#'   for assessing funnel plot asymmetry).  Note that the count is of studies,
#'   not of effect sizes.
#' @param xlim Numeric vector of length 2; x-axis limits.  \code{NULL}
#'   auto-computes.
#' @param xlab Character string; x-axis label.  \code{NULL} derives it from the
#'   measure.
#' @param ylab Character string; y-axis label.
#' @param title Character string; plot title.  Defaults to \code{x$name}.
#' @param test Logical; run the asymmetry test and print it under the plot
#'   (default \code{TRUE}).
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
#' @return Invisibly, a list with \code{test} (the asymmetry test, or
#'   \code{NULL}), \code{file} (the path written, or \code{NULL}) and
#'   \code{skipped} (\code{TRUE} when the analysis had fewer than
#'   \code{min.studies} clusters).
#'
#' @importFrom grDevices rgb png pdf dev.off
#' @method funnel meta3l_result
#' @export
funnel.meta3l_result <- function(x,
                                 min.studies = 10L,
                                 xlim        = NULL,
                                 xlab        = NULL,
                                 ylab        = "Standard error",
                                 title       = x$name,
                                 test        = TRUE,
                                 file        = character(0),
                                 format      = "png",
                                 width       = NULL,
                                 height      = NULL,
                                 ...) {

  stopifnot(inherits(x, "meta3l_result"))

  dat     <- x$data
  k_clust <- length(unique(dat[[x$cluster]]))
  if (k_clust < min.studies) {
    message(x$name, ": ", k_clust, " studies (< ", min.studies,
            "), funnel plot skipped.")
    return(invisible(list(test = NULL, file = NULL, skipped = TRUE)))
  }

  yi  <- dat$yi
  sei <- sqrt(dat$vi)
  est <- as.numeric(x$model$b)

  res <- if (isTRUE(test)) funnel_asymmetry(x) else NULL

  se_max <- max(sei, na.rm = TRUE) * 1.05
  if (is.null(xlim)) {
    span <- max(abs(c(yi, est + 1.96 * se_max, est - 1.96 * se_max) - est),
                na.rm = TRUE)
    xlim <- c(est - span * 1.05, est + span * 1.05)
  }
  if (is.null(xlab)) {
    xlab <- switch(x$measure,
                   MD  = "Mean difference",
                   SMD = "Standardised mean difference",
                   RR  = "Log risk ratio",
                   OR  = "Log odds ratio",
                   "Effect size")
  }

  out_file <- resolve_file(x, file, format, suffix = "funnel")
  w <- if (!is.null(width))  width  else 2100L
  h <- if (!is.null(height)) height else 2000L

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
  grid::pushViewport(grid::viewport(
    x = grid::unit(0.5, "npc"), y = grid::unit(0.5, "npc"),
    width  = grid::unit(1, "npc") - grid::unit(2.6, "cm"),
    height = grid::unit(1, "npc") - grid::unit(4.0, "cm"),
    xscale = xlim, yscale = c(se_max, 0)
  ))

  # funnel: pseudo 95% confidence region around the pooled estimate
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
    x = grid::unit(pmin(pmax(yi[keep], xlim[1]), xlim[2]), "native"),
    y = grid::unit(sei[keep], "native"),
    pch = 21,
    gp  = grid::gpar(fill = rgb(0.35, 0.35, 0.35, 0.6), col = "grey15",
                     cex = 0.55)
  )

  grid::grid.rect(gp = grid::gpar(fill = NA, col = "grey40", lwd = 0.7))
  grid::grid.xaxis(gp = grid::gpar(cex = 0.65))
  grid::grid.yaxis(gp = grid::gpar(cex = 0.65))
  grid::grid.text(xlab, y = grid::unit(-2.6, "lines"),
                  gp = grid::gpar(cex = 0.75))
  grid::grid.text(ylab, x = grid::unit(-3.2, "lines"), rot = 90,
                  gp = grid::gpar(cex = 0.75))
  if (!is.null(title) && nzchar(title)) {
    grid::grid.text(title, y = grid::unit(1, "npc") + grid::unit(1.6, "lines"),
                    gp = grid::gpar(cex = 0.9, fontface = "bold"))
  }
  if (!is.null(res)) {
    p_txt <- if (res$pval < 0.001) "p < 0.001" else sprintf("p = %.3f", res$pval)
    grid::grid.text(
      sprintf("Test for funnel plot asymmetry: slope %.2f (95%% CI %.2f to %.2f), %s; %d studies",
              res$slope, res$ci.lb, res$ci.ub, p_txt, res$k_clust),
      x = grid::unit(0, "npc"), y = grid::unit(-4.4, "lines"), just = "left",
      gp = grid::gpar(cex = 0.6, fontface = "italic")
    )
  }
  grid::popViewport()

  invisible(list(test = res, file = out_file, skipped = FALSE))
}

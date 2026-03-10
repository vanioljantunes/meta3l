#' Print a meta3l_result object
#'
#' Displays a compact summary of a three-level meta-analysis result including
#' the back-transformed pooled estimate, 95\% confidence interval, number of
#' studies and effect sizes, assumed within-cluster correlation, and multilevel
#' I-squared decomposition.
#'
#' @param x An object of class \code{"meta3l_result"} as returned by
#'   \code{\link{meta3L}}.
#' @param digits Integer; number of decimal places used when formatting the
#'   pooled estimate and confidence limits.  Defaults to \code{4}.
#' @param ... Additional arguments (currently unused; present for S3
#'   compatibility).
#'
#' @return Invisibly returns \code{x}.
#'
#' @export
#' @method print meta3l_result
print.meta3l_result <- function(x, digits = 4L, ...) {
  # Number of unique clusters (studies)
  k <- length(unique(x$data[[x$cluster]]))
  # Total number of effect sizes
  n <- nrow(x$data)

  cat("Three-Level Meta-Analysis (meta3l)\n")
  cat(rep("-", 40L), "\n", sep = "")
  cat(sprintf("Measure  : %s\n", x$measure))
  cat(sprintf("Pooled   : %s  [95%% CI: %s, %s]\n",
              format(round(x$estimate, digits), nsmall = digits),
              format(round(x$ci.lb,    digits), nsmall = digits),
              format(round(x$ci.ub,    digits), nsmall = digits)))
  cat(sprintf("k        : %d studies,  n = %d effect sizes\n", k, n))
  cat(sprintf("rho      : %.2f (assumed within-cluster correlation)\n", x$rho))
  cat(rep("-", 40L), "\n", sep = "")
  cat(sprintf("I2 total   : %5.1f%%\n", x$i2$total))
  cat(sprintf("  between  : %5.1f%%\n", x$i2$between))
  cat(sprintf("  within   : %5.1f%%\n", x$i2$within))
  cat(rep("-", 40L), "\n", sep = "")
  cat("Robust SEs via clubSandwich (CR2)\n")

  invisible(x)
}

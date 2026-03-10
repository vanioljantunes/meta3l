#' Summarise a meta3l_result object
#'
#' Displays a detailed summary of a three-level meta-analysis result.
#' Everything shown by \code{\link{print.meta3l_result}} is included, plus
#' sigma-squared variance components, the robust variance table, and model
#' convergence information.
#'
#' @param object An object of class \code{"meta3l_result"} as returned by
#'   \code{\link{meta3L}}.
#' @param digits Integer; number of decimal places used when formatting numeric
#'   values.  Defaults to \code{4}.
#' @param ... Additional arguments (currently unused; present for S3
#'   compatibility).
#'
#' @return Invisibly returns \code{object}.
#'
#' @export
#' @method summary meta3l_result
summary.meta3l_result <- function(object, digits = 4L, ...) {
  # Print the compact summary first
  print(object, digits = digits)

  # Access the underlying rma.mv fit (the non-robust version is not stored, so
  # sigma2 comes from the robust model which still carries the rma.mv sigma2
  # values; metafor's robust() preserves $sigma2 from the original fit)
  fit <- object$model  # robust.rma object

  cat("\n")
  cat("Variance components (sigma2):\n")
  cat(sprintf("  Level 3 (between-cluster) : %.6f\n", fit$sigma2[1L]))
  cat(sprintf("  Level 2 (within-cluster)  : %.6f\n", fit$sigma2[2L]))

  cat("\n")
  cat("Robust variance table (CR2):\n")

  # Extract robust coefficient table
  b    <- fit$b[[1L]]
  se   <- fit$se
  zval <- fit$zval
  pval <- fit$pval
  ci_lb <- fit$ci.lb
  ci_ub <- fit$ci.ub

  cat(sprintf("  Estimate (log scale) : %.*f\n", digits, b))
  cat(sprintf("  SE (robust CR2)      : %.*f\n", digits, se))
  cat(sprintf("  z-value              : %.*f\n", digits, zval))
  cat(sprintf("  p-value              : %.*f\n", digits, pval))
  cat(sprintf("  95%% CI [log scale]  : [%.*f, %.*f]\n",
              digits, ci_lb, digits, ci_ub))

  cat("\n")
  cat("Convergence:\n")
  if (!is.null(fit$conv) && fit$conv == 0L) {
    cat("  Model converged successfully.\n")
  } else if (!is.null(fit$convergence)) {
    conv_msg <- if (fit$convergence == 0L) "successful" else "WARNING: may not have converged"
    cat(sprintf("  Convergence code: %d (%s)\n", fit$convergence, conv_msg))
  } else {
    cat("  Convergence status not available.\n")
  }

  invisible(object)
}

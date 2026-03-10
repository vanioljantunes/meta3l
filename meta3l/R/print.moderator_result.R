#' Print a moderator_result object
#'
#' Displays a manuscript-friendly summary of a moderator analysis, including
#' the moderator name, Wald-type omnibus test, likelihood-ratio test (LRT),
#' and per-subgroup back-transformed pooled estimates with 95\% confidence
#' intervals.
#'
#' @param x An object of class \code{"moderator_result"} as returned by
#'   \code{moderator.meta3L()}.
#' @param digits Integer; number of decimal places for estimates and CIs
#'   (default: 3).
#' @param digits_p Integer; number of decimal places for p-values
#'   (default: 4).
#' @param ... Currently unused.
#'
#' @return Invisibly returns \code{x}.
#'
#' @method print moderator_result
#' @export
print.moderator_result <- function(x, digits = 3L, digits_p = 4L, ...) {

  cat("\nModerator Analysis:", x$subgroup, "\n")
  cat(strrep("-", 60L), "\n\n")

  # --- Wald test line --------------------------------------------------------
  cat(sprintf(
    "Wald test:  QM(%d) = %.3f, p = %.*f\n",
    x$wald$df,
    x$wald$QM,
    digits_p,
    x$wald$QMp
  ))

  # --- LRT line -------------------------------------------------------------
  cat(sprintf(
    "LRT:        chi2(%d) = %.3f, p = %.*f\n",
    x$lrt$df,
    x$lrt$statistic,
    digits_p,
    x$lrt$pval
  ))

  cat("\n")

  # --- Per-subgroup estimates table -----------------------------------------
  cat("Per-subgroup estimates:\n")

  # Determine column widths
  lev_width <- max(nchar("Level"), nchar(x$estimates$level))
  k_width   <- max(nchar("k"), nchar(as.character(x$estimates$k)))

  fmt_est <- sprintf("%.*f", digits, x$estimates$estimate)
  fmt_lb  <- sprintf("%.*f", digits, x$estimates$ci.lb)
  fmt_ub  <- sprintf("%.*f", digits, x$estimates$ci.ub)
  ci_strs <- paste0("[", fmt_lb, ", ", fmt_ub, "]")

  est_width <- max(nchar("Estimate"), nchar(fmt_est))
  ci_width  <- max(nchar("[95% CI]"), nchar(ci_strs))

  # Header row
  cat(sprintf(
    "  %-*s  %*s  %-*s  %-*s\n",
    lev_width, "Level",
    k_width,   "k",
    est_width, "Estimate",
    ci_width,  "[95% CI]"
  ))
  cat(sprintf(
    "  %s  %s  %s  %s\n",
    strrep("-", lev_width),
    strrep("-", k_width),
    strrep("-", est_width),
    strrep("-", ci_width)
  ))

  # Data rows
  for (i in seq_len(nrow(x$estimates))) {
    cat(sprintf(
      "  %-*s  %*d  %-*s  %-*s\n",
      lev_width, x$estimates$level[[i]],
      k_width,   x$estimates$k[[i]],
      est_width, fmt_est[[i]],
      ci_width,  ci_strs[[i]]
    ))
  }

  cat("\n")
  invisible(x)
}

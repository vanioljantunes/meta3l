# bubble.meta3L.R — Meta-regression bubble plot for three-level meta-analysis
# Produces a scatter plot with regression line, CI band, bubble sizing by
# precision (1/sqrt(vi)), back-transformed axes, robust p-value annotation,
# and a summary table in the bottom margin.

#' Bubble plot for meta-regression with a continuous moderator
#'
#' Fits a meta-regression model using \code{metafor::rma.mv} with the named
#' continuous moderator, computes robust variance estimates via
#' \code{metafor::robust} (clubSandwich CR2), and draws a scatter plot with:
#' \itemize{
#'   \item Bubble sizes proportional to \code{1/sqrt(vi)}
#'   \item Regression line and CI band on the back-transformed scale
#'   \item Robust p-value annotation in the top-right margin
#'   \item Summary table (Estimate, 95\% CI, R², p-value) in the bottom margin
#' }
#'
#' @param x A \code{meta3l_result} object from \code{\link{meta3L}}.
#' @param ... Further arguments (currently unused).
#'
#' @return Invisibly returns a named list with:
#'   \describe{
#'     \item{summary}{A \code{data.frame} with columns \code{estimate},
#'       \code{ci.lb}, \code{ci.ub}, \code{r2}, \code{pval}.}
#'     \item{file}{The path to the saved file, or \code{NULL} if
#'       \code{file = NULL} (display-only mode).}
#'   }
#'
#' @export
bubble <- function(x, ...) UseMethod("bubble")

#' @describeIn bubble Bubble plot method for \code{meta3l_result} objects
#' @method bubble meta3L
#' @export
#'
#' @param x      A \code{meta3l_result} object from \code{\link{meta3L}}.
#' @param mod    Character string; name of the continuous moderator column in
#'   \code{x$data}.  Must be numeric.  Categorical (factor/character) columns
#'   are rejected with an informative error.
#' @param file   One of: \code{NULL} (display-only, no file saved);
#'   \code{character(0)} (auto-name based on \code{x$name} and \code{mod});
#'   or a character string (explicit file path).  Defaults to
#'   \code{character(0)} (auto-name).
#' @param format Character string; output device format.  One of \code{"png"}
#'   (default) or \code{"pdf"}.
#' @param width  Integer or \code{NULL}; plot width in pixels (png) or inches
#'   (pdf).  If \code{NULL}, defaults to 2200 px / 8 in.
#' @param height Integer or \code{NULL}; plot height in pixels (png) or inches
#'   (pdf).  If \code{NULL}, defaults to 1800 px / 7 in.
#' @param title  Character string or \code{NULL}; plot title.  If \code{NULL},
#'   auto-generated as \code{"Meta-regression: {mod}"}.
#' @param ...    Additional arguments (currently unused).
#'
#' @importFrom metafor rma.mv robust
#' @importFrom grDevices png pdf dev.off rgb
#' @importFrom stats as.formula predict
bubble.meta3L <- function(x, mod, file = character(0),
                          format = "png",
                          width  = NULL,
                          height = NULL,
                          title  = NULL,
                          ...) {

  # --- 1. Validate mod column -------------------------------------------------
  if (!mod %in% names(x$data)) {
    stop("Column '", mod, "' not found in meta3l_result$data.",
         call. = FALSE)
  }

  mod_col <- x$data[[mod]]

  if (is.factor(mod_col) || is.character(mod_col)) {
    stop(
      "Column '", mod, "' is categorical. ",
      "For categorical moderators, use moderator.meta3L() ",
      "or forest_subgroup.meta3L().",
      call. = FALSE
    )
  }

  # --- 2. Filter NA rows in yi, vi, and mod column ----------------------------
  keep <- !is.na(x$data$yi) & !is.na(x$data$vi) & !is.na(x$data[[mod]])
  dat  <- x$data[keep, , drop = FALSE]
  V    <- x$V[keep, keep, drop = FALSE]

  # --- 3. Build random formula ------------------------------------------------
  random_formula <- stats::as.formula(
    paste0("~ 1 | ", x$cluster, " / TE_id")
  )

  # --- 4. Fit null model for R-squared ----------------------------------------
  fit_null <- metafor::rma.mv(
    yi, V,
    random = random_formula,
    data   = dat
  )

  # --- 5. Fit full (meta-regression) model ------------------------------------
  mods_formula <- stats::as.formula(paste("~", mod))
  fit_full <- metafor::rma.mv(
    yi, V,
    mods   = mods_formula,
    random = random_formula,
    data   = dat
  )

  # --- 6. Robust variance estimation -----------------------------------------
  fit_rob <- metafor::robust(
    fit_full,
    cluster      = dat[[x$cluster]],
    clubSandwich = TRUE
  )

  # --- 7. Compute R-squared ---------------------------------------------------
  r2 <- max(0, (sum(fit_null$sigma2) - sum(fit_full$sigma2)) /
              (sum(fit_null$sigma2) + 1e-16))

  # --- 8. Extract robust p-value ---------------------------------------------
  # robust() returns a robust.rma object; QMp holds the robust Wald p-value
  pval <- fit_rob$QMp
  if (is.null(pval) || is.na(pval)) {
    # Fallback: use the first p-value from the coefficient table
    pval <- fit_rob$pval[length(fit_rob$pval)]
  }

  # --- 9. Back-transformed estimate from full model (slope coefficient) -------
  # Report the intercept back-transformed (pooled at mean moderator) via
  # a prediction at the mean of the moderator
  mod_mean <- mean(dat[[mod]], na.rm = TRUE)
  pred_mean <- stats::predict(fit_full,
                              newmods = matrix(mod_mean, ncol = 1L),
                              transf  = x$transf)
  est   <- pred_mean$pred
  ci_lb <- pred_mean$ci.lb
  ci_ub <- pred_mean$ci.ub

  # --- 10. Prediction grid for CI band ----------------------------------------
  x_seq  <- seq(min(dat[[mod]], na.rm = TRUE),
                max(dat[[mod]], na.rm = TRUE),
                length.out = 200L)
  pred   <- stats::predict(fit_full,
                            newmods = matrix(x_seq, ncol = 1L),
                            transf  = x$transf)

  # --- 11. Bubble sizes -------------------------------------------------------
  wi     <- 1 / sqrt(dat$vi)
  wi_min <- min(wi)
  wi_rng <- diff(range(wi)) + 1e-9
  cex_b  <- 0.6 + 2.5 * (wi - wi_min) / wi_rng

  # --- 12. Back-transform yi for scatter --------------------------------------
  y_plot <- x$transf(dat$yi)

  # --- 13. Resolve output file path ------------------------------------------
  suffix   <- paste0("bubble_", mod)
  out_path <- resolve_file(x, file, format, suffix = suffix)

  # --- 14. Open device --------------------------------------------------------
  if (!is.null(out_path)) {
    w_default <- if (format == "pdf") 8 else 2200L
    h_default <- if (format == "pdf") 7 else 1800L
    w <- if (!is.null(width))  width  else w_default
    h <- if (!is.null(height)) height else h_default

    if (format == "pdf") {
      grDevices::pdf(out_path, width = w, height = h)
    } else {
      grDevices::png(out_path, width = w, height = h, res = 150L)
    }
    on.exit(grDevices::dev.off(), add = TRUE)
  }

  # --- 15. Draw plot ----------------------------------------------------------
  # Extra bottom margin for summary table text
  old_par <- par(mar = c(7, 4, 3, 2))
  on.exit(par(old_par), add = TRUE)

  # Scatter with back-transformed yi
  plot(
    dat[[mod]], y_plot,
    cex  = cex_b,
    pch  = 21,
    bg   = grDevices::rgb(0.4, 0.4, 0.4, 0.5),
    xlab = mod,
    ylab = "Effect size",
    main = ""
  )

  # CI band polygon
  graphics::polygon(
    c(x_seq, rev(x_seq)),
    c(pred$ci.lb, rev(pred$ci.ub)),
    col    = grDevices::rgb(0.7, 0.85, 1, 0.4),
    border = NA
  )

  # Regression line
  graphics::lines(x_seq, pred$pred, lwd = 2, col = "darkblue")

  # Title
  main_title <- if (!is.null(title)) title else paste("Meta-regression:", mod)
  graphics::title(main = main_title)

  # Robust p-value annotation (top-right)
  graphics::mtext(
    sprintf("Robust p = %.4f", pval),
    side = 3, adj = 1, cex = 0.9
  )

  # Summary table in bottom margin
  summary_text <- sprintf(
    "Estimate: %.3f [%.3f, %.3f]  |  R\u00b2 = %.1f%%  |  p = %.4f",
    est, ci_lb, ci_ub, r2 * 100, pval
  )
  graphics::mtext(summary_text, side = 1, line = 5, cex = 0.85)

  # --- 16. Return value -------------------------------------------------------
  result_summary <- data.frame(
    estimate = est,
    ci.lb    = ci_lb,
    ci.ub    = ci_ub,
    r2       = r2,
    pval     = pval,
    stringsAsFactors = FALSE
  )

  invisible(list(summary = result_summary, file = out_path))
}

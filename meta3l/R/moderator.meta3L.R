#' S3 generic for moderator analysis
#'
#' Dispatches to the appropriate moderator method based on the class of
#' \code{x}.
#'
#' @param x An object of class \code{"meta3l_result"} or similar.
#' @param ... Additional arguments passed to the specific method.
#' @return A moderator result object (class depends on dispatch target).
#' @export
moderator <- function(x, ...) {
  UseMethod("moderator")
}


#' Fit a mixed-effects moderator model with categorical moderator
#'
#' Fits a three-level mixed-effects model using
#' \code{metafor::rma.mv(mods = ~factor(subgroup))} and returns both Wald-type
#' and likelihood-ratio tests for the moderator, together with per-subgroup
#' back-transformed pooled estimates.
#'
#' @param x An object of class \code{"meta3l_result"} as returned by
#'   \code{meta3L()}.
#' @param subgroup Character string; name of the column in \code{x$data} that
#'   contains the categorical moderator (subgroup labels).  Must be a
#'   \code{factor} or \code{character} column.  If the column is
#'   \code{numeric} or \code{integer}, an error is thrown with a message
#'   pointing to \code{bubble.meta3L()}.
#' @param ... Currently unused.
#'
#' @return An object of class \code{"moderator_result"}, a named list with:
#'   \describe{
#'     \item{model}{The \code{robust.rma} object from
#'       \code{metafor::robust(..., clubSandwich = TRUE)}.}
#'     \item{wald}{Named list with \code{QM} (Wald statistic), \code{QMp}
#'       (p-value), and \code{df} (degrees of freedom).}
#'     \item{lrt}{Named list with \code{statistic} (LRT chi-square),
#'       \code{pval} (p-value), and \code{df} (degrees of freedom).}
#'     \item{estimates}{Data frame with columns \code{level} (subgroup label),
#'       \code{k} (number of observations), \code{estimate} (back-transformed
#'       pooled estimate), \code{ci.lb}, and \code{ci.ub}.}
#'     \item{subgroup}{The \code{subgroup} argument as supplied.}
#'     \item{measure}{Effect size measure string from \code{x$measure}.}
#'     \item{transf}{Back-transformation function from \code{x$transf}.}
#'   }
#'
#' @method moderator meta3l_result
#' @export
#' @importFrom stats anova predict
moderator.meta3l_result <- function(x, subgroup, ...) {

  # --- 1. Validate subgroup column exists ------------------------------------
  if (!subgroup %in% names(x$data)) {
    stop(
      "Column '", subgroup, "' was not found in the data.",
      call. = FALSE
    )
  }

  # --- 2. Reject numeric/integer moderators ----------------------------------
  col_vals <- x$data[[subgroup]]
  if (is.numeric(col_vals) || is.integer(col_vals)) {
    stop(
      "Column '", subgroup, "' is numeric. ",
      "For continuous moderators, use bubble.meta3L() instead.",
      call. = FALSE
    )
  }

  # --- 3. Coerce to factor ---------------------------------------------------
  dat <- x$data
  dat[[subgroup]] <- factor(dat[[subgroup]])

  # --- 4. Warn for subgroup levels with only 1 observation ------------------
  lvl_counts <- table(dat[[subgroup]])
  single_obs <- names(lvl_counts)[lvl_counts == 1L]
  if (length(single_obs) > 0L) {
    warning(
      "Subgroup level(s) ",
      paste(paste0("'", single_obs, "'"), collapse = ", "),
      " have only 1 observation. ",
      "Estimates for these levels may be unreliable.",
      call. = FALSE
    )
  }

  # --- 5. Filter NA rows in yi/vi AND moderator column ----------------------
  na_mask <- is.na(dat$yi) | is.na(dat$vi) | is.na(dat[[subgroup]])
  n_drop <- sum(na_mask)
  if (n_drop > 0L) {
    warning(
      n_drop, " row(s) with NA values in yi, vi, or '", subgroup,
      "' were removed before analysis.",
      call. = FALSE
    )
    dat <- dat[!na_mask, , drop = FALSE]
  }

  # Re-subset V to matching rows
  keep_idx <- which(!na_mask)
  V_sub <- x$V[keep_idx, keep_idx, drop = FALSE]

  # --- 6. Build random formula -----------------------------------------------
  random_formula <- stats::as.formula(
    paste0("~ 1 | ", x$cluster, " / TE_id")
  )

  # --- 7. Fit null model (REML) for Wald test --------------------------------
  fit_null <- tryCatch(
    metafor::rma.mv(yi, V_sub, random = random_formula, data = dat),
    error = function(e) {
      if (grepl("convergence", conditionMessage(e), ignore.case = TRUE)) {
        metafor::rma.mv(yi, V_sub, random = random_formula, data = dat,
                        control = list(optimizer = "bobyqa"))
      } else {
        stop(e)
      }
    }
  )

  # --- 8. Fit full model (REML) for Wald test --------------------------------
  mods_formula <- stats::as.formula(
    paste0("~ factor(", subgroup, ")")
  )
  fit_full <- tryCatch(
    metafor::rma.mv(yi, V_sub, mods = mods_formula,
                    random = random_formula, data = dat),
    error = function(e) {
      if (grepl("convergence", conditionMessage(e), ignore.case = TRUE)) {
        metafor::rma.mv(yi, V_sub, mods = mods_formula,
                        random = random_formula, data = dat,
                        control = list(optimizer = "bobyqa"))
      } else {
        stop(e)
      }
    }
  )

  # --- 9. Apply robust variance estimation (CR2) ----------------------------
  fit_rob <- metafor::robust(fit_full,
                             cluster      = dat[[x$cluster]],
                             clubSandwich = TRUE)

  # --- 10. Extract Wald test -------------------------------------------------
  wald <- list(
    QM  = fit_rob$QM,
    QMp = fit_rob$QMp,
    df  = fit_rob$m
  )

  # --- 11. Compute LRT using ML-fitted models --------------------------------
  # LRT requires ML (not REML) for valid comparison across different fixed effects.
  lrt <- tryCatch({
    fit_null_ml <- tryCatch(
      metafor::rma.mv(yi, V_sub, random = random_formula, method = "ML", data = dat),
      error = function(e) {
        if (grepl("convergence", conditionMessage(e), ignore.case = TRUE)) {
          metafor::rma.mv(yi, V_sub, random = random_formula, method = "ML", data = dat,
                          control = list(optimizer = "bobyqa"))
        } else {
          stop(e)
        }
      }
    )
    fit_full_ml <- tryCatch(
      metafor::rma.mv(yi, V_sub, mods = mods_formula,
                      random = random_formula, method = "ML", data = dat),
      error = function(e) {
        if (grepl("convergence", conditionMessage(e), ignore.case = TRUE)) {
          metafor::rma.mv(yi, V_sub, mods = mods_formula,
                          random = random_formula, method = "ML", data = dat,
                          control = list(optimizer = "bobyqa"))
        } else {
          stop(e)
        }
      }
    )
    lrt_raw <- stats::anova(fit_full_ml, fit_null_ml)
    list(
      statistic = lrt_raw$LRT,
      pval      = lrt_raw$pval,
      df        = lrt_raw$parms.f - lrt_raw$parms.r
    )
  }, error = function(e) {
    warning(
      "LRT could not be computed (ML model convergence failed): ",
      conditionMessage(e),
      call. = FALSE
    )
    list(statistic = NA_real_, pval = NA_real_, df = NA_real_)
  })

  # --- 12. Compute per-subgroup estimates ------------------------------------
  levels_sg  <- levels(dat[[subgroup]])
  n_levels   <- length(levels_sg)
  # Reference level is levels_sg[1]; additional levels are contrasts
  # newmods: one row per level, one column per contrast coefficient
  # For reference level: all zeros
  # For level j (j >= 2): 1 in column j-1, 0 elsewhere
  n_contrasts <- n_levels - 1L
  estimates_list <- vector("list", n_levels)

  for (j in seq_len(n_levels)) {
    if (n_contrasts > 0L) {
      newmods_row <- matrix(0, nrow = 1L, ncol = n_contrasts)
      if (j > 1L) {
        newmods_row[1L, j - 1L] <- 1L
      }
    } else {
      newmods_row <- NULL
    }

    pred_j <- metafor::predict.rma(fit_full, newmods = newmods_row)
    k_j <- sum(dat[[subgroup]] == levels_sg[[j]])

    estimates_list[[j]] <- list(
      level    = levels_sg[[j]],
      k        = k_j,
      estimate = x$transf(pred_j$pred),
      ci.lb    = x$transf(pred_j$ci.lb),
      ci.ub    = x$transf(pred_j$ci.ub)
    )
  }

  estimates_df <- do.call(rbind, lapply(estimates_list, function(e) {
    data.frame(
      level    = e$level,
      k        = e$k,
      estimate = e$estimate,
      ci.lb    = e$ci.lb,
      ci.ub    = e$ci.ub,
      stringsAsFactors = FALSE
    )
  }))

  # --- 13. Return S3 result object -------------------------------------------
  structure(
    list(
      model     = fit_rob,
      wald      = wald,
      lrt       = lrt,
      estimates = estimates_df,
      subgroup  = subgroup,
      measure   = x$measure,
      transf    = x$transf
    ),
    class = "moderator_result"
  )
}

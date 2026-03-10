#' Fit a three-level random-effects meta-analysis model
#'
#' Wraps \code{metafor::escalc}, \code{metafor::vcalc}, \code{metafor::rma.mv},
#' \code{metafor::robust}, and multilevel I-squared computation into a single
#' function call.  Returns an S3 object of class \code{meta3l_result} that
#' contains the fitted model, heterogeneity statistics, and back-transformed
#' pooled estimate.
#'
#' @param data A data frame containing the raw study data.
#' @param slab Character string naming the column in \code{data} that holds
#'   study labels (used as the \code{slab} argument to \code{escalc} and as
#'   the cluster column by default).
#' @param measure Character string specifying the effect size measure.  One of
#'   \code{"PLO"} (logit-transformed proportion), \code{"PAS"}
#'   (arcsine-transformed proportion), \code{"SMD"} (standardised mean
#'   difference), \code{"MD"} (raw mean difference), \code{"RR"} (log risk
#'   ratio), or \code{"OR"} (log odds ratio).
#' @param cluster Character string naming the column in \code{data} that
#'   identifies study clusters (level 3).  Defaults to \code{"studlab"}.
#' @param rho Numeric scalar; assumed within-cluster correlation used by
#'   \code{metafor::vcalc}.  Defaults to \code{0.5}.
#' @param transf Optional function to back-transform the pooled estimate and
#'   confidence limits.  If \code{NULL} (default), the transformation is
#'   resolved automatically from \code{measure}.
#' @param xi Character string; column name for the numerator count (events).
#'   Required for \code{measure = "PLO"} and \code{measure = "PAS"}.
#' @param ni Character string; column name for the total count (sample size).
#'   Required for \code{measure = "PLO"} and \code{measure = "PAS"}.
#' @param ai Character string; column name for events in group 1 (2x2 table).
#'   Required for \code{measure = "RR"} and \code{measure = "OR"}.
#' @param bi Character string; column name for non-events in group 1.
#'   Required for \code{measure = "RR"} and \code{measure = "OR"}.
#' @param ci Character string; column name for events in group 2.
#'   Required for \code{measure = "RR"} and \code{measure = "OR"}.
#' @param di Character string; column name for non-events in group 2.
#'   Required for \code{measure = "RR"} and \code{measure = "OR"}.
#' @param n1i Character string; column name for sample size in group 1.
#'   Required for \code{measure = "SMD"} and \code{measure = "MD"}.
#' @param n2i Character string; column name for sample size in group 2.
#'   Required for \code{measure = "SMD"} and \code{measure = "MD"}.
#' @param m1i Character string; column name for mean in group 1.
#'   Required for \code{measure = "SMD"} and \code{measure = "MD"}.
#' @param sd1i Character string; column name for standard deviation in group 1.
#'   Required for \code{measure = "SMD"} and \code{measure = "MD"}.
#' @param m2i Character string; column name for mean in group 2.
#'   Required for \code{measure = "SMD"} and \code{measure = "MD"}.
#' @param sd2i Character string; column name for standard deviation in group 2.
#'   Required for \code{measure = "SMD"} and \code{measure = "MD"}.
#' @param mi Character string; column name for a single-group mean.
#'   Currently reserved for future use.
#' @param sdi Character string; column name for a single-group standard
#'   deviation.  Currently reserved for future use.
#'
#' @return An object of class \code{"meta3l_result"}, a named list with the
#'   following components:
#'   \describe{
#'     \item{model}{The \code{robust.rma} object from
#'       \code{metafor::robust(..., clubSandwich = TRUE)}.}
#'     \item{data}{The escalc-enriched data frame (\code{yi}, \code{vi}, and
#'       \code{TE_id} columns added).}
#'     \item{V}{Variance-covariance matrix from \code{metafor::vcalc}.}
#'     \item{i2}{Named list with elements \code{total}, \code{between}, and
#'       \code{within} (percentages).}
#'     \item{transf}{Resolved back-transformation function.}
#'     \item{measure}{The \code{measure} argument as supplied.}
#'     \item{cluster}{The \code{cluster} argument as supplied.}
#'     \item{rho}{The \code{rho} argument as supplied.}
#'     \item{slab}{The \code{slab} argument as supplied.}
#'     \item{TE_id}{The string \code{"TE_id"}.}
#'     \item{estimate}{Back-transformed pooled estimate (numeric scalar).}
#'     \item{ci.lb}{Back-transformed lower 95\% confidence limit.}
#'     \item{ci.ub}{Back-transformed upper 95\% confidence limit.}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' d <- data.frame(
#'   author  = rep(c("Smith", "Jones"), each = 3),
#'   year    = rep(c(2020, 2021), each = 3),
#'   studlab = rep(c("Smith, 2020", "Jones, 2021"), each = 3),
#'   xi      = c(10, 12, 8, 15, 11, 9),
#'   ni      = c(50, 55, 48, 60, 52, 47)
#' )
#' r <- meta3L(d, slab = "studlab", xi = "xi", ni = "ni", measure = "PLO")
#' print(r)
#' }
meta3L <- function(data,
                   slab,
                   measure,
                   cluster  = "studlab",
                   rho      = 0.5,
                   transf   = NULL,
                   xi       = NULL,
                   ni       = NULL,
                   ai       = NULL,
                   bi       = NULL,
                   ci       = NULL,
                   di       = NULL,
                   n1i      = NULL,
                   n2i      = NULL,
                   m1i      = NULL,
                   sd1i     = NULL,
                   m2i      = NULL,
                   sd2i     = NULL,
                   mi       = NULL,
                   sdi      = NULL) {

  # --- 1. Resolve back-transform early (also validates measure) ---------------
  transf_fn <- resolve_transf(measure, transf)

  # --- 2. Build col_args: named list of user-supplied column name strings ------
  col_args <- list()
  if (!is.null(xi))   col_args[["xi"]]   <- xi
  if (!is.null(ni))   col_args[["ni"]]   <- ni
  if (!is.null(ai))   col_args[["ai"]]   <- ai
  if (!is.null(bi))   col_args[["bi"]]   <- bi
  if (!is.null(ci))   col_args[["ci"]]   <- ci
  if (!is.null(di))   col_args[["di"]]   <- di
  if (!is.null(n1i))  col_args[["n1i"]]  <- n1i
  if (!is.null(n2i))  col_args[["n2i"]]  <- n2i
  if (!is.null(m1i))  col_args[["m1i"]]  <- m1i
  if (!is.null(sd1i)) col_args[["sd1i"]] <- sd1i
  if (!is.null(m2i))  col_args[["m2i"]]  <- m2i
  if (!is.null(sd2i)) col_args[["sd2i"]] <- sd2i
  if (!is.null(mi))   col_args[["mi"]]   <- mi
  if (!is.null(sdi))  col_args[["sdi"]]  <- sdi

  # --- 3. Validate columns ----------------------------------------------------
  validate_columns(data, measure, col_args, slab, cluster)

  # --- 4. Filter NA rows in required data columns ----------------------------
  required <- REQUIRED_COLS[[measure]]
  # Map required escalc arg names to user-supplied column names
  user_cols <- vapply(required, function(arg) col_args[[arg]], character(1L))

  # Find rows with any NA in the required columns
  has_na <- Reduce("|", lapply(user_cols, function(col) is.na(data[[col]])))
  n_drop <- sum(has_na)
  if (n_drop > 0L) {
    warning(
      n_drop, " row(s) with NA values in required columns (",
      paste(user_cols, collapse = ", "), ") were removed before analysis.",
      call. = FALSE
    )
    data <- data[!has_na, , drop = FALSE]
  }

  # --- 5. Rename user columns to canonical escalc argument names --------------
  # Work on a copy so we don't mutate the caller's data
  dat <- data
  for (arg_name in names(col_args)) {
    user_col <- col_args[[arg_name]]
    # Only rename if the user name differs from the canonical name
    if (!identical(user_col, arg_name)) {
      dat[[arg_name]] <- dat[[user_col]]
    }
  }

  # --- 6. Call escalc via do.call with canonical column names -----------------
  escalc_args <- list(
    measure = measure,
    data    = dat,
    slab    = dat[[slab]]
  )
  # Add measure-specific canonical column name args
  for (arg_name in required) {
    escalc_args[[arg_name]] <- dat[[arg_name]]
  }

  dat <- do.call(metafor::escalc, escalc_args)
  dat$TE_id <- seq_len(nrow(dat))

  # --- 7. Build variance-covariance matrix -----------------------------------
  V <- metafor::vcalc(
    vi      = dat$vi,
    cluster = dat[[cluster]],
    obs     = dat$TE_id,
    rho     = rho,
    data    = dat
  )

  # --- 8. Build dynamic random formula ----------------------------------------
  random_formula <- stats::as.formula(paste0("~ 1 | ", cluster, " / TE_id"))

  # --- 9. Fit three-level model -----------------------------------------------
  res <- metafor::rma.mv(yi, V,
                         random = random_formula,
                         data   = dat)

  # --- 10. Robust variance estimation (CR2) -----------------------------------
  res_robust <- metafor::robust(res,
                                cluster       = dat[[cluster]],
                                clubSandwich  = TRUE)

  # --- 11. I-squared via P-matrix projection ----------------------------------
  i2 <- compute_i2(res, V)

  # --- 12. Back-transform pooled estimate and CI from robust model ------------
  estimate <- transf_fn(res_robust$b[[1L]])
  ci_lb    <- transf_fn(res_robust$ci.lb)
  ci_ub    <- transf_fn(res_robust$ci.ub)

  # --- 13. Construct S3 result object -----------------------------------------
  structure(
    list(
      model    = res_robust,
      data     = dat,
      V        = V,
      i2       = i2,
      transf   = transf_fn,
      measure  = measure,
      cluster  = cluster,
      rho      = rho,
      slab     = slab,
      TE_id    = "TE_id",
      estimate = estimate,
      ci.lb    = ci_lb,
      ci.ub    = ci_ub
    ),
    class = "meta3l_result"
  )
}

# Internal helper utilities for meta3l
# None of these functions are exported.

# Supported measure → required escalc column names
REQUIRED_COLS <- list(
  PLO = c("xi", "ni"),
  PAS = c("xi", "ni"),
  SMD = c("m1i", "sd1i", "n1i", "m2i", "sd2i", "n2i"),
  MD  = c("m1i", "sd1i", "n1i", "m2i", "sd2i", "n2i"),
  RR  = c("ai", "bi", "ci", "di"),
  OR  = c("ai", "bi", "ci", "di")
)


#' Resolve the back-transformation function for a given effect size measure
#'
#' @param measure Character string; one of PLO, PAS, RR, OR, SMD, MD.
#' @param user_transf Optional function. If supplied, it is returned as-is,
#'   ignoring \code{measure}.
#' @return A function suitable for back-transforming effect size estimates.
#' @keywords internal
resolve_transf <- function(measure, user_transf = NULL) {
  if (!is.null(user_transf)) {
    return(user_transf)
  }

  switch(measure,
    PLO = metafor::transf.ilogit,
    PAS = metafor::transf.iarcsin,
    RR  = exp,
    OR  = exp,
    SMD = identity,
    MD  = identity,
    stop(
      "measure '", measure, "' is not supported. ",
      "Use PLO, PAS, SMD, MD, RR, or OR.",
      call. = FALSE
    )
  )
}


#' Validate that required columns exist in the data for a given measure
#'
#' Checks that every required escalc column, plus the \code{slab} and
#' \code{cluster} columns, are present in \code{data}. Raises an informative
#' error if any column is missing.
#'
#' @param data A data frame.
#' @param measure Character string; one of PLO, PAS, RR, OR, SMD, MD.
#' @param col_args Named list mapping canonical argument names (e.g. "xi",
#'   "ni") to user-supplied column name strings.
#' @param slab Character string; column name used as study label.
#' @param cluster Character string; column name used as cluster identifier.
#' @return Invisibly \code{NULL} on success; errors on failure.
#' @keywords internal
validate_columns <- function(data, measure, col_args, slab, cluster) {
  if (!measure %in% names(REQUIRED_COLS)) {
    stop(
      "measure '", measure, "' is not recognised. ",
      "Supported measures: ", paste(names(REQUIRED_COLS), collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  required <- REQUIRED_COLS[[measure]]

  # Sentinel values used by meta3L() for internally-derived columns (e.g. bi, di
  # computed from n.e - event.e).  These do not need to exist in the data yet.
  derived_sentinels <- c("bi", "di")

  for (arg_name in required) {
    # Skip validation for columns that are derived internally from other cols
    if (arg_name %in% derived_sentinels) {
      col_name <- col_args[[arg_name]]
      # If the column name equals the arg_name sentinel or is NULL, skip check
      if (is.null(col_name) || col_name == arg_name) next
    }
    col_name <- col_args[[arg_name]]
    if (is.null(col_name) || !col_name %in% names(data)) {
      stop(
        "Column '", if (is.null(col_name)) arg_name else col_name,
        "' required for measure '", measure, "' was not found in data.",
        call. = FALSE
      )
    }
  }

  if (!slab %in% names(data)) {
    stop(
      "Study label column '", slab, "' was not found in data.",
      call. = FALSE
    )
  }

  if (!cluster %in% names(data)) {
    stop(
      "Cluster column '", cluster, "' was not found in data.",
      call. = FALSE
    )
  }

  invisible(NULL)
}


#' Compute multilevel I-squared via P-matrix projection
#'
#' Uses the precision-matrix (P-matrix) method from the metafor documentation
#' (\url{https://www.metafor-project.org/doku.php/tips:i2_multilevel_multivariate})
#' to decompose I-squared into between-study and within-study components.
#'
#' @param fit An \code{rma.mv} object returned by \code{metafor::rma.mv()}.
#' @param V The variance-covariance matrix passed to \code{rma.mv()} (the
#'   output of \code{metafor::vcalc()}). Must be non-singular.
#' @return A named list with elements \code{total}, \code{between}, and
#'   \code{within}, each a numeric percentage (0-100).
#' @keywords internal
compute_i2 <- function(fit, V) {
  W <- solve(V)
  X <- model.matrix(fit)
  P <- W - W %*% X %*% solve(t(X) %*% W %*% X) %*% t(X) %*% W
  denom <- sum(fit$sigma2) + (fit$k - fit$p) / sum(diag(P))

  list(
    total   = 100 * sum(fit$sigma2) / denom,
    between = 100 * fit$sigma2[1L] / denom,
    within  = 100 * fit$sigma2[2L] / denom
  )
}

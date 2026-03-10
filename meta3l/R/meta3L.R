#' Fit a three-level random-effects meta-analysis model
#'
#' Wraps \code{metafor::escalc}, \code{metafor::vcalc}, \code{metafor::rma.mv},
#' \code{metafor::robust}, and multilevel I-squared computation into a single
#' function call.  Returns an S3 object of class \code{meta3l_result} that
#' contains the fitted model, heterogeneity statistics, and back-transformed
#' pooled estimate.
#'
#' @section Column name conventions:
#' \code{meta3L()} accepts two column naming styles:
#'
#' \strong{Meta-style names} (preferred):
#' \itemize{
#'   \item PLO/PAS: \code{event}, \code{n}
#'   \item RR/OR: \code{event.e}, \code{n.e}, \code{event.c}, \code{n.c}
#'   \item SMD/MD: \code{mean.e}, \code{sd.e}, \code{n.e}, \code{mean.c}, \code{sd.c}, \code{n.c}
#' }
#'
#' \strong{Escalc-style names} (backward compatible, deprecated):
#' \itemize{
#'   \item PLO/PAS: \code{xi}, \code{ni}
#'   \item RR/OR: \code{ai}, \code{bi}, \code{ci}, \code{di}
#'   \item SMD/MD: \code{m1i}, \code{sd1i}, \code{n1i}, \code{m2i}, \code{sd2i}, \code{n2i}
#' }
#'
#' \strong{Auto-detection}: If no column arguments are supplied, \code{meta3L()}
#' will check whether the data frame already contains the standard meta-style
#' column names for the requested \code{measure} and use them automatically.
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
#' @param event Character string; column name for the event count (single
#'   group).  Required for \code{measure = "PLO"} and \code{measure = "PAS"}
#'   when using meta-style column names.
#' @param n Character string; column name for the total count / sample size
#'   (single group).  Required for \code{measure = "PLO"} and
#'   \code{measure = "PAS"} when using meta-style column names.
#' @param event.e Character string; column name for events in the experimental
#'   group.  Required for \code{measure = "RR"} and \code{measure = "OR"}
#'   when using meta-style column names.
#' @param n.e Character string; column name for the total in the experimental
#'   group.  Required for \code{measure = "RR"} and \code{measure = "OR"}
#'   when using meta-style column names.
#' @param event.c Character string; column name for events in the control
#'   group.  Required for \code{measure = "RR"} and \code{measure = "OR"}
#'   when using meta-style column names.
#' @param n.c Character string; column name for the total in the control
#'   group.  Required for \code{measure = "RR"} and \code{measure = "OR"}
#'   when using meta-style column names.
#' @param mean.e Character string; column name for the mean in the experimental
#'   group.  Required for \code{measure = "SMD"} and \code{measure = "MD"}
#'   when using meta-style column names.
#' @param sd.e Character string; column name for the standard deviation in the
#'   experimental group.  Required for \code{measure = "SMD"} and
#'   \code{measure = "MD"} when using meta-style column names.
#' @param mean.c Character string; column name for the mean in the control
#'   group.  Required for \code{measure = "SMD"} and \code{measure = "MD"}
#'   when using meta-style column names.
#' @param sd.c Character string; column name for the standard deviation in the
#'   control group.  Required for \code{measure = "SMD"} and
#'   \code{measure = "MD"} when using meta-style column names.
#' @param xi Character string; column name for the numerator count (events).
#'   Deprecated; use \code{event} instead.  For \code{measure = "PLO"} and
#'   \code{measure = "PAS"}.
#' @param ni Character string; column name for the total count (sample size).
#'   Deprecated; use \code{n} instead.  For \code{measure = "PLO"} and
#'   \code{measure = "PAS"}.
#' @param ai Character string; column name for events in group 1 (2x2 table).
#'   Deprecated; use \code{event.e} instead.  For \code{measure = "RR"} and
#'   \code{measure = "OR"}.
#' @param bi Character string; column name for non-events in group 1.
#'   Deprecated; use \code{event.e} + \code{n.e} instead (computed internally).
#'   For \code{measure = "RR"} and \code{measure = "OR"}.
#' @param ci Character string; column name for events in group 2.
#'   Deprecated; use \code{event.c} instead.  For \code{measure = "RR"} and
#'   \code{measure = "OR"}.
#' @param di Character string; column name for non-events in group 2.
#'   Deprecated; use \code{event.c} + \code{n.c} instead (computed internally).
#'   For \code{measure = "RR"} and \code{measure = "OR"}.
#' @param n1i Character string; column name for sample size in group 1.
#'   Deprecated; use \code{n.e} instead.  For \code{measure = "SMD"} and
#'   \code{measure = "MD"}.
#' @param n2i Character string; column name for sample size in group 2.
#'   Deprecated; use \code{n.c} instead.  For \code{measure = "SMD"} and
#'   \code{measure = "MD"}.
#' @param m1i Character string; column name for mean in group 1.
#'   Deprecated; use \code{mean.e} instead.  For \code{measure = "SMD"} and
#'   \code{measure = "MD"}.
#' @param sd1i Character string; column name for standard deviation in group 1.
#'   Deprecated; use \code{sd.e} instead.  For \code{measure = "SMD"} and
#'   \code{measure = "MD"}.
#' @param m2i Character string; column name for mean in group 2.
#'   Deprecated; use \code{mean.c} instead.  For \code{measure = "SMD"} and
#'   \code{measure = "MD"}.
#' @param sd2i Character string; column name for standard deviation in group 2.
#'   Deprecated; use \code{sd.c} instead.  For \code{measure = "SMD"} and
#'   \code{measure = "MD"}.
#' @param mi Character string; column name for a single-group mean.
#'   Currently reserved for future use.
#' @param sdi Character string; column name for a single-group standard
#'   deviation.  Currently reserved for future use.
#' @param name Character string; optional name for the analysis (e.g., the
#'   Excel sheet name). Used by \code{forest.meta3L()} for default output
#'   filenames. Defaults to \code{NULL}.
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
#'     \item{name}{The \code{name} argument as supplied (or \code{NULL}).}
#'   }
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Meta-style column names (preferred)
#' d <- data.frame(
#'   studlab = rep(c("Smith, 2020", "Jones, 2021"), each = 3),
#'   event   = c(10, 12, 8, 15, 11, 9),
#'   n       = c(50, 55, 48, 60, 52, 47)
#' )
#' r <- meta3L(d, slab = "studlab", event = "event", n = "n", measure = "PLO")
#'
#' # Auto-detection (data already has standard meta-style column names)
#' r2 <- meta3L(d, slab = "studlab", measure = "PLO")
#'
#' # Escalc-style column names (backward compatible)
#' d2 <- data.frame(
#'   studlab = rep(c("Smith, 2020", "Jones, 2021"), each = 3),
#'   xi      = c(10, 12, 8, 15, 11, 9),
#'   ni      = c(50, 55, 48, 60, 52, 47)
#' )
#' r3 <- meta3L(d2, slab = "studlab", xi = "xi", ni = "ni", measure = "PLO")
#' }

# Internal mapping from meta-style argument names to escalc canonical names
# Used for auto-detection and meta-style API translation
META_COL_MAP <- list(
  PLO = list(xi = "event", ni = "n"),
  PAS = list(xi = "event", ni = "n"),
  RR  = list(ai = "event.e", n1i = "n.e", ci = "event.c", n2i = "n.c"),
  OR  = list(ai = "event.e", n1i = "n.e", ci = "event.c", n2i = "n.c"),
  SMD = list(m1i = "mean.e", sd1i = "sd.e", n1i = "n.e",
             m2i = "mean.c", sd2i = "sd.c", n2i = "n.c"),
  MD  = list(m1i = "mean.e", sd1i = "sd.e", n1i = "n.e",
             m2i = "mean.c", sd2i = "sd.c", n2i = "n.c")
)

meta3L <- function(data,
                   slab,
                   measure,
                   cluster  = "studlab",
                   rho      = 0.5,
                   transf   = NULL,
                   # --- Meta-style column names (preferred) ---
                   event    = NULL,
                   n        = NULL,
                   event.e  = NULL,
                   n.e      = NULL,
                   event.c  = NULL,
                   n.c      = NULL,
                   mean.e   = NULL,
                   sd.e     = NULL,
                   mean.c   = NULL,
                   sd.c     = NULL,
                   # --- Escalc-style column names (backward compatible) ---
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
                   sdi      = NULL,
                   name     = NULL) {

  # --- 1. Resolve back-transform early (also validates measure) ---------------
  transf_fn <- resolve_transf(measure, transf)

  # --- 2. Build col_args: named list mapping escalc canonical names to data
  #        column name strings. Priority order:
  #        (a) meta-style args  -> translate to escalc names
  #        (b) escalc-style args -> use directly
  #        (c) auto-detect from data column names

  col_args <- list()

  # (a) Meta-style args: translate meta-style parameter names to escalc names
  meta_map <- META_COL_MAP[[measure]]

  # PLO/PAS: event -> xi, n -> ni
  if (!is.null(event)) col_args[["xi"]] <- event
  if (!is.null(n))     col_args[["ni"]] <- n

  # RR/OR: event.e -> ai (n.e will compute bi = n.e - event.e later),
  #         event.c -> ci (n.c will compute di = n.c - event.c later)
  # We store meta-style n.e / n.c for the bi/di computation step
  meta_n_e_col   <- n.e
  meta_n_c_col   <- n.c
  meta_event_e   <- event.e
  meta_event_c   <- event.c

  if (!is.null(event.e)) col_args[["ai"]]  <- event.e
  if (!is.null(event.c)) col_args[["ci"]]  <- event.c
  # n.e / n.c are used only to derive bi / di — do NOT add to col_args as n1i/n2i for RR/OR
  # because escalc for RR/OR requires ai, bi, ci, di (not n1i/n2i)

  # SMD/MD: mean.e -> m1i, sd.e -> sd1i, n.e -> n1i, mean.c -> m2i, etc.
  if (measure %in% c("SMD", "MD")) {
    if (!is.null(mean.e)) col_args[["m1i"]]  <- mean.e
    if (!is.null(sd.e))   col_args[["sd1i"]] <- sd.e
    if (!is.null(n.e))    col_args[["n1i"]]  <- n.e
    if (!is.null(mean.c)) col_args[["m2i"]]  <- mean.c
    if (!is.null(sd.c))   col_args[["sd2i"]] <- sd.c
    if (!is.null(n.c))    col_args[["n2i"]]  <- n.c
  }

  # (b) Escalc-style args: only fill in if meta-style did not already set them
  if (!is.null(xi)   && is.null(col_args[["xi"]]))   col_args[["xi"]]   <- xi
  if (!is.null(ni)   && is.null(col_args[["ni"]]))   col_args[["ni"]]   <- ni
  if (!is.null(ai)   && is.null(col_args[["ai"]]))   col_args[["ai"]]   <- ai
  if (!is.null(bi)   && is.null(col_args[["bi"]]))   col_args[["bi"]]   <- bi
  if (!is.null(ci)   && is.null(col_args[["ci"]]))   col_args[["ci"]]   <- ci
  if (!is.null(di)   && is.null(col_args[["di"]]))   col_args[["di"]]   <- di
  if (!is.null(n1i)  && is.null(col_args[["n1i"]]))  col_args[["n1i"]]  <- n1i
  if (!is.null(n2i)  && is.null(col_args[["n2i"]]))  col_args[["n2i"]]  <- n2i
  if (!is.null(m1i)  && is.null(col_args[["m1i"]]))  col_args[["m1i"]]  <- m1i
  if (!is.null(sd1i) && is.null(col_args[["sd1i"]])) col_args[["sd1i"]] <- sd1i
  if (!is.null(m2i)  && is.null(col_args[["m2i"]]))  col_args[["m2i"]]  <- m2i
  if (!is.null(sd2i) && is.null(col_args[["sd2i"]])) col_args[["sd2i"]] <- sd2i
  if (!is.null(mi))   col_args[["mi"]]  <- mi
  if (!is.null(sdi))  col_args[["sdi"]] <- sdi

  # (c) Auto-detection: if no column args supplied at all, check if data has
  #     standard meta-style column names for the requested measure
  if (length(col_args) == 0L) {
    meta_map_m <- META_COL_MAP[[measure]]
    # Check whether all meta-style columns exist in data
    meta_cols  <- unlist(meta_map_m, use.names = FALSE)
    if (all(meta_cols %in% names(data))) {
      # Translate meta-style names to escalc canonical names
      for (escalc_name in names(meta_map_m)) {
        meta_col <- meta_map_m[[escalc_name]]
        # For RR/OR n.e and n.c: store separately for bi/di computation
        if (measure %in% c("RR", "OR") && escalc_name %in% c("n1i", "n2i")) {
          if (escalc_name == "n1i") meta_n_e_col <- meta_col
          if (escalc_name == "n2i") meta_n_c_col <- meta_col
          # Do NOT add n1i/n2i to col_args for RR/OR — escalc needs bi/di
        } else {
          col_args[[escalc_name]] <- meta_col
        }
        # Track event.e and event.c column names for bi/di derivation
        if (measure %in% c("RR", "OR") && escalc_name == "ai") meta_event_e <- meta_col
        if (measure %in% c("RR", "OR") && escalc_name == "ci") meta_event_c <- meta_col
      }
    }
  }

  # --- 3. For RR/OR: if we have meta-style n.e/n.c + event.e/event.c but no bi/di,
  #        compute bi = n.e - event.e and di = n.c - event.c as new data columns ---
  if (measure %in% c("RR", "OR")) {
    has_meta_totals <- (!is.null(meta_n_e_col) && !is.null(meta_n_c_col) &&
                        !is.null(meta_event_e) && !is.null(meta_event_c))
    needs_bi <- is.null(col_args[["bi"]])
    needs_di <- is.null(col_args[["di"]])

    if (has_meta_totals && (needs_bi || needs_di)) {
      # Compute derived columns in a copy of data (we will work on dat below)
      # For now, flag that we need to do this after filtering
      # We'll use sentinel names __bi_derived__ and __di_derived__
      if (needs_bi) col_args[["bi"]] <- ".meta3l_bi_derived"
      if (needs_di) col_args[["di"]] <- ".meta3l_di_derived"
    }
  }

  # --- 4. Validate columns ----------------------------------------------------
  # Skip validation of derived sentinel columns (they don't exist in data yet)
  col_args_for_validation <- col_args
  sentinel_cols <- c(".meta3l_bi_derived", ".meta3l_di_derived")
  for (s in sentinel_cols) {
    sentinel_key <- names(col_args_for_validation)[col_args_for_validation == s]
    if (length(sentinel_key) > 0L) {
      col_args_for_validation[[sentinel_key]] <- sentinel_key
    }
  }
  validate_columns(data, measure, col_args_for_validation, slab, cluster)

  # --- 5. Filter NA rows in required data columns ----------------------------
  required <- REQUIRED_COLS[[measure]]
  # Map required escalc arg names to user-supplied column names, skip sentinels
  user_cols <- character(0L)
  for (arg in required) {
    col <- col_args[[arg]]
    if (!is.null(col) && !col %in% sentinel_cols) {
      user_cols <- c(user_cols, col)
    }
  }
  # Also include source columns for derived bi/di
  if (measure %in% c("RR", "OR")) {
    if (!is.null(meta_n_e_col)) user_cols <- c(user_cols, meta_n_e_col)
    if (!is.null(meta_n_c_col)) user_cols <- c(user_cols, meta_n_c_col)
  }
  user_cols <- unique(user_cols)

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

  # --- 6. Rename user columns to canonical escalc argument names --------------
  # Work on a copy so we don't mutate the caller's data
  dat <- data

  # Compute derived bi/di columns if needed
  if (measure %in% c("RR", "OR")) {
    if (".meta3l_bi_derived" %in% unlist(col_args, use.names = FALSE)) {
      dat[[".meta3l_bi_derived"]] <- dat[[meta_n_e_col]] - dat[[meta_event_e]]
    }
    if (".meta3l_di_derived" %in% unlist(col_args, use.names = FALSE)) {
      dat[[".meta3l_di_derived"]] <- dat[[meta_n_c_col]] - dat[[meta_event_c]]
    }
  }

  for (arg_name in names(col_args)) {
    user_col <- col_args[[arg_name]]
    # Only rename if the user name differs from the canonical name
    if (!identical(user_col, arg_name)) {
      dat[[arg_name]] <- dat[[user_col]]
    }
  }

  # --- 7. Call escalc via do.call with canonical column names -----------------
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

  # --- 8. Build variance-covariance matrix -----------------------------------
  V <- metafor::vcalc(
    vi      = dat$vi,
    cluster = dat[[cluster]],
    obs     = dat$TE_id,
    rho     = rho,
    data    = dat
  )

  # --- 9. Build dynamic random formula ----------------------------------------
  random_formula <- stats::as.formula(paste0("~ 1 | ", cluster, " / TE_id"))

  # --- 10. Fit three-level model -----------------------------------------------
  res <- metafor::rma.mv(yi, V,
                         random = random_formula,
                         data   = dat)

  # --- 11. Robust variance estimation (CR2) -----------------------------------
  res_robust <- metafor::robust(res,
                                cluster       = dat[[cluster]],
                                clubSandwich  = TRUE)

  # --- 12. I-squared via P-matrix projection ----------------------------------
  i2 <- compute_i2(res, V)

  # --- 13. Back-transform pooled estimate and CI from robust model ------------
  estimate <- transf_fn(res_robust$b[[1L]])
  ci_lb    <- transf_fn(res_robust$ci.lb)
  ci_ub    <- transf_fn(res_robust$ci.ub)

  # --- 14. Construct S3 result object -----------------------------------------
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
      ci.ub    = ci_ub,
      name     = name
    ),
    class = "meta3l_result"
  )
}

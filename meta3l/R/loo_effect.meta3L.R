# loo_effect.meta3L.R — Effect-level leave-one-out sensitivity analysis
# Drops each effect size row, refits, and returns influence table + plot.

#' Effect-level leave-one-out sensitivity analysis (generic)
#'
#' @param x An S3 object to dispatch on.
#' @param ... Additional arguments passed to methods.
#' @return A named list; see \code{\link{loo_effect.meta3l_result}}.
#' @export
loo_effect <- function(x, ...) UseMethod("loo_effect")

#' Effect-level leave-one-out sensitivity analysis for meta3l_result objects
#'
#' Drops each effect size row in turn, refits the three-level model on the
#' remaining data, and returns a table showing how the pooled estimate and
#' heterogeneity statistics change.  Also produces a grid-based influence plot.
#'
#' @param x     A \code{meta3l_result} object returned by \code{\link{meta3L}}.
#' @param file  One of: \code{character(0)} (default, auto-name from
#'   \code{x$name} and \code{meta3l.mwd} option); \code{NULL} (display only,
#'   returns \code{NULL} for \code{plot_file}); or a character string (explicit
#'   file path).
#' @param format Character string; output format — \code{"png"} (default) or
#'   \code{"pdf"}.
#' @param width  Integer or NULL; output width in pixels.  \code{NULL}
#'   auto-computes via \code{auto_dims()}.
#' @param height Integer or NULL; output height in pixels.  \code{NULL}
#'   auto-computes.
#' @param ... Currently ignored.
#'
#' @return Invisibly returns a named list with:
#'   \describe{
#'     \item{table}{A data frame with columns \code{omitted}, \code{estimate},
#'       \code{ci.lb}, \code{ci.ub}, \code{i2_between}, \code{i2_within},
#'       \code{pval}.  The last row is the "All studies" baseline.}
#'     \item{plot_file}{File path of the saved plot (character string) or
#'       \code{NULL} if \code{file = NULL}.}
#'   }
#'
#' @importFrom metafor rma.mv robust
#' @importFrom grDevices png pdf dev.off
#' @importFrom stats as.formula
#' @method loo_effect meta3l_result
#' @export
loo_effect.meta3l_result <- function(x,
                                      file   = character(0),
                                      format = "png",
                                      width  = NULL,
                                      height = NULL,
                                      ...) {

  stopifnot(inherits(x, "meta3l_result"))

  n_effects      <- nrow(x$data)
  random_formula <- stats::as.formula(paste0("~ 1 | ", x$cluster, " / TE_id"))

  # -------------------------------------------------------------------
  # 1. Sequential LOO loop over effect size rows (Windows-safe)
  # -------------------------------------------------------------------
  results_list <- lapply(seq_len(n_effects), function(i) {
    keep    <- rep(TRUE, n_effects)
    keep[i] <- FALSE
    dat_loo <- x$data[keep, , drop = FALSE]
    V_loo   <- x$V[keep, keep, drop = FALSE]

    # Guard: need >= 2 clusters remaining
    n_clust <- length(unique(dat_loo[[x$cluster]]))
    if (n_clust < 2L) {
      warning("Dropping row ", i, " leaves < 2 clusters; skipping.", call. = FALSE)
      return(list(omitted = .loo_effect_label(x, i), estimate = NA_real_,
                  ci.lb = NA_real_, ci.ub = NA_real_,
                  i2_between = NA_real_, i2_within = NA_real_,
                  pval = NA_real_))
    }

    tryCatch({
      fit_loo <- metafor::rma.mv(yi, V_loo,
                                 random = random_formula,
                                 data   = dat_loo)
      fit_rob <- metafor::robust(fit_loo,
                                 cluster      = dat_loo[[x$cluster]],
                                 clubSandwich = TRUE)
      i2_loo  <- compute_i2(fit_loo, V_loo)

      list(omitted    = .loo_effect_label(x, i),
           estimate   = x$transf(fit_rob$b[[1L]]),
           ci.lb      = x$transf(fit_rob$ci.lb),
           ci.ub      = x$transf(fit_rob$ci.ub),
           i2_between = i2_loo$between,
           i2_within  = i2_loo$within,
           pval       = fit_rob$pval)
    }, error = function(e) {
      warning("LOO iteration for row ", i, " failed: ", e$message, call. = FALSE)
      list(omitted = .loo_effect_label(x, i), estimate = NA_real_,
           ci.lb = NA_real_, ci.ub = NA_real_,
           i2_between = NA_real_, i2_within = NA_real_,
           pval = NA_real_)
    })
  })

  # -------------------------------------------------------------------
  # 2. Build LOO table
  # -------------------------------------------------------------------
  tbl <- do.call(rbind, lapply(results_list, function(r) {
    as.data.frame(r, stringsAsFactors = FALSE)
  }))

  # -------------------------------------------------------------------
  # 3. Add "All studies" baseline row (full model estimates)
  # -------------------------------------------------------------------
  full_fit_i2 <- tryCatch({
    compute_i2(metafor::rma.mv(yi, x$V,
                               random = random_formula,
                               data   = x$data),
               x$V)
  }, error = function(e) {
    list(between = NA_real_, within = NA_real_, total = NA_real_)
  })

  baseline <- data.frame(
    omitted    = "All studies",
    estimate   = x$estimate,
    ci.lb      = x$ci.lb,
    ci.ub      = x$ci.ub,
    i2_between = full_fit_i2$between,
    i2_within  = full_fit_i2$within,
    pval       = x$model$pval,
    stringsAsFactors = FALSE
  )
  tbl <- rbind(tbl, baseline)
  rownames(tbl) <- NULL

  # -------------------------------------------------------------------
  # 4. Resolve file and open device
  # -------------------------------------------------------------------
  out_path <- resolve_file(x, file, format, suffix = "loo_effect")
  n_rows   <- nrow(tbl)
  dims     <- auto_dims(n_rows, width, height)

  if (!is.null(out_path)) {
    if (identical(format, "pdf")) {
      grDevices::pdf(out_path,
                     width  = dims$width  / 300,
                     height = dims$height / 300)
    } else {
      grDevices::png(out_path,
                     width  = dims$width,
                     height = dims$height,
                     res    = 300L)
    }
    on.exit(grDevices::dev.off(), add = TRUE)
    .draw_loo_plot(tbl, x$measure, x$cluster)
  }

  invisible(list(table = tbl, plot_file = out_path))
}

# ---------------------------------------------------------------------------
# Internal: build slab-style label for a dropped effect row
# ---------------------------------------------------------------------------

#' Build a label for a dropped effect row (internal)
#'
#' @param x A \code{meta3l_result} object.
#' @param i Integer; row index being dropped.
#' @return A character string label of the form "StudyLabel [i]".
#' @keywords internal
.loo_effect_label <- function(x, i) {
  slab_val <- if (!is.null(x$slab) && x$slab %in% names(x$data)) {
    as.character(x$data[[x$slab]][i])
  } else {
    paste0("Row_", i)
  }
  paste0(slab_val, " [", i, "]")
}

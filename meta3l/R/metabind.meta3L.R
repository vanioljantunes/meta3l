# metabind.meta3L.R - Combine several meta3l_result objects (and, optionally,
# their subgroup analyses) into a single summary forest plot.
# Uses grid graphics exclusively (no base-R plot/par/text calls).

# ---------------------------------------------------------------------------
# Internal: fit a three-level model on a subset of rows of a meta3l_result
# ---------------------------------------------------------------------------

#' Fit a three-level model on a row subset of a meta3l_result (internal)
#'
#' Mirrors the per-subgroup fitting logic used by \code{forest_subgroup.meta3L}:
#' three-level \code{rma.mv} + CR2 robust variance when the subset contains two
#' or more clusters, two-level \code{rma} fallback otherwise.
#'
#' @param x   A \code{meta3l_result} object.
#' @param idx Integer vector of row indices into \code{x$data}.
#'
#' @return A named list with elements \code{est}, \code{lb}, \code{ub},
#'   \code{pval}, \code{i2}, \code{k_eff}, \code{k_clust}, \code{ok}.
#'
#' @keywords internal
bind_fit_subset <- function(x, idx) {
  dat_g   <- x$data[idx, , drop = FALSE]
  V_g     <- x$V[idx, idx, drop = FALSE]
  cluster <- x$cluster
  k_eff   <- nrow(dat_g)
  k_clust <- length(unique(dat_g[[cluster]]))

  rob_g <- NULL
  i2_g  <- NULL

  if (k_clust >= 2L) {
    if (x$measure == "GLMM") {
      fit_g <- tryCatch(
        metafor::rma.glmm(xi = dat_g$xi, ni = dat_g$ni,
                          measure = "PLO", slab = dat_g[[x$slab]],
                          data = dat_g),
        error = function(e) NULL
      )
      if (!is.null(fit_g)) {
        rob_g <- fit_g
        i2_g  <- tryCatch(compute_i2_glmm(fit_g, dat_g$vi),
                          error = function(e) NULL)
      }
    } else {
      formula_g <- stats::as.formula(paste0("~ 1 | ", cluster, " / TE_id"))
      fit_g <- tryCatch(
        metafor::rma.mv(yi, V_g, random = formula_g, data = dat_g),
        error = function(e) {
          tryCatch(
            metafor::rma.mv(yi, V_g, random = formula_g, data = dat_g,
                            control = list(optimizer = "bobyqa")),
            error = function(e2) NULL
          )
        }
      )
      if (!is.null(fit_g)) {
        rob_g <- tryCatch(
          metafor::robust(fit_g, cluster = dat_g[[cluster]],
                          clubSandwich = TRUE),
          error = function(e) fit_g
        )
        i2_g <- tryCatch(compute_i2(fit_g), error = function(e) NULL)
      }
    }
  }

  if (is.null(rob_g)) {
    fit_fallback <- tryCatch(metafor::rma(yi, vi, data = dat_g),
                             error = function(e) NULL)
    if (!is.null(fit_fallback)) {
      rob_g <- fit_fallback
      i2_g  <- list(total = fit_fallback$I2, between = 0,
                    within = fit_fallback$I2)
    }
  }

  if (is.null(i2_g)) i2_g <- list(total = NA_real_, between = NA_real_,
                                  within = NA_real_)

  if (is.null(rob_g)) {
    return(list(est = NA_real_, lb = NA_real_, ub = NA_real_,
                pval = NA_real_, i2 = i2_g, k_eff = k_eff,
                k_clust = k_clust, ok = FALSE))
  }

  list(
    est     = x$transf(as.numeric(rob_g$b)),
    lb      = x$transf(as.numeric(rob_g$ci.lb)),
    ub      = x$transf(as.numeric(rob_g$ci.ub)),
    pval    = as.numeric(rob_g$pval),
    i2      = i2_g,
    k_eff   = k_eff,
    k_clust = k_clust,
    ok      = TRUE
  )
}

#' Omnibus test for subgroup differences (internal)
#'
#' @param x        A \code{meta3l_result} object.
#' @param subgroup Character string; column name in \code{x$data}.
#'
#' @return Numeric p-value, or \code{NA_real_} when the moderator model cannot
#'   be fitted (including \code{measure = "GLMM"}, which does not accept
#'   moderators).
#'
#' @keywords internal
bind_qtest <- function(x, subgroup) {
  if (x$measure == "GLMM") return(NA_real_)
  dat <- x$data
  random_formula <- stats::as.formula(paste0("~ 1 | ", x$cluster, " / TE_id"))
  mods_formula   <- stats::as.formula(paste0("~ factor(", subgroup, ")"))
  res_mod <- tryCatch(
    metafor::rma.mv(yi, x$V, mods = mods_formula, random = random_formula,
                    data = dat),
    error = function(e) {
      tryCatch(
        metafor::rma.mv(yi, x$V, mods = mods_formula, random = random_formula,
                        data = dat, control = list(optimizer = "bobyqa")),
        error = function(e2) NULL
      )
    }
  )
  if (is.null(res_mod)) NA_real_ else as.numeric(res_mod$QMp)
}

#' Summarise each arm of a set of effect sizes without double counting (internal)
#'
#' A three-level data set repeats the same patients across the effect sizes of
#' one cluster (e.g. left and right measurements of the same participants), so
#' summing the sample-size column over rows inflates the count.  With
#' \code{method = "max"} each cluster is represented by its largest row, and
#' those representatives are summed (totals), pooled by sample size (means) or
#' pooled with the usual within-group formula (SDs).  \code{method = "sum"}
#' restores the naive row-wise aggregation for data whose rows really are
#' disjoint patient groups.
#'
#' @param dat     Data frame; the rows to summarise (already subset).
#' @param cluster Character string; name of the cluster column in \code{dat}.
#' @param measure Character string; the effect size measure, used to pick the
#'   sample-size, mean and SD columns.
#' @param method  \code{"max"} (default) or \code{"sum"}.
#'
#' @return A named numeric vector with elements \code{n_e}, \code{mean_e},
#'   \code{sd_e}, \code{n_c}, \code{mean_c}, \code{sd_c}; elements that the
#'   data cannot supply are \code{NA_real_}.
#'
#' @keywords internal
bind_arm_summary <- function(dat, cluster, measure, method = c("max", "sum")) {
  method <- match.arg(method)

  pick <- function(cands) {
    hit <- cands[cands %in% names(dat)]
    if (length(hit) == 0L) return(NULL)
    v <- suppressWarnings(as.numeric(dat[[hit[1L]]]))
    if (all(is.na(v))) NULL else v
  }

  single <- is_single_arm(measure)
  arms <- if (single) {
    list(e = list(n = pick(c("n", "ni")), m = NULL, s = NULL))
  } else {
    list(
      e = list(n = pick(c("n.e", "n1i")), m = pick(c("mean.e", "m1i")),
               s = pick(c("sd.e", "sd1i"))),
      c = list(n = pick(c("n.c", "n2i")), m = pick(c("mean.c", "m2i")),
               s = pick(c("sd.c", "sd2i")))
    )
  }

  cl <- dat[[cluster]]
  out <- c(n_e = NA_real_, mean_e = NA_real_, sd_e = NA_real_,
           n_c = NA_real_, mean_c = NA_real_, sd_c = NA_real_)

  for (side in names(arms)) {
    a <- arms[[side]]
    if (is.null(a$n)) next

    # One representative row per cluster keeps repeated measurements of the
    # same participants from being counted several times
    if (identical(method, "max")) {
      idx <- vapply(unique(cl), function(k) {
        rows <- which(cl == k)
        rows[which.max(replace(a$n[rows], is.na(a$n[rows]), -Inf))]
      }, integer(1L))
    } else {
      idx <- seq_along(a$n)
    }

    n <- a$n[idx]
    out[[paste0("n_", side)]] <- sum(n, na.rm = TRUE)

    if (!is.null(a$m)) {
      m  <- a$m[idx]
      ok <- is.finite(n) & is.finite(m)
      if (any(ok)) {
        out[[paste0("mean_", side)]] <- sum(m[ok] * n[ok]) / sum(n[ok])
      }
    }
    if (!is.null(a$s)) {
      sdv <- a$s[idx]
      ok  <- is.finite(n) & is.finite(sdv) & n > 1
      if (any(ok)) {
        out[[paste0("sd_", side)]] <-
          sqrt(sum((n[ok] - 1) * sdv[ok]^2) / sum(n[ok] - 1))
      }
    }
  }
  out
}

# ---------------------------------------------------------------------------
# metabind()
# ---------------------------------------------------------------------------

#' Combine several three-level meta-analyses into one summary object
#'
#' Collects the pooled estimates of two or more \code{meta3l_result} objects -
#' and, when \code{subgroup} is supplied, the pooled estimates of each subgroup
#' level within each analysis - into a single object that
#' \code{\link[metafor]{forest}} can draw as one summary forest plot.  This is
#' the three-level analogue of \code{metafor::metabind()}: no new pooling is
#' performed across analyses, the rows are simply stacked for comparison.
#'
#' Every analysis must share the same \code{measure}; mixing measures on one
#' axis is refused.
#'
#' Within an analysis the subgroup categories are listed first, each as its own
#' sub-heading with the omnibus test for subgroup differences, and the pooled
#' estimate of the whole analysis closes the block.  Set
#' \code{overall.first = TRUE} to put the pooled estimate on top instead.
#'
#' @param ... Two or more \code{meta3l_result} objects, or a single (optionally
#'   named) list of them.  Names, when present, become the block labels;
#'   otherwise the \code{name} field of each result is used.
#' @param subgroup Character vector of column names to break each analysis down
#'   by (e.g. \code{c("side", "intervention")}).  Several categories per
#'   analysis are allowed and each gets its own sub-heading.  A column absent
#'   from a given analysis is skipped with a warning.  \code{NULL} (default)
#'   produces one row per analysis.
#' @param labels Character vector of block labels, one per analysis.  Overrides
#'   list names and \code{name} fields.
#' @param overall Logical; include the whole-analysis pooled row in each block
#'   (default \code{TRUE}).  When \code{subgroup} is \code{NULL} this is the only
#'   row a block has and the argument is ignored.
#' @param overall.first Logical; draw the pooled row before its subgroup
#'   categories instead of after them (default \code{FALSE}).
#' @param qtest Logical; compute the omnibus test for subgroup differences for
#'   each subgroup column (default \code{TRUE}).  Ignored when \code{subgroup}
#'   is \code{NULL}.
#' @param patients.method How to count patients without double counting those
#'   who contribute several effect sizes: \code{"max"} (default) takes the
#'   largest sample size per cluster, \code{"sum"} adds the rows up.  See
#'   \code{bind_arm_summary}.
#' @param name Character string; base name used for auto-generated plot file
#'   names.  Defaults to \code{"metabind"}.
#'
#' @return An object of class \code{"meta3l_bind"}, a named list with:
#'   \describe{
#'     \item{rows}{Data frame with one row per printed line: \code{block},
#'       \code{type} (\code{"block"}, \code{"sub"} or \code{"row"}),
#'       \code{kind} (\code{"overall"} or \code{"level"} for estimate rows),
#'       \code{label}, \code{est}, \code{lb}, \code{ub}, \code{pval},
#'       \code{k_eff}, \code{k_clust}, \code{i2}, \code{i2b}, \code{i2w},
#'       \code{n_e}, \code{mean_e}, \code{sd_e}, \code{n_c},
#'       \code{mean_c}, \code{sd_c}, \code{note}.}
#'     \item{measure}{The shared effect size measure.}
#'     \item{rho}{Vector of \code{rho} values, one per analysis.}
#'     \item{group.e, group.c}{Group labels taken from the first analysis.}
#'     \item{subgroup}{The \code{subgroup} argument as supplied.}
#'     \item{name}{The \code{name} argument as supplied.}
#'   }
#'
#' @seealso \code{\link{forest_subgroup}} for a study-level subgroup forest of a
#'   single analysis.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' mb <- metabind(
#'   Putamen  = r_putamen,
#'   Caudate  = r_caudate,
#'   Thalamus = r_thalamus,
#'   subgroup = c("side", "intervention")
#' )
#' print(mb)
#' forest(mb, analysis.lab = "Region", title = "QSM", file = character(0))
#' }
metabind <- function(..., subgroup = NULL, labels = NULL, overall = TRUE,
                     overall.first = FALSE, qtest = TRUE,
                     patients.method = c("max", "sum"), name = "metabind") {

  patients.method <- match.arg(patients.method)

  objs <- list(...)
  if (length(objs) == 1L && is.list(objs[[1L]]) &&
      !inherits(objs[[1L]], "meta3l_result")) {
    objs <- objs[[1L]]
  }

  if (length(objs) == 0L) {
    stop("metabind() needs at least one meta3l_result object.", call. = FALSE)
  }
  ok_class <- vapply(objs, inherits, logical(1L), what = "meta3l_result")
  if (!all(ok_class)) {
    stop("All objects passed to metabind() must be meta3l_result objects ",
         "(offending position(s): ",
         paste(which(!ok_class), collapse = ", "), ").", call. = FALSE)
  }

  measures <- vapply(objs, function(o) o$measure, character(1L))
  if (length(unique(measures)) > 1L) {
    stop("All analyses must share the same `measure`; got: ",
         paste(unique(measures), collapse = ", "), ".", call. = FALSE)
  }

  # --- Block labels ---------------------------------------------------------
  if (!is.null(labels)) {
    if (length(labels) != length(objs)) {
      stop("`labels` must have one entry per analysis (", length(objs),
           "); got ", length(labels), ".", call. = FALSE)
    }
    block_labels <- as.character(labels)
  } else {
    nm <- names(objs)
    block_labels <- vapply(seq_along(objs), function(i) {
      if (!is.null(nm) && nzchar(nm[i])) return(nm[i])
      if (!is.null(objs[[i]]$name) && nzchar(objs[[i]]$name)) {
        return(objs[[i]]$name)
      }
      paste0("Analysis ", i)
    }, character(1L))
  }

  # --- Build rows -----------------------------------------------------------
  na_arms <- c(n_e = NA_real_, mean_e = NA_real_, sd_e = NA_real_,
               n_c = NA_real_, mean_c = NA_real_, sd_c = NA_real_)
  make_row <- function(block, type, label, kind = "", fit = NULL,
                       pat = na_arms, note = "") {
    data.frame(
      block   = block,
      type    = type,
      kind    = kind,
      label   = label,
      est     = if (is.null(fit)) NA_real_ else fit$est,
      lb      = if (is.null(fit)) NA_real_ else fit$lb,
      ub      = if (is.null(fit)) NA_real_ else fit$ub,
      pval    = if (is.null(fit)) NA_real_ else fit$pval,
      k_eff   = if (is.null(fit)) NA_integer_ else as.integer(fit$k_eff),
      k_clust = if (is.null(fit)) NA_integer_ else as.integer(fit$k_clust),
      i2      = if (is.null(fit)) NA_real_ else fit$i2$total,
      i2b     = if (is.null(fit)) NA_real_ else fit$i2$between,
      i2w     = if (is.null(fit)) NA_real_ else fit$i2$within,
      n_e     = unname(pat[["n_e"]]),
      mean_e  = unname(pat[["mean_e"]]),
      sd_e    = unname(pat[["sd_e"]]),
      n_c     = unname(pat[["n_c"]]),
      mean_c  = unname(pat[["mean_c"]]),
      sd_c    = unname(pat[["sd_c"]]),
      note    = note,
      stringsAsFactors = FALSE
    )
  }

  rows <- list()

  for (i in seq_along(objs)) {
    x  <- objs[[i]]
    bl <- block_labels[i]

    rows[[length(rows) + 1L]] <- make_row(bl, "block", bl)

    overall_row <- NULL
    if (isTRUE(overall) || is.null(subgroup)) {
      fit_ov <- list(
        est     = x$estimate,
        lb      = x$ci.lb,
        ub      = x$ci.ub,
        pval    = as.numeric(x$model$pval),
        i2      = x$i2,
        k_eff   = nrow(x$data),
        k_clust = length(unique(x$data[[x$cluster]])),
        ok      = TRUE
      )
      overall_row <- make_row(
        bl, "row", "Overall", kind = "overall", fit = fit_ov,
        pat = bind_arm_summary(x$data, x$cluster, x$measure,
                               patients.method)
      )
    }

    if (!is.null(overall_row) && isTRUE(overall.first)) {
      rows[[length(rows) + 1L]] <- overall_row
    }

    if (!is.null(subgroup)) {
      for (sg_col in subgroup) {
        if (!sg_col %in% names(x$data)) {
          warning("Subgroup column '", sg_col, "' not found in analysis '",
                  bl, "'; skipped.", call. = FALSE)
          next
        }
        lv <- unique(x$data[[sg_col]])
        lv <- lv[!is.na(lv)]
        if (length(lv) == 0L) next

        q_note <- ""
        if (isTRUE(qtest) && length(lv) > 1L) {
          qp <- bind_qtest(x, sg_col)
          if (!is.na(qp)) {
            # Just the p-value: the "p (diff)" column header carries the
            # meaning and the value is centred over the category's band
            q_note <- if (qp < 0.001) "<0.001" else sprintf("%.3f", qp)
          }
        }
        rows[[length(rows) + 1L]] <- make_row(bl, "sub", as.character(sg_col),
                                              note = q_note)

        for (l in lv) {
          idx <- which(x$data[[sg_col]] == l)
          fit <- bind_fit_subset(x, idx)
          rows[[length(rows) + 1L]] <- make_row(
            bl, "row", as.character(l), kind = "level", fit = fit,
            pat  = bind_arm_summary(x$data[idx, , drop = FALSE], x$cluster,
                                    x$measure, patients.method),
            note = if (fit$ok) "" else "not estimable"
          )
        }
      }
    }

    if (!is.null(overall_row) && !isTRUE(overall.first)) {
      rows[[length(rows) + 1L]] <- overall_row
    }
  }

  rows_df <- do.call(rbind, rows)
  rownames(rows_df) <- NULL

  structure(
    list(
      rows     = rows_df,
      analyses = objs,
      measure  = measures[[1L]],
      rho      = vapply(objs, function(o) o$rho, numeric(1L)),
      group.e  = objs[[1L]]$group.e,
      group.c  = objs[[1L]]$group.c,
      subgroup = subgroup,
      name     = name
    ),
    class = "meta3l_bind"
  )
}

# ---------------------------------------------------------------------------
# print method
# ---------------------------------------------------------------------------

#' Print a combined three-level meta-analysis object
#'
#' @param x      A \code{meta3l_bind} object from \code{\link{metabind}}.
#' @param digits Integer; digits for estimates and confidence limits.
#' @param ...    Currently ignored.
#'
#' @return \code{x}, invisibly.
#'
#' @method print meta3l_bind
#' @export
print.meta3l_bind <- function(x, digits = 2L, ...) {
  cat("Combined three-level meta-analysis (", x$measure, ")\n\n", sep = "")
  r <- x$rows
  fmt_n <- function(v) if (is.na(v)) "-" else format(round(v))
  for (i in seq_len(nrow(r))) {
    if (r$type[i] == "block") {
      cat(r$label[i], "\n", sep = "")
    } else if (r$type[i] == "sub") {
      cat("  Subgroup: ", r$label[i],
          if (nzchar(r$note[i])) paste0("   (p diff = ", r$note[i], ")") else "",
          "\n", sep = "")
    } else {
      est_txt <- if (is.na(r$est[i])) {
        "not estimable"
      } else {
        sprintf("%.*f [%.*f; %.*f]", digits, r$est[i], digits, r$lb[i],
                digits, r$ub[i])
      }
      cat(sprintf(
        "    %-22s %-26s k = %-4s n = %s/%s  I2 = %s (btw %s, wth %s)\n",
        r$label[i], est_txt,
        ifelse(is.na(r$k_clust[i]), "-", r$k_clust[i]),
        fmt_n(r$n_e[i]), fmt_n(r$n_c[i]),
        ifelse(is.na(r$i2[i]),  "-", sprintf("%.0f%%", r$i2[i])),
        ifelse(is.na(r$i2b[i]), "-", sprintf("%.0f%%", r$i2b[i])),
        ifelse(is.na(r$i2w[i]), "-", sprintf("%.0f%%", r$i2w[i]))
      ))
    }
  }
  invisible(x)
}

# ---------------------------------------------------------------------------
# forest method
# ---------------------------------------------------------------------------

#' Summary forest plot for combined three-level meta-analyses
#'
#' Draws one mark per pooled estimate collected by \code{\link{metabind}}: a
#' diamond for the pooled estimate of each analysis and a square for each
#' subgroup level.  No study-level rows are drawn - use
#' \code{\link{forest_subgroup}} for those.
#'
#' Each analysis opens with a header row carrying its name and, when the object
#' was built with \code{subgroup}, the p-value of the omnibus test for subgroup
#' differences of every category in brackets.
#'
#' @param x A \code{meta3l_bind} object returned by \code{\link{metabind}}.
#' @param analysis.lab Character string; header of the first column.  Defaults
#'   to \code{"Outcome"}.
#' @param refline Numeric scalar; x position of the vertical reference line.
#'   \code{NULL} auto-derives from the measure.
#' @param xlim Numeric vector of length 2; x-axis limits.  \code{NULL}
#'   auto-computes from the pooled estimates and their confidence limits.
#' @param xlim.trim Numeric in (0, 1]; quantile of the confidence bounds the
#'   automatic x-axis has to cover.  The default \code{0.95} keeps one very
#'   imprecise subgroup from stretching the axis until every other interval is
#'   unreadable; intervals reaching past the limits get arrow heads.  Set to
#'   \code{1} to cover every bound, or pass \code{xlim} to fix the limits.
#' @param at Numeric vector; tick positions.  \code{NULL} uses
#'   \code{pretty(xlim, n = 5)}.
#' @param xlab Character string; x-axis label.  \code{NULL} omits it.
#' @param title Character string; plot title drawn below the axis.
#' @param add.text Footnote describing the model, drawn under the plot.
#'   \code{TRUE} (default) composes it from the object, \code{FALSE} omits it,
#'   and a character vector is printed verbatim, one line per element.
#' @param showdata Logical; show the per-arm data columns (default
#'   \code{TRUE}).  For two-arm measures these are mean, SD and total for each
#'   group, headed by the group names; single-arm measures get one total column.
#' @param showk Logical; show the "Studies" and "Effects" columns
#'   (default \code{TRUE}).
#' @param showi2 Logical; show the I-squared columns (default \code{TRUE}).
#' @param showi2.parts Logical; split I-squared into between- and
#'   within-cluster columns next to the total (default \code{TRUE}).
#' @param shade One of \code{"zebra"} (default, alternate estimate rows),
#'   \code{"category"} (one band per subgroup category), \code{"block"}
#'   (alternate analyses) or \code{"none"}.
#' @param colshade Colour used for shading.
#' @param squaresize Numeric scaling factor for the subgroup-level squares.
#' @param digits Integer; digits for estimates and confidence limits.
#' @param digits.data Integer; digits for the mean and SD columns.
#' @param file One of: \code{character(0)} (default, auto-name); \code{NULL}
#'   (display only); or an explicit file path.
#' @param format Character; \code{"png"} (default) or \code{"pdf"}.
#' @param width Integer; output width in pixels.  \code{NULL} auto-computes.
#' @param height Integer; output height in pixels.  \code{NULL} auto-computes.
#' @param ... Currently ignored.
#'
#' @return Invisibly returns the file path of the saved plot, or \code{NULL}
#'   when \code{file = NULL}.
#'
#' @importFrom grDevices rgb png pdf dev.off
#' @method forest meta3l_bind
#' @export
forest.meta3l_bind <- function(x,
                               analysis.lab = "Outcome",
                               refline      = NULL,
                               xlim         = NULL,
                               xlim.trim    = 0.95,
                               at           = NULL,
                               xlab         = NULL,
                               title        = NULL,
                               add.text     = TRUE,
                               showdata     = TRUE,
                               showk        = TRUE,
                               showi2       = TRUE,
                               showi2.parts = TRUE,
                               shade        = "zebra",
                               colshade     = rgb(0.92, 0.92, 0.92),
                               squaresize   = 1,
                               digits       = 2L,
                               digits.data  = 1L,
                               file         = character(0),
                               format       = "png",
                               width        = NULL,
                               height       = NULL,
                               ...) {

  stopifnot(inherits(x, "meta3l_bind"))

  r         <- x$rows
  measure   <- x$measure
  show_pval <- !is_single_arm(measure)
  two_arm   <- !is_single_arm(measure)

  has_e <- showdata && any(!is.na(r$n_e))
  has_c <- showdata && two_arm && any(!is.na(r$n_c))
  has_ms <- showdata && two_arm &&
    (any(!is.na(r$mean_e)) || any(!is.na(r$mean_c)))

  # -------------------------------------------------------------------
  # 1. Footnote text
  # -------------------------------------------------------------------
  foot <- character(0)
  if (isTRUE(add.text)) {
    rho_txt <- if (length(unique(x$rho)) == 1L) {
      sprintf("%.1f", x$rho[[1L]])
    } else {
      paste(sprintf("%.1f", range(x$rho)), collapse = " to ")
    }
    foot <- sprintf(paste0("Three-level meta-analysis using robust variance ",
                           "estimation (CR2), with studies considered as ",
                           "clusters; within-cluster correlation \u03c1 = %s."),
                    rho_txt)
  } else if (is.character(add.text)) {
    foot <- add.text
  }

  # -------------------------------------------------------------------
  # 2. Row plan
  # -------------------------------------------------------------------
  # The subgroup categories do not take rows of their own any more: their
  # omnibus tests are appended to the analysis header instead.
  drop_block_hdr <- !any(r$type == "sub")

  notes_by_block <- list()
  for (i in which(r$type == "sub")) {
    if (!nzchar(r$note[i])) next
    b <- r$block[i]
    lbl <- gsub("[._]+", " ", r$label[i])
    lbl <- paste0(toupper(substr(lbl, 1L, 1L)), substr(lbl, 2L, nchar(lbl)))
    sep <- if (startsWith(r$note[i], "<")) " " else " = "
    notes_by_block[[b]] <- c(notes_by_block[[b]],
                             paste0(lbl, " p", sep, r$note[i]))
  }

  plan <- list()
  prev_block <- NULL
  band_id <- 0L
  cur_band <- NA_integer_
  for (i in seq_len(nrow(r))) {
    if (r$type[i] == "block") {
      if (!is.null(prev_block) && !drop_block_hdr) {
        plan[[length(plan) + 1L]] <- list(kind = "gap", band = NA_integer_)
      }
      prev_block <- r$block[i]
      cur_band <- NA_integer_
      if (drop_block_hdr) next
      plan[[length(plan) + 1L]] <- list(kind = "block", i = i,
                                        band = NA_integer_)
      next
    }
    if (r$type[i] == "sub") {
      band_id  <- band_id + 1L
      cur_band <- band_id
      next
    }
    is_level <- identical(r$kind[i], "level")
    plan[[length(plan) + 1L]] <- list(kind = "row", i = i,
                                      band = if (is_level) cur_band else
                                        NA_integer_)
    if (!is_level) cur_band <- NA_integer_
  }

  n_head_rows  <- if (has_ms || (showi2 && showi2.parts)) 2L else 1L
  n_body_rows  <- length(plan)
  n_total_rows <- n_head_rows + n_body_rows + 1L         # + axis row
  if (measure %in% c("SMD", "MD", "RR", "OR")) n_total_rows <- n_total_rows + 1L
  if (!is.null(title) && nzchar(title)) n_total_rows <- n_total_rows + 1L
  if (!is.null(xlab))                   n_total_rows <- n_total_rows + 1L
  n_tail_rows <- n_total_rows - (n_head_rows + n_body_rows)

  # -------------------------------------------------------------------
  # 3. Column layout
  # -------------------------------------------------------------------
  col_names <- c("label",
                 if (showk) c("studies", "effects"),
                 if (has_e && has_ms) c("e_mean", "e_sd"),
                 if (has_e) "e_n",
                 if (has_c && has_ms) c("c_mean", "c_sd"),
                 if (has_c) "c_n",
                 if (showi2 && showi2.parts) c("i2b", "i2w"),
                 if (showi2) "i2",
                 "gap1", "ci", "gap2", "results",
                 if (show_pval) "pval")
  col_of <- function(nm) {
    j <- match(nm, col_names)
    if (is.na(j)) NA_integer_ else as.integer(j)
  }

  label_col   <- col_of("label")
  studies_col <- col_of("studies")
  effects_col <- col_of("effects")
  e_mean_col  <- col_of("e_mean")
  e_sd_col    <- col_of("e_sd")
  e_n_col     <- col_of("e_n")
  c_mean_col  <- col_of("c_mean")
  c_sd_col    <- col_of("c_sd")
  c_n_col     <- col_of("c_n")
  i2b_col     <- col_of("i2b")
  i2w_col     <- col_of("i2w")
  i2_col      <- col_of("i2")
  gap1_col    <- col_of("gap1")
  ci_col      <- col_of("ci")
  gap2_col    <- col_of("gap2")
  results_col <- col_of("results")
  pval_col    <- col_of("pval")
  first_col   <- label_col
  last_col    <- length(col_names)
  n_cols      <- last_col

  is_row  <- r$type == "row"
  est_all <- r$est[is_row]
  lb_all  <- r$lb[is_row]
  ub_all  <- r$ub[is_row]

  disp_label <- function(i) {
    if (r$type[i] == "block") {
      note <- notes_by_block[[r$label[i]]]
      if (is.null(note)) return(r$label[i])
      return(sprintf("%s  (%s)", r$label[i], paste(note, collapse = "; ")))
    }
    if (drop_block_hdr) return(r$block[i])
    paste0("  ", r$label[i])
  }
  all_labels <- vapply(seq_len(nrow(r)), disp_label, character(1L))

  results_lab <- paste0(measure, " [95% CI]")
  label_chars <- max(nchar(all_labels), nchar(analysis.lab), na.rm = TRUE)
  label_w     <- max(4.0, ilab_col_cm(label_chars))
  k_w         <- 1.5
  ms_w        <- 1.7
  n_w         <- 1.4
  i2_w        <- 1.4
  gap_w       <- 0.5
  pval_w      <- if (show_pval) 1.8 else 0
  results_chars <- max(
    nchar(sprintf(paste0("%.", digits, "f [%.", digits, "f; %.", digits, "f]"),
                  est_all, lb_all, ub_all)),
    nchar(results_lab), na.rm = TRUE
  )
  results_w <- ilab_col_cm(results_chars)

  col_widths_cm <- numeric(n_cols)
  col_widths_cm[label_col] <- label_w
  if (showk) {
    col_widths_cm[studies_col] <- k_w
    col_widths_cm[effects_col] <- k_w
  }
  for (j in c(e_mean_col, e_sd_col, c_mean_col, c_sd_col)) {
    if (!is.na(j)) col_widths_cm[j] <- ms_w
  }
  for (j in c(e_n_col, c_n_col)) if (!is.na(j)) col_widths_cm[j] <- n_w
  for (j in c(i2b_col, i2w_col, i2_col)) {
    if (!is.na(j)) col_widths_cm[j] <- i2_w
  }
  col_widths_cm[gap1_col]    <- gap_w
  col_widths_cm[gap2_col]    <- gap_w
  col_widths_cm[results_col] <- results_w
  if (show_pval) col_widths_cm[pval_col] <- pval_w

  other_cm <- sum(col_widths_cm)
  ci_cm    <- max(min(7, other_cm * 0.6), 4)

  if (length(foot) > 0L) {
    foot_cm    <- sum(col_widths_cm[label_col:gap1_col])
    foot_chars <- max(40L, as.integer(foot_cm / 0.14))
    foot <- unlist(lapply(foot, function(line) {
      words <- strsplit(line, " ", fixed = TRUE)[[1L]]
      out <- character(0)
      cur <- ""
      for (w in words) {
        cand <- if (nzchar(cur)) paste(cur, w) else w
        if (nchar(cand) > foot_chars && nzchar(cur)) {
          out <- c(out, cur)
          cur <- w
        } else {
          cur <- cand
        }
      }
      c(out, cur)
    }), use.names = FALSE)
  }
  n_total_rows <- n_total_rows + max(0L, length(foot) - n_tail_rows)

  col_units_list <- vector("list", n_cols)
  for (j in seq_len(n_cols)) {
    col_units_list[[j]] <- if (j == ci_col) grid::unit(ci_cm, "cm") else
      grid::unit(col_widths_cm[j], "cm")
  }
  col_widths_units <- do.call(grid::unit.c, col_units_list)

  # -------------------------------------------------------------------
  # 4. xlim, refline
  # -------------------------------------------------------------------
  xlim_final <- if (!is.null(xlim)) {
    xlim
  } else if (xlim.trim < 1) {
    q_lo <- stats::quantile(lb_all, 1 - xlim.trim, na.rm = TRUE, names = FALSE)
    q_hi <- stats::quantile(ub_all, xlim.trim,     na.rm = TRUE, names = FALSE)
    auto_xlim(measure, est_all, pmax(lb_all, q_lo), pmin(ub_all, q_hi))
  } else {
    auto_xlim(measure, est_all, lb_all, ub_all)
  }
  refline_final <- if (!is.null(refline)) refline else auto_refline(measure)
  .show_refline <- !is.null(refline_final) && !is.na(refline_final) &&
    refline_final >= xlim_final[1] && refline_final <= xlim_final[2]

  # -------------------------------------------------------------------
  # 5. Row heights and device
  # -------------------------------------------------------------------
  rh <- rep(1.2, n_total_rows)
  if (n_head_rows == 2L) rh[1L] <- 1.1
  rh[n_head_rows] <- 1.6
  for (p in seq_along(plan)) {
    kind <- plan[[p]]$kind
    if (identical(kind, "row"))   rh[n_head_rows + p] <- 1.15
    if (identical(kind, "block")) rh[n_head_rows + p] <- 1.35
    if (identical(kind, "gap"))   rh[n_head_rows + p] <- 0.35
  }
  # The axis row holds the tick labels below the line, so it needs the room
  rh[n_head_rows + n_body_rows + 1L] <- 1.9

  out_file <- resolve_file(x, file, format)
  dims     <- auto_dims(n_total_rows, width, height)
  total_cm <- sum(col_widths_cm) + ci_cm
  auto_w   <- as.integer(total_cm * 300 / 2.54) + 300L
  if (is.null(width)) dims$width <- max(dims$width, auto_w)
  if (is.null(height)) {
    dims$height <- as.integer((sum(rh) * 0.2 + 0.7) * 300)
  }

  if (!is.null(out_file)) {
    if (identical(format, "pdf")) {
      grDevices::pdf(out_file, width = dims$width / 300,
                     height = dims$height / 300)
    } else {
      grDevices::png(out_file, width = dims$width, height = dims$height,
                     res = 300L)
    }
  } else {
    grDevices::pdf(nullfile(), width = dims$width / 300,
                   height = dims$height / 300)
  }
  on.exit(grDevices::dev.off(), add = TRUE)

  # -------------------------------------------------------------------
  # 6. Grid layout
  # -------------------------------------------------------------------
  grid::grid.newpage()

  row_heights <- grid::unit(rh, "lines")
  left_inset  <- grid::unit(0.9, "cm")

  grid::pushViewport(grid::viewport(
    layout = grid::grid.layout(nrow = n_total_rows, ncol = n_cols,
                               widths = col_widths_units,
                               heights = row_heights),
    x      = left_inset,
    y      = grid::unit(0, "npc"),
    width  = grid::unit(1, "npc") - left_inset,
    height = grid::unit(1, "npc") - grid::unit(0.4, "cm"),
    just   = c("left", "bottom")
  ))

  push_cell <- function(row, col, xscale = c(0, 1), clip = "off") {
    grid::pushViewport(grid::viewport(layout.pos.row = row,
                                      layout.pos.col = col,
                                      xscale = xscale, clip = clip))
  }
  push_span <- function(row, col_from, col_to, xscale = c(0, 1), clip = "off") {
    grid::pushViewport(grid::viewport(layout.pos.row = row,
                                      layout.pos.col = col_from:col_to,
                                      xscale = xscale, clip = clip))
  }
  txt <- function(row, col, s, gp, just = "centre",
                  xpos = if (identical(just, "left")) 0 else 0.5) {
    if (is.na(col) || !nzchar(s)) return(invisible(NULL))
    push_cell(row, col)
    grid::grid.text(s, x = grid::unit(xpos, "npc"), y = grid::unit(0.5, "npc"),
                    just = just, gp = gp)
    grid::popViewport()
  }

  bold_gp  <- grid::gpar(fontface = "bold", cex = 0.75)
  norm_gp  <- grid::gpar(cex = 0.75)
  small_gp <- grid::gpar(cex = 0.65, fontface = "italic")

  draw_refline <- function(row) {
    if (!.show_refline) return(invisible(NULL))
    push_cell(row, ci_col, xscale = xlim_final)
    grid::grid.segments(
      x0 = grid::unit(refline_final, "native"),
      x1 = grid::unit(refline_final, "native"),
      y0 = grid::unit(0, "npc"), y1 = grid::unit(1, "npc"),
      gp = grid::gpar(lty = "solid", col = "black", lwd = 0.8)
    )
    grid::popViewport()
  }

  # -------------------------------------------------------------------
  # 7. Header rows
  # -------------------------------------------------------------------
  hdr_row <- n_head_rows

  if (n_head_rows == 2L) {
    if (has_e && has_ms) {
      push_span(1L, e_mean_col, e_n_col)
      grid::grid.text(if (!is.null(x$group.e)) x$group.e else "Treatment",
                      x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
      grid::popViewport()
    }
    if (has_c && has_ms) {
      push_span(1L, c_mean_col, c_n_col)
      grid::grid.text(if (!is.null(x$group.c)) x$group.c else "Control",
                      x = grid::unit(0.5, "npc"), just = "centre", gp = bold_gp)
      grid::popViewport()
    }
    if (showi2 && showi2.parts) {
      push_span(1L, i2b_col, i2_col)
      grid::grid.text("I\u00b2", x = grid::unit(0.5, "npc"), just = "centre",
                      gp = bold_gp)
      grid::popViewport()
    }
  }

  txt(hdr_row, label_col, analysis.lab, bold_gp, just = "left")
  if (showk) {
    txt(hdr_row, studies_col, "Studies", bold_gp)
    txt(hdr_row, effects_col, "Effects", bold_gp)
  }
  if (has_e) {
    if (has_ms) {
      txt(hdr_row, e_mean_col, "Mean", bold_gp)
      txt(hdr_row, e_sd_col,   "SD",   bold_gp)
    }
    txt(hdr_row, e_n_col, if (has_ms) "Total" else "Patients", bold_gp)
  }
  if (has_c) {
    if (has_ms) {
      txt(hdr_row, c_mean_col, "Mean", bold_gp)
      txt(hdr_row, c_sd_col,   "SD",   bold_gp)
    }
    txt(hdr_row, c_n_col, "Total", bold_gp)
  }
  if (showi2) {
    if (showi2.parts) {
      txt(hdr_row, i2b_col, "btw", bold_gp)
      txt(hdr_row, i2w_col, "wth", bold_gp)
      txt(hdr_row, i2_col,  "total", bold_gp)
    } else {
      txt(hdr_row, i2_col, "I\u00b2", bold_gp)
    }
  }
  txt(hdr_row, results_col, results_lab, bold_gp)
  if (show_pval) txt(hdr_row, pval_col, "p-value", bold_gp)

  method_gp <- grid::gpar(fontface = "bold", cex = 0.65)
  push_cell(hdr_row, ci_col)
  grid::grid.text(sprintf("Inverse Variance, %s", measure),
                  x = grid::unit(0.5, "npc"), y = grid::unit(0.65, "npc"),
                  just = "centre", gp = method_gp)
  grid::grid.text(sprintf("Three-Level, \u03c1 = %.1f", x$rho[[1L]]),
                  x = grid::unit(0.5, "npc"), y = grid::unit(0.3, "npc"),
                  just = "centre", gp = method_gp)
  grid::popViewport()

  # -------------------------------------------------------------------
  # 8. Body rows
  # -------------------------------------------------------------------
  block_ids <- as.integer(factor(r$block, levels = unique(r$block)))
  row_seq   <- 0L
  fmt_est   <- paste0("%.", digits, "f [%.", digits, "f; %.", digits, "f]")
  fmt_int   <- function(v) if (is.na(v)) "" else format(round(v))
  fmt_num   <- function(v) if (is.na(v)) "" else
    sprintf(paste0("%.", digits.data, "f"), v)
  fmt_pct   <- function(v) if (is.na(v)) "" else sprintf("%.0f%%", v)

  for (p in seq_along(plan)) {
    row_i <- n_head_rows + p
    kind  <- plan[[p]]$kind

    if (identical(kind, "gap")) {
      draw_refline(row_i)
      next
    }

    i      <- plan[[p]]$i
    band_i <- plan[[p]]$band

    do_shade <- if (identical(shade, "zebra")) {
      identical(kind, "row") && (row_seq + 1L) %% 2L == 0L
    } else if (identical(shade, "category")) {
      !is.na(band_i) && band_i %% 2L == 1L
    } else if (identical(shade, "block")) {
      block_ids[i] %% 2L == 1L
    } else {
      FALSE
    }
    if (do_shade) {
      push_span(row_i, first_col, last_col)
      draw_zebra_rect(colshade)
      grid::popViewport()
    }

    if (identical(kind, "block")) {
      push_span(row_i, first_col, last_col)
      grid::grid.text(all_labels[i], x = grid::unit(0, "npc"), just = "left",
                      gp = grid::gpar(fontface = "bold", cex = 0.85))
      grid::popViewport()
      draw_refline(row_i)
      next
    }

    row_seq <- row_seq + 1L
    is_overall <- identical(r$kind[i], "overall")
    lbl_gp <- if (is_overall) bold_gp else norm_gp

    txt(row_i, label_col, all_labels[i], lbl_gp, just = "left")
    if (showk) {
      txt(row_i, studies_col, fmt_int(r$k_clust[i]), norm_gp)
      txt(row_i, effects_col, fmt_int(r$k_eff[i]),   norm_gp)
    }
    if (has_e) {
      if (has_ms) {
        txt(row_i, e_mean_col, fmt_num(r$mean_e[i]), norm_gp)
        txt(row_i, e_sd_col,   fmt_num(r$sd_e[i]),   norm_gp)
      }
      txt(row_i, e_n_col, fmt_int(r$n_e[i]), norm_gp)
    }
    if (has_c) {
      if (has_ms) {
        txt(row_i, c_mean_col, fmt_num(r$mean_c[i]), norm_gp)
        txt(row_i, c_sd_col,   fmt_num(r$sd_c[i]),   norm_gp)
      }
      txt(row_i, c_n_col, fmt_int(r$n_c[i]), norm_gp)
    }
    if (showi2) {
      if (showi2.parts) {
        txt(row_i, i2b_col, fmt_pct(r$i2b[i]), norm_gp)
        txt(row_i, i2w_col, fmt_pct(r$i2w[i]), norm_gp)
      }
      txt(row_i, i2_col, fmt_pct(r$i2[i]), norm_gp)
    }

    draw_refline(row_i)

    if (!is.na(r$est[i]) && !is.na(r$lb[i]) && !is.na(r$ub[i])) {
      push_cell(row_i, ci_col, xscale = xlim_final, clip = "on")
      if (is_overall) {
        draw_diamond(
          max(r$lb[i], xlim_final[1]),
          min(max(r$est[i], xlim_final[1]), xlim_final[2]),
          min(r$ub[i], xlim_final[2]),
          y_center = 0.5
        )
        for (side in c(1L, 2L)) {
          runs_off <- if (side == 1L) r$lb[i] < xlim_final[1] else
            r$ub[i] > xlim_final[2]
          if (!runs_off) next
          edge  <- xlim_final[side]
          inner <- edge + (if (side == 1L) 1 else -1) * diff(xlim_final) * 0.03
          grid::grid.segments(
            x0 = grid::unit(inner, "native"), x1 = grid::unit(edge, "native"),
            y0 = grid::unit(0.5, "npc"), y1 = grid::unit(0.5, "npc"),
            arrow = grid::arrow(ends = "last",
                                length = grid::unit(0.05, "inches")),
            gp = grid::gpar(lwd = 1)
          )
        }
      } else {
        lb_draw <- max(r$lb[i], xlim_final[1])
        ub_draw <- min(r$ub[i], xlim_final[2])
        trunc_left  <- r$lb[i] < xlim_final[1]
        trunc_right <- r$ub[i] > xlim_final[2]
        if (trunc_left || trunc_right) {
          arrow_ends <- if (trunc_left && trunc_right) "both" else
            if (trunc_left) "first" else "last"
          grid::grid.segments(
            x0 = grid::unit(lb_draw, "native"),
            x1 = grid::unit(ub_draw, "native"),
            y0 = grid::unit(0.5, "npc"), y1 = grid::unit(0.5, "npc"),
            arrow = grid::arrow(ends = arrow_ends,
                                length = grid::unit(0.05, "inches")),
            gp = grid::gpar(lwd = 1)
          )
        } else {
          draw_ci_line(lb_draw, ub_draw)
        }
        if (r$est[i] >= xlim_final[1] && r$est[i] <= xlim_final[2]) {
          draw_square(r$est[i], 0.55 * squaresize)
        }
      }
      grid::popViewport()

      txt(row_i, results_col,
          sprintf(fmt_est, r$est[i], r$lb[i], r$ub[i]),
          if (is_overall) bold_gp else norm_gp)

      if (show_pval && !is.na(r$pval[i])) {
        pv <- if (r$pval[i] < 0.001) "<0.001" else sprintf("%.4f", r$pval[i])
        txt(row_i, pval_col, pv, if (is_overall) bold_gp else norm_gp)
      }
    } else {
      txt(row_i, results_col, "not estimable", small_gp)
    }
  }

  # -------------------------------------------------------------------
  # 9. Axis row
  # -------------------------------------------------------------------
  current_row <- n_head_rows + n_body_rows + 1L
  at_final <- if (!is.null(at)) at else pretty(xlim_final, n = 5L)

  push_cell(current_row, ci_col, xscale = xlim_final)
  grid::grid.segments(
    x0 = grid::unit(xlim_final[1], "native"),
    x1 = grid::unit(xlim_final[2], "native"),
    y0 = grid::unit(1, "npc"), y1 = grid::unit(1, "npc"),
    gp = grid::gpar(lwd = 1)
  )
  for (.tick in at_final) {
    if (.tick >= xlim_final[1] && .tick <= xlim_final[2]) {
      grid::grid.segments(
        x0 = grid::unit(.tick, "native"), x1 = grid::unit(.tick, "native"),
        y0 = grid::unit(1, "npc"),
        y1 = grid::unit(1, "npc") - grid::unit(0.35, "lines"),
        gp = grid::gpar(lwd = 1)
      )
      # Tick labels clear the marks, otherwise the numbers sit on the ticks
      grid::grid.text(format(.tick), x = grid::unit(.tick, "native"),
                      y = grid::unit(1, "npc") - grid::unit(1.05, "lines"),
                      gp = grid::gpar(cex = 0.65))
    }
  }
  grid::popViewport()
  current_row <- current_row + 1L

  # -------------------------------------------------------------------
  # 10. Favours labels, title, xlab, footnote
  # -------------------------------------------------------------------
  if (measure %in% c("SMD", "MD", "RR", "OR")) {
    fav_left  <- paste0("Favours ",
                        if (!is.null(x$group.c)) x$group.c else "Control")
    fav_right <- paste0("Favours ",
                        if (!is.null(x$group.e)) x$group.e else "Treatment")
    push_cell(current_row, ci_col, xscale = xlim_final)
    grid::grid.text(fav_left, x = grid::unit(0.25, "npc"), just = "centre",
                    gp = bold_gp)
    grid::grid.text(fav_right, x = grid::unit(0.75, "npc"), just = "centre",
                    gp = bold_gp)
    grid::popViewport()
    current_row <- current_row + 1L
  }

  if (!is.null(title) && nzchar(title)) {
    push_cell(current_row, ci_col)
    grid::grid.text(title, x = grid::unit(0.5, "npc"), just = "centre",
                    gp = grid::gpar(fontface = "bold", cex = 0.85))
    grid::popViewport()
    current_row <- current_row + 1L
  }

  if (!is.null(xlab)) {
    push_cell(current_row, ci_col)
    grid::grid.text(xlab, x = grid::unit(0.5, "npc"), just = "centre",
                    gp = grid::gpar(cex = 0.7))
    grid::popViewport()
    current_row <- current_row + 1L
  }

  foot_row <- n_head_rows + n_body_rows + 1L
  for (line in foot) {
    push_span(foot_row, first_col, gap1_col, clip = "on")
    grid::grid.text(line, x = grid::unit(0, "npc"), y = grid::unit(0.6, "npc"),
                    just = "left", gp = small_gp)
    grid::popViewport()
    foot_row <- foot_row + 1L
  }

  grid::popViewport()

  invisible(out_file)
}

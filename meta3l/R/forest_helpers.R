# forest_helpers.R — Internal drawing primitives and utility functions
# for grid-based forest plots.  All draw_* functions assume they are called
# inside an active grid viewport with xscale already set.

# ---------------------------------------------------------------------------
# Drawing primitives
# ---------------------------------------------------------------------------

#' Draw a weighted study square (internal)
#'
#' Draws a filled rectangle centred at (x_pos, 0.5 npc) whose size is
#' proportional to the normalised study weight.  Must be called inside an
#' active grid viewport with an xscale set.
#'
#' @param x_pos Numeric; x position in native (data) coordinates.
#' @param size  Numeric; side length in "lines" units (proportional to weight).
#' @param col   Character; fill colour.  Defaults to \code{"black"}.
#' @param col_border Character; border colour.  Defaults to \code{"black"}.
#'
#' @keywords internal
draw_square <- function(x_pos, size, col = "black", col_border = "black") {
  grid::grid.rect(
    x      = grid::unit(x_pos, "native"),
    y      = grid::unit(0.5, "npc"),
    width  = grid::unit(size, "lines"),
    height = grid::unit(size, "lines"),
    just   = "centre",
    gp     = grid::gpar(fill = col, col = col_border)
  )
}

#' Draw a pooled-estimate diamond (internal)
#'
#' Draws a 4-point polygon (diamond) spanning from \code{lb} to \code{ub}
#' on the x-axis, centred at the y midpoint.  Must be called inside a
#' viewport with an xscale set.
#'
#' @param lb  Numeric; left x position (lower CI bound) in native coordinates.
#' @param est Numeric; centre x position (estimate) in native coordinates.
#' @param ub  Numeric; right x position (upper CI bound) in native coordinates.
#' @param hh  Numeric; half-height of diamond as a fraction of npc height.
#'   Defaults to \code{0.35}.
#' @param col       Character; fill colour.  Defaults to \code{"darkgray"}.
#' @param col_border Character; border colour.  Defaults to \code{"black"}.
#'
#' @keywords internal
draw_diamond <- function(lb, est, ub, hh = 0.35, y_center = 0.5,
                         col = "darkgray", col_border = "black") {
  grid::grid.polygon(
    x  = grid::unit(c(lb, est, ub, est), "native"),
    y  = grid::unit(c(y_center, y_center + hh, y_center, y_center - hh), "npc"),
    gp = grid::gpar(fill = col, col = col_border)
  )
}

#' Draw a confidence interval line (internal)
#'
#' Draws a horizontal segment from \code{lb} to \code{ub} at y = 0.5 npc.
#' Must be called inside a viewport with an xscale set.
#'
#' @param lb  Numeric; left endpoint in native coordinates.
#' @param ub  Numeric; right endpoint in native coordinates.
#' @param lwd Numeric; line width.  Defaults to \code{1}.
#' @param col Character; line colour.  Defaults to \code{"black"}.
#'
#' @keywords internal
draw_ci_line <- function(lb, ub, lwd = 1, col = "black") {
  grid::grid.segments(
    x0 = grid::unit(lb, "native"),
    x1 = grid::unit(ub, "native"),
    y0 = grid::unit(0.5, "npc"),
    y1 = grid::unit(0.5, "npc"),
    gp = grid::gpar(lwd = lwd, col = col)
  )
}

#' Draw a full-width zebra shading rectangle (internal)
#'
#' Draws a full-width, full-height filled rectangle over the current viewport.
#' Use for alternating row shading.
#'
#' @param colshade Character; fill colour.  Defaults to
#'   \code{rgb(0.92, 0.92, 0.92)}.
#'
#' @importFrom grDevices rgb
#' @keywords internal
draw_zebra_rect <- function(colshade = rgb(0.92, 0.92, 0.92)) {
  grid::grid.rect(
    x      = grid::unit(0.5, "npc"),
    y      = grid::unit(0.5, "npc"),
    width  = grid::unit(1, "npc"),
    height = grid::unit(1, "npc"),
    gp     = grid::gpar(fill = colshade, col = NA)
  )
}

# ---------------------------------------------------------------------------
# File path resolution
# ---------------------------------------------------------------------------

#' Resolve output file path for forest plot (internal)
#'
#' Resolves the file path for saving the forest plot based on a sentinel
#' \code{file} argument, the result object's \code{name} field, the active
#' \code{meta3l.mwd} option, the desired \code{format}, and an optional
#' \code{suffix} for Phase 3 filename patterns.
#'
#' @param x      A \code{meta3l_result} object (must have a \code{name} field).
#' @param file   One of: \code{NULL} (display only, return \code{NULL});
#'   \code{character(0)} (sentinel for auto-name); or a character string
#'   (returned as-is).
#' @param format Character string; file extension, e.g. \code{"png"} or
#'   \code{"pdf"}.
#' @param suffix Character string; optional suffix appended to the base name
#'   with an underscore separator before the file extension.  For example,
#'   \code{suffix = "subgroup_drug"} produces
#'   \code{"{name}_subgroup_drug.{format}"}.  Defaults to \code{""} (no
#'   suffix), which preserves backward-compatible behaviour.
#'
#' @return A character string (file path) or \code{NULL}.
#'
#' @keywords internal
resolve_file <- function(x, file, format, suffix = "") {
  # NULL: display only
  if (is.null(file)) {
    return(NULL)
  }

  # Explicit string: pass through unchanged
  if (length(file) == 1L && nchar(file) > 0L) {
    return(file)
  }

  # character(0) sentinel: auto-assemble from name + suffix + mwd + format
  base_name <- if (!is.null(x$name) && nchar(x$name) > 0L) {
    x$name
  } else {
    "meta3l_plot"
  }

  fname <- if (nchar(suffix) > 0L) paste0(base_name, "_", suffix) else base_name

  dir_path <- getOption("meta3l.mwd", default = getwd())
  file.path(dir_path, paste0(fname, ".", format))
}

# ---------------------------------------------------------------------------
# Auto-dimension calculator
# ---------------------------------------------------------------------------

#' Compute default plot dimensions from study count (internal)
#'
#' Returns a list with \code{width} and \code{height} in pixels.  Height is
#' scaled by the number of studies (floor at 800 px).
#'
#' @param n      Integer; number of studies.
#' @param user_w Integer or NULL; user-supplied width override.
#' @param user_h Integer or NULL; user-supplied height override.
#'
#' @return A named list with elements \code{width} and \code{height}.
#'
#' @keywords internal
auto_dims <- function(n, user_w = NULL, user_h = NULL, n_ilab = 0L,
                      has_wrapped = FALSE) {
  row_px <- if (has_wrapped) 120L else 80L
  list(
    width  = if (!is.null(user_w)) user_w else 3000L + as.integer(n_ilab) * 200L,
    height = if (!is.null(user_h)) user_h else max(900L, 400L + n * row_px)
  )
}

# ---------------------------------------------------------------------------
# Auto x-axis limits
# ---------------------------------------------------------------------------

#' Compute default x-axis limits from measure and data (internal)
#'
#' Returns an appropriate \code{xlim} vector for the CI axis.
#'
#' @param measure  Character string; one of \code{"PLO"}, \code{"PAS"},
#'   \code{"SMD"}, \code{"MD"}, \code{"RR"}, \code{"OR"}.
#' @param yi       Numeric vector of back-transformed effect size estimates.
#' @param ci_lb    Numeric vector of back-transformed lower confidence limits.
#' @param ci_ub    Numeric vector of back-transformed upper confidence limits.
#'
#' @return A length-2 numeric vector \code{c(lower, upper)}.
#'
#' @keywords internal
auto_xlim <- function(measure, yi, ci_lb, ci_ub) {
  if (measure %in% c("PLO", "PAS")) {
    return(c(0, 1))
  }

  all_vals <- c(yi, ci_lb, ci_ub)
  all_vals <- all_vals[is.finite(all_vals)]

  if (measure %in% c("SMD", "MD")) {
    # Symmetric around 0
    half <- max(abs(all_vals)) * 1.05
    return(c(-half, half))
  }

  if (measure %in% c("RR", "OR")) {
    # Log scale: ensure lower > 0, add 5% margin
    lower <- max(0.001, min(all_vals) * 0.95)
    upper <- max(all_vals) * 1.05
    return(c(lower, upper))
  }

  # Fallback: raw range with margin
  margin <- diff(range(all_vals)) * 0.05
  c(min(all_vals) - margin, max(all_vals) + margin)
}

# ---------------------------------------------------------------------------
# Auto reference line
# ---------------------------------------------------------------------------

#' Compute default reference line position from measure (internal)
#'
#' @param measure Character string; one of \code{"PLO"}, \code{"PAS"},
#'   \code{"SMD"}, \code{"MD"}, \code{"RR"}, \code{"OR"}.
#'
#' @return A numeric scalar or \code{NULL}.
#'
#' @keywords internal
auto_refline <- function(measure) {
  if (measure %in% c("PLO", "PAS")) {
    return(NULL)
  }
  if (measure %in% c("SMD", "MD")) {
    return(0)
  }
  if (measure %in% c("RR", "OR")) {
    return(1)
  }
  NULL
}

# ---------------------------------------------------------------------------
# Model label formatter
# ---------------------------------------------------------------------------

#' Format the heterogeneity label for the pooled row (internal)
#'
#' @param i2 Named list with numeric elements \code{total}, \code{between},
#'   and \code{within} (all percentages, 0-100).
#'
#' @return A character string with the format
#'   \sQuote{RE Model | I^2 = 85\% (between: 60\%, within: 25\%)}.
#'
#' @keywords internal
format_mlab <- function(i2) {
  sprintf(
    "I\u00b2 = %.0f%% (between: %.0f%%, within: %.0f%%)",
    i2$total,
    i2$between,
    i2$within
  )
}

# ---------------------------------------------------------------------------
# Aggregate ilab column for pooled/summary rows
# ---------------------------------------------------------------------------

#' Aggregate a numeric ilab column for display on a summary row (internal)
#'
#' Sample-size and event columns are summed once per cluster.
#' Mean columns are weighted-averaged by corresponding n.
#' SD columns are pooled using the standard pooled-SD formula.
#' Non-numeric columns return an empty string.
#'
#' @param values  Vector of column values (subset of rows to aggregate).
#' @param col_name Character; column name used to determine aggregation type.
#' @param cluster Vector of cluster identifiers (same length as \code{values}).
#' @param data    Data frame (same rows as \code{values}); needed for mean/SD
#'   aggregation to look up the corresponding n column.
#' @return A character string suitable for display.
#' @keywords internal
aggregate_ilab_col <- function(values, col_name, cluster, data = NULL) {
  if (!is.numeric(values)) return("")
  if (length(values) == 0L || all(is.na(values))) return("")

  is_n     <- grepl("^n[._]|^n$|^ni$|total", col_name, ignore.case = TRUE)
  is_event <- grepl("^xi$|^event", col_name, ignore.case = TRUE)
  is_mean  <- grepl("^mean[._]", col_name, ignore.case = TRUE)
  is_sd    <- grepl("^sd[._]", col_name, ignore.case = TRUE)

  uclust <- unique(cluster)

  if (is_n || is_event) {
    # Sum first value per cluster
    total <- 0
    for (cl in uclust) total <- total + values[cluster == cl][1L]
    return(as.character(as.integer(total)))
  }

  if (is_mean && !is.null(data)) {
    n_col <- sub("^mean", "n", col_name)
    if (n_col %in% names(data)) {
      n_vals <- data[[n_col]]
      sum_wm <- 0; sum_n <- 0
      for (cl in uclust) {
        mask <- cluster == cl
        sum_wm <- sum_wm + values[mask][1L] * n_vals[mask][1L]
        sum_n  <- sum_n  + n_vals[mask][1L]
      }
      if (sum_n > 0) return(sprintf("%.1f", sum_wm / sum_n))
    }
    return("")
  }

  if (is_sd && !is.null(data)) {
    n_col <- sub("^sd", "n", col_name)
    if (n_col %in% names(data)) {
      n_vals <- data[[n_col]]
      sum_var <- 0; sum_df <- 0
      for (cl in uclust) {
        mask <- cluster == cl
        s <- values[mask][1L]; n <- n_vals[mask][1L]
        sum_var <- sum_var + (n - 1) * s^2
        sum_df  <- sum_df  + (n - 1)
      }
      if (sum_df > 0) return(sprintf("%.1f", sqrt(sum_var / sum_df)))
    }
    return("")
  }

  return("")
}

# ---------------------------------------------------------------------------
# Text wrapping for ilab columns
# ---------------------------------------------------------------------------

#' Wrap long text at the closest space or parenthesis to the midpoint (internal)
#'
#' @param txt Character vector of labels to wrap.
#' @param max_chars Integer; strings longer than this are split into two lines.
#' @return Character vector with \code{"\\n"} inserted at the split point.
#' @keywords internal
wrap_label <- function(txt, max_chars = 15L) {
  vapply(as.character(txt), function(t) {
    if (is.na(t)) return("")
    # Priority 1: if the label contains a parenthesised qualifier, push it to
    # a new line regardless of total length. This is the most common header
    # pattern (e.g. "Follow-up (days)", "PCPC (mean)") and visually groups the
    # qualifier under its label.
    paren_pos <- regexpr("\\(", t)[[1L]]
    if (paren_pos > 1L) {
      head <- trimws(substr(t, 1L, paren_pos - 1L))
      tail <- substr(t, paren_pos, nchar(t))
      return(paste0(head, "\n", tail))
    }
    # Priority 2: split at the space closest to the midpoint when the string
    # is longer than the max_chars threshold
    if (nchar(t) <= max_chars) return(t)
    mid <- nchar(t) / 2
    pos <- gregexpr("[ ]", t)[[1L]]
    if (pos[1L] == -1L) return(t)
    best <- pos[which.min(abs(pos - mid))]
    paste0(substr(t, 1L, best - 1L), "\n", substr(t, best + 1L, nchar(t)))
  }, character(1L), USE.NAMES = FALSE)
}

# ---------------------------------------------------------------------------
# Abbreviation extraction for questionnaire / scale names
# ---------------------------------------------------------------------------

#' Extract abbreviation from questionnaire or scale names
#'
#' Searches for an existing all-uppercase abbreviation token (e.g.
#' \code{"SRS"}, \code{"CBCL"}, \code{"PEP-3"}) in the text.  If none is
#' found, strips parenthesized descriptors and builds an acronym from the
#' first letters of significant words (excluding common articles and
#' prepositions).
#'
#' @param txt Character vector of scale / questionnaire names.
#' @return Character vector of abbreviations, same length as \code{txt}.
#'
#' @examples
#' extract_abbrev(c(
#'   "Aberrant Behavior Checklist (raw score)",
#'   "Social Responsiveness Scale SRS (T-score)",
#'   "CBCL (Child Behavior Checklist) T-score",
#'   "PEP-3"
#' ))
#' # => c("ABC", "SRS", "CBCL", "PEP-3")
#'
#' @export
extract_abbrev <- function(txt) {
  vapply(as.character(txt), function(t) {
    if (is.na(t) || nchar(t) == 0L) return("")
    # Look for existing all-caps abbreviation (2+ uppercase letters,
    # optionally followed by hyphens/digits, e.g. "SRS", "CBCL", "PEP-3")
    m <- regmatches(t, gregexpr("[A-Z][A-Z0-9][-A-Z0-9]*", t))[[1L]]
    if (length(m) > 0L) return(m[which.max(nchar(m))])
    # Strip parenthesized content and trailing whitespace
    clean <- trimws(gsub("\\([^)]*\\)", "", t))
    # Acronym from first letters of significant words
    words <- strsplit(clean, "\\s+")[[1L]]
    skip  <- c("the", "of", "for", "and", "in", "a", "an", "to", "with", "by")
    words <- words[!tolower(words) %in% skip]
    if (length(words) == 0L) return(t)
    paste0(toupper(substr(words, 1L, 1L)), collapse = "")
  }, character(1L), USE.NAMES = FALSE)
}

# ---------------------------------------------------------------------------
# Column width helper
# ---------------------------------------------------------------------------

#' Compute ilab column width from character count (internal)
#'
#' @param max_chars Integer; maximum character count across all wrapped lines
#'   in the column (including the header label).
#' @return Numeric; column width in cm.
#' @keywords internal
ilab_col_cm <- function(max_chars) {
  max(1.2, max_chars * 0.13 + 0.3)
}

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
draw_diamond <- function(lb, est, ub, hh = 0.35,
                         col = "darkgray", col_border = "black") {
  grid::grid.polygon(
    x  = grid::unit(c(lb, est, ub, est), "native"),
    y  = grid::unit(c(0.5, 0.5 + hh, 0.5, 0.5 - hh), "npc"),
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
#' \code{meta3l.mwd} option, and the desired \code{format}.
#'
#' @param x      A \code{meta3l_result} object (must have a \code{name} field).
#' @param file   One of: \code{NULL} (display only, return \code{NULL});
#'   \code{character(0)} (sentinel for auto-name); or a character string
#'   (returned as-is).
#' @param format Character string; file extension, e.g. \code{"png"} or
#'   \code{"pdf"}.
#'
#' @return A character string (file path) or \code{NULL}.
#'
#' @keywords internal
resolve_file <- function(x, file, format) {
  # NULL: display only
  if (is.null(file)) {
    return(NULL)
  }

  # Explicit string: pass through unchanged
  if (length(file) == 1L && nchar(file) > 0L) {
    return(file)
  }

  # character(0) sentinel: auto-assemble from name + mwd + format
  base_name <- if (!is.null(x$name) && nchar(x$name) > 0L) {
    x$name
  } else {
    "forest_plot"
  }

  dir_path <- getOption("meta3l.mwd", default = getwd())
  file.path(dir_path, paste0(base_name, ".", format))
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
auto_dims <- function(n, user_w = NULL, user_h = NULL) {
  list(
    width  = if (!is.null(user_w)) user_w else 3000L,
    height = if (!is.null(user_h)) user_h else max(800L, 200L + n * 80L)
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
#' @return A character string, e.g.
#'   \code{"RE Model  |  I\u00b2 = 85% (between: 60%, within: 25%)"}.
#'
#' @keywords internal
format_mlab <- function(i2) {
  sprintf(
    "RE Model  |  I\u00b2 = %.0f%% (between: %.0f%%, within: %.0f%%)",
    i2$total,
    i2$between,
    i2$within
  )
}

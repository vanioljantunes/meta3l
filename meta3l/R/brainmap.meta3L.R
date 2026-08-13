# brainmap.meta3L.R - Colour a 2D brain slice by the pooled effect of each
# region collected in a meta3l_bind object.
#
# Geometry comes from the FreeSurfer subcortical segmentation shipped by ggseg
# (see https://drmowinckels.io/blog/2020/using-freesurfer-annotation-files-to-plot-in-r/).
# Nuclei that segmentation does not label separately - substantia nigra and red
# nucleus live inside VentralDC - are drawn as schematic ellipses anchored to
# the VentralDC polygon of each hemisphere, so every analysed region can carry a
# colour on one figure.

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

#' Normalise a region name for matching (internal)
#'
#' Lower-cases, drops punctuation and the generic anatomical words that differ
#' between an analysis label and an atlas label (\dQuote{nucleus},
#' \dQuote{globus}, \dQuote{proper}, ...).
#'
#' @param s Character vector.
#' @return Character vector of match keys.
#' @keywords internal
bm_key <- function(s) {
  s <- tolower(as.character(s))
  s <- gsub("[^a-z ]+", " ", s)
  s <- gsub("\\b(nucleus|nuclei|globus|proper|area|region|left|right)\\b", " ", s)
  s <- gsub("pallidus|pallidum|pallidal", "pallid", s)
  s <- gsub("\\s+", " ", s)
  trimws(s)
}

#' Build an ellipse as an sf polygon (internal)
#'
#' @param cx,cy Numeric; centre.
#' @param rx,ry Numeric; radii.
#' @param n     Integer; number of vertices.
#' @return An \code{sfc} geometry of length one.
#' @keywords internal
bm_ellipse <- function(cx, cy, rx, ry, n = 72L) {
  th <- seq(0, 2 * pi, length.out = n)
  m  <- cbind(cx + rx * cos(th), cy + ry * sin(th))
  m[n, ] <- m[1L, ]
  sf::st_sfc(sf::st_polygon(list(m)))
}

#' Place the schematic midbrain nuclei relative to VentralDC (internal)
#'
#' @param slice sf data frame of the chosen atlas view.
#' @param names Character vector of the schematic region names to place, in the
#'   order \code{c(red_nucleus, substantia_nigra)}.
#' @return An sf data frame with columns \code{region} and \code{geometry}, two
#'   rows per name (one per hemisphere), or \code{NULL} when the anchor is
#'   missing.
#' @keywords internal
bm_schematic <- function(slice, names) {
  # The midbrain sits at the brainstem, so anchor there when the slice has it
  # and fall back to VentralDC otherwise.
  bs <- slice[bm_key(slice$region) == "brain stem", , drop = FALSE]
  if (nrow(bs) > 0L) {
    bb <- sf::st_bbox(sf::st_geometry(bs))
    w  <- (bb[["xmax"]] - bb[["xmin"]]) / 2
    h  <- bb[["ymax"]] - bb[["ymin"]]
    cx <- mean(c(bb[["xmin"]], bb[["xmax"]]))
    cy <- mean(c(bb[["ymin"]], bb[["ymax"]]))
    centres <- data.frame(
      hemi = c("left", "right"),
      x    = c(cx - w / 2, cx + w / 2),
      y    = c(cy, cy),
      w    = c(w, w),
      h    = c(h, h),
      stringsAsFactors = FALSE
    )
  } else {
    anchor <- slice[bm_key(slice$region) == "ventraldc" &
                      !is.na(slice$hemi), , drop = FALSE]
    if (nrow(anchor) == 0L) return(NULL)
    centres <- do.call(rbind, lapply(seq_len(nrow(anchor)), function(i) {
      bb <- sf::st_bbox(sf::st_geometry(anchor[i, ]))
      data.frame(hemi = as.character(anchor$hemi[i]),
                 x = mean(c(bb[["xmin"]], bb[["xmax"]])),
                 y = mean(c(bb[["ymin"]], bb[["ymax"]])),
                 w = bb[["xmax"]] - bb[["xmin"]],
                 h = bb[["ymax"]] - bb[["ymin"]],
                 stringsAsFactors = FALSE)
    }))
  }
  midline <- mean(centres$x)

  out <- list()
  for (i in seq_len(nrow(centres))) {
    cc   <- centres[i, ]
    sign <- if (cc$x < midline) 1 else -1   # positive points towards midline
    # Red nucleus: medial and slightly anterior within VentralDC.
    # Substantia nigra: lateral and slightly posterior to it.
    specs <- list(
      list(nm = names[1L], cx = cc$x + sign * 0.22 * cc$w,
           cy = cc$y + 0.18 * cc$h, rx = 0.26 * cc$w, ry = 0.22 * cc$h),
      list(nm = names[2L], cx = cc$x - sign * 0.26 * cc$w,
           cy = cc$y - 0.30 * cc$h, rx = 0.34 * cc$w, ry = 0.20 * cc$h)
    )
    for (sp in specs) {
      if (is.na(sp$nm)) next
      out[[length(out) + 1L]] <- sf::st_sf(
        region   = sp$nm,
        hemi     = cc$hemi,
        geometry = bm_ellipse(sp$cx, sp$cy, sp$rx, sp$ry)
      )
    }
  }
  if (length(out) == 0L) return(NULL)
  do.call(rbind, out)
}

#' Lay the numbered key out in rows (internal)
#'
#' @param nums   Integer vector of marker numbers.
#' @param labels Character vector of region names.
#' @return A data frame with the row, x offset and width of each item, in mm.
#' @keywords internal
bm_key_layout <- function(nums, labels) {
  disc  <- 3.4     # marker diameter, mm
  gap   <- 1.4     # marker to text, mm
  space <- 7.0     # between items, mm
  avail <- as.numeric(grid::convertWidth(grid::unit(1, "npc"), "mm")) - 8

  tw <- vapply(labels, function(l) {
    as.numeric(grid::convertWidth(grid::stringWidth(l), "mm")) * 0.72
  }, numeric(1L))
  item_w <- disc + gap + tw

  row <- integer(length(nums))
  xo  <- numeric(length(nums))
  cur_row <- 1L
  cur_x   <- 0
  for (i in seq_along(nums)) {
    if (cur_x > 0 && cur_x + item_w[i] > avail) {
      cur_row <- cur_row + 1L
      cur_x   <- 0
    }
    row[i] <- cur_row
    xo[i]  <- cur_x
    cur_x  <- cur_x + item_w[i] + space
  }
  row_w <- vapply(split(seq_along(nums), row),
                  function(ix) max(xo[ix] + item_w[ix]), numeric(1L))
  data.frame(num = nums, label = labels, row = row, x = xo,
             item_w = item_w, row_w = unname(row_w[as.character(row)]),
             disc = disc, gap = gap, stringsAsFactors = FALSE)
}

#' Number of lines the numbered key needs (internal)
#'
#' @param labels Character vector of region names.
#' @return Integer.
#' @keywords internal
bm_key_rows <- function(labels) {
  max(bm_key_layout(seq_along(labels), labels)$row)
}

#' Draw the numbered key, centred in the current viewport (internal)
#'
#' Repeats the marker used on the map - a white disc carrying the region
#' number - so the key reads as the same object rather than as plain text.
#'
#' @param nums   Integer vector of marker numbers.
#' @param labels Character vector of region names.
#' @return Invisibly \code{NULL}; called for the drawing.
#' @keywords internal
bm_draw_key <- function(nums, labels) {
  lay    <- bm_key_layout(nums, labels)
  n_rows <- max(lay$row)
  for (i in seq_len(nrow(lay))) {
    y  <- grid::unit(1 - (lay$row[i] - 0.5) / n_rows, "npc")
    x0 <- grid::unit(0.5, "npc") - grid::unit(lay$row_w[i] / 2, "mm") +
      grid::unit(lay$x[i], "mm")
    grid::grid.circle(x = x0 + grid::unit(lay$disc[i] / 2, "mm"), y = y,
                      r = grid::unit(lay$disc[i] / 2, "mm"),
                      gp = grid::gpar(fill = "white", col = "grey15",
                                      lwd = 0.7))
    grid::grid.text(lay$num[i], x = x0 + grid::unit(lay$disc[i] / 2, "mm"),
                    y = y, gp = grid::gpar(cex = 0.5, col = "grey10"))
    grid::grid.text(lay$label[i],
                    x = x0 + grid::unit(lay$disc[i] + lay$gap[i], "mm"),
                    y = y, just = "left",
                    gp = grid::gpar(cex = 0.72, col = "grey20"))
  }
  invisible(NULL)
}

# ---------------------------------------------------------------------------
# Generic
# ---------------------------------------------------------------------------

#' Brain map of pooled regional effects
#'
#' @param x An object holding one pooled estimate per anatomical region.
#' @param ... Passed to the method.
#'
#' @return Invisibly, the file path of the saved plot (or \code{NULL} when
#'   \code{file = NULL}).
#'
#' @export
brainmap <- function(x, ...) UseMethod("brainmap")

# ---------------------------------------------------------------------------
# Method for meta3l_bind
# ---------------------------------------------------------------------------

#' @param view Character; atlas view to draw.  One of the views of
#'   \code{ggseg::aseg()}; \code{"axial_5"} (default) is the slice that carries
#'   caudate, putamen, pallidum, thalamus and VentralDC together.
#' @param panels Character vector selecting what each panel shows: the keyword
#'   \code{"Overall"} for the pooled estimate of every analysis, or the label of
#'   a subgroup level present in the object (e.g. \code{"Neuro Wilson"}).
#'   \code{NULL} (default) draws a single overall panel.  All panels share one
#'   colour scale so they can be compared.
#' @param panel.labs Character vector of panel titles, one per entry of
#'   \code{panels}.  \code{NULL} (default) uses the panel keys themselves.
#' @param palette Character; \pkg{MetBrewer} palette name.  Defaults to
#'   \code{"Okeeffe1"}.
#' @param direction \code{1} (default) or \code{-1}; flips the palette.
#' @param value One of \code{"estimate"} (default) or \code{"abs"}; \code{"abs"}
#'   colours by the magnitude of the effect regardless of sign.
#' @param scale One of \code{"sequential"} (default) or \code{"diverging"}.
#'   Most MetBrewer palettes are diverging, so their two ends are both dark and
#'   a weak effect would look as strong as a large one; \code{"sequential"}
#'   uses one arm of the palette, pale to dark, so a stronger colour always
#'   means a larger effect.
#' @param limits Numeric length 2; colour scale limits.  \code{NULL}
#'   auto-computes from the data.
#' @param region.map Named character vector mapping analysis labels to atlas
#'   region names, for labels the automatic matcher cannot resolve.  Names are
#'   the analysis labels.
#' @param schematic Character vector of length 2 giving the analysis labels to
#'   draw as midbrain ellipses, in the order red nucleus, substantia nigra.
#'   \code{NULL} (default) auto-detects them from the labels.  Use \code{NA} in
#'   a slot to skip it, or \code{character(0)} to draw none.
#' @param labels One of \code{"number"} (default), \code{"name"} or
#'   \code{"none"}.  \code{"number"} marks each coloured region with a small
#'   numbered disc and lists the numbers under the figure, which keeps long
#'   anatomical names off the slice; \code{"name"} writes the name on the
#'   region itself.  \code{TRUE} and \code{FALSE} are accepted as synonyms of
#'   \code{"name"} and \code{"none"}.
#' @param legend.title Character; legend title.  \code{NULL} derives it from the
#'   measure.
#' @param title Character; plot title.
#' @param caption Character; caption under the plot.  \code{TRUE} (default)
#'   states that the midbrain nuclei are schematic, \code{FALSE} omits it.
#' @param file One of: \code{character(0)} (default, auto-name); \code{NULL}
#'   (return the plot, draw nothing); or an explicit file path.
#' @param format Character; \code{"png"} (default) or \code{"pdf"}.
#' @param width,height Integer; output size in pixels.  \code{NULL}
#'   auto-computes.
#'
#' @details
#' Requires the suggested packages \pkg{ggseg}, \pkg{ggplot2}, \pkg{sf} and
#' \pkg{MetBrewer}.
#'
#' Only the analyses whose labels resolve to a region of the slice are coloured;
#' the rest of the slice stays neutral grey, and unmatched analyses are reported
#' in a warning.
#'
#' @rdname brainmap
#' @method brainmap meta3l_bind
#' @export
brainmap.meta3l_bind <- function(x,
                                 view         = "axial_5",
                                 panels       = NULL,
                                 panel.labs   = NULL,
                                 palette      = "Okeeffe1",
                                 direction    = 1,
                                 value        = c("estimate", "abs"),
                                 scale        = c("sequential", "diverging"),
                                 limits       = NULL,
                                 region.map   = NULL,
                                 schematic    = NULL,
                                 labels       = c("number", "name", "none"),
                                 legend.title = NULL,
                                 title        = NULL,
                                 caption      = TRUE,
                                 file         = character(0),
                                 format       = "png",
                                 width        = NULL,
                                 height       = NULL,
                                 ...) {

  stopifnot(inherits(x, "meta3l_bind"))
  value <- match.arg(value)
  scale <- match.arg(scale)
  if (isTRUE(labels))  labels <- "name"
  if (isFALSE(labels)) labels <- "none"
  labels <- match.arg(labels, c("number", "name", "none"))

  need <- c("ggseg", "ggplot2", "sf", "MetBrewer")
  miss <- need[!vapply(need, requireNamespace, logical(1L), quietly = TRUE)]
  if (length(miss) > 0L) {
    stop("brainmap() needs the package(s) ", paste(miss, collapse = ", "),
         ". Install with install.packages(c(",
         paste0("\"", miss, "\"", collapse = ", "), ")).", call. = FALSE)
  }

  # --- 1. One pooled estimate per analysis, per panel ----------------------
  r <- x$rows
  if (is.null(panels)) panels <- "Overall"

  panel_rows <- function(key) {
    if (identical(key, "Overall")) {
      r[r$type == "row" & r$kind == "overall", , drop = FALSE]
    } else {
      r[r$type == "row" & r$kind == "level" & r$label == key, , drop = FALSE]
    }
  }

  parts <- lapply(panels, function(key) {
    rows <- panel_rows(key)
    if (nrow(rows) == 0L) {
      warning("No rows for panel '", key, "'; skipped.", call. = FALSE)
      return(NULL)
    }
    data.frame(panel = key,
               label = rows$block,
               est   = if (identical(value, "abs")) abs(rows$est) else rows$est,
               stringsAsFactors = FALSE)
  })
  parts <- parts[!vapply(parts, is.null, logical(1L))]
  if (length(parts) == 0L) {
    stop("None of the requested panels has any pooled row.", call. = FALSE)
  }
  dat_all <- do.call(rbind, parts)

  panel_keys <- unique(dat_all$panel)
  panel_show <- if (!is.null(panel.labs)) {
    if (length(panel.labs) != length(panels)) {
      stop("`panel.labs` must have one entry per panel (", length(panels),
           "); got ", length(panel.labs), ".", call. = FALSE)
    }
    stats::setNames(panel.labs, panels)[panel_keys]
  } else {
    stats::setNames(panel_keys, panel_keys)
  }
  dat_all$panel <- factor(unname(panel_show[dat_all$panel]),
                          levels = unname(panel_show))

  # --- 2. Atlas slice -------------------------------------------------------
  atlas <- as.data.frame(ggseg::aseg())
  if (!view %in% atlas$view) {
    stop("View '", view, "' not in the atlas; available: ",
         paste(unique(atlas$view), collapse = ", "), ".", call. = FALSE)
  }
  slice0 <- sf::st_as_sf(atlas[atlas$view == view, , drop = FALSE])
  slice0 <- slice0[!sf::st_is_empty(sf::st_geometry(slice0)), , drop = FALSE]

  # --- 3. Which labels are drawn as schematic midbrain nuclei --------------
  all_labels <- unique(dat_all$label)
  if (is.null(schematic)) {
    rn <- all_labels[grepl("red", all_labels, ignore.case = TRUE)]
    sn <- all_labels[grepl("nigra", all_labels, ignore.case = TRUE)]
    schematic <- c(if (length(rn) > 0L) rn[1L] else NA_character_,
                   if (length(sn) > 0L) sn[1L] else NA_character_)
  }
  schem_labels <- schematic[!is.na(schematic)]

  # --- 4. Match the remaining labels to atlas regions ----------------------
  atlas_regions <- unique(as.character(slice0$region))
  atlas_regions <- atlas_regions[!is.na(atlas_regions)]
  atlas_keys    <- bm_key(atlas_regions)
  resolve <- function(lbl) {
    if (!is.null(region.map) && lbl %in% names(region.map)) {
      return(unname(region.map[[lbl]]))
    }
    k <- bm_key(lbl)
    hit <- atlas_regions[which(atlas_keys == k)]
    if (length(hit) > 0L) return(hit[1L])
    hit <- atlas_regions[which(vapply(atlas_keys, function(a)
      nzchar(a) && (grepl(a, k, fixed = TRUE) || grepl(k, a, fixed = TRUE)),
      logical(1L)))]
    if (length(hit) > 0L) return(hit[1L])
    NA_character_
  }

  key_tab <- data.frame(
    label  = all_labels,
    num    = seq_along(all_labels),
    schem  = all_labels %in% schem_labels,
    stringsAsFactors = FALSE
  )
  key_tab$region <- vapply(seq_len(nrow(key_tab)), function(i) {
    if (key_tab$schem[i]) key_tab$label[i] else resolve(key_tab$label[i])
  }, character(1L))

  unmatched <- key_tab$label[is.na(key_tab$region)]
  if (length(unmatched) > 0L) {
    warning("No atlas region for: ", paste(unmatched, collapse = ", "),
            ". Use region.map = c(\"", unmatched[1L],
            "\" = \"<atlas region>\") or schematic = to place them.",
            call. = FALSE)
  }

  schem0 <- if (any(key_tab$schem)) bm_schematic(slice0, schematic) else NULL

  # --- 5. One copy of the geometry per panel, carrying that panel's values --
  atlas_parts <- list()
  schem_parts <- list()
  for (pl in levels(dat_all$panel)) {
    d <- dat_all[dat_all$panel == pl, , drop = FALSE]
    d <- merge(d, key_tab, by = "label", all.x = TRUE)

    keyed <- d[!d$schem & !is.na(d$region), , drop = FALSE]
    sl <- slice0
    idx <- match(bm_key(sl$region), bm_key(keyed$region))
    sl$eff   <- keyed$est[idx]
    sl$lab   <- keyed$label[idx]
    sl$num   <- keyed$num[idx]
    sl$panel <- pl
    atlas_parts[[length(atlas_parts) + 1L]] <- sl

    if (!is.null(schem0)) {
      sc  <- schem0
      dsc <- d[d$schem & !is.na(d$est), , drop = FALSE]
      j   <- match(sc$region, dsc$label)
      sc$eff   <- dsc$est[j]
      sc$lab   <- sc$region
      sc$num   <- dsc$num[j]
      sc$panel <- pl
      sc <- sc[!is.na(sc$eff), , drop = FALSE]
      if (nrow(sc) > 0L) schem_parts[[length(schem_parts) + 1L]] <- sc
    }
  }
  slice <- do.call(rbind, atlas_parts)
  slice$panel <- factor(slice$panel, levels = levels(dat_all$panel))
  schem_sf <- if (length(schem_parts) > 0L) do.call(rbind, schem_parts) else NULL
  if (!is.null(schem_sf)) {
    schem_sf$panel <- factor(schem_sf$panel, levels = levels(dat_all$panel))
  }

  # --- 6. Colour scale ------------------------------------------------------
  pal_names <- names(MetBrewer::MetPalettes)
  pal_hit   <- pal_names[tolower(pal_names) == tolower(palette)]
  if (length(pal_hit) == 0L) {
    stop("Unknown MetBrewer palette '", palette, "'. Available: ",
         paste(pal_names, collapse = ", "), ".", call. = FALSE)
  }
  cols <- MetBrewer::met.brewer(pal_hit[1L], n = 512L, type = "continuous")
  if (identical(scale, "sequential")) {
    # Okeeffe1 and friends are diverging: taken end to end, both extremes are
    # dark, so a large and a small effect would read the same.  One arm of the
    # palette, pale to dark, keeps "darker = larger" true.
    cols <- rev(cols[seq_len(length(cols) / 2)])
  }
  if (direction < 0) cols <- rev(cols)
  vals <- c(slice$eff, if (!is.null(schem_sf)) schem_sf$eff)
  vals <- vals[is.finite(vals)]
  # One scale across every panel, otherwise the panels cannot be compared
  lims <- if (!is.null(limits)) limits else range(vals, na.rm = TRUE)

  if (is.null(legend.title)) {
    legend.title <- switch(x$measure,
                           MD  = "Mean difference",
                           SMD = "Standardised mean difference",
                           RR  = "Risk ratio",
                           OR  = "Odds ratio",
                           "Effect")
  }

  n_panels <- length(levels(dat_all$panel))
  w <- if (!is.null(width))  width  else as.integer(1500 * n_panels + 900)
  h <- if (!is.null(height)) height else 1800L

  key_tab_shown <- NULL
  if (identical(labels, "number")) {
    key_tab_shown <- key_tab[!is.na(key_tab$region), , drop = FALSE]
    key_tab_shown <- key_tab_shown[order(key_tab_shown$num), , drop = FALSE]
    if (nrow(key_tab_shown) == 0L) key_tab_shown <- NULL
  }

  cap <- NULL
  if (isTRUE(caption)) {
    if (!is.null(schem_sf) && nrow(schem_sf) > 0L) {
      cap <- paste0("Subcortical geometry from the FreeSurfer segmentation ",
                    "(ggseg, ", view, "). ",
                    paste(unique(schem_sf$region), collapse = " and "),
                    " are drawn schematically: the segmentation does not ",
                    "label them separately.")
    } else {
      cap <- paste0("Subcortical geometry from the FreeSurfer segmentation ",
                    "(ggseg, ", view, ").")
    }
  } else if (is.character(caption)) {
    cap <- caption
  }
  # The key runs the full width of the figure: roughly 20 characters per inch
  # at the caption size
  wrap_at <- max(60L, as.integer(w / 300 * 20))
  if (!is.null(cap)) cap <- paste(strwrap(cap, width = wrap_at),
                                  collapse = "\n")

  # --- 7. Assemble the plot -------------------------------------------------
  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = slice,
                     ggplot2::aes(fill = eff),
                     colour = "grey35", linewidth = 0.2) +
    ggplot2::scale_fill_gradientn(colours = cols, limits = lims,
                                  na.value = "grey93",
                                  name = legend.title) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(
      legend.position       = "right",
      plot.title            = ggplot2::element_text(face = "bold", size = 16,
                                                    hjust = 0.5,
                                                    margin = ggplot2::margin(
                                                      b = 8)),
      plot.title.position   = "panel",
      strip.text            = ggplot2::element_text(face = "bold", size = 10,
                                                    margin = ggplot2::margin(
                                                      t = 4, b = 6)),
      panel.border          = ggplot2::element_rect(colour = "grey45",
                                                    fill = NA, linewidth = 0.4),
      panel.spacing         = grid::unit(8, "pt"),
      plot.caption          = ggplot2::element_text(size = 7.5,
                                                    colour = "grey30",
                                                    hjust = 0.5),
      plot.caption.position = "panel",
      plot.margin           = ggplot2::margin(10, 10, 8, 10)
    ) +
    ggplot2::labs(title = title, caption = cap)

  if (!is.null(schem_sf) && nrow(schem_sf) > 0L) {
    p <- p + ggplot2::geom_sf(data = schem_sf,
                              ggplot2::aes(fill = eff),
                              colour = "grey35", linewidth = 0.2,
                              linetype = "22")
  }

  if (!identical(labels, "none")) {
    mark <- slice[!is.na(slice$eff), c("lab", "num", "panel", "geometry")]
    if (!is.null(schem_sf) && nrow(schem_sf) > 0L) {
      mark <- rbind(mark, schem_sf[, c("lab", "num", "panel", "geometry")])
    }
    if (nrow(mark) > 0L) {
      if (identical(labels, "name")) {
        # One name per region and panel - the larger polygon of the pair - so
        # the two hemispheres do not print the same name twice
        areas <- as.numeric(sf::st_area(mark))
        keep  <- vapply(split(seq_along(areas),
                              paste(mark$panel, mark$lab)),
                        function(ix) ix[which.max(areas[ix])], integer(1L))
        mark  <- mark[sort(keep), , drop = FALSE]
        p <- p + ggplot2::geom_sf_text(data = mark,
                                       ggplot2::aes(label = lab),
                                       size = 2.4, colour = "grey15")
      } else {
        pts <- sf::st_point_on_surface(sf::st_geometry(mark))
        pts <- sf::st_sf(num = mark$num, panel = mark$panel, geometry = pts)
        p <- p +
          ggplot2::geom_sf(data = pts, shape = 21, fill = "white",
                           colour = "grey15", size = 3.6, stroke = 0.4) +
          ggplot2::geom_sf_text(data = pts, ggplot2::aes(label = num),
                                size = 2.1, colour = "grey10")
      }
    }
  }

  if (n_panels > 1L) {
    p <- p + ggplot2::facet_wrap(~ panel, nrow = 1L)
  }

  # --- 8. Draw -------------------------------------------------------------
  out_file <- resolve_file(x, file, format, suffix = "brainmap")
  if (is.null(out_file)) return(p)

  if (identical(format, "pdf")) {
    grDevices::pdf(out_file, width = w / 300, height = h / 300)
  } else {
    grDevices::png(out_file, width = w, height = h, res = 300L)
  }
  on.exit(grDevices::dev.off(), add = TRUE)

  if (is.null(key_tab_shown)) {
    print(p)
  } else {
    # Reserve a strip under the figure for the key and centre it there
    grid::grid.newpage()
    n_key <- bm_key_rows(key_tab_shown$label)
    grid::pushViewport(grid::viewport(
      layout = grid::grid.layout(
        nrow    = 2L,
        heights = grid::unit.c(grid::unit(1, "null"),
                               grid::unit(n_key * 5.5 + 2, "mm"))
      )
    ))
    grid::pushViewport(grid::viewport(layout.pos.row = 1L))
    print(p, newpage = FALSE)
    grid::popViewport()
    grid::pushViewport(grid::viewport(layout.pos.row = 2L))
    bm_draw_key(key_tab_shown$num, key_tab_shown$label)
    grid::popViewport(2L)
  }

  invisible(out_file)
}

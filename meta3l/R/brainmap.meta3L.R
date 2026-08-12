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

  # --- 1. One pooled estimate per analysis ---------------------------------
  r  <- x$rows
  ov <- r[r$type == "row" & r$kind == "overall", , drop = FALSE]
  if (nrow(ov) == 0L) {
    stop("No pooled rows in this object; metabind(..., overall = TRUE) is ",
         "needed for a brain map.", call. = FALSE)
  }
  dat <- data.frame(
    label = ov$block,
    est   = if (identical(value, "abs")) abs(ov$est) else ov$est,
    stringsAsFactors = FALSE
  )

  # --- 2. Atlas slice -------------------------------------------------------
  atlas <- as.data.frame(ggseg::aseg())
  if (!view %in% atlas$view) {
    stop("View '", view, "' not in the atlas; available: ",
         paste(unique(atlas$view), collapse = ", "), ".", call. = FALSE)
  }
  slice <- sf::st_as_sf(atlas[atlas$view == view, , drop = FALSE])
  slice <- slice[!sf::st_is_empty(sf::st_geometry(slice)), , drop = FALSE]

  # --- 3. Which labels are drawn as schematic midbrain nuclei --------------
  if (is.null(schematic)) {
    rn <- dat$label[grepl("red", dat$label, ignore.case = TRUE)]
    sn <- dat$label[grepl("nigra", dat$label, ignore.case = TRUE)]
    schematic <- c(if (length(rn) > 0L) rn[1L] else NA_character_,
                   if (length(sn) > 0L) sn[1L] else NA_character_)
  }
  is_schem <- dat$label %in% schematic[!is.na(schematic)]

  # --- 4. Match the remaining labels to atlas regions ----------------------
  atlas_regions <- unique(as.character(slice$region))
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
  dat$region <- vapply(dat$label, function(l) {
    if (l %in% schematic) l else resolve(l)
  }, character(1L), USE.NAMES = FALSE)

  unmatched <- dat$label[is.na(dat$region)]
  if (length(unmatched) > 0L) {
    warning("No atlas region for: ", paste(unmatched, collapse = ", "),
            ". Use region.map = c(\"", unmatched[1L],
            "\" = \"<atlas region>\") or schematic = to place them.",
            call. = FALSE)
  }

  # --- 5. Attach the values to the geometry --------------------------------
  dat$num <- seq_len(nrow(dat))
  keyed <- dat[!is_schem & !is.na(dat$region), , drop = FALSE]
  slice$eff <- keyed$est[match(bm_key(slice$region), bm_key(keyed$region))]
  slice$lab   <- keyed$label[match(bm_key(slice$region), bm_key(keyed$region))]

  schem_sf <- NULL
  schem_in <- dat[is_schem & !is.na(dat$est), , drop = FALSE]
  if (nrow(schem_in) > 0L) {
    schem_sf <- bm_schematic(slice, schematic)
    if (!is.null(schem_sf)) {
      schem_sf$eff <- schem_in$est[match(schem_sf$region, schem_in$label)]
      schem_sf$lab   <- schem_sf$region
      schem_sf <- schem_sf[!is.na(schem_sf$eff), , drop = FALSE]
    }
  }

  # --- 5b. Numbering, in the order the analyses were bound -----------------
  slice$num <- keyed$num[match(bm_key(slice$region), bm_key(keyed$region))]
  if (!is.null(schem_sf) && nrow(schem_sf) > 0L) {
    schem_sf$num <- dat$num[match(schem_sf$region, dat$label)]
  }

  # --- 6. Colour scale ------------------------------------------------------
  # MetBrewer spells some palettes unusually ("OKeeffe1"), so match loosely
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
  lims <- if (!is.null(limits)) limits else range(vals, na.rm = TRUE)

  if (is.null(legend.title)) {
    legend.title <- switch(x$measure,
                           MD  = "Mean difference",
                           SMD = "Standardised mean difference",
                           RR  = "Risk ratio",
                           OR  = "Odds ratio",
                           "Effect")
  }

  key_txt <- NULL
  if (identical(labels, "number")) {
    shown <- dat[!is.na(dat$region) & !is.na(dat$est), , drop = FALSE]
    if (nrow(shown) > 0L) {
      key_txt <- paste(sprintf("%d - %s", shown$num, shown$label),
                       collapse = "   |   ")
    }
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
  if (!is.null(cap)) cap <- paste(strwrap(cap, width = 95L), collapse = "
")
  if (!is.null(key_txt)) {
    key_txt <- paste(strwrap(key_txt, width = 95L), collapse = "
")
    cap <- if (is.null(cap)) key_txt else paste(key_txt, cap, sep = "

")
  }

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
      legend.position = "right",
      plot.title      = ggplot2::element_text(face = "bold", hjust = 0.5),
      plot.caption    = ggplot2::element_text(size = 7, colour = "grey30",
                                              hjust = 0)
    ) +
    ggplot2::labs(title = title, caption = cap)

  if (!is.null(schem_sf) && nrow(schem_sf) > 0L) {
    p <- p + ggplot2::geom_sf(data = schem_sf,
                              ggplot2::aes(fill = eff),
                              colour = "grey35", linewidth = 0.2,
                              linetype = "22")
  }

  if (!identical(labels, "none")) {
    mark <- slice[!is.na(slice$eff), c("lab", "num", "geometry")]
    if (!is.null(schem_sf) && nrow(schem_sf) > 0L) {
      mark <- rbind(mark, schem_sf[, c("lab", "num", "geometry")])
    }
    if (nrow(mark) > 0L) {
      if (identical(labels, "name")) {
        # One name per region - the largest polygon of the pair - so the two
        # hemispheres do not print the same name twice on top of each other
        areas <- as.numeric(sf::st_area(mark))
        keep  <- vapply(split(seq_along(areas), mark$lab),
                        function(ix) ix[which.max(areas[ix])], integer(1L))
        mark  <- mark[sort(keep), , drop = FALSE]
        p <- p + ggplot2::geom_sf_text(data = mark,
                                       ggplot2::aes(label = lab),
                                       size = 2.4, colour = "grey15")
      } else {
        pts <- sf::st_point_on_surface(sf::st_geometry(mark))
        pts <- sf::st_sf(num = mark$num, geometry = pts)
        p <- p +
          ggplot2::geom_sf(data = pts, shape = 21, fill = "white",
                           colour = "grey15", size = 3.6, stroke = 0.4) +
          ggplot2::geom_sf_text(data = pts, ggplot2::aes(label = num),
                                size = 2.1, colour = "grey10")
      }
    }
  }

  # --- 8. Draw -------------------------------------------------------------
  out_file <- resolve_file(x, file, format, suffix = "brainmap")
  if (is.null(out_file)) return(p)

  w <- if (!is.null(width))  width  else 2400L
  h <- if (!is.null(height)) height else 1800L
  if (identical(format, "pdf")) {
    grDevices::pdf(out_file, width = w / 300, height = h / 300)
  } else {
    grDevices::png(out_file, width = w, height = h, res = 300L)
  }
  on.exit(grDevices::dev.off(), add = TRUE)
  print(p)

  invisible(out_file)
}

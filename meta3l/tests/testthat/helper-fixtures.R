# Synthetic test fixtures for all measure types.
# All fixtures have at least 9 rows spread across 3 studies (3 effects each).

#' Make PLO/PAS fixture data
#' @return data.frame with author, year, studlab, xi, ni, subgroup columns
make_plo_data <- function() {
  data.frame(
    author   = rep(c("Smith", "Jones", "Brown"), each = 3L),
    year     = rep(c(2020L, 2021L, 2022L), each = 3L),
    studlab  = rep(c("Smith, 2020", "Jones, 2021", "Brown, 2022"), each = 3L),
    xi       = c(10L, 12L, 8L, 15L, 11L, 9L, 7L, 13L, 10L),
    ni       = c(50L, 55L, 48L, 60L, 52L, 47L, 45L, 58L, 51L),
    subgroup = rep(c("Group A", "Group B", "Group A"), each = 3L),
    stringsAsFactors = FALSE
  )
}

#' Make PAS fixture data (same structure as PLO)
make_pas_data <- function() {
  make_plo_data()
}

#' Make PLO fixture data with subgroup column (alias for make_plo_data with 3 studies)
make_plo_data_subgroup <- function() {
  make_plo_data()
}

#' Make SMD / MD fixture data (two-group design)
#' @return data.frame with studlab, meta-style columns, subgroup, and dose columns
make_smd_data <- function() {
  data.frame(
    studlab  = rep(c("Smith, 2020", "Jones, 2021", "Brown, 2022"), each = 3L),
    m1i      = c(5.2, 5.8, 6.1, 4.7, 5.0, 5.5, 6.3, 5.1, 4.9),
    sd1i     = c(1.1, 1.2, 1.0, 0.9, 1.3, 1.1, 1.0, 1.2, 0.8),
    n1i      = c(20L, 22L, 18L, 25L, 20L, 23L, 21L, 19L, 24L),
    m2i      = c(4.0, 4.3, 4.5, 3.8, 4.1, 4.4, 4.6, 3.9, 4.2),
    sd2i     = c(1.0, 1.1, 0.9, 0.8, 1.2, 1.0, 0.9, 1.1, 0.8),
    n2i      = c(20L, 22L, 18L, 25L, 20L, 23L, 21L, 19L, 24L),
    subgroup = rep(c("Group A", "Group B", "Group A"), each = 3L),
    dose     = rep(c(10.0, 20.0, 15.0), each = 3L),
    stringsAsFactors = FALSE
  )
}

#' Make MD fixture data (same structure as SMD)
make_md_data <- function() {
  make_smd_data()
}

#' Make RR / OR fixture data (2x2 table using escalc-style column names)
make_rr_data <- function() {
  data.frame(
    studlab  = rep(c("Smith, 2020", "Jones, 2021", "Brown, 2022"), each = 3L),
    ai       = c(10L, 12L, 8L, 15L, 11L, 9L, 7L, 13L, 10L),
    bi       = c(40L, 43L, 40L, 45L, 41L, 38L, 38L, 42L, 37L),
    ci       = c(5L,  6L,  4L, 8L,  5L,  4L, 3L,  7L,  5L),
    di       = c(45L, 49L, 44L, 52L, 47L, 43L, 42L, 48L, 45L),
    subgroup = rep(c("Group A", "Group B", "Group A"), each = 3L),
    stringsAsFactors = FALSE
  )
}

#' Make OR fixture data (same structure as RR)
make_or_data <- function() {
  make_rr_data()
}

#' Make RR / OR fixture data using meta-style column names (event.e, n.e, event.c, n.c)
#' Used to test auto-detection and meta-style API
make_rr_meta_style_data <- function() {
  data.frame(
    studlab  = rep(c("Smith, 2020", "Jones, 2021", "Brown, 2022"), each = 3L),
    event.e  = c(10L, 12L, 8L, 15L, 11L, 9L, 7L, 13L, 10L),
    n.e      = c(50L, 55L, 48L, 60L, 52L, 47L, 45L, 55L, 47L),
    event.c  = c(5L,  6L,  4L, 8L,  5L,  4L, 3L,  7L,  5L),
    n.c      = c(50L, 55L, 48L, 60L, 52L, 47L, 45L, 55L, 50L),
    subgroup = rep(c("Group A", "Group B", "Group A"), each = 3L),
    stringsAsFactors = FALSE
  )
}

#' Make SMD fixture data using meta-style column names (mean.e, sd.e, etc.)
#' Used to test auto-detection and meta-style API
make_smd_meta_style_data <- function() {
  data.frame(
    studlab  = rep(c("Smith, 2020", "Jones, 2021", "Brown, 2022"), each = 3L),
    mean.e   = c(5.2, 5.8, 6.1, 4.7, 5.0, 5.5, 6.3, 5.1, 4.9),
    sd.e     = c(1.1, 1.2, 1.0, 0.9, 1.3, 1.1, 1.0, 1.2, 0.8),
    n.e      = c(20L, 22L, 18L, 25L, 20L, 23L, 21L, 19L, 24L),
    mean.c   = c(4.0, 4.3, 4.5, 3.8, 4.1, 4.4, 4.6, 3.9, 4.2),
    sd.c     = c(1.0, 1.1, 0.9, 0.8, 1.2, 1.0, 0.9, 1.1, 0.8),
    n.c      = c(20L, 22L, 18L, 25L, 20L, 23L, 21L, 19L, 24L),
    stringsAsFactors = FALSE
  )
}

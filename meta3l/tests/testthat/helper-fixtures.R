# Synthetic test fixtures for all measure types.
# All fixtures have at least 6 rows spread across 2 studies (3 effects each).

#' Make PLO/PAS fixture data
#' @return data.frame with author, year, studlab, xi, ni columns
make_plo_data <- function() {
  data.frame(
    author  = rep(c("Smith", "Jones"), each = 3L),
    year    = rep(c(2020L, 2021L), each = 3L),
    studlab = rep(c("Smith, 2020", "Jones, 2021"), each = 3L),
    xi      = c(10L, 12L, 8L, 15L, 11L, 9L),
    ni      = c(50L, 55L, 48L, 60L, 52L, 47L),
    stringsAsFactors = FALSE
  )
}

#' Make PAS fixture data (same structure as PLO)
make_pas_data <- function() {
  make_plo_data()
}

#' Make SMD / MD fixture data (two-group design)
make_smd_data <- function() {
  data.frame(
    studlab = rep(c("Smith, 2020", "Jones, 2021"), each = 3L),
    m1i  = c(5.2, 5.8, 6.1, 4.7, 5.0, 5.5),
    sd1i = c(1.1, 1.2, 1.0, 0.9, 1.3, 1.1),
    n1i  = c(20L, 22L, 18L, 25L, 20L, 23L),
    m2i  = c(4.0, 4.3, 4.5, 3.8, 4.1, 4.4),
    sd2i = c(1.0, 1.1, 0.9, 0.8, 1.2, 1.0),
    n2i  = c(20L, 22L, 18L, 25L, 20L, 23L),
    stringsAsFactors = FALSE
  )
}

#' Make MD fixture data (same structure as SMD)
make_md_data <- function() {
  make_smd_data()
}

#' Make RR / OR fixture data (2x2 table)
make_rr_data <- function() {
  data.frame(
    studlab = rep(c("Smith, 2020", "Jones, 2021"), each = 3L),
    ai = c(10L, 12L, 8L, 15L, 11L, 9L),
    bi = c(40L, 43L, 40L, 45L, 41L, 38L),
    ci = c(5L,  6L,  4L, 8L,  5L,  4L),
    di = c(45L, 49L, 44L, 52L, 47L, 43L),
    stringsAsFactors = FALSE
  )
}

#' Make OR fixture data (same structure as RR)
make_or_data <- function() {
  make_rr_data()
}

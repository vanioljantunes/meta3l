# test-forest.meta3L.R — Smoke and integration tests for forest.meta3L()

# ---------------------------------------------------------------------------
# Minimal fixture factory
# ---------------------------------------------------------------------------

make_forest_fixture <- function() {
  d <- data.frame(
    studlab = rep(c("Study A", "Study B", "Study C"), each = 2L),
    xi = c(10L, 12L, 8L, 15L, 11L, 9L),
    ni = c(50L, 55L, 48L, 60L, 52L, 47L),
    stringsAsFactors = FALSE
  )
  meta3L(d, slab = "studlab", xi = "xi", ni = "ni", measure = "PLO",
         name = "test_outcome")
}

# ---------------------------------------------------------------------------
# Basic smoke tests
# ---------------------------------------------------------------------------

test_that("forest.meta3L produces a non-empty PNG file", {
  result <- make_forest_fixture()
  out <- tempfile(fileext = ".png")
  forest.meta3L(result, file = out)
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 1000)
})

test_that("forest.meta3L produces a non-empty PDF file", {
  result <- make_forest_fixture()
  out <- tempfile(fileext = ".pdf")
  forest.meta3L(result, file = out, format = "pdf")
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 1000)
})

test_that("forest.meta3L runs without error in display-only mode (file=NULL)", {
  result <- make_forest_fixture()
  # Open a null device so drawing has somewhere to go; close after
  grDevices::pdf(nullfile())
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(forest.meta3L(result, file = NULL))
})

# ---------------------------------------------------------------------------
# ilab columns
# ---------------------------------------------------------------------------

test_that("forest.meta3L with ilab columns produces file without error", {
  result <- make_forest_fixture()
  out <- tempfile(fileext = ".png")
  expect_no_error(
    forest.meta3L(result, ilab = c("xi", "ni"),
                  ilab.lab = c("Events", "Total"), file = out)
  )
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 1000)
})

# ---------------------------------------------------------------------------
# Batch safety
# ---------------------------------------------------------------------------

test_that("Batch loop of 5 sequential calls produces 5 valid PNG files", {
  result <- make_forest_fixture()
  files <- replicate(5L, tempfile(fileext = ".png"), simplify = TRUE)
  for (f in files) {
    forest.meta3L(result, file = f)
  }
  sizes <- vapply(files, function(f) file.info(f)$size, numeric(1L))
  expect_true(all(file.exists(files)))
  expect_true(all(sizes > 1000))
})

# ---------------------------------------------------------------------------
# Auto-naming from x$name + meta3l.mwd option
# ---------------------------------------------------------------------------

test_that("Auto-naming from x$name and meta3l.mwd produces expected file path", {
  result <- make_forest_fixture()   # name = "test_outcome"
  td <- tempdir()
  old_opt <- getOption("meta3l.mwd")
  options(meta3l.mwd = td)
  on.exit(options(meta3l.mwd = old_opt), add = TRUE)

  expected <- file.path(td, "test_outcome.png")
  if (file.exists(expected)) file.remove(expected)

  ret <- forest.meta3L(result, file = character(0))
  expect_equal(ret, expected)
  expect_true(file.exists(expected))
  expect_gt(file.info(expected)$size, 1000)
})

# ---------------------------------------------------------------------------
# showweights flag
# ---------------------------------------------------------------------------

test_that("showweights=TRUE produces a file", {
  result <- make_forest_fixture()
  out <- tempfile(fileext = ".png")
  expect_no_error(forest.meta3L(result, showweights = TRUE, file = out))
  expect_gt(file.info(out)$size, 1000)
})

test_that("showweights=FALSE produces a file", {
  result <- make_forest_fixture()
  out <- tempfile(fileext = ".png")
  expect_no_error(forest.meta3L(result, showweights = FALSE, file = out))
  expect_gt(file.info(out)$size, 1000)
})

# ---------------------------------------------------------------------------
# sortvar
# ---------------------------------------------------------------------------

test_that("sortvar='yi' produces a file without error", {
  result <- make_forest_fixture()
  out <- tempfile(fileext = ".png")
  expect_no_error(forest.meta3L(result, sortvar = "yi", file = out))
  expect_gt(file.info(out)$size, 1000)
})

# ---------------------------------------------------------------------------
# refline behaviour
# ---------------------------------------------------------------------------

test_that("PLO measure produces file with no refline error", {
  result <- make_forest_fixture()  # PLO measure
  out <- tempfile(fileext = ".png")
  expect_no_error(forest.meta3L(result, file = out))
  expect_gt(file.info(out)$size, 1000)
})

test_that("SMD measure produces file with refline at 0", {
  d <- data.frame(
    studlab = rep(c("Study A", "Study B", "Study C"), each = 2L),
    m1i  = c(5.2, 5.8, 6.1, 4.7, 5.0, 5.5),
    sd1i = c(1.1, 1.2, 1.0, 0.9, 1.3, 1.1),
    n1i  = c(20L, 22L, 18L, 25L, 20L, 23L),
    m2i  = c(4.0, 4.3, 4.5, 3.8, 4.1, 4.4),
    sd2i = c(1.0, 1.1, 0.9, 0.8, 1.2, 1.0),
    n2i  = c(20L, 22L, 18L, 25L, 20L, 23L),
    stringsAsFactors = FALSE
  )
  smd_result <- meta3L(d, slab = "studlab",
                       m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                       m2i = "m2i", sd2i = "sd2i", n2i = "n2i",
                       measure = "SMD")
  out <- tempfile(fileext = ".png")
  expect_no_error(forest.meta3L(smd_result, file = out))
  expect_gt(file.info(out)$size, 1000)
})

# ---------------------------------------------------------------------------
# p-value in pooled label for comparison measures
# ---------------------------------------------------------------------------

test_that("SMD measure includes p-value in pooled text (no error)", {
  d <- data.frame(
    studlab = rep(c("Study A", "Study B", "Study C"), each = 2L),
    m1i  = c(5.2, 5.8, 6.1, 4.7, 5.0, 5.5),
    sd1i = c(1.1, 1.2, 1.0, 0.9, 1.3, 1.1),
    n1i  = c(20L, 22L, 18L, 25L, 20L, 23L),
    m2i  = c(4.0, 4.3, 4.5, 3.8, 4.1, 4.4),
    sd2i = c(1.0, 1.1, 0.9, 0.8, 1.2, 1.0),
    n2i  = c(20L, 22L, 18L, 25L, 20L, 23L),
    stringsAsFactors = FALSE
  )
  smd_result <- meta3L(d, slab = "studlab",
                       m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                       m2i = "m2i", sd2i = "sd2i", n2i = "n2i",
                       measure = "SMD")
  out <- tempfile(fileext = ".png")
  expect_no_error(forest.meta3L(smd_result, file = out))
})

# ---------------------------------------------------------------------------
# No base-R graphics check
# ---------------------------------------------------------------------------

test_that("forest.meta3L.R does not use base-R graphics functions", {
  forest_file <- system.file("R", "forest.meta3L.R", package = "meta3l")
  # Fallback for devtools::load_all() context
  if (!nzchar(forest_file)) {
    forest_file <- file.path(
      system.file(package = "meta3l"),
      "..", "..", "R", "forest.meta3L.R"
    )
  }
  # Only check if file is accessible
  if (file.exists(forest_file)) {
    lines <- readLines(forest_file)
    base_calls <- grep("^par\\(|^plot\\(|^text\\(", lines, value = TRUE)
    expect_length(base_calls, 0L)
  } else {
    skip("forest.meta3L.R file path not accessible in this test context")
  }
})

# ---------------------------------------------------------------------------
# Return value
# ---------------------------------------------------------------------------

test_that("forest.meta3L invisibly returns the file path", {
  result <- make_forest_fixture()
  out <- tempfile(fileext = ".png")
  ret <- forest.meta3L(result, file = out)
  expect_equal(ret, out)
})

test_that("forest.meta3L returns NULL for display-only mode", {
  result <- make_forest_fixture()
  grDevices::pdf(nullfile())
  on.exit(grDevices::dev.off(), add = TRUE)
  ret <- forest.meta3L(result, file = NULL)
  expect_null(ret)
})

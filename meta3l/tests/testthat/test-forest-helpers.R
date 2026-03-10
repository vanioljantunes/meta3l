# Tests for forest_helpers.R — drawing primitives and utility functions
# TDD: tests written before implementation

# ---------------------------------------------------------------------------
# resolve_file() — pure logic, no device needed
# ---------------------------------------------------------------------------

test_that("resolve_file returns path with name and mwd option", {
  old <- getOption("meta3l.mwd")
  on.exit(options(meta3l.mwd = old))
  options(meta3l.mwd = "/tmp")

  x <- list(name = "foo")
  result <- meta3l:::resolve_file(x, character(0), "png")
  expect_true(grepl("foo\\.png$", result))
  expect_true(grepl("/tmp", result))
})

test_that("resolve_file with format=pdf returns .pdf extension", {
  old <- getOption("meta3l.mwd")
  on.exit(options(meta3l.mwd = old))
  options(meta3l.mwd = "/tmp")

  x <- list(name = "foo")
  result <- meta3l:::resolve_file(x, character(0), "pdf")
  expect_true(grepl("foo\\.pdf$", result))
})

test_that("resolve_file with name=NULL uses forest_plot fallback", {
  old <- getOption("meta3l.mwd")
  on.exit(options(meta3l.mwd = old))
  options(meta3l.mwd = "/tmp")

  x <- list(name = NULL)
  result <- meta3l:::resolve_file(x, character(0), "png")
  expect_true(grepl("forest_plot", result))
})

test_that("resolve_file with missing option uses getwd()", {
  old <- getOption("meta3l.mwd")
  on.exit(options(meta3l.mwd = old))
  options(meta3l.mwd = NULL)

  x <- list(name = "bar")
  result <- meta3l:::resolve_file(x, character(0), "png")
  expect_true(grepl(getwd(), result, fixed = TRUE))
  expect_true(grepl("bar\\.png$", result))
})

test_that("resolve_file with file=NULL returns NULL (display only)", {
  x <- list(name = "foo")
  result <- meta3l:::resolve_file(x, NULL, "png")
  expect_null(result)
})

test_that("resolve_file with explicit string returns that string as-is", {
  x <- list(name = "foo")
  result <- meta3l:::resolve_file(x, "/custom/path/output.png", "png")
  expect_equal(result, "/custom/path/output.png")
})

# ---------------------------------------------------------------------------
# auto_dims() — pure logic
# ---------------------------------------------------------------------------

test_that("auto_dims returns list with width=3000 by default", {
  dims <- meta3l:::auto_dims(10L)
  expect_type(dims, "list")
  expect_equal(dims$width, 3000L)
})

test_that("auto_dims computes height = max(800, 200 + n * 80)", {
  expect_equal(meta3l:::auto_dims(10L)$height, max(800L, 200L + 10L * 80L))
  expect_equal(meta3l:::auto_dims(1L)$height,  800L)   # floor at 800
  expect_equal(meta3l:::auto_dims(20L)$height, max(800L, 200L + 20L * 80L))
})

test_that("auto_dims respects user width override", {
  dims <- meta3l:::auto_dims(10L, user_w = 4000L)
  expect_equal(dims$width, 4000L)
})

test_that("auto_dims respects user height override", {
  dims <- meta3l:::auto_dims(10L, user_h = 1200L)
  expect_equal(dims$height, 1200L)
})

# ---------------------------------------------------------------------------
# auto_xlim() — pure logic
# ---------------------------------------------------------------------------

test_that("auto_xlim returns c(0,1) for PLO", {
  xlim <- meta3l:::auto_xlim("PLO", c(0.1, 0.3, 0.5), c(0.05, 0.2, 0.4), c(0.2, 0.4, 0.6))
  expect_equal(xlim, c(0, 1))
})

test_that("auto_xlim returns c(0,1) for PAS", {
  xlim <- meta3l:::auto_xlim("PAS", c(0.1, 0.3), c(0.05, 0.2), c(0.2, 0.4))
  expect_equal(xlim, c(0, 1))
})

test_that("auto_xlim returns symmetric range for SMD", {
  xlim <- meta3l:::auto_xlim("SMD", c(-0.5, 0.2, 0.8), c(-0.8, -0.1, 0.5), c(-0.2, 0.5, 1.1))
  # Should be symmetric around 0
  expect_equal(xlim[1], -xlim[2])
  expect_true(xlim[2] > 0)
})

test_that("auto_xlim returns symmetric range for MD", {
  xlim <- meta3l:::auto_xlim("MD", c(-1, 2, 3), c(-2, 1, 2), c(0, 3, 4))
  expect_equal(xlim[1], -xlim[2])
})

test_that("auto_xlim returns positive range for RR", {
  xlim <- meta3l:::auto_xlim("RR", c(1.2, 1.5, 2.0), c(0.9, 1.1, 1.6), c(1.6, 2.0, 2.5))
  expect_true(xlim[1] > 0)
  expect_true(xlim[2] > xlim[1])
})

test_that("auto_xlim returns positive range for OR", {
  xlim <- meta3l:::auto_xlim("OR", c(0.8, 1.2, 2.0), c(0.5, 0.9, 1.5), c(1.1, 1.6, 2.8))
  expect_true(xlim[1] > 0)
})

# ---------------------------------------------------------------------------
# auto_refline() — pure logic
# ---------------------------------------------------------------------------

test_that("auto_refline returns NULL for PLO", {
  expect_null(meta3l:::auto_refline("PLO"))
})

test_that("auto_refline returns NULL for PAS", {
  expect_null(meta3l:::auto_refline("PAS"))
})

test_that("auto_refline returns 0 for SMD", {
  expect_equal(meta3l:::auto_refline("SMD"), 0)
})

test_that("auto_refline returns 0 for MD", {
  expect_equal(meta3l:::auto_refline("MD"), 0)
})

test_that("auto_refline returns 1 for RR", {
  expect_equal(meta3l:::auto_refline("RR"), 1)
})

test_that("auto_refline returns 1 for OR", {
  expect_equal(meta3l:::auto_refline("OR"), 1)
})

# ---------------------------------------------------------------------------
# format_mlab() — pure logic
# ---------------------------------------------------------------------------

test_that("format_mlab produces correctly formatted string", {
  i2 <- list(total = 85.3, between = 60.1, within = 25.2)
  result <- meta3l:::format_mlab(i2)
  expect_type(result, "character")
  expect_true(grepl("RE Model", result))
  expect_true(grepl("I\u00b2", result))
  expect_true(grepl("85%", result))
  expect_true(grepl("between", result, ignore.case = TRUE))
  expect_true(grepl("60%", result))
  expect_true(grepl("within", result, ignore.case = TRUE))
  expect_true(grepl("25%", result))
})

test_that("format_mlab rounds to nearest integer", {
  i2 <- list(total = 84.6, between = 59.9, within = 24.7)
  result <- meta3l:::format_mlab(i2)
  expect_true(grepl("85%", result))
  expect_true(grepl("60%", result))
  expect_true(grepl("25%", result))
})

# ---------------------------------------------------------------------------
# draw_*() smoke tests — require graphics device + viewport
# ---------------------------------------------------------------------------

test_that("draw_square does not error inside a viewport", {
  skip_if_not_installed("grid")
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp))

  pdf(tmp, width = 7, height = 7)
  on.exit(dev.off(), add = TRUE)

  grid::grid.newpage()
  vp <- grid::viewport(xscale = c(0, 1))
  grid::pushViewport(vp)
  expect_no_error(meta3l:::draw_square(0.5, 0.5))
  grid::popViewport()
})

test_that("draw_diamond does not error inside a viewport", {
  skip_if_not_installed("grid")
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp))

  pdf(tmp, width = 7, height = 7)
  on.exit(dev.off(), add = TRUE)

  grid::grid.newpage()
  vp <- grid::viewport(xscale = c(0, 1))
  grid::pushViewport(vp)
  expect_no_error(meta3l:::draw_diamond(0.3, 0.5, 0.7))
  grid::popViewport()
})

test_that("draw_ci_line does not error inside a viewport", {
  skip_if_not_installed("grid")
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp))

  pdf(tmp, width = 7, height = 7)
  on.exit(dev.off(), add = TRUE)

  grid::grid.newpage()
  vp <- grid::viewport(xscale = c(0, 1))
  grid::pushViewport(vp)
  expect_no_error(meta3l:::draw_ci_line(0.2, 0.8))
  grid::popViewport()
})

test_that("draw_zebra_rect does not error inside a viewport", {
  skip_if_not_installed("grid")
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp))

  pdf(tmp, width = 7, height = 7)
  on.exit(dev.off(), add = TRUE)

  grid::grid.newpage()
  vp <- grid::viewport(xscale = c(0, 1))
  grid::pushViewport(vp)
  expect_no_error(meta3l:::draw_zebra_rect(rgb(0.92, 0.92, 0.92)))
  grid::popViewport()
})

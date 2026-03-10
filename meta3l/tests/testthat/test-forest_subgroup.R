# test-forest_subgroup.R — Smoke tests for forest_subgroup.meta3L()

# ---------------------------------------------------------------------------
# Fixture factory
# ---------------------------------------------------------------------------

make_subgroup_fixture <- function() {
  d <- data.frame(
    studlab  = rep(c("Smith, 2020", "Jones, 2021", "Brown, 2022", "Clark, 2023"),
                  each = 3L),
    xi       = c(10L, 12L, 8L, 15L, 11L, 9L, 7L, 13L, 10L, 12L, 8L, 11L),
    ni       = c(50L, 55L, 48L, 60L, 52L, 47L, 45L, 58L, 51L, 55L, 48L, 52L),
    subgroup = rep(c("Group A", "Group A", "Group B", "Group B"), each = 3L),
    stringsAsFactors = FALSE
  )
  meta3L(d, slab = "studlab", xi = "xi", ni = "ni", measure = "PLO",
         name = "test_subgroup")
}

# ---------------------------------------------------------------------------
# Core smoke tests
# ---------------------------------------------------------------------------

test_that("forest_subgroup.meta3L produces a non-empty PNG file", {
  result <- make_subgroup_fixture()
  out <- tempfile(fileext = ".png")
  ret <- forest_subgroup.meta3L(result, subgroup = "subgroup", file = out)
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 10000)
})

test_that("forest_subgroup.meta3L returns the file path invisibly", {
  result <- make_subgroup_fixture()
  out <- tempfile(fileext = ".png")
  ret <- forest_subgroup.meta3L(result, subgroup = "subgroup", file = out)
  expect_equal(ret, out)
})

test_that("forest_subgroup.meta3L with overall=FALSE still produces file > 5000 bytes", {
  result <- make_subgroup_fixture()
  out <- tempfile(fileext = ".png")
  forest_subgroup.meta3L(result, subgroup = "subgroup", overall = FALSE, file = out)
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 5000)
})

test_that("forest_subgroup.meta3L errors when subgroup column not found", {
  result <- make_subgroup_fixture()
  out <- tempfile(fileext = ".png")
  expect_error(
    forest_subgroup.meta3L(result, subgroup = "nonexistent_col", file = out),
    "not found"
  )
})

test_that("forest_subgroup.meta3L with ilab argument produces file without error", {
  result <- make_subgroup_fixture()
  out <- tempfile(fileext = ".png")
  expect_no_error(
    forest_subgroup.meta3L(result, subgroup = "subgroup",
                           ilab = c("xi", "ni"),
                           ilab.lab = c("Events", "Total"),
                           file = out)
  )
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 5000)
})

test_that("file naming contains 'subgroup_' in the path when auto-named", {
  result <- make_subgroup_fixture()
  td <- tempdir()
  old_opt <- getOption("meta3l.mwd")
  options(meta3l.mwd = td)
  on.exit(options(meta3l.mwd = old_opt), add = TRUE)

  ret <- forest_subgroup.meta3L(result, subgroup = "subgroup",
                                file = character(0))
  expect_true(grepl("subgroup_", ret))
})

test_that("forest_subgroup.meta3L in display-only mode (file=NULL) returns NULL without error", {
  result <- make_subgroup_fixture()
  grDevices::pdf(nullfile())
  on.exit(grDevices::dev.off(), add = TRUE)
  ret <- forest_subgroup.meta3L(result, subgroup = "subgroup", file = NULL)
  expect_null(ret)
})

# test-loo.R — tests for loo_cluster.meta3L() and loo_effect.meta3L()

# ---------------------------------------------------------------------------
# Shared fixture: 3-study SMD model (fitted once for both LOO tests)
# ---------------------------------------------------------------------------

make_loo_fixture <- function() {
  d <- make_smd_data()
  meta3L(d, slab = "studlab", measure = "SMD",
         m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
         m2i = "m2i", sd2i = "sd2i", n2i = "n2i",
         name = "loo_test")
}

# ---------------------------------------------------------------------------
# loo_cluster.meta3L() tests — Task 1 RED phase
# ---------------------------------------------------------------------------

test_that("loo_cluster.meta3L returns list with $table and $plot_file", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  out <- loo_cluster(res)
  expect_type(out, "list")
  expect_true("table" %in% names(out))
  expect_true("plot_file" %in% names(out))
})

test_that("loo_cluster table has nrow == n_clusters + 1 (All studies baseline)", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  out <- loo_cluster(res)
  n_clusters <- length(unique(res$data[[res$cluster]]))
  expect_equal(nrow(out$table), n_clusters + 1L)
})

test_that("loo_cluster table has correct column names", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  out <- loo_cluster(res)
  expected_cols <- c("omitted", "estimate", "ci.lb", "ci.ub",
                     "i2_between", "i2_within", "pval")
  expect_true(all(expected_cols %in% names(out$table)))
})

test_that("loo_cluster table last row is 'All studies'", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  out <- loo_cluster(res)
  expect_equal(out$table$omitted[nrow(out$table)], "All studies")
})

test_that("loo_cluster table estimate values are numeric", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  out <- loo_cluster(res)
  # All rows except possibly failed LOO iterations should have numeric estimates
  # The 3-study fixture should produce non-NA results for at least one iteration
  expect_true(is.numeric(out$table$estimate))
  expect_true(is.numeric(out$table$ci.lb))
  expect_true(is.numeric(out$table$ci.ub))
})

test_that("loo_cluster produces non-empty PNG file when file=character(0)", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  old_mwd <- getOption("meta3l.mwd")
  on.exit({
    if (is.null(old_mwd)) options(meta3l.mwd = NULL) else options(meta3l.mwd = old_mwd)
  }, add = TRUE)
  options(meta3l.mwd = tempdir())
  out <- loo_cluster(res, file = character(0), format = "png")
  expect_false(is.null(out$plot_file))
  expect_true(file.exists(out$plot_file))
  expect_gt(file.size(out$plot_file), 5000L)
})

test_that("loo_cluster file path contains 'loo_cluster' suffix", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  old_mwd <- getOption("meta3l.mwd")
  on.exit({
    if (is.null(old_mwd)) options(meta3l.mwd = NULL) else options(meta3l.mwd = old_mwd)
  }, add = TRUE)
  options(meta3l.mwd = tempdir())
  out <- loo_cluster(res, file = character(0), format = "png")
  expect_true(grepl("loo_cluster", out$plot_file))
})

test_that("loo_cluster returns NULL plot_file when file=NULL", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  out <- loo_cluster(res, file = NULL)
  expect_null(out$plot_file)
})

# ---------------------------------------------------------------------------
# loo_effect.meta3L() tests — Task 2 RED phase
# ---------------------------------------------------------------------------

test_that("loo_effect.meta3L returns list with $table and $plot_file", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  out <- loo_effect(res)
  expect_type(out, "list")
  expect_true("table" %in% names(out))
  expect_true("plot_file" %in% names(out))
})

test_that("loo_effect table has nrow == n_effects + 1 (All studies baseline)", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  out <- loo_effect(res)
  n_effects <- nrow(res$data)
  expect_equal(nrow(out$table), n_effects + 1L)
})

test_that("loo_effect table last row is 'All studies'", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  out <- loo_effect(res)
  expect_equal(out$table$omitted[nrow(out$table)], "All studies")
})

test_that("loo_effect table has correct column names", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  out <- loo_effect(res)
  expected_cols <- c("omitted", "estimate", "ci.lb", "ci.ub",
                     "i2_between", "i2_within", "pval")
  expect_true(all(expected_cols %in% names(out$table)))
})

test_that("loo_effect produces non-empty PNG file when file=character(0)", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  old_mwd <- getOption("meta3l.mwd")
  on.exit({
    if (is.null(old_mwd)) options(meta3l.mwd = NULL) else options(meta3l.mwd = old_mwd)
  }, add = TRUE)
  options(meta3l.mwd = tempdir())
  out <- loo_effect(res, file = character(0), format = "png")
  expect_false(is.null(out$plot_file))
  expect_true(file.exists(out$plot_file))
  expect_gt(file.size(out$plot_file), 5000L)
})

test_that("loo_effect file path contains 'loo_effect' suffix", {
  skip_if_not_installed("metafor")
  skip_if_not_installed("clubSandwich")
  res <- make_loo_fixture()
  old_mwd <- getOption("meta3l.mwd")
  on.exit({
    if (is.null(old_mwd)) options(meta3l.mwd = NULL) else options(meta3l.mwd = old_mwd)
  }, add = TRUE)
  options(meta3l.mwd = tempdir())
  out <- loo_effect(res, file = character(0), format = "png")
  expect_true(grepl("loo_effect", out$plot_file))
})

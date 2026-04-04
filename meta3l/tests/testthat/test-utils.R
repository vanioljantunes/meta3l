test_that("resolve_transf returns correct function for PLO", {
  expect_identical(resolve_transf("PLO"), metafor::transf.ilogit)
})

test_that("resolve_transf returns correct function for PAS", {
  expect_identical(resolve_transf("PAS"), metafor::transf.iarcsin)
})

test_that("resolve_transf returns exp for RR", {
  expect_identical(resolve_transf("RR"), exp)
})

test_that("resolve_transf returns exp for OR", {
  expect_identical(resolve_transf("OR"), exp)
})

test_that("resolve_transf returns identity for SMD", {
  expect_identical(resolve_transf("SMD"), identity)
})

test_that("resolve_transf returns identity for MD", {
  expect_identical(resolve_transf("MD"), identity)
})

test_that("resolve_transf throws error for unsupported measure PFT", {
  expect_error(resolve_transf("PFT"), "not supported")
})

test_that("resolve_transf respects user_transf override", {
  expect_identical(resolve_transf("PLO", user_transf = sqrt), sqrt)
})

test_that("validate_columns errors when required column is missing", {
  data <- make_plo_data()
  data$xi <- NULL  # remove required column
  col_args <- list(xi = "xi", ni = "ni", slab = "studlab", cluster = "studlab")
  expect_error(
    validate_columns(data, "PLO", col_args, slab = "studlab", cluster = "studlab"),
    regexp = "xi"
  )
})

test_that("validate_columns errors when slab column is missing", {
  data <- make_plo_data()
  col_args <- list(xi = "xi", ni = "ni", slab = "no_such_col", cluster = "studlab")
  expect_error(
    validate_columns(data, "PLO", col_args, slab = "no_such_col", cluster = "studlab"),
    regexp = "no_such_col"
  )
})

test_that("validate_columns passes silently when all columns present", {
  data <- make_plo_data()
  col_args <- list(xi = "xi", ni = "ni", slab = "studlab", cluster = "studlab")
  expect_silent(
    validate_columns(data, "PLO", col_args, slab = "studlab", cluster = "studlab")
  )
})

test_that("compute_i2 returns list with total, between, within components", {
  skip_if_not_installed("metafor")
  data <- make_plo_data()
  dat <- metafor::escalc(data = data, measure = "PLO", xi = xi, ni = ni,
                         slab = studlab)
  dat$TE_id <- seq_len(nrow(dat))
  V <- metafor::vcalc(data = dat, cluster = dat$studlab, obs = dat$TE_id,
                      vi = dat$vi, rho = 0.5)
  fit <- metafor::rma.mv(yi, V, random = ~ 1 | studlab / TE_id, data = dat)
  result <- compute_i2(fit)
  expect_type(result, "list")
  expect_named(result, c("total", "between", "within"))
  expect_true(is.numeric(result$total))
  expect_true(is.numeric(result$between))
  expect_true(is.numeric(result$within))
  expect_true(result$total >= 0)
  expect_true(result$between >= 0)
  expect_true(result$within >= 0)
})

test_that("compute_i2: between + within equals total within tolerance", {
  skip_if_not_installed("metafor")
  data <- make_plo_data()
  dat <- metafor::escalc(data = data, measure = "PLO", xi = xi, ni = ni,
                         slab = studlab)
  dat$TE_id <- seq_len(nrow(dat))
  V <- metafor::vcalc(data = dat, cluster = dat$studlab, obs = dat$TE_id,
                      vi = dat$vi, rho = 0.5)
  fit <- metafor::rma.mv(yi, V, random = ~ 1 | studlab / TE_id, data = dat)
  result <- compute_i2(fit)
  expect_equal(result$between + result$within, result$total, tolerance = 1e-10)
})

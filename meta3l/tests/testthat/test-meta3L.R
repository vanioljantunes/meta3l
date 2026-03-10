# Tests for meta3L() core function, print.meta3l_result(), and summary.meta3l_result()
# Follows TDD pattern established in 01-01.

test_that("meta3L returns meta3l_result for PLO measure", {
  d <- make_plo_data()
  r <- meta3L(d, slab = "studlab", xi = "xi", ni = "ni", measure = "PLO")

  expect_s3_class(r, "meta3l_result")
  expect_s3_class(r$model, "robust.rma")

  # i2 structure
  expect_named(r$i2, c("total", "between", "within"))
  expect_true(is.numeric(r$i2$total))
  expect_true(is.numeric(r$i2$between))
  expect_true(is.numeric(r$i2$within))
  expect_true(r$i2$total >= 0)
  expect_true(r$i2$between >= 0)
  expect_true(r$i2$within >= 0)
  # between + within should equal total (within floating-point tolerance)
  expect_equal(r$i2$between + r$i2$within, r$i2$total, tolerance = 0.01)

  # transf
  expect_true(is.function(r$transf))

  # back-transformed pooled estimate fields
  expect_true(is.numeric(r$estimate))
  expect_true(is.numeric(r$ci.lb))
  expect_true(is.numeric(r$ci.ub))
  expect_true(length(r$estimate) == 1L)

  # metadata fields
  expect_equal(r$measure, "PLO")
  expect_equal(r$cluster, "studlab")
  expect_equal(r$rho, 0.5)
  expect_equal(r$slab, "studlab")
  expect_equal(r$TE_id, "TE_id")

  # V matrix
  expect_true(is.matrix(r$V))
  expect_equal(nrow(r$V), nrow(d))
  expect_equal(ncol(r$V), nrow(d))

  # data field contains escalc columns
  expect_true("yi" %in% names(r$data))
  expect_true("vi" %in% names(r$data))
  expect_true("TE_id" %in% names(r$data))
})

test_that("meta3L works for PAS measure", {
  d <- make_pas_data()
  r <- meta3L(d, slab = "studlab", xi = "xi", ni = "ni", measure = "PAS")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$measure, "PAS")
  expect_true(is.numeric(r$estimate))
  # PAS back-transform returns a proportion (0-1)
  expect_true(r$estimate >= 0 && r$estimate <= 1)
})

test_that("meta3L works for SMD measure", {
  d <- make_smd_data()
  r <- meta3L(d,
              slab  = "studlab",
              m1i   = "m1i", sd1i = "sd1i", n1i = "n1i",
              m2i   = "m2i", sd2i = "sd2i", n2i = "n2i",
              measure = "SMD")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$measure, "SMD")
  expect_true(is.numeric(r$estimate))
})

test_that("meta3L works for MD measure", {
  d <- make_md_data()
  r <- meta3L(d,
              slab  = "studlab",
              m1i   = "m1i", sd1i = "sd1i", n1i = "n1i",
              m2i   = "m2i", sd2i = "sd2i", n2i = "n2i",
              measure = "MD")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$measure, "MD")
})

test_that("meta3L works for RR measure", {
  d <- make_rr_data()
  r <- meta3L(d,
              slab = "studlab",
              ai   = "ai", bi = "bi", ci = "ci", di = "di",
              measure = "RR")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$measure, "RR")
  expect_true(is.numeric(r$estimate))
  expect_true(r$estimate > 0)  # RR is always positive after exp()
})

test_that("meta3L works for OR measure", {
  d <- make_or_data()
  r <- meta3L(d,
              slab = "studlab",
              ai   = "ai", bi = "bi", ci = "ci", di = "di",
              measure = "OR")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$measure, "OR")
  expect_true(r$estimate > 0)
})

test_that("meta3L rejects unsupported measure PFT", {
  d <- make_plo_data()
  expect_error(
    meta3L(d, slab = "studlab", xi = "xi", ni = "ni", measure = "PFT"),
    regexp = "not supported"
  )
})

test_that("meta3L errors on missing required column", {
  d <- make_plo_data()
  # Pass a column name that does not exist in the data frame
  expect_error(
    meta3L(d, slab = "studlab", xi = "no_such_col", ni = "ni", measure = "PLO"),
    regexp = "no_such_col"
  )
})

test_that("meta3L errors when slab column is missing", {
  d <- make_plo_data()
  expect_error(
    meta3L(d, slab = "missing_slab", xi = "xi", ni = "ni", measure = "PLO"),
    regexp = "missing_slab"
  )
})

test_that("meta3L warns on NA rows and filters them", {
  d <- make_plo_data()
  d$xi[2L] <- NA  # introduce one NA in xi column
  expect_warning(
    r <- meta3L(d, slab = "studlab", xi = "xi", ni = "ni", measure = "PLO"),
    regexp = "NA"
  )
  # After filtering, data should have one fewer row than original
  expect_equal(nrow(r$data), nrow(make_plo_data()) - 1L)
})

test_that("meta3L respects custom cluster argument", {
  d <- make_plo_data()
  # Rename studlab to 'mygroup' and use that as cluster
  d$mygroup <- d$studlab
  r <- meta3L(d, slab = "mygroup", xi = "xi", ni = "ni",
               measure = "PLO", cluster = "mygroup")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$cluster, "mygroup")
})

test_that("print.meta3l_result produces expected output", {
  d <- make_plo_data()
  r <- meta3L(d, slab = "studlab", xi = "xi", ni = "ni", measure = "PLO")
  out <- capture.output(print(r))
  combined <- paste(out, collapse = "\n")

  expect_true(grepl("Pooled", combined, ignore.case = TRUE))
  expect_true(grepl("I", combined))
  expect_true(grepl("[Bb]etween", combined))
  expect_true(grepl("[Ww]ithin", combined))
  expect_true(grepl("k", combined))  # number of studies
  expect_true(grepl("n", combined))  # number of effect sizes
})

test_that("summary.meta3l_result shows sigma-squared components", {
  d <- make_plo_data()
  r <- meta3L(d, slab = "studlab", xi = "xi", ni = "ni", measure = "PLO")
  out <- capture.output(summary(r))
  combined <- paste(out, collapse = "\n")

  # summary should include everything print has
  expect_true(grepl("Pooled", combined, ignore.case = TRUE))
  # plus sigma2 components
  expect_true(grepl("sigma", combined, ignore.case = TRUE))
})

test_that("meta3L with custom rho returns correct rho in result", {
  d <- make_plo_data()
  r <- meta3L(d, slab = "studlab", xi = "xi", ni = "ni",
               measure = "PLO", rho = 0.3)

  expect_equal(r$rho, 0.3)
})

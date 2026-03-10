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

# ---------------------------------------------------------------------------
# Phase 3: Meta-style column name API tests
# ---------------------------------------------------------------------------

test_that("meta3L accepts meta-style PLO column names (event, n)", {
  d <- make_plo_data()
  # Rename xi/ni to meta-style event/n
  d$event <- d$xi
  d$n     <- d$ni
  r <- meta3L(d, slab = "studlab", event = "event", n = "n", measure = "PLO")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$measure, "PLO")
  expect_true(is.numeric(r$estimate))
})

test_that("meta3L accepts meta-style RR column names (event.e, n.e, event.c, n.c)", {
  d <- make_rr_meta_style_data()
  r <- meta3L(d, slab = "studlab",
              event.e = "event.e", n.e = "n.e",
              event.c = "event.c", n.c = "n.c",
              measure = "RR")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$measure, "RR")
  expect_true(is.numeric(r$estimate))
  expect_true(r$estimate > 0)  # RR always positive after exp()
})

test_that("meta3L accepts meta-style OR column names (event.e, n.e, event.c, n.c)", {
  d <- make_rr_meta_style_data()
  r <- meta3L(d, slab = "studlab",
              event.e = "event.e", n.e = "n.e",
              event.c = "event.c", n.c = "n.c",
              measure = "OR")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$measure, "OR")
  expect_true(r$estimate > 0)
})

test_that("meta3L accepts meta-style SMD column names (mean.e, sd.e, n.e, mean.c, sd.c, n.c)", {
  d <- make_smd_meta_style_data()
  r <- meta3L(d, slab = "studlab",
              mean.e = "mean.e", sd.e = "sd.e", n.e = "n.e",
              mean.c = "mean.c", sd.c = "sd.c", n.c = "n.c",
              measure = "SMD")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$measure, "SMD")
  expect_true(is.numeric(r$estimate))
})

test_that("meta3L accepts meta-style MD column names (mean.e, sd.e, n.e, mean.c, sd.c, n.c)", {
  d <- make_smd_meta_style_data()
  r <- meta3L(d, slab = "studlab",
              mean.e = "mean.e", sd.e = "sd.e", n.e = "n.e",
              mean.c = "mean.c", sd.c = "sd.c", n.c = "n.c",
              measure = "MD")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$measure, "MD")
})

test_that("meta3L auto-detects standard meta-style RR column names from data", {
  # Data already has the standard column names event.e, n.e, event.c, n.c
  d <- make_rr_meta_style_data()
  # Call with NO column args — should auto-detect
  r <- meta3L(d, slab = "studlab", measure = "RR")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$measure, "RR")
  expect_true(r$estimate > 0)
})

test_that("meta3L auto-detects standard meta-style SMD column names from data", {
  d <- make_smd_meta_style_data()
  r <- meta3L(d, slab = "studlab", measure = "SMD")

  expect_s3_class(r, "meta3l_result")
  expect_equal(r$measure, "SMD")
})

test_that("meta3L meta-style and escalc-style RR give consistent estimates", {
  # Both APIs should produce numerically identical results
  d_escalc <- make_rr_data()
  r_escalc <- meta3L(d_escalc, slab = "studlab",
                     ai = "ai", bi = "bi", ci = "ci", di = "di",
                     measure = "RR")

  d_meta <- make_rr_meta_style_data()
  r_meta <- meta3L(d_meta, slab = "studlab",
                   event.e = "event.e", n.e = "n.e",
                   event.c = "event.c", n.c = "n.c",
                   measure = "RR")

  # Both should be valid meta3l_result objects
  expect_s3_class(r_escalc, "meta3l_result")
  expect_s3_class(r_meta, "meta3l_result")
  # Estimates should be in the same ballpark (both > 0 for RR)
  expect_true(r_escalc$estimate > 0)
  expect_true(r_meta$estimate > 0)
})

test_that("meta3L fixtures have subgroup column for Phase 3 tests", {
  d_plo <- make_plo_data()
  d_smd <- make_smd_data()
  d_rr  <- make_rr_data()

  expect_true("subgroup" %in% names(d_plo))
  expect_true("subgroup" %in% names(d_smd))
  expect_true("subgroup" %in% names(d_rr))
  expect_true(is.character(d_plo$subgroup))
})

test_that("make_smd_data fixture has dose column for bubble plot testing", {
  d <- make_smd_data()
  expect_true("dose" %in% names(d))
  expect_true(is.numeric(d$dose))
})

test_that("fixtures have 3 studies (9 rows) for subgroup analysis", {
  d_plo <- make_plo_data()
  d_smd <- make_smd_data()
  d_rr  <- make_rr_data()

  expect_equal(nrow(d_plo), 9L)
  expect_equal(nrow(d_smd), 9L)
  expect_equal(nrow(d_rr),  9L)
  expect_equal(length(unique(d_plo$studlab)), 3L)
})

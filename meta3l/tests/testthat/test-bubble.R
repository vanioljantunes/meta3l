# Tests for bubble.meta3L() — meta-regression bubble plot
# Covers MREG-01 through MREG-04

test_that("bubble.meta3L returns list with $summary and $file", {
  dat    <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  out <- bubble(result, mod = "dose", file = NULL)
  expect_type(out, "list")
  expect_true("summary" %in% names(out))
  expect_true("file"    %in% names(out))
})

test_that("bubble.meta3L $summary has required columns", {
  dat    <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  out <- bubble(result, mod = "dose", file = NULL)
  expect_s3_class(out$summary, "data.frame")
  expect_true(all(c("estimate", "ci.lb", "ci.ub", "r2", "pval") %in% names(out$summary)))
})

test_that("bubble.meta3L $summary$pval is numeric in [0, 1]", {
  dat    <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  out <- bubble(result, mod = "dose", file = NULL)
  expect_true(is.numeric(out$summary$pval))
  expect_true(out$summary$pval >= 0 && out$summary$pval <= 1)
})

test_that("bubble.meta3L $summary$r2 is numeric in [0, 1]", {
  dat    <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  out <- bubble(result, mod = "dose", file = NULL)
  expect_true(is.numeric(out$summary$r2))
  expect_true(out$summary$r2 >= 0 && out$summary$r2 <= 1)
})

test_that("bubble.meta3L produces non-empty PNG file", {
  dat    <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  tmp_dir <- tempdir()
  tmp_file <- file.path(tmp_dir, "test_bubble.png")
  out <- bubble(result, mod = "dose", file = tmp_file)
  expect_true(file.exists(tmp_file))
  expect_gt(file.size(tmp_file), 5000L)
  file.remove(tmp_file)
})

test_that("bubble.meta3L auto-naming contains 'bubble_dose'", {
  dat    <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i",
                   name = "test_analysis")
  withr::with_options(list(meta3l.mwd = tempdir()), {
    out <- bubble(result, mod = "dose", file = character(0))
    expect_true(grepl("bubble_dose", out$file))
    if (!is.null(out$file) && file.exists(out$file)) file.remove(out$file)
  })
})

test_that("bubble.meta3L errors on factor moderator with mention of moderator.meta3L", {
  dat    <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  expect_error(bubble(result, mod = "subgroup"), "moderator")
})

test_that("bubble.meta3L errors on missing column with 'not found'", {
  dat    <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  expect_error(bubble(result, mod = "nonexistent"), "not found")
})

test_that("bubble.meta3L $file is NULL when file=NULL", {
  dat    <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  out <- bubble(result, mod = "dose", file = NULL)
  expect_null(out$file)
})

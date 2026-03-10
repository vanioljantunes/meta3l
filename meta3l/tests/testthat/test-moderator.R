test_that("moderator.meta3L() returns object of class moderator_result", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  mod_result <- moderator(result, subgroup = "subgroup")
  expect_s3_class(mod_result, "moderator_result")
})

test_that("moderator_result$wald contains QM, QMp, df fields", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  mod_result <- moderator(result, subgroup = "subgroup")

  expect_true(is.numeric(mod_result$wald$QM))
  expect_true(is.numeric(mod_result$wald$QMp))
  expect_true(mod_result$wald$QMp >= 0 && mod_result$wald$QMp <= 1)
  expect_true(is.numeric(mod_result$wald$df) || is.integer(mod_result$wald$df))
})

test_that("moderator_result$lrt contains statistic, pval, df fields", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  mod_result <- moderator(result, subgroup = "subgroup")

  expect_true(!is.null(mod_result$lrt$statistic))
  expect_true(is.numeric(mod_result$lrt$statistic))
  expect_true(!is.null(mod_result$lrt$pval))
  expect_true(is.numeric(mod_result$lrt$pval))
  expect_true(mod_result$lrt$pval >= 0 && mod_result$lrt$pval <= 1)
  expect_true(!is.null(mod_result$lrt$df))
  expect_true(is.numeric(mod_result$lrt$df) || is.integer(mod_result$lrt$df))
})

test_that("moderator_result$estimates is a data.frame with required columns", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  mod_result <- moderator(result, subgroup = "subgroup")

  expect_s3_class(mod_result$estimates, "data.frame")
  expect_true(all(c("level", "k", "estimate", "ci.lb", "ci.ub") %in%
                    names(mod_result$estimates)))
  # should have one row per subgroup level
  n_levels <- length(unique(dat$subgroup))
  expect_equal(nrow(mod_result$estimates), n_levels)
})

test_that("moderator_result$estimates values are back-transformed (SMD = identity)", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  mod_result <- moderator(result, subgroup = "subgroup")

  # For SMD, transf = identity, so estimate should be a plain numeric
  expect_true(is.numeric(mod_result$estimates$estimate))
  expect_true(is.numeric(mod_result$estimates$ci.lb))
  expect_true(is.numeric(mod_result$estimates$ci.ub))
})

test_that("moderator_result$estimates$k contains observation counts per subgroup", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  mod_result <- moderator(result, subgroup = "subgroup")

  expect_true(all(mod_result$estimates$k > 0))
  expect_equal(sum(mod_result$estimates$k), nrow(dat))
})

test_that("moderator_result contains subgroup, measure, transf fields", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  mod_result <- moderator(result, subgroup = "subgroup")

  expect_equal(mod_result$subgroup, "subgroup")
  expect_equal(mod_result$measure, "SMD")
  expect_true(is.function(mod_result$transf))
})

test_that("moderator.meta3L() errors on numeric moderator with message about bubble.meta3L()", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  expect_error(
    moderator(result, subgroup = "dose"),
    "bubble"
  )
})

test_that("moderator.meta3L() errors when subgroup column not found in data", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  expect_error(
    moderator(result, subgroup = "nonexistent"),
    "not found"
  )
})

test_that("print.moderator_result() produces non-empty output", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  mod_result <- moderator(result, subgroup = "subgroup")

  out <- capture.output(print(mod_result))
  expect_true(length(out) > 0)
})

test_that("print.moderator_result() output contains moderator name", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  mod_result <- moderator(result, subgroup = "subgroup")

  out <- paste(capture.output(print(mod_result)), collapse = "\n")
  expect_true(grepl("subgroup", out, ignore.case = TRUE))
})

test_that("print.moderator_result() output contains Wald test info", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  mod_result <- moderator(result, subgroup = "subgroup")

  out <- paste(capture.output(print(mod_result)), collapse = "\n")
  expect_true(grepl("QM|Wald", out, ignore.case = FALSE))
})

test_that("print.moderator_result() output contains LRT info", {
  dat <- make_smd_data()
  result <- meta3L(dat, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  mod_result <- moderator(result, subgroup = "subgroup")

  out <- paste(capture.output(print(mod_result)), collapse = "\n")
  expect_true(grepl("LRT|chi", out, ignore.case = TRUE))
})

test_that("moderator.meta3L() works with PLO measure", {
  dat <- make_plo_data()
  result <- meta3L(dat, slab = "studlab", measure = "PLO",
                   xi = "xi", ni = "ni")
  mod_result <- moderator(result, subgroup = "subgroup")
  expect_s3_class(mod_result, "moderator_result")
  expect_true(is.numeric(mod_result$wald$QM))
  # for PLO, back-transform is ilogit, so estimates should be in (0,1)
  expect_true(all(mod_result$estimates$estimate > 0 &
                    mod_result$estimates$estimate < 1))
})

test_that("moderator.meta3L() warns when a subgroup level has only 1 observation", {
  dat <- make_smd_data()
  # add a third subgroup level with only 1 row
  single_row <- dat[1L, ]
  single_row$subgroup <- "Group C"
  dat_ext <- rbind(dat, single_row)
  result <- meta3L(dat_ext, slab = "studlab", measure = "SMD",
                   m1i = "m1i", sd1i = "sd1i", n1i = "n1i",
                   m2i = "m2i", sd2i = "sd2i", n2i = "n2i")
  expect_warning(
    moderator(result, subgroup = "subgroup"),
    "1 observation"
  )
})

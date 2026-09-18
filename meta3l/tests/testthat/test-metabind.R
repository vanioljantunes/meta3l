# bind_arm_summary(): patient counts without double counting

arm_dat <- data.frame(
  studlab      = c(rep("A", 4), rep("B", 6), "C"),
  intervention = c("neuro", "hepatic", "neuro", "hepatic",
                   "total", "neuro", "hepatic", "total", "neuro", "hepatic",
                   "neuro"),
  side         = c("right", "right", "left", "left",
                   "right", "right", "right", "left", "left", "left",
                   "mean"),
  n.e    = c(20, 13, 20, 13, 63, 32, 31, 63, 32, 31, 19),
  mean.e = rep(10, 11),
  sd.e   = rep(2, 11),
  n.c    = c(20, 20, 20, 20, 14, 14, 14, 14, 14, 14, 25),
  mean.c = rep(5, 11),
  sd.c   = rep(2, 11),
  stringsAsFactors = FALSE
)

test_that("default keeps the largest row per cluster", {
  out <- bind_arm_summary(arm_dat, "studlab", "MD")
  expect_equal(unname(out[["n_e"]]), 20 + 63 + 19)
  expect_equal(unname(out[["n_c"]]), 20 + 14 + 25)
})

test_that("patient groups are added up unless a total row exists", {
  out <- bind_arm_summary(arm_dat, "studlab", "MD", by = "intervention")
  # A: neuro + hepatic, B: total row, C: only group with data
  expect_equal(unname(out[["n_e"]]), 33 + 63 + 19)
  # controls are shared by the groups: one row per cluster
  expect_equal(unname(out[["n_c"]]), 20 + 14 + 25)
})

test_that("an unknown grouping column falls back to one row per cluster", {
  out <- bind_arm_summary(arm_dat, "studlab", "MD", by = "nope")
  expect_equal(unname(out[["n_e"]]), 20 + 63 + 19)
})

test_that("missing group labels are not dropped", {
  d <- arm_dat
  d$intervention[11] <- NA
  out <- bind_arm_summary(d, "studlab", "MD", by = "intervention")
  expect_equal(unname(out[["n_e"]]), 33 + 63 + 19)
})

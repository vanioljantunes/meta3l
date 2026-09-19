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

# metabind3L(): one breakdown per analysis

bind_dat <- function(seed) {
  set.seed(seed)
  data.frame(
    studlab = rep(paste0("S", 1:6), each = 2),
    side    = rep(c("left", "right"), 6),
    era     = rep(c("old", "new"), each = 6),
    n.e     = 20, mean.e = rnorm(12, 10, 1), sd.e = 2,
    n.c     = 20, mean.c = rnorm(12, 8, 1),  sd.c = 2,
    stringsAsFactors = FALSE
  )
}

test_that("a list of subgroups gives each analysis its own breakdown", {
  a <- meta3L(bind_dat(1), slab = "studlab", measure = "MD", name = "A")
  b <- meta3L(bind_dat(2), slab = "studlab", measure = "MD", name = "B")
  mb <- expect_silent(
    metabind3L(A = a, B = b, subgroup = list("side", "era"))
  )
  subs <- mb$rows[mb$rows$type == "sub", c("block", "label")]
  expect_equal(subs$block, c("A", "B"))
  expect_equal(subs$label, c("side", "era"))
  lv <- mb$rows[mb$rows$kind == "level", c("block", "label")]
  expect_equal(sort(lv$label[lv$block == "A"]), c("left", "right"))
  expect_equal(sort(lv$label[lv$block == "B"]), c("new", "old"))
})

test_that("a NULL entry leaves that analysis with its pooled row only", {
  a <- meta3L(bind_dat(1), slab = "studlab", measure = "MD", name = "A")
  b <- meta3L(bind_dat(2), slab = "studlab", measure = "MD", name = "B")
  mb <- metabind3L(A = a, B = b, subgroup = list("side", NULL))
  expect_equal(mb$rows$block[mb$rows$type == "sub"], "A")
  expect_equal(sum(mb$rows$kind == "overall"), 2L)
})

test_that("a subgroup list of the wrong length is an error", {
  a <- meta3L(bind_dat(1), slab = "studlab", measure = "MD", name = "A")
  b <- meta3L(bind_dat(2), slab = "studlab", measure = "MD", name = "B")
  expect_error(
    metabind3L(A = a, B = b, subgroup = list("side")),
    "one entry per analysis"
  )
})

test_that("a character vector still applies to every analysis", {
  a <- meta3L(bind_dat(1), slab = "studlab", measure = "MD", name = "A")
  b <- meta3L(bind_dat(2), slab = "studlab", measure = "MD", name = "B")
  mb <- metabind3L(A = a, B = b, subgroup = "side")
  expect_equal(mb$rows$block[mb$rows$type == "sub"], c("A", "B"))
})

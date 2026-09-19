# Renders the example plots shown in the tutorial image.
# Run from the package root: Rscript tutorial/plot.R
#
# Data: dat.bornmann2007 from metadat (installed with metafor): gender
# differences in grant and fellowship awards, 66 odds ratios in 21 studies.

suppressMessages(devtools::load_all(quiet = TRUE))
dir.create("man/figures", showWarnings = FALSE, recursive = TRUE)

d <- metadat::dat.bornmann2007
dat <- data.frame(
  studlab = d$study,
  type    = d$type,
  year    = d$year,
  event.e = d$waward, n.e = d$wtotal,   # women: awarded / applied
  event.c = d$maward, n.c = d$mtotal    # men:   awarded / applied
)

# All awards: three-level OR
r <- meta3L(dat, slab = "studlab", measure = "OR", name = "awards",
            group.e = "Women", group.c = "Men")
print(r)

# One outcome drawn in full: fellowships (26 effects in 11 studies)
r_fel <- meta3L(dat[dat$type == "Fellowship", ], slab = "studlab",
                measure = "OR", name = "fellowships",
                group.e = "Women", group.c = "Men")
forest3L(r_fel, at = c(0.5, 1, 2, 3, 4), xlim = c(0, 5),
         title = "Fellowship awards, women vs men",
         file = "man/figures/tutorial-forest.png")

# All awards, broken down by funding type, on one summary forest
mb <- metabind3L(`All awards` = r, subgroup = "type")
print(mb)
forest3L(mb, analysis.lab = "Analysis",
         xlab = "Odds ratio of an award, women vs men",
         title = "Awards by funding type",
         file = "man/figures/tutorial-metabind.png")

# Two outcomes in one image, each with its own breakdown: fellowships by
# decade, grants by the size of the applicant pool
dat$decade <- ifelse(dat$year < 2000, "Before 2000", "2000 onwards")
pool <- dat$n.e + dat$n.c
dat$applicants <- ifelse(pool >= stats::median(pool), "Large pool",
                         "Small pool")

r_fel2 <- meta3L(dat[dat$type == "Fellowship", ], slab = "studlab",
                 measure = "OR", name = "fellowships",
                 group.e = "Women", group.c = "Men")
r_gra2 <- meta3L(dat[dat$type == "Grant", ], slab = "studlab",
                 measure = "OR", name = "grants",
                 group.e = "Women", group.c = "Men")

mb2 <- metabind3L(Fellowships = r_fel2, Grants = r_gra2,
                  subgroup = list("decade", "applicants"))
print(mb2)
forest3L(mb2, analysis.lab = "Outcome",
         xlab = "Odds ratio of an award, women vs men",
         title = "Two outcomes, one breakdown each",
         file = "man/figures/tutorial-metabind-outcomes.png")

cat("man/figures/tutorial-forest.png, tutorial-metabind.png, tutorial-metabind-outcomes.png written
")

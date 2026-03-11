# meta3l <img src="man/figures/logo.png" align="right" height="139" alt="" />

> Three-Level Meta-Analysis via Metafor

`meta3l` wraps the key steps of a three-level meta-analysis into a **single function call**: effect size computation (`escalc`), variance-covariance matrix construction (`vcalc`), multilevel random-effects modeling (`rma.mv`), cluster-robust inference (`clubSandwich`), and I-squared decomposition — all handled transparently.

## Supported Effect Size Measures

| Measure | Description |
|---------|-------------|
| `PLO`   | Proportion (logit-transformed) |
| `PAS`   | Proportion (arcsine-transformed) |
| `SMD`   | Standardized mean difference |
| `MD`    | Raw mean difference |
| `RR`    | Log risk ratio |
| `OR`    | Log odds ratio |

Back-transformation to the original scale is automatic.

## Installation

```r
# install.packages("remotes")
remotes::install_github("vanioljantunes/meta3l", subdir = "meta3l")
```

## Tutorial

### 1. Fit a Three-Level Model

```r
library(meta3l)

# Example: prevalence data with multiple effect sizes per study
dat <- data.frame(
  studlab = rep(c("Adams 2019", "Baker 2020", "Clark 2021", "Davis 2022"), each = 3),
  event   = c(12, 15, 10, 20, 18, 22, 8, 11, 9, 25, 19, 23),
  n       = c(100, 120, 95, 150, 130, 160, 80, 90, 85, 200, 170, 190),
  region  = rep(c("North", "South"), each = 6),
  year    = c(2019, 2019, 2019, 2020, 2020, 2020, 2021, 2021, 2021, 2022, 2022, 2022)
)

result <- meta3L(dat, slab = "studlab", event = "event", n = "n", measure = "PLO")
```

Each row is one effect size; each unique `studlab` value is a cluster (study). The default cluster column is `"studlab"` — pass `cluster = "author"` to use a different column.

### 2. Examine Results

```r
print(result)
summary(result)
```

Key output:
- **Pooled estimate** (back-transformed) with 95% CI
- **I-squared decomposition**: `I2_total`, `I2_between`, `I2_within`

Access individual components:

```r
result$estimate    # back-transformed pooled estimate
result$ci.lb       # lower 95% CI
result$ci.ub       # upper 95% CI
result$i2          # list: total, between, within
result$model       # underlying rma.mv object (full metafor access)
```

### 3. Forest Plot

```r
# Display in viewer
forest.meta3L(result, file = NULL)

# Save to PNG (auto-named)
forest.meta3L(result)

# With annotation columns
forest.meta3L(
  result,
  ilab     = c("event", "n"),
  ilab.lab = c("Events", "Total"),
  file     = NULL
)

# Save as PDF
forest.meta3L(result, file = "my_forest.pdf", format = "pdf")
```

### 4. Subgroup Analysis

Test a categorical moderator with Wald test, likelihood ratio test, and per-subgroup estimates:

```r
mod_result <- moderator(result, subgroup = "region")
print(mod_result)
```

Visualise with a grouped forest plot:

```r
forest_subgroup.meta3L(result, subgroup = "region", file = NULL)
```

### 5. Meta-Regression (Bubble Plot)

Fit a meta-regression with a continuous moderator:

```r
bub <- bubble.meta3L(result, mod = "year", file = NULL)
bub$summary   # estimate, CI, R-squared, slope, robust p-value
```

### 6. Sensitivity Analysis (Leave-One-Out)

**Cluster-level LOO** — drop one study at a time:

```r
loo_c <- loo_cluster(result, file = NULL)
loo_c$table   # pooled estimate and I2 after dropping each study
```

**Effect-level LOO** — drop one effect size at a time:

```r
loo_e <- loo_effect(result, file = NULL)
loo_e$table
```

Both produce influence plots showing how the pooled estimate shifts when each observation is removed.

### 7. Reading Multi-Sheet Excel Files

```r
sheets <- read_multisheet_excel("path/to/data.xlsx")
names(sheets)          # sheet names
sheets[["Sheet1"]]     # individual sheet as data frame
```

## Typical Workflow

```
1. Fit       →  result <- meta3L(dat, slab, event, n, measure)
2. Inspect   →  print(result) / summary(result)
3. Visualise →  forest.meta3L(result)
4. Subgroup  →  moderator(result, subgroup) + forest_subgroup.meta3L(result, subgroup)
5. Regress   →  bubble.meta3L(result, mod)
6. Sensitiv. →  loo_cluster(result) / loo_effect(result)
```

All six effect size measures follow the same workflow — `meta3l` selects the correct `escalc` call and back-transformation automatically.

## Requirements

- R >= 4.0.0
- [metafor](https://cran.r-project.org/package=metafor) >= 4.0-0
- [clubSandwich](https://cran.r-project.org/package=clubSandwich) >= 0.5.0
- [readxl](https://cran.r-project.org/package=readxl) >= 1.3.0

## License

MIT

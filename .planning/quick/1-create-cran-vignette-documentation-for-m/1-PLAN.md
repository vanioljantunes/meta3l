---
phase: quick
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - meta3l/DESCRIPTION
  - meta3l/vignettes/introduction.Rmd
autonomous: true
requirements: [VIGNETTE-01]

must_haves:
  truths:
    - "R CMD build includes the vignette in the tarball"
    - "VignetteBuilder and Suggests fields in DESCRIPTION are CRAN-compliant"
    - "Vignette covers the full meta3l workflow from data to sensitivity analysis"
  artifacts:
    - path: "meta3l/vignettes/introduction.Rmd"
      provides: "Comprehensive introductory vignette"
      contains: "VignetteIndexEntry"
    - path: "meta3l/DESCRIPTION"
      provides: "Updated package metadata"
      contains: "VignetteBuilder: knitr"
  key_links:
    - from: "meta3l/vignettes/introduction.Rmd"
      to: "meta3l/DESCRIPTION"
      via: "VignetteBuilder field"
      pattern: "VignetteBuilder:\\s*knitr"
---

<objective>
Create a CRAN-style vignette for the meta3l package that walks users through the complete three-level meta-analysis workflow.

Purpose: Provide long-form documentation that CRAN expects and users need — covering installation, basic usage, result interpretation, forest plots, subgroup/moderator analysis, meta-regression bubble plots, and leave-one-out sensitivity analysis.

Output: A working vignette (.Rmd) and updated DESCRIPTION with proper vignette build dependencies.
</objective>

<execution_context>
@C:/Users/vanio/.claude/get-shit-done/workflows/execute-plan.md
@C:/Users/vanio/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@meta3l/DESCRIPTION
@meta3l/man/meta3L.Rd
@meta3l/man/forest.meta3L.Rd
@meta3l/man/moderator.meta3l_result.Rd
@meta3l/man/bubble.Rd
@meta3l/man/forest_subgroup.Rd
@meta3l/man/loo_cluster.meta3l_result.Rd
@meta3l/man/loo_effect.meta3l_result.Rd
@meta3l/man/summary.meta3l_result.Rd
@meta3l/man/print.meta3l_result.Rd
@meta3l/man/read_multisheet_excel.Rd
</context>

<tasks>

<task type="auto">
  <name>Task 1: Update DESCRIPTION with vignette build dependencies</name>
  <files>meta3l/DESCRIPTION</files>
  <action>
Add `VignetteBuilder: knitr` as a new top-level field in DESCRIPTION (after RoxygenNote or before Depends).

Add `knitr` and `rmarkdown` to the existing Suggests field. The updated Suggests should read:

```
Suggests:
    testthat (>= 3.0.0),
    writexl,
    mockery,
    knitr,
    rmarkdown
```

Do NOT change any other fields. Preserve exact whitespace/formatting conventions already in the file.
  </action>
  <verify>
    <automated>grep -c "VignetteBuilder: knitr" meta3l/DESCRIPTION && grep -c "knitr" meta3l/DESCRIPTION && grep -c "rmarkdown" meta3l/DESCRIPTION</automated>
  </verify>
  <done>DESCRIPTION has VignetteBuilder: knitr, and knitr + rmarkdown in Suggests</done>
</task>

<task type="auto">
  <name>Task 2: Create comprehensive introductory vignette</name>
  <files>meta3l/vignettes/introduction.Rmd</files>
  <action>
Create directory `meta3l/vignettes/` if it does not exist.

Create `meta3l/vignettes/introduction.Rmd` with the following structure. All code chunks MUST use `eval = FALSE` since the vignette uses simulated data and the package depends on metafor which may not be available during CRAN check builds. Use `results = "hide"` is NOT needed when eval is FALSE.

**YAML header:**
```yaml
---
title: "Introduction to meta3l: Three-Level Meta-Analysis"
author: "meta3l package authors"
date: "`r Sys.Date()`"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Introduction to meta3l: Three-Level Meta-Analysis}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---
```

**Section 1: Introduction**
- Brief explanation of what three-level meta-analysis is and when it is needed (multiple effect sizes nested within studies)
- What meta3l does: wraps metafor's escalc, vcalc, rma.mv, and robust() into a single call
- Mention supported effect size measures: PLO, PAS (proportions), SMD, MD (means), RR, OR (binary outcomes)

**Section 2: Installation**
```r
# From source (development version)
# install.packages("meta3l", repos = NULL, type = "source")

# Or using devtools/remotes if hosted on GitHub
# remotes::install_github("user/meta3l")
```

**Section 3: Quick Start — Fitting a Model**
Create a simulated example dataset with proportions (PLO measure) — use `data.frame()` with studlab, event, and n columns. At least 4 studies with 2-3 effect sizes each. Show:

```r
library(meta3l)

# Simulated dataset: prevalence of a condition across studies
dat <- data.frame(
  studlab = rep(c("Adams 2019", "Baker 2020", "Clark 2021", "Davis 2022"), each = 3),
  event   = c(12, 15, 10, 20, 18, 22, 8, 11, 9, 25, 19, 23),
  n       = c(100, 120, 95, 150, 130, 160, 80, 90, 85, 200, 170, 190),
  region  = rep(c("North", "South"), each = 6),
  year    = c(2019, 2019, 2019, 2020, 2020, 2020, 2021, 2021, 2021, 2022, 2022, 2022)
)

result <- meta3L(dat, slab = "studlab", event = "event", n = "n", measure = "PLO")
```

**Section 4: Examining Results**
Show `print(result)` and `summary(result)` output. Explain the key components:
- Back-transformed pooled estimate and 95% CI
- Number of studies (clusters) vs. number of effect sizes
- I-squared decomposition: total, between-study, within-study
- Accessing components: `result$estimate`, `result$ci.lb`, `result$ci.ub`, `result$i2`
- The underlying metafor model: `result$model`

**Section 5: Forest Plots**
```r
# Display in viewer
forest.meta3L(result, file = NULL)

# Save to PNG (auto-named)
forest.meta3L(result)

# With annotation columns
forest.meta3L(result, ilab = c("event", "n"), ilab.lab = c("Events", "Total"), file = NULL)

# Save as PDF with explicit path
forest.meta3L(result, file = "my_forest.pdf", format = "pdf")
```
Explain key arguments: ilab/ilab.lab, sortvar, refline, xlim, showweights, file/format.

**Section 6: Subgroup Analysis**
Show how to use `moderator()` for categorical moderator testing:
```r
mod_result <- moderator(result, subgroup = "region")
print(mod_result)
```
Explain: Wald test, LRT, per-subgroup estimates.

Then show the subgroup forest plot:
```r
forest_subgroup.meta3L(result, subgroup = "region", file = NULL)
```

**Section 7: Meta-Regression (Continuous Moderator)**
Show how to use `bubble.meta3L()` for continuous moderator:
```r
bub <- bubble.meta3L(result, mod = "year", file = NULL)
bub$summary  # estimate, CI, R-squared, p-value
```
Explain: bubble sizes proportional to precision, regression line with CI band, robust p-value.

**Section 8: Sensitivity Analysis — Leave-One-Out**
Show both LOO methods:
```r
# Cluster-level LOO (drop one study at a time)
loo_c <- loo_cluster(result, file = NULL)
loo_c$table

# Effect-level LOO (drop one effect size at a time)
loo_e <- loo_effect(result, file = NULL)
loo_e$table
```
Explain: how to interpret influence plots, what large changes in estimate/I-squared mean.

**Section 9: Working with Excel Data**
Brief section on `read_multisheet_excel()`:
```r
# Read all sheets from an Excel workbook
sheets <- read_multisheet_excel("path/to/data.xlsx")
# Returns a named list of data frames, one per sheet
```

**Section 10: Summary**
- Recap the workflow: meta3L() -> print/summary -> forest plot -> moderator/bubble -> LOO
- Point to `?meta3L`, `?forest.meta3L`, etc. for full argument documentation
- Mention that meta3l supports all six effect size measures with automatic back-transformation

**Style guidelines:**
- Use `## ` for main sections (not `# ` — that is the title)
- Use backtick-fenced code blocks with `{r eval=FALSE}` for all R chunks
- Keep prose concise and practical — this is a workflow guide, not a textbook
- Do NOT use emojis
- Total length: approximately 200-300 lines of Rmd
  </action>
  <verify>
    <automated>test -f meta3l/vignettes/introduction.Rmd && grep -c "VignetteIndexEntry" meta3l/vignettes/introduction.Rmd && grep -c "VignetteEngine" meta3l/vignettes/introduction.Rmd && grep -c "meta3L" meta3l/vignettes/introduction.Rmd</automated>
  </verify>
  <done>Vignette file exists with proper YAML header (VignetteIndexEntry, VignetteEngine), covers all 10 sections (intro, install, quick start, results, forest, subgroup, meta-regression, LOO, Excel, summary), and all code chunks use eval=FALSE</done>
</task>

</tasks>

<verification>
1. `grep "VignetteBuilder" meta3l/DESCRIPTION` shows `VignetteBuilder: knitr`
2. `grep "knitr\|rmarkdown" meta3l/DESCRIPTION` shows both in Suggests
3. `test -d meta3l/vignettes` confirms directory exists
4. `head -15 meta3l/vignettes/introduction.Rmd` shows correct YAML header with VignetteIndexEntry
5. `grep -c "^##" meta3l/vignettes/introduction.Rmd` shows at least 9 sections
6. `grep "eval.*FALSE" meta3l/vignettes/introduction.Rmd` confirms no chunks try to execute
</verification>

<success_criteria>
- DESCRIPTION has VignetteBuilder: knitr and knitr + rmarkdown in Suggests
- meta3l/vignettes/introduction.Rmd exists with valid vignette YAML header
- Vignette covers: installation, meta3L(), print/summary, forest plots, subgroup analysis, moderator analysis, bubble plots, LOO sensitivity, Excel reading
- All code chunks use eval=FALSE (safe for CRAN check)
- No existing DESCRIPTION fields are broken
</success_criteria>

<output>
After completion, create `.planning/quick/1-create-cran-vignette-documentation-for-m/1-SUMMARY.md`
</output>

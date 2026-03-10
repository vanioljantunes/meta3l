# Requirements: meta3L

**Defined:** 2026-03-10
**Core Value:** Make three-level meta-analysis accessible through a clean API that handles multilevel modeling complexity while producing publication-quality forest plots.

## Implementation References

- **I² formula:** https://www.metafor-project.org/doku.php/tips:i2_multilevel_multivariate (P-matrix projection method)
- **Workflow guide:** https://doing-meta.guide/multilevel-ma (three-level workflow with dmetar/clubSandwich)
- **Working template:** `three_level.Rmd` in project root (complete working pipeline for single-arm proportions)
- **Forest plot reference:** `forest_template.R` — `meta::forest.meta` source (~12k lines, grid graphics architecture)

## v1 Requirements

### Data Import

- [ ] **IMPT-01**: User can import multi-sheet Excel file into a named list of data frames (one per sheet/outcome)

### Core Model

- [ ] **MODL-01**: User can fit three-level random-effects model via `rma.mv` with `~ 1 | cluster / effect_id`
- [ ] **MODL-02**: Variance-covariance matrix constructed via `vcalc` with configurable rho (default 0.5)
- [ ] **MODL-03**: Robust variance estimation applied via `clubSandwich` (CR2) by default
- [ ] **MODL-04**: Multilevel I² computed automatically (total, between-cluster, within-cluster) using P-matrix projection
- [ ] **MODL-05**: Back-transformation auto-detected from effect size measure (PLO→plogis, PAS→iarcsin, SMD→identity, RR→exp, OR→exp) with user override via `transf` argument
- [ ] **MODL-06**: Support for PAS, PLO, SMD, MD, RR, OR effect size types
- [ ] **MODL-07**: Default cluster column is `studlab`, overridable via argument
- [ ] **MODL-08**: R >= 4.0 compatibility (no native pipe `|>` or `\(x)` lambda)

### Forest Plot

- [ ] **FRST-01**: Forest plot displays study-level point estimates with confidence intervals
- [ ] **FRST-02**: Pooled effect shown as summary diamond
- [ ] **FRST-03**: Multilevel I² (total, between, within) displayed in summary label
- [ ] **FRST-04**: User-defined `ilab` columns supported (e.g., dose, regimen, follow-up)
- [ ] **FRST-05**: Zebra shading for alternating study rows
- [ ] **FRST-06**: Grid graphics system (not base R) for publication-quality output

### Subgroup Analysis

- [ ] **SUBG-01**: Subgroup forest plot with separate three-level fit per subgroup level
- [ ] **SUBG-02**: Per-subgroup summary polygons with subgroup-level I²
- [ ] **SUBG-03**: Omnibus Q-test for subgroup differences displayed in plot
- [ ] **SUBG-04**: Mixed-effects moderator model via `rma.mv` with `mods` for formal hypothesis testing
- [ ] **SUBG-05**: Wald-type and likelihood-ratio tests for moderator significance

### Meta-Regression

- [ ] **MREG-01**: Bubble plot with scatter points sized by precision (1/sqrt(vi))
- [ ] **MREG-02**: Regression line with confidence interval band
- [ ] **MREG-03**: Back-transformed axes (e.g., probability scale for PLO/PAS)
- [ ] **MREG-04**: Robust p-value from clubSandwich displayed on plot

### Sensitivity Analysis

- [ ] **SENS-01**: Leave-one-out at cluster level — drop each study, refit, show table + influence plot with I² trajectory
- [ ] **SENS-02**: Leave-one-out at within-cluster level — drop each effect size, refit, show table + influence plot with I² trajectory

### Output

- [ ] **OUTP-01**: PNG output by default, PDF supported via argument
- [ ] **OUTP-02**: Filename defaults to data frame name (from Excel sheet), overridable
- [ ] **OUTP-03**: Image dimensions (width, height) settable via arguments with auto-estimation based on number of studies

## v2 Requirements

### Package Polish

- **PLSH-01**: Vignettes with worked examples for each effect size type
- **PLSH-02**: pkgdown documentation site
- **PLSH-03**: Full testthat test suite for CRAN submission
- **PLSH-04**: Batch pipeline wrapper with progress reporting for 20+ outcomes

### Extended Features

- **EXTD-01**: Profile likelihood confidence intervals for variance components
- **EXTD-02**: Funnel plot adapted for three-level structure (with caveats documented)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Network meta-analysis | Different methodology, different package (netmeta) |
| Bayesian meta-analysis | Frequentist only via metafor; direct to RoBMA/brms |
| Interactive/Shiny dashboards | Scripting package; reproducibility over interactivity |
| Automatic report generation (Rmd/Quarto) | Templates go stale; provide companion vignettes instead |
| ggplot2-based forest plots | grid gives better layout control; matches meta package quality |
| Publication bias tests (Egger, trim-and-fill) | Formally invalid for three-level models with dependent effects |
| Freeman-Tukey (PFT) back-transform | Known failure mode producing impossible values (Schwarzer 2019) |
| Automatic risk-of-bias scoring | Meta-analysis packages don't do critical appraisal; users bring RoB as ilab |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| IMPT-01 | — | Pending |
| MODL-01 | — | Pending |
| MODL-02 | — | Pending |
| MODL-03 | — | Pending |
| MODL-04 | — | Pending |
| MODL-05 | — | Pending |
| MODL-06 | — | Pending |
| MODL-07 | — | Pending |
| MODL-08 | — | Pending |
| FRST-01 | — | Pending |
| FRST-02 | — | Pending |
| FRST-03 | — | Pending |
| FRST-04 | — | Pending |
| FRST-05 | — | Pending |
| FRST-06 | — | Pending |
| SUBG-01 | — | Pending |
| SUBG-02 | — | Pending |
| SUBG-03 | — | Pending |
| SUBG-04 | — | Pending |
| SUBG-05 | — | Pending |
| MREG-01 | — | Pending |
| MREG-02 | — | Pending |
| MREG-03 | — | Pending |
| MREG-04 | — | Pending |
| SENS-01 | — | Pending |
| SENS-02 | — | Pending |
| OUTP-01 | — | Pending |
| OUTP-02 | — | Pending |
| OUTP-03 | — | Pending |

**Coverage:**
- v1 requirements: 29 total
- Mapped to phases: 0
- Unmapped: 29 ⚠️

---
*Requirements defined: 2026-03-10*
*Last updated: 2026-03-10 after initial definition*

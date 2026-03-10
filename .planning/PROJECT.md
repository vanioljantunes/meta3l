# meta3L

## What This Is

An R package that provides a complete pipeline for three-level meta-analysis using `metafor::rma.mv`. It wraps the workflow of fitting multilevel random-effects models (`~ 1 | cluster / effect_id`), computing multilevel I² (total, between-cluster, within-cluster), and producing publication-quality forest plots using grid graphics — all adapted for the three-level structure where multiple effect sizes are nested within studies.

## Core Value

Make three-level meta-analysis accessible through a clean API that handles the complexity of multilevel modeling (vcalc, clubSandwich robust variance, multilevel I²) while producing polished, customizable forest plots that properly display the three-level structure.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Excel import utility: read multi-sheet Excel files into a named list of data frames (one per sheet/outcome)
- [ ] Three-level model fitting: `rma.mv` with `~ 1 | cluster / effect_id`, `vcalc` for correlated effects, `clubSandwich` robust variance estimation
- [ ] Multilevel I² computation: total, between-cluster, and within-cluster heterogeneity — displayed in all outputs
- [ ] Auto-detection of back-transformation based on effect size measure (PAS→iarcsin, PLO→plogis, SMD→identity, etc.) with user override via `transf` argument
- [ ] Forest plot (grid graphics): study-level CIs, pooled diamond, multilevel I² in summary label, user-defined `ilab` columns, zebra shading
- [ ] Subgroup forest plot: separate three-level fits per subgroup, subgroup summary polygons with I², omnibus Q-test for subgroup differences
- [ ] Subgroup analysis with mixed-effects moderator models (rma.mv with `mods`) including Wald-type and likelihood-ratio tests
- [ ] Meta-regression bubble plots: scatter + regression line + CI band, back-transformed axes, robust p-value
- [ ] Leave-one-out analysis at cluster level: drop each study, refit, show table + influence plot with between/within I²
- [ ] Leave-one-out analysis at within-cluster level: drop each individual effect size, refit, show table + influence plot with between/within I²
- [ ] Default cluster column is `studlab` (author+year), overridable via argument
- [ ] Default rho = 0.5 for vcalc, overridable via argument
- [ ] File output: PNG by default, filename defaults to data frame name (from Excel sheet), user can override filename and format (PDF, etc.) via arguments
- [ ] Image dimensions (width, height) settable via arguments with sensible auto-estimation defaults based on number of studies
- [ ] Support for proportions (PLO/PAS), mean differences (SMD/MD), and risk/odds ratios (RR/OR) effect size types
- [ ] R >= 4.0 compatibility (no native pipe)

### Out of Scope

- Network meta-analysis — different methodology, different package
- Bayesian meta-analysis — frequentist only via metafor
- Interactive/Shiny dashboards — this is a scripting package
- Automatic report generation (Rmd/Quarto templates) — may add later but not v1

## Context

- Built on top of `metafor` (model fitting, escalc, vcalc), `clubSandwich` (robust variance), and `grid` (graphics)
- Workflow derived from a working three-level Rmd template used for single-arm proportion meta-analyses (e.g., cure rates in leishmaniasis)
- The `forest.meta` function from the `meta` package (~12k lines) serves as reference for grid-based forest plot architecture
- Target audience starts as the research group's mentees but package will be polished for CRAN publication
- Key differentiator: existing packages (`meta`, `metafor`) don't provide a unified three-level pipeline with proper multilevel I² in forest plots

## Constraints

- **R version**: >= 4.0 (no native pipe `|>` or `\(x)` lambda)
- **Graphics system**: grid (not base R) for forest plots — matches `meta` package quality expectations
- **Dependencies**: metafor, clubSandwich, grid, readxl (for import utility) — keep dependency list minimal
- **CRAN-ready**: Code must follow CRAN policies (no `:::`, proper NAMESPACE, roxygen2 docs)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Grid graphics for forest plots | Matches publication quality of `meta::forest.meta`, better layout control | — Pending |
| Default cluster = studlab with override | Most common use case is study-level clustering, but flexibility needed | — Pending |
| Auto-detect back-transformation | Reduces user burden, avoids wrong transform errors | — Pending |
| Separate subgroup fits + moderator models | Covers both descriptive subgroup analysis and formal hypothesis testing | — Pending |
| Two-level leave-one-out (cluster + within) | Unique to three-level models, not available in existing packages | — Pending |

---
*Last updated: 2026-03-10 after initialization*

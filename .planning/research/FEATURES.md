# Feature Research

**Domain:** R package for three-level meta-analysis (meta3L)
**Researched:** 2026-03-10
**Confidence:** HIGH (based on direct analysis of metafor, meta, dmetar packages and the "Doing Meta-Analysis in R" textbook workflows)

---

## Feature Landscape

### Table Stakes (Users Expect These)

These are the baseline features users assume exist in any serious meta-analysis package. Missing any of these makes the package feel incomplete or unusable for real research.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Three-level model fitting via `rma.mv` | Core promise of the package; without this it doesn't exist | LOW | Wraps `metafor::rma.mv` with `~ 1 | cluster / effect_id`; the fitting step itself is well-understood |
| Variance-covariance matrix construction (`vcalc`) | Three-level models require handling correlated sampling errors; `vcalc` is the standard approach in metafor | MEDIUM | Users assume rho = 0.5 default is acceptable; must be overridable |
| Robust variance estimation (clubSandwich) | Standard corrective step for three-level models; expected by anyone who has read Hedges et al. (2010) or the Harrer guide | MEDIUM | Wraps `clubSandwich::conf_int` and `coef_test`; seamless integration needed |
| Multilevel I² (total, between-cluster, within-cluster) | The single most-cited gap in raw `rma.mv` output; users cannot interpret heterogeneity without this | MEDIUM | Currently requires `dmetar::var.comp` or manual calculation; must be embedded in all output |
| Forest plot with pooled diamond | Absolute minimum for publication; without forest plot the package is not useful for papers | HIGH | Grid-based; must show study-level CIs and pooled effect |
| Back-transformation of effect sizes | Proportions (PLO, PAS), SMD, OR/RR all need different transforms; wrong transform → wrong paper | MEDIUM | Auto-detect from `measure` argument; user override via `transf` |
| Effect size type support: PAS, PLO, SMD, MD, RR, OR | The research group works across these domains; any missing type blocks a use case | LOW | Enum-check on input; drive `vcalc` and `transf` decisions |
| File output (PNG/PDF) with auto-naming | Researchers produce plots in batch; manual file naming is friction | LOW | Default to data-frame name from Excel sheet; override via argument |
| Auto-scaled plot dimensions | Too many studies → illegible plot; too few → wasted space | LOW | Sensible formula: ~0.4 cm per study + fixed margins |
| R >= 4.0 compatibility (no native pipe, no `\(x)` lambda) | Mentees and collaborators may not use latest R; CRAN policy requires stated R version | LOW | Use `function(x)` and `%>%` if pipe is needed, or no pipe |

### Differentiators (Competitive Advantage)

Features that no existing single package provides in a unified way, or that require painful multi-package assembly without meta3L.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Excel multi-sheet import as named list | Researchers store one outcome per Excel sheet; no existing package wraps `readxl` to return a named list that drives downstream batch analysis | LOW | `lapply(sheets, read_xlsx)` with sheet names as list names; unlocks the batch workflow |
| Multilevel I² embedded in all outputs (forest plot labels, summary tables) | `rma.mv` suppresses I² by default; `dmetar::var.comp` requires a separate call; meta3L makes it automatic and visible everywhere | MEDIUM | Every summary label and plot title shows total I², between I², within I² |
| Subgroup forest plot with per-subgroup three-level fits | `meta::forest` does subgroups but for two-level models; `metafor::forest.rma` requires manual assembly; no package auto-fits separate `rma.mv` per subgroup and arranges them with summary diamonds | HIGH | Each subgroup gets its own `rma.mv` fit; Q-test for subgroup differences reported automatically |
| Leave-one-out at cluster level (study-level) | `metafor::leave1out` works only for `rma.uni`; three-level LOO requires custom loop and is absent from all packages as a ready function | MEDIUM | Drop each unique cluster, refit, return table + influence plot showing between/within I² trajectory |
| Leave-one-out at within-cluster level (effect-size level) | No existing package provides this; specific to three-level models; crucial for identifying a single influential effect size nested inside a study | MEDIUM | Drop each individual row, refit, return table + influence plot |
| Meta-regression bubble plot with back-transformed axes | `metafor::regplot` exists but does not back-transform axes; with proportions the x-axis shows log-odds, which is uninterpretable in a paper | MEDIUM | Scatter + regression line + CI band; axis labels apply `transf`; robust p-value from clubSandwich displayed |
| Single-call pipeline (`meta3L()`) | Users want one function call that produces fitted model, I², and forest plot; current workflow requires 5-8 separate steps across 3 packages | HIGH | The main user-facing function; all other features are accessible through it or through dedicated plot/analysis functions |
| Structured batch execution across outcomes | Excel has N sheets (outcomes); researchers need to run the full pipeline per outcome; meta3L's named-list design enables `lapply(data_list, meta3L)` | LOW | The architecture (named list in, named list out) is the differentiator; not a special function |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Shiny/interactive dashboard | "Can we click through the analysis?" is a common ask from less-technical mentees | Turns a scripting package into an app; doubles maintenance burden; outside CRAN scope; makes reproducibility harder | Provide clear vignettes and example scripts; scripting IS the reproducibility layer |
| Automatic report generation (Rmd/Quarto) | "Generate my methods section" is appealing | Templates go stale, are opinionated, and tie the package to a specific document format; hard to maintain; CRAN frowns on bundled Rmd templates with external knit dependencies | Provide a companion vignette users can copy; do not bundle inside the package |
| Network meta-analysis | Users working in evidence synthesis often ask for NMA | Entirely different statistical model; requires `netmeta` or `gemtc`; adding NMA would require a separate architecture and bloat scope | Explicitly document in README that NMA is out of scope; point to `netmeta` |
| Bayesian meta-analysis | "Can I get a posterior?" is sometimes asked | Requires `brms` or `rstan`; different inference philosophy; MCMC dependency chain is heavy; not what the research group validated their workflow against | Out of scope; direct users to `RoBMA` or `brms` |
| Automatic study quality / risk-of-bias scoring | "Can the package assess bias?" | Meta-analysis packages do not perform critical appraisal; any automation here is pseudo-scientific; creates false confidence | Users bring their own GRADE/RoB columns as `ilab` data in the forest plot |
| ggplot2-based forest plots | ggplot2 is popular; users sometimes request it | `ggplot2` grid system conflicts with `grid` directly; publication-quality forest plots with complex multi-column layouts are easier in raw `grid`; the `meta::forest.meta` reference implementation uses `grid` | Stick with `grid`; the output quality is higher and aligns with what journals accept |
| Publication bias tests (Egger, trim-and-fill) for three-level models | Standard feature in `meta` and `metafor` for two-level models | Egger's test and trim-and-fill are formally invalid for three-level models with dependent effect sizes; applying them misleads users | Flag in documentation that standard publication bias tests assume independence; do not expose them; point to selection model approaches if needed |

---

## Feature Dependencies

```
Excel import (read_multisheet_excel)
    └──enables──> Batch pipeline (lapply over named list)
                       └──requires──> Single-outcome pipeline (meta3L())

meta3L() [core pipeline]
    ├──requires──> vcalc (variance-covariance matrix)
    │                  └──requires──> rho argument (default 0.5)
    ├──requires──> rma.mv model fit
    │                  └──produces──> rma.mv object
    ├──requires──> Multilevel I² computation
    │                  └──requires──> rma.mv object
    ├──requires──> Back-transformation logic
    │                  └──driven-by──> measure argument (PAS/PLO/SMD/MD/RR/OR)
    └──produces──> Fitted model object (S3 class meta3L_fit)

Forest plot (forest.meta3L)
    ├──requires──> meta3L_fit object
    ├──requires──> Multilevel I² (for summary label)
    ├──optional──> ilab columns (user-supplied data frame)
    └──produces──> PNG/PDF file

Subgroup forest plot (forest_subgroup.meta3L)
    ├──requires──> meta3L_fit object (or raw data + subgroup column)
    ├──requires──> meta3L() [runs separate fits per subgroup]
    └──requires──> Forest plot renderer

Meta-regression bubble plot (bubble.meta3L)
    ├──requires──> rma.mv with mods argument
    ├──requires──> clubSandwich for robust p-value
    └──requires──> Back-transformation logic

Leave-one-out cluster (loo_cluster.meta3L)
    └──requires──> meta3L() [called N times in loop]

Leave-one-out within-cluster (loo_effect.meta3L)
    └──requires──> meta3L() [called N times in loop]

Subgroup moderator analysis (moderator.meta3L)
    ├──requires──> rma.mv with mods argument
    └──requires──> clubSandwich for robust inference
```

### Dependency Notes

- **meta3L() is the central dependency**: Forest plots, LOO, subgroup analysis, and bubble plots all require a fitted `meta3L_fit` object or the ability to produce one. Build `meta3L()` first.
- **Multilevel I² must be computed before any output**: Every plot and table references I² values; compute once inside `meta3L()` and attach to the result object.
- **Back-transformation is driven by `measure`**: The `measure` argument set at model-fit time determines the transformation applied in all downstream plots. It must be stored in the `meta3L_fit` object.
- **clubSandwich is required for moderator and bubble plots**: Wald tests from raw `rma.mv` are less reliable for small samples; robust variance estimation must be the default, not optional.
- **LOO functions are independent of each other**: Cluster-level and within-cluster LOO can be built in any order; both depend only on `meta3L()`.
- **Excel import does not depend on any other feature**: It can be built and tested standalone as a pure utility.

---

## MVP Definition

### Launch With (v1)

Minimum viable product — the smallest set that delivers the core value proposition for the research group's active manuscripts.

- [ ] `read_multisheet_excel()` — Without data import, every user must write their own; blocks adoption immediately
- [ ] `meta3L()` core pipeline — `vcalc` + `rma.mv` + multilevel I² + clubSandwich robust variance in one call; this IS the package
- [ ] `forest.meta3L()` — Forest plot with multilevel I² in summary label, ilab support, zebra shading, pooled diamond; required for any paper
- [ ] Auto-detect back-transformation from `measure` — Proportions (PLO/PAS) are the primary use case; wrong transform = wrong paper
- [ ] File output (PNG/PDF) with auto-naming — Required for batch runs; trivial to implement
- [ ] Auto-scaled plot dimensions — Prevents illegible output for large datasets; low effort, high impact

### Add After Validation (v1.x)

Features to add once the core pipeline is working and being used on real manuscripts.

- [ ] `forest_subgroup.meta3L()` — Needed for comparative analyses; high complexity justifies deferral until core is stable
- [ ] `moderator.meta3L()` — Mixed-effects meta-regression; needed for moderator papers but depends on core being solid
- [ ] `bubble.meta3L()` — Visualization for moderator analyses; add alongside `moderator.meta3L()`
- [ ] `loo_cluster.meta3L()` — Sensitivity analysis; important for reviewer responses; add after first manuscripts are submitted

### Future Consideration (v2+)

Features to defer until the package has real users outside the research group.

- [ ] `loo_effect.meta3L()` — Within-cluster LOO; methodologically interesting but rarely demanded in reviews; high compute cost for large datasets
- [ ] Structured batch wrapper with progress reporting — Useful for groups running 20+ outcomes; add when usage patterns demand it
- [ ] CRAN submission polish (vignettes, pkgdown site, full test suite) — Prerequisite for public release; defer until feature set is stable

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| `meta3L()` core pipeline | HIGH | MEDIUM | P1 |
| Multilevel I² in all outputs | HIGH | MEDIUM | P1 |
| Forest plot (`forest.meta3L`) | HIGH | HIGH | P1 |
| Excel multi-sheet import | HIGH | LOW | P1 |
| Auto back-transformation | HIGH | MEDIUM | P1 |
| File output + auto-naming | MEDIUM | LOW | P1 |
| Auto-scaled dimensions | MEDIUM | LOW | P1 |
| Subgroup forest plot | HIGH | HIGH | P2 |
| Moderator analysis (`moderator.meta3L`) | HIGH | MEDIUM | P2 |
| Bubble plot | MEDIUM | MEDIUM | P2 |
| Leave-one-out cluster | HIGH | MEDIUM | P2 |
| Leave-one-out within-cluster | MEDIUM | MEDIUM | P3 |
| Batch pipeline wrapper | LOW | LOW | P3 |

**Priority key:**
- P1: Must have for launch (v1)
- P2: Should have, add when possible (v1.x)
- P3: Nice to have, future consideration (v2+)

---

## Competitor Feature Analysis

| Feature | metafor | meta | dmetar | meta3L (planned) |
|---------|---------|------|--------|-----------------|
| Three-level model fitting | YES (rma.mv, raw) | PARTIAL (recent addition, limited) | NO (wraps meta/metafor) | YES (clean API) |
| Multilevel I² auto-computed | NO (manual vcalc) | NO | YES (var.comp, separate call) | YES (automatic, in all outputs) |
| Forest plot for rma.mv | YES (complex, raw) | YES (two-level only) | NO | YES (dedicated, multilevel-aware) |
| Subgroup forest plot (three-level) | NO (manual assembly) | NO | NO | YES |
| Leave-one-out for rma.mv | NO (leave1out only for rma.uni) | YES (two-level, metainf) | NO | YES (both levels) |
| Bubble plot with back-transformation | PARTIAL (regplot, no back-transform) | NO | NO | YES |
| Excel multi-sheet import | NO | NO | NO | YES |
| clubSandwich robust variance integrated | NO (separate call) | NO | NO | YES (default) |
| Back-transform auto-detection | PARTIAL (manual transf) | YES (limited measures) | NO | YES |
| Single-call pipeline | NO | PARTIAL | NO | YES |

---

## Sources

- [metafor package features page](https://www.metafor-project.org/doku.php/features) — comprehensive feature inventory (HIGH confidence)
- [Doing Meta-Analysis in R — Multilevel chapter](https://doing-meta.guide/multilevel-ma.html) — three-level workflow gaps (HIGH confidence)
- [dmetar package — var.comp / mlm.variance.distribution](https://dmetar.protectlab.org/reference/mlm.variance.distribution.html) — confirmed I² gap in raw rma.mv (HIGH confidence)
- [meta package PDF (Sept 2025)](https://cran.r-project.org/web/packages/meta/meta.pdf) — current meta package feature set (HIGH confidence)
- [PMC: meta vs metafor contrast paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC7593135/) — user-facing comparison of the two main packages (MEDIUM confidence)
- [metafor forest.rma documentation](https://wviechtb.github.io/metafor/reference/forest.rma.html) — ilab, customization options (HIGH confidence)
- [R-sig-meta-analysis thread on subgroup forest for multilevel](https://stat.ethz.ch/pipermail/r-sig-meta-analysis/2020-August/002317.html) — confirms no easy subgroup forest for rma.mv (MEDIUM confidence, 2020)
- [Fitting three-level meta-analytic models in R (TQMP 2016)](https://www.tqmp.org/RegularArticles/vol12-3/p154/p154.pdf) — canonical reference for three-level structure (HIGH confidence)

---

*Feature research for: R three-level meta-analysis package (meta3L)*
*Researched: 2026-03-10*

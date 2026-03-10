# Pitfalls Research

**Domain:** R package — three-level meta-analysis pipeline (metafor/rma.mv)
**Researched:** 2026-03-10
**Confidence:** HIGH (domain-specific, multiple authoritative sources including metafor official docs)

---

## Critical Pitfalls

### Pitfall 1: Wrong I-squared Formula for Three-Level Models

**What goes wrong:**
Using the standard two-level I² formula (`τ²/(τ² + ṽ)`) for a three-level model. This collapses all between- and within-cluster heterogeneity into a single number, misrepresenting where variance actually lives. Users get one I² when the model has two distinct variance components (σ²₂ for within-cluster, σ²₃ for between-cluster), making the output scientifically misleading.

**Why it happens:**
The standard I² formula from Higgins & Thompson (2002) is what most researchers know. The correct multilevel extension — summing all variance components and computing separate level-specific I² values using the Cheung (2014) / metafor tip formula — requires a non-obvious implementation that is not surfaced by default in `rma.mv` output.

**How to avoid:**
Implement the multilevel I² formula explicitly: `I²_total = 100% × Σ(σ²) / [Σ(σ²) + (k-p)/tr(P)]`, and compute separate I² values for Level 2 (within-cluster) and Level 3 (between-cluster). Follow the exact implementation from the metafor tips page (https://www.metafor-project.org/doku.php/tips:i2_multilevel_multivariate). Expose all three values (total, L2, L3) in every output — model summary, forest plot summary label, leave-one-out table.

**Warning signs:**
- Function returns a single I² value for a three-level model
- I² is computed from `model$sigma2[1]` alone rather than both `model$sigma2` elements
- Forest plot summary shows "I² = X%" without level decomposition

**Phase to address:** Model fitting phase (core pipeline). Must be correct before any output function is written — all downstream outputs copy from this computation.

---

### Pitfall 2: Treating vcalc rho as Inconsequential

**What goes wrong:**
Hard-coding or silently defaulting `rho = 0.5` without (a) documenting the assumption in outputs and (b) making it easily overridable. If the assumed within-study correlation is wrong, the variance-covariance matrix passed to `rma.mv` is wrong, and all downstream estimates (point estimates, CIs, I²) are affected. Reviewers and replicators cannot reproduce results if rho is invisible.

**Why it happens:**
`rho = 0.5` is a widely-used default (Cheung 2015, Borenstein et al.) and feels "safe," so developers embed it without surfacing it. The `vcalc()` function accepts it silently. Because results rarely change dramatically across plausible rho values, the error goes undetected.

**How to avoid:**
Expose `rho` as a named argument with default `0.5` in every function that calls `vcalc()`. Print the assumed rho in model summary output (e.g., `"Assumed within-cluster correlation: rho = 0.5"`). Document in roxygen2 that users should conduct sensitivity analyses across rho values (0.3, 0.5, 0.7) for robustness.

**Warning signs:**
- `rho` is not a parameter of the main fitting function
- Package internals call `vcalc(rho = 0.5)` without an external argument wired to it
- No mention of assumed correlation in any printed output

**Phase to address:** Model fitting phase. Wire rho through as a first-class argument at the start, not retrofitted later.

---

### Pitfall 3: Variance Components Not Identifiable (Flat Profile Likelihood)

**What goes wrong:**
The model is overparameterized — typically when one level has no meaningful variance (e.g., all effects within a cluster are identical, so σ²₂ → 0) or when there is only one effect per cluster. `rma.mv` will still converge and return estimates, but the variance component is estimated at the boundary (zero) or is arbitrary. Any I² or leave-one-out analysis built on those estimates is meaningless.

**Why it happens:**
`rma.mv` does not raise an error or warning for boundary estimates by default. Developers who skip `profile()` checks and move straight to output functions ship code that computes and displays meaningless variance decompositions.

**How to avoid:**
After fitting, always inspect `profile(model, sigma2 = 1); profile(model, sigma2 = 2)`. Add a diagnostic check in the fitting function: if any `sigma2` estimate is at or near zero (e.g., `< 1e-6`), emit a `warning()` that explains the implication ("Between-cluster variance is effectively zero — three-level model may be unnecessary; consider rma.uni"). Document that users should run `profile()` on their fitted model objects.

**Warning signs:**
- `model$sigma2[i]` equals exactly `0` or `1e-99`
- Profile likelihood plot is flat across a wide parameter range
- I²_L3 or I²_L2 reports as 0% across all analyses
- Datasets where every study contributes exactly one effect size (no within-cluster nesting)

**Phase to address:** Model fitting phase. Diagnostic warning should be part of the fitting function itself, not a separate diagnostics phase.

---

### Pitfall 4: Back-Transformation Applied to Wrong Effect Size Measure

**What goes wrong:**
Auto-detection of back-transformation applies the wrong function — most dangerously, applying `iarcsin` (arcsine inverse) to a logit-transformed proportion (PLO) or vice versa. This silently produces wrong point estimates and CI bounds on the natural scale. The forest plot shows values that look plausible but are incorrect.

**Why it happens:**
The `measure` argument in `metafor` (e.g., `"PAS"`, `"PLO"`, `"SMD"`, `"RR"`, `"OR"`) must be mapped to the correct back-transformation function. Auto-detection logic based on string matching is error-prone, especially when users pass non-standard measure codes or when the measure attribute is missing from the data frame (e.g., after subsetting or rbind).

**How to avoid:**
Build an explicit named lookup table (not a chain of if/else) mapping measure codes to transformation functions: `transf_map <- list(PAS = sin, PLO = plogis, SMD = identity, RR = exp, OR = exp, MD = identity)`. Validate the measure argument against this map at function entry and stop with a clear error if the code is unrecognized. Always allow `transf` argument to override. After applying back-transformation, perform a sanity check: proportions should be in [0,1], RR/OR should be positive — emit a warning if violated.

**Warning signs:**
- Pooled proportion > 1 or < 0 in output
- CI bounds cross impossible boundaries (OR < 0, proportion outside [0,1])
- Auto-detection logic uses `if (measure == "PAS") ... else if (measure == "PLO") ...` without an explicit else-stop
- Missing measure attribute silently falls through to identity transform

**Phase to address:** Model fitting and forest plot phase. The lookup table should be a shared internal utility used by all output functions.

---

### Pitfall 5: Subgroup Analysis Conflating Separate Fits with Moderator Models

**What goes wrong:**
The omnibus Q-test for subgroup differences is computed incorrectly, or the package conflates two methodologically distinct approaches — (a) fitting separate three-level models per subgroup and combining them, vs. (b) fitting a single mixed-effects model with the subgroup as a moderator (`mods = ~ subgroup`). These are not equivalent: separate fits allow heterogeneity to vary by subgroup; the moderator approach constrains heterogeneity to be equal across subgroups. If the package silently uses one approach but labels results with the other's interpretation, published results will be methodologically wrong.

**Why it happens:**
The distinction is subtle and not well-documented in most applied tutorials. Developers often implement the approach that is easier to code (moderator model) but label outputs with subgroup-analysis language that implies the separate-fit approach.

**How to avoid:**
Implement both explicitly and distinctly: a `subgroup_forest()` function using separate fits (with a note in output that heterogeneity is estimated per subgroup), and a moderator analysis function using `mods = ~ factor(subgroup)` with clear labeling that heterogeneity is pooled. The omnibus test for subgroup differences from the moderator model should use the Wald-type QM test (already provided by `rma.mv`). Document the distinction in roxygen2 `@details` for both functions.

**Warning signs:**
- Subgroup forest function uses `mods` argument internally but reports "subgroup-specific I²"
- Summary polygons in the subgroup forest display I² values from the pooled moderator model rather than per-subgroup fits
- No distinction in function naming between descriptive subgroup plot and formal moderator test

**Phase to address:** Subgroup analysis phase. Design the API separation between these two functions before implementation starts.

---

### Pitfall 6: Leave-One-Out Dropping at Wrong Level for Three-Level Models

**What goes wrong:**
`leave1out()` in metafor operates at the individual-observation level (each row), not the cluster level. For a three-level model, dropping individual observations within a cluster is a within-cluster sensitivity analysis, which is different from dropping entire studies (clusters). If the package only wraps `leave1out()` without implementing cluster-level dropping separately, users studying study-level influence get the wrong analysis.

**Why it happens:**
`leave1out()` only supports `rma.uni` objects, not `rma.mv`. For `rma.mv`, cluster-level leave-one-out must be implemented manually — iterating over unique cluster values, subsetting data, refitting, and collecting estimates. Developers unfamiliar with this limitation attempt to use `leave1out()` on `rma.mv` objects and get an error or fall back to observation-level influence diagnostics.

**How to avoid:**
Implement cluster-level LOO manually: `for (cl in unique(data[[cluster_col]])) { fit_without_cl <- rma.mv(..., data = data[data[[cluster_col]] != cl, ]) }`. Do the same for within-cluster LOO (dropping individual rows). Both loops need to recompute I² for each reduced model to populate the influence table. Test with a dataset where one cluster is clearly influential.

**Warning signs:**
- LOO implementation uses `leave1out(model)` directly — this only works for `rma.uni`
- LOO loop iterates over `seq_len(nrow(data))` rather than `unique(data[[cluster_col]])`
- Influence plot shows k rows equal to number of effect sizes when cluster-level analysis is claimed

**Phase to address:** Sensitivity analysis phase. Must be planned as a manual loop from the beginning — not a wrapper.

---

### Pitfall 7: Grid Graphics Viewport Not Cleaned Up Between Plots

**What goes wrong:**
Grid graphics require explicit viewport management. If a forest plot function opens viewports (via `pushViewport()`) but does not close them on error or early return, subsequent plot calls accumulate orphaned viewports, producing corrupted graphics or the error: `"cannot pop the top-level viewport ('grid' and 'graphics' output mixed?)"`. This is especially problematic in the context of lapply-driven batch plotting over many outcomes.

**Why it happens:**
Grid's viewport stack is global state. A function that calls `pushViewport()` must always call `popViewport()` or `upViewport()` — including in error paths. Developers writing forest plot code copy patterns from base R graphics where this cleanup is automatic, without accounting for grid's explicit stack.

**How to avoid:**
Wrap all viewport operations in `on.exit(upViewport(0), add = TRUE)` at the top of the forest plot function. This ensures cleanup even on error or early return. Test the function in a loop calling it 20 times sequentially — if viewports leak, the 5th or 10th call will produce errors. Use `grid.newpage()` at the start of each plot call to reset state.

**Warning signs:**
- Forest plot function uses `pushViewport()` without a corresponding `on.exit` cleanup
- Calling the function twice in a row produces an error on the second call
- `grid::current.vpTree()` shows unexpected depth after a plot call

**Phase to address:** Forest plot phase. Establish the viewport management pattern in the first working prototype — retrofitting is painful.

---

### Pitfall 8: Auto-Sizing Forest Plot Dimensions Failing for Extreme Cases

**What goes wrong:**
Auto-estimated plot dimensions (width, height) based on number of studies break for edge cases: very few studies (e.g., k=3, producing a too-tall plot with huge empty space), very many studies (k=60+, producing clipped or illegible text), or very long study labels (overflowing the left column). The result is a PNG where text is cut off or the diamond is not visible.

**Why it happens:**
Linear formulas like `height = 2 + k * 0.3` work for mid-range k but fail at extremes. Study label length is rarely factored in. Width is often set as a fixed value that does not account for ilab column count.

**How to avoid:**
Make auto-sizing a function of multiple inputs: number of studies (k), number of ilab columns, maximum study label character count. Apply floor and ceiling constraints. Test the auto-sizing function explicitly with k=2, k=5, k=20, k=50. For the file output function, document that users can always override via `width` and `height` arguments. Prefer `unit()` with `"lines"` or `"strheight"` in grid for text-relative sizing.

**Warning signs:**
- Auto-sizing formula is a single linear expression with no floor/ceiling
- ilab column count is not a parameter of the sizing function
- No test for k < 5 or k > 40

**Phase to address:** Forest plot phase, specifically when implementing file output and auto-sizing logic.

---

### Pitfall 9: CRAN Rejection Due to `:::` Usage or Unqualified Global Variable Bindings

**What goes wrong:**
Using `package:::internal_function()` to access non-exported functions from metafor or other packages causes immediate CRAN rejection. Separately, using bare column names in `for`/`lapply` expressions without `globalVariables()` declaration produces `NOTE: no visible binding for global variable` in `R CMD check`, which may also cause rejection depending on the CRAN reviewer.

**Why it happens:**
During development it is tempting to call metafor internal helpers via `:::` (e.g., `metafor::::.calcH`) rather than reimplementing them. `globalVariables()` is not obvious to developers who primarily work interactively rather than writing packages.

**How to avoid:**
Never use `:::`. Reimplement any needed internal logic (I² formula, etc.) directly in the package — this is also safer against metafor version changes. For `R CMD check` notes, add `utils::globalVariables(c("var1", "var2", ...))` in a package-level `zzz.R` or `package-name-package.R` file. Run `R CMD check --as-cran` in CI before every release. Address all NOTEs, not just ERRORs — CRAN rejects on NOTEs too.

**Warning signs:**
- Any occurrence of `:::` in package source
- `R CMD check` output contains `NOTE: no visible binding for global variable`
- DESCRIPTION does not list all used packages in `Imports:` field

**Phase to address:** Package scaffolding phase (first). Establish check discipline immediately — catching it late means touching every function.

---

### Pitfall 10: Freeman-Tukey Double Arcsine Transformation Back-Transformation Errors

**What goes wrong:**
The Freeman-Tukey double arcsine transformation (`"PFT"` in metafor) has a complicated back-transformation that requires specifying a sample size (typically the harmonic mean of study sample sizes). If the package auto-detects `"PFT"` and applies a naive inverse, it can produce proportions of exactly 0 or values outside [0,1] — a documented, published failure mode (Schwarzer et al. 2019, PMC6767151).

**Why it happens:**
The `iarcsin` back-transformation (for the simple arcsine, `"PAS"`) and the Freeman-Tukey double arcsine (`"PFT"`) look similar but are not. The double arcsine requires `transf.ipft.hm()` from metafor with the harmonic mean of n passed as `targs`. Developers who see "arcsine" assume a simple inverse applies.

**How to avoid:**
Do not support `"PFT"` in the auto-detection table at all — mark it as unsupported with a clear `stop()` message directing users to use `"PLO"` (logit) instead, which is methodologically preferred for proportions. If `"PFT"` must be supported, use `metafor::transf.ipft.hm()` with `targs = list(ni = harmonic_mean_n)` and document this explicitly.

**Warning signs:**
- Package maps `"PFT"` to `iarcsin` or `sin` in the transformation lookup table
- Back-transformed pooled proportion is exactly 0.000 or > 1.000
- No harmonic mean computation anywhere in the proportion back-transformation path

**Phase to address:** Model fitting phase — the transformation lookup table is the right place to block this.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hard-code `rho = 0.5` internally without argument | Simpler function signature | Users cannot run sensitivity analyses; not scientifically reproducible | Never — expose rho from day one |
| Use `:::` to access metafor internals | Avoid reimplementing formulas | CRAN rejection; breaks on metafor version bumps | Never |
| Single global I² for three-level model | Simpler output | Scientifically wrong output; methodological criticism | Never |
| Skip `profile()` check in fitting function | Faster model return | Users publish results from unidentified models | Never for the fitting function; acceptable to make it optional (`check = TRUE`) |
| Fixed plot dimensions (no auto-sizing) | Simpler code | Almost every user sees clipped plots | Acceptable in MVP if `width`/`height` arguments are exposed |
| Import entire packages with `@import` instead of `@importFrom` | Fewer roxygen lines to write | Namespace conflicts; CRAN policy concern | Never for large packages (metafor, grid); acceptable for tiny single-function packages |
| Implement LOO with `leave1out()` wrapper for rma.mv | Reuse existing metafor code | Does not work — `leave1out()` does not support `rma.mv` objects | Never |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `metafor::vcalc()` | Passing a simple diagonal matrix (ignoring within-cluster correlation) when studies report multiple outcomes | Pass the full block-diagonal VCV matrix from `vcalc(rho = rho, cluster = cluster_col)` as the `V` argument to `rma.mv` |
| `clubSandwich::coef_test()` | Not specifying `vcov = "CR2"` — using CR0 underestimates variance in small samples | Always use `"CR2"` (recommended by Pustejovsky & Tipton 2018) and document the choice |
| `clubSandwich` cluster specification | Assuming it auto-detects the correct cluster — it defaults to the outermost random effect, which may not match the intended cluster | Explicitly pass `cluster = data[[cluster_col]]` to `vcovCR()` and `coef_test()` |
| `readxl::excel_sheets()` + `lapply` | Not naming the output list by sheet name | Use `setNames(lapply(sheets, ...), sheets)` or `purrr::map` with named vector to get a self-named list |
| `readxl` empty sheets | Silently importing empty sheets as 0-row data frames that then fail downstream | Filter out empty sheets before returning: `Filter(function(df) nrow(df) > 0, sheet_list)` |
| `grid` device management | Calling `grid.newpage()` inside a function that is part of a larger composite plot | Guard `grid.newpage()` with an argument `new_page = TRUE` that users can set to `FALSE` |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Leave-one-out refits without parallelism | LOO over 50 clusters takes minutes; users assume the package is broken | Document expected runtime; expose `parallel` and `ncpus` arguments wrapping metafor's built-in parallel support | k > 30 clusters on a standard laptop |
| Rebuilding the VCV matrix inside each LOO iteration | LOO runtime scales quadratically | Recompute the VCV matrix from scratch only for the reduced dataset — do not try to subset the full-dataset VCV | k > 20, fine-grained within-cluster LOO |
| Grid graphics saved to PNG with default resolution | Forest plot unreadable when printed (72 dpi default) | Default to `res = 300` (or `600` for journal submission) in `png()` calls; expose as argument | Always visible — low-quality PNG is immediately apparent |
| Storing full model objects in a list during LOO | Memory exhaustion for large datasets | Only store the summary statistics needed (estimate, CI, sigma2 values) from each LOO fit, not the full `rma.mv` object | k > 100 effects in LOO |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Silent default `rho = 0.5` with no printed message | Reviewer asks "what correlation did you assume?" and user doesn't know | Print `"Note: Using assumed within-cluster correlation rho = 0.5"` in model summary |
| Forest plot returns invisibly without printing to device | User calls function, nothing appears, confusion | Return the plot object invisibly AND render to device; document that users can capture with `recordPlot()` |
| Error messages from metafor bubbling up without context | "object 'V' not found" with no indication of which function or argument caused it | Wrap `rma.mv` calls in `tryCatch` and prepend package-specific context to error messages |
| Subgroup forest plot with 8 subgroups generates a tiny per-subgroup section | Text overlaps; unreadable | Warn when any subgroup has k < 3 effects, suggest combining subgroups |
| LOO influence table with no indication of "most influential" study | User must manually scan 50-row table | Sort output by absolute change in point estimate; add a column flagging studies where CI shifts significantly |

---

## "Looks Done But Isn't" Checklist

- [ ] **I² computation:** Displays three values (total, L2, L3) — verify formula matches metafor tips page, not standard two-level formula
- [ ] **Back-transformation:** Test with PAS, PLO, SMD, RR, OR each — verify output is on natural scale and within valid range
- [ ] **vcalc integration:** Verify `V` matrix passed to `rma.mv` is block-diagonal (not diagonal) — check with a dataset where multiple effects share a study
- [ ] **Leave-one-out cluster level:** Verify loop drops entire cluster (all rows for a study), not individual rows — check output has k_cluster rows, not k_effects rows
- [ ] **Forest plot viewport cleanup:** Call forest plot function 5 times in a loop — verify no viewport errors on calls 2–5
- [ ] **CRAN check:** Run `R CMD check --as-cran` with zero ERRORs and zero NOTEs before any release
- [ ] **rho argument:** Verify `rho` is a named argument in every public function that calls `vcalc()` — not buried in an internal
- [ ] **File output dimensions:** Test with k=3 and k=60 — verify plot is not clipped in either case
- [ ] **Subgroup omnibus test:** Verify Q-test p-value is from the moderator model (`QM`), not the residual heterogeneity test (`QE`)
- [ ] **R >= 4.0 compatibility:** Run examples with R 4.0 — verify no native pipe `|>` or `\(x)` lambda syntax anywhere

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong I² formula shipped in a release | HIGH — published papers citing the package have wrong statistics | Release a patch immediately; add a `NEWS.md` breaking change notice; provide a migration guide |
| `:::` usage caught at CRAN submission | LOW — CRAN will reject, not archive | Identify all `:::` calls, reimplement the needed logic, resubmit |
| Viewport leaks discovered in batch use | MEDIUM — requires refactoring plot internals | Add `on.exit(upViewport(0), add = TRUE)` to all plot functions; add `grid.newpage()` guard |
| Wrong back-transformation for PFT shipped | HIGH — numeric results are wrong | Same as wrong I² — immediate patch, NEWS.md, version bump |
| LOO loop operating at wrong level | MEDIUM — results are not wrong, just answering a different question | Rename existing function to `loo_within()`, implement correct `loo_cluster()` separately |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Wrong multilevel I² formula | Model fitting (core pipeline) | Unit test: compare computed I² against manually calculated reference values from Cheung 2014 example |
| Silent rho without argument | Model fitting (core pipeline) | Check function signature includes `rho = 0.5`; check model summary prints rho |
| Flat profile / unidentified variance | Model fitting (core pipeline) | Add `check_convergence()` call; unit test with single-effect-per-cluster dataset |
| Wrong back-transformation | Model fitting + forest plot | Unit test each measure code against known back-transformed values |
| Subgroup fit vs. moderator conflation | Subgroup analysis phase | Separate functions with distinct names; documentation review |
| LOO at wrong level | Sensitivity analysis phase | Unit test: LOO output row count equals k_clusters, not k_effects |
| Grid viewport leaks | Forest plot phase | Integration test: call plot function 10x in a loop without error |
| Auto-sizing extremes | Forest plot phase | Integration test with k=2 and k=60 datasets |
| `:::` and CRAN check errors | Package scaffolding (first phase) | CI runs `R CMD check --as-cran`; fail build on any NOTE |
| Freeman-Tukey back-transform | Model fitting (core pipeline) | Unit test: PFT measure triggers `stop()` with informative message |

---

## Sources

- metafor tips — I² for multilevel/multivariate models: https://www.metafor-project.org/doku.php/tips:i2_multilevel_multivariate
- metafor reference — `profile.rma`: https://wviechtb.github.io/metafor/reference/profile.rma.html
- metafor reference — `rma.mv`: https://wviechtb.github.io/metafor/reference/rma.mv.html
- metafor reference — `vcalc`: https://wviechtb.github.io/metafor/reference/vcalc.html
- metafor reference — `influence.rma.mv`: https://wviechtb.github.io/metafor/reference/influence.rma.mv.html
- clubSandwich vignette — meta-analysis with CRVE: https://cran.r-project.org/web/packages/clubSandwich/vignettes/meta-analysis-with-CRVE.html
- Schwarzer et al. (2019) — Freeman-Tukey back-transform problems: https://pmc.ncbi.nlm.nih.gov/articles/PMC6767151/
- Lin (2020) — Arcsine transformation pros/cons: https://pmc.ncbi.nlm.nih.gov/articles/PMC7384291/
- Harrer et al. — Doing Meta-Analysis in R, Chapter 10 (multilevel): https://bookdown.org/MathiasHarrer/Doing_Meta_Analysis_in_R/multilevel-ma.html
- Harrer et al. — Doing Meta-Analysis in R, Chapter 10 (three-level fit): https://bookdown.org/MathiasHarrer/Doing_Meta_Analysis_in_R/fitting-a-three-level-model.html
- R-sig-meta-analysis list — subgroup analysis under three-level model: https://stat.ethz.ch/pipermail/r-sig-meta-analysis/2021-March/002713.html
- roxygen2 NAMESPACE management: https://roxygen2.r-lib.org/articles/namespace.html
- R Packages (2e) — CRAN release: https://r-pkgs.org/release.html
- ThinkR CRAN preparation checklist: https://github.com/ThinkR-open/prepare-for-cran

---
*Pitfalls research for: R package — three-level meta-analysis pipeline (meta3L)*
*Researched: 2026-03-10*

# Phase 1: Core Model Pipeline - Research

**Researched:** 2026-03-10
**Domain:** R package development — metafor three-level meta-analysis, S3 API, CRAN compliance
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**API Surface Design**
- All-in-one function: `meta3L()` handles escalc, vcalc, rma.mv, robust, and I² internally
- Column names passed as quoted strings (character), not NSE — loop-friendly, matches metafor conventions
- Supports all measure types: proportions (PLO, PAS) via xi/ni, continuous (SMD, MD) via mi/sdi/ni, two-group (RR, OR) via ai/bi/ci/di/n1i/n2i, two-group continuous (SMD) via m1i/sd1i/n1i/m2i/sd2i/n2i
- Full 2x2 table args accepted for RR/OR — user never touches escalc directly
- `slab` is a required named argument (column name as string)
- Default cluster = `studlab`, overridable via `cluster` argument
- Default rho = 0.5, overridable via `rho` argument

**Effect Size Handling**
- Back-transformation auto-detected from `measure` argument: PLO→plogis, PAS→iarcsin, RR/OR→exp, SMD/MD→identity
- User can override with `transf` argument (pass a function)
- Single measure per call — no dual computation
- Strict validation: required columns checked before escalc; clear error messages
- Unsupported measures (PFT, etc.) fail early with informative message
- Rows with NA in essential columns filtered with warning stating count and column names

**Result Object (meta3l_result S3)**
- Contains: fitted rma.mv model, three I² values, robust variance estimates, resolved back-transform function, escalc'd data frame, V matrix, call metadata, TE_id column name, pre-computed back-transformed pooled estimate + CI
- `result$model` exposed for advanced users
- `print()`: pooled estimate + 95% CI (back-transformed), k, n, rho, I² breakdown, robust SE note
- `summary()`: everything in print() plus sigma² components, robust variance table, convergence info

**Excel Import (read_multisheet_excel)**
- Reads all sheets; returns named list of data.frames (names = sheet names)
- Auto-constructs `studlab = paste0(author, ", ", year)` if both columns present; silent skip otherwise
- No sheet filtering — user subsets afterwards
- readxl defaults for type detection; wraps with as.data.frame()
- NULL/missing path falls back to rstudioapi::selectFile()
- rstudioapi is a hard dependency (Imports)
- Empty sheets skipped with warning

**Package Structure**
- One file per exported function: meta3L.R, read_multisheet_excel.R, print.meta3l_result.R, summary.meta3l_result.R
- utils.R for internal helpers (compute_i2, resolve_transf, validate_columns)
- meta3L-package.R for package-level documentation
- roxygen2 for documentation and NAMESPACE generation
- MIT license
- Basic testthat suite in Phase 1

**Error Messaging**
- Plain stop()/warning() with call. = FALSE — no cli dependency
- Every error includes problem + suggestion

### Claude's Discretion
- Package name casing (meta3L vs meta3l) — pick based on CRAN naming conventions
- Exact compute_i2 internal implementation details
- summary() formatting and level of detail
- testthat test case selection and coverage scope
- DESCRIPTION fields (Title, Description wording, Authors)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| IMPT-01 | User can import multi-sheet Excel file into a named list of data frames (one per sheet/outcome) | readxl `excel_sheets()` + `read_excel()` + `lapply()` pattern confirmed; as.data.frame() wrapper confirmed |
| MODL-01 | User can fit three-level random-effects model via `rma.mv` with `~ 1 | cluster / effect_id` | metafor 4.8-0 rma.mv random formula pattern confirmed from working template |
| MODL-02 | Variance-covariance matrix constructed via `vcalc` with configurable rho (default 0.5) | metafor vcalc with cluster/obs/vi/rho pattern confirmed from template and official docs |
| MODL-03 | Robust variance estimation applied via `clubSandwich` (CR2) by default | `robust(res, cluster=..., clubSandwich=TRUE)` confirmed as current recommended pattern |
| MODL-04 | Multilevel I² computed automatically using P-matrix projection | P-matrix formula with `W = solve(V)` confirmed for non-diagonal V; component extraction via `res$sigma2` |
| MODL-05 | Back-transformation auto-detected from measure; user override via `transf` | metafor transf functions confirmed: `transf.ilogit` (PLO), `transf.iarcsin` (PAS), `exp` (RR/OR), identity (SMD/MD) |
| MODL-06 | Support for PAS, PLO, SMD, MD, RR, OR effect size types | escalc required columns per measure verified from official docs |
| MODL-07 | Default cluster column is `studlab`, overridable via argument | String-column lookup via `dat[[cluster]]` pattern confirmed in template |
| MODL-08 | R >= 4.0 compatibility (no native pipe or lambda) | Requires avoiding `|>` and `\(x)` syntax; use standard `function(x)` and `|>` alternatives |
</phase_requirements>

---

## Summary

This phase builds a CRAN-compliant R package (`meta3l`) that wraps metafor's three-level meta-analysis workflow into a single `meta3L()` call. The working template in `three_level.Rmd` already contains a complete, validated pipeline — the primary implementation work is wrapping those patterns in an S3 API, adding argument validation, and scaffolding the package structure correctly.

The core statistical machinery is stable and well-documented: `metafor` 4.8-0 (released 2025-01-28) provides `escalc()`, `vcalc()`, `rma.mv()`, and `robust()`. The P-matrix I² formula is authoritatively documented by Viechtbauer at metafor-project.org. The key implementation subtlety is using `W = solve(V)` (not `diag(1/res$vi)`) because `vcalc()` produces a non-diagonal V matrix — the working template already does this correctly. The back-transformation mapping is straightforward: metafor exports `transf.ilogit` and `transf.iarcsin` directly; `exp` is base R; SMD/MD use `identity`.

Package structure follows standard CRAN conventions: roxygen2 for docs + NAMESPACE, `usethis::use_testthat()` for test scaffolding, `devtools::check()` for `R CMD check`. The package name `meta3l` (all lowercase) is preferred by CRAN convention and avoids conflict with any existing package. The `rstudioapi` dependency is unavoidable given the interactive file-picker requirement, but should be `Imports` (not `Suggests`) per the locked decision — this is a mild CRAN friction point and reviewers may request a fallback path.

**Primary recommendation:** Scaffold package with `usethis`, port `three_level.Rmd` internals into `meta3L()` and `utils.R`, implement argument validation before any metafor calls, and run `devtools::check()` iteratively.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| metafor | 4.8-0 | escalc, vcalc, rma.mv, robust, transf.* | The authoritative R meta-analysis engine; all workflow patterns live here |
| readxl | >= 1.3.0 | Read .xlsx/.xls into data frames | Lightweight, no Java dependency, tidyverse-maintained |
| rstudioapi | >= 0.13 | Interactive file picker (`selectFile()`) | Required by locked decision; only hard dep for import UI |
| roxygen2 | >= 7.0.0 | Inline documentation + NAMESPACE generation | CRAN standard; devtools/usethis integrate with it |
| testthat | >= 3.0.0 | Unit tests | CRAN expects a test suite; 3rd edition has snapshot tests |

### Supporting (development-only, not package dependencies)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| devtools | >= 2.4.0 | load_all(), check(), install() | Local dev + CRAN check automation |
| usethis | >= 2.0.0 | Package scaffolding (use_r, use_testthat, use_mit_license) | One-time setup tasks |
| clubSandwich | >= 0.5.0 | CR2 sandwich estimator called by metafor's robust() | Imported automatically via metafor's robust(clubSandwich=TRUE); list in Suggests or Imports depending on whether user calls it directly |

> **Note on clubSandwich:** `metafor::robust(clubSandwich = TRUE)` internally calls `clubSandwich` functions. Because `meta3L()` always calls `robust(clubSandwich = TRUE)`, `clubSandwich` must be in `Imports` (not just `Suggests`) so it is always available.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| readxl | openxlsx | openxlsx supports writing; readxl is read-only but lighter and more stable |
| rstudioapi::selectFile | file.choose() | `file.choose()` works outside RStudio but has no caption/filter UI; rstudioapi is the locked decision |
| testthat | tinytest | testthat has snapshot support and wider ecosystem; tinytest is smaller but less capable |

**Installation (user-facing dependencies):**
```r
install.packages(c("metafor", "readxl", "rstudioapi", "clubSandwich"))
```

**Installation (dev dependencies):**
```r
install.packages(c("devtools", "usethis", "roxygen2", "testthat"))
```

---

## Architecture Patterns

### Recommended Package Structure
```
meta3l/
├── DESCRIPTION              # Package metadata, Imports, R >= 4.0.0
├── NAMESPACE                # Generated by roxygen2 — do not edit manually
├── LICENSE                  # MIT
├── R/
│   ├── meta3L.R             # Exported: meta3L()
│   ├── read_multisheet_excel.R  # Exported: read_multisheet_excel()
│   ├── print.meta3l_result.R    # S3 method: print.meta3l_result()
│   ├── summary.meta3l_result.R  # S3 method: summary.meta3l_result()
│   ├── utils.R              # Internal: compute_i2(), resolve_transf(), validate_columns()
│   └── meta3l-package.R     # Package-level @docType package roxygen block
├── man/                     # Generated by roxygen2 — do not edit manually
├── tests/
│   └── testthat/
│       ├── test-meta3L.R
│       └── test-read_multisheet_excel.R
└── .Rbuildignore
```

### Pattern 1: Three-Level Pipeline (core of meta3L())
**What:** escalc → vcalc → rma.mv → robust → compute_i2, executed in sequence on validated input
**When to use:** Always — this is the single code path inside meta3L()

```r
# Source: three_level.Rmd (working template) + metafor 4.8-0 docs
dat <- metafor::escalc(
  measure = measure,
  xi = dat[[xi]], ni = dat[[ni]],   # or appropriate args per measure
  data = dat, slab = dat[[slab]]
)
dat$TE_id <- seq_len(nrow(dat))
V <- metafor::vcalc(
  vi      = dat$vi,
  cluster = dat[[cluster]],
  obs     = dat$TE_id,
  rho     = rho,
  data    = dat
)
res <- metafor::rma.mv(
  yi, V,
  random = ~ 1 | studlab / TE_id,   # literal column names — cluster always studlab or overridden
  data   = dat
)
res_robust <- metafor::robust(res, cluster = dat[[cluster]], clubSandwich = TRUE)
i2 <- compute_i2(res, V)
```

> **CRITICAL:** The `random` formula uses literal column names. When `cluster != "studlab"`, the formula must be built dynamically:
> `as.formula(paste0("~ 1 | ", cluster, " / TE_id"))`

### Pattern 2: P-Matrix I² (compute_i2 internal)
**What:** Correct multilevel I² formula using solve(V) as precision matrix
**When to use:** Always for rma.mv with non-diagonal V from vcalc

```r
# Source: metafor-project.org/doku.php/tips:i2_multilevel_multivariate
# IMPORTANT: use W = solve(V), NOT diag(1/res$vi) — V is non-diagonal from vcalc
compute_i2 <- function(fit, V) {
  W   <- solve(V)
  X   <- model.matrix(fit)
  P   <- W - W %*% X %*% solve(t(X) %*% W %*% X) %*% t(X) %*% W
  denom <- sum(fit$sigma2) + (fit$k - fit$p) / sum(diag(P))
  list(
    total   = 100 * sum(fit$sigma2) / denom,
    between = 100 * fit$sigma2[1]   / denom,
    within  = 100 * fit$sigma2[2]   / denom
  )
}
```

### Pattern 3: Back-Transform Resolution (resolve_transf internal)
**What:** Map measure string to the correct back-transformation function
**When to use:** Once inside meta3L(); result stored in `result$transf`

```r
# Source: metafor transf docs + locked decisions
resolve_transf <- function(measure, user_transf = NULL) {
  if (!is.null(user_transf)) return(user_transf)
  switch(measure,
    PLO = metafor::transf.ilogit,   # equivalent to plogis()
    PAS = metafor::transf.iarcsin,
    RR  = exp,
    OR  = exp,
    SMD = ,
    MD  = identity,
    stop("measure '", measure, "' is not supported. Use PLO, PAS, SMD, MD, RR, or OR.",
         call. = FALSE)
  )
}
```

> **Note:** `plogis()` and `metafor::transf.ilogit` are functionally identical for scalar inputs, but using `metafor::transf.ilogit` is preferred so it integrates with metafor's `forest(..., transf=...)` in Phase 2.

### Pattern 4: Column Validation (validate_columns internal)
**What:** Check required columns exist before calling escalc; produce informative error
**When to use:** At the start of meta3L(), before any computation

```r
# Required columns per measure (from metafor escalc docs)
REQUIRED_COLS <- list(
  PLO = c("xi", "ni"),
  PAS = c("xi", "ni"),
  SMD = c("m1i", "sd1i", "n1i", "m2i", "sd2i", "n2i"),
  MD  = c("m1i", "sd1i", "n1i", "m2i", "sd2i", "n2i"),
  RR  = c("ai", "bi", "ci", "di"),
  OR  = c("ai", "bi", "ci", "di")
)

validate_columns <- function(data, measure, col_args, slab) {
  required <- REQUIRED_COLS[[measure]]
  if (is.null(required)) {
    stop("measure '", measure, "' is not supported. Use: PLO, PAS, SMD, MD, RR, or OR.",
         call. = FALSE)
  }
  # col_args is the named list of user-supplied column name strings
  for (req in required) {
    col <- col_args[[req]]
    if (is.null(col) || !col %in% names(data)) {
      stop("Column '", col, "' (", req, ") not found in data for measure '", measure, "'.",
           call. = FALSE)
    }
  }
  if (!slab %in% names(data)) {
    stop("slab column '", slab, "' not found in data.", call. = FALSE)
  }
}
```

### Pattern 5: Multi-Sheet Excel Import
**What:** Read all sheets into named list of data.frames; auto-build studlab if author+year present
**When to use:** read_multisheet_excel()

```r
# Source: readxl docs + three_level.Rmd pattern
read_multisheet_excel <- function(path = NULL) {
  if (is.null(path)) {
    path <- rstudioapi::selectFile(caption = "Choose Excel file",
                                   filter  = "Excel files (*.xlsx, *.xls)")
  }
  sheet_names <- readxl::excel_sheets(path)
  result <- lapply(sheet_names, function(s) {
    df <- as.data.frame(readxl::read_excel(path, sheet = s))
    if (nrow(df) == 0) {
      warning("Sheet '", s, "' is empty and will be skipped.", call. = FALSE)
      return(NULL)
    }
    if ("author" %in% names(df) && "year" %in% names(df)) {
      df$studlab <- paste0(df$author, ", ", df$year)
    }
    df
  })
  names(result) <- sheet_names
  result <- Filter(Negate(is.null), result)
  result
}
```

### Pattern 6: S3 Result Constructor
**What:** Build the `meta3l_result` list with all downstream-needed fields
**When to use:** At the end of meta3L() before returning

```r
structure(
  list(
    model    = res_robust,     # rma.mv robust result — exposed for advanced users
    data     = dat,            # escalc'd data frame (yi, vi, TE_id, slab cols added)
    V        = V,              # variance-covariance matrix from vcalc
    i2       = i2,             # list(total, between, within)
    transf   = transf_fn,      # resolved back-transform function
    measure  = measure,
    cluster  = cluster,        # column name string
    rho      = rho,
    slab     = slab,           # column name string
    TE_id    = "TE_id",
    estimate = transf_fn(res_robust$b[[1]]),
    ci.lb    = transf_fn(res_robust$ci.lb),
    ci.ub    = transf_fn(res_robust$ci.ub)
  ),
  class = "meta3l_result"
)
```

### Pattern 7: Dynamic Formula for Configurable Cluster
**What:** Build `~ 1 | cluster / TE_id` when cluster column name is not hardcoded
**When to use:** Inside meta3L() when cluster != "studlab"

```r
# R >= 4.0 compatible (no native pipe, no \(x) lambda)
random_formula <- as.formula(paste0("~ 1 | ", cluster, " / TE_id"))
res <- metafor::rma.mv(yi, V, random = random_formula, data = dat)
```

### Anti-Patterns to Avoid
- **Using `diag(1/res$vi)` as W in the I² formula:** Wrong when V from vcalc is non-diagonal. Always use `solve(V)`.
- **Calling `escalc()` then checking columns:** Validate columns FIRST, then call escalc — otherwise metafor errors are cryptic.
- **NSE / unquoted column names:** Breaks programmatic use. All column references via `dat[[col_string]]`.
- **`:::` calls to internal metafor functions:** Fails CRAN check. Use only exported functions.
- **Native pipe `|>` or `\(x)` lambda syntax:** Breaks R < 4.1. Use `function(x)` and chained assignments.
- **`1:nrow(dat)` instead of `seq_len(nrow(dat))`:** `1:0` returns `c(1,0)` not empty; always use `seq_len`.
- **Tibbles from read_excel without `as.data.frame()`:** Tibble subsetting behavior differs; wrap immediately.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Heterogeneity between dependent effects | Custom variance matrix | `metafor::vcalc()` | Handles compound symmetry, AR1, UN structures with cluster/obs structure |
| CR2 sandwich variance estimator | Custom sandwich matrix | `metafor::robust(..., clubSandwich=TRUE)` | Bell-McCaffrey CR2 is mathematically non-trivial; clubSandwich is the reference implementation |
| Back-transformation functions | `1/(2*sin(x))^2` etc. | `metafor::transf.iarcsin`, `metafor::transf.ilogit` | Metafor's versions handle edge cases and integrate with `forest(..., transf=)` |
| Effect size computation with variance | `log(xi/ni)` etc. | `metafor::escalc()` | Handles continuity corrections, bias corrections, 30+ measure types |
| P-matrix I² computation | Custom projection | `compute_i2()` as documented by Viechtbauer | Formula is subtle; wrong W matrix is a silent error |
| NAMESPACE management | Editing NAMESPACE directly | `roxygen2` `@import`, `@importFrom` | CRAN check will fail on namespace errors; roxygen2 handles transitive imports |

**Key insight:** The entire statistical core is a direct port from `three_level.Rmd` — the work is API wrapping, not statistical invention.

---

## Common Pitfalls

### Pitfall 1: Wrong W Matrix in I² Formula
**What goes wrong:** Using `W <- diag(1/res$vi)` when V from vcalc is non-diagonal produces silently wrong I² values (often lower than correct values).
**Why it happens:** The standard metafor I² tip page shows the diagonal form for the common independent case; the non-diagonal case requires `solve(V)`.
**How to avoid:** Always use `W <- solve(V)` inside `compute_i2`. Add a unit test that cross-checks against the template's known output.
**Warning signs:** I² values that seem lower than expected, or identical across all three components.

### Pitfall 2: Dynamic Formula for rma.mv
**What goes wrong:** `rma.mv(yi, V, random = ~ 1 | cluster / TE_id, data = dat)` literally references a variable named `cluster` in `dat`, not the value of the `cluster` argument.
**Why it happens:** R formula parsing is lexical — `cluster` in the formula is evaluated as a column name string in data, not as the R variable holding the column name.
**How to avoid:** `as.formula(paste0("~ 1 | ", cluster, " / TE_id"))` where `cluster` is the string argument. The template does this correctly with `dat[[cluster]]` for `robust()` but uses a hardcoded `studlab` in the formula — this must be generalized.
**Warning signs:** `Error in rma.mv: object 'cluster' not found` or silent use of wrong grouping.

### Pitfall 3: rstudioapi in Non-Interactive Sessions
**What goes wrong:** `rstudioapi::selectFile()` errors with `RStudio not running` when the package is used from Rscript, knitr, or CI environments.
**Why it happens:** rstudioapi checks for an active RStudio session; the selectFile path is only reachable when `path = NULL`.
**How to avoid:** Only call `rstudioapi::selectFile()` when `is.null(path)` AND `rstudioapi::isAvailable()` returns TRUE. If not available and path is NULL, `stop("path argument is required in non-RStudio environments.", call. = FALSE)`.
**Warning signs:** CRAN `R CMD check` NOTE about rstudioapi — needs to be in `Imports` with proper conditional use.

### Pitfall 4: escalc() Passing Vectors vs. Column Names
**What goes wrong:** `escalc(data=dat, xi=dat[[xi_col]], ...)` works for computation but loses the `data` integration — metafor may not attach `yi`/`vi` back to the data frame properly.
**Why it happens:** `escalc(data=dat, xi=xi_col_name)` expects the column name as a symbol or string depending on the interface version.
**How to avoid:** Use `do.call(metafor::escalc, args_list)` to pass column names dynamically, or use `dat[[col]] <- dat[[col]]` to rename columns to expected names before calling escalc with fixed argument names.
**Warning signs:** `yi` and `vi` not appearing in the returned data frame.

### Pitfall 5: CRAN Check — Global Variable Binding Notes
**What goes wrong:** `R CMD check --as-cran` produces NOTEs like `no visible binding for global variable 'yi'` because `rma.mv(yi, V, data=dat)` uses NSE.
**Why it happens:** `R CMD check` performs static analysis and can't see that `yi` is a column in `dat`.
**How to avoid:** Add `utils::globalVariables(c("yi", "vi", "TE_id"))` in `meta3l-package.R`. This is the standard CRAN-approved suppression pattern.
**Warning signs:** Any NOTE mentioning "no visible binding for global variable" in check output.

### Pitfall 6: clubSandwich in DESCRIPTION
**What goes wrong:** `robust(clubSandwich=TRUE)` at runtime triggers `requireNamespace("clubSandwich")` inside metafor — if clubSandwich is only in `Suggests`, it may not be installed and will error silently on user machines.
**Why it happens:** metafor lists clubSandwich in its Suggests but can function without it if the argument is not used.
**How to avoid:** List `clubSandwich` in the `Imports` field of DESCRIPTION (not Suggests), since `meta3L()` always calls `robust(clubSandwich=TRUE)`.

### Pitfall 7: PFT Back-Transform (Reject Explicitly)
**What goes wrong:** If PFT were supported, `transf.ipft` (without harmonic mean sample size) produces impossible values (e.g., estimated proportion exactly 0) for sample sizes 10-120 per Schwarzer (2019).
**Why it happens:** The inverse Freeman-Tukey transform requires sample sizes which aren't available at the pooled estimate level; the harmonic mean heuristic also fails.
**How to avoid:** `validate_columns()` / `resolve_transf()` both reject PFT with an explicit `stop()` that cites the Schwarzer (2019) reason.

---

## Code Examples

Verified patterns from official sources and the working template:

### Full Three-Level Pipeline (condensed)
```r
# Source: three_level.Rmd + metafor 4.8-0
dat <- metafor::escalc(measure="PLO", xi=event, ni=n, slab=studlab, data=data)
dat$TE_id <- seq_len(nrow(dat))
V   <- metafor::vcalc(vi=dat$vi, cluster=dat[["studlab"]], obs=dat$TE_id, rho=0.5, data=dat)
res <- metafor::rma.mv(yi, V, random = ~1|studlab/TE_id, data=dat)
res_robust <- metafor::robust(res, cluster=dat[["studlab"]], clubSandwich=TRUE)
```

### I² Decomposition
```r
# Source: metafor-project.org/doku.php/tips:i2_multilevel_multivariate
# W = solve(V) required for non-diagonal V from vcalc
W     <- solve(V)
X     <- model.matrix(res)
P     <- W - W %*% X %*% solve(t(X) %*% W %*% X) %*% t(X) %*% W
denom <- sum(res$sigma2) + (res$k - res$p) / sum(diag(P))
i2_total   <- 100 * sum(res$sigma2)  / denom
i2_between <- 100 * res$sigma2[[1]]  / denom
i2_within  <- 100 * res$sigma2[[2]]  / denom
```

### Back-Transformation Mapping
```r
# PLO (logit-transformed proportion) -> probability
plogis(res_robust$b)           # base R equivalent
metafor::transf.ilogit(res_robust$b)  # preferred for forest() integration

# PAS (arcsine-transformed proportion) -> proportion
metafor::transf.iarcsin(res_robust$b)

# RR / OR (log-transformed) -> ratio
exp(res_robust$b)

# SMD / MD (identity)
res_robust$b   # no transformation needed
```

### Reading All Excel Sheets
```r
# Source: readxl docs + three_level.Rmd
sheet_names <- readxl::excel_sheets(path)
ma <- lapply(sheet_names, function(s) as.data.frame(readxl::read_excel(path, sheet=s)))
names(ma) <- sheet_names
```

### roxygen2 S3 Method Registration
```r
#' @export
#' @method print meta3l_result
print.meta3l_result <- function(x, ...) { ... }
```
> The `@method` tag ensures NAMESPACE gets `S3method(print, meta3l_result)` — required for proper S3 dispatch and CRAN compliance.

### globalVariables Suppression (CRAN NOTE prevention)
```r
# In meta3l-package.R
utils::globalVariables(c("yi", "vi", "TE_id"))
```

### DESCRIPTION Snippet
```
Package: meta3l
Type: Package
Title: Three-Level Meta-Analysis via metafor
Version: 0.1.0
Depends: R (>= 4.0.0)
Imports:
    metafor (>= 4.0-0),
    readxl (>= 1.3.0),
    rstudioapi (>= 0.13),
    clubSandwich (>= 0.5.0)
Suggests:
    testthat (>= 3.0.0)
License: MIT + file LICENSE
Encoding: UTF-8
RoxygenNote: 7.x.x
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual I² with `diag(1/vi)` for all models | `solve(V)` precision matrix for multilevel | metafor docs updated ~2019-2021 | Silently wrong I² with dependent effects |
| `robust()` without clubSandwich | `robust(..., clubSandwich=TRUE)` for CR2 | clubSandwich integrated into metafor ~2020 | Better small-sample inference |
| `vcalc()` not available | `vcalc()` for constructing block-diagonal V | Added to metafor ~2021 (v3.0+) | Replaced manual V matrix construction |
| `1:nrow(dat)` for IDs | `seq_len(nrow(dat))` | R best practices — always | Avoids `1:0 = c(1,0)` bug |

**Deprecated/outdated:**
- `transf.ipft` (PFT back-transform): Schwarzer (2019) demonstrated impossible values for n=10-120; do not support PFT.
- Manual V matrix construction via `outer()`: Replaced by `vcalc()` which handles cluster structure declaratively.

---

## Open Questions

1. **clubSandwich as Imports vs. Suggests**
   - What we know: meta3L always calls `robust(clubSandwich=TRUE)`, so clubSandwich must be available at runtime
   - What's unclear: Whether CRAN reviewers object to a non-core package in Imports
   - Recommendation: Put in Imports; if reviewer flags it, fall back to Suggests + `requireNamespace("clubSandwich", quietly=FALSE)` guard

2. **rstudioapi CRAN scrutiny**
   - What we know: rstudioapi in Imports causes no CRAN error but reviewers sometimes ask "is this truly required?"
   - What's unclear: Whether interactive-only code path (when path=NULL) satisfies CRAN's rstudioapi usage policy
   - Recommendation: Guard with `rstudioapi::isAvailable()` check (see Pitfall 3); document in `read_multisheet_excel()` that non-RStudio users must pass `path=`

3. **rma.mv formula with configurable cluster**
   - What we know: `as.formula(paste0("~ 1 | ", cluster, " / TE_id"))` is correct
   - What's unclear: Whether metafor parses column names with special characters (dots, spaces) in formulas
   - Recommendation: Document that cluster column names should be valid R identifiers; add a check in `validate_columns()`

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | testthat >= 3.0.0 |
| Config file | `tests/testthat.R` (generated by `usethis::use_testthat()`) |
| Quick run command | `devtools::test(filter="meta3L")` |
| Full suite command | `devtools::test()` |
| CRAN check command | `devtools::check(args="--as-cran")` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| IMPT-01 | `read_multisheet_excel()` returns named list of data.frames | unit | `devtools::test(filter="read_multisheet")` | Wave 0 |
| MODL-01 | `meta3L()` returns object with `$model` of class `rma.mv` | unit | `devtools::test(filter="meta3L")` | Wave 0 |
| MODL-02 | `result$V` is a valid variance-covariance matrix (symmetric, positive definite) | unit | `devtools::test(filter="meta3L")` | Wave 0 |
| MODL-03 | `result$model` has class `robust.rma` | unit | `devtools::test(filter="meta3L")` | Wave 0 |
| MODL-04 | `result$i2$total`, `$between`, `$within` are numeric and sum to `$total` | unit | `devtools::test(filter="meta3L")` | Wave 0 |
| MODL-05 | `resolve_transf("PLO")` returns `metafor::transf.ilogit` | unit | `devtools::test(filter="meta3L")` | Wave 0 |
| MODL-06 | `meta3L(..., measure="PAS")` runs without error; `meta3L(..., measure="RR")` runs without error | unit | `devtools::test(filter="meta3L")` | Wave 0 |
| MODL-07 | `meta3L(..., cluster="author")` uses author column for grouping | unit | `devtools::test(filter="meta3L")` | Wave 0 |
| MODL-08 | `R CMD check --as-cran` produces 0 errors, 0 warnings | integration | `devtools::check(args="--as-cran")` | Wave 0 |
| Phase gate | Unsupported measure ("PFT") produces `stop()` with informative message | unit | `expect_error(meta3L(..., measure="PFT"), regexp="not supported")` | Wave 0 |

### Sampling Rate
- **Per task commit:** `devtools::test(filter="meta3L")` (< 5s on synthetic data)
- **Per wave merge:** `devtools::test()` (full suite)
- **Phase gate:** `devtools::check(args="--as-cran")` — zero errors, zero warnings

### Wave 0 Gaps
- [ ] `tests/testthat/test-meta3L.R` — covers MODL-01 through MODL-08 and PFT rejection
- [ ] `tests/testthat/test-read_multisheet_excel.R` — covers IMPT-01
- [ ] `tests/testthat/helper-fixtures.R` — synthetic minimal data frames for each measure type (PLO, PAS, SMD, MD, RR, OR)
- [ ] Package scaffold itself: `usethis::create_package("meta3l")` + `usethis::use_testthat()`

---

## Sources

### Primary (HIGH confidence)
- `three_level.Rmd` (project root) — verified working pipeline for PLO/PAS single-arm proportions
- [metafor-project.org I² multilevel](https://www.metafor-project.org/doku.php/tips:i2_multilevel_multivariate) — authoritative P-matrix formula with solve(V) for non-diagonal V
- [metafor reference: escalc](https://wviechtb.github.io/metafor/reference/escalc.html) — required arguments per measure (PLO, PAS, SMD, MD, RR, OR) verified
- [metafor reference: transf](https://wviechtb.github.io/metafor/reference/transf.html) — transf.ilogit, transf.iarcsin availability confirmed
- [metafor reference: robust](https://wviechtb.github.io/metafor/reference/robust.html) — clubSandwich=TRUE argument confirmed
- [CRAN metafor 4.8-0](https://cran.r-project.org/web/packages/metafor/index.html) — current version (2025-01-28)
- [testthat 3.3.2 CRAN](https://cran.r-project.org/web/packages/testthat/testthat.pdf) — current version, snapshot and expect_error patterns

### Secondary (MEDIUM confidence)
- [readxl workflows](https://readxl.tidyverse.org/articles/readxl-workflows.html) — multi-sheet lapply pattern verified against three_level.Rmd
- [Schwarzer 2019 — PFT back-transform failure](https://onlinelibrary.wiley.com/doi/10.1002/jrsm.1348) — PFT rejection rationale confirmed
- [clubSandwich CRVE vignette](https://cran.r-project.org/web/packages/clubSandwich/vignettes/meta-analysis-with-CRVE.html) — CR2 estimator in meta-analysis context

### Tertiary (LOW confidence — needs validation)
- CRAN package naming: ~70% lowercase convention from survey data (2012 R Journal article) — sufficient for choosing `meta3l` but no strict rule enforced

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — metafor 4.8-0 confirmed on CRAN; all function signatures verified against official docs + working template
- Architecture: HIGH — package structure follows standard usethis/roxygen2 conventions; S3 patterns confirmed
- I² formula: HIGH — verified against authoritative metafor-project.org documentation; `solve(V)` vs `diag(1/vi)` distinction confirmed
- Back-transform mapping: HIGH — all transf.* functions confirmed in metafor docs
- Pitfalls: HIGH for statistical pitfalls (P-matrix, dynamic formula); MEDIUM for CRAN process pitfalls (rstudioapi scrutiny)

**Research date:** 2026-03-10
**Valid until:** 2026-04-10 (metafor is stable; check for minor updates before CRAN submission)

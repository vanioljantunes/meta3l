---
phase: 3
slug: subgroup-meta-regression-sensitivity
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-10
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat >= 3.0.0 (Config/testthat/edition: 3 in DESCRIPTION) |
| **Config file** | meta3l/tests/testthat.R |
| **Quick run command** | `testthat::test_file("tests/testthat/test-{module}.R")` |
| **Full suite command** | `devtools::test()` or `R CMD check meta3l` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `testthat::test_file("tests/testthat/test-{module}.R")`
- **After every plan wave:** Run `devtools::test()`
- **Before `/gsd:verify-work`:** Full suite must be green + `R CMD check --no-manual meta3l` 0 errors 0 warnings
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 0 | SUBG-01,02,03 | stub | `testthat::test_file("tests/testthat/test-forest_subgroup.R")` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 0 | SUBG-04,05 | stub | `testthat::test_file("tests/testthat/test-moderator.R")` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 0 | MREG-01,02,03,04 | stub | `testthat::test_file("tests/testthat/test-bubble.R")` | ❌ W0 | ⬜ pending |
| 03-01-04 | 01 | 0 | SENS-01,02 | stub | `testthat::test_file("tests/testthat/test-loo.R")` | ❌ W0 | ⬜ pending |
| 03-XX-XX | XX | 1 | SUBG-01 | smoke | `testthat::test_file("tests/testthat/test-forest_subgroup.R")` | W0 dep | ⬜ pending |
| 03-XX-XX | XX | 1 | SUBG-02 | smoke | `testthat::test_file("tests/testthat/test-forest_subgroup.R")` | W0 dep | ⬜ pending |
| 03-XX-XX | XX | 1 | SUBG-03 | smoke | `testthat::test_file("tests/testthat/test-forest_subgroup.R")` | W0 dep | ⬜ pending |
| 03-XX-XX | XX | 1 | SUBG-04 | unit | `testthat::test_file("tests/testthat/test-moderator.R")` | W0 dep | ⬜ pending |
| 03-XX-XX | XX | 1 | SUBG-05 | unit | `testthat::test_file("tests/testthat/test-moderator.R")` | W0 dep | ⬜ pending |
| 03-XX-XX | XX | 2 | MREG-01 | smoke | `testthat::test_file("tests/testthat/test-bubble.R")` | W0 dep | ⬜ pending |
| 03-XX-XX | XX | 2 | MREG-02 | smoke | `testthat::test_file("tests/testthat/test-bubble.R")` | W0 dep | ⬜ pending |
| 03-XX-XX | XX | 2 | MREG-03 | unit | `testthat::test_file("tests/testthat/test-bubble.R")` | W0 dep | ⬜ pending |
| 03-XX-XX | XX | 2 | MREG-04 | unit | `testthat::test_file("tests/testthat/test-bubble.R")` | W0 dep | ⬜ pending |
| 03-XX-XX | XX | 3 | SENS-01 | unit | `testthat::test_file("tests/testthat/test-loo.R")` | W0 dep | ⬜ pending |
| 03-XX-XX | XX | 3 | SENS-02 | unit | `testthat::test_file("tests/testthat/test-loo.R")` | W0 dep | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-forest_subgroup.R` — stubs for SUBG-01, SUBG-02, SUBG-03
- [ ] `tests/testthat/test-moderator.R` — stubs for SUBG-04, SUBG-05
- [ ] `tests/testthat/test-bubble.R` — stubs for MREG-01, MREG-02, MREG-03, MREG-04
- [ ] `tests/testthat/test-loo.R` — stubs for SENS-01, SENS-02
- [ ] `tests/testthat/helper-fixtures.R` — add subgroup column to existing fixtures

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Forest subgroup visual layout | SUBG-01 | Visual inspection of subgroup sections, diamonds, layout | Open PNG, verify subgroup headers, per-subgroup diamonds, I² labels |
| Bubble plot visual elements | MREG-01 | Visual inspection of scatter, regression line, CI band | Open PNG, verify points sized by precision, line + band visible |
| LOO influence plot trajectory | SENS-01 | Visual inspection of trajectory shape | Open PNG, verify one point per cluster, dashed reference line |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

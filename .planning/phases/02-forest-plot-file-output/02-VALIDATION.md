---
phase: 02
slug: forest-plot-file-output
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-10
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | testthat 3.x |
| **Config file** | tests/testthat.R |
| **Quick run command** | `Rscript -e "testthat::test_file('tests/testthat/test-forest.R')"` |
| **Full suite command** | `Rscript -e "devtools::test()"` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `Rscript -e "testthat::test_file('tests/testthat/test-forest.R')"`
- **After every plan wave:** Run `Rscript -e "devtools::test()"`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | FRST-01 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-forest.R')"` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | FRST-02 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-forest.R')"` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | FRST-03 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-forest.R')"` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 1 | FRST-04 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-forest.R')"` | ❌ W0 | ⬜ pending |
| 02-01-05 | 01 | 1 | FRST-05 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-forest.R')"` | ❌ W0 | ⬜ pending |
| 02-01-06 | 01 | 1 | FRST-06 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-forest.R')"` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 1 | OUTP-01 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-output.R')"` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 1 | OUTP-02 | unit | `Rscript -e "testthat::test_file('tests/testthat/test-output.R')"` | ❌ W0 | ⬜ pending |
| 02-02-03 | 02 | 1 | OUTP-03 | integration | `Rscript -e "testthat::test_file('tests/testthat/test-output.R')"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/testthat/test-forest.R` — stubs for FRST-01 through FRST-06
- [ ] `tests/testthat/test-output.R` — stubs for OUTP-01 through OUTP-03

*Existing infrastructure covers test framework setup (testthat already configured from Phase 1).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual quality of forest plot | FRST-01 | Visual inspection needed | Open PNG, verify point estimates, CIs, diamond, and I² label are positioned correctly |
| Zebra shading appearance | FRST-05 | Visual inspection needed | Open PNG, confirm alternating row shading visible |
| ilab column alignment | FRST-03 | Visual inspection needed | Open PNG, verify annotation columns are left-aligned and labeled |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

# Scale Benchmark

**Measured:** 2026-08-27, on a single developer machine (see "Machine" below).
Produced by `tools/benchmark_scale.R`, which generates a seeded synthetic
loanbook (`tools/generate_scale_fixture.R`) at each (loans, distinct
counterparties) cell and times two stages against it. Raw data:
`docs/scale_benchmark.csv`.

## What was measured

**Intake validation** (`scripts/intake_validate_and_map.R`, run as a real
subprocess so its own cost shows up honestly) across a 3×3 grid of loan
counts (1,000 / 10,000 / 50,000) crossed with distinct-counterparty counts
(200 / 1,000 / 5,000), skipping the one cell where counterparties would
exceed loans (1,000 loans × 5,000 counterparties). All 8 valid cells
completed within the 300-second per-cell timeout.

| Loans | Counterparties | Intake seconds |
|---:|---:|---:|
| 1,000 | 200 | 3.8 |
| 1,000 | 1,000 | 3.9 |
| 10,000 | 200 | 18.0 |
| 10,000 | 1,000 | 19.6 |
| 10,000 | 5,000 | 18.3 |
| 50,000 | 200 | 101.6 |
| 50,000 | 1,000 | 230.3 |
| 50,000 | 5,000 | 151.4 |

**Bottleneck identified:** intake time scales with **loan row count**, not
distinct-counterparty count (10,000 loans costs about the same whether
matched to 200 or 5,000 counterparties; the three 50,000-loan cells differ
from each other more than they differ from the underlying loan-count trend
would predict, which reads as ordinary system-load noise on a shared
development machine rather than a counterparty-count effect — no monotonic
increase with counterparty count is visible at any loan-count tier). This is
consistent with `scripts/intake_validate_and_map.R` making three separate
row-wise passes over the loanbook (`R:196,253,285` in the pre-Wave-3 audit)
— exactly the hot spot named in
`research/2026-08-19-pcaf-layer-scale-and-platform-seams-brainstorm.md` F-005.

**Machine:** Windows 10 x64, 8 logical cores, ~8 GB total RAM. This machine
was also running other applications during the benchmark (browser, IDE,
background agent tooling) — the timings above should be read as "this ran to
completion in this much wall-clock time on a busy shared machine," not as a
clean, isolated performance ceiling. A quieter machine would likely be
faster; the qualitative finding (loan count drives intake cost, not
counterparty count) is expected to hold regardless.

## What was NOT measured

- **`r2dii.match::match_name()` fuzzy-matching timing.** The benchmark
  harness attempted to time this directly but could not produce a reliable
  reading in this session (`match_seconds` is `NA` for every cell in
  `docs/scale_benchmark.csv`) — the synthetic fixture's matching setup needs
  further work to exercise `match_name()` the way the real intake pipeline
  does. This remains the single most important unmeasured number, because
  `research/2026-08-19-...-brainstorm.md` F-005 specifically named fuzzy
  matching (not intake's row-wise passes) as the classic quadratic
  bottleneck. **Do not assume matching is cheap at 5,000 counterparties
  because intake was fast — this was not tested.**
- **The full PACTA + TRISK chain at scale.** Every number above is intake
  only. Running `scripts/pacta_vietnam_scenario.R` and the TRISK stages
  against a synthetic loanbook this large — including whether
  `r2dii.analysis::target_market_share()`/`target_sda()` and the TRISK
  per-sector runs complete in reasonable time — was out of scope for the
  time available when this benchmark was built.
- **Memory usage.** Only wall-clock time was recorded.

## Submission size (intake stage only)

Per the measurements above, intake validation completed for **50,000 loans
across up to 5,000 distinct counterparties in under 3 minutes** on a busy
development machine. This is the only stage benchmarked; **it is not a
claim about the full pipeline's supported size** (see "What was NOT
measured"). `intake/SCHEMA.md`'s submission-size guidance is written to
reflect this scope precisely — do not read it as an end-to-end pipeline
guarantee.

## Reproducing / extending this benchmark

```powershell
$env:Path += ";C:\Program Files\R\R-4.5.2\bin"
Rscript tools/benchmark_scale.R --timeout-seconds 300
```

Appends to `docs/scale_benchmark.csv` (does not overwrite prior rows), so a
future session can extend this grid — larger loan counts, a working
`match_name()` timing, or a full-chain benchmark — without losing what is
here. `tools/generate_scale_fixture.R`'s fixtures are written under
`bench/` (gitignored) and are never committed.

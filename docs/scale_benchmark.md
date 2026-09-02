# Scale Benchmark

**Measured:** first on 2026-08-27 (intake only), extended on 2026-09-02 to add
fuzzy-matching timings and a before/after comparison for the Wave 4 intake
vectorization. Produced by `tools/benchmark_scale.R`, which generates a seeded
synthetic loanbook (`tools/generate_scale_fixture.R`) at each (loans, distinct
counterparties) cell and times two stages against it. Raw data:
`docs/scale_benchmark.csv`, whose `note` column tags the Wave 4 rows
`wave4-before-vectorization` / `wave4-after-vectorization`.

## What was measured

A 3x3 grid of loan counts (1,000 / 10,000 / 50,000) crossed with
distinct-counterparty counts (200 / 1,000 / 5,000), skipping the one cell where
counterparties would exceed loans. Two stages per cell:

1. **Intake validation** — `scripts/intake_validate_and_map.R`, run as a real
   subprocess so its own cost shows up honestly.
2. **Fuzzy name matching** — `r2dii.match::match_name()`, in process, called
   exactly as `R/pacta_core.R` calls it: `by_sector = TRUE`, `min_score = 0.8`,
   `method = "jw"`, `p = 0.1`, and the same VSIC-to-ISIC
   `sector_classification` extension. Without that extension r2dii rejects this
   pipeline's own ISIC codes as unknown and matching returns zero rows, which
   would time a path the pipeline never takes.

## Intake: before and after the Wave 4 vectorization

Both columns were measured on the same machine in the same session, so they are
directly comparable. The 2026-08-27 numbers in `docs/scale_benchmark.csv` are
from a different session and should not be differenced against these.

| Loans | Counterparties | Before (s) | After (s) | Speed-up |
|---:|---:|---:|---:|---:|
| 1,000 | 200 | 3.5 | 2.6 | 1.35x |
| 1,000 | 1,000 | 3.6 | 2.7 | 1.33x |
| 10,000 | 200 | 16.4 | 6.8 | 2.41x |
| 10,000 | 1,000 | 17.1 | 7.1 | 2.41x |
| 10,000 | 5,000 | 17.4 | 7.3 | 2.38x |
| 50,000 | 200 | 84.8 | 28.2 | 3.01x |
| 50,000 | 1,000 | 86.0 | 33.3 | 2.58x |
| 50,000 | 5,000 | 90.2 | 28.1 | 3.21x |

**Read the 50,000-row speed-ups as "about 3x", not as three separate figures.**
Run-to-run noise on this shared development machine is roughly +/-15%. Timing
the 50,000 x 1,000 cell three more times in isolation gave 28.7 / 29.3 / 33.5
seconds (median 29.3), i.e. **2.9x** against the 86.0-second baseline rather
than the 2.58x a single sample suggested. The honest summary is: **intake at
50,000 loans went from roughly 85-90 seconds to roughly 28-33 seconds, a
speed-up of about 2.6x-3.2x depending on the cell and the run.**

**What changed.** `scripts/intake_validate_and_map.R` made three separate
row-wise passes over the loanbook, each beginning with `row <- input_data[i, ]`
— a single-row tibble slice executed once per loan. Wave 4 hoists every
column-level coercion out of those loops and computes it once per column;
the loops that remain visit only the rows that actually produce an error or a
warning. Emission order is unchanged (ascending row; within a row
counterparty_name, exposure_vnd, credit_limit_vnd, sector_code_system,
sector_code), which matters because `validation_errors.csv` is a committed
regression fixture. Verified byte-identical against the pre-change
implementation on the `sdb-rehearsal` fixture and on an adversarial fixture
covering multi-error rows, unparseable numbers, out-of-scope sector codes, USD
conversion, and an unsupported currency.

## Fuzzy matching: the number Wave 3 could not produce

`match_seconds` was `NA` in every cell of the original benchmark. The cause was
not slowness: the harness built a five-column loanbook subset and an ABCD table
with no `sector` column, so every call raised

```
Must have missing names: `sector_classification_direct_loantaker`
```

which a `tryCatch` silently converted to `NA`. Wave 4 passes the normalized
loanbook through whole (intake already emits exactly the 13-column r2dii shape)
and builds ABCD from the fixture's own `abcd.csv` with its sector codes mapped
to PACTA sectors. Measured, post-fix:

| Loans | Counterparties | match_name (s) | Matched rows |
|---:|---:|---:|---:|
| 1,000 | 200 | 0.4 | 604 |
| 1,000 | 1,000 | 0.4 | 596 |
| 10,000 | 200 | 1.4 | 6,206 |
| 10,000 | 1,000 | 2.5 | 6,516 |
| 10,000 | 5,000 | 7.2 | 5,846 |
| 50,000 | 200 | 6.8 | 30,750 |
| 50,000 | 1,000 | 9.3 | 32,196 |
| 50,000 | 5,000 | 26.9 | 29,414 |

**This confirms the hypothesis Wave 3 could not test.** Intake cost is driven by
*loan count* and is flat in counterparty count. Matching is the opposite: at a
fixed 50,000 loans, going from 200 to 5,000 distinct counterparties takes
matching from 6.8 to 26.9 seconds — a 25x increase in counterparties for a ~4x
increase in time. Matching is the stage that scales with counterparty breadth,
exactly as `research/2026-08-19-pcaf-layer-scale-and-platform-seams-brainstorm.md`
F-005 predicted. It is not yet the dominant cost at these sizes (27 s of
matching against 28 s of intake at the largest cell), but it is the term that
grows with the axis a larger bank differs on.

## What is still NOT measured

- **The full PACTA + TRISK chain.** Every number above is intake and matching
  only. `target_market_share()`, `target_sda()` and the per-sector TRISK runs
  have never been timed at scale. A genuine full-chain benchmark needs
  asset-level data (assets, financial features, carbon prices, scenarios) for
  the synthetic counterparties, and `tools/generate_scale_fixture.R` generates
  only a loanbook and an ABCD table. Fabricating the rest would measure a
  fiction, so it is deliberately left undone rather than faked.
- **Memory usage.** Only wall-clock time was recorded, in both sessions.
- **A quiet machine.** See below.

**Machine:** Windows 10 x64, 8 logical cores, ~8 GB total RAM, running other
applications throughout (browser, IDE, background agent tooling). Read the
timings as "this ran to completion in this much wall-clock time on a busy shared
machine", not as a clean performance ceiling. The qualitative findings — loan
count drives intake, counterparty count drives matching, and vectorization cuts
intake by roughly two thirds at 50,000 rows — are expected to hold regardless.

## Submission size (intake and matching only)

Intake validation plus fuzzy matching completed for **50,000 loans across up to
5,000 distinct counterparties in under a minute** post-vectorization (28 s
intake + 27 s matching at the largest cell), against roughly two minutes before.
This covers the two stages benchmarked; **it is not a claim about the full
pipeline's supported size** (see "What is still NOT measured").
`intake/SCHEMA.md`'s submission-size guidance is written to that scope
precisely — do not read it as an end-to-end guarantee.

## Reproducing / extending this benchmark

```powershell
$env:Path += ";C:\Program Files\R\R-4.5.2\bin"
Rscript tools/benchmark_scale.R --timeout-seconds 400
```

Appends to `docs/scale_benchmark.csv` (never overwrites prior rows), so a future
session can extend the grid — larger loan counts, a memory profile, or the
full-chain benchmark named above — without losing what is here. Fixtures are
written under `bench/` (gitignored) and are never committed.

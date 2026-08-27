---
title: "Wave 3: Convergence, Scenario Vintage Truth, and Delivery Readiness"
date: "2026-08-26"
type: "brainstorm"
depth: "standard"
source_request: "Unattended analysis: what would take pacta-trisk to the next level, grounded in the repo at 6170ae2"
slug: "wave3-convergence-vintage-and-delivery-readiness"
predecessors:
  - "research/2026-08-11_gtb-middle-tier-gap-closers-brainstorm.md"
  - "research/2026-08-19-pcaf-layer-scale-and-platform-seams-brainstorm.md"
---

# Brainstorm: Wave 3 — Convergence, Scenario Vintage Truth, and Delivery Readiness

## Problem & Why Now

The last commit that changed a line of pipeline code is `7ce3dc8`, **2026-08-08**.
`6170ae2` (2026-08-18) is plan triage. In the eighteen days since Wave 2 closed,
this repository has produced **two brainstorms totalling ~52 KB, 26 resolved
decisions and 9 open questions — and zero plans and zero code**.

That is the finding that reframes everything else. The bottleneck has moved. It is
no longer "we don't know what to build"; two documents answer that in considerable
detail and both are, on re-verification, substantially correct. The bottleneck is
that analysis is accumulating faster than it converts, and each new unconverted
backlog makes the next conversion harder — three parallel decision sets with
overlapping IDs, overlapping refreeze requirements, and no agreed order.

**So this brainstorm has two jobs, in this order:**

1. **Converge.** Merge the two open backlogs into one sequenced program with one
   refreeze boundary, so `/plan` has a single target instead of three.
2. **Add what a fresh read turns up that neither covered** — and there is a
   meaningful set, clustered in three places both predecessors walked past: the
   **scenario vintages** the whole methodology is benchmarked against, the
   **delivery format** every client artifact is produced in, and the **data
   governance** posture that applies the moment a real bank's loanbook arrives.

Why now, concretely: the GTB 2026–2027 program starts Q4 2026. Roughly five weeks
of build time remain before that is a present-tense commitment rather than a
future one, and three of the findings below are visible in artifacts that ship
today.

## Current vs Desired State

- **Current state — measured, not quoted.** I ran both suites at `6170ae2` on
  2026-08-26:
  - `Rscript -e "testthat::test_dir('tests/testthat')"` → **FAIL 0 | WARN 5 |
    SKIP 1 | PASS 408**, exit 0. (`NEWS.md` 0.4.1 says 404; nothing checks that
    number, see N-006.)
  - `python -m pytest dashboard/tests` → **58 passed**.
  - 10,295 lines of R across `R/` + `scripts/`; 2,811 lines of Python.
  - Two engagements run end to end through one orchestrator; two acceptance gates
    (byte-identity, INV-001..006) wired into `ci.yml` on every push.
  The platform is internally honest and internally verified. That was Wave 2's
  goal and it was met.
- **What is not true yet.** Every benchmark it measures against is dated 2023.
  Every deliverable it produces is an HTML file. Every client-facing word it
  writes is English. Its `.gitignore` would commit a real bank's counterparty
  names to git. Its private-instance recipe tops out at one client. And its
  scale-testing plan (predecessor DEC-005) assumes a synthetic generator that
  does not exist.
- **Desired state.** A platform whose benchmarks carry a current vintage and can
  show two vintages side by side; whose deliverables arrive in the format and
  language the recipient files them in; whose data-governance defaults are safe
  for a real loanbook rather than tuned for a fixture; and which has one ordered
  program of work instead of three parallel ones.
- **Key repo surfaces this brainstorm touches** (predecessor surfaces not
  repeated):
  - Vintage: `data/scenarios/pdp8-2023/`, `scenario_source` literals
    (`pdp8_2023`, `nze_2023`, `steps_2023`), `tools/verify_refactor.R` INV-002
  - Delivery: `R/report_toolkit.R`, `scripts/generate_*.R` (all HTML-only),
    `templates/engagement/letter_template.html`,
    `templates/disclosure/disclosure_sections.md`, `reports/*.pdf` (April, hand-made)
  - Governance: `.gitignore` (engagement whitelist block),
    `docs/intake_privacy.md`, `docs/private-instance-deploy.md`,
    `dashboard/lib/auth.py`
  - Scale: `scripts/generate_vietnam_data.R` (751 lines, zero RNG),
    `data/fixtures/unseen_bank_loanbook.csv` (40 rows)
  - Publication: `scripts/refresh_dashboard_data.R:73-81`,
    `dashboard/lib/loaders.py::report_catalog()`

## Findings

New findings are `N-0xx`. Where a predecessor already owns a finding I cite it by
file rather than renumber it: `[GTB]` =
`research/2026-08-11_gtb-middle-tier-gap-closers-brainstorm.md`, `[PCAF]` =
`research/2026-08-19-pcaf-layer-scale-and-platform-seams-brainstorm.md`.

### N-001 — The whole methodology benchmarks against 2023 vintages, and says so in the data

Every scenario row in the repo is stamped with its vintage, and every stamp reads
2023:

```
$ cut -d, -f1,2 data/scenarios/pdp8-2023/vietnam_scenario_ms.csv | sort -u
pdp8_2023,pdp8_ndc
nze_2023,nze_global
steps_2023,steps
```

`data/scenarios/` has exactly one child: `pdp8-2023/`.

Vietnam amended PDP8 in April 2025 (the "Adjusted PDP8", Decision 768/QĐ-TTg),
materially raising renewable-capacity targets and reshaping the coal trajectory —
which is precisely the trajectory that produces the repo's headline finding
("coal capacity +13.37 pp over PDP8 target",
`docs/bidv_sector_prioritization_methodology.md:39`). The IEA has republished NZE
since WEO 2023. *Verify both citations against primary sources before publishing
anything* — but note that the finding does not depend on the verification: the
repo's own labels say 2023, unambiguously, three vintages back, in a program
running 2026–2027.

The commercial shape of this is unusually sharp. BIDV's and Techcombank's own
strategy teams work to the current PDP8. A tool that tells a Vietnamese bank it is
misaligned against a superseded national power plan does not get a second meeting,
and the objection arrives in the first one.

The good news is that the machinery for this already exists and has never been
used. Wave 1 built the vintage directory convention *and* an invariant to police
it — INV-002 checks that no scenario vintage exists at two paths — and then gave
it exactly one tenant. Adding `data/scenarios/pdp8-2025-adjusted/` is the first
real exercise of a mechanism that has so far only ever guarded a single file set,
and running both vintages side by side is itself a saleable artifact: *"here is
what changed for your portfolio when the national plan changed."*

### N-002 — Every client deliverable is an HTML file; there is no PDF or Word path

```
$ grep -rn "pdf\|docx\|officer\|pagedown\|chromote\|wkhtmltopdf" --include=*.R scripts/ R/
(no matches)
```

The engagement letters, the disclosure pack, the coverage & reconciliation report,
the validation report, the BIDV framework report — all HTML, all the time. The
three PDFs in `reports/` are dated 2026-04-16 and were made by hand; no deliverable
produced since April has one.

What those deliverables are *for* is the problem. `docs/outputs_layer.md` describes
the disclosure pack as "a TCFD-aligned, ISSB-cross-referenced, Decision 263–mapped
board/regulator document, answering *what to file with SBV*." Board packs and
regulatory filings are PDF. Engagement letters that a relationship manager takes
into a borrower meeting are PDF. A bank's document-management system ingests PDF.
Handing a bank a folder of `.html` files and asking them to print each one is the
kind of friction that makes a good analytical product feel like a prototype.

This is cheap in effort and awkward in dependencies: the natural R tools
(`pagedown`, `chromote`, `officer`) all add a pipeline dependency, and Law 8 says
don't. The escape hatch is that PDF rendering is a *delivery* step, not a
*pipeline* step — it can live in `tools/` with a soft `requireNamespace()` guard
and a documented headless-Chrome prerequisite, exactly the way
`R/report_toolkit.R` already degrades when `base64enc` is missing.

### N-003 — There is no result history, in a product whose whole regulatory purpose is annual comparison

Every run overwrites. `synthesis_output/` is regenerated in place; `dashboard/data`
is a single frozen snapshot republished weekly; `pipeline_manifest.json` carries
`generated_at` and `git_sha` and nothing else. The only history in this repository
is `git log`, and git is not a query surface for "what was our 2026 coal alignment
gap versus our 2025 one".

TCFD, ISSB/IFRS S2 and Decision 263 are all *annual and comparative*. The
question a bank's disclosure actually has to answer is not "what is our alignment
gap" but "how did it move, against what baseline, and did our target hold". The
platform cannot express that sentence today, and neither queued workstream fixes
it: `[GTB]` DEC-008's target registry has a "baseline year/value" column with
nothing to populate it from, and `[PCAF]` DEC-001's financed-emissions inventory
is only meaningful as a time series — a single-year financed-emissions number with
no prior year is a number a bank cannot use.

The minimum viable version is small and purely additive: an append-only
`history/<vintage>/` directory holding the handful of headline artifacts per run
(alignment gaps, sector ranking, engagement priority, and later financed
emissions), keyed by run date + git sha + scenario vintage, plus one diff report
that renders the deltas. It costs one directory and one script; it converts every
downstream deliverable from a snapshot into a trend.

### N-004 — `.gitignore` whitelists a real client's normalized loanbook

`docs/intake_privacy.md` rule 1: *"No raw client data is committed to git."*

`.gitignore`:

```
engagements/*/intake/*
!engagements/*/intake/normalized_loanbook.csv
!engagements/*/intake/validation_warnings.csv
!engagements/*/intake/coverage_metrics.json
...
engagements/*/output/engagement/*
!engagements/*/output/engagement/engagement_priority.csv
```

Those negations are wildcards over **every** engagement. They were added for one
purpose — keeping the SDB rehearsal's regression fixtures tracked — and they are
correct for that purpose. But `normalized_loanbook.csv` is the post-intake
loanbook: counterparty legal names, exposures in whole VND, credit limits, sector
codes, LEIs. `engagement_priority.csv` is a named borrower ranking. The moment
someone runs `Rscript scripts/new_engagement.R` for BIDV and then `git add -A`,
a real bank's named exposures are staged, silently, by a rule written for a
fixture — in direct contradiction of the repo's own published privacy rule.

The fix is one line of specificity (whitelist `engagements/sdb-rehearsal/...`
rather than `engagements/*/...`) plus, ideally, an invariant that fails if any
tracked path under `engagements/` belongs to a slug not on an explicit
fixture allowlist. That is the same shape as INV-003 and INV-004 and would cost
about a dozen lines in `tools/verify_refactor.R`.

There is a second-order version of the same problem in
`docs/private-instance-deploy.md`, which instructs the operator to clone the repo
and commit the client snapshot into a private GitHub repo. That is a reasonable
delivery model, but it means the safety of a bank's data rests entirely on the
operator having created the repo private and on these `.gitignore` rules — neither
of which is checked by anything.

### N-005 — Private client instances top out at one bank, gated by a shared static password

Two things in `docs/private-instance-deploy.md` do not survive contact with two
signed clients:

- **"Streamlit Community Cloud free tier supports 1 private app."** The document
  says this itself. BIDV plus Techcombank is two. The stated workaround — "delete
  it first or upgrade" — is not a workaround for two concurrent engagements.
- **`DEMO_PASSWORD` is the entire access-control model.** One shared static
  string, in `dashboard/lib/auth.py`, compared with `==` (not
  `hmac.compare_digest`), with no per-user identity, no rotation, no lockout, no
  rate limiting, and no access log. For a public synthetic demo that is exactly
  right and I would not change it. For an instance holding a real bank's
  loanbook-derived exposures under an MoU, it is the first item a bank infosec
  reviewer writes down — and "we have a shared password" is not an answer that
  gets a pilot approved.

Neither of these is a code defect today; both are commitments that become due at
signature. The decision they force is *where a client instance is hosted* — and it
should be made before a bank asks, not during the review.

### N-006 — There is no synthetic *generator*; predecessor DEC-005 rests on one that does not exist

```
$ grep -rn "set.seed\|runif\|rnorm\|sample(" scripts/*.R R/*.R
(no matches)
```

`scripts/generate_vietnam_data.R` is 751 lines of hand-written literals — 43
`make_loan()` calls, ~174 `make_abcd()` rows, scenario points typed out one at a
time. It is a *transcript*, not a generator. That is a deliberate and good choice
for byte-identity (zero RNG is why the pipeline reproduces exactly), and it should
not change.

But `[PCAF]` DEC-005 says: *"Parameterize the synthetic generator by row count,
time intake → match → PACTA → scoring at 1k / 10k / 50k loans."* There is nothing
to parameterize. Scale benchmarking needs a **new, seeded, second generator**
(`tools/generate_scale_fixture.R`), writing only to a gitignored scratch path,
never to `data/`, and never on the byte-identity path. This does not weaken
DEC-005 — measurement is still the right first move, and the largest loanbook
anywhere in the repo is `data/fixtures/unseen_bank_loanbook.csv` at 40 rows — it
corrects its cost estimate and its acceptance boundary.

A related nuance for whoever plans this: `r2dii.match::match_name()` is fuzzy
string matching over the counterparty × ABCD-company cross product, so the scaling
variable that matters is **distinct counterparties**, not loans. A 50,000-loan book
with 800 borrowers may be entirely fine while a 5,000-loan book with 5,000
borrowers is not. Benchmark both axes or the published number will be wrong in the
direction that embarrasses.

### N-007 — Every client-facing word is English, for two Vietnamese banks

```
$ grep -rln "Tiếng Việt\|bilingual" --include=*.R --include=*.py --include=*.md . \
    | grep -v research/ | grep -v plans/ | grep -v attic/
./activeContext.md
./reports/2026-05-22-bidv-framework-recommendation-gap-analysis.md
```

`intake/templates/README_vi.md` exists — the intake templates are bilingual, which
is the one place someone thought about it, and it is the *right* place to have
started. Nothing else is: not the dashboard, not the engagement letters, not the
disclosure pack, not the coverage report, not any generated HTML.

The BIDV MoU is itself a bilingual document. `intake/SCHEMA.md` already knows this
matters — it explains the whole-VND unit contract in terms of *"nghìn đồng"* and
*"triệu đồng"* because that is how a Vietnamese bank's MIS actually reports. A
disclosure pack destined for SBV, and an engagement letter a relationship manager
reads out to a Vietnamese borrower, have the same requirement and don't meet it.

`plans/PROGRESS.md` raised exactly this as open decision #5 — *"full bilingual,
English-only with Vietnamese annotations, or English-only"* — on **2026-03-21**.
Five months later it is still open, and it is the only one of that document's six
open decisions that has become *more* expensive to defer, because there are now
five HTML generators to retrofit instead of one.

The honest scoping is that full bilingual output is a real workstream, not a
sprint. The cheap 80% is a per-engagement label overlay: one CSV of
`token,en,vi`, one lookup in `R/report_toolkit.R`, applied to section headings,
table column names and the fixed disclaimer text — leaving analyst-written
narrative English until someone commits to translating it.

### N-008 — The public demo republishes four internal build reports and two European ones

Sharpening `[PCAF]` F-004 rather than repeating it. `refresh_dashboard_data.R:73-81`
copies eight reports into `dashboard/data/reports/`;
`dashboard/lib/loaders.py::report_catalog()` has metadata for four and silently
drops the rest via `if meta:`. Of the eight actually sitting in the public
snapshot right now:

- `PACTA_Alignment_Report.html` and `PACTA_Comparison_Report.html` are built on
  r2dii's bundled **European demo portfolio** — `[PCAF]` F-004's finding, verified.
- `2026-04-28-trisk-multisector-phases-1-2.html` and
  `2026-04-16-pacta-baseline-stabilization.html` are **internal engineering phase
  reports**. They are build logs. They are on the sales surface.
- Four of the eight are unreachable from the app that publishes them.
- The newest is dated 2026-04-28. Every Wave 0, 1 and 2 report, the BIDV framework
  report, and the coverage & reconciliation report have never reached the demo.

`[PCAF]` DEC-006's fix (a config-declared report set with one title/date/summary
sidecar consumed by both languages) resolves all of it, and should also cover the
distinction this finding adds: *internal build report* is a third category
alongside *client-facing* and *methodology reference*, and only the latter two
belong in a public snapshot.

### N-009 — Two verification asymmetries: the changelog's numbers, and Python's dependency pinning

Two small things that share a shape — a claim that nothing checks.

- **`NEWS.md` 0.4.1 states "FAIL 0 / PASS 404".** Today's run is 408. The
  difference is almost certainly benign (environment, an added assertion), but the
  point is that nobody knows, because no gate reads that number. For a repo whose
  entire acceptance culture is "the claim must be mechanically checkable", a
  hand-typed pass count in the changelog is the one claim that isn't.
- **The R stack is pinned to the digit in `renv.lock`; the Python stack is not
  pinned at all.** `dashboard/requirements.txt` is five range constraints
  (`streamlit>=1.41,<2`, `pandas>=2.2,<3`, …). Streamlit Community Cloud resolves
  those fresh on every rebuild, so the *public demo* — the sales surface — can
  change its Streamlit minor version underneath a live client walkthrough while the
  analytical layer beneath it is reproducible to the digit. A `requirements.lock`
  (or `uv.lock`) generated once and used by CI and Cloud removes an entire class
  of "it looked different yesterday".

Neither is urgent. Both are ten minutes. Both are the sort of thing that is
embarrassing precisely because this repo is otherwise rigorous about it.

### N-010 — The only test that runs the orchestrator is skipped by default

Today's local run: `SKIP 1`. That skip is `test_sdb_engagement.R`'s regeneration
path, gated behind `RUN_SDB_ENGAGEMENT=1`. It **does** run in CI as its own job,
which is exactly what `lessons.md` #4 demanded and got — so this is not the old
defect returning.

It is a smaller, live version of it: on a developer laptop, the default
`testthat::test_dir()` command that `CLAUDE.md` names as *the* full-suite command
never exercises `run_engagement.R` at all. 408 green assertions can coexist with a
broken orchestrator until CI says otherwise, which is a slow feedback loop for the
one script every engagement depends on. The cheap mitigation is not un-skipping it
(it's slow, and the gate is correct) but making the skip *loud* — a one-line
summary at the end of a local run saying which gated tests did not execute and
how to run them.

## Resolved Decisions

Per the unattended-run rule, where a choice was open I adopted the option I would
have recommended and recorded it here. `DEC-1xx` numbering avoids collision with
the predecessors' `DEC-0xx`.

- **DEC-101: Stop brainstorming and convert. The next artifact this repository
  produces should be a plan, not a third analysis.** This document is written to
  be the last one before `/plan`, and it deliberately merges rather than extends.
  — Three unconverted backlogs is already one too many; a fourth would make the
  eventual plan a synthesis exercise instead of an implementation one.

- **DEC-102: One merged Wave 3 program, one refreeze boundary.** All three
  documents' work items sequence into the single ordered program in *Approaches
  Considered* below, with exactly one golden refreeze at the end that carries
  `[PCAF]` F-002 (rounding before ranking), `[PCAF]` F-003
  (`trisk_priority_score`), and any SDA/target changes `[GTB]` DEC-007/DEC-010
  produce. — Each refreeze costs a full re-verification; the repo's batched
  discipline has worked three times and should not be abandoned for convenience.

- **DEC-103: The scenario-vintage refresh (N-001) is the highest-priority
  *client-facing* item, and it goes early — immediately after the seams work.**
  Add `data/scenarios/pdp8-2025-adjusted/` as a second vintage; keep `pdp8-2023`
  tracked and runnable; make the vintage a config key rather than a path literal;
  ship a two-vintage comparison as a deliverable in its own right. — It is the
  only finding here that a client can raise as an objection in the first meeting,
  and the mechanism to fix it was built in Wave 1 and has never carried a second
  tenant.

- **DEC-104: Scenario vintage becomes a first-class, run-stamped attribute, not a
  directory name.** Every output that depends on a scenario carries a
  `scenario_vintage` column or manifest field, and `pipeline_manifest.json`
  records it. — Without this, N-003's history layer cannot tell "the portfolio
  changed" from "the benchmark changed", which is the single most important
  distinction in a year-over-year climate disclosure.

- **DEC-105: Build the result-history layer (N-003) as an append-only
  `history/<run-id>/` tree plus one diff report, and build it *before* the PCAF
  layer.** Run-id = date + git sha + scenario vintage. Only headline artifacts are
  retained, not the full tree. — PCAF financed emissions is the artifact that most
  needs a time series, and retrofitting history onto it later means a migration;
  building it first means PCAF's first run is simply its first vintage.

- **DEC-106: Fix N-004 immediately and independently of everything else.** Narrow
  the `.gitignore` negations to `engagements/sdb-rehearsal/`, and add INV-007:
  no tracked file under `engagements/<slug>/` for any slug not on an explicit
  fixture allowlist. — It is a one-line change plus a dozen-line invariant, it
  trips no gate, it contradicts a published privacy rule today, and its failure
  mode is the single worst outcome available to this project.

- **DEC-107: PDF is a delivery step in `tools/`, never a pipeline step.**
  `tools/render_pdf.R` wraps a soft-dependency renderer behind
  `requireNamespace()`, documents the headless-Chrome prerequisite, and is invoked
  explicitly — not from `run_engagement.R`, not from `build_step_list()`. HTML
  stays the canonical generated artifact. — Preserves Law 8 (no new pipeline
  dependency) and Law 5 (nothing on the byte-identity path changes) while closing
  the gap, and mirrors `report_toolkit.R`'s existing soft-dependency pattern.

- **DEC-108: Bilingual output ships as a token overlay first, not a translation
  project.** One `templates/i18n/labels.csv` of `token,en,vi`; a lookup in
  `R/report_toolkit.R`; applied to headings, table column names, and the mandatory
  synthetic-data disclaimer. Narrative body text stays English until someone
  commits to translating it, and every bilingual artifact states which parts are
  translated. — Delivers the visible 80% for two Vietnamese banks at a fraction of
  the cost, and settles `PROGRESS.md`'s five-month-old open decision #5 as
  "bilingual labels, English narrative, explicitly stated" rather than leaving it
  open a sixth month.

- **DEC-109: Scale benchmarking gets a new seeded generator in `tools/`, writing
  only to a gitignored scratch path, and benchmarks distinct counterparties as a
  separate axis from loan count.** `scripts/generate_vietnam_data.R` stays
  RNG-free and untouched. — Corrects `[PCAF]` DEC-005's cost estimate (N-006) and
  keeps the zero-RNG property that makes byte-identity work.

- **DEC-110: Answer the client-instance hosting question (N-005) as a written
  decision record before signature, not as code.** `docs/hosting-decision.md`
  gains a second section covering multi-client private instances, with a
  recommendation. My recommendation, adopted: **a single access-controlled
  operator-hosted deployment with per-engagement data separation, rather than N
  cloned private repos** — the clone-per-client recipe multiplies the N-004 risk
  by the number of clients and is capped at one by the free tier anyway. — This is
  a decision, not a build; making it costs an hour and unblocks the infosec
  conversation.

- **DEC-111: Adopt every predecessor decision unchanged except where a finding
  here amends it.** Amendments: `[PCAF]` DEC-005 is amended by DEC-109 (no
  generator exists); `[PCAF]` DEC-006 is amended by N-008 (internal build reports
  are a third category); everything else — the PCAF layer, the data-quality
  scoring, the carbon-cost analytic, the declarative step registry, the dependency
  invariant, the four GTB workstreams — stands as written. — Both predecessors
  re-verified cleanly against the tree; re-deciding settled questions is exactly
  the failure mode DEC-101 exists to stop.

- **DEC-112: Fold the small verification asymmetries (N-009, N-010) into the
  first hygiene phase rather than tracking them separately.** Generate a Python
  lockfile; either drop the pass count from `NEWS.md` or have a gate assert it;
  print skipped-test names at the end of a local run. — Together they are under an
  hour and they close the last gaps between what this repo claims and what it
  checks.

## Assumptions & Constraints

- **ASM-101:** Both predecessor brainstorms remain wanted and unplanned; nothing
  in `plans/` is dated August. Verified at `6170ae2`.
- **ASM-102:** The 2025 Adjusted PDP8 (Decision 768/QĐ-TTg, April 2025) exists and
  supersedes the 2023 plan for power-sector target-setting. **This must be verified
  against primary sources before any client-facing use** — but N-001 stands
  regardless, because the repo's own vintage labels read 2023.
- **ASM-103:** No real BIDV or Techcombank loanbook exists this cycle. Unchanged
  from both predecessors.
- **ASM-104:** Q4 2026 program start, per `[GTB]` DEC-002. Roughly five weeks of
  build time remain.
- **ASM-105:** A headless Chrome or equivalent is available on the operator
  machine for PDF rendering. If not, DEC-107 degrades to a documented
  "print-to-PDF from the browser" runbook, which is what happens today implicitly.
- **CON-101:** Law 5 — byte-identity of `synthesis_output/**`,
  `output/engagement/engagement_priority.csv` and the committed SDB outputs, gated
  in `ci.yml` on every push. Every item here is additive except the vintage work
  (DEC-103), which *will* move numbers if the second vintage becomes the default —
  hence DEC-102's single refreeze boundary and DEC-103's requirement that
  `pdp8-2023` stays runnable.
- **CON-102:** Law 4 — `test_golden_numbers.R` pins six values including
  `composite_score[1] == 0.9113849765258216`. Both the rounding fix and any
  vintage default change move them; both must re-pin in the same commit.
- **CON-103:** Law 8 — no new *pipeline* dependencies. DEC-107 and DEC-108 are
  built to respect this: PDF is a `tools/` soft dependency, i18n is a CSV and a
  lookup.
- **CON-104:** Law 2 — VND is never rescaled. Unaffected by everything here.
- **CON-105:** Synthetic-data disclaimers are mandatory in every generated
  artifact. DEC-108 makes the disclaimer one of the first strings translated, not
  one of the last — a Vietnamese-labelled report with an English-only disclaimer is
  worse than an English report.
- **CON-106:** `dashboard/data` is writable only by `mcb-demo`
  (`public_snapshot_allowed`). The history layer (DEC-105) is per-engagement and
  must not assume the public snapshot path.

## Approaches Considered

**Chosen — one merged Wave 3, sequenced cheapest-unblocking-first:**

| # | Phase | Sources | Why here |
|---|---|---|---|
| 0 | **Hygiene & governance** — N-004 gitignore + INV-007, N-009 Python lockfile + NEWS claim, N-010 loud skips, `PROGRESS.md`/`activeContext.md` refresh, DEC-110 hosting decision record | N-004, N-009, N-010, DEC-110 | Hours, not days. Trips no gate. One item is a live data-governance defect. |
| 1 | **Seams** — declarative step registry, strict unknown-key rejection, `schema_version`, `--only-step`/`--resume-from`, failure reasons in the manifest, dependency-manifest invariant | `[PCAF]` DEC-008, DEC-009, F-006, F-007 | Every later phase adds a step; doing this after phase 4 means four more `if` branches. |
| 2 | **Publication truth** — config-declared report set, retire the European and internal-build reports, one metadata sidecar for both languages | `[PCAF]` DEC-006 as amended by N-008 | The public demo is the sales surface and is frozen at April. |
| 3 | **Scenario vintage** — second vintage, vintage as config key, `scenario_vintage` stamped on outputs, two-vintage comparison deliverable | N-001, DEC-103, DEC-104 | Highest client-facing risk; exercises a mechanism built in Wave 1 and never used. |
| 4 | **Scale truth** — seeded generator in `tools/`, benchmark both axes, publish the curve, state a supported size in `intake/SCHEMA.md` | `[PCAF]` DEC-005 as amended by DEC-109 | The most predictable question a bank IT team asks, currently unanswerable. |
| 5 | **History layer** — append-only `history/<run-id>/`, one diff report | N-003, DEC-105 | Must precede PCAF so PCAF's first run is its first vintage, not a migration. |
| 6 | **PCAF layer** — `R/financed_emissions.R`, data-quality scoring, carbon-cost exposure | `[PCAF]` DEC-001..004 | The structural gap both client scopes open at. |
| 7 | **GTB commitments** — SLL readiness screen, target registry, report parameterization, workshop kit | `[GTB]` DEC-003..017 | Depends on 3 (vintage), 5 (baselines) and 6 (emissions) to be fully expressible. |
| 8 | **Delivery format** — PDF renderer, bilingual label overlay | N-002, N-007, DEC-107, DEC-108 | Presentation of everything above; content must exist before it is formatted. |
| 9 | **Single refreeze** — rounding before ranking, `trisk_priority_score`, SDA/target changes, re-pin goldens, bump to 0.5.0 | `[PCAF]` F-002/F-003, `[GTB]` DEC-007/010, DEC-102 | One batched re-verification, as the last three waves did. |

- **ALT-101: Keep the two backlogs separate and plan them independently.**
  Rejected: they collide on `engagement_priority.csv`, on the refreeze boundary,
  and on the step list, and independent plans would each have to guess what the
  other did to those.
- **ALT-102: PCAF first, everything else after** (i.e. `[PCAF]` ALT-001, revived
  now that the seams work is only one phase). Rejected for the reason that
  document gave, plus a new one: a financed-emissions inventory published against
  2023 scenario vintages inherits N-001's credibility problem at the exact moment
  it is most damaging.
- **ALT-103: Ship the delivery-format work (PDF + bilingual) first, as the
  fastest visible improvement.** Genuinely tempting — it is the most *demo-able*
  change here and the cheapest per unit of client reaction. Rejected because it
  formats content that phases 3–7 are about to change, so most of the work would
  be done twice; it is placed at phase 8 rather than dropped.
- **ALT-104: Treat the scenario vintage as a data-refresh chore rather than a
  phase.** Rejected: it is not a chore, it changes the headline number
  (`+13.37 pp over PDP8 target`) that three documents and one report quote, and it
  is the first exercise of the vintage mechanism — which means it is where that
  mechanism's bugs live.
- **ALT-105: Defer N-004 to the first real engagement, since no real client data
  exists yet.** Rejected outright. The whole point of the finding is that the
  failure happens on the *first* real engagement, when attention is on the client
  and not on `.gitignore`.

## Out of Scope

- Re-deciding anything settled by either predecessor (DEC-111). Where they are
  amended, the amendment is named explicitly and the rest stands.
- The ABCD sourcing decision (`docs/abcd_sourcing_decision.md`) — still open,
  still unblocked by everything here, and it is genuinely the largest open
  methodological question in the repo.
- Automotive TRISK, real SDA convergence for cement/steel — owned by `[GTB]`.
- Multi-engagement dashboard viewing — blocked by design (CON-106).
- Full narrative translation into Vietnamese (DEC-108 scopes labels only).
- Refactoring `R/pacta_core.R` (1,459 lines) or `R/trisk_core.R` (1,745 lines) for
  their own sake. `[PCAF]` F-008's point — that `pacta_core.R` has 2 `test_that`
  blocks guarding the methodological heart — is the version of this worth acting
  on, and it belongs inside whichever phase touches that code, not as a standalone
  refactor.
- Any migration off Streamlit. DEC-110 decides hosting, not framework.

## Open Questions

1. **Q-101: When the 2025 Adjusted PDP8 vintage lands, does it become the default
   for the public MCB demo, or does the demo stay on `pdp8-2023` with the new
   vintage shown as a comparison?**
   - **Recommended default:** make 2025 the default and refreeze. A public demo
     benchmarked against a superseded national plan is the exact objection N-001
     describes, and keeping it to avoid a refreeze optimises for the gate rather
     than the client.
   - **Why this matters:** it decides whether phase 3 is additive or lands inside
     the phase-9 refreeze, which changes the shape of the whole plan.

2. **Q-102: Does the history layer (DEC-105) retain full artifacts per run, or a
   defined headline subset?**
   - **Recommended default:** a defined subset — alignment gaps, sector ranking,
     engagement priority, coverage metrics, and later financed emissions — listed
     in one config key so it is extensible without a schema change. Full retention
     turns every weekly refresh into a permanent tree.
   - **Why this matters:** it is the difference between a directory that grows by
     kilobytes a year and one that grows by megabytes a week, in a repo already
     carrying a 4 MB PDF and 6 MB of reports.

3. **Q-103: Is the bilingual overlay per-engagement or global?**
   - **Recommended default:** global (`templates/i18n/labels.csv`), with a
     per-engagement override file for bank-specific terminology. One shared table
     is the same reasoning `[GTB]` DEC-011 used to reject per-engagement template
     directories.
   - **Why this matters:** decides whether adding a third Vietnamese client costs
     a file or a fork.

4. **Q-104: Does the supported-scale commitment (phase 4) become a contractual
   number in client documents, or an internal engineering target published in
   `docs/`?**
   - **Recommended default:** publish the measured curve in `docs/` and state a
     conservative supported size in `intake/SCHEMA.md`; keep the contractual
     number out of MoUs until a real book has been processed. Measured-and-published
     beats promised-and-untested.
   - **Why this matters:** determines the acceptance bar for phase 4 — a
     benchmark you publish and a number you sign are different pieces of work.

5. **Q-105: Should INV-007 (fixture-allowlist enforcement, DEC-106) fail the build
   or warn?**
   - **Recommended default:** fail. Every other invariant fails, the allowlist is
     explicit and one line to extend, and a warning in CI output is not a control.
   - **Why this matters:** it is the only mechanical protection standing between a
     real client's named exposures and a git commit.

## Suggested Next Step

Run `/plan wave3-convergence-vintage-and-delivery-readiness` against this file,
with both predecessors as input. The plan should carry the phase-0 hygiene items
as a single first commit landable the same day, and should treat phase 9 as the
only refreeze in the program.

If only one thing gets done from this document: **DEC-106** — narrow the
`.gitignore` negations to `engagements/sdb-rehearsal/` and add INV-007. It is one
line plus an invariant, it contradicts a published privacy rule today, and it is
the only finding here whose failure mode cannot be undone.

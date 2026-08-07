# Engagement & Disclosure Output Layer

This layer turns the pipeline's analytical outputs (PACTA alignment + TRISK transition-risk results) into tangible, client-facing deliverables:

1. **Engagement letters** — one one-page letter per top-N borrower, telling the relationship manager *what to ask the borrower on Monday*.
2. **A disclosure pack** — a TCFD-aligned, ISSB-cross-referenced, Decision 263–mapped board/regulator document, answering *what to file with SBV*.

It reads only the existing committed snapshot — **no PACTA/TRISK model re-run is required** to produce a deliverable.

> **Everything here is synthetic and illustrative.** Generated artifacts are model outputs on a synthetic demonstration portfolio. They are **not** financial advice, a credit decision, or a regulatory filing, and **require human and legal review before any external use.** Every generated file carries a watermark/disclaimer saying so.

---

## Components

| File | Role |
|---|---|
| `scripts/generate_coverage_report.R` | PHASE-06 (Wave 2) — per-engagement coverage & reconciliation report. |
| `scripts/engagement_scoring.R` | PHASE-01 — builds the canonical borrower priority table. |
| `scripts/generate_engagement_letters.R` | PHASE-02 — renders per-borrower engagement letters. |
| `scripts/generate_disclosure_pack.R` | PHASE-03 — renders the disclosure pack. |
| `templates/engagement/letter_template.html` | Editable letter skeleton (tokens + CSS + watermark). |
| `templates/engagement/engagement_prompt_templates.csv` | Editable per-sector letter wording (intro + 3 actions). |
| `templates/disclosure/disclosure_sections.md` | Editable TCFD/ISSB/Decision 263 narrative. |
| `dashboard/lib/outputs.py` | Operator gating + R subprocess wrappers. |
| `dashboard/pages/7_Outputs.py` | Operator-only dashboard page. |

## Coverage & Reconciliation Report

Every engagement that runs intake produces `scripts/generate_coverage_report.R`'s
output: a **Coverage & Reconciliation Report** HTML plus a machine-readable
sidecar `engagements/<slug>/intake/coverage_metrics.json` (tracked — it carries
no timestamp, so it is byte-stable across runs). It answers, in both row counts
and VND:

- **Submitted vs normalized vs dropped** — the arithmetic identities
  `submitted == normalized + dropped` hold for both rows and VND, so nothing
  silently disappears from a client's loanbook.
- **Dropped by hard error column** — which schema violations removed which
  exposure.
- **Retained-with-warning by classification** — out-of-scope sector codes
  (`sector_out_of_scope`), USD rows converted at intake (`fx_converted`),
  USD rows retained with NA exposure for want of a rate (`fx_rate_missing`),
  and unsupported currencies (`unsupported_currency`). Warnings never drop a
  row.
- **ABCD asset-level coverage** — the share of normalized exposure whose
  counterparty resolves to an ABCD company after diacritic normalization,
  broken down by PACTA sector, with the unmatched counterparties listed by
  name and exposure so an operator knows exactly who to chase.

This is the artifact that makes "send us your loanbook and we will tell you
your coverage" a concrete offer.

## Data flow

```
TRISK borrower CSVs (power/cement/steel) ─┐
PACTA company file (automotive) ──────────┼─► engagement_scoring.R ─► output/engagement/engagement_priority.csv
matched loanbook (exposure_vnd) ──────────┘                                   │
                                                                              ├─► generate_engagement_letters.R ─► output/engagement_letters/<slug>/letter.html (+ index, manifest)
                                                                              └─► generate_disclosure_pack.R ───► output/disclosure/disclosure_pack.html
```

`engagement_priority.csv` is computed **once** and consumed by both generators, so borrower numbers are never hardcoded.

---

## How to run (command line)

Run from the repository root. On this machine, `Rscript` is at
`C:\Program Files\R\R-4.5.2\bin\Rscript.exe`.

```sh
# 1. Build the priority table (always run first; the generators also auto-run it if missing)
Rscript scripts/engagement_scoring.R                 # optional: --w_align 0.5 --w_trisk 0.5

# 2. Engagement letters (top-N by composite score; default N=10)
Rscript scripts/generate_engagement_letters.R        # optional: --top_n 10

# 3. Disclosure pack (named internal board pack by default)
Rscript scripts/generate_disclosure_pack.R           # optional: --top_n 10
Rscript scripts/generate_disclosure_pack.R --anonymize   # external-shareable (Borrower A/B/C)
```

**Outputs**

- `output/engagement/engagement_priority.csv` — ranked borrower table (tracked in git).
- `output/engagement_letters/<slug>/letter.html` + `index.html` + `manifest.csv` (git-ignored).
- `output/disclosure/disclosure_pack.html` (git-ignored).

To turn a letter or the disclosure pack into a PDF, open it in a browser and use **Print → Save as PDF** (print CSS handles page breaks). There is no separate PDF/DOCX dependency by design.

---

## How to run (dashboard, operator-only)

The dashboard page is **gated** and never appears on the public deployment.

```sh
# Enable the page, then start the dashboard
set OUTPUTS_LAYER=1                                  # Windows (PowerShell: $env:OUTPUTS_LAYER = "1")
set R_RSCRIPT=C:\Program Files\R\R-4.5.2\bin\Rscript.exe   # if Rscript is not on PATH
streamlit run dashboard/app.py
```

On the **Engagement & Disclosure Outputs** page:

1. Tick the confirmation checkbox ("illustrative, synthetic-data artifacts requiring human review"). Until ticked, both generate buttons are disabled.
2. Choose `Top-N` and (for the disclosure pack) the `Anonymise` toggle.
3. Click **Generate engagement letters** or **Generate disclosure pack**.
4. Download the artifacts; preview the disclosure pack inline.

If `OUTPUTS_LAYER` is unset, the page shows a disabled message and runs nothing.

> The composite engagement score is a **fixed 50/50** blend of PACTA alignment gap and TRISK transition-stress priority. There is intentionally no weight slider; the weighting is a documented script parameter (`--w_align` / `--w_trisk`) only.

---

## Privacy & disclaimer posture

- **Generated letters and the disclosure pack are never committed to git.** `.gitignore` ignores `output/engagement_letters/*` and `output/disclosure/*` (a `.gitkeep` keeps each directory). Only the aggregate scoring table `output/engagement/engagement_priority.csv` is tracked.
- The dashboard page is **operator-gated** (`OUTPUTS_LAYER=1`) and requires an explicit confirmation before generating — mirroring the BYOL intake page (`BYOL_INTAKE`).
- Every letter carries a synthetic-data watermark band and a human/legal-review disclaimer; every data-driven disclosure section carries a synthetic-data callout.
- The disclosure pack defaults to **named** (internal board pack). Use `--anonymize` (or the dashboard toggle) to replace borrower names with stable `Borrower A/B/C` pseudonyms before any external sharing.

---

## How the bank edits the deliverables (no code)

| To change… | Edit… |
|---|---|
| Letter layout, letterhead, watermark, styling | `templates/engagement/letter_template.html` |
| Per-sector letter wording (intro + the 3 engagement actions) | `templates/engagement/engagement_prompt_templates.csv` |
| Disclosure narrative (TCFD pillars, ISSB/Decision 263 notes) | `templates/disclosure/disclosure_sections.md` |

The generators only substitute `{{tokens}}` (letters) and convert markdown to HTML (disclosure); they never hardcode figures. After editing a template, just re-run the relevant script.

**Available letter tokens:** `borrower`, `sector`, `date`, `rank`, `top_n`, `scenario_name`, `intro`, `alignment_gap`, `npv_change`, `pd_change`, `exposure_vnd`, `trisk_status`, `engagement_actions`, `generated_at`. If a token is left unsubstituted (for example a sector missing a prompt row), the letter generator **aborts the run** and names the offending borrower/token rather than shipping a raw `{{token}}`.

---

## Coverage notes

- **TRISK-covered sectors:** power, cement, steel. Their borrowers carry NPV/PD stress figures.
- **PACTA-only sector:** automotive. These borrowers are scored on the alignment gap only, flagged `composite_partial = TRUE`, and show "Not assessed — sector not in the TRISK pilot" for the stress figures.
- Cross-sector gap magnitudes are not strictly comparable (market-share percentage-points for power/automotive vs SDA emission-intensity `gap_pct` for cement/steel). Treat the composite as a demo prioritisation aid.

## Verification

```sh
Rscript scripts/engagement_scoring.R
Rscript scripts/generate_engagement_letters.R
Rscript scripts/generate_disclosure_pack.R
python -m pytest dashboard/tests/test_outputs.py
git status --short output/        # should show no generated letter/pack files
```

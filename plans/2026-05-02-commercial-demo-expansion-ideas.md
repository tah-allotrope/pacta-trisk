# Commercial Demo / Deployment — Three Expansion Ideas

> Date: 2026-05-02
> Author: pair-programming session
> Status: For triage. Pick one as the next sprint.

## Context

The repo currently ships:

- A working synthetic Vietnam PACTA pipeline (Mekong Commercial Bank, MCB)
- A package-backed TRISK pilot covering `power`, `cement`, and `steel`
- A public Streamlit dashboard (`pactavn.streamlit.app`) with PACTA, TRISK, Reports, and Methodology pages
- Frozen `dashboard/data/` snapshot, sector-aware manifest, refresh script, demo script, deploy doc

What is *missing* for a paid commercial demo or first deployment:

1. The dashboard is read-only against a frozen synthetic snapshot — nothing the client can drive
2. The pipeline assumes our hand-built MCB CSVs; no path for a real bank to plug in their own loanbook
3. The output stops at analytics — there is no client-facing artifact (engagement letter, regulator filing) that a bank can actually hand to a borrower or to SBV

The three ideas below each close one of those gaps and are sized as roughly one focused sprint.

---

## Idea 1 — Bring-Your-Own-Loanbook (BYOL) Pilot Intake

**Problem it solves.** Today, going from synthetic MCB to a real Vietnamese bank requires us to manually rebuild loanbook + ABCD + scenario CSVs. A bank that says "yes, run this on us" cannot self-serve and we have no clean intake contract. This is the single biggest blocker to converting a demo conversation into a paid pilot.

**What we build.**

- A documented input contract under `intake/` defining the minimum loanbook columns (counterparty name, exposure VND, ISIC or VSIC, sector hint, optional LEI/tax ID) and the minimum ABCD columns
- An Excel + CSV intake template under `intake/templates/` with examples, validation rules, and a Vietnamese-language README
- A mapping wizard script `scripts/intake_validate_and_map.R` that:
  - reads a client loanbook
  - applies VSIC→ISIC→PACTA sector mapping (already in `pacta_vietnam_scenario.R`)
  - flags rows requiring manual review (low fuzzy score, sector mismatch, missing counterparty)
  - emits a normalized loanbook in the synthesis pipeline's expected format
- A new dashboard page `5_Intake_Wizard.py` (gated) that lets a logged-in operator upload a client file, view the validation report, and produce a downloadable normalized snapshot
- A privacy note in `docs/intake_privacy.md`: aggregated views only, no raw counterparty rows leave the operator's machine, optional pre-anonymization of borrower names

**Commercial value.** Turns the repo from "look at our synthetic demo" into "here is the file we need from your bank, we will return your alignment + transition stress in 5 business days." That is a real proposal sentence.

**Effort.** Medium. The mapping logic already exists; the work is contract definition, validation, and the operator-only intake page.

**Risks.** Privacy posture must be explicit before any real bank file touches the codebase. Public Streamlit deployment cannot host the intake wizard — we either move to a password-gated deployment for operator pages or run intake offline.

---

## Idea 2 — Interactive Scenario & Stress Builder

**Problem it solves.** The current TRISK page shows precomputed sensitivity grid output. A banker in a live demo cannot move the levers that matter to them — `shock_year`, `discount_rate`, `risk_free_rate`, `market_passthrough`, carbon-price trajectory. This means we can describe TRISK but we cannot actually let the client *use* it during a sales meeting, which is exactly the moment buying intent forms.

**What we build.**

- A scenario authoring page `dashboard/pages/5_Scenario_Builder.py` with sliders / inputs for:
  - shock year (2025–2035)
  - discount rate
  - risk-free rate
  - market passthrough
  - carbon price scenario family (NGFS Net Zero, Below 2C, Delayed, custom upload)
- Two execution modes:
  - **Precomputed grid** (works on Streamlit Cloud, no R runtime): expand the existing one-at-a-time sensitivity grid in `scripts/trisk_sector_demo.R` into a small factorial grid, snapshot the borrower-level outputs, and let the slider page interpolate / lookup against that grid
  - **Live rerun** (operator deployment with R available): call `scripts/trisk_sector_demo.R` as a subprocess and stream a fresh borrower-level table back into the page
- A side-by-side comparison view: baseline vs scenario, top movers in NPV change and PD change, exportable as PNG and CSV
- A "save scenario" feature that writes the parameter set + results into `dashboard/data/saved_scenarios/` so the same view can be revisited or shared

**Commercial value.** Demos shift from narration to interaction. A banker who has just dragged a slider and seen their top-20 borrowers reorder is much closer to writing a check than one who watched a static dashboard. Also unlocks workshop-style engagements (paid scenario design sessions).

**Effort.** Medium. The precomputed grid path is purely additive over existing scripts. The live-rerun path needs a process boundary and a small queue, deferrable to a second iteration.

**Risks.** Grid size can blow up — keep the v1 grid to two or three parameters at coarse step sizes. Live-rerun mode must not be exposed publicly without rate-limiting and operator auth.

---

## Idea 3 — Engagement & Disclosure Output Layer

**Problem it solves.** The pipeline currently ends at analytics. Bankers and regulators ask the next question — "so what do I do Monday morning, and what do I file with SBV?" There is no template that converts our outputs into a borrower-facing engagement letter or a regulator-ready disclosure pack. Without this layer, the dashboard is interesting but not actionable, and the deal stalls at the proof-of-concept stage.

**What we build.**

- A borrower engagement letter generator `scripts/generate_engagement_letters.R` that, for a chosen top-N list of borrowers (by TRISK priority score), produces:
  - a one-page Vietnamese / English bilingual letter per borrower
  - alignment status by relevant sector (PACTA market share or SDA gap)
  - transition stress summary (NPV change, PD change vs baseline, scenario)
  - three suggested engagement actions (data request, transition plan ask, covenant tightening trigger)
  - output as PDF and DOCX under `output/engagement_letters/<borrower>/`
- A regulator/board disclosure pack generator `scripts/generate_disclosure_pack.R` aligned to TCFD pillars (Governance, Strategy, Risk Management, Metrics & Targets) and ISSB IFRS S2 disclosure topics, producing:
  - executive summary
  - portfolio alignment vs PDP8 / NDC / NZE
  - top-10 transition risk borrowers (anonymized option)
  - methodology appendix referencing the existing `4_Methodology` page
  - output as a single self-contained HTML and PDF
- A new dashboard page `6_Outputs.py` that lists generated artifacts with download buttons, gated to operator role
- Templates under `templates/engagement/` and `templates/disclosure/` with placeholder syntax so the bank can rebrand without code changes

**Commercial value.** Converts every analytical run into a tangible deliverable that a Head of Credit can mail to a borrower and a Head of Risk can put in a board pack. This is the artifact bankers can show their boss to justify the engagement, which is the difference between a one-off demo and a recurring quarterly subscription.

**Effort.** Medium-high. The generators are mostly templating over existing dataframes, but bilingual layout, PDF rendering on Windows, and TCFD/ISSB phrasing review will eat time. Plan for a templating library (`officer` / `quarto` / `rmarkdown` to PDF) and a legal review pass on the letter language before any external use.

**Risks.** Letter content has commercial and reputational consequences if shared externally — must ship behind explicit operator confirmation and synthetic-data watermark until a real bank signs off. Regulator alignment (SBV vs international TCFD wording) needs a domain reviewer.

---

## Recommendation

If we are optimizing for **closing the first paid pilot**, do **Idea 1** first — without an intake path no real bank can engage. If we are optimizing for **winning the next live demo**, do **Idea 2** first — interactive levers convert better than static dashboards. If we are optimizing for **stickiness and recurring revenue**, do **Idea 3** first — only the output layer makes the analytics part of a quarterly process.

A natural sequencing if we have three sprints: **2 → 1 → 3**. The interactive builder strengthens the demo that gets us to a yes; the BYOL intake makes that yes operationally possible; the disclosure layer turns the pilot into a renewal.

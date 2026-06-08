# Gap Analysis: Bank-Prospect PACTA/TRISK Pitch Deck

**Date:** 2026-06-09
**Scope:** Building a presentation via the `present` skill, styled on the reference deck at `present/ref/Allotrope GTB updates_Tara Vietnam_December 2025.pptx`, that showcases this repo's PACTA, TRISK, and case-study/demo capabilities to a prospective bank client (e.g., BIDV or Techcombank).
**Status:** Draft for Review

---

## Executive Summary

The repo is **content-rich and visually under-assembled**: there is an abundance of PACTA/TRISK analytical output (charts, HTML reports, a live Streamlit dashboard, BIDV-specific framework docs) but **zero slide-level material** and only an *internal progress-update* template to build on — not a prospect-facing sales narrative. The single biggest gap is narrative architecture: the reference deck is a status update *to a funder ("Tara")* with energy-storage (BESS) case studies that are irrelevant to PACTA/TRISK, so its content must be substantially repurposed rather than refreshed in place. There are **2 CRITICAL gaps** (no editable working deck + no prospect narrative/slide outline) and the work is best handled as a single 4–5 phase `/plan`. Recommendation: lock the slide-by-slide storyline first, then assemble reused charts/screenshots into a copy of the template.

---

## Current Capabilities (What We Have)

| Capability | Status | Key Surfaces |
|---|---|---|
| Branded deck template (16:9, Allotrope masters/layouts/logos) | Mature | `present/ref/Allotrope GTB updates_Tara Vietnam_December 2025.pptx` (25 slides, 11 layouts, BIDV/TCB already named) |
| PACTA portfolio-alignment charts | Mature | `synthesis_output/vietnam/*.png` (techmix, coal/renewables trajectories, SDA, alignment overview, coal stranded risk), `dashboard/data/pacta/*.png` |
| TRISK borrower-stress charts | Mature | `dashboard/data/trisk/{power,cement,steel}/*.png` (NPV change, PD change, priority top-10) |
| Narrative HTML reports (client-grade) | Working | `reports/2026-04-16-final-vietnam-bank-trisk-demo.html`, `reports/PACTA_Vietnam_Bank_Report.html`, `reports/PACTA_Synthesis_Report.html` |
| BIDV-specific positioning material | Working | `docs/bidv_framework_comparison.md`, `docs/bidv_decision263_mapping.md`, `docs/bidv_sector_prioritization_methodology.md`, `docs/bidv_implementation_roadmap.md`, `reports/BIDV_Framework_Recommendation_Report.html` |
| Live interactive demo (dashboard) | Mature | `dashboard/app.py` + `dashboard/pages/` (PACTA Alignment, TRISK Risk, Reports, Methodology, Scenario Builder, Intake Wizard, Outputs) |
| Demo walkthrough script | Working | `docs/demo-script.md` (8-min live dashboard tour — but *not* a slide script) |
| Engagement & disclosure outputs | Working | `output/engagement/engagement_priority.csv`, `output/disclosure/disclosure_pack.html`, `templates/{engagement,disclosure}` |
| Editable working copy of the deck | **Missing** | Only the original exists under `present/ref/` |
| Prospect-facing slide outline / storyline | **Missing** | No deck script anywhere in `docs/`, `plans/`, `reports/` |
| Presentation-quality dashboard screenshots | Partial | Only low-res `phase6-*.png` / `streamlit-*.png` at repo root |

---

## Target State

> A polished `.pptx`, indistinguishable in look-and-feel from the Allotrope GTB reference deck (same masters, layouts, logos, color system, 16:9 geometry), but re-narrated as a **capability pitch to a prospective bank**. It walks the bank from problem (transition risk / Decision 263 obligations) → PACTA portfolio alignment → TRISK borrower stress → a concrete Vietnam-bank case study/demo (with real charts and dashboard screenshots) → the engagement offer and 2026 roadmap. All visuals are rendered PNGs placed at the template's existing shape positions; all text is prospect-appropriate (no internal "waiting for response from BIDV" status language).

---

## Gap Analysis

### GAP-01: No editable working deck — `present` edits in place

**Severity:** CRITICAL — `present` modifies a template file in place; there is currently only the canonical reference original, which must not be overwritten.

**Current state:** Single file at `present/ref/Allotrope GTB updates_Tara Vietnam_December 2025.pptx`. No working copy exists.

**What's needed:**
- A working copy (e.g., `present/bank_prospect_deck.pptx`) duplicated from the reference, so the original stays pristine as a style reference.
- Confirm the copy opens and round-trips through `python-pptx` (the reference is Google-Slides-origin; shape names are `Google Shape;NNN;pXX`).

**Existing assets to reuse:**
- The reference deck itself — copy, don't recreate. All masters/layouts/logos carry over for free.

**Effort estimate:** Trivial — first step of phase 1 (single file copy + load check).

---

### GAP-02: No prospect narrative or slide-by-slide outline

**Severity:** CRITICAL — without a storyline, there is nothing for `present` to fill. The reference deck's narrative (internal progress update to a funder) is the wrong genre for a prospective-client pitch.

**Current state:** The reference is a status update: "BIDV Progress Update — Summary", Scope 1/2/3 completion tracking, "Waiting for a response from BIDV", "Questions from Tara". `docs/demo-script.md` is a *live-dashboard* tour, not a slide script. No slide outline exists in `docs/`, `plans/`, or `reports/`.

**What's needed:**
- A slide-by-slide outline mapped onto the reference's existing 25 slides / 11 layouts: which reference slides to keep, repurpose, or drop, and what each new slide says.
- A prospect arc: (1) title/cover, (2) the transition-risk + Decision 263 problem for VN banks, (3) PACTA = portfolio alignment answer, (4) TRISK = borrower-level stress answer, (5) case-study/demo evidence, (6) engagement offer + 2026 roadmap, (7) Q&A/contact.
- Decision on prospect framing: BIDV and Techcombank are named in the reference as *existing* collaborators — clarify whether the deck pitches a *new* prospect or extends an existing relationship (assumption below).

**Existing assets to reuse:**
- `reports/2026-04-16-final-vietnam-bank-trisk-demo.html` and `reports/PACTA_Vietnam_Bank_Report.html` — ready-made narrative spine (executive summary, PACTA-vs-TRISK division of labor, findings).
- `docs/bidv_framework_comparison.md` + `docs/bidv_decision263_mapping.md` — the regulatory "why now" problem framing.
- `docs/demo-script.md` — value-proposition bullets and the close ("portfolio story / borrower stress / interactive exploration / downloadable evidence").
- Reference slides 4–7 / 16 ("Looking Ahead: Proposed 2026 GTB Vietnam Activities", "Proposed Engagement for 2026") — directly reusable layout for the offer/roadmap section.

**Effort estimate:** 1 phase (the analytical core of the plan); pairs naturally with `/plan` after this report.

---

### GAP-03: Reference case-study slides are BESS/energy-storage — wrong domain

**Severity:** HIGH — reference slides 9–11 (Emivest "Behind-the-Meter BESS", solar surplus, IRR/peak-shaving) are energy-storage site analysis, unrelated to PACTA/TRISK. Left as-is they break the narrative; they are prime real estate to repurpose into the PACTA/TRISK case study.

**Current state:** No PACTA/TRISK "case study" slides exist. The repo's equivalent evidence lives in the TRISK Vietnam-bank demo (synthetic MCB portfolio) and its outputs.

**What's needed:**
- Replace the BESS case-study slides with a PACTA/TRISK case study: synthetic Vietnam-bank loanbook → coverage/matching → power-sector alignment → coal stranded-risk → TRISK NPV/PD borrower ranking.
- A "key takeaways" slide mirroring the reference's 5-box takeaway layout (slide 11), repopulated with PACTA/TRISK findings.

**Existing assets to reuse:**
- `synthesis_output/vietnam/13_vn_coal_stranded_risk.png`, `12_vn_alignment_overview.png`, `05_vn_power_techmix.png`, `06_vn_coal_trajectory.png` — drop-in case-study visuals.
- `dashboard/data/trisk/power/*.png` (NPV change, PD change, priority top-10) — the borrower-stress payoff charts.
- `reports/2026-04-16-final-vietnam-bank-trisk-demo.html` — written findings to mine for the 5 takeaway boxes.
- The reference's slide-11 multi-box layout (`Google Shape;552..561`) — reuse the exact shape geometry.

**Effort estimate:** Part of 1 phase (case-study assembly), bundled with chart export (GAP-04).

---

### GAP-04: Charts not rendered at slide resolution / aspect

**Severity:** MEDIUM — charts exist but were produced for HTML reports and the dashboard, not for placement at the template's shape boxes on a 10"×5.625" slide. Resolution/aspect mismatch will look amateurish next to the polished template.

**Current state:** PNGs exist in `synthesis_output/`, `synthesis_output/vietnam/`, `dashboard/data/pacta/`, and `dashboard/data/trisk/*`. DPI/aspect unknown and likely inconsistent; some root screenshots (`phase6-*.png`) are clearly low-res.

**What's needed:**
- Audit target charts for DPI and aspect; re-export the few that don't fit the destination shape boxes (the R scripts in `scripts/` that produced them can re-render at higher DPI).
- Ensure transparent/white backgrounds match the slide background.

**Existing assets to reuse:**
- `scripts/` R pipelines that generate `synthesis_output/` and `dashboard/data/` charts — re-run with a higher DPI argument rather than recreating plots.
- Existing PNGs where resolution is already adequate (use as-is to save effort).

**Effort estimate:** Small — 1 sub-phase; mostly re-export, not authoring.

---

### GAP-05: No presentation-quality dashboard screenshots

**Severity:** MEDIUM — the "demo" is the live Streamlit app; a static deck needs crisp screenshots of the PACTA Alignment, TRISK Risk, and Scenario Builder pages to convey interactivity. Current root-level captures are low-res and stale.

**Current state:** `phase6-local-preview-*.png`, `streamlit-*.png` at repo root — small, outdated, pre-multisector. Dashboard has 7 pages (`dashboard/pages/`) none freshly captured.

**What's needed:**
- Fresh, high-resolution screenshots of 2–3 hero pages (PACTA Alignment, TRISK Risk, Scenario Builder) running on current data.
- Run dashboard locally per `docs/demo-script.md` fallback (`streamlit run dashboard/app.py`) and capture, or use a headless browser.

**Existing assets to reuse:**
- `dashboard/app.py` + `dashboard/pages/` — the live app to capture.
- `docs/demo-script.md` pre-demo checklist — exact pages and talking points to frame each screenshot.
- `.playwright-mcp/` present in repo — a browser-capture path already available.

**Effort estimate:** Small — 1 sub-phase (run app, capture 3 screenshots).

---

### GAP-06: Prospect-appropriate framing of named banks and synthetic data

**Severity:** MEDIUM — the reference repeatedly uses internal status language ("Waiting for a response from BIDV", "BIDV proposes transferring this report"), and all repo data is *synthetic*. A prospect deck must not present synthetic results as the prospect's real portfolio, and must scrub internal-status phrasing.

**Current state:** Reference slides 4–6, 12–15, 18–19 are dense with internal scope-tracking status. Repo data is explicitly synthetic (`docs/demo-script.md`: "State that the dataset is synthetic and safe for demo use").

**What's needed:**
- A standing "illustrative / synthetic data" disclaimer on case-study slides.
- Rewrite or drop internal-status slides; reframe BIDV/TCB material as either (a) a credibility/track-record slide or (b) generalized capability, depending on the prospect-framing decision in GAP-02.

**Existing assets to reuse:**
- `docs/demo-script.md` disclaimer language.
- `reports/BIDV_Framework_Recommendation_Report.html` — track-record framing if positioning BIDV as an existing reference client.

**Effort estimate:** Small — folded into the narrative phase (GAP-02).

---

## Second-Tier Gaps

| Gap | Severity | Summary | Existing Assets |
|---|---|---|---|
| GAP-07 | LOW | Contact/closing slide names "Tara" recipients (`tah@allotropepartners.com` et al.) — update for the prospect meeting | Reference slide 8 layout |
| GAP-08 | LOW | Speaker notes absent — add per-slide talking points for the presenter | `docs/demo-script.md` timings/bullets |
| GAP-09 | LOW | Decision 263 / TCFD / ISSB framing could be a dedicated "compliance value" slide | `docs/bidv_decision263_mapping.md`, `output/disclosure/disclosure_pack.html` |

---

## Recommended Sprint Sequencing

| Priority | Gap | Rationale |
|---|---|---|
| Sprint 1 | GAP-01, GAP-02 | Copy the template and lock the slide-by-slide storyline — nothing can be assembled without the narrative and a writable file. Blocks everything. |
| Sprint 2 | GAP-04, GAP-05 | Produce the visual assets (re-exported charts + fresh dashboard screenshots) the narrative calls for. Can start once the outline names which visuals each slide needs. |
| Sprint 3 | GAP-03, GAP-06 | Assemble case-study slides and apply prospect-appropriate framing/disclaimers — depends on both narrative (S1) and assets (S2). |
| Sprint 4 | GAP-07, GAP-08, GAP-09 | Polish: contacts, speaker notes, optional compliance slide. |

---

## Risk Register

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| `present` overwrites the canonical reference deck | Loss of the only branded original | M | Work on a copy (GAP-01) before any edit; keep `present/ref/` read-only. |
| Google-Slides-origin shapes round-trip poorly in `python-pptx` (odd shape names, grouped shapes, tables) | Layout breakage, lost formatting | M | Edit text/picture fills at existing shape positions only; avoid restructuring layouts; verify after each batch by re-opening. |
| Synthetic results read as the prospect's real data | Credibility / compliance issue in the meeting | M | Persistent "illustrative/synthetic" disclaimer (GAP-06); state it verbally per demo-script. |
| Reused charts look low-res beside the polished template | Undermines the "indistinguishable continuation" goal | M | DPI audit + re-export from `scripts/` (GAP-04); reject any PNG below slide-fit resolution. |
| Internal-status language survives into the prospect deck | Awkward/confusing for a new prospect | L | Explicit scrub pass in Sprint 3; checklist against reference slides 4–6, 12–19. |

---

## Suggested Next Step

Review this report, then invoke `/plan` to turn GAP-01 + GAP-02 into a multi-phase build plan (template copy + slide outline first), with Sprints 2–4 as subsequent phases. Resolve the one open framing question before planning: **is the deck pitching a brand-new prospect, or extending the existing BIDV/Techcombank relationship?** — this determines whether the named-bank slides become "track record" or get generalized.

### Documented assumptions
- "Case studies or demo in this repo" = the synthetic **Vietnam-bank PACTA/TRISK demo** (loanbook → alignment → borrower stress) plus the **live Streamlit dashboard**, *not* the energy-storage/BESS analyses shown in the reference deck (those have no backing data in this repo).
- "Similar to the reference deck" = same **visual template/brand and layout system**, with a **re-authored prospect narrative** — not a content refresh of the funder progress-update.
- The deck targets a single prospect per build (BIDV *or* Techcombank), parameterizable at the title/contact/positioning slides.

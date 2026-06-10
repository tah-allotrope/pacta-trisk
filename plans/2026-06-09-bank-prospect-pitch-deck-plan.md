---
title: "Bank-Prospect PACTA/TRISK Pitch Deck"
date: "2026-06-09"
status: "completed"
request: "Build the bank-prospect PACTA/TRISK pitch deck described in reports/2026-06-09-bank-prospect-deck-gap-analysis.md, covering gaps GAP-01..GAP-09, using the present skill to edit a copy of the reference deck at present/ref/, then git commit and push to main."
plan_type: "multi-phase"
research_inputs:
  - "reports/2026-06-09-bank-prospect-deck-gap-analysis.md"
  - "research/future_planning_ideas.md"
---

# Plan: Bank-Prospect PACTA/TRISK Pitch Deck

## Objective
Produce a polished `.pptx` that is visually indistinguishable from the Allotrope GTB reference deck (same masters, layouts, logos, 16:9 geometry) but re-narrated as a **capability pitch to a prospective bank** (BIDV or Techcombank), walking from transition-risk/Decision-263 problem → PACTA portfolio alignment → TRISK borrower stress → a Vietnam-bank case study/demo → the engagement offer and 2026 roadmap. The deck is built by editing a copy of the reference template via the `present` skill, then committed and pushed to `main`. This matters now because the repo holds abundant analytical output but no prospect-facing slide artifact to take into a sales meeting.

## Context Snapshot
- **Current state:** Rich content (PACTA/TRISK charts, client-grade HTML reports, BIDV framework/Decision-263 docs, a live 7-page Streamlit dashboard, an 8-minute demo script) but **zero slides**. The only deck is the reference original at `present/ref/Allotrope GTB updates_Tara Vietnam_December 2025.pptx` — a 25-slide funder progress-update with energy-storage (BESS) case studies unrelated to PACTA/TRISK.
- **Desired state:** A new `present/bank_prospect_deck.pptx` (copy-derived from the reference), re-authored as a prospect pitch, with slide-resolution charts and fresh dashboard screenshots, prospect-appropriate framing + synthetic-data disclaimers, speaker notes, updated contacts — committed and pushed to `main`.
- **Key repo surfaces:**
  - Template: `present/ref/Allotrope GTB updates_Tara Vietnam_December 2025.pptx` (25 slides, 11 layouts, 10"×5.625", Google-Slides-origin shape names `Google Shape;NNN;pXX`).
  - `present` skill: `~/.claude/skills/present/SKILL.md` + `scripts/inspect_template.py`, `scripts/render_deck.py`.
  - PACTA charts: `synthesis_output/vietnam/*.png`, `dashboard/data/pacta/*.png`.
  - TRISK charts: `dashboard/data/trisk/{power,cement,steel}/*.png`.
  - Reports (narrative spine): `reports/2026-04-16-final-vietnam-bank-trisk-demo.html`, `reports/PACTA_Vietnam_Bank_Report.html`, `reports/BIDV_Framework_Recommendation_Report.html`.
  - Positioning docs: `docs/bidv_framework_comparison.md`, `docs/bidv_decision263_mapping.md`, `docs/bidv_sector_prioritization_methodology.md`, `docs/bidv_implementation_roadmap.md`, `docs/demo-script.md`.
  - Live demo: `dashboard/app.py`, `dashboard/pages/` (1_PACTA_Alignment, 2_TRISK_Risk, 5_Scenario_Builder, …).
  - Chart generators: `scripts/*.R` (re-runnable for higher-DPI re-export).
- **Out of scope:** New analysis or model runs; changing the PACTA/TRISK methodology; building a from-scratch deck; live BESS/energy-storage content (no backing data in repo); altering the reference original (read-only).

## Research Inputs
- `reports/2026-06-09-bank-prospect-deck-gap-analysis.md` — defines the nine gaps, their severity, reusable assets per gap, and the 4-sprint sequencing this plan's phases follow. Drives the phase split and the documented assumptions.
- `research/future_planning_ideas.md` — consulted for commercial-positioning direction; no constraints that override the gap report.

## Assumptions and Constraints
- **ASM-001:** "Case study/demo in this repo" = the synthetic **Vietnam-bank PACTA/TRISK demo** (loanbook → alignment → borrower stress) plus the **live Streamlit dashboard** — NOT the reference deck's BESS slides.
- **ASM-002:** "Similar to the reference deck" = same visual template/brand/layout system with a **re-authored prospect narrative**, not a refresh of the funder update.
- **ASM-003:** One prospect per build, parameterized at title/contact/positioning slides (default target chosen in Grill Me).
- **CON-001:** All repo data is **synthetic**; every case-study slide must carry an "illustrative / synthetic data" disclaimer (per `docs/demo-script.md`).
- **CON-002:** `present` edits a file **in place by shape index** and must **never overwrite the reference original** — always work on a copy and write to a distinct output path.
- **CON-003 (privacy):** Per repo `.gitignore`, generated per-borrower engagement letters and disclosure packs are not committed; do not embed borrower-identifying content from those artifacts in the deck.
- **DEC-001:** Template is 16:9 (10"×5.625"); shapes are Google-Slides-origin with grouped shapes and tables — edit text/picture-fills at existing positions only; do not restructure layouts.
- **DEC-002:** Toolchain is `python-pptx` + the `present` skill's `inspect_template.py` / `render_deck.py`; charts re-exported via existing R scripts in `scripts/`.

## Phase Summary
| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Working copy + template inventory + slide-by-slide narrative outline | None | `present/bank_prospect_deck.pptx` (copy), `present/deck_outline.md`, shape-index map |
| PHASE-02 | Produce slide-resolution visual assets (charts + dashboard screenshots) | PHASE-01 | `present/assets/*.png` |
| PHASE-03 | Build the deck via `present` (text swap, case-study repurpose, framing) + mandatory render QA | PHASE-01, PHASE-02 | Built `present/bank_prospect_deck.pptx`, `present/build_deck.py`, render PNGs |
| PHASE-04 | Polish: contacts, speaker notes, optional compliance slide, final QA | PHASE-03 | Final deck, speaker notes |
| PHASE-05 | Commit and push to `main` | PHASE-04 | Commit on `main`, pushed |

## Detailed Phases

### PHASE-01 - Foundation: working copy, inventory, and narrative outline
**Goal**
Create a safe editable copy, learn the exact shape contract, and lock a slide-by-slide prospect storyline mapped onto the reference's 25 slides. (Resolves GAP-01, GAP-02.)

**Tasks**
- [ ] TASK-01-01: Copy `present/ref/Allotrope GTB updates_Tara Vietnam_December 2025.pptx` → `present/bank_prospect_deck.pptx`. Leave the reference untouched.
- [ ] TASK-01-02: Run `python "<present_skill_dir>/scripts/inspect_template.py" "present/bank_prospect_deck.pptx"` and save the shape-index/geometry/text map (capture to `present/template_inventory.txt`).
- [ ] TASK-01-03: From the inventory, classify each slide's shapes: title/headline/body text boxes, old-content PICTUREs to replace, and decorative brand PICTUREs (logos/rails/backgrounds) to keep.
- [ ] TASK-01-04: Write `present/deck_outline.md` — a slide-by-slide plan: for each of the 25 reference slides, decide keep / repurpose / drop, and state the new headline + body + which asset fills each image slot. Target arc: cover → VN bank transition-risk + Decision 263 problem → PACTA (portfolio alignment) → TRISK (borrower stress) → Vietnam-bank case study/demo → engagement offer + 2026 roadmap → Q&A/contact.
- [ ] TASK-01-05: Mine narrative source text into the outline: executive summary + findings from `reports/2026-04-16-final-vietnam-bank-trisk-demo.html` and `reports/PACTA_Vietnam_Bank_Report.html`; problem framing from `docs/bidv_framework_comparison.md` + `docs/bidv_decision263_mapping.md`; value-prop/close bullets from `docs/demo-script.md`; offer/roadmap from reference slides 7/16 ("Proposed 2026 GTB Vietnam Activities").
- [ ] TASK-01-06: Flag every reference slide carrying internal-status language (slides ~4–6, 12–15, 18–19: "Waiting for a response from BIDV", scope-tracking) for rewrite or drop in the outline.

**Files / Surfaces**
- `present/ref/...December 2025.pptx` - source of truth for layout/brand (read-only).
- `present/bank_prospect_deck.pptx` - the new working copy.
- `present/template_inventory.txt`, `present/deck_outline.md` - phase outputs.
- `~/.claude/skills/present/scripts/inspect_template.py` - inventory tool.
- `reports/`, `docs/bidv_*.md`, `docs/demo-script.md` - narrative source material.

**Dependencies**
- None.

**Exit Criteria**
- [ ] `present/bank_prospect_deck.pptx` exists and opens via `python-pptx` without error; reference original byte-identical/untouched.
- [ ] `present/deck_outline.md` covers all 25 slides with a keep/repurpose/drop decision and named asset for each image slot.
- [ ] Every internal-status slide is explicitly marked for rewrite or drop.

**Phase Risks**
- **RISK-01-01:** Google-Slides-origin grouped shapes/tables may inventory oddly. Mitigation: rely on `inspect_template.py` indices; treat grouped shapes as units; do not restructure.

### PHASE-02 - Visual assets at slide resolution
**Goal**
Produce every PNG the outline calls for, crisp at slide scale on white/transparent backgrounds. (Resolves GAP-04, GAP-05.)

**Tasks**
- [ ] TASK-02-01: From `present/deck_outline.md`, list the exact charts needed and locate existing PNGs (`synthesis_output/vietnam/`, `dashboard/data/pacta/`, `dashboard/data/trisk/{power,cement,steel}/`).
- [ ] TASK-02-02: Audit each needed chart's resolution/aspect vs its destination shape box (from `present/template_inventory.txt`). Mark adequate vs needs re-export.
- [ ] TASK-02-03: Re-export sub-resolution charts at ≈220 DPI by re-running the originating R scripts in `scripts/` (do not hand-recreate plots); confirm white/transparent background matching the slide.
- [ ] TASK-02-04: Capture 2–3 high-res dashboard screenshots (PACTA Alignment, TRISK Risk, Scenario Builder). Run `streamlit run dashboard/app.py` (per `docs/demo-script.md`) and capture via the repo's `.playwright-mcp/` browser path or a headless screenshot; do not reuse stale root-level `phase6-*.png`.
- [ ] TASK-02-05: Stage all final assets in `present/assets/` with names matching the outline's slot references.

**Files / Surfaces**
- `synthesis_output/vietnam/*.png`, `dashboard/data/pacta/*.png`, `dashboard/data/trisk/*/*.png` - source charts.
- `scripts/*.R` - re-export at higher DPI.
- `dashboard/app.py`, `dashboard/pages/` - live app for screenshots.
- `present/assets/` - phase output folder.

**Dependencies**
- PHASE-01 (outline names which assets are needed and their destination boxes).

**Exit Criteria**
- [ ] Every image slot in `present/deck_outline.md` has a matching file in `present/assets/` at adequate resolution for its box.
- [ ] At least 3 fresh, legible dashboard screenshots exist on current data.

**Phase Risks**
- **RISK-02-01:** Streamlit cold-start / local run may fail. Mitigation: fallback to capturing the rendered HTML reports in `dashboard/data/reports/` as static evidence (per demo-script fallback).
- **RISK-02-02:** R re-export environment may not be configured. Mitigation: if a chart is already adequate resolution, keep as-is; only re-export the few that fail the audit.

### PHASE-03 - Build the deck via `present` + mandatory render QA
**Goal**
Edit the working copy in place at existing shape positions: swap text, replace image slots, repurpose the BESS case-study slides into the Vietnam-bank PACTA/TRISK case study, apply prospect framing + disclaimers, then render and visually QA. (Resolves GAP-03, GAP-06, core of the deck.)

**Tasks**
- [ ] TASK-03-01: Write `present/build_deck.py` (per `present` SKILL.md procedure): open the copy, use `set_text` (clears frame, zeroes margins, single run, `<a:buNone/>` to suppress inherited bullets) for text, and `delete_shape` + `add_picture` at original coordinates for images. Adapt helpers from the reference implementation `build_2026_from_ref.py` named in the skill — do not reinvent.
- [ ] TASK-03-02: Apply text edits per outline to all kept/repurposed slides (cover title, section headers, problem, PACTA, TRISK, offer/roadmap, Q&A). Scrub all internal-status language flagged in PHASE-01.
- [ ] TASK-03-03: Repurpose reference case-study slides 9–11 (Emivest BESS) into the PACTA/TRISK case study: place `synthesis_output/vietnam/13_vn_coal_stranded_risk.png`, `12_vn_alignment_overview.png`, `05_vn_power_techmix.png` and `dashboard/data/trisk/power/*` charts; repopulate the slide-11 five-box takeaway layout with PACTA/TRISK findings.
- [ ] TASK-03-04: Add a persistent "illustrative / synthetic data" disclaimer to every case-study/data slide.
- [ ] TASK-03-05: Apply the prospect-framing decision (Q-001): either convert BIDV/TCB status slides into a "track record" credibility slide or generalize them.
- [ ] TASK-03-06: Run `python "<present_skill_dir>/scripts/render_deck.py" "present/bank_prospect_deck.pptx"` and **Read every slide PNG**. Hunt for: 2-line headline overlap with charts below, text past right/bottom edges, stray/double bullets, dark backgrounds not fully covered by new panels.
- [ ] TASK-03-07: Fix overflow/collisions (reduce font size, nudge image y/height, widen box), rebuild, and re-render affected slides until clean.

**Files / Surfaces**
- `present/build_deck.py` - the build script (new).
- `present/bank_prospect_deck.pptx` - edited in place by the script.
- `present/assets/*.png` - assets placed into slots.
- `~/.claude/skills/present/scripts/render_deck.py` - QA renderer.
- `build_2026_from_ref.py` (dppa-case reference impl named in SKILL.md) - helper source to adapt.

**Dependencies**
- PHASE-01 (outline + inventory), PHASE-02 (assets).

**Exit Criteria**
- [ ] `present/build_deck.py` runs clean and writes the deck without overwriting the reference.
- [ ] Rendered PNGs of all slides reviewed; no overflow, collision, stray-bullet, or uncovered-dark-background defects remain.
- [ ] No BESS/energy-storage content and no internal-status phrasing remains; disclaimers present on data slides.

**Phase Risks**
- **RISK-03-01:** In-place text replacement overflows original boxes. Mitigation: the mandatory render-and-Read QA loop (TASK-03-06/07) is the definition of done, not a clean save.
- **RISK-03-02:** Accidentally deleting a decorative logo/rail PICTURE. Mitigation: only delete PICTUREs classified as old content in PHASE-01; re-inspect if behavior surprises.

### PHASE-04 - Polish and final QA
**Goal**
Finishing touches and a clean final render. (Resolves GAP-07, GAP-08, GAP-09.)

**Tasks**
- [ ] TASK-04-01: Update the contact/closing slide (reference slide 8) — replace "Tara" recipients with prospect-meeting-appropriate contacts.
- [ ] TASK-04-02: Add per-slide speaker notes drawn from `docs/demo-script.md` timings and bullets.
- [ ] TASK-04-03 (optional, per Q-002): Add a dedicated "compliance value" slide framing Decision 263 / TCFD / ISSB using `docs/bidv_decision263_mapping.md` and the structure of `output/disclosure/disclosure_pack.html` (do not embed borrower-identifying content — CON-003).
- [ ] TASK-04-04: Final full render via `render_deck.py`; Read all slides end-to-end for consistency (fonts, alignment, brand).

**Files / Surfaces**
- `present/bank_prospect_deck.pptx` - final edits.
- `docs/demo-script.md`, `docs/bidv_decision263_mapping.md`, `output/disclosure/disclosure_pack.html` - sources.

**Dependencies**
- PHASE-03.

**Exit Criteria**
- [ ] Contacts updated; speaker notes present on content slides.
- [ ] Final render reviewed end-to-end with no visual defects.

**Phase Risks**
- **RISK-04-01:** Speaker notes API differs for grouped/placeholder slides. Mitigation: use `slide.notes_slide.notes_text_frame`; skip notes on pure section-divider slides.

### PHASE-05 - Commit and push to main
**Goal**
Version the deck artifact and plan onto `main`.

**Tasks**
- [ ] TASK-05-01: Review `git status`; stage `present/bank_prospect_deck.pptx`, `present/build_deck.py`, `present/deck_outline.md`, `present/assets/`, this plan, and the gap report. Do NOT stage gitignored generated artifacts (`output/engagement_letters/*`, `output/disclosure/*` beyond what's tracked) or unrelated working-tree noise (`Rplots.pdf`, `*.log`, `__pycache__/`, `.playwright-mcp/`).
- [ ] TASK-05-02: Confirm the reference original `present/ref/...December 2025.pptx` shows no modification in the diff.
- [ ] TASK-05-03: Commit with a descriptive message (Co-Authored-By trailer per repo convention) and push to `main`.

**Files / Surfaces**
- Git working tree; remote `main`.

**Dependencies**
- PHASE-04.

**Exit Criteria**
- [ ] Commit lands on `main` and is pushed; `git status` clean of intended artifacts; reference original unchanged.

**Phase Risks**
- **RISK-05-01:** Large binary `.pptx` (~10 MB like the reference) bloats the repo. Mitigation: acceptable per existing repo practice (reference deck already committed); confirm no oversized stray asset is staged.
- **RISK-05-02:** Pushing directly to `main`. Mitigation: user explicitly requested push to `main`; ensure working tree contains only intended changes before committing.

## Verification Strategy
- **TEST-001:** `python "<present_skill_dir>/scripts/inspect_template.py" "present/bank_prospect_deck.pptx"` loads without error after build (round-trip check).
- **MANUAL-001:** Read every rendered slide PNG from `render_deck.py` after PHASE-03 and PHASE-04 — overflow/collision/bullet/background checks (the skill's mandatory QA).
- **MANUAL-002:** Side-by-side spot check of 3 slides against the reference render to confirm brand/layout fidelity.
- **OBS-001:** `git show --stat HEAD` post-push confirms only intended files changed and the reference original is absent from the diff.

## Risks and Alternatives
- **RISK-001:** Narrative genre mismatch (funder-update vs prospect-pitch) leads to leftover internal phrasing. Mitigation: PHASE-01 flag list + PHASE-03 scrub + final read.
- **RISK-002:** Synthetic results misread as the prospect's real portfolio. Mitigation: standing disclaimer (TASK-03-04) + verbal framing in speaker notes.
- **ALT-001:** Build a brand-new deck from scratch (`anthropic-skills:pptx`). Rejected — loses the reference deck's authentic brand/masters/logos, which is the explicit goal ("similar to the reference deck").
- **ALT-002:** Split into multiple separate plan files per gap. Rejected — the gaps form one coherent deliverable (a single deck) with tight sequential dependencies; one multi-phase plan is clearer and avoids cross-file coordination overhead.

## Grill Me
1. **Q-001:** Should the deck pitch a brand-new prospect, or extend/credentialize the existing BIDV/Techcombank relationship? (The reference names both as current collaborators.)
   - **Recommended default:** Treat BIDV/Techcombank work as a **track-record / credibility** section and frame the deck for a *new* prospect of the same profile (default target: a Vietnamese commercial bank; pick **Techcombank** as the named prospect).
   - **Why this matters:** Determines whether PHASE-03 converts the BIDV/TCB status slides into a "track record" slide or generalizes them, and how the cover/contact slides are worded.
   - **If answered differently:** If extending an existing relationship, keep bank-named slides as engagement-progress and reframe the offer as "next phase"; less scrubbing, different CTA.
2. **Q-002:** Include the optional dedicated Decision 263 / TCFD / ISSB "compliance value" slide (GAP-09)?
   - **Recommended default:** Yes — compliance pressure is the strongest "why now" for a VN bank.
   - **Why this matters:** Adds TASK-04-03 and one repurposed slide; pulls from `docs/bidv_decision263_mapping.md`.
   - **If answered differently:** Skip to keep the deck tighter; fold a one-line compliance mention into the problem slide instead.
3. **Q-003:** Target deck length?
   - **Recommended default:** ~12–15 slides (trim the reference's 25 by dropping redundant status/divider slides).
   - **Why this matters:** Drives how many reference slides are dropped in PHASE-01's outline.
   - **If answered differently:** Keep closer to 25 for a detailed leave-behind, or cut to ~8 for a tight pitch.

## Suggested Next Step
Answer the three Grill Me questions (especially Q-001 prospect framing), update `present/deck_outline.md` accordingly in PHASE-01, then execute phases in order. PHASE-05 performs the requested commit and push to `main`.

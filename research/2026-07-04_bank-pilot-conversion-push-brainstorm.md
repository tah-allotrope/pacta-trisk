---
title: "Bank Pilot Conversion Push"
date: "2026-07-04"
type: "brainstorm"
depth: "standard"
source_request: "Take the pacta-trisk project to the next level"
slug: "bank-pilot-conversion-push"
---

# Brainstorm: Bank Pilot Conversion Push

## Problem & Why Now
The platform (PACTA + TRISK for Vietnamese banks, synthetic MCB loanbook) is demo-complete: 7-page Streamlit dashboard, multisector TRISK, engagement/disclosure output layer, and a finished bank-prospect pitch deck. What's missing is everything that converts a demo into a **signed, paid real-data engagement**. The pilot itself will stay on synthetic data, so the next level is not more analytics — it is (a) a pilot experience a bank team can evaluate unsupervised, (b) concrete "your data here" conversion artifacts for the closing conversation, (c) an operated-not-hand-cranked impression (automated refresh, freshness badges), and (d) Vietnamese-language client documents. Doing this now means the platform is pilot-ready whenever a prospect conversation (BIDV/Techcombank-type) lands.

## Current vs Desired State
- **Current state:** R pipeline (`scripts/`) produces `synthesis_output/`, hand-copied into `dashboard/data/` for a fully public Streamlit Community Cloud app (no auth, no freshness metadata). Pitch deck done (`present/bank_prospect_deck.pptx`). All data synthetic; TRISK NPV/PD are demo stress indicators. Idea 2 from `research/future_planning_ideas.md` (refresh automation) is unbuilt. No evaluation guide, no data-spec sheet, no real-data phase proposal, no VN-language materials, no usage visibility. Repo has hygiene debt (stray root files, uncommitted snapshot churn).
- **Desired state:** A pilot package: guided-session script + reworked home-page evaluation tour + lightweight usage analytics; a conversion pack (loanbook data-spec sheet, real-data phase proposal template, polished Intake Wizard demo path) with `{{BANK_NAME}}` tailoring slots; `pipeline_refresh.R` orchestrator + `pipeline_manifest.json` + "Data as of" dashboard badge + GitHub Actions refresh workflow; bilingual EN/VN versions of the key client documents marked as reference translations.
- **Key repo surfaces:** `dashboard/app.py` (home tour), `dashboard/lib/` (badge, analytics, loaders), `dashboard/pages/6_Intake_Wizard.py`, `scripts/refresh_dashboard_data.R` and the TRISK/PACTA script chain (orchestrator wraps these), `.github/workflows/` (new), `templates/` + `reports/` (conversion pack, VN docs), `docs/PACTA_Beginner_Guide.md` and `dashboard/README.md` (disclaimers/copy).

## Resolved Decisions
- **DEC-001:** The goal of this push is winning a real bank pilot — prioritize whatever removes "this is just a demo" objections, not broader analytics or SaaS productization.
- **DEC-002:** The pilot itself runs on the synthetic MCB bank; real bank data enters only in the paid next phase.
- **DEC-003:** Success criterion = the bank signs a next-phase engagement for a real-data run; the pilot must let them picture their own book in the PACTA → TRISK → engagement workflow.
- **DEC-004:** Pilot shape = 2–3 guided walkthrough sessions plus ~2 weeks of open self-explore access for the bank team.
- **DEC-005:** Hosting stays fully public on Streamlit Community Cloud with no auth gate — synthetic data isn't sensitive and zero friction maximizes exploration.
- **DEC-006:** All four workstreams are in scope: conversion assets, self-explore readiness, pipeline automation (idea 2), and Vietnamese language.
- **DEC-007:** Vietnamese scope = bilingual key client documents (report pack, evaluation guide, data-spec sheet); the dashboard stays English.
- **DEC-008:** Automation goes all the way: `pipeline_refresh.R` orchestrator + `pipeline_manifest.json` + "Data as of" badge, plus a GitHub Actions workflow that reruns the pipeline and commits refreshed snapshots.
- **DEC-009:** Conversion assets are bank-agnostic with `{{BANK_NAME}}`-style tailoring slots and a tailoring checklist (customizable per prospect in under an hour).
- **DEC-010:** Rework the dashboard home page into a guided evaluation tour (ordered steps linking into each page) and add lightweight anonymous page-view analytics so engagement is visible before the closing conversation.
- **DEC-011:** No fixed deadline; ~4–6 week steady pace, sequenced by value: conversion assets → self-explore readiness → automation → bilingual documents.
- **DEC-012:** Vietnamese translations are AI-produced and explicitly labeled "bản dịch tham khảo" (reference translation); no human review pass is planned.
- **DEC-013:** (From repo grounding) Include a small hygiene phase: remove stray root files (`nul`, `Rplots.pdf`, root PNGs, cache dirs), commit or reconcile the dirty snapshot CSVs, and prune redundant deck variants — a bank-visible public repo should look tended.
- **DEC-014:** (From repo grounding) The self-explore copy pass must keep the README's methodology caveats visible in-app: TRISK NPV/PD are illustrative stress indicators, cement/steel are sector-level SDA, steel match coverage is low.

## Assumptions & Constraints
- **ASM-001:** The existing pitch deck and report generators are content-current enough to reuse; this push wraps them, it doesn't rebuild them.
- **ASM-002:** Streamlit Community Cloud remains adequate for pilot traffic and uptime during the open-access weeks.
- **ASM-003:** A VN-speaking reviewer is *not* in the loop (DEC-012); the "reference translation" label carries the quality disclaimer.
- **CON-001:** Everything shown to a bank must carry synthetic/illustrative-data disclaimers (all data is synthetic).
- **CON-002:** R package restore in GitHub Actions is slow; the CI workflow needs renv (or a rocker container) with aggressive caching to stay usable.
- **CON-003:** The app is public with no login, so analytics must be anonymous and PII-free.

## Approaches Considered
- **Chosen:** Pilot-conversion package on the existing synthetic platform — four workstreams (conversion assets, self-explore readiness, refresh automation with CI, bilingual documents) sequenced over 4–6 weeks.
- **ALT-001:** Production-harden first (automation/reproducibility as the headline) — rejected as the sole focus; it's included but subordinate to conversion, since reproducibility alone doesn't close a pilot.
- **ALT-002:** Broaden analytical coverage (borrower-level SDA for cement/steel, more sectors, real data sources) — deferred; methodology depth is not the current objection and real data belongs to the paid phase.
- **ALT-003:** Productize as multi-tenant SaaS (auth, workspaces, white-label) — premature before a single paying pilot exists.
- **ALT-004:** Self-service BYOL pilot with real bank uploads — rejected for the pilot; raises security/hosting stakes the synthetic evaluation doesn't need.

## Out of Scope
- Real bank data ingestion, per-bank isolation, and any auth/login work (DEC-005; real data is the *next* phase).
- Dashboard i18n / VN language toggle (documents only, DEC-007).
- New sectors or methodology upgrades (borrower-level SDA, VinFast sensitivity, etc.).
- Pricing/commercial terms inside the proposal template beyond scope-and-timeline placeholders.
- Paid hosting or custom domain migration.

## Open Questions
1. **Q-001:** Should the GitHub Actions refresh workflow commit regenerated snapshots directly to `main` (auto-deploying the public app), or open a PR for review?
   - **Recommended default:** Manual-dispatch + weekly schedule, committing directly to `main` — the data is synthetic and deterministic, and auto-deploy reinforces the "operated" impression.
   - **Why this matters:** Direct commits risk publishing a bad run to the live pilot app with no review gate.
2. **Q-002:** What mechanism for the anonymous page-view analytics — a tiny external collector (e.g., a serverless endpoint or hosted product like GoatCounter) vs. in-app logging to Streamlit Cloud logs?
   - **Recommended default:** A free hosted counter (GoatCounter-style) pinged from each page — Streamlit Cloud's own logs are ephemeral and awkward to aggregate.
   - **Why this matters:** Determines whether you can actually see engagement numbers before the closing conversation, and whether a third-party domain appears in the app's network traffic.

## Suggested Next Step
Run `/plan bank-pilot-conversion-push` to turn this into a multi-phase implementation plan.

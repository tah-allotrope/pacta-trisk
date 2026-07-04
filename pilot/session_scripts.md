# Guided Session Scripts

Three ~45-60 minute sessions covering the synthetic-data pilot, mapped to
dashboard pages and `present/bank_prospect_deck_v2.pptx` slides. Run these
live with the bank team, then leave the dashboard open for ~2 weeks of
self-guided exploration (public URL, no login required).

## Session 1 — PACTA Alignment story

**Deck:** slides 1-6 (context, methodology, PDP8/NDC/NZE framing).
**Dashboard:** home page tour steps 1-2, then **1 PACTA Alignment**.

1. Open the home page, walk through the five-step evaluation tour so the
   team knows what's coming across all three sessions.
2. Open **PACTA Alignment**. Show sector filters and the market-share vs.
   SDA alignment views. Narrate: "This tells us which loans are already
   pointed the right direction, and which ones are betting against the
   transition."
3. Pause on the misaligned borrowers — this is the hook for Session 2.

## Session 2 — TRISK transition-risk stress + Scenario Builder

**Deck:** slides 7-10 (TRISK methodology, stress mechanics, results).
**Dashboard:** **2 TRISK Risk**, **5 Scenario Builder**.

1. Open **TRISK Risk**, switch between power / cement / steel sectors.
   Narrate the NPV and PD deltas under the default shock scenario.
2. Move to **Scenario Builder**. Hand the controls to the bank's own risk
   analyst if possible — let them move shock year, discount rate, and
   carbon-price family themselves and watch borrower rankings shift live.
   This is the session's centerpiece; give it the most time.
3. Close with the caveats: TRISK NPV/PD figures here are illustrative
   stress indicators, cement/steel currently run sector-level SDA (not
   borrower-level), and steel's synthetic match coverage is low (~4%) — a
   real loanbook improves this materially (see `loanbook_data_spec.md`).

## Session 3 — Outputs, Intake, and the next step

**Deck:** slides 11-15 (engagement outputs, disclosure alignment, next steps).
**Dashboard:** **7 Outputs**, Intake Wizard demo (operator mode), **3 Reports** / **4 Methodology** for reference.

1. Open **Outputs**: engagement priority scoring, sample engagement letter,
   sample disclosure pack section (Decision 263 / TCFD framing).
2. Run the Intake Wizard demo per `intake_demo_script.md` — this answers
   "what would happen with our own loanbook?" concretely.
3. Point to **Reports** and **Methodology** as the take-home reference for
   their risk/ESG team to review independently during the open-access weeks.
4. Close with `real_data_phase_proposal.md`: walk through scope, timeline,
   and data-handling sections; confirm the anonymization approach the bank
   is comfortable with; agree on next steps and a decision date.

## After the sessions

- Share the public dashboard URL and `loanbook_data_spec.md` for the
  self-guided evaluation period (~2 weeks).
- Follow up mid-window to check in, using dashboard analytics (if
  `PILOT_ANALYTICS_ENDPOINT` is configured) to see which pages got explored.
- Close with a call to walk through `real_data_phase_proposal.md` sign-off.

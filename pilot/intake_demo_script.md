# Intake Wizard Demo Script

*Operator-only walkthrough — the Intake Wizard page is gated behind
`BYOL_INTAKE=1` and is not shown on the public dashboard. Run this locally
or on an operator-enabled instance during a guided session.*

## Setup

1. Set the environment variable before launching Streamlit:
   `BYOL_INTAKE=1 streamlit run dashboard/app.py` (or set it in your
   deployment's secrets/env config for a session-only enabled instance).
2. Navigate to **6 Intake Wizard** in the sidebar. Confirm the sidebar shows
   "Intake Wizard enabled (operator mode)".
3. Have `intake/templates/loanbook_template.csv` ready to upload — it
   contains four illustrative Vietnamese borrowers spanning power,
   automotive, cement, and steel.

## Click-path

1. **Upload:** click "Choose a loanbook file", select
   `intake/templates/loanbook_template.csv`. Confirm the success message
   shows the file name and byte size.
2. **Validate & Map:** click the "Validate & Map" button. Narrate while the
   spinner runs: "This is the same automated validator a real loanbook would
   go through — schema check, sector mapping, fuzzy matching against our
   borrower database, before any analysis touches the numbers."
3. **Validation Summary:** expand and point out total rows / passing rows /
   error rows. With the template file, all 4 rows should pass.
4. **Validation Errors:** should show "No validation errors detected." — if
   demonstrating error handling, use a modified copy of the template with a
   blank `counterparty_name` or an invalid `sector_code_system` to show the
   error table and downloadable `validation_errors.csv`.
5. **Match Preview:** expand to show fuzzy-matched borrower names against
   the synthetic ABCD database, color-coded by match score. Narrate: "Green
   rows matched automatically; yellow/red rows would be flagged for manual
   review before the loanbook is finalized."
6. **Normalized Loanbook Preview:** expand to show the mapped output —
   sector codes normalized, IDs assigned, diacritics normalized for
   matching. This is the file that would feed directly into the PACTA/TRISK
   pipeline.
7. **Downloads:** demonstrate the individual CSV downloads and the "full
   bundle (ZIP)" option — this is what a bank's risk team would receive
   back after submitting their own loanbook for validation.

## Talking points

- The wizard never writes uploaded data to the repository or the public
  dashboard — files are processed in a temporary path and deleted after the
  session (see `docs/intake_privacy.md`).
- The same validator (`scripts/intake_validate_and_map.R`) runs identically
  whether it's this demo template or a real bank's export — nothing special
  happens for the demo case.
- If a bank asks "what if our sector codes don't match your list?" — show
  the "not in scope" handling: unmapped sector codes are surfaced, not
  silently dropped.

## Known rough edges to narrate around

- Steel-sector fuzzy match coverage is low (~4%) in the synthetic ABCD
  database; a real loanbook with LEI/tax ID populated matches far better —
  mention this proactively rather than let a bank discover it.
- XLSX upload converts via the first sheet only; if a bank's export has a
  cover sheet before the data, ask them to have the data on the first tab.

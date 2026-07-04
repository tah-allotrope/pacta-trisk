# Tailoring Checklist

Customize the conversion pack for one named prospect in under an hour.

## 1. Fill the slots (~15 min)

In `real_data_phase_proposal.md`, replace:
- `{{BANK_NAME}}` — the prospect's name, consistently everywhere.
- `{{CONTACT_NAME}}` / `{{CONTACT_EMAIL}}` — your relationship owner.
- `{{DATE}}`, `{{DATE_1..4}}` — realistic milestone dates from kickoff.
- `{{ANONYMIZATION_APPROACH}}` — confirm with the bank's risk/ESG team
  whether pseudonymized names or hashed IDs are their preference (see
  `loanbook_data_spec.md` § Format and delivery).
- `{{SECTOR_LIST}}` — the sectors that matter for this bank's book (check
  their public loan portfolio breakdown or annual report if available;
  default to `power, cement, steel` if unknown).
- `{{SCENARIO_SELECTION}}` — leave as default unless the bank has stated a
  scenario preference (e.g., a specific PDP8 revision or NZE variant).
- `{{REPORT_LANGUAGE}}` — `English`, `Vietnamese`, or `Bilingual` per the
  audience (risk/ESG teams often prefer Vietnamese; see `vn/` translations).
- `{{DATA_RETENTION_PERIOD}}`, `{{ADDITIONAL_CONFIDENTIALITY_TERMS}}`,
  `{{PRICING_AND_TERMS_PLACEHOLDER}}` — fill from your standard engagement
  terms.

## 2. Sector-mix emphasis (~10 min)

Check whether this bank's portfolio is power-heavy, cement/steel-heavy, or
diversified. If known, reorder `session_scripts.md`'s Session 2 to lead with
the bank's dominant sector's TRISK results, and swap the corresponding
example borrower names in the deck (`present/bank_prospect_deck_v2.pptx`,
slide 6-8) for sector-appropriate framing language (do not fabricate the
bank's actual borrowers — keep MCB's synthetic names, just adjust narration).

## 3. Deck slide swaps (~15 min)

Open `present/bank_prospect_deck_v2.pptx`:
- Title slide and closing slide: replace the generic prospect placeholder
  with `{{BANK_NAME}}`.
- Confirm speaker notes reference the correct sector emphasis from step 2.
- Do not alter the MCB synthetic case data on the analysis slides — the deck
  demonstrates methodology, not the prospect's own numbers.

## 4. Regulatory framing check (~10 min)

If the bank is a joint-stock commercial bank subject to SBV Circular /
Decision 263 disclosure timelines, confirm `docs/bidv_decision263_mapping.md`
still reflects current guidance; note any bank-specific compliance context
in the proposal's § 5.

## 5. Final pass (~10 min)

- Search the tailored copies for any remaining `{{...}}` placeholder.
- Confirm every document still carries the synthetic-data disclaimer.
- Re-render to HTML (`pilot/rendered/`) if any content changed materially.

# BYOL Intake — Bring Your Own Loanbook

## Workflow Overview

1. **Bank prepares** a loanbook file using the provided template (`intake/templates/`)
2. **Operator receives** the file via secure channel (email, drive)
3. **Operator runs** the intake validation script or uploads via the dashboard intake wizard (gated behind `BYOL_INTAKE=1`)
4. **Validation report** surfaces errors, warnings, and match preview
5. **Normalized loanbook** is emitted in the 13-column schema consumed by the PACTA pipeline
6. **Operator feeds** `normalized_loanbook.csv` into `scripts/pacta_vietnam_scenario.R` for alignment analysis

## Directory Layout

```
intake/
├── README.md              # This file
├── SCHEMA.md              # Input/output column contract
├── .gitignore             # Safety net — blocks client CSV/XLSX
├── templates/             # Downloadable templates for the bank
│   ├── README_vi.md       # Vietnamese-language instructions
│   ├── loanbook_template.csv
│   └── loanbook_template.xlsx
└── output/                # Generated outputs (gitignored)
    ├── normalized_loanbook.csv
    ├── validation_errors.csv
    ├── match_preview.csv
    └── validation_summary.txt
```

## Security & Privacy

See `docs/intake_privacy.md` for the full privacy posture. Key rules:

- No raw client data is committed to git
- No raw counterparty names appear on the public dashboard
- The intake wizard runs behind `BYOL_INTAKE=1` env flag only
- Aggregated views only in dashboard output

## Anonymization

The `--anonymize` flag replaces counterparty names with stable pseudonyms
(`Counterparty 001`, `Counterparty 002`, ...) in the normalized loanbook and
match preview. A mapping file (`pseudonym_map.csv`) is written to the output
directory for operator reference but is gitignored and never committed.

```bash
Rscript scripts/intake_validate_and_map.R \
  --input data/fixtures/unseen_bank_loanbook.csv \
  --output-dir intake/output_rehearsal \
  --anonymize
```

**Note:** Pseudonym numbering is per-run. The map must be regenerated and
re-held per delivery; never reuse across extracts.

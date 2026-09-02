# PACTA + TRISK Vietnam — Status

> **As of:** 2026-09-02

Waves 0 through 4 are complete. The platform is at version 0.6.0: two
engagements (`mcb-demo`, `sdb-rehearsal`) run end to end through one
orchestrator (`scripts/run_engagement.R`), gated in CI by a byte-identity
check and twelve cross-artifact invariants (`tools/verify_refactor.R`).

Wave 4 ("Deliverable Trust, Provenance Truth, and Scale Follow-Through")
extended the acceptance gate from CSVs to the generated HTML deliverables —
before it, `classify_path()` ignored every `.html` file by construction, so all
71 tracked HTML artifacts had no regression protection. It also made the refresh
audit derive its paths from the engagement config (it had been attesting to a
scenario vintage the pipeline no longer used), marked filtered pipeline runs as
`partial`, removed the last hardcoded bank slug from an analytic, regenerated
the package export surface (33 → 55 exports), and vectorized the intake
validator (about 2.6×–3.2× faster at 50,000 loans).

`NEWS.md` is the authoritative, actively-maintained changelog — read it for what
shipped in each wave and phase. This file is intentionally a pointer, not a
duplicate.

The Wave 4 program is `plans/2026-09-01-wave4-deliverable-trust-and-scale-followthrough-plan.md`;
its per-phase checkboxes and "Execution notes" sections record what landed, what
deviated from the plan, and the one task (TASK-05-08, the full-chain scale
benchmark) that was deliberately not done and why. Check that file rather than
this one for the state of any in-progress work.

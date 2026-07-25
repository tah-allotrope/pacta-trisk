#!/usr/bin/env Rscript
# pipeline_refresh.R
# Compatibility wrapper (Wave 1 PHASE-05, orchestrator convergence).
#
# scripts/run_engagement.R is now the single orchestrator serving both the
# public MCB demo and every client engagement. This script delegates to it
# with engagements/mcb-demo/engagement_config.json, preserving the historical
# entry point and its default-mode byte-identical output -- required because
# .github/workflows/refresh.yml, tools/verify_refactor.R, README.md,
# CLAUDE.md, and AGENTS.md all invoke it by name (ASM-007).
#
# Usage: Rscript scripts/pipeline_refresh.R [--full]
#
# Default (no flag): the full 12-step mcb-demo engagement chain -- PACTA,
# TRISK prepare, all three sectors, scenario grid, prioritization, snapshot,
# engagement scoring, letters, disclosure, refresh audit. This is a superset
# of the prior 8-step default chain: PACTA, engagement scoring, letters, and
# disclosure previously ran only in --full mode (or not at all -- the public
# MCB refresh never exercised letters/disclosure before this convergence).
# Running them every refresh, not just --full, is intentional: it is the fix
# for A1 (the public demo previously never traveled the engagement code
# path run_engagement.R gives every other bank).
# With --full: additionally prepends data generation -- 13 steps total.
#
# Every flag this script receives (--full, --dry-run, or both) is forwarded
# unchanged to run_engagement.R -- true pass-through, not a reimplementation
# of run_engagement.R's flag parsing.
#
# system2("Rscript", ...) needs Rscript resolvable on PATH even when this
# script itself was invoked with a full path.

args <- commandArgs(trailingOnly = TRUE)

run_args <- c(
  "scripts/run_engagement.R",
  "--config", "engagements/mcb-demo/engagement_config.json",
  args
)

status <- system2("Rscript", args = run_args)
quit(status = status)

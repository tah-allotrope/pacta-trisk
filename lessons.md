# Lessons

Patterns discovered the hard way in this repo, and the rule that prevents
each one recurring. Reviewed at the start of every session per this
project's global workflow; updated after any correction worth generalizing.

## 1. Verify byte-identity with autocrlf-aware `git diff`, never raw `md5sum`

**What happened:** Early refactor-acceptance checks compared raw file
digests (`tools::md5sum()`) between runs. On Windows, `core.autocrlf`
normalizes line endings on checkout/diff but not on disk, so two files that
are byte-identical *after* normalization can show different raw digests —
producing false positives that looked like drift when there was none.

**Rule:** Always classify byte-identity via `git diff --name-only` (which
respects `core.autocrlf`), never via `tools::md5sum()` on the working-tree
files directly. `tools/verify_refactor.R` is the canonical implementation —
extend it rather than hand-rolling a new comparison.

## 2. `file.path(getwd(), ...)` double-join produces silently wrong absolute paths

**What happened:** A function that already received an absolute path
re-joined it with `getwd()` (e.g. `file.path(getwd(), already_absolute_path)`),
producing a path like `/repo/repo/data/x.csv` that doesn't exist — R doesn't
error on this, it just fails later with a confusing "file not found" far
from the actual bug.

**Rule:** Before calling `file.path(getwd(), x)`, check whether `x` might
already be absolute (or already resolved relative to the repo root by an
earlier `file.path(getwd(), ...)` call upstream). Path-building helpers
should document whether they expect a relative or absolute input, and
resolve it exactly once.

## 3. Caches must be keyed on their inputs, not only on their parameters

**What happened (Wave 1, C1):** The TRISK scenario grid's cache was keyed
on `scenario_id` alone — the five lever values — with zero dependency on
the underlying ABCD/scenario/financial-features data that actually produces
the numbers. When those inputs changed (a bug fix, a data refresh), the
grid kept silently serving three-month-old results because its cache key
never changed. This was not caught for months because every acceptance
check only asked "does this run match the last run?", never "does this
cached artifact still match its own inputs?".

**Rule:** Any cache keyed on parameters must ALSO be keyed on a fingerprint
of its inputs (see `grid_input_fingerprint()` / `grid_cache_is_valid()` in
`R/trisk_core.R` for the pattern: hash the input files, store the hash in
the cache's own metadata, invalidate the whole cache — not a partial merge
— on any mismatch). A cache with no input dependency is not a cache, it is
a permanent freeze that nobody decided to make permanent.

## 4. A golden test that reads committed artifacts guards the artifacts, not the code

**What happened (Wave 1, C3):** `tests/testthat/test_sdb_engagement.R`
read three committed files under `engagements/sdb-rehearsal/` and asserted
on their contents. This is a real test — it catches someone hand-editing
those files incorrectly — but it says nothing about whether
`scripts/run_engagement.R` still actually produces them. A regression in
the orchestrator that broke a second bank's engagement while leaving MCB's
untouched could ship silently forever, because nothing ever re-ran the
orchestrator to check.

**Rule:** A regression test for "does the code still produce the right
artifact" must actually run the code and regenerate the artifact, at least
some of the time (gated by an opt-in environment variable if it's slow —
see `RUN_SDB_ENGAGEMENT=1` — and wired into CI so "some of the time" means
"every push", not "whenever someone remembers"). A test that only reads
committed output is a fixture-content test, not a regression test, and
should be named and understood as such.

## 5. `jsonlite::toJSON()` round-trips an empty vector as an empty `list()`, not the original type

**What happened (Wave 1, PHASE-02 and again in PHASE-06):** Two different
optional config keys defaulted to an empty R-native container —
`inputs$raw_loanbook_csv = NULL` and `row_count_files = character(0)`.
Both were written to disk via `jsonlite::toJSON(..., auto_unbox = TRUE)`
as part of an engagement's *resolved* config (the copy
`scripts/run_engagement.R` writes after intake), then read back by every
downstream step via `jsonlite::read_json(..., simplifyVector = TRUE)`.
`NULL` serializes as `{}` and comes back as an empty named `list()`.
`character(0)` serializes as `[]` and *also* comes back as an empty
`list()`, not `character(0)`. Both defeated type checks written against the
original R-native shape (`is.null(x)`, `is.character(x)`), each time
inside a resolved-config code path that only fires for engagements using
intake — so it passed every direct test of the default config and broke
only when a real multi-step engagement ran.

**Rule:** Any validation check on an optional/empty config field must
accept `length(x) == 0` as "not configured," regardless of whether that
manifests as `NULL`, `character(0)`, or `list()` — never gate solely on
`is.null()` or `is.<type>()` for a field that can legitimately be empty.
When adding a new optional config key, write a test that specifically
round-trips it through `toJSON()` + `read_json()` (not just through
`load_engagement_config()` on a hand-written JSON file), because the bug
only appears on the *second* generation of a config, not the first.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`prcheck` is a single-file Bash tool (`bin/prcheck`) that lists open GitHub PRs genuinely needing the user's review — skipping PRs they've already fully reviewed with no new commits/files since. There is no build step, no test suite, and no source tree beyond the one script and the installer.

## Commands

- Run locally against the current repo: `./bin/prcheck`
- Run against another repo: `./bin/prcheck -r OWNER/REPO`
- See all flags: `./bin/prcheck --help`
- Debug the underlying data without the table renderer: `./bin/prcheck --json | jq .`
- Force-bust the local cache while iterating: `rm -rf /tmp/prcheck_cache` (TTL defaults to 8s; override with `PRCHECK_TTL`)
- Smoke-test the installer end to end: `bash install.sh` (downloads from GitHub `main`, so local edits are not exercised — run `./bin/prcheck` directly instead)

Runtime deps, enforced at startup: `gh` (authenticated with the `repo` scope) and `jq`. macOS install: `brew install gh jq`.

## Architecture

The whole pipeline lives in `bin/prcheck`. The flow is a single GraphQL round-trip, then all filtering/rendering in-process:

1. **Arg + env resolution.** Flags override `PRCHECK_DEFAULT_LABEL`, `GH_USER` auto-detect, and repo auto-detect from `gh`. Two internal booleans (`USER_SET`, `REPO_SET`) track whether a value came from the CLI vs. a default — matters for how auth caching and repo detection interact.
2. **Auth check, cached.** `gh auth status` is ~600ms, so its output is cached at `$XDG_CACHE_HOME/prcheck/gh_auth` (falls back to `~/.cache/prcheck`). The cache is only written on success *and* only if the `repo` scope is present, so a broken/incomplete auth state always forces a fresh check next run.
3. **GraphQL query.** One `gh api graphql` call fetches candidate PRs (filtered by search qualifiers: author, label, base branch, review-requested). The GraphQL response is cached at `/tmp/prcheck_cache/<key>.json` with a short TTL. **Important:** if you change the GraphQL shape, bump `CACHE_VERSION` in the script so stale caches are invalidated.
4. **jq filter (`$JQ_PROGRAM`).** Decides which PRs actually need review: never reviewed, new commits since your last review, or unviewed files. Emits one object per surviving PR with `title/url/author/type/status/updated`.
5. **Rendering.** `--json` prints the jq output directly. Default output emits TSV from jq, then a custom Bash table renderer draws fixed-width columns. **Do not replace this with `column` or `awk`-based rendering** — the title column embeds ANSI hyperlink escape codes (OSC 8) by default, and those bytes are invisible to the user but are counted by standard column tools, which misaligns the table. `truncate_to_var` and the width bookkeeping handle visible-width math manually for this reason.

Any change that touches the GraphQL selection set, the jq filter, or the column set in the TSV typically needs updates in all three places (GraphQL → jq → renderer), and a `CACHE_VERSION` bump.

## Distribution

`install.sh` curls `bin/prcheck` from the raw GitHub URL on `main`. There is no versioning or release tagging — merging to `main` ships to everyone running `install.sh` or re-running it to update. Be deliberate about what lands on `main`.

## Style notes specific to this repo

- Keep the tool a single self-contained script. No sourcing, no split modules.
- Comments in `bin/prcheck` are heavier than usual because a lot of decisions (cache invalidation rules, why rendering is hand-rolled, the `USER_SET`/`REPO_SET` flags) are non-obvious from the code alone. When you touch those areas, keep the "why" comment up to date or remove it if it no longer applies.
- Fail fast and loud on missing deps / bad auth — users run this from terminals and need actionable error messages pointing at the exact `brew install` or `gh auth refresh` command.

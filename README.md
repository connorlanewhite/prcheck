# prcheck

## Why this exists

If you look at the list of open PRs on GitHub, you can filter by a lot of things, but it's still quite challenging to find PRs that need your attention.

This script fixes that by showing only the PRs that genuinely need your review:
- PRs you've never reviewed
- PRs with new commits since your last review
- PRs with files you haven't viewed yet

## What it does

Queries GitHub's API to find open PRs and intelligently filters them based on your interaction history. For each PR, it checks whether you've reviewed it, whether new commits have landed since your last review, and whether you've viewed all the files. Only PRs that need your attention make it to the output table.

Run it from any GitHub repo; it'll auto-detect the repo and your username. Or point it at any repo you want with flags.

## Why a shell script

Because installing Node, Python, or Ruby just to check your PRs is silly. 

With that said, you do need:
- GitHub CLI (gh)
- jq
- jtbl

(All of which are available via Homebrew)

## Usage

Basic usage (auto-detects everything):
```bash
./prcheck.sh
```

Set a default label filter via environment variable:
```bash
export PRCHECK_DEFAULT_LABEL="needs-review"
./prcheck.sh
```

However, I like to put the script somewhere, `chmod` and alias it to run from any repo I like.

Common flags:
- `-r OWNER/REPO` — specify a different repo
- `-l LABEL` — filter by label
- `-L` — disable label filtering
- `-u USERNAME` — set your GitHub username explicitly
- `-n NUMBER` — max PRs to fetch (default: 50)
- `--include-review-requested` — also show PRs where you're tagged as a reviewer
- `--no-title-as-hyperlink` — show URL as a separate column instead of embedding it in the title

Run `./prcheck.sh --help` for the full list of options.

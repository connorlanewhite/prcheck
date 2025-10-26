# prcheck

<img width="700" alt="prcheck" src="https://github.com/user-attachments/assets/884dbfda-fa87-4882-8396-0a0f6d440e7d" />

## Why this exists

If you look at the list of open PRs on GitHub, you can filter by a lot of things, but it's still quite challenging to find PRs that need your attention.

This script fixes that by showing only the PRs that genuinely need your review:
- PRs you've never reviewed
- PRs with new commits since your last review
- PRs with files you haven't viewed yet

## What it does

Queries GitHub's API to find open PRs and intelligently filters them based on your interaction history. For each PR, it checks whether you've reviewed it, whether new commits have landed since your last review, and whether you've viewed all the files. Only PRs that need your attention make it to the output table.

Run it from any GitHub repo; it'll auto-detect the repo and your username. Or point it at any repo you want with flags.

## Limitations

Due to GitHub API pagination constraints, this tool has the following limitations:

- **File checking**: Only the first 100 files per PR are fetched. If a PR has more than 100 files, the "Unviewed Files" indicator may not be accurate.
- **Review history**: Only the first 50 most recent reviews per PR are checked. If a PR has more than 50 reviews and your review was earlier, it may be incorrectly flagged as "Never Reviewed".

For most PRs, these limits are sufficient. However, be aware of potential false positives on exceptionally large or heavily-reviewed PRs.

## Why a shell script

Because installing Node, Python, or Ruby just to check your PRs is silly. 

With that said, you do need:
- GitHub CLI (gh)
- jq
- jtbl

(All of which are available via Homebrew)

## Install

Install prcheck with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/connorlanewhite/prcheck/main/install.sh | bash
```

This will download and install prcheck to `~/.local/bin`. Make sure `~/.local/bin` is in your PATH.

Alternatively, you can manually download the script:

```bash
curl -o prcheck https://raw.githubusercontent.com/connorlanewhite/prcheck/main/bin/prcheck
chmod +x prcheck
mv prcheck ~/.local/bin/
```

Then install the dependencies:

```bash
brew install gh jq jtbl
```

## Usage

Basic usage (auto-detects everything):
```bash
./bin/prcheck
```

Set a default label filter via environment variable:
```bash
export PRCHECK_DEFAULT_LABEL="needs-review"
./bin/prcheck
```

Common flags:
- `-r OWNER/REPO` — specify a different repo
- `-l LABEL` — filter by label
- `-L` — disable label filtering
- `-u USERNAME` — set your GitHub username explicitly
- `-n NUMBER` — max PRs to fetch (default: 50)
- `--include-review-requested` — also show PRs where you're tagged as a reviewer
- `--no-title-as-hyperlink` — show URL as a separate column instead of embedding it in the title
- `--json` - output JSON instead of a table (also enables `--no-title-as-hyperlink`)

Run `./prcheck.sh --help` for the full list of options.

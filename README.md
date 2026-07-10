# prcheck

<img width="700" alt="prcheck" src="https://github.com/user-attachments/assets/fd12e620-a5bf-4a44-86ca-601b5ff3c3c1" />


## Why this exists

If you look at the list of open PRs on GitHub, you can filter by a lot of things, but it's still quite challenging to find PRs that need your attention.

This script fixes that by showing only the PRs that genuinely need your review:
- PRs you've never reviewed
- PRs with new commits since your last review
- PRs with files you haven't viewed yet

## What it does

Queries GitHub's API to find open PRs and intelligently filters them based on your interaction history. For each PR, it checks whether you've reviewed it, whether new commits have landed since your last review, and whether you've viewed all the files. Only PRs that need your attention make it to the output table.

By default, only PRs targeting the repository's default branch (e.g., `main` or `master`) are shown. PRs targeting other branches (like feature branches or release branches) are excluded unless you use the `--include-all-base-branches` flag.

Run it from any GitHub repo; it'll auto-detect the repo and your username. Or point it at any repo you want with flags.

## Status column colors

On truecolor terminals, the Status column is shaded so you can tell at a glance how much independent review a PR has already received — the greener it is, the safer it is to skip.

| Shade | Hex | When it appears |
| --- | --- | --- |
| Vibrant green | `#23c554` | You've approved it, or two or more others have approved with no outstanding feedback |
| Pale green | `#7ee787` | Exactly one other reviewer has approved, nothing else |
| Olive | `#a6b771` | Someone has approved, but there are unresolved comments |
| Yellow | `#e3b341` | Only comments, no approvals yet |
| Red | `#f85149` | Changes requested — even if some reviewers have also approved |
| Default | — | No reviews yet |

On 8-color terminals the shades collapse to the original scheme: any approval is green, comments are yellow, changes requested is red.

## Greptile confidence

Use `--greptile-confidence` to add Greptile's latest confidence score to the table. Set `PRCHECK_GREPTILE_CONFIDENCE=true` to enable the column by default.

| Score | Color |
| --- | --- |
| 5/5 | Vibrant green |
| 4/5 | Green |
| 3/5 | Olive |
| 2/5 | Yellow |
| 1/5 | Red |

The column displays `—` when Greptile has not reported a parseable score. JSON output includes the numeric score as `greptileConfidence`, or `null` when unavailable.

## Limitations

Due to GitHub API pagination constraints, this tool has the following limitations:

- **File checking**: Only the first 100 files per PR are fetched. If a PR has more than 100 files, the "Unviewed Files" indicator may not be accurate.
- **Review history**: Only the latest 50 reviews per PR are checked. If a PR has more than 50 reviews and your review was earlier, it may be incorrectly flagged as "Never Reviewed".
- **Greptile confidence**: Only the latest 20 timeline comments and latest 50 reviews are checked for a score. An older Greptile summary may display `—`.

For most PRs, these limits are sufficient. However, be aware of potential false positives on exceptionally large or heavily-reviewed PRs.

## Why a shell script

Because installing Node, Python, or Ruby just to check your PRs is silly. 

With that said, you do need:
- GitHub CLI (gh)
- jq

(Both available via Homebrew)

## Install

Install prcheck with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/connorlanewhite/prcheck/main/install.sh | bash
```

This will download and install prcheck to `~/.local/bin`. If prcheck is already installed, it will update to the latest version. Make sure `~/.local/bin` is in your PATH.

To install zsh tab completion at the same time:

```bash
curl -fsSL https://raw.githubusercontent.com/connorlanewhite/prcheck/main/install.sh | bash -s -- --with-zsh-completion
```

Alternatively, you can manually download the script:

```bash
curl -o prcheck https://raw.githubusercontent.com/connorlanewhite/prcheck/main/bin/prcheck
chmod +x prcheck
mv prcheck ~/.local/bin/
```

Then install the dependencies:

```bash
brew install gh jq
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
- `-a USER1,USER2` — include only PRs from the listed authors
- `-u USERNAME` — set your GitHub username explicitly
- `-n NUMBER` — max PRs to fetch (default: 50)
- `--no-approvals` — only show PRs without any approvals
- `--created-within DAYS` — only show PRs opened within the last number of days
- `--request-review` — request your review on each listed PR where it is not already requested
- `--include-team-review-requests` — include team-based review requests in addition to direct requests
- `--include-all-base-branches` — include PRs targeting any base branch (default: only default branch)
- `--greptile-confidence` — add Greptile's latest confidence score
- `--no-title-as-hyperlink` — show URL as a separate column instead of embedding it in the title
- `--json` — output JSON instead of a table

Zsh completion:
```bash
prcheck --install-zsh-completion
prcheck --uninstall-zsh-completion
mkdir -p ~/.local/share/zsh/site-functions
prcheck --completion zsh > ~/.local/share/zsh/site-functions/_prcheck
```

Run `prcheck --help` for the full list of options.

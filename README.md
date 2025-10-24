# prcheck
Simple bash script to list out the PRs to review on Github

Usage basics:
- Run inside a GitHub repo to auto-detect OWNER/REPO and your gh-authenticated username.
- Optionally set a default label via environment variable before running:
  export PRCHECK_DEFAULT_LABEL="My Label"
  If PRCHECK_DEFAULT_LABEL is unset, no label filter is applied by default (you can still pass -l or -L).

Flags:
- -r OWNER/REPO to specify repo
- -l LABEL to filter by label
- -L to disable label filtering
- -u USERNAME to set your GitHub username
- --no-title-as-hyperlink to show the URL as a separate column

#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = auth ]; then
  echo 'Token scopes: repo'
elif [ "$1" = api ] && [ "$2" = graphql ]; then
  if [ -n "${PRCHECK_FAIL_ONCE_FILE:-}" ] && [ ! -e "$PRCHECK_FAIL_ONCE_FILE" ]; then
    touch "$PRCHECK_FAIL_ONCE_FILE"
    exit 1
  fi
  jq -n '
    def pr($number; $title; $updated; $base; $head): {
      number: $number,
      state: "OPEN",
      title: $title,
      url: "https://example.test/\($number)",
      updatedAt: $updated,
      baseRefName: $base,
      headRefName: $head,
      repository: {defaultBranchRef: {name: "main"}},
      author: {login: "writer", name: "Writer"},
      commits: {nodes: []},
      reviews: {nodes: []},
      reviewRequests: {nodes: []},
      files: {nodes: [], pageInfo: {hasNextPage: false}}
    };
    {data: {
      primary: {nodes: [
        pr(3; "Linear 3"; "2026-01-10T00:00:00Z"; "linear-2"; "linear-3"),
        pr(6; "Fork B";   "2026-01-09T00:00:00Z"; "fork-root"; "fork-b"),
        pr(10; "Solo";    "2026-01-08T00:00:00Z"; "main"; "solo"),
        pr(13; "Example stack 2/2: follow-up"; "2026-01-08T00:00:00Z"; "merged-base"; "open-child"),
        pr(20; "Historical root"; "2026-01-06T00:00:00Z"; "main"; "historical-root"),
        pr(22; "Historical stack 2/2"; "2026-01-05T00:00:00Z"; "historical-root"; "historical-open"),
        pr(2; "Linear 2"; "2026-01-02T00:00:00Z"; "linear-hidden"; "linear-2"),
        (pr(8; "Hidden (1/8)"; "2026-01-02T00:00:00Z"; "linear-1"; "linear-hidden")
          | .reviews.nodes = [{author: {login: "reviewer", __typename: "User"}, state: "APPROVED", submittedAt: "2026-01-03T00:00:00Z"}]
          | .files.nodes = [{viewerViewedState: "VIEWED"}]),
        pr(5; "Fork A";   "2026-01-02T00:00:00Z"; "fork-root"; "fork-a"),
        pr(1; "Linear 1"; "2026-01-01T00:00:00Z"; "main"; "linear-1"),
        pr(4; "Fork root";"2026-01-01T00:00:00Z"; "main"; "fork-root")
      ]},
      reviewRequested: {nodes: []}, reviewedBy: {nodes: []},
      stackMembers: {nodes: [
        (pr(12; "Example stack 1/2: base"; "2026-01-07T00:00:00Z"; "main"; "merged-base") | .state = "MERGED"),
        (pr(21; "Historical stack 1/2"; "2026-01-04T00:00:00Z"; "historical-root"; "historical-merged") | .state = "MERGED")
      ]},
      greptilePrimary: {nodes: []}, greptileReviewRequested: {nodes: []},
      greptileReviewedBy: {nodes: []}
    }}
  '
else
  exit 1
fi
EOF
chmod +x "$tmpdir/gh"

run_prcheck() {
  PATH="$tmpdir:$PATH" PRCHECK_TTL=0 PRCHECK_AUTH_TTL=0 \
    "$repo_root/bin/prcheck" -r test/repo -u reviewer -L \
    --no-title-as-hyperlink "$@"
}

plain=$(run_prcheck)
stacks=$(run_prcheck --stack-mode)
stacks_with_greptile=$(run_prcheck --stack-mode --greptile-confidence)
json=$(run_prcheck --stack-mode --json)
retry=$(PRCHECK_FAIL_ONCE_FILE="$tmpdir/fail-once" run_prcheck --stack-mode 2>/dev/null)
historical_line=$(printf '%s\n' "$stacks" | grep -F "Historical stack 2/2")

[[ "$plain" != *"Stack"* ]]
[[ "$plain" != *"Example stack 1/2"* ]]
[[ "$stacks" == *"Stack"* ]]
[[ "$stacks" == *"│ Status"*"│ Review status"* ]]
[[ "$stacks" == *"Stack: Linear 1"*"4 PRs"*"1/4 approved by you"* ]]
[[ "$stacks" == *"Linear 1"*"0/8"*"Linear 2"*"2/8"*"Linear 3"*"3/8"* ]]
[[ "$stacks" == *$'\033[2m'"├─ Hidden (1/8)"* ]]
[[ "$stacks" == *$'\033[2m'"├─ Example stack 1/2: base"*"Example stack 2/2: follow-up"*"2/2"* ]]
[[ "$stacks" == *"Merged"* ]]
[[ "$stacks" == *"└─ Linear 3"* ]]
[[ "$stacks" == *"Fork root"*"fork"*"Fork A"*"fork"*"Fork B"*"fork"* ]]
[[ "$historical_line" != *"fork"* ]]
[[ "$stacks" == *"Solo"*"│ -"* ]]
[[ "$stacks" != *"—"* ]]
[[ "$stacks_with_greptile" == *"Stack"*"Greptile"* ]]
[[ "$json" != *"_stack"* ]]
[[ "$json" != *"Hidden"* ]]
[[ "$json" != *"Example stack 1/2"* ]]
[[ "$retry" == *"Example stack 2/2: follow-up"* ]]

echo "stack tests passed"

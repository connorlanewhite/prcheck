#!/usr/bin/env bash
set -euo pipefail

# End-to-end CLI coverage using a local fake of the GitHub CLI.

repo_root=$(cd "$(dirname "$0")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

fail() {
  echo "test failed: $1" >&2
  exit 1
}

assert_contains() {
  [[ "$1" == *"$2"* ]] || fail "expected output to contain: $2"
}

assert_not_contains() {
  [[ "$1" != *"$2"* ]] || fail "expected output not to contain: $2"
}

assert_file_contains() {
  grep -qF "$2" "$1" || fail "expected $1 to contain: $2"
}

assert_file_not_contains() {
  if grep -qF "$2" "$1"; then
    fail "expected $1 not to contain: $2"
  fi
}

cat > "$tmpdir/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = auth ]; then
  echo 'Token scopes: repo'
elif [ "$1" = api ] && [ "$2" = graphql ]; then
  if [[ "$*" == *"query BotThreads"* ]]; then
    [ "${PRCHECK_FAIL_BOT_FETCH:-false}" = true ] && exit 1
    ids=()
    for arg in "$@"; do
      case "$arg" in
        ids\[\]=*) ids+=("${arg#*=}");;
      esac
    done
    jq -n --args '
      def thread($resolved; $type): {
        isResolved: $resolved,
        comments: {nodes: [{author: {__typename: $type}}]}
      };
      def result($id): {
        id: $id,
        reviewThreads: {
          pageInfo: {hasNextPage: ($id == "PR_36")},
          nodes: (
            if $id == "PR_32" then [thread(true; "Bot")]
            elif $id == "PR_33" then [thread(false; "Bot")]
            elif $id == "PR_34" then [thread(false; "User")]
            elif $id == "PR_35" then [thread(false; "Bot")]
            else []
            end
          )
        }
      };
      {data: {nodes: [$ARGS.positional[] | result(.)]}}
    ' "${ids[@]}"
    exit 0
  fi
  if [ -n "${PRCHECK_FAIL_ONCE_FILE:-}" ] && [ ! -e "$PRCHECK_FAIL_ONCE_FILE" ]; then
    touch "$PRCHECK_FAIL_ONCE_FILE"
    exit 1
  fi
  jq -n '
    def pr($number; $title; $updated; $base; $head): {
      id: "PR_\($number)",
      number: $number,
      state: "OPEN",
      title: $title,
      url: "https://example.test/\($number)",
      updatedAt: $updated,
      baseRefName: $base,
      headRefName: $head,
      mergeable: "MERGEABLE",
      repository: {defaultBranchRef: {name: "main"}},
      author: {login: "writer", name: "Writer"},
      commits: {nodes: [{commit: {
        committedDate: "2025-01-01T00:00:00Z",
        statusCheckRollup: {state: "SUCCESS"}
      }}]},
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
        # Readiness filter fixtures.
        (pr(30; "Failing CI"; "2026-01-05T00:00:00Z"; "main"; "failing-ci")
          | .commits.nodes[-1].commit.statusCheckRollup.state = "FAILURE"),
        (pr(31; "Merge conflict"; "2026-01-05T00:00:00Z"; "main"; "merge-conflict")
          | .mergeable = "CONFLICTING"),
        # Bot-thread filter fixtures.
        pr(32; "Resolved bot thread"; "2026-01-05T00:00:00Z"; "main"; "resolved-bot"),
        pr(33; "Unresolved bot thread"; "2026-01-05T00:00:00Z"; "main"; "unresolved-bot"),
        pr(34; "Unresolved human thread"; "2026-01-05T00:00:00Z"; "main"; "unresolved-human"),
        pr(35; "Outdated unresolved bot thread"; "2026-01-05T00:00:00Z"; "main"; "outdated-bot"),
        pr(36; "More than 100 threads"; "2026-01-05T00:00:00Z"; "main"; "too-many-threads"),
        (pr(37; "Approved"; "2026-01-05T00:00:00Z"; "main"; "approved")
          | .reviews.nodes = [{author: {login: "approver", __typename: "User"}, state: "APPROVED", submittedAt: "2026-01-03T00:00:00Z"}]),
        (pr(38; "Approval re-requested"; "2026-01-05T00:00:00Z"; "main"; "approval-re-requested")
          | .reviews.nodes = [{author: {login: "approver", __typename: "User"}, state: "APPROVED", submittedAt: "2026-01-03T00:00:00Z"}]
          | .reviewRequests.nodes = [{requestedReviewer: {login: "approver"}}]),
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
elif [ "$1" = api ] && [ "$2" = -X ] && [ "$3" = POST ]; then
  [ -n "${PRCHECK_REQUEST_LOG:-}" ] && echo "$4" >> "$PRCHECK_REQUEST_LOG"
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

test_stack_rendering() {
  local plain stacks stacks_with_greptile json retry
  local historical_root historical_merged historical_open

  plain=$(run_prcheck)
  stacks=$(run_prcheck --stack-mode)
  stacks_with_greptile=$(run_prcheck --stack-mode --greptile-confidence)
  json=$(run_prcheck --stack-mode --json)
  retry=$(PRCHECK_FAIL_ONCE_FILE="$tmpdir/fail-once" run_prcheck --stack-mode 2>/dev/null)
  historical_root=$(printf '%s\n' "$stacks" | grep -F "├─ Historical root")
  historical_merged=$(printf '%s\n' "$stacks" | grep -F "Historical stack 1/2")
  historical_open=$(printf '%s\n' "$stacks" | grep -F "Historical stack 2/2")

  assert_not_contains "$plain" "Stack"
  assert_not_contains "$plain" "Example stack 1/2"
  assert_contains "$stacks" "Stack"
  [[ "$stacks" == *"│ Status"*"│ Review status"* ]] || fail "expected table headers"
  [[ "$stacks" == *"Stack: Linear 1"*"4 PRs"*"1/4 approved by you"* ]] || fail "expected Linear stack summary"
  [[ "$stacks" == *"Linear 1"*"0/8"*"Linear 2"*"2/8"*"Linear 3"*"3/8"* ]] || fail "expected anchored Linear stack order"
  assert_contains "$stacks" $'\033[2m'"├─ Hidden (1/8)"
  [[ "$stacks" == *$'\033[2m'"├─ Example stack 1/2: base"*"Example stack 2/2: follow-up"*"2/2"* ]] || fail "expected merged stack context"
  assert_contains "$stacks" "Merged"
  assert_contains "$stacks" "└─ Linear 3"
  [[ "$stacks" == *"Fork root"*"fork"*"Fork A"*"fork"*"Fork B"*"fork"* ]] || fail "expected forked stack"
  [[ "$historical_root" == *"Historical root"*"0/2"* ]] || fail "expected historical root position"
  [[ "$historical_merged" == *"Historical stack 1/2"*"1/2"* ]] || fail "expected historical merged position"
  [[ "$historical_open" == *"Historical stack 2/2"*"2/2"* ]] || fail "expected historical open position"
  assert_not_contains "$historical_open" "fork"
  [[ "$stacks" == *"Solo"*"│ -"* ]] || fail "expected non-stack marker"
  assert_not_contains "$stacks" "—"
  assert_contains "$stacks_with_greptile" "Greptile"
  assert_not_contains "$json" "_stack"
  assert_not_contains "$json" "Hidden"
  assert_not_contains "$json" "Example stack 1/2"
  assert_contains "$retry" "Example stack 2/2: follow-up"
}

test_readiness_filter() {
  local default_output ready_only include_unready
  default_output=$(run_prcheck)
  ready_only=$(run_prcheck --ready-only)
  include_unready=$(run_prcheck --include-unready)

  assert_not_contains "$default_output" "Failing CI"
  assert_not_contains "$default_output" "Merge conflict"
  assert_not_contains "$ready_only" "Failing CI"
  assert_not_contains "$ready_only" "Merge conflict"
  assert_contains "$ready_only" "Solo"
  assert_contains "$include_unready" "Failing CI"
  assert_contains "$include_unready" "Merge conflict"
}

test_approval_filter() {
  local output
  output=$(run_prcheck --no-approvals)

  assert_not_contains "$output" "│ Approved "
  assert_contains "$output" "Approval re-requested"
}

test_bot_thread_filter() {
  local default_output explicit_filter opt_out json request_log
  default_output=$(run_prcheck)
  explicit_filter=$(run_prcheck --all-bot-threads-resolved)
  opt_out=$(PRCHECK_FAIL_BOT_FETCH=true run_prcheck --include-bot-unresolved)
  json=$(run_prcheck --json)
  request_log="$tmpdir/requests"
  PRCHECK_REQUEST_LOG="$request_log" run_prcheck --request-review >/dev/null

  [[ "$explicit_filter" == "$default_output" ]] || fail "expected bot-thread filter to default on"
  assert_contains "$default_output" "Resolved bot thread"
  assert_contains "$default_output" "Unresolved human thread"
  assert_not_contains "$default_output" "Unresolved bot thread"
  assert_not_contains "$default_output" "Outdated unresolved bot thread"
  assert_not_contains "$default_output" "More than 100 threads"
  assert_contains "$opt_out" "Unresolved bot thread"
  assert_contains "$opt_out" "Outdated unresolved bot thread"
  assert_contains "$opt_out" "More than 100 threads"
  assert_contains "$json" "Resolved bot thread"
  assert_contains "$json" "Unresolved human thread"
  assert_not_contains "$json" "Unresolved bot thread"
  assert_not_contains "$json" '"_id"'
  assert_file_contains "$request_log" "/pulls/32/requested_reviewers"
  assert_file_contains "$request_log" "/pulls/34/requested_reviewers"
  assert_file_not_contains "$request_log" "/pulls/33/requested_reviewers"
  assert_file_not_contains "$request_log" "/pulls/35/requested_reviewers"
  assert_file_not_contains "$request_log" "/pulls/36/requested_reviewers"
}

test_stack_rendering
test_readiness_filter
test_approval_filter
test_bot_thread_filter
echo "prcheck tests passed"

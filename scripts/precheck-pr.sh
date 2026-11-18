#!/usr/bin/env bash
# Decides each fire of the pull-request schedule. Allows the run only when there
# is something to *do* — a draft to mark ready, a red check, a conflict, a
# review to answer, or a green pull request still to hand over. Waiting for a
# check or for the automated reviewer is not something to do, so those fires are
# declined.
#
# Exit 0 allows, exit 1 declines, anything else counts as broken and allows.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 2
. "$(dirname "$0")/lib/config.sh"

host="$(cfg host)"; [ -n "$host" ] && export GH_HOST="$host"
repo="$(cfg repo)"
reviewer="$(cfg reviewer)"
[ -n "$repo" ] && [ -n "$reviewer" ] || exit 1
prefix="$(cfg branch_prefix)"; prefix="${prefix:-updepbot/}"
bot="$(cfg auto_reviewer)"

if ! prs=$(gh pr list --repo "$repo" --state open --limit 100 \
  --json number,headRefName,isDraft,mergeable,reviewDecision,statusCheckRollup,reviewRequests,assignees 2>/dev/null); then
  exit 2
fi

if ! actionable=$(printf '%s' "$prs" | jq -r \
  --arg prefix "$prefix" \
  --arg bot "$bot" \
  --arg human "$reviewer" '
  def state: (.conclusion // .state // "") | ascii_upcase;
  def failing: any(.statusCheckRollup[]?; state | IN("FAILURE","ERROR","CANCELLED","TIMED_OUT","ACTION_REQUIRED","STARTUP_FAILURE"));
  def running: any(.statusCheckRollup[]?; (state == "") or ((.status // "") | ascii_upcase | IN("QUEUED","IN_PROGRESS","WAITING","PENDING")) or (state == "PENDING"));
  def requested($who): ($who != "") and any(.reviewRequests[]?; ((.login // .slug // "") == $who));
  def handedOver: requested($human) or any(.assignees[]?; .login == $human);

  [ .[]
    | select(.headRefName | startswith($prefix))
    | . as $pr
    | (if $pr.isDraft then "draft, not yet under review"
       elif ($pr | failing) then "a check is failing"
       elif $pr.mergeable == "CONFLICTING" then "conflicts with the base branch"
       elif $pr.reviewDecision == "CHANGES_REQUESTED" then "changes requested"
       elif $pr.reviewDecision == "APPROVED" and ($pr | running | not) and ($pr | handedOver | not) then "approved and green, ready to hand over"
       elif $pr.reviewDecision != "APPROVED" and ($pr | running | not) and ($pr | requested($bot) | not) then "nobody is reviewing it"
       else empty end) as $why
    | "PR #\($pr.number) \($pr.headRefName) — \($why)"
  ] | .[]'); then
  exit 2
fi

[ -n "$actionable" ] || exit 1

echo "Fix pull requests needing attention:"
printf '%s\n' "$actionable"
exit 0

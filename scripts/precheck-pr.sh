#!/usr/bin/env bash
# Decides each fire of the pull-request schedule. Allows the run only when
# there is something for the agent to *do* — a draft to mark ready, a red
# check, a conflict, a review to answer, or an approved pull request still to
# hand over. Waiting for a check to finish or for the automated reviewer to
# answer is not something to do, so those fires are declined.
#
# Exit 0 allows, exit 1 declines, anything else counts as broken and allows.
set -uo pipefail

settings="$HOME/settings.env"
[ -r "$settings" ] || exit 1
# shellcheck source=/dev/null
. "$settings"

: "${REPO:?}"
: "${HUMAN_REVIEWER:?}"
: "${FIX_BRANCH_PREFIX:=chore/cve-}"

prs=$(gh pr list --repo "$REPO" --state open --limit 50 \
  --json number,headRefName,isDraft,mergeable,reviewDecision,statusCheckRollup,reviewRequests,assignees \
  2>/dev/null)

# gh could not answer. A broken precheck allows the run rather than silencing
# the schedule for as long as the outage lasts.
[ -n "$prs" ] || exit 2

actionable=$(printf '%s' "$prs" | jq -r \
  --arg prefix "$FIX_BRANCH_PREFIX" \
  --arg bot "${AUTOMATED_REVIEWER:-}" \
  --arg human "$HUMAN_REVIEWER" '
  def state: (.conclusion // .state // "") | ascii_upcase;
  def failing: any(.statusCheckRollup[]?; state | IN("FAILURE","ERROR","CANCELLED","TIMED_OUT","ACTION_REQUIRED","STARTUP_FAILURE"));
  def running: any(.statusCheckRollup[]?; (state == "") or ((.status // "") | ascii_upcase | IN("QUEUED","IN_PROGRESS","WAITING","PENDING")) or (state == "PENDING"));
  def requested($who): ($who != "") and any(.reviewRequests[]?; (.login // .slug // "") == $who);
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
  ] | .[]')

[ -n "$actionable" ] || exit 1

echo "Fix pull requests needing attention:"
printf '%s\n' "$actionable"
exit 0

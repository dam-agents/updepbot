#!/usr/bin/env bash
# Decides each fire of the pull-request schedule. Allows the run only when there
# is something to *do* — a draft to mark ready, a red check, a conflict, a
# review to answer, or a green pull request still to hand over. Waiting for a
# check or for the reviewer to answer is not something to do, so those fires are
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

# A changes-requested review the agent already addressed is not work to do.
# The agent records the review id it answered in work/reviewed/<n>; a new review
# has a new id, so this also skips a repeated wake while the reviewer is away.
reviews='[]'
for n in $(printf '%s' "$prs" | jq -r --arg p "$prefix" \
  '.[] | select(.headRefName | startswith($p)) | select(.reviewDecision == "CHANGES_REQUESTED") | .number'); do
  if ! view=$(gh pr view "$n" --repo "$repo" --json reviews 2>/dev/null); then
    exit 2
  fi
  seen=""
  [ -r "$HOME/work/reviewed/$n" ] && seen="$(head -n 1 "$HOME/work/reviewed/$n")"
  if ! reviews=$(jq -nc --argjson acc "$reviews" --argjson v "$view" --argjson n "$n" --arg seen "$seen" '
    $acc + [{number: $n,
             id: ([$v.reviews[]? | select(.state == "CHANGES_REQUESTED") | .id] | last // ""),
             seen: $seen}]
  '); then
    exit 2
  fi
done

if ! actionable=$(printf '%s' "$prs" | jq -r \
  --arg prefix "$prefix" \
  --arg bot "$bot" \
  --arg human "$reviewer" \
  --argjson reviews "$reviews" '
  def state: (.conclusion // .state // "") | ascii_upcase;
  def failing: any(.statusCheckRollup[]?; state | IN("FAILURE","ERROR","CANCELLED","TIMED_OUT","ACTION_REQUIRED","STARTUP_FAILURE"));
  def running: any(.statusCheckRollup[]?; (state == "") or ((.status // "") | ascii_upcase | IN("QUEUED","IN_PROGRESS","WAITING","PENDING")) or (state == "PENDING"));
  def requested($who): ($who != "") and any(.reviewRequests[]?; ((.login // .slug // "") == $who));
  def handedOver: requested($human) or any(.assignees[]?; .login == $human);
  def changesOpen($n):
    any($reviews[]?; .number == $n and .id != .seen);

  [ .[]
    | select(.headRefName | startswith($prefix))
    | . as $pr
    | (if $pr.isDraft then "draft, not yet under review"
       elif ($pr | failing) then "a check is failing"
       elif $pr.mergeable == "CONFLICTING" then "conflicts with the base branch"
       elif $pr.reviewDecision == "CHANGES_REQUESTED" and changesOpen($pr.number) then "changes requested"
       elif $pr.reviewDecision == "CHANGES_REQUESTED" then empty
       elif $pr.reviewDecision == "APPROVED" and ($pr | running | not) and ($pr | handedOver | not) then "approved and green, ready to hand over"
       elif $pr.reviewDecision != "APPROVED" and ($pr | running | not) and ($pr | requested($bot) | not) and ($pr | handedOver | not) then "nobody is reviewing it"
       else empty end) as $why
    | "PR #\($pr.number) \($pr.headRefName) — \($why)"
  ] | .[]'); then
  exit 2
fi

[ -n "$actionable" ] || exit 1

echo "Fix pull requests needing attention:"
printf '%s\n' "$actionable"
exit 0

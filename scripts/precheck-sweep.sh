#!/usr/bin/env bash
# Decides each fire of the daily sweep, before any model is woken.
#
# Exit 0 allows the run, exit 1 declines it, anything else counts as broken and
# allows the run anyway. Whatever this prints on stdout is appended to the task
# prompt, so the turn does not re-derive what the cheap check just found.
set -uo pipefail

settings="$HOME/settings.env"
# Not onboarded yet: there is no repository to sweep. Schedules are held until
# onboarding completes anyway, so this only matters if the file is lost later.
[ -r "$settings" ] || exit 1
# shellcheck source=/dev/null
. "$settings"

: "${REPO:?}"
: "${FIX_BRANCH_PREFIX:=chore/cve-}"

# A fix pull request is still open from the last sweep. Sweeping again would
# fight it for the same lockfiles; the pull-request schedule owns it until it
# lands.
open_fix_prs=$(gh pr list --repo "$REPO" --state open --limit 50 \
  --json headRefName --jq "[.[] | select(.headRefName | startswith(\"$FIX_BRANCH_PREFIX\"))] | length" 2>/dev/null)
if [ "${open_fix_prs:-0}" -gt 0 ]; then
  exit 1
fi

alerts=$(gh api "repos/$REPO/dependabot/alerts?state=open&per_page=100" \
  --jq '.[] | "\(.security_advisory.severity)\t\(.dependency.package.ecosystem)\t\(.dependency.package.name)\t\(.security_advisory.cve_id // .security_advisory.ghsa_id)"' 2>/dev/null)
# GitHub could not answer. A broken precheck allows the run rather than
# silencing the sweep for as long as the outage lasts — an empty answer and a
# failed one look identical otherwise.
[ $? -eq 0 ] || exit 2

issues=""
if [ -n "${VULN_LABEL:-}" ]; then
  issues=$(gh issue list --repo "$REPO" --state open --label "$VULN_LABEL" --limit 50 \
    --json number,title --jq '.[] | "issue #\(.number)\t\(.title)"' 2>/dev/null)
fi

if [ -z "$alerts" ] && [ -z "$issues" ]; then
  exit 1
fi

echo "Open in $REPO as of this fire:"
[ -n "$alerts" ] && printf '%s\n' "$alerts"
[ -n "$issues" ] && printf '%s\n' "$issues"
exit 0

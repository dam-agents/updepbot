#!/usr/bin/env bash
# Decides each fire of the daily sweep, before any model is woken.
#
# Exit 0 allows the run, exit 1 declines it, anything else counts as broken and
# allows the run anyway. Whatever this prints on stdout is appended to the task
# prompt, so the turn does not re-derive what the cheap check just found.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 2
. "$(dirname "$0")/lib/config.sh"

host="$(cfg host)"; [ -n "$host" ] && export GH_HOST="$host"
repo="$(cfg repo)"
reviewer="$(cfg reviewer)"
[ -n "$repo" ] && [ -n "$reviewer" ] || exit 1
prefix="$(cfg branch_prefix)"; prefix="${prefix:-updepbot/}"

# A fix pull request is still open from the last sweep. Sweeping again would
# fight it for the same lockfiles; the pull-request schedule owns it until it
# lands.
if ! open=$(gh pr list --repo "$repo" --state open --limit 100 \
  --json headRefName,isCrossRepository 2>/dev/null \
  | jq -r --arg p "$prefix" '[.[] | select(.isCrossRepository == false) | select(.headRefName | startswith($p))] | length'); then
  exit 2
fi
[ "${open:-0}" -gt 0 ] && exit 1

# One page is enough to answer "is there anything at all?"; the run paginates
# when it needs the full list.
if ! alerts=$(gh api "repos/$repo/dependabot/alerts?state=open&per_page=100" \
  --jq '.[] | "\(.number)\t\(.security_advisory.severity)\t\(.dependency.package.ecosystem)\t\(.dependency.package.name)\t\(.dependency.manifest_path)\t\(.security_vulnerability.first_patched_version.identifier // "no fix")"' 2>/dev/null); then
  exit 2
fi

issues=""
label="$(cfg vuln_label)"
if [ -n "$label" ]; then
  if ! issues=$(gh issue list --repo "$repo" --state open --label "$label" --limit 100 \
    --json number,title,updatedAt --jq '.[] | "issue\t\(.number)\t\(.updatedAt)\t\(.title)"' 2>/dev/null); then
    exit 2
  fi
fi

if [ -z "$alerts" ] && [ -z "$issues" ]; then
  exit 1
fi

# The set the last completed sweep reported. An unchanged set — an alert with no
# fix, an unsupported ecosystem, a breaking-only fix left for the user — is not
# worth another turn. A new or changed alert is.
current="$( { printf '%s\n' "$alerts" | awk -F '\t' 'NF {print "alert\t"$1"\t"$6}'
              printf '%s\n' "$issues" | awk -F '\t' 'NF {print "issue\t"$2"\t"$3}' ; } | sort )"
last="$HOME/work/last-sweep.tsv"
if [ -s "$last" ] && [ "$current" = "$(cat "$last")" ]; then
  exit 1
fi
mkdir -p "$HOME/work"
printf '%s\n' "$current" > "$HOME/work/last-sweep.pending"

echo "Open in $repo as of this fire:"
[ -n "$alerts" ] && printf 'alert\tseverity\tecosystem\tpackage\tmanifest\tfixed\n%s\n' "$alerts"
[ -n "$issues" ] && printf '%s\n' "$issues"
exit 0

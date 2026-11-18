#!/usr/bin/env bash
# The shape check onboarding must pass. It judges what work/CONFIG.md says and
# what GitHub answers, never the data it found; every failure names its fix.
set -uo pipefail

. "$(dirname "$0")/lib/config.sh"

host="$(cfg host)"; [ -n "$host" ] && export GH_HOST="$host"
fail=0
need() {
  [ -n "$(cfg "$1")" ] || {
    echo "FAIL: $1 is missing — fix: write '- $1: <value>' to $CONFIG"
    fail=1
  }
}

need repo
need reviewer
need verify

case "$(cfg major)" in
  ''|report|migrate) ;;
  *) echo "FAIL: major must be report or migrate — fix: write '- major: report'"; fail=1 ;;
esac

repo="$(cfg repo)"
if [ -n "$repo" ]; then
  gh api "repos/$repo" --jq .full_name >/dev/null 2>&1 || {
    echo "FAIL: cannot read $repo — fix: grant the GitHub connection access to it"
    fail=1
  }
  gh api "repos/$repo/dependabot/alerts?state=open&per_page=1" >/dev/null 2>&1 || {
    echo "FAIL: cannot read the Dependabot alerts of $repo — fix: enable Dependabot alerts and grant the connection Dependabot alerts read (security_events for a token)"
    fail=1
  }
fi

[ -d "$HOME/work/repo/.git" ] || {
  echo "FAIL: $HOME/work/repo is not a checkout — fix: run 'gh repo clone <repo> \"$HOME/work/repo\"'"
  fail=1
}

[ -s "$HOME/work/repository.md" ] || {
  echo "FAIL: $HOME/work/repository.md is missing — fix: write what you learned about the repository (ONBOARDING.md step 4)"
  fail=1
}

[ "$fail" -eq 0 ] && echo PASS || exit 1

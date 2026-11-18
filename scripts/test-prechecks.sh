#!/usr/bin/env bash
# Offline fixtures for the two schedule gates. A fake `gh` stands in for GitHub;
# the config and the checkout are a throwaway HOME.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$ROOT"

mkdir -p "$TMP/home/work" "$TMP/bin"
cat > "$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
case "${1:-}" in
  pr)
    case "${2:-}" in
      list)
        [ "${FAKE_PR_EXIT:-0}" -eq 0 ] || exit "$FAKE_PR_EXIT"
        printf '%s' "${FAKE_PRS:-[]}" | jq -c 'map(. + {isCrossRepository: (.isCrossRepository // false)})'
        ;;
      view)
        if [ -n "${FAKE_PR_VIEW:-}" ]; then
          printf '%s\n' "$FAKE_PR_VIEW"
        else
          printf '%s\n' '{"headRefOid":"","reviews":[]}'
        fi
        ;;
      *) exit 1 ;;
    esac
    ;;
  api)
    [ "${FAKE_API_EXIT:-0}" -eq 0 ] || exit "$FAKE_API_EXIT"
    case " $* " in
      *" user "*) printf '%s\n' "${FAKE_USER:-}" ;;
      *) printf '%s\n' "${FAKE_ALERTS:-}" ;;
    esac
    ;;
  issue)
    printf '%s\n' "${FAKE_ISSUES:-}"
    ;;
  *)
    echo "stub: unsupported gh call: $*" >&2
    exit 1
    ;;
esac
STUB
chmod +x "$TMP/bin/gh"
export HOME="$TMP/home" PATH="$TMP/bin:$PATH"

write_config() {
  cat > "$HOME/work/CONFIG.md" <<CFG
- repo: acme/widgets
- reviewer: alice
- major: report
- verify: make check
${1:-}
CFG
}

failures=0
check() { # <name> <expected exit> <script> [expected stdout substring]
  local name="$1" want="$2" script="$3" want_out="${4:-}" out rc
  out="$(bash "scripts/$script" 2>&1)"; rc=$?
  if [ "$rc" != "$want" ]; then
    echo "FAIL $name: exit $rc, want $want"
    printf '%s\n' "$out"
    failures=$((failures + 1))
  elif [ -n "$want_out" ] && ! printf '%s' "$out" | grep -qF "$want_out"; then
    echo "FAIL $name: output does not contain $want_out"
    printf '%s\n' "$out"
    failures=$((failures + 1))
  else
    echo "ok $name"
  fi
}

write_config
FAKE_PRS='[]' FAKE_ALERTS='' FAKE_ISSUES='' check "sweep: quiet" 1 precheck-sweep.sh
FAKE_PRS='[]' FAKE_ALERTS="1	critical	npm	lodash	package-lock.json	4.17.21" check "sweep: alerts" 0 precheck-sweep.sh lodash
mkdir -p "$HOME/work" && printf 'alert\t1\t4.17.21\n' > "$HOME/work/last-sweep.tsv"
FAKE_PRS='[]' FAKE_ALERTS="1	critical	npm	lodash	package-lock.json	4.17.21" check "sweep: unchanged set" 1 precheck-sweep.sh
FAKE_PRS='[]' FAKE_ALERTS="1	critical	npm	lodash	package-lock.json	4.17.22" check "sweep: fixed version moved" 0 precheck-sweep.sh lodash
rm -f "$HOME/work/last-sweep.tsv"
write_config "- vuln_label: vulnerability"
FAKE_PRS='[]' FAKE_ALERTS='' FAKE_ISSUES="issue	1	2026-11-18T00:00:00Z	known vulnerability" check "sweep: labelled issue" 0 precheck-sweep.sh "known vulnerability"
FAKE_PRS='[{"headRefName":"updepbot/2026-11-18"}]' FAKE_ALERTS="1	critical	npm	lodash	package-lock.json	4.17.21" check "sweep: fix PR already open" 1 precheck-sweep.sh
FAKE_PRS='[{"headRefName":"updepbot/2026-11-18","isCrossRepository":true}]' FAKE_ALERTS="1	critical	npm	lodash	package-lock.json	4.17.21" check "sweep: fork PR is ignored" 0 precheck-sweep.sh lodash
FAKE_PRS='[]' FAKE_ALERTS='' FAKE_API_EXIT=1 check "sweep: GitHub fails open" 2 precheck-sweep.sh

rm -f "$HOME/work/CONFIG.md"
check "sweep: no config" 1 precheck-sweep.sh
check "pr: no config" 1 precheck-pr.sh
write_config
sed -i.bak '/^- reviewer:/d' "$HOME/work/CONFIG.md"
check "sweep: no reviewer" 1 precheck-sweep.sh
write_config

FAKE_PRS='[]' check "pr: no pull request" 1 precheck-pr.sh
FAKE_PRS='[{"number":9,"headRefName":"updepbot/x","isCrossRepository":true,"isDraft":false,"mergeable":"MERGEABLE","reviewDecision":"","statusCheckRollup":[{"conclusion":"FAILURE","status":"COMPLETED"}],"reviewRequests":[],"assignees":[]}]' check "pr: fork PR is ignored" 1 precheck-pr.sh
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":true,"mergeable":"MERGEABLE","reviewDecision":"","statusCheckRollup":[],"reviewRequests":[],"assignees":[]}]' check "pr: draft is left alone" 1 precheck-pr.sh
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"MERGEABLE","reviewDecision":"","updatedAt":"2026-11-18T00:00:00Z","statusCheckRollup":[{"conclusion":"FAILURE","status":"COMPLETED"}],"reviewRequests":[],"assignees":[]}]' check "pr: failing check" 0 precheck-pr.sh "failing"
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"MERGEABLE","reviewDecision":"","updatedAt":"2026-11-18T00:00:00Z","statusCheckRollup":[{"conclusion":"FAILURE","status":"COMPLETED","completedAt":"2026-11-17T23:00:00Z"}],"reviewRequests":[],"assignees":[]}]' PLATFORM_LAST_RUN_AT='2026-11-18T00:00:00Z' check "pr: failing check already seen" 1 precheck-pr.sh
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"MERGEABLE","reviewDecision":"","updatedAt":"2026-11-18T00:00:00Z","statusCheckRollup":[{"conclusion":"FAILURE","status":"COMPLETED","completedAt":"2026-11-18T00:01:00Z"}],"reviewRequests":[],"assignees":[]}]' PLATFORM_LAST_RUN_AT='2026-11-18T00:00:00Z' check "pr: failing check is new" 0 precheck-pr.sh "failing"
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"MERGEABLE","reviewDecision":"","statusCheckRollup":[{"conclusion":null,"status":"IN_PROGRESS"}],"reviewRequests":[],"assignees":[]}]' check "pr: only running" 1 precheck-pr.sh
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"MERGEABLE","reviewDecision":"APPROVED","statusCheckRollup":[{"conclusion":"SUCCESS","status":"COMPLETED"}],"reviewRequests":[],"assignees":[]}]' check "pr: approved and green" 0 precheck-pr.sh "hand over"
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"MERGEABLE","reviewDecision":"APPROVED","statusCheckRollup":[{"conclusion":"SUCCESS","status":"COMPLETED"}],"reviewRequests":[{"login":"alice"}],"assignees":[]}]' check "pr: already handed over" 1 precheck-pr.sh
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"MERGEABLE","reviewDecision":"REVIEW_REQUIRED","statusCheckRollup":[{"conclusion":"SUCCESS","status":"COMPLETED"}],"reviewRequests":[],"assignees":[{"login":"alice"}]}]' check "pr: handed over, not approved" 1 precheck-pr.sh
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"MERGEABLE","reviewDecision":"CHANGES_REQUESTED","statusCheckRollup":[{"conclusion":"SUCCESS","status":"COMPLETED"}],"reviewRequests":[],"assignees":[]}]' FAKE_PR_VIEW='{"reviews":[{"id":"rev1","state":"CHANGES_REQUESTED"}]}' check "pr: changes requested" 0 precheck-pr.sh "changes requested"
mkdir -p "$HOME/work/reviewed" && printf 'rev1\n' > "$HOME/work/reviewed/1"
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"MERGEABLE","reviewDecision":"CHANGES_REQUESTED","statusCheckRollup":[{"conclusion":"SUCCESS","status":"COMPLETED"}],"reviewRequests":[],"assignees":[]}]' FAKE_PR_VIEW='{"reviews":[{"id":"rev1","state":"CHANGES_REQUESTED"}]}' check "pr: changes requested already addressed" 1 precheck-pr.sh
printf 'old\n' > "$HOME/work/reviewed/1"
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"MERGEABLE","reviewDecision":"CHANGES_REQUESTED","statusCheckRollup":[{"conclusion":"SUCCESS","status":"COMPLETED"}],"reviewRequests":[],"assignees":[]}]' FAKE_PR_VIEW='{"reviews":[{"id":"rev2","state":"CHANGES_REQUESTED"}]}' check "pr: a new changes-requested review" 0 precheck-pr.sh "changes requested"
rm -rf "$HOME/work/reviewed"
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"CONFLICTING","reviewDecision":"","updatedAt":"2026-11-18T00:00:00Z","statusCheckRollup":[],"reviewRequests":[],"assignees":[]}]' check "pr: conflict" 0 precheck-pr.sh "conflicts"
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"CONFLICTING","reviewDecision":"","updatedAt":"2026-11-17T23:00:00Z","statusCheckRollup":[],"reviewRequests":[],"assignees":[]}]' PLATFORM_LAST_RUN_AT='2026-11-18T00:00:00Z' check "pr: conflict already seen" 1 precheck-pr.sh
FAKE_PRS='[{"number":1,"headRefName":"updepbot/x","isDraft":false,"mergeable":"CONFLICTING","reviewDecision":"","updatedAt":"2026-11-18T00:01:00Z","statusCheckRollup":[],"reviewRequests":[],"assignees":[]}]' PLATFORM_LAST_RUN_AT='2026-11-18T00:00:00Z' check "pr: conflict is new" 0 precheck-pr.sh "conflicts"
FAKE_PRS='[]' FAKE_PR_EXIT=1 check "pr: GitHub fails open" 2 precheck-pr.sh

mkdir -p "$HOME/work/repo/.git"
printf 'notes\n' > "$HOME/work/repository.md"
FAKE_USER=bot check "verify: valid shape" 0 verify-onboarding.sh PASS
FAKE_USER=alice check "verify: reviewer is the connection" 1 verify-onboarding.sh "reviewer is"
write_config "- auto_reviewer: bot
- auto_review_trigger: nonsense"
FAKE_USER=bot check "verify: bad review trigger" 1 verify-onboarding.sh "auto_review_trigger"
write_config

if [ "$failures" -ne 0 ]; then
  echo "$failures fixture(s) failed"
  exit 1
fi
echo "all precheck fixtures passed"

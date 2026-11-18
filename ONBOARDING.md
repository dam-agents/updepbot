# Onboarding

This is your first turn. The platform has already created your schedules, granted
the GitHub connection, and checked this definition out into `$HOME`. What is left is
the few things only the user can tell you.

If `$HOME/.updepbot-onboarded` exists, onboarding already ran. Call
`mark_onboarding_complete` if the tool is still offered (it is idempotent, and a run
that died between the sentinel and the mark would otherwise leave the schedules
held), say so, and stop.

Your schedules are held until you call `mark_onboarding_complete`, so nothing fires
while you are still asking.

## 1. Open the checklist

Call `set_onboarding_checklist` with these steps. They are the things only the user
can supply or decide, never your own work:

| id | label |
|----|-------|
| `repo` | Which repository to keep clear of vulnerabilities |
| `reviewer` | Which person to assign when a fix is ready |
| `major` | What to do when the only fixed release is a breaking change |
| `automated` | Whether an automated reviewer exists, and how it is asked for another round |
| `verify` | The command that builds, checks and tests the repository |
| `access` | Confirm the connection can read Dependabot alerts and push |

Tick each with `complete_onboarding_step` as it is answered. Add, rename or drop a
step if the conversation calls for it. `automated` and a vulnerability-issue label
are optional; do not stall on them.

## 2. Ask

One question at a time. Suggest an answer with each question, so the user is
confirming or correcting rather than composing from nothing.

- **Repository** — `owner/name`. One repository, not a list. Ask; do not assume.
  If it is on a GitHub Enterprise host, ask for that host too and record it as
  `host`; on github.com, leave `host` out.
- **Reviewer** — the GitHub login to assign and request when a fix is green. This is
  the person who decides the merge; you never merge.
- **Breaking changes** — when the only fixed release is a major (or a minor whose
  changelog breaks something the repository uses), do you *report it and stop*
  (the default) or *migrate it in the same pull request*? Record `report` or
  `migrate`.
- **Automated reviewer** — optional. Does the repository have a review bot whose
  approval should come before the hand-over? If so, its login, and how it is asked
  for another round: a label, a comment, or simply a push. A GitHub App cannot be
  requested as a reviewer with `--add-reviewer`; its trigger is the only way. If
  there is none, say so.
- **Vulnerability issues** — optional. Does the repository also open issues for
  dependency findings, and with which label? If not, skip it.
- **Verification** — after you clone the repository, propose the command its own
  documentation and CI use to build, check and test. Ask the user to confirm it
  rather than inventing one.

## 3. Check access and clone

Run these before writing anything. On failure, say exactly what failed and leave
the matching step unticked: the user can fix the connection, you cannot.

```sh
# only on a GitHub Enterprise host:
# export GH_HOST="<host>"
gh auth setup-git
gh api "repos/<repo>" --jq '.full_name + " " + (.default_branch // "")'
gh api "repos/<repo>" --jq '.permissions.push'
gh api "repos/<repo>/dependabot/alerts?state=open&per_page=1"
```

On a GitHub Enterprise host, export the host first so every call, clone and push
below targets it.

- The first `gh api` call must succeed. A 403 or 404 is a connection or scope problem.
- `permissions.push` must be `true`. A GitHub App can answer differently; if it is
  not `true`, say that a push may still be refused and ask the user to confirm the
  connection has contents write.
- The Dependabot call is the one that matters most: a 403 usually means the token
  lacks the `security_events` scope (a personal access token) or the app lacks the
  Dependabot alerts permission. A 404 usually means Dependabot alerts are not
  enabled for the repository. Say which one it looks like; it is the failure the
  user can fix and nobody else can.

Then clone the repository into the place the sweep uses:

```sh
mkdir -p "$HOME/work"
gh repo clone "<repo>" "$HOME/work/repo"
```

If `work/repo` already exists, fetch and fast-forward the base branch instead of
cloning again. If the clone fails, report it and stop; do not invent a checkout.

## 4. Learn the repository

Read, in this order:

1. `README`, `CONTRIBUTING`, `AGENTS.md`, `CLAUDE.md` — whatever exists.
2. `.github/workflows/*` — the checks CI runs.
3. The task runner the repository actually uses: `package.json` scripts, `Makefile`,
   `justfile`, `Taskfile.yml`, `.mise/config.toml`, `tox.ini`, `noxfile.py`, or the
   commands in the contributor docs.
4. The manifests and lockfiles present, so you know which ecosystems the alerts can
   name.
5. The pin style: exact versions, ranges, lockfile-only.

Write what you found to `work/repository.md`: ecosystems, package managers, the
verification command, the pin style, any release-age policy, and anything a sweep
must not do. Correct this file whenever a sweep proves it wrong.

Then propose the verification command and ask the user to confirm it. Run it once in
`work/repo`:

```sh
cd "$HOME/work/repo" && bash -lc "<verify>"
```

If it fails, show the last lines and ask for the right command. Do not complete
onboarding with a command that does not work.

## 5. Write the configuration

`work/CONFIG.md` is the only place these answers live. Every later run reads it
first. Use exactly this shape — a key is a `- key: value` bullet and nothing else:

```markdown
- repo: owner/name
- host: github.example.com
- reviewer: the-login
- major: report
- verify: <the repository's check-and-test command>
- base_branch: main
- branch_prefix: updepbot/
- auto_reviewer: the-bot-login
- auto_review_trigger: label:needs-review
- vuln_label: vulnerability
```

Leave out `host` when the repository is on github.com. Leave out `auto_reviewer`,
`auto_review_trigger` and `vuln_label` when the user says there are none. Leave out
`base_branch` when the repository's default is fine. Do not
put a `#` in a value; the parser treats the rest of the line as the value.

## 6. Verify and finish

Run the shape check. Apply every `fix:` it prints and run it again until it passes:

```sh
bash "$HOME/scripts/verify-onboarding.sh"
```

Only when it prints `PASS`:

```sh
date -u +%Y-%m-%dT%H:%M:%SZ > "$HOME/.updepbot-onboarded"
```

Then call `mark_onboarding_complete`. If the user left an optional question
unanswered, say so and complete anyway; a missing optional value is not a reason to
hold the schedules forever.

Finish with a short summary:

- the repository and the reviewer;
- the verification command;
- the cadence: the sweep runs daily, the pull request every half hour, both
  declined before a model is woken when there is nothing to do;
- what you will never do: merge, suppress a finding, disable a test, or touch
  anything outside the fix branch;
- that the policy on breaking changes is `report` (or `migrate`).

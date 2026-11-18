# UpDepBot

A DAM [starter kit](https://github.com/dam-agents/dam/blob/main/docs/architecture/starter-kits.md):
an agent that keeps one repository's known vulnerabilities from piling up.

Every day it asks GitHub what Dependabot has open against the repository, fixes every
advisory that has a released fix — in npm, Python, Go and Rust, whichever the
repository actually uses — verifies against the repository's own checks, and opens
**one** pull request. Then it stays with that pull request: reads the failing checks,
answers the review, resolves conflicts, and hands it to a reviewer you named once it
is green.

It never merges, never suppresses a finding, and never disables a test to get a bump
through. An advisory with no released fix, one in an ecosystem the first version has
no recipe for, or one whose only fix is a breaking change you did not authorise, is
reported back to you rather than worked around.

A quiet repository costs nothing: both schedules carry a precheck that asks GitHub
the cheap question first and declines the fire when there is nothing to do.

## What is in here

| | |
|---|---|
| `kit.yaml` | the kit the catalog offers — connection, schedules, prechecks, bundled skills |
| `ONBOARDING.md` | the first turn: what the agent asks you, and what it does with the answers |
| `CLAUDE.md` | the agent's operating manual and its boundaries |
| `AGENTS.md` | a pointer to `CLAUDE.md`, for any harness |
| `.agents/skills/updep-sweep` | collect, fix, verify, open the pull request |
| `.agents/skills/pr-to-green` | drive that pull request until it is ready for a person |
| `scripts/precheck-*.sh` | the checks that decide each scheduled fire |
| `scripts/verify-onboarding.sh` | the shape check onboarding must pass |

Runtime state lives in `work/`, which is never tracked: `work/CONFIG.md` is the
onboarding answer, `work/repo/` the maintained checkout, `work/repository.md` what
the agent learned about building and testing it, and `work/reviewed/<n>` the
changes-requested review the agent last answered on a pull request.

## Setting it up

Pick **UpDepBot** in the starter kit catalog, connect GitHub, and answer the agent's
first message. It asks for the repository, the reviewer, what it may do about a
breaking change, and which command builds and tests the repository.

The GitHub connection needs:

- **contents: write** — to push the fix branch;
- **pull requests: write** — to open the pull request and request the reviewer;
- **Dependabot alerts: read** — `security_events` for a personal access token, the
  Dependabot alerts permission for a GitHub App;
- **checks: read, actions: read** — to read a failing check and its log.

A repository that pulls from a private package registry needs an egress rule for that
host, which the agent's owner adds after create.

**The repository must be public** for the curated catalog to read this kit and seed
the definition. A private definition can be used only through a private catalog on a
GitHub Enterprise host, with that install's own credential.

## The limits of the first version

- It fixes npm, Python, Go and Rust. Alerts in other ecosystems are reported, not
  guessed at.
- It reads Dependabot alerts and, if you name a label, open issues with that label.
  It does not run a scanner of its own, and it does not fix findings in code you
  wrote.
- One pull request per sweep, so the fixes share a review and their lockfiles never
  fight each other.
- It hands the pull request to a person and stops. Merging is theirs.

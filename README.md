# UpDepBot

A DAM [starter kit](https://github.com/dam-agents/dam/blob/main/docs/architecture/starter-kits.md):
an agent that keeps one repository's known vulnerabilities from piling up.

Every day it asks GitHub what Dependabot has open against the repository, fixes every
advisory that has a released fix — in whichever of the ecosystems Dependabot alerts
cover the repository uses: npm, Python, Go, Rust, Maven or Gradle, NuGet, Bundler,
Composer, Hex, pub, Swift, or GitHub Actions — verifies against the repository's own
checks, and opens **one** pull request. Then it stays with that pull request: reads
the failing checks, answers the review, resolves conflicts, and hands it to a
reviewer you named once it is green.

It never merges, never suppresses a finding, and never disables a test to get a bump
through. An advisory with no released fix, one no recipe can place, or one whose only
fix is a breaking change you did not authorise, is reported back to you rather than
worked around.

A quiet repository costs nothing: both schedules carry a precheck that asks GitHub
the cheap question first and declines the fire when there is nothing to do. The sweep
records the set it last reported, so an unfixable alert is not reported every day.
The pull-request loop declines a failure it has already seen.

## What is in here

| | |
|---|---|
| `kit.yaml` | the kit the catalog offers — connection, schedules, prechecks, bundled skills |
| `ONBOARDING.md` | the first turn: what the agent asks you, and what it does with the answers |
| `CLAUDE.md` | the agent's operating manual and its boundaries |
| `AGENTS.md` | a pointer to `CLAUDE.md`, for any harness |
| `.agents/skills/updep-sweep` | collect, fix, verify, open the pull request; one recipe per ecosystem under `references/` |
| `.agents/skills/pr-to-green` | drive that pull request until it is ready for a person |
| `scripts/precheck-*.sh` | the checks that decide each scheduled fire |
| `scripts/verify-onboarding.sh` | the shape check onboarding must pass |

Runtime state lives in `work/`, which is never tracked: `work/CONFIG.md` is the
onboarding answer, `work/repo/` the maintained checkout, `work/repository.md` what
the agent learned about building and testing it, `work/last-sweep.tsv` the set the
last sweep reported, and `work/reviewed/<n>` the changes-requested review the agent
last answered on a pull request.

## Setting it up

Pick **UpDepBot** in the starter kit catalog, connect GitHub, and answer the agent's
first message. It asks for the repository, the reviewer, what it may do about a
breaking change, and which command builds and tests the repository. The apply form
shows both schedules; change their cadence or skip one there. Onboarding does not
ask for cadence.

The GitHub connection needs:

- **contents: write** — to push the fix branch;
- **pull requests: write** — to open the pull request and assign or request the
  reviewer;
- **Dependabot alerts: read** — `security_events` for a personal access token, the
  Dependabot alerts permission for a GitHub App;
- **checks: read, actions: read** — to read a failing check and its log;
- **workflows: write** — only when a fix touches `.github/workflows/` (or the
  `workflow` scope on a classic token); without it GitHub refuses the push and the
  agent reports the Actions alert back to you instead of failing the sweep.

You can name the connection's own account as the reviewer. GitHub will not request a
review from a pull request's author, so the agent assigns the pull request to that
account and skips the review request; for anyone else it requests the review and
assigns.

A repository that pulls from a private package registry needs an egress rule for that
host, which the agent's owner adds after create.

The curated catalog reads this kit anonymously from public GitHub, so the
repository is public. A fork must be public too, or reached through a private
catalog on a GitHub Enterprise host.

## The limits of the first version

- It has a recipe for every ecosystem Dependabot alerts cover, one file per
  ecosystem. An alert no recipe can place is reported, not guessed at.
- It reads Dependabot alerts and, if you name a label, open issues with that label.
  It does not run a scanner of its own, and it does not fix findings in code you
  wrote.
- One pull request per sweep, so the fixes share a review and their lockfiles never
  fight each other. New alerts that arrive while that pull request is open wait for
  the next sweep after it lands.
- It ignores pull requests from forks: only a branch in the repository itself is
  its own.
- It hands the pull request to a person and stops. Merging is theirs.

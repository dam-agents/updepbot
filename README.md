# UpDepBot

A DAM [starter kit](https://github.com/dam-agents/dam/blob/main/docs/architecture/starter-kits.md):
an agent that keeps one repository's known vulnerabilities from piling up.

Every day it asks GitHub what is open against the repository, fixes every advisory
that has a released fix — in whichever ecosystems the repository actually uses —
verifies against the repository's own checks, and opens **one** pull request. Then it
stays with that pull request: reads the failing checks, answers the review, rebases
on conflicts, and hands it to a reviewer you named once it is green.

It never merges, never suppresses a finding, and never disables a test to get a bump
through. An advisory with no released fix, or one whose only fix is a breaking change
you did not authorise, is reported back to you rather than worked around.

A quiet repository costs nothing: both schedules carry a precheck that asks GitHub
the cheap question first and declines the fire when there is nothing to do.

## What is in here

| | |
|---|---|
| `kit.yaml` | the kit the catalog offers — connections, schedules, prechecks, size |
| `ONBOARDING.md` | the first turn: what the agent asks you, and what it does with the answers |
| `CLAUDE.md` | the agent's operating manual and its boundaries |
| `.claude/skills/cve-sweep` | collect, fix, verify, open the pull request |
| `.claude/skills/pr-to-green` | drive that pull request until it is ready for a person |
| `scripts/precheck-*.sh` | the checks that decide each scheduled fire |

## Setting it up

Pick **UpDepBot** in the starter kit catalog, connect GitHub, optionally bind a
Slack channel, and answer the agent's first message. It asks for the repository, the
reviewer, and what it may do about a breaking change.

The GitHub connection needs to be able to read the repository's security alerts and
open pull requests on it. A repository that pulls from a private package registry
needs an egress rule for that host, which the agent's owner adds.

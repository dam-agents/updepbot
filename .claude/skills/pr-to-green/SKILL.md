---
name: pr-to-green
description: >
  Drive an open pull request until its checks pass and its review is resolved,
  then assign the human reviewer. Works in any repository, with or without an
  automated reviewer. TRIGGER on "take the PR to green", "babysit this PR",
  "why is the PR red", or a scheduled fire of the pull-request schedule.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Agent
---

# Take a pull request to green

One pass per fire. Do not loop inside a single run waiting for a check that takes an
hour — finish what you can, and the next fire picks it up. That is what the schedule
is for.

## Each pass

1. **Read the state**, for every open pull request on the fix branch:

   ```sh
   gh pr view <n> --repo "$REPO" --json number,headRefName,isDraft,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,comments,reviews
   ```

2. **Mark it ready** if it is still a draft. On a repository with an automated
   reviewer, that is usually what summons it.

3. **Fix everything that is red**, in this order:
   - **Failing checks.** Read the failing job's log (`gh run view <id> --log-failed`),
     fix the cause, push. A check that fails for a reason your change did not cause —
     a flake, an unrelated broken job on the base branch — is reported, not worked
     around. Never disable a check to make a pull request green.
   - **Review comments**, automated and human alike. Address every one: change the
     code, or reply saying why not. An automated reviewer is usually right and
     occasionally wrong; disagreeing in a reply is a legitimate resolution, silence
     is not.
   - **Conflicts.** Rebase on the base branch, force-push, and wait for the checks
     again. A rebase that is not trivial gets the review re-requested afterwards.

4. **Re-request the review** once you have pushed fixes:

   ```sh
   gh pr edit <n> --repo "$REPO" --add-reviewer "$AUTOMATED_REVIEWER"
   ```

   Prefer re-requesting over any "review everything again" trigger the repository
   offers: a re-request reviews the new diff, which is both faster and cheaper.
   `settings.md` names the automated reviewer, or says the repository has none — in
   which case this step is skipped and green checks alone are the bar.

5. **Do not re-run a run that a push already superseded.** `gh run rerun` is only for
   a run whose `headSha` is still `HEAD`; re-running a superseded one cancels the
   fresh run that replaced it.

## When it is green

Green checks, review resolved, no conflicts. Then:

```sh
gh pr edit <n> --repo "$REPO" --add-reviewer "$HUMAN_REVIEWER" --add-assignee "$HUMAN_REVIEWER"
```

`$HUMAN_REVIEWER` is the handle the user gave at onboarding. Say so in the channel,
with the pull request link and a one-line summary of what it fixes.

**Never merge.** Merging is the reviewer's, always — including when the repository
would let you, and including when the change is trivial. The user asked for a
proposal, not a deploy.

## When it will not go green

After three passes on the same failure, stop pushing at it and report: the pull
request link, the check that fails, the log line that says why, and what you tried.
A stuck pull request the user knows about is worth more than a fourth identical fix.

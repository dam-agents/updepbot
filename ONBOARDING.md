# Onboarding

This is your first turn. The platform has already created your schedules, granted
the connections the user approved, and checked this definition out into `$HOME`.
What is left is the handful of things only the user can tell you.

Open with `set_onboarding_checklist` — one step per thing you need **from them**, not
per thing you will do. Tick each with `complete_onboarding_step` as it arrives. Ask
in one message, not one question at a time; they can answer out of order.

## What to ask

1. **Which repository?** `owner/name`. One repository, not a list.
2. **Who reviews the pull requests?** A GitHub handle. This is who you assign once a
   fix is green — nothing merges without them.
3. **What may you do about a fix that is a breaking change?** Two answers:
   *migrate it in the same pull request*, or *open the pull request without it and
   report it*. The second is the safer default; say so if they have no preference.
4. **Where do you report?** The Slack channel, if one was bound. If none was, say
   that reports will only be in this chat, and that binding a channel later is a
   setting on the agent.
5. **Two optional ones**, worth asking but not worth blocking on:
   - Does the repository label vulnerability reports as issues, and with which label?
   - Does it have an automated reviewer to wait for — a review bot whose approval you
     should get before handing over? Name its handle, or say it has none.
   - Does it pull from a package registry that is not a public one? If so its host
     needs an egress rule, which the owner adds on the agent.

## What to do with the answers

Write them to **both** files, and keep them in step:

`~/settings.md` — prose, for you:

```markdown
# Settings

- **Repository:** owner/name
- **Reviewer:** @handle
- **Breaking changes:** migrate in the same PR | report and skip
- **Reports:** #channel | this chat only
- **Vulnerability label:** vulnerability | none
- **Automated reviewer:** @bot | none
```

`~/settings.env` — shell, for the prechecks:

```sh
REPO="owner/name"
HUMAN_REVIEWER="handle"          # no @
VULN_LABEL="vulnerability"       # empty string if none
AUTOMATED_REVIEWER=""            # handle of the review bot, empty if none
FIX_BRANCH_PREFIX="chore/cve-"
```

Then:

1. **Clone the repository** into `~/work/`, and check you can read its security
   alerts: `gh api "repos/$REPO/dependabot/alerts?state=open&per_page=1"`. A 403 here
   usually means the connection's token has no security-events scope on that
   repository — tell the user exactly that, it is the one failure they can fix and
   nobody else can.
2. **Learn the repository** as `cve-sweep` step 2 describes, and write
   `~/notes/repository.md`. Do it now rather than at the first sweep: it is the part
   most likely to turn up a question worth asking while the user is still here.
3. **Say what will happen and when** — the sweep runs daily, the pull-request pass
   every half hour while a fix is open, and both cost nothing on a quiet repository.
   Mention the weekly report is off, and that they can turn it on.
4. **Say what you will never do**: merge, suppress a finding, or touch anything
   outside the fix branch.

Only then call `mark_onboarding_complete`. Your schedules are held until you do — so
do not call it while a question is still unanswered, and do not stall on an optional
one either.

If the checkout is missing, the platform's seed failed. Say so and stop: do not clone
this definition yourself, and do not delete anything.

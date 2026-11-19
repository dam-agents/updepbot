# GitHub Actions

Verified 2026-11-19: in a throwaway git repository, a workflow's
`step-security/harden-runner` reference moved from `@v2.15.1` to `@v2.16.0`, and a
SHA pin of the same action with its `# v2.15.1` comment moved to the `v2.16.0` SHA
with the comment updated; `actionlint` passed before and after.

## Find it

The alert names the action (`owner/repo`) and the workflow file
(`.github/workflows/<file>.yml`). The alert's `fixed` is the release version
without a `v`; the tag is whatever the repository publishes.

```sh
grep -rn '<owner>/<repo>@' .github/workflows/
```

That shows the current ref: a tag (`@v1.2.3`), a major tag (`@v1`) or a commit SHA
(`@<40 hex>`). GitHub raises an alert only for a reference that names a semantic
version, so the alerted file has a tag; other workflows may still pin the same
action by SHA, and every reference of it moves to the fixed release so the
repository does not run two versions.

## Move it

Keep each reference's shape. A tag stays a tag:

```sh
# @v2.15.1 -> the patched tag
sed -i 's|<owner>/<repo>@v2.15.1|<owner>/<repo>@v2.16.0|' .github/workflows/<file>.yml
```

A major tag stays a major tag. `@v2` already resolves to the newest v2, so it
admits the fix and there is nothing to edit: report that the ref already allows
`fixed`. If `fixed` is a new major and the repository pins `@v1`, moving to `@v2`
is a breaking change — follow `major` (`report` hands it back).

A SHA stays a SHA, with its comment. Resolve the tag to a commit, following an
annotated tag:

```sh
ref=$(gh api "repos/<owner>/<repo>/git/ref/tags/<tag>")
sha=$(jq -r '.object.sha' <<<"$ref")
[ "$(jq -r '.object.type' <<<"$ref")" = tag ] \
  && sha=$(gh api "repos/<owner>/<repo>/git/tags/$sha" --jq .object.sha)
sed -i "s|<owner>/<repo>@[0-9a-f]\{40\}\( *# *v\?[0-9][^ ]*\)\?|<owner>/<repo>@$sha # <tag>|" \
  .github/workflows/<file>.yml
```

Check the file's own comment style (`# v2.16.0` or `# v2.16.0 <link>`); keep it.

If the repository already uses `pinact` (a `.pinact.yaml`, or `pinact` in CI), run
it instead of editing: `pinact run`. Do not introduce pinact into a repository
that does not use it.

## Regenerate the lockfile

There is none; the workflow file is the record. Commit only the workflow files the
alerts name.

## Pin style

Tag stays tag, major tag stays major tag, SHA stays SHA. If the patched release is
a new major and the repository pins `@v1`, moving to `@v<new major>` is the same
style, and it follows the `major` policy like any other breaking fix.

## Verify

The new ref exists (`gh api repos/<owner>/<repo>/git/ref/tags/<tag>` succeeds),
the workflow parses (`actionlint`, or the repository's own workflow lint such as
`zizmor`), and the repository's `verify` command if it checks the workflows.

## Toolchain

Nothing to install. `actionlint` is not shipped: `mise use -g actionlint` if the
repository already lints workflows.

## The push needs Workflows permission

Pushing a change under `.github/workflows/` needs more than contents write: the
fine-grained token or GitHub App needs **Workflows: write**, and a classic token
needs the `workflow` scope. Without it the push is refused:

```text
! [remote rejected] ... refusing to allow a Personal Access Token to create or
update workflow `.github/workflows/ci.yml` without `workflow` scope
```

A GitHub App gets the same `refusing to allow a GitHub App to create or update
workflow …` refusal. Match only `refusing to allow .* workflow`: a 403 without that
message is a missing contents write, which is a different problem and must not cost
the commit. Do not retry, and do not move the change out of the workflow file:

1. the sweep commits the Actions fix last, so drop it with `git reset --hard
   HEAD~1`;
2. in the pull-request body, remove that row from **What** and add the alert to
   **Handed back** as "needs your decision: the connection needs Workflows write to
   change `.github/workflows/`";
3. push the remaining commits. If there are none — the Actions fix was the only
   one — open no pull request and report the hand-back in chat instead.

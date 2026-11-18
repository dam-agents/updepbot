---
name: updep-sweep
description: >
  Sweep one repository's open Dependabot alerts, fix every advisory that has a
  released fix in npm, Python, Go or Rust, verify with the repository's own
  checks, and open one pull request. Repository-agnostic: detects the package
  manager, lockfile, task runner and pinning style instead of assuming any of
  them. Use on the daily sweep fire, or when asked to fix dependency
  vulnerabilities.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - WebFetch
  - WebSearch
---

# Sweep the vulnerabilities

You maintain **one** repository, the one named by `repo` in `work/CONFIG.md`. Work in
`work/repo`. Read the config first; if it is missing, or `reviewer` is empty, say
onboarding has not finished and stop.

Nothing below assumes a task runner, a package manager or a pinning policy. Detect
them from the repository in front of you.

Set what the rest of this skill uses, once:

```sh
. "$HOME/scripts/lib/config.sh"
host="$(cfg host)"; [ -n "$host" ] && export GH_HOST="$host"
REPO="$(cfg repo)"
BASE="$(cfg base_branch)"
PREFIX="$(cfg branch_prefix)"; PREFIX="${PREFIX:-updepbot/}"
VERIFY="$(cfg verify)"
VULN_LABEL="$(cfg vuln_label)"
```

## 1. Collect what is open

The precheck's list is a hint, and it reads one page. Always fetch the full
paginated list before you plan:

```sh
gh api --paginate "repos/$REPO/dependabot/alerts?state=open&per_page=100" \
  --jq '.[] | {number, severity: .security_advisory.severity,
                ghsa: .security_advisory.ghsa_id, cve: .security_advisory.cve_id,
                ecosystem: .dependency.package.ecosystem,
                package: .dependency.package.name,
                manifest: .dependency.manifest_path,
                vulnerable: .security_vulnerability.vulnerable_version_range,
                fixed: (.security_vulnerability.first_patched_version.identifier // null)}'
```

When `vuln_label` in `work/CONFIG.md` names a label, the repository also opens issues
for dependency findings. Read them too:

```sh
gh issue list --repo "$REPO" --state open --label "$VULN_LABEL" --limit 100 \
  --json number,title,body,url
```

Do not read code-scanning alerts and do not run a scanner: findings in code the team
wrote are out of scope. If an issue turns out to be about code, report it; do not
fix it.

If both sources are empty, say so in one line and stop. Nothing is opened.

## 2. Prepare the checkout

```sh
git -C "$HOME/work/repo" status --porcelain
```

A non-empty answer is someone else's work: report it and stop; never discard it.
Then:

```sh
gh auth setup-git                 # idempotent; routes git through the connection
git -C "$HOME/work/repo" fetch origin
BASE="${BASE:-$(gh api "repos/$REPO" --jq .default_branch)}"
git -C "$HOME/work/repo" switch "$BASE"
git -C "$HOME/work/repo" pull --ff-only
```

If `base_branch` is in the config, use it instead of the default. If more than one
GitHub account is granted, the platform's `platform-github` skill says how to
switch to the one that reaches this repository.

Create a branch under `branch_prefix` (default `updepbot/`):

```sh
branch="${PREFIX}$(date -u +%Y-%m-%d-%H%M)"
git -C "$HOME/work/repo" switch -c "$branch"
```

## 3. Learn the repository before changing it

Do this every sweep, not once: a repository grows ecosystems.

- **The manifest is authoritative.** Each alert names `dependency.manifest_path`.
  Fix that manifest and its lockfile, not a lookalike elsewhere.
- **Which package manager owns it.** Read the lockfile and the contributor docs. For
  npm, `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lock*` → bun,
  `package-lock.json` → npm. For Python, `uv.lock` → uv, `poetry.lock` → poetry,
  `Pipfile.lock` → pipenv, `pip-compile` output → pip-tools, otherwise the
  `requirements*.txt` or `pyproject.toml` bound. For Go, `go.mod` + `go.sum`. For
  Rust, `Cargo.toml` + `Cargo.lock`.
- **How the repository builds and tests.** Read its contributor docs, its CI
  workflows and its task definitions, in that order, and use the commands they use.
  If it drives everything through a task runner, drive everything through that task
  runner too.
- **Whether the toolchain is installed.** The image ships Node with `aube` (also as
  `pnpm`), Python with `uv`, and `mise`. Go and Rust are not shipped; install them
  with `mise use -g go@<version>` / `mise use -g rust@<version>`, taking the
  version the repository pins (`go.mod` `toolchain`, `rust-toolchain.toml`,
  `.node-version`, `.python-version`, `mise.toml`). The image's `pnpm` is `aube`;
  when `packageManager` names a pnpm version, run that version
  (`mise use -g pnpm@<version>` or `npx pnpm@<version>`). A missing Yarn or Bun is
  installed the same way (`aube add -g yarn`, or `mise`). The trusted egress covers
  the public toolchain hosts; a host it does not cover is reported, not waited on
  from an unattended fire.
- **How it pins.** Exact stays exact; a range stays a range; a lockfile is
  regenerated with its own tool, never hand-edited.
- **Whether it has a minimum release age.** If the policy documents a security
  exception, take it for this fix and say so in the pull request. If it does not,
  a fixed release younger than the floor is reported and retried next sweep. Check
  the release date at the registry (`npm view <pkg> time.<version>`, the PyPI JSON,
  `go list -m -json <module>@<version>`, crates.io) or in the changelog.

Write what you learn into `work/repository.md`, and correct it when it turns out to
be wrong.

## 4. Plan, then fix

Fix every alert that has a released fix and an ecosystem recipe. Do not ask which
ones. Use the **lowest released version that clears the advisory**: `fixed` from the
alert, unless the repository already resolves higher.

A fix is a **breaking change** when the major version moves, or, for a `0.x`
dependency, the minor version moves. Read the changelog when unsure. What to do is
the `major` policy in `work/CONFIG.md`:

- `report` (the default): leave it alone and hand it back.
- `migrate`: read every changelog entry from the current version to the fixed one,
  check each breaking change against the repository's code, migrate, and verify. A
  migration that needs a product decision is reported, not guessed.

Recipes, one per supported ecosystem. Run them at the manifest's directory, or with
the workspace flag the tool uses.

**npm** — pnpm, yarn, bun or npm, whichever lockfile is present.

```sh
pnpm add --save-exact <pkg>@<fixed>        # exact pin; drop --save-exact for a range
yarn up <pkg>@<fixed>                      # check the manifest; Yarn 1: yarn upgrade
npm install --save-exact <pkg>@<fixed>     # exact pin; `@^<fixed>` keeps a caret
bun add --exact <pkg>@<fixed>
```

The tool may change the pin style. Check the manifest diff and correct it, then
re-lock. Add `--workspace <path>` or the tool's workspace flag when the manifest is
one.

In a workspace, target the package that owns the manifest: `pnpm --filter <name>
update <pkg>@<fixed>`, `yarn workspace <name> up <pkg>@<fixed>`, or `npm install
--workspace <path> <pkg>@<fixed>`. Do not update the root by accident.

A transitive package: `pnpm why <pkg>` / `npm ls <pkg>` / `yarn why <pkg>` finds the
direct dependency to bump. Only when no released direct version fixes it, use
`pnpm.overrides`, `overrides` or `resolutions`, and say in the pull request that it
is temporary.

**Python** — uv, poetry, pipenv, pip-tools, or a plain requirements file.

```sh
uv add "<pkg>==<fixed>"                    # direct dependency, exact
poetry add "<pkg>==<fixed>"
pipenv install "<pkg>==<fixed>"
# pip-tools: change the .in to <pkg>==<fixed>, then pip-compile <input>.in
# plain requirements.txt: change the pin to <pkg>==<fixed>
```

For a transitive package, pin the fixed version in the tool's constraint or
override and say so in the pull request. `uv lock --upgrade-package`,
`poetry update` and `pipenv update` take the newest allowed version, not the
lowest that clears the advisory.

When the manifest bound excludes `fixed`, raise it to the lowest bound that allows
the fixed release, in the style the file already uses, then re-lock.

**Go** — `go.mod`.

```sh
go get <module>@v<fixed>
go mod tidy
```

The advisory gives the Go version without the leading `v`. A transitive module is
fixed the same way; if that adds a direct requirement, say so in the pull request.

**Rust** — `Cargo.toml` and `Cargo.lock`.

```sh
cargo update -p <crate> --precise <fixed>
```

If the manifest bound does not allow it, raise the bound to the lowest requirement
that does, then `cargo update -p <crate>`.

**Anything else** — Maven, Gradle, Bundler, Composer, NuGet, Docker, GitHub Actions,
a vendored binary: report it as "no recipe for this ecosystem yet". Do not guess at
a command, do not edit a lockfile by hand, and do not suppress the alert.

Commit as you go, one commit per ecosystem, naming the advisories it clears:

```sh
git add <the manifests and lockfiles you touched>
git commit -m "fix(deps): <ecosystem> — clear <advisories>"
```

Follow the repository's own commit convention (read the last twenty subjects). Sign
off with `git commit -s` when its contributing guide asks for a DCO.

## 5. Verify

Run the repository's own command from `verify`, in its checkout:

```sh
cd "$HOME/work/repo" && bash -lc "$VERIFY"
```

Make it pass. If a fix fails it and cannot be made to pass, revert that one commit
and report the fix as blocked with the failure. Never open a red pull request, and
never weaken the check.

The advisory is cleared when the manifest or lockfile resolves at or above `fixed`.
GitHub may take a while to close the alert; do not wait for it and do not dismiss it.

## 6. Open one pull request

One pull request per sweep, not one per alert: the fixes share lockfiles, so separate
pull requests would conflict. If there is nothing to fix — every finding is a
hand-back — do not open a pull request; report instead.

Read `From` from the manifest or lockfile before you write the body; the alert gives
the vulnerable range, not the installed version.

Write the body to a file (name it, so the command below uses it):

```sh
body="$(mktemp)"
```

```markdown
## What

Fixes <n> Dependabot advisories in <repo>.

| Severity | Advisory | Package | From | To | Manifest | Note |
|---|---|---|---|---|---|---|

## Handed back

- <advisory> — no released fix.
- <advisory> — breaking change; policy is `report`.
- <advisory> — no recipe for <ecosystem> yet.
- <advisory> — fix dropped: `<verify>` failed with <failure>.

## Verification

`<verify>` — pass.
```

Push the branch, then open it ready, not as a draft, so the repository's review
starts:

```sh
git -C "$HOME/work/repo" push -u origin "$branch"
gh pr create --repo "$REPO" --base "$BASE" --head "$branch" \
  --title "fix(deps): clear <n> dependency advisories (<date>)" \
  --body-file "$body"
```

The precheck wrote `work/last-sweep.pending` with the set it found. Once the run is
finished — a pull request opened or the hand-backs reported — move it into place so
the next fire can decline an unchanged set:

```sh
[ -f "$HOME/work/last-sweep.pending" ] && mv "$HOME/work/last-sweep.pending" "$HOME/work/last-sweep.tsv"
```

Do not assign the human reviewer here; the pull-request run does that when it is
green. Do not close, dismiss or edit any alert. Report the pull request link and the
hand-backs in chat (and in the bound Slack channel, if there is one), then stop.

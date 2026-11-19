---
name: updep-sweep
description: >
  Sweep one repository's open Dependabot alerts, fix every advisory that has a
  released fix in any ecosystem Dependabot alerts cover, verify with the
  repository's own checks, and open one pull request. Repository-agnostic:
  detects the package manager, lockfile, task runner and pinning style instead of
  assuming any of them. Use on the daily sweep fire, or when asked to fix
  dependency vulnerabilities.
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
  Rust, `Cargo.toml` + `Cargo.lock`. Every other ecosystem's reference file says
  what owns its manifest.
- **How the repository builds and tests.** Read its contributor docs, its CI
  workflows and its task definitions, in that order, and use the commands they use.
  If it drives everything through a task runner, drive everything through that task
  runner too.
- **Whether the toolchain is installed.** The image ships Node with `aube` (also as
  `pnpm`), Python with `uv`, and `mise`. Every other ecosystem's reference file has
  a **Toolchain** section naming the tool and how to install it, `mise` first, at
  the version the repository pins. The trusted egress covers the public toolchain
  hosts; a host it does not cover is reported, not waited on from an unattended
  fire.
- **How it pins.** Exact stays exact; a range stays a range; a lockfile is
  regenerated with its own tool, never hand-edited.
- **Whether it has a minimum release age.** If the policy documents a security
  exception, take it for this fix and say so in the pull request. If it does not,
  a fixed release younger than the floor is reported and retried next sweep. Check
  the release date at the registry the reference file names, or in the changelog.

Write what you learn into `work/repository.md`, and correct it when it turns out to
be wrong.

## 4. Plan, then fix

Fix every alert that has a released fix and an ecosystem recipe. Do not ask which
ones. Use the **lowest released version that clears the advisory**: `fixed` from the
alert, unless the repository already resolves higher, or the tool's own audit
refuses that release (npm's bad-release flag, Composer's advisory policy) — then
the lowest release it accepts, said in the pull request. When several alerts name
one package, fix once to the highest `fixed` among them.

A fix is a **breaking change** when the major version moves, or, for a `0.x`
dependency, the minor version moves. Read the changelog when unsure. What to do is
the `major` policy in `work/CONFIG.md`:

- `report` (the default): leave it alone and hand it back.
- `migrate`: read every changelog entry from the current version to the fixed one,
  check each breaking change against the repository's code, migrate, and verify. A
  migration that needs a product decision is reported, not guessed.

Each alert's `dependency.package.ecosystem` names one file under `references/`.
Read only the files the open alerts need: this skill is the flow, they are the
tool-specific commands, the lockfile each tool regenerates, the pin style it keeps
and what "verified" means for it.

| alert `ecosystem` | file | covers |
|---|---|---|
| `npm` | [npm.md](references/npm.md) | npm, pnpm, yarn, bun |
| `pip` | [python.md](references/python.md) | pip, uv, poetry, pipenv, pip-tools |
| `go` | [go.md](references/go.md) | Go modules |
| `rust` | [rust.md](references/rust.md) | Cargo |
| `maven` | [maven.md](references/maven.md) | Maven, Gradle (its manifests share this value) |
| `nuget` | [nuget.md](references/nuget.md) | PackageReference, central package management, packages.config |
| `rubygems` | [rubygems.md](references/rubygems.md) | Bundler, gemspecs |
| `composer` | [composer.md](references/composer.md) | Composer |
| `erlang` | [erlang.md](references/erlang.md) | Hex, through mix |
| `pub` | [pub.md](references/pub.md) | pub, Dart and Flutter |
| `swift` | [swift.md](references/swift.md) | Swift Package Manager |
| `actions` | [actions.md](references/actions.md) | GitHub Actions workflows |

Run a recipe at the manifest's directory, or with the workspace flag its tool uses.
A file marked **Unverified** was not run end to end when it was written: use it, but
if a step does not do what it says, report the alert instead of forcing it.

An ecosystem not in the table is reported as "no recipe for this ecosystem yet".
Do not guess at a command, do not edit a lockfile by hand, and do not suppress the
alert.

Commit as you go, one commit per ecosystem, naming the advisories it clears. Commit
the GitHub Actions fix last: a refused workflow push drops exactly that commit.

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

Check the closed pull requests first. A bump a person closed without merging is a
decision, not a queue item:

```sh
gh pr list --repo "$REPO" --state closed --limit 50 \
  --json number,headRefName,mergedAt,title \
  | jq -r --arg p "$PREFIX" '.[] | select(.headRefName | startswith($p)) | select(.mergedAt == null) | "#\(.number) \(.title)"'
```

An advisory in one of those is handed back, not reopened.

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

A push that changes `.github/workflows/` needs Workflows write and can be refused;
`references/actions.md` says how to detect that and hand the alert back.

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

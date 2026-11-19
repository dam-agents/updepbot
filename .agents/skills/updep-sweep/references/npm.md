# npm (npm, pnpm, yarn, bun)

Verified 2026-11-19: npm 11 in a throwaway project, `package-lock.json` moved
lodash 4.17.15 → 4.18.1, `npm ci` and `node -e "require('lodash')"` passed.
4.18.0, the lower release, is deprecated by npm as a bad release.

## Find it

The alert names the manifest (`package.json`) and the lockfile is beside it:
`package-lock.json` → npm, `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn,
`bun.lock`/`bun.lockb` → bun. The installed version is in the lockfile:

```sh
npm ls <pkg>            # or: pnpm why / yarn why / bun pm ls
```

For a transitive package, find the direct dependency that pulls it in. Only when
no released direct version clears the advisory, override it and say in the pull
request that the override is temporary.

## Move it

At the manifest's directory, or with the workspace flag the tool uses:

```sh
pnpm add --save-exact <pkg>@<fixed>        # exact pin; drop --save-exact for a range
yarn up <pkg>@<fixed>                      # check the manifest; Yarn 1: yarn upgrade
npm install --save-exact <pkg>@<fixed>     # exact pin; `@^<fixed>` keeps a caret
bun add --exact <pkg>@<fixed>
```

The tool may change the pin style. Check the manifest diff and correct it, then
re-lock.

In a workspace, target the package that owns the manifest: `pnpm --filter <name>
update <pkg>@<fixed>`, `yarn workspace <name> up <pkg>@<fixed>`, or `npm install
--workspace <path> <pkg>@<fixed>`. Do not update the root by accident.

A transitive package: bump the direct parent first. Only when nothing released
fixes it, use `pnpm.overrides`, `overrides` or `resolutions`.

## Regenerate the lockfile

The tool above rewrites the lockfile. Never run a bare `npm update`, `pnpm update`
or `yarn upgrade`: it moves everything the constraints allow, not just the fix.
A bare `npm install` only fills in what the manifest changed, so after editing a
version by hand it is the way to re-lock.

## Pin style

An exact pin stays exact (`--save-exact`, `bun add --exact`, a `1.2.3` range
stays `1.2.3`); a caret stays a caret; a lockfile-only repository keeps the
manifest entry unchanged and only the lockfile moves. Skip a release the registry
marks deprecated or bad (`npm view <pkg> deprecated`).

## Verify

`npm ci` (or the tool's frozen install) then the repository's `verify` command:
the lockfile resolves at or above `fixed` and the build and tests pass.

## Toolchain

Node and `aube` (as `pnpm`) ship with the image. A missing Yarn or Bun is
installed with `mise use -g yarn@<version>` / `mise use -g bun@<version>`, or
`aube add -g yarn`. When `packageManager` names a pnpm version, run that version
(`mise use -g pnpm@<version>` or `npx pnpm@<version>`).

## Reported, not fixed

- A Deno alert (`deno.json`/`deno.lock` in the dependency graph) whose fix is an
  npm package: no `package.json` names it. Report it. A missing Yarn or Bun is
installed with `mise use -g yarn@<version>` / `mise use -g bun@<version>`, or
`aube add -g yarn`. When `packageManager` names a pnpm version, run that version
(`mise use -g pnpm@<version>` or `npx pnpm@<version>`).

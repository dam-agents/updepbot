# Hex (Elixir and Erlang, mix)

Verified 2026-11-19: Elixir 1.18 with OTP 27 in a throwaway project, `mix.exs` and
`mix.lock` moved plug 1.17.1 → 1.17.4; `mix deps.update plug` rewrote only that
entry and `mix compile --force` passed.

## Find it

The alert names `mix.exs` and `mix.lock`. Hex alerts come only from a dependency
submission — the dependency graph does not read `mix.lock` — so an alert may name a
path the submission reported; the requirement is still in `mix.exs`.

```sh
mix deps.tree
mix hex.info <pkg>
grep -n '<pkg>' mix.lock
```

## Move it

Raise the requirement in `mix.exs` to the lowest that admits `fixed`, keeping the
style (`"~> 1.17"` stays pessimistic, `"1.17.1"` stays exact), then:

```sh
mix deps.update <pkg>
mix compile
```

`mix deps.update <pkg>` works for a transitive dependency too; it unlocks that
dependency and the projects it depends on, not the whole tree. If the parent's
requirement forbids `fixed`, raise the parent, or add `{:pkg, ">= <fixed>",
override: true}` and say in the pull request that it is an override.

Mix resolves the latest version the requirements allow, not the lowest that clears
the advisory; say so in the pull request when that lands above `fixed`.

## Regenerate the lockfile

`mix deps.update <pkg>` rewrites `mix.lock` for that subtree. Never run
`mix deps.update --all`, and never hand-edit `mix.lock`.

## Pin style

`~>` stays `~>`, an exact string stays exact, an umbrella app's dependency stays
in the child that declares it. Do not add `override: true` unless it is needed.

## Verify

`mix deps.get --check-locked` (or `mix deps.get` then `git diff --exit-code
mix.lock`), `mix compile` and the repository's `verify` command.

## Toolchain

Neither ships. Install the pair the repository pins (`.tool-versions`,
`mise.toml`, `elixir` in `mix.exs`, `.elixir-version`/`.tool-versions` for OTP)
with `mise use -g erlang@<otp> elixir@<version>`. Hex is fetched by
`mix local.hex --force` on the first `mix deps.get`.

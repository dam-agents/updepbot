# Ruby (Bundler and gemspecs)

Verified 2026-11-19: Ruby 3.4 with Bundler 2.6 in throwaway projects, `Gemfile` and
`Gemfile.lock` moved mustache 1.1.2 → 1.1.3 directly and rack 2.2.3 → 2.2.25
transitively with `--conservative`; `bundle exec` and the other gems stayed put.

## Find it

The alert names `Gemfile` or a `*.gemspec`; `Gemfile.lock` is the lock.

```sh
bundle info <gem>          # only after bundle install
grep -n '<gem>' Gemfile Gemfile.lock
```

## Move it

- Declared in the `Gemfile`: raise its bound to the lowest that admits `fixed`,
  keeping the style (`gem "<gem>", "= <fixed>"` stays exact, `"~> <fixed>"` stays
  pessimistic), then run the same `bundle update <gem> --conservative`.
- Only in `Gemfile.lock` (transitive, or a lockfile-pinned repository): update the
  one gem; Bundler holds every other gem to its locked version:

```sh
bundle update <gem> --conservative
```

This works for a transitive gem too. If the parent's requirement forbids `fixed`,
raise the parent, or add `gem "<gem>", ">= <fixed>"` to the `Gemfile` and say in
the pull request that it is an override. Never hand-edit `Gemfile.lock`.

Bundler takes the newest allowed version, not the lowest that clears the advisory;
say so in the pull request when that lands above `fixed`.

## Regenerate the lockfile

`bundle update <gem> --conservative` rewrites the lock for that gem only. A bare
`bundle update` moves every gem; do not run it.

## Pin style

A `.gemspec` constraint (`add_dependency "x", ">= 1.2"`) stays a constraint; the
`Gemfile`'s exact pin stays exact; `BUNDLED WITH` in the lock is not a dependency
version, leave it.

## Verify

`bundle check` (or `bundle install` on the lock) and the repository's `verify`
command; the resolved version is at or above `fixed` (`bundle info <gem>`).

## Toolchain

Ruby is not shipped in a usable version. Install the one the repository pins
(`.ruby-version`, `ruby "x.y"` in the `Gemfile`, `mise.toml`) with
`mise use -g ruby@<version>`, then `gem install bundler -v <BUNDLED WITH>` (or
`bundle _<version>_`). Native gems compile on first install; without a compiler in
the image that fails, so report a gem that needs one instead of forcing it.

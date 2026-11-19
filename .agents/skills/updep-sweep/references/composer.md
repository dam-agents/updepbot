# Composer (PHP)

Verified 2026-11-19: static PHP 8.5.8 (static-php-cli build) and Composer 2.11 in a
throwaway project, `composer.json` and `composer.lock` moved symfony/yaml 7.4.17 →
7.4.23 with the exact pin kept; `composer validate`, a script using the package and
`composer audit` all passed. 7.4.18 is the advisory's first patched release but
Composer's own policy still flags it for a second advisory, so the run took the
lowest release `composer audit` accepts.

## Find it

The alert names `composer.json`; `composer.lock` is the lock.

```sh
composer why <vendor/pkg>
composer show <vendor/pkg>
```

## Move it

- Declared in `require`/`require-dev`: raise the constraint to the lowest that
  admits `fixed`, keeping the style (`"vendor/pkg": "1.2.3"` stays exact,
  `"^1.2"` stays a caret):

```sh
composer require <vendor/pkg>:<constraint>
```

  Add `-W` (`--with-all-dependencies`) only when resolution fails, because it also
  moves the package's own dependencies.

- Transitive: `composer update <vendor/pkg> --with-dependencies` moves it if the
  parent's constraint allows. Otherwise raise the parent. Composer has no
  overrides: if nothing released fixes it, add `"vendor/pkg": "<fixed>"` to
  `require` and say in the pull request that it is temporary.

Composer takes the newest version the constraints allow, not the lowest that clears
the advisory; say so in the pull request when that lands above `fixed`.

Composer 2.11 and later refuse to resolve a release its security policy flags
(`Your requirements could not be resolved … affected by security advisories`).
When that hits `fixed`, take the next release `composer audit` accepts and say so
in the pull request.

## Regenerate the lockfile

`composer require` / `composer update <vendor/pkg>` rewrites `composer.lock` for
that package and what it must move. Never run a bare `composer update`: it moves
everything within the constraints. Never hand-edit `composer.lock`.

## Pin style

An exact version stays exact, a caret stays a caret, `~` stays `~`. Leave
`config.platform` alone.

## Verify

`composer validate --strict`, `composer audit`, `composer install --no-interaction`
on the lock, and the repository's `verify` command (its test suite); the package
resolves at or above `fixed` (`composer show <vendor/pkg>`).

## Toolchain

PHP and Composer are not shipped.

```sh
mise use -g php@<version>        # or a static build, below
curl -sS https://getcomposer.org/installer | php -- \
  --install-dir="$HOME/.local/bin" --filename=composer
```

mise's `php` plugin compiles PHP and needs autoconf, bison, re2c, pkg-config and the
extension libraries; when the image lacks them, a static-php-cli build needs no
compiler:

```sh
curl -fsSL "https://dl.static-php.dev/static-php-cli/bulk/php-<version>-cli-$(uname -s | tr A-Z a-z)-$(uname -m).tar.gz" \
  | tar xz -C "$HOME/.local/bin"     # provides `php`
```

The macOS `aarch64` build was used for the verification; the Linux builds sit in
the same directory. Composer itself needs `openssl`, `phar` and `mbstring`, which
those builds carry. If neither path works, report the alert as not fixable from
here.

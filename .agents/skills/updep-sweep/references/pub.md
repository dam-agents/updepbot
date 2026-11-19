# pub (Dart and Flutter)

Verified 2026-11-19: Dart 3.14 in a throwaway project, `pubspec.yaml` and
`pubspec.lock` moved jose 0.3.5 → 0.3.5+1; `dart pub get`, `dart analyze` and
`dart run` passed.

## Find it

The alert names `pubspec.yaml`; `pubspec.lock` is the lock.

```sh
dart pub deps --style=compact
dart pub outdated
```

## Move it

- Declared in `pubspec.yaml`: raise the constraint to the lowest that admits
  `fixed`, keeping its shape (`^0.3.5+1` stays a caret, `0.3.5` stays exact), or
  `dart pub add <pkg>:<constraint>`.
- Then resolve: `dart pub get` rewrites `pubspec.lock` for the changed package.
- Transitive: `dart pub upgrade <pkg>` upgrades that package alone where the
  resolution allows; otherwise raise the parent. If nothing released fixes it, add
  a `dependency_overrides` entry at `fixed` and say in the pull request that it is
  an override.

pub resolves the latest version the constraints allow, not the lowest that clears
the advisory; say so in the pull request when that lands above `fixed`.

## Regenerate the lockfile

`dart pub get` (or `dart pub upgrade <pkg>`) rewrites `pubspec.lock`. Never run a
bare `dart pub upgrade`: it moves every package. Never hand-edit `pubspec.lock`.

## Pin style

A caret stays a caret, an exact version stays exact, a `>=x <y` range stays a
range. A Flutter plugin's `sdk: flutter` entries are untouched.

## Verify

`dart pub get`, `dart analyze` and `dart test` (or the repository's `verify`
command); the package resolves at or above `fixed` (`dart pub deps`).

## Toolchain

Dart is not shipped. Install the version the `pubspec.yaml`'s SDK constraint
allows with `mise use -g dart@<version>`. A Flutter project (`flutter:` under
`sdk` dependencies, a `flutter` section) needs the Flutter SDK instead — install
it with `mise use -g flutter@<version>`; if that is not installable here, report
the alert.

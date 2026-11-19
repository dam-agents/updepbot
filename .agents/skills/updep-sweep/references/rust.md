# Rust (Cargo)

Verified 2026-11-19: Rust 1.99 in a throwaway crate, `Cargo.lock` moved time
0.2.22 → 0.2.23 with `cargo update -p time --precise 0.2.23` (range bound) and by
raising an exact `=0.2.22` bound to `=0.2.23` then `cargo update -p time`;
`cargo build --locked` passed.

## Find it

`Cargo.toml` is the manifest, `Cargo.lock` the lock. The installed version:

```sh
cargo tree -i <crate>
cargo tree | grep <crate>
```

## Move it

```sh
cargo update -p <crate> --precise <fixed>
```

`--precise` lands exactly the fixed release, direct or transitive. If the
manifest bound does not allow it, raise the bound to the lowest requirement that
does, then `cargo update -p <crate>`.

## Regenerate the lockfile

`cargo update -p <crate>` rewrites only that crate and what it must move. Never
run a bare `cargo update`: it moves every crate.

## Pin style

An exact `=x.y.z` stays exact, a `"x.y"` requirement stays that shape, and a
`workspace = true` dependency is fixed in the workspace manifest. Never hand-edit
`Cargo.lock`.

## Verify

`cargo build --locked` (or `cargo check --locked`) and the repository's `verify`
command; the crate resolves at or above `fixed`.

## Toolchain

Rust is not shipped. Install the version the repository pins
(`rust-toolchain.toml`, `.rust-version`, `mise.toml`) with
`mise use -g rust@<version>`; without a pin, the current stable.

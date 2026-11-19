# Go (Go modules)

Verified 2026-11-19: Go 1.27 in a throwaway module, `go.sum` moved
golang.org/x/text 0.3.6 → 0.3.8, `go build` and `go test` passed.

## Find it

`go.mod` is the manifest and `go.sum` the lock. The installed version:

```sh
go list -m <module>
go mod graph | grep <module>
```

## Move it

```sh
go get <module>@v<fixed>
go mod tidy
```

The alert gives the Go version without the leading `v`; add it. A transitive
module is fixed the same way; if that adds a direct requirement to `go.mod`, say
so in the pull request. If `go get` has to raise the `go` or `toolchain` line, that
is a breaking change: follow `major`.

## Regenerate the lockfile

`go get` updates `go.mod`/`go.sum` for that module and whatever it must move to
satisfy the requirement. `go mod tidy` then drops anything no longer needed. Never
hand-edit `go.sum`.

## Pin style

`go.mod` requirements are minimum versions by design; `go get <module>@v<fixed>`
writes the minimum that admits the fix. Leave a `toolchain` line alone.

## Verify

`go build ./...` and `go test ./...` (or the repository's `verify` command); the
module resolves at or above `fixed`.

## Toolchain

Go is not shipped. Install the version the repository pins (`go.mod` `go` /
`toolchain`, `.go-version`, `mise.toml`) with `mise use -g go@<version>`; without a
pin, the current stable (`mise use -g go@latest`).

# Swift Package Manager

Verified 2026-11-19: Swift 6.4 in a throwaway package, `Package.swift` and
`Package.resolved` moved apple/swift-nio-extras 1.9.1 → 1.9.2 as an exact pin;
only its two lines in `Package.resolved` changed and `swift build` passed. That
clears the advisory whose first patched release is 1.9.2; the package has newer
advisories with newer fixes, which is what "highest `fixed` among the open alerts"
is for.

## Find it

The alert names `Package.resolved`; the requirement is in the `Package.swift`
beside it. If there is no `Package.swift` next to the `Package.resolved` (an Xcode
project's `…/xcshareddata/swiftpm/Package.resolved`), `swift package update`
cannot change it: report the alert.

```sh
swift package show-dependencies
cat Package.resolved
```

## Move it

- Declared requirement: raise its lower bound to `fixed`, keeping the style —
  `.upToNextMajor(from: "<fixed>")` stays, `.upToNextMinor` stays, `.exact` stays
  exact.
- Then update the one package:

```sh
swift package update <name>
```

  `<name>` is the package identity from `Package.resolved` (often the last path
  component, e.g. `leaf-kit`), not the URL.
- Transitive: the same command moves the package if the parent's requirement
  allows it; otherwise raise the parent. SwiftPM cannot pin a transitive package
  directly, so with no released parent that allows `fixed`, report the alert.

`swift package update` takes the newest version the requirements allow, not the
lowest that clears the advisory; say so in the pull request when that lands above
`fixed`. Never hand-edit `Package.resolved`.

## Regenerate the lockfile

`swift package update <name>` (or `swift package resolve` after a requirement
edit) rewrites it. Never run a bare `swift package update`: it moves every
package.

## Pin style

`from:`, `.exact`, `.upToNextMajor` and `.upToNextMinor` all stay what they were.

## Verify

`swift build` (or `swift test`) and the repository's `verify` command; the
resolved version is at or above `fixed` (`swift package show-dependencies`).

## Toolchain

Swift is not shipped. On Linux install the toolchain the package's
`// swift-tools-version:` needs with `mise use -g swift@<version>`; the image is
Debian, so the download is large and may need system libraries the base does not
carry. If the toolchain cannot be installed, report the alert.

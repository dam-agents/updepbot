# NuGet (.NET)

Verified 2026-11-19: .NET 8 in a throwaway project, `app.csproj` and
`packages.lock.json` moved AutoMapper 15.1.3 → 15.1.4; a plain `dotnet restore`
moved the lock and `dotnet build` passed (`--force-evaluate` was not needed).

## Find it

The alert names the manifest: a project file (`*.csproj`, `*.fsproj`,
`*.vbproj`), `Directory.Packages.props` (central package management), or
`packages.config` (old style). Which style:

```sh
dotnet list package --include-transitive
```

A version in `Directory.Packages.props` wins over one in a project file; raising
the project file alone does nothing under central package management.

## Move it — PackageReference

```sh
dotnet add <project> package <pkg> --version <fixed>
```

or edit `<PackageReference Include="<pkg>" Version="<fixed>" />`. This writes an
exact version; when the file used a range (`[1.0,2.0)`), restore the range with
its lower bound raised to `fixed`. A transitive package: bump the direct parent
first. If no parent release fixes it, add a direct `PackageReference` at `fixed`
and say in the pull request that it is an override.

## Move it — central package management

Edit `<PackageVersion Include="<pkg>" Version="<fixed>" />` in
`Directory.Packages.props`. Leave the project files' `PackageReference` entries
(no `Version`) alone. Then `dotnet restore`.

## Move it — packages.config

Needs `nuget.exe` (`mono` on Linux): `nuget update <packages.config> -Id <pkg>
-Version <fixed>`. The dotnet CLI does not understand `packages.config`; when
`nuget.exe` is not installable here, report the alert instead of editing the file
by hand.

## Regenerate the lockfile

When the project locks (`packages.lock.json` or `RestorePackagesWithLockFile`), a
plain `dotnet restore` after the manifest edit moves the changed package. If the
lock did not move:

```sh
dotnet restore --force-evaluate
```

`--force-evaluate` re-resolves every floating version, so check the diff: if it
touches more than the one package, discard it and report the alert instead. Never
hand-edit `packages.lock.json`.

## Pin style

A `Version` attribute stays an attribute, a central `PackageVersion` stays
central, a floating `1.*` stays floating only if the repository really floats.
Do not introduce a lockfile the repository does not have.

## Verify

`dotnet build` and the repository's `verify` command, with the resolved version
at or above `fixed` (`dotnet list package`).

## Toolchain

.NET is not shipped. Install the SDK the repository pins (`global.json` `sdk`;
otherwise the `TargetFramework`s in the project files, e.g. `net8.0` → .NET 8)
with `mise use -g dotnet@<major>`. `dotnet` downloads the SDK's targeting packs
on first restore; the trusted egress covers nuget.org.

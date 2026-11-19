# Maven and Gradle

Verified 2026-11-19: Maven 3.9 and Gradle 9.9 in throwaway projects,
`org.json:json` 20250517 → 20260719 in a `pom.xml`, a `build.gradle` and a
`gradle/libs.versions.toml`; `mvn package`, `gradle build` and
`gradle dependencies --update-locks org.json:json` passed, the last changing only
that entry in `gradle.lockfile`.

## Find it

An alert names `pom.xml` for Maven. Gradle is not read by the dependency graph: its
alerts come from a dependency submission, and name the path the submission reported —
often `build.gradle[.kts]`, `gradle/libs.versions.toml` or a path inside the
repository. Locate the declaration with the commands below; when no file declares
the artifact, the constraint below is how you raise it.

```sh
mvn dependency:tree -Dincludes=<group>:<artifact>    # Maven
./gradlew dependencyInsight --dependency <artifact> --configuration runtimeClasspath
```

Maven: read whether the version is declared on the dependency, inherited from a
parent, or managed by a BOM in `<dependencyManagement>`; the managed version wins.

## Move it — Maven

- Declared version: change `<version>` to the lowest patched one.
- Managed by a BOM or parent: raise the BOM/parent version, not the leaf.
- Transitive: add (or raise) a `<dependencyManagement>` entry for the artifact at
  the fixed version. Say in the pull request that it is an override.
- Plugins are dependencies too: a `<plugin>` version gets the same edit.

Maven has no lockfile. If the repository uses `maven-lockfile` or another locking
plugin, regenerate with that plugin's own command after the edit.

## Move it — Gradle

- `build.gradle[.kts]`: change the declared version to the fixed one.
- Version catalog: change the version in `gradle/libs.versions.toml`; the
  catalog is the single place, do not edit the build file's `libs.*` reference.
- Transitive: add a constraint at the fixed version —
  `dependencies { constraints { implementation("<group>:<artifact>:<fixed>") } }`
  — and say in the pull request that it is an override.
- Wrapper version: take the wrapper's version from
  `gradle/wrapper/gradle-wrapper.properties` and use `./gradlew`; do not install a
  different Gradle.
- Dependency locking in use (`gradle.lockfile` or `dependencyLocking { }`):
  `./gradlew dependencies --update-locks <group>:<artifact>` updates only that
  entry. A bare `--write-locks` re-resolves every locked configuration and would
  move dynamic versions elsewhere. In a multi-project build prefix the task with
  the project (`:<project>:dependencies`). Never hand-edit `gradle.lockfile`.

## Regenerate the lockfile

Maven: none, the pom is the record. Gradle: `--update-locks` rewrites the one entry
in `gradle.lockfile`; check the diff touches the one artifact.

## Pin style

An exact version stays exact, a range (`1.+`, `[1.0,2.0)`) stays a range, a
version-catalog reference stays a reference. Kotlin DSL strings use `"` and
parents `()`; keep the file's syntax.

## Verify

The repository's `verify` command, at least `mvn -DskipTests package` /
`./gradlew build`; the resolved version must be at or above `fixed`
(`mvn dependency:tree`, `./gradlew dependencyInsight`).

## Toolchain

Neither ships. Install the JDK the project pins (`maven.compiler.release`,
`<release>`, `.java-version`, `.sdkmanrc`, Gradle's `java.toolchain`) with
`mise use -g java@<version>`, and `mise use -g maven@<version>` for Maven (3.9 or
4.x, whichever the pom targets); Gradle comes from the wrapper. A JDK version the
build does not support fails the build, not the bump: report it rather than
loosening the project's compiler settings.

## Reported, not fixed

- A Bazel alert (`MODULE.bazel` / `maven_install.json` feed the `maven` ecosystem)
  whose artifact no `pom.xml` or build file pins: report it.
- A Maven version supplied by a property that only a parent POM (outside this
  repository) sets: report it.
- A Gradle artifact no manifest and no version catalog declares, whose transitive
  version cannot be constrained because the build has no configuration to put the
  constraint in: report it.

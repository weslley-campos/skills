# Koin compiler setup and convention plugin

Use the Koin compiler plugin for Koin projects that meet its current Kotlin and Gradle
requirements. It provides compile-time graph validation for annotations and the compiler DSL, and
generates no visible source files. Recheck the live
[compiler-plugin setup](https://insert-koin.io/docs/setup/compiler-plugin/) and
[KSP migration guide](https://insert-koin.io/docs/migration/from-ksp-to-compiler-plugin/) before
editing: compatibility requirements and the independently versioned compiler plugin can move.

Create a `<prefix>.koin` convention plugin on the first module that needs Koin, rather than waiting
for a second consumer to prove the repetition. A build that has already bootstrapped `build-logic`
is already organized around more than one module of a kind; retrofitting a convention after several
modules have each hand-declared the same compiler, dependency and source-set setup means migrating
every one of them later, the exact rework `init` exists to avoid doing module-by-module. Koin's
shared surface, the compiler plugin plus `koin-core` and `koin-annotations` in `commonMain`, is
stable across consumers, so there is nothing a second module teaches that the first did not already
show.

Keep the convention narrow. Only the compiler plugin and the two portable dependencies belong
inside it. Compose, either navigation integration, tests, Android integration and WorkManager stay
opt-in and module-local, declared directly by whichever modules use them, per "Select integrations
per module" below — folding them into the base convention would force them onto a module that only
wants the DI graph. A module that does not want Koin at all simply does not apply the convention; it
sits beside the module-type convention, not inside it.

## Select integrations per module

Survey the catalog and consuming modules first:

```bash
rg -n "koin|compose|navigation|serialization|lifecycle|workmanager" \
    --glob "libs.versions.toml" --glob "*.gradle.kts" --glob "AndroidManifest.xml" .
```

The current question API does not support the old paged selection workflow. Use exactly two
interactions:

1. Show the relevant rows below as a markdown checklist, including whether each alias and
   prerequisite already exists. Ask for one free-text response such as `accept`, or
   `include: koin-compose; exclude: koin-annotations; add: ...`.
2. Restate the final per-module dependency list and catalog edits, then ask one explicit
   `Proceed` / `Adjust` confirmation before editing.

| Dependency | Default | What it is for |
|---|---|---|
| `koin-core` | `[x]` | Koin runtime and module DSL; use in `commonMain` wherever Koin runs |
| `koin-annotations` | `[x]` | `@Singleton`, `@Module`, and `@ComponentScan` in `commonMain`; turn off for compiler-DSL-only modules |
| `koin-compose` | `[ ]` | `KoinApplication { }`, `koinInject()`, and the Compose bridge in `commonMain`; Compose modules only |
| `koin-compose-viewmodel` | `[ ]` | `koinViewModel()` in composables from `commonMain`; Compose ViewModel modules only |
| `koin-compose-navigation3` | `[ ]` | Koin-backed `navigation<T>` entries and `koinEntryProvider` in `commonMain`; requires Navigation 3 plus the Kotlin serialization runtime and plugin |
| `koin-compose-viewmodel-navigation` | `[ ]` | Koin ViewModel integration for Navigation 2 (`navigation-compose`) in `commonMain`; alternative to the Navigation 3 artifact |
| `koin-core-viewmodel` | `[ ]` | `@KoinViewModel` outside Compose in `commonMain`; only where that API is used |
| `koin-test` | `[ ]` | Koin test APIs in `commonTest`; compiler validation is preferred, with `verify()` reserved for classic/runtime DSL gaps |
| `koin-android` | `[ ]` | Android context and `androidContext()` in KMP `androidMain`, or ordinary `implementation` in an Android module |
| `koin-androidx-workmanager` | `[ ]` | Koin's WorkManager factory and worker definitions in KMP `androidMain`, or ordinary Android dependencies; also requires `koin-android`, `workManagerFactory()` startup configuration, and disabling WorkManager's default manifest initializer |

`koin-core` and `koin-annotations` default on because a module applying the `<prefix>.koin`
convention already gets both from it; the checklist only asks about them for a module that
intentionally does not apply the convention — a non-KMP module, or a KMP module opting out.
Everything below those two rows is a genuine per-module choice, convention or not.

The two navigation artifacts are alternatives. Inspect the module's existing navigation stack and
offer only the matching integration. Before selecting `koin-compose-navigation3`, verify both a
`kotlinx-serialization-*` runtime dependency and the `org.jetbrains.kotlin.plugin.serialization`
plugin; its type-safe routes use `@Serializable`.

Only the compiler plugin and the two portable dependencies belong in the shared convention. Compose,
either navigation integration, tests, Android integration and WorkManager stay module-local
regardless of how many modules exist, because they are not properties every consumer shares — fold
one in and a module that does not want it inherits it anyway. Do not turn the checklist into one
hardcoded dependency bundle.

Android-only artifacts never belong in `commonMain`. A KMP module puts them in `androidMain`; a
single-platform Android module uses its ordinary dependency configuration.

## Catalog and root classpath

Reuse compatible existing aliases. In Koin 4.2, `koin-core` and `koin-annotations` are released from
the main Koin project and use the same `koin` version. Only the compiler plugin keeps its independent
`koin-plugin` version:

```toml
[versions]
koin = "<current-compatible-koin-version>"
koin-plugin = "<current-compatible-koin-compiler-plugin-version>"

[libraries]
koin-core = { module = "io.insert-koin:koin-core", version.ref = "koin" }
koin-annotations = { module = "io.insert-koin:koin-annotations", version.ref = "koin" }

[plugins]
koin-compiler = { id = "io.insert-koin.compiler.plugin", version.ref = "koin-plugin" }
```

Optional Koin integrations use the same `koin` version unless their current official setup says
otherwise. Do not add a separate annotations version.

Declare the compiler plugin once at the root so it resolves exactly once for the whole build:

```kotlin
plugins {
    alias(libs.plugins.koin.compiler) apply false
}
```

That root declaration is the whole classpath story for Koin, and it is the one edit that is not
optional: the convention plugin applies `koin.compiler` by id, and the id resolves against the
consuming build's plugin classpath, which the `apply false` line above owns.

Whether Koin also needs a `compileOnly` entry in `convention/build.gradle.kts` depends on what the
convention does with it, and the rule is worth stating precisely because it is easy to get backwards:

- **Applying the plugin only** — the convention calls `apply(plugin = <id>)` and nothing else. No
  `compileOnly` entry is needed, unlike AGP, KGP and the Compose Gradle plugin. Those three are on
  that classpath because their conventions *configure extension types*
  (`ApplicationExtension`, `KotlinMultiplatformExtension`, the Compose DSL). A plugin id is a
  string, so a convention that only applies Koin references no Koin type, and `build-logic`
  compiles, `validatePlugins` passes and the plugin applies without the artifact.
- **Configuring `koinCompiler { }`** — the convention references `KoinGradleExtension`, a real type.
  Now `io.insert-koin:koin-compiler-gradle-plugin` must be `compileOnly` in
  `convention/build.gradle.kts`, and it needs its own `[libraries]` catalog entry:

```toml
[libraries]
koin-compiler-gradle-plugin = { module = "io.insert-koin:koin-compiler-gradle-plugin", version.ref = "koin-plugin" }
```

## Configuring the compiler plugin from the convention

Build-wide compiler policy — logging and safety switches — is a good fit for the convention, because
it is a property of how the build treats Koin rather than of one module's dependencies. The
extension is `org.koin.compiler.plugin.KoinGradleExtension`, registered under the name
`koinCompiler`:

```kotlin
import org.gradle.kotlin.dsl.assign
import org.koin.compiler.plugin.KoinGradleExtension

extensions.configure<KoinGradleExtension> {
    compileSafety = true      // compile-time dependency validation
    skipDefaultValues = true  // Kotlin default values win over container resolution
    unsafeDslChecks = true    // create() must be the only instruction in its lambda
    userLogs = true           // trace detected components
    debugLogs = false         // internal FIR/IR tracing, for debugging the plugin
    logSeverity = "info"      // keep the two log switches out of the warning stream
    // strictSafety deliberately unset — see below
}
```

**Every field is a Gradle `Property<T>`, not a plain `Boolean` or `String`.** In a `.gradle.kts`
build script the `=` form works with no ceremony, because `org.gradle.kotlin.dsl.*` is imported
implicitly. Inside a convention plugin, which is ordinary Kotlin rather than a script, `=` compiles
only with an explicit `import org.gradle.kotlin.dsl.assign`. Without that import the assignment does
not resolve, and the error points at the property rather than at the missing import. `userLogs.set(true)`
is the equivalent that needs no import; pick one and keep the file consistent.

Read the defaults off `KoinGradleExtension` in the version actually resolved, rather than off the
published options table: the documented table has trailed the extension before. At the time of
writing the table lists six options while the extension exposes ten, and the four it omits include
`logSeverity`, which governs how loud two of the documented six are.

| Field | Default | What it does |
|---|---|---|
| `compileSafety` | `true` | Compile-time dependency validation — every dependency a `@Module` needs must be provided |
| `strictSafety` | auto-detected | Forces the aggregator's safety pass to re-run every build, bypassing Kotlin incremental compilation. Auto-enabled on modules where an entry point is found |
| `skipDefaultValues` | `true` | Parameters with a Kotlin default value keep it instead of being resolved from the container |
| `userLogs` | `false` | Logs component detection and DSL/annotation processing |
| `debugLogs` | `false` | Verbose logs of the plugin's internal FIR/IR processing |
| `unsafeDslChecks` | `true` | Validates that a `create()` call inside a lambda is the only instruction there |
| `strictSafetyForceOff` | `false` | Explicit acknowledgement that `strictSafety` auto-detection misfired |
| `aiAssist` | `true` | One diagnostic-triage hint per build when a Koin error fires |
| `logSeverity` | `"warning"` | Severity of `userLogs`/`debugLogs` output |
| `versionCheckSeverity` | `"warning"` | Severity of the unverified-Kotlin-version warning |

`strictSafety` is the one field to think twice about before pinning. It has no default value at all:
the plugin scans each compilation for `startKoin`, `koinApplication` or `@KoinApplication` and turns
itself on where it finds one. Setting it to `false` is *ignored* once that detection fires, because
an aggregator skipping revalidation on an incremental rebuild is a correctness gap rather than a
preference; `strictSafetyForceOff = true` is the real opt-out, and only for a confirmed misfire.
Enabling it costs that module its incremental-compilation cache on every build, so leave it to the
detector unless there is a reason not to.

Two of these interact in a way that surprises people. `userLogs = true` emits a line per detected
component, and `logSeverity` defaults to `"warning"`, so those lines arrive as compiler warnings on
every compilation of every module — which is noise on a large graph, and a hard failure on any build
using `allWarningsAsErrors` or `-Werror`. Setting `logSeverity = "info"` demotes them and leaves real
`KOIN-Dxxx` diagnostics at their own severity. Turning `userLogs` on without deciding `logSeverity`
is the single most common way this block goes wrong.

Whether to write out the fields that already match their defaults is a real choice, and it splits by
where the block lives. In a module build file, restating a default is noise. In a convention plugin
it is defensible as pinning: the convention is where build-wide policy is declared, and a value
written down cannot be changed underneath the build by an upstream default that moves in a later
Koin release. Pinning costs a line and buys a diff when that happens. Choose one and apply it to the
whole block, so a reader can tell which lines are decisions — and leave `strictSafety` out of it
either way, for the reason above.

Note what the compiler plugin does when a module has no Koin entry point yet. It applies, runs, and
reports `[Koin] compile-safety validation skipped — no Koin entry point in this compilation`.
Wiring the plugin in is therefore not the same as getting compile-time graph validation: the
validation only starts doing work once the module actually declares a Koin graph. Do not report the
setup as "validated by the compiler" on the strength of a green `assemble` alone.

## The KMP convention

Register a `<prefix>.koin` convention plugin. It applies Kotlin Multiplatform and the Koin compiler
plugin, then adds only the two portable dependencies genuinely shared by every KMP consumer:
`koin-core` and `koin-annotations` in `commonMain`. Keep Android, Compose, navigation, test and
WorkManager dependencies module-local — see "Select integrations per module" above.

```kotlin
import extensions.configureKoinDependencies
import extensions.libs
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.assign
import org.gradle.kotlin.dsl.configure
import org.jetbrains.kotlin.gradle.dsl.KotlinMultiplatformExtension
import org.koin.compiler.plugin.KoinGradleExtension

class KoinConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = libs.plugins.kotlin.multiplatform.get().pluginId)
        apply(plugin = libs.plugins.koin.compiler.get().pluginId)

        extensions.configure<KotlinMultiplatformExtension>(::configureKoinDependencies)

        extensions.configure<KoinGradleExtension> {
            userLogs = true
            logSeverity = "info"
        }
    }
}
```

In `extensions/Koin.kt`:

```kotlin
package extensions

import org.gradle.api.Project
import org.jetbrains.kotlin.gradle.dsl.KotlinMultiplatformExtension

internal fun Project.configureKoinDependencies(extension: KotlinMultiplatformExtension) {
    extension.sourceSets.apply {
        commonMain.dependencies {
            implementation(libs.koin.core)
            implementation(libs.koin.annotations)
        }
    }
}
```

```toml
[plugins]
<prefix>-koin = { id = "<prefix>.koin" }
```

```kotlin
gradlePlugin {
    plugins {
        register("koin") {
            id = libs.plugins.<prefix>.koin.get().pluginId
            implementationClass = "KoinConventionPlugin"
        }
    }
}
```

Consuming KMP modules apply this convention instead of separately applying Kotlin Multiplatform and
the Koin compiler plugin. Follow the four catalog, registration and root-classpath edits in
`SKILL.md`.

## Direct declarations, for what stays outside the convention

A module that is not KMP, or a KMP module that deliberately does not want the shared graph, opts
into Koin without the convention. The consuming module keeps its existing module-type plugin; Koin
does not select or apply the module type.

A KMP module that skips the convention places portable dependencies in `commonMain` and looks up
Android-specific source sets defensively:

```kotlin
plugins {
    alias(libs.plugins.<existing-kmp-or-base-plugin>)
    alias(libs.plugins.koin.compiler)
}

kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation(libs.koin.core)
            implementation(libs.koin.annotations)
        }
        // Only when this KMP module uses Android Koin APIs.
        findByName("androidMain")?.dependencies {
            implementation(libs.koin.android)
        }
    }
}
```

An Android application uses the application or base convention it already has and ordinary
dependency configurations:

```kotlin
plugins {
    alias(libs.plugins.<existing-android-application-or-base-plugin>)
    alias(libs.plugins.koin.compiler)
}

dependencies {
    implementation(libs.koin.core)
    implementation(libs.koin.annotations)
    implementation(libs.koin.android)
}
```

Remove any row the module does not use. In particular, do not copy Android, Compose, navigation,
test or WorkManager dependencies from one module into another merely for symmetry.

## WorkManager requires runtime setup

`koin-androidx-workmanager` is not sufficient by itself. A participating Android application needs
both Android artifacts:

```kotlin
dependencies {
    implementation(libs.koin.android)
    implementation(libs.koin.androidx.workmanager)
}
```

Enable Koin's worker factory during application startup. Typed startup remains valid:

```kotlin
@KoinApplication(modules = [AppModule::class])
class App

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin<App> {
            androidContext(this@MainApplication)
            workManagerFactory()
        }
    }
}
```

Then disable WorkManager's default initializer in the application manifest so it does not initialize
before Koin's factory:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <application>
        <provider
            android:name="androidx.startup.InitializationProvider"
            android:authorities="${applicationId}.androidx-startup"
            android:exported="false"
            tools:node="merge">
            <meta-data
                android:name="androidx.work.WorkManagerInitializer"
                android:value="androidx.startup"
                tools:node="remove" />
        </provider>
    </application>
</manifest>
```

Only after the dependency, startup and manifest steps is `@KoinWorker` or `worker<T>()` wired for
WorkManager creation. Keep the
[official WorkManager setup](https://insert-koin.io/docs/reference/koin-android/workmanager/) beside
this checklist because AndroidX initializer details can change.

## Navigation 3 prerequisites and API

`koin-compose-navigation3` primarily adds `Module.navigation<T>`, scoped navigation entries and
`koinEntryProvider`; ViewModels can be injected inside an entry, but ViewModel scoping is not the
artifact's principal role.

Before adding it, confirm all three pieces in the consuming module:

```kotlin
plugins {
    alias(libs.plugins.kotlin.serialization)
}

dependencies {
    implementation(libs.koin.compose.navigation3)
    implementation(libs.kotlinx.serialization.core)
}
```

The alias names are illustrative; reuse the repository's existing aliases and verify current
coordinates against the
[official Navigation 3 integration](https://insert-koin.io/docs/reference/koin-compose/navigation3/).
If either the runtime or serialization plugin is absent, the integration selection is incomplete.

## Migrate from KSP

Treat the old KSP path as input to remove, not as a parallel fallback:

- Confirm the build meets the current Koin compiler-plugin, Kotlin compiler and Gradle wrapper
  requirements.
- Add the compiler plugin alias and its root `apply false`, then wire it in through the `<prefix>.koin`
  convention for every participating KMP module (or directly, for a module that stays outside it).
- Remove `koin-ksp-compiler`, Koin KSP arguments, generated source directories, metadata helpers and
  manual task dependencies. Remove the KSP plugin and catalog/version entries only when no other
  processor uses them.
- Keep `koin-annotations` only in annotation-using modules, and change it to `version.ref = "koin"`.
- Change `org.koin.android.annotation.KoinViewModel` imports to
  `org.koin.core.annotation.KoinViewModel` where present.
- Remove `org.koin.ksp.generated.*` imports and generated `.module` references. Add an
  `@KoinApplication(modules = [...])` entry point and use typed `startKoin<App>()`, retaining existing
  configuration such as `androidContext` and `workManagerFactory()`.
- When adopting the compiler DSL, import `org.koin.plugin.module.dsl.*` and replace constructor
  references such as `singleOf(::Service)` with typed forms such as `single<Service>()`. Leave
  classic DSL code alone when it is outside the migration.

Do not copy KSP generated-source or task-ordering workarounds into compiler-plugin setup. The
[migration guide](https://insert-koin.io/docs/migration/from-ksp-to-compiler-plugin/) is the source
for the current cleanup and typed-startup steps.

## Testing and verification

Prefer compiler validation for graphs covered by annotations or the compiler DSL. The legacy module
checker is deprecated. `koin-test` remains useful for injection, declarations, mocks and runtime
tests; `verify()` is limited to classic/runtime DSL edges the compiler cannot validate. Consult the
[official testing reference](https://insert-koin.io/docs/reference/koin-test/testing/) for current
test APIs.

For a convention, run all standard gates. For direct declarations, skip the included-build gate if
`build-logic` did not change. After removing KSP, include one clean assemble so stale generated output
cannot hide missing wiring:

```bash
./gradlew --stop
./gradlew -p build-logic :convention:check
./gradlew help
./gradlew assemble
./gradlew clean assemble
```

The included-build check validates registration, `help` catches plugin/classpath mistakes, and
`assemble` proves the compiler plugin and dependencies reach every participating source set. Do not
claim the KSP migration is complete until the clean assemble passes.

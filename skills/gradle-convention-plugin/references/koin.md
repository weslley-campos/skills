# Koin compiler setup and convention plugins

Use the Koin compiler plugin for Koin projects that meet its current Kotlin and Gradle
requirements. It provides compile-time graph validation for annotations and the compiler DSL, and
generates no visible source files. Recheck the live
[compiler-plugin setup](https://insert-koin.io/docs/setup/compiler-plugin/) and
[KSP migration guide](https://insert-koin.io/docs/migration/from-ksp-to-compiler-plugin/) before
editing: compatibility requirements and the independently versioned compiler plugin can move.

## One convention, one branch per module type

Koin's setup is the same in every module: the compiler plugin, `koin-core` and `koin-annotations`.
Only where the dependencies go differs. So use one `<prefix>.koin` convention. It applies the
compiler plugin, then adds the dependencies according to the module type it finds:

| Module type | Detected by | Dependencies |
|---|---|---|
| Kotlin Multiplatform: libraries, a Web launcher, a KMP Desktop launcher, the shared module iOS links | `KotlinMultiplatformExtension` | the `koin` bundle in `commonMain`, plus `koin-compose` and `koin-compose-viewmodel` when the module has the Compose compiler |
| Kotlin JVM: a Desktop launcher on `org.jetbrains.kotlin.jvm` | `KotlinJvmProjectExtension` | the `koin` bundle through `implementation` |
| Android application | `ApplicationExtension` | the `koin` bundle and `koin-android` through `implementation` |

Each module type registers exactly one of these extensions, so exactly one branch runs per module:

- With AGP 9's built-in Kotlin, an Android application registers `KotlinAndroidProjectExtension`,
  not the JVM one.
- The Android target of a KMP module, from the KMP Android library plugin, registers no
  project-level `android` extension. The KMP branch covers it.

The convention never applies Kotlin or Android itself. The module-type convention does that.
Applying Kotlin Multiplatform from the Koin convention breaks every Kotlin JVM module, and applying
the Android plugin would turn every consumer into an app.

**Plugin order matters.** `findByType` and `hasPlugin` check once, when the convention is applied.
So `<prefix>.koin` goes after the module-type convention, and after the Compose convention where the
module has one. Listed first, it silently adds no Koin dependencies.

Create the convention on the first module that needs Koin rather than waiting for a second consumer.
The shared surface is stable. Retrofitting a convention after several modules have hand-declared the
same compiler and dependency setup means migrating each of them later.

## Identify the module types first

Generate only the branches the build needs. List the module types that use Koin, or are about to:

```bash
rg -n "kotlin.multiplatform|kotlin.jvm|android.application|compose.compiler" build-logic --glob "*.kt"
rg -n "alias\(libs\.plugins\." --glob "*.gradle.kts" .
```

Map each Koin module to a row of the table above through its module-type convention. Then trim the
convention to match:

- **No Kotlin JVM module:** drop the JVM branch and its import.
- **No Android application, or one that does not start Koin:** drop the Android branch, and the
  `koin-android` catalog entry unless a KMP `androidMain` still uses it.
- **No Compose in the build** (no Compose compiler alias in the catalog): drop the Compose check. Its
  accessor would not compile.
- **iOS** has no Gradle launcher module. Koin for iOS lives in the shared KMP module's `iosMain`,
  which the KMP branch already covers.
- **A module type the table does not list**, such as a standalone `com.android.library`, gets a
  branch of its own on its own extension type (`LibraryExtension`). It never borrows another type's
  branch.

## Select integrations per module

Survey the catalog and consuming modules first:

```bash
rg -n "koin|compose|navigation|lifecycle|workmanager" \
    --glob "libs.versions.toml" --glob "*.gradle.kts" --glob "AndroidManifest.xml" .
```

Use exactly two interactions:

1. Show the relevant rows below as a markdown checklist, including whether each alias and
   prerequisite already exists. Ask for one free-text response such as `accept`, or
   `include: koin-compose; exclude: koin-annotations; add: ...`.
2. Restate the final per-convention and per-module dependency lists and catalog edits, then ask one
   explicit `Proceed` / `Adjust` confirmation before editing.

| Dependency | Where it goes | What it is for |
|---|---|---|
| `koin-core` | `koin` bundle, every branch | Koin runtime and module DSL |
| `koin-annotations` | `koin` bundle, every branch | `@Single`, `@Module`, `@ComponentScan`, `@Configuration`. The compiler plugin also reads other modules' definitions through these classes wherever `startKoin<T>` or `get<T>()` is called. Leave it out of the bundle only when the build uses no Koin annotations at all |
| `koin-compose` | KMP branch, when the module has the Compose compiler | `koinInject()`, `KoinApplication { }`, and the Compose bridge |
| `koin-compose-viewmodel` | same as `koin-compose` | `koinViewModel()` in composables |
| `koin-compose-viewmodel-navigation` | module-local `commonMain` | Koin ViewModel integration for Navigation 2 (`navigation-compose`) |
| `koin-core-viewmodel` | module-local `commonMain` | `@KoinViewModel` outside Compose; only where that API is used |
| `koin-test` | module-local `commonTest` | Koin test APIs; compiler validation is preferred, with `verify()` reserved for classic/runtime DSL gaps |
| `koin-android` | Android application branch; KMP `androidMain` only where `org.koin.android.*` APIs are used | `androidContext()` and the Android extensions |
| `koin-androidx-workmanager` | Android application module | Koin's WorkManager factory and worker definitions; also requires `koin-android`, `workManagerFactory()` startup configuration, and disabling WorkManager's default manifest initializer |

Navigation 3 needs no Koin artifact. Its own ViewModel entry decorator scopes ViewModels to each
entry, and the entry resolves them with `koinViewModel()` from `koin-compose-viewmodel`. Do not offer
`koin-compose-navigation3`. Offer `koin-compose-viewmodel-navigation` only to a module already on
Navigation 2.

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
koin-android = { module = "io.insert-koin:koin-android", version.ref = "koin" }
# Only when the build has Compose.
koin-compose = { module = "io.insert-koin:koin-compose", version.ref = "koin" }
koin-compose-viewmodel = { module = "io.insert-koin:koin-compose-viewmodel", version.ref = "koin" }

[bundles]
koin = ["koin-core", "koin-annotations"]

[plugins]
koin-compiler = { id = "io.insert-koin.compiler.plugin", version.ref = "koin-plugin" }
```

Every branch adds `koin-core` and `koin-annotations` together, so the catalog names the pair once as
a bundle, and each branch adds it with `implementation(libs.bundles.koin)`.

Optional Koin integrations use the same `koin` version unless their current official setup says
otherwise. Do not add a separate annotations version.

Declare the compiler plugin once at the root so it resolves exactly once for the whole build:

```kotlin
plugins {
    alias(libs.plugins.koin.compiler) apply false
}
```

That root declaration is the whole classpath story for Koin, and it is the one edit that is not
optional: the convention applies `koin.compiler` by id, and the id resolves against the consuming
build's plugin classpath, which the `apply false` line above owns.

Whether Koin also needs a `compileOnly` entry in `convention/build.gradle.kts` depends on what the
convention does with it, and the rule is easy to get backwards:

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

## The convention

This is the full convention for a build with all three module types and Compose. Generate only the
branches the survey found. It uses the `implementation` helper from `extensions/Dependencies.kt`
(see `conventions.md`):

```kotlin
import com.android.build.api.dsl.ApplicationExtension
import extensions.implementation
import extensions.libs
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.dependencies
import org.gradle.kotlin.dsl.findByType
import org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension
import org.jetbrains.kotlin.gradle.dsl.KotlinMultiplatformExtension

class KoinConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = libs.plugins.koin.compiler.get().pluginId)

        extensions.findByType<KotlinMultiplatformExtension>()?.apply {
            sourceSets.commonMain.dependencies {
                implementation(libs.bundles.koin)
                if (pluginManager.hasPlugin(libs.plugins.compose.compiler.get().pluginId)) {
                    implementation(libs.koin.compose)
                    implementation(libs.koin.compose.viewmodel)
                }
            }
        }
        extensions.findByType<KotlinJvmProjectExtension>()?.apply {
            dependencies {
                implementation(libs.bundles.koin)
            }
        }
        extensions.findByType<ApplicationExtension>()?.apply {
            dependencies {
                implementation(libs.bundles.koin)
                implementation(libs.koin.android)
            }
        }
        Unit
    }
}
```

- **`findByType` returns `null`** when the module has no such extension, so each block runs only
  on its own module type. Do not use `configure<T>`: it throws when `T` is missing, so
  `configure<ApplicationExtension>` would fail on every non-Android module.
- **`dependencies { }` in the JVM and Android blocks is the project's.** Neither
  `KotlinJvmProjectExtension` nor `ApplicationExtension` has a `dependencies` member.
  `KotlinMultiplatformExtension` does: the experimental top-level `kotlin { dependencies { } }`. So
  the KMP block goes through `sourceSets.commonMain.dependencies` and never through a bare
  `dependencies { }`.
- **`Unit` closes the expression body.** `with` returns its last expression, and `?.apply` returns
  the extension. Keep it when trimming branches.
- **The Compose check** reads the catalog's Compose compiler alias. Reuse the existing alias if it is
  named differently, and drop the check when the build has no Compose.
- **The extension types come from AGP and KGP.** Both are already `compileOnly` in
  `convention/build.gradle.kts` for the module-type conventions. The convention references no Koin
  type, so it needs no Koin artifact there.

## Registration and consumers

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

The `<prefix>.koin` id cannot coexist with ids that extend it, such as `<prefix>.koin-library` or
`<prefix>.koin-android`. The catalog turns both `.` and `-` into accessor segments, so
`libs.plugins.<prefix>.koin` becomes a group instead of a plugin, and `build-logic` stops compiling.
A build that already has per-type Koin conventions replaces them in one change: delete their
classes, registrations and catalog ids, add `<prefix>.koin`, and switch every consumer's alias.

Every Koin module applies the convention after its module-type convention, and after its Compose
convention where it has one. It declares no Koin compiler alias and no `koin-core`,
`koin-annotations` or `koin-android` lines of its own. Show only the module types the build has:

```kotlin
// KMP library module
plugins {
    alias(libs.plugins.<prefix>.multiplatform.library)
    alias(libs.plugins.<prefix>.compose.library)
    alias(libs.plugins.<prefix>.koin)
}
```

```kotlin
// Kotlin JVM Desktop launcher
plugins {
    alias(libs.plugins.<prefix>.jvm.application)
    alias(libs.plugins.<prefix>.koin)
}
```

```kotlin
// Android application module
plugins {
    alias(libs.plugins.<prefix>.android.application)
    alias(libs.plugins.<prefix>.koin)
}
```

Follow the four catalog, registration and root-classpath edits in `SKILL.md`.

## Starting Koin on each platform

Every app entry point starts Koin once, before the first injection, with the root module as the type
argument. Tag that module `@Configuration`:

```kotlin
@Configuration
@Module(includes = [FeatureModule::class])
@ComponentScan
class AppModule
```

`startKoin<AppModule>` is the typed start from `org.koin.plugin.module.dsl`, shipped in `koin-core`
(`org.koin.core.context.startKoin` has no type parameter). The compiler plugin rewrites it where it
is called, so the module that calls it must apply `<prefix>.koin`. That call is also the
compilation's Koin entry point, so no `@KoinApplication` class is needed.

The rewrite does not load the type argument as a module. It loads the modules tagged
`@Configuration`:

- **`@Module`** only marks a class as a Koin module. It is loaded when something references it:
  another module's `includes`, or an explicit module list.
- **`@Configuration`** marks a module that the typed start loads automatically. Tag only the root,
  because its `includes` bring in the rest.

Without `@Configuration` on `AppModule`, the call still compiles, and so does every module. Koin then
starts with no modules, and the first injection throws `NoDefinitionFoundException` at runtime.

To name the modules explicitly instead, use one of these. Neither needs `@Configuration`:

- `@KoinApplication(modules = [AppModule::class]) object App` with `startKoin<App>()`
- the untyped `startKoin { module<AppModule>() }`

Every launcher repeats that list, so prefer `@Configuration` unless the build already starts Koin
one of these ways.

Start Koin outside any composable lambda. Composition can re-run that lambda, and a second
`startKoin` throws. In the launchers below, `App()` stands for the shared root composable.

### Android

Start Koin in the `Application` subclass, registered in the manifest with
`android:name=".MainApplication"`:

```kotlin
import android.app.Application
import org.koin.android.ext.koin.androidContext
import org.koin.plugin.module.dsl.startKoin

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin<AppModule> {
            androidContext(this@MainApplication)
        }
    }
}
```

### Web (Wasm)

The web launcher is a KMP module, so the KMP branch of `<prefix>.koin` covers it. It starts Koin at
the top of its `main()`:

```kotlin
plugins {
    alias(libs.plugins.<prefix>.web.application)
    alias(libs.plugins.<prefix>.koin)
}
```

```kotlin
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.window.ComposeViewport
import kotlinx.browser.document
import org.koin.core.logger.Level
import org.koin.plugin.module.dsl.startKoin

@OptIn(ExperimentalComposeUiApi::class)
fun main() {
    startKoin<AppModule> {
        printLogger(Level.DEBUG)
    }

    ComposeViewport(viewportContainer = document.body!!) {
        App()
    }
}
```

### Desktop (JVM)

The Desktop launcher applies `<prefix>.koin` like any other module. A launcher on the Kotlin JVM
plugin gets the JVM branch, and a KMP launcher gets the KMP branch. It starts Koin at the top of
`main()`, before `application { }`:

```kotlin
plugins {
    alias(libs.plugins.<prefix>.jvm.application)
    alias(libs.plugins.<prefix>.koin)
}
```

```kotlin
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application
import org.koin.plugin.module.dsl.startKoin

fun main() {
    startKoin<AppModule>()
    application {
        Window(onCloseRequest = ::exitApplication, title = "<App name>") {
            App()
        }
    }
}
```

A dependency on the shared module is not enough for the launcher. The compiler plugin rewrites
`startKoin<T>` and validates `get<T>()` in the module that calls them, and it reads the definitions
from other modules through `koin-annotations` on that module's classpath. The JVM branch brings both
the plugin and the annotations.

### iOS

Use the untyped start, with the compiler-DSL `module<T>()`, in the shared module's `iosMain`:

```kotlin
// <shared>/src/iosMain/kotlin/<package>/Koin.kt
import org.koin.core.context.startKoin
import org.koin.plugin.module.dsl.module

fun initKoin() {
    startKoin { module<AppModule>() }
}
```

Call it from the SwiftUI `App` initializer, before any Compose view controller is created:

```swift
import SwiftUI
import <SharedFramework>

@main
struct iOSApp: App {
    init() {
        KoinKt.doInitKoin()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Swift sees a top-level Kotlin function as a static method on a class named after its file
(`Koin.kt` becomes `KoinKt`). Kotlin/Native also prefixes functions whose names start with `init`
with `do`, so the call is `doInitKoin()`. Renaming the file changes the Swift call.

Do not use typed startup here. With compiler plugin 1.2.1, a typed start in the iOS compilation
(`startKoin<AppModule>()` or a `@KoinApplication`) makes the plugin validate `get<T>()` call sites
there. It then reports `KOIN-D002 Missing definition` for a valid lookup of a definition from another
Gradle module, such as a `MainViewController` reading an aggregator. JVM and Wasm accept the same
lookup. The untyped start loads the same modules without triggering it. Recheck this when upgrading
the plugin.

## Direct declarations, for what stays outside a convention

A module that cannot use the convention — one whose module type has no branch, or one that
deliberately opts out — wires Koin directly. It keeps its existing module-type plugin, adds the
compiler plugin, and declares only what it uses:

```kotlin
plugins {
    alias(libs.plugins.<existing-kmp-module-type-plugin>)
    alias(libs.plugins.koin.compiler)
}

kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation(libs.koin.core)
            implementation(libs.koin.annotations)
        }
    }
}
```

A non-KMP module does the same with its ordinary `dependencies { implementation(...) }`. Do not copy
Android, Compose, navigation, test or WorkManager dependencies from one module into another merely
for symmetry.

## Configuring the compiler plugin (optional)

The convention above only applies the plugin, which is enough for most builds and needs no
`compileOnly` entry. Configure the extension from a convention only when the build has a policy to
set — most often `logSeverity = "info"` for a build using `allWarningsAsErrors`. The extension is
`org.koin.compiler.plugin.KoinGradleExtension`, registered under the name `koinCompiler`:

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

Read the defaults off `KoinGradleExtension` in the version actually resolved; the published options
table has trailed the extension before.

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

`userLogs = true` emits a line per detected component, and `logSeverity` defaults to `"warning"`, so
those lines arrive as compiler warnings on every compilation of every module — noise on a large graph,
and a hard failure under `allWarningsAsErrors` or `-Werror`. Setting `logSeverity = "info"` demotes
them and leaves real `KOIN-Dxxx` diagnostics at their own severity. Never turn `userLogs` on without
deciding `logSeverity`.

In a convention, restating a default is defensible as pinning: a value written down cannot be
changed underneath the build by an upstream default that moves in a later Koin release. Either pin
every field or none, so a reader can tell which lines are decisions — and leave `strictSafety` out
either way.

## WorkManager, only when requested

This section applies only when `koin-androidx-workmanager` was selected in the checklist. Without
that dependency, do not add `workManagerFactory()` or the manifest change: the factory is an
extension from that artifact and does not resolve without it.

The artifact is not sufficient by itself. `koin-android` already comes from the Android application
branch of `<prefix>.koin`, so the Android application adds only:

```kotlin
dependencies {
    implementation(libs.koin.androidx.workmanager)
}
```

Add Koin's worker factory to the existing typed startup:

```kotlin
startKoin<AppModule> {
    androidContext(this@MainApplication)
    workManagerFactory()
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

## Delegating ViewModels and circular dependencies

When `KOIN-D004` reports `<Screen>ViewModel → <Screen>ViewModel`, inspect annotation bindings before
changing Gradle dependencies. The diagnostic describes Koin's object graph, not the Gradle module
graph: an app and a feature both depending on a shared navigation module is valid, and a Kotlin
import alone creates no DI binding.

In `ViewModel(), Navigator by navigator`, the class both consumes and implements `Navigator`. Plain
`@KoinViewModel` automatically binds implemented interfaces, so the ViewModel becomes another
provider of `Navigator` beside the real one. If resolution selects the ViewModel for its own
constructor parameter, it creates a self-cycle.

When creating or updating a ViewModel that constructor-injects and delegates an interface, bind it
explicitly to its own class unless the extra binding is intended:

```kotlin
@KoinViewModel(binds = [<Screen>ViewModel::class])
class <Screen>ViewModel(
    val navigator: Navigator,
) : ViewModel(), Navigator by navigator
```

Keep the real provider's plain `@Single`, which binds `Navigator` automatically. Explicit
self-binding replaces automatic interface binding while preserving constructor injection and
delegation. `binds = []` also suppresses automatic bindings, but self-binding states the intent.
`Lazy<Navigator>` does not remove an unintended binding.

Sibling ViewModels with the same unintended binding can compile cleanly: in compiler plugin 1.2.1 the
cycle checker keeps only the first provider it discovers per interface. Fix them too, but report that
cleanup separately from the change the reported error required. Verify by compiling the module that
holds the Koin entry point (for example `:<android-app>:compileDebugKotlin`); a library without an
entry point skips graph validation.

See Koin's [automatic or specific binding documentation](https://insert-koin.io/docs/reference/koin-annotations/definitions/#automatic-or-specific-binding)
and the [delegation issue](https://github.com/InsertKoinIO/koin-compiler-plugin/issues/12).

## Migrate from KSP

Treat the old KSP path as input to remove, not as a parallel fallback:

- Confirm the build meets the current Koin compiler-plugin, Kotlin compiler and Gradle wrapper
  requirements.
- Add the compiler plugin alias and its root `apply false`, then wire it in through `<prefix>.koin`
  (or directly, for a module whose type has no branch).
- Remove `koin-ksp-compiler`, Koin KSP arguments, generated source directories, metadata helpers and
  manual task dependencies. Remove the KSP plugin and catalog/version entries only when no other
  processor uses them.
- Change `koin-annotations` to `version.ref = "koin"`. It now reaches every Koin module through the
  `koin` bundle, so delete the module-level `koin-annotations` lines.
- Change `org.koin.android.annotation.KoinViewModel` imports to
  `org.koin.core.annotation.KoinViewModel` where present.
- Remove `org.koin.ksp.generated.*` imports and generated `.module` references. Tag the root module
  `@Configuration` and replace `<App>KoinApp.startKoin { modules(AppModule().module) }` with the
  typed `startKoin<AppModule> { }` from `org.koin.plugin.module.dsl`. Carry over the rest of the
  startup configuration as-is, for example `androidContext` or `printLogger`. Delete the
  `@KoinApplication` object, since nothing references it anymore. iOS keeps the untyped start; see
  **Starting Koin on each platform**. Keep `workManagerFactory()` only where it was already there.
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

A green `assemble` is not the same as compile-time graph validation. In a compilation with no Koin
entry point the plugin applies, runs, and reports `[Koin] compile-safety validation skipped — no Koin
entry point in this compilation`; validation only does work in the module that declares the graph.
Do not report the setup as "validated by the compiler" on the strength of library modules alone.

Launch every app once after wiring or changing the startup. A typed `startKoin<AppModule>` whose
root module lacks `@Configuration` compiles cleanly and crashes at the first injection; only a run
shows it.

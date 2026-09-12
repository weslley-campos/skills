# Scaffold: the `build-logic` included build

Scaffold files to create, root files to edit, and the catalog entries they all depend on. Placeholders in
`<angle brackets>` come from step 2 of `references/init.md`.

Contents:
- [1. build-logic/settings.gradle.kts](#1-build-logicsettingsgradlekts)
- [2. build-logic/convention/build.gradle.kts](#2-build-logicconventionbuildgradlekts)
- [3. Root settings.gradle.kts](#3-root-settingsgradlekts-edit)
- [4. Root build.gradle.kts](#4-root-buildgradlekts-edit)
- [5. Version catalog](#5-version-catalog)
- [6. .gitignore](#6-gitignore)

---

## 1. `build-logic/settings.gradle.kts`

An included build is a build in its own right: it resolves its own plugins and dependencies, and
inherits none of the root's `dependencyResolutionManagement`. That is why the catalog is declared
again here rather than shared.

```kotlin
/**
 * Convention plugins, used to keep a single source of truth for common module configurations.
 * @see <a href="https://github.com/android/nowinandroid/blob/main/build-logic/README.md">Convention Plugins</a>
 */

pluginManagement {
    repositories {
        gradlePluginPortal()
        google()
    }
}

dependencyResolutionManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
    }
    versionCatalogs {
        create("libs") {
            from(files("../gradle/libs.versions.toml"))
        }
    }
}

rootProject.name = "build-logic"
include(":convention")
```

The `content { }` filter on `google()` is not decoration: without it Gradle asks Google for every
artifact in the build before falling through to Maven Central, which is a measurable cost on a cold
cache. Mirror whatever filtering the root `settings.gradle.kts` already uses so the two stay
consistent.

Runtime flags such as the build cache, configuration cache and parallelism come from the root Gradle
invocation, including when it configures the included build. Put desired defaults in the root
`gradle.properties`; do not create an included-build copy. Configure-on-demand is incubating and is
not a default recommendation.

## 2. `build-logic/convention/build.gradle.kts`

```kotlin
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    `kotlin-dsl`
}

group = "<root.package>.buildlogic"

/**
 * Configure the build-logic plugins to target JDK <N>.
 * This matches the JDK used to build the project, and is not related to what is running on device.
 */
java {
    sourceCompatibility = JavaVersion.VERSION_<N>
    targetCompatibility = JavaVersion.VERSION_<N>
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_<N>
    }
}

/**
 * The generated `LibrariesForLibs` accessors, so convention plugins can use typed `libs.*` from
 * gradle/libs.versions.toml — Gradle does not hand them to plugin classes on its own.
 * See https://github.com/gradle/gradle/issues/15383.
 *
 * The class is looked up by name on purpose: Gradle generates it for *this* script's classpath, and
 * naming `libs` here is what the IDE fails to resolve.
 */
val enableTypeAccessors: ConfigurableFileCollection = files(
    Class.forName("org.gradle.accessors.dm.LibrariesForLibs").protectionDomain.codeSource.location
)

/**
 * The Gradle plugins the convention plugins apply by id. `compileOnly`, so they are visible while
 * the scripts compile but are *not* republished on this project's runtime classpath. The consuming
 * build gets them from the root `plugins { ... apply false }` block, which resolves each one exactly
 * once for the whole build — one AGP, one KGP, one classloader.
 */
dependencies {
    compileOnly(enableTypeAccessors)
    compileOnly(libs.android.gradle.plugin)
    compileOnly(libs.kotlin.gradle.plugin)
}

/**
 * Convention plugins are classes, so each id has to be registered against its implementation — the
 * filename means nothing here. Ids come from the catalog so that this registration and the
 * `alias(libs.plugins.<prefix>.*)` calls in the modules cannot drift apart.
 */
gradlePlugin {
    plugins {
        register("android-application") {
            id = libs.plugins.<prefix>.android.application.get().pluginId
            implementationClass = "AndroidApplicationConventionPlugin"
        }
        // ...one register block per convention plugin
    }
}

tasks {
    validatePlugins {
        enableStricterValidation = true
        failOnWarning = true
    }
}
```

**Choosing `<N>`.** This is the JDK that compiles `build-logic`, not the JVM target the app ships.
Choose it from the project's Gradle daemon, toolchain and CI requirement first, within the Gradle
version's supported range. The shell JDK printed by the survey is diagnostic only: do not lower the
target merely because an accidental shell happens to run an older JDK.

**`validatePlugins`.** Stricter validation turns plugin authoring mistakes (missing task input
annotations, unserialisable fields) into build failures instead of warnings that scroll past. It is
cheap insurance in a directory that half the team will never open.

## 3. Root `settings.gradle.kts` (edit)

Add one line, inside the existing `pluginManagement { }`:

```kotlin
pluginManagement {
    includeBuild("build-logic")
    repositories { /* unchanged */ }
}
```

Inside `pluginManagement`, and nowhere else. An `includeBuild` at the top level of the settings file
contributes dependency substitutions but not plugin ids, so `alias(libs.plugins.<prefix>...)` fails
with "Plugin ... was not found", which reads like a catalog problem and is not one.

`pluginManagement` must come before `dependencyResolutionManagement` and before any `include(...)`.
Older Gradle versions additionally require it before *any* other statement in the file — if the
build fails complaining about the block's position, move it to the very top rather than debating it.

## 4. Root `build.gradle.kts` (edit)

```kotlin
plugins {
    /**
     * Declared here, applied nowhere. This resolves each plugin exactly once for the whole build,
     * so every subproject — and the convention plugins in build-logic, which depend on them
     * `compileOnly` — share a single AGP and a single KGP in one classloader.
     *
     * The Android and Kotlin plugins are applied by the convention plugins in build-logic; modules
     * only ask for them by id, without a version.
     */
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.multiplatform.library) apply false
    alias(libs.plugins.kotlin.multiplatform) apply false
    // ...every third-party plugin any module or convention plugin uses
}
```

Every plugin a convention plugin applies must appear here, `apply false`. This is the block that
makes the `compileOnly` in step 3 work: `compileOnly` deliberately leaves the runtime classpath
empty, and this is what fills it, once.

The convention plugins themselves do **not** go in this block — they come from the included build
and are applied per module.

## 5. Version catalog

```toml
[versions]
# build
agp = "<agp version>"
kotlin = "<kotlin version>"
jvm-target = "<the JVM bytecode level the app ships, e.g. 11, 17, 21>"

# android
android-compile-sdk = "<n>"
android-min-sdk = "<n>"
android-target-sdk = "<n>"

# app (single-application builds only)
app-version-code = "1"
app-version-name = "1.0"

[libraries]
# ================================================================
# Dependencies of the included build-logic
# ================================================================
android-gradle-plugin = { module = "com.android.tools.build:gradle", version.ref = "agp" }
kotlin-gradle-plugin = { module = "org.jetbrains.kotlin:kotlin-gradle-plugin", version.ref = "kotlin" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
android-library = { id = "com.android.library", version.ref = "agp" }
multiplatform-library = { id = "com.android.kotlin.multiplatform.library", version.ref = "agp" }
kotlin-multiplatform = { id = "org.jetbrains.kotlin.multiplatform", version.ref = "kotlin" }

# ================================================================
#  Plugins defined by this project
# ================================================================
<prefix>-android-application = { id = "<prefix>.android.application" }
<prefix>-android-library = { id = "<prefix>.android.library" }
<prefix>-multiplatform-library = { id = "<prefix>.multiplatform.library" }
```

Keep only the catalog entries and root `apply false` lines for the module types you actually
decided on in step 2 of `references/init.md` — a build with no classic Android library module needs neither the
`android-library` rows here nor its `apply false` line in the root build file above.
Likewise, omit the app-version entries when there are multiple application modules; their identity
and version values remain in each module.

Three things worth understanding rather than copying:

- **`jvm-target` is one entry, read twice.** AGP wants a `JavaVersion` for `compileOptions`, Kotlin
  wants a `JvmTarget` for `compilerOptions`. Two catalog entries for one number is how they drift.
  `extensions/Project.kt` converts the single string into both types.

- **The convention plugin entries have no version.** They resolve from the included build, and
  giving them a version makes Gradle look for them in a repository instead. The banner comment
  earns its place: the next person will otherwise "fix" the missing version.

- **`android-gradle-plugin` is the plugin's *artifact*, not its marker.** `com.android.tools.build:gradle`
  is what you compile `ApplicationExtension` against. It is a `[libraries]` entry even though it is
  a plugin, because `build-logic` depends on it as a library.

## 6. `.gitignore`

Add `build-logic/**/build/` and `build-logic/.gradle/` if the existing rules are anchored to the
root (`/build`, `/.gradle`) rather than global. An included build produces its own build directories
and they should not be committed.

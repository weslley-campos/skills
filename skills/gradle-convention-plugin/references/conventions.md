# The convention plugins and their shared extensions

Contents:
- [Layout and why the split](#layout-and-why-the-split)
- [extensions/Project.kt — the catalog bridge](#extensionsprojectkt--the-catalog-bridge)
- [extensions/Dependencies.kt — adding dependencies from a plugin class](#extensionsdependencieskt--adding-dependencies-from-a-plugin-class)
- [extensions/Android.kt — the shared configuration](#extensionsandroidkt--the-shared-configuration)
- [AndroidApplicationConventionPlugin](#androidapplicationconventionplugin)
- [AndroidLibraryConventionPlugin (classic)](#androidlibraryconventionplugin-classic)
- [MultiplatformLibraryConventionPlugin](#multiplatformlibraryconventionplugin)
- [AGP 8 vs AGP 9](#agp-8-vs-agp-9)
- [Verify the types before you commit to them](#verify-the-types-before-you-commit-to-them)

---

## Layout and why the split

```
convention/src/main/kotlin/
├── AndroidApplicationConventionPlugin.kt      default package — no `package` line
├── MultiplatformLibraryConventionPlugin.kt
└── extensions/
    ├── Project.kt                             catalog access, JVM target
    ├── Dependencies.kt                        implementation/debugImplementation for plugin classes
    └── Android.kt                             the actual Android configuration
```

Plugin classes sit in the **default package**. `implementationClass` in `gradlePlugin { }` is a
fully-qualified name, so a package would have to be repeated there; the convention in this ecosystem
(and in Now in Android) is to skip it. The helpers do get a package, because they are imported.

The rule that keeps this from rotting: **a plugin class contains only what is unique to its module
type.** The moment two plugin classes contain the same line, that line belongs in `extensions/`.
Applied honestly, a convention plugin ends up being four or five lines, which is the point — it
makes "what is different about an application module?" answerable by reading one short file.

## `extensions/Project.kt` — the catalog bridge

```kotlin
package extensions

import org.gradle.accessors.dm.LibrariesForLibs
import org.gradle.api.JavaVersion
import org.gradle.api.Project
import org.gradle.kotlin.dsl.the
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

/**
 * Typed access to gradle/libs.versions.toml. Gradle injects `libs` into build scripts but not into
 * plugin classes, so this is the single place that bridges it — every convention plugin reads the
 * catalog through here. See the `enableTypeAccessors` note in build-logic/convention/build.gradle.kts.
 */
internal val Project.libs: LibrariesForLibs get() = the<LibrariesForLibs>()

/**
 * The bytecode level the app ships, from the `jvm-target` catalog entry. Named to not collide with
 * the `jvmTarget` property inside Kotlin's `compilerOptions { }`, where this is read.
 */
internal val Project.kotlinJvmTarget: JvmTarget
    get() = JvmTarget.fromTarget(libs.versions.jvm.target.get())

/** The same level as a [JavaVersion], for AGP's `compileOptions`. */
internal val Project.javaCompatibility: JavaVersion
    get() = JavaVersion.toVersion(libs.versions.jvm.target.get())
```

The naming detail is worth keeping: inside `compilerOptions { }` there is already a property called
`jvmTarget`, and an extension property with the same name shadows confusingly at the exact point of
use. `kotlinJvmTarget` costs nothing and removes the trap.

Everything is `internal` — `build-logic` is not a published library, and `internal` keeps the IDE's
completion inside the convention plugins honest.

## `extensions/Dependencies.kt` — adding dependencies from a plugin class

Gradle generates the `implementation(...)` accessors for build *scripts*, the same way it generates
`libs` — a plugin class gets neither. The only form available there is `add("implementation", ...)`,
and once several convention plugins spell a configuration name as a string, a misspelling surfaces as
an unknown-configuration failure during configuration, from a line no compiler ever checked:

```kotlin
package extensions

import org.gradle.api.artifacts.Dependency
import org.gradle.api.artifacts.dsl.DependencyHandler

internal fun DependencyHandler.implementation(dependency: Any): Dependency? =
    add("implementation", dependency)

/** Android only: AGP is what creates the per-variant `debugImplementation` configuration. */
internal fun DependencyHandler.debugImplementation(dependency: Any): Dependency? =
    add("debugImplementation", dependency)
```

These are for the classic `dependencies { }` handler only. A Kotlin Multiplatform source set has its
own `implementation(...)` inside `commonMain.dependencies { }` and needs none of this.

## `extensions/Android.kt` — the shared configuration

```kotlin
package extensions

import com.android.build.api.dsl.CommonExtension
import com.android.build.api.dsl.KotlinMultiplatformAndroidLibraryTarget
import javax.lang.model.SourceVersion
import org.gradle.api.Project
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.withType
import org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension
import org.jetbrains.kotlin.gradle.dsl.KotlinMultiplatformExtension

/**
 * The package root of the whole build and the base of every module's [androidNamespace].
 */
internal const val ROOT_PACKAGE = "<root.package>"

/** Licence files that several dependencies ship and that must not collide when packaged. */
private const val EXCLUDED_RESOURCES = "/META-INF/{AL2.0,LGPL2.1}"

/**
 * The Android defaults for a module on the classic AGP DSL — `com.android.application` and
 * `com.android.library`, which both create a [CommonExtension].
 *
 * `targetSdk`, the application identity and the release build type are not here: they exist on the
 * application DSL alone, so the application convention plugin keeps them.
 */
internal fun Project.configureAndroid() {
    extensions.configure<CommonExtension> {
        namespace = androidNamespace
        compileSdk = androidCompileSdk
        defaultConfig.minSdk = androidMinSdk

        compileOptions.apply {
            sourceCompatibility = javaCompatibility
            targetCompatibility = javaCompatibility
        }
        packaging.resources.excludes += EXCLUDED_RESOURCES
    }

    // AGP 9 provides the project-level `kotlin` extension through its built-in Kotlin support.
    extensions.configure<KotlinAndroidProjectExtension> {
        compilerOptions {
            jvmTarget.set(kotlinJvmTarget)
        }
    }
}

/**
 * The module's Android namespace — the package of its generated `R`, and what relative names in
 * AndroidManifest.xml resolve against. Derived when the existing namespace follows the path rule.
 *
 * Every module appends its Gradle path, so `:app` is `<root.package>.app` and `:feature:home` is
 * `<root.package>.feature.home`. A single-application convention may override its namespace with
 * [ROOT_PACKAGE]; multiple applications keep distinct derived or explicit namespaces.
 */
internal val Project.androidNamespace: String
    get() = (listOf(ROOT_PACKAGE) + path.split(":").filter(String::isNotEmpty).map { packageSegment(it) })
        .joinToString(".")

/** Preserve valid segments exactly; reject anything that would need a lossy rewrite. */
private fun Project.packageSegment(pathSegment: String): String {
    require(SourceVersion.isIdentifier(pathSegment) && !SourceVersion.isKeyword(pathSegment)) {
        "Cannot derive Android namespace for $path: '$pathSegment' is not a valid Java package identifier"
    }
    return pathSegment
}

internal val Project.androidCompileSdk: Int
    get() = libs.versions.android.compile.sdk.get().toInt()

internal val Project.androidMinSdk: Int
    get() = libs.versions.android.min.sdk.get().toInt()

internal val Project.androidTargetSdk: Int
    get() = libs.versions.android.target.sdk.get().toInt()

internal val Project.appVersionCode: Int
    get() = libs.versions.app.version.code.get().toInt()

internal val Project.appVersionName: String
    get() = libs.versions.app.version.name.get()
```

The last three imports above — `KotlinMultiplatformAndroidLibraryTarget`, `withType`, and `KotlinMultiplatformExtension`
— go unused in this snippet; they serve `configureLibrary()`, shown later in this file, and are only
needed if the build has a multiplatform module.

**On the derived namespace.** This is the single highest-value line in the whole setup and also the
one most likely to break an existing project, so check it against the survey before adopting it. If
the modules' current namespaces already follow `<root>.<path>`, deriving them removes a per-module
declaration forever. If they do not — a module at `:core:ui` whose namespace is
`com.example.designsystem` — then either rename the namespace (a real change: it moves the generated
`R` class, so every `import com.example.designsystem.R` has to move with it) or keep an override.
Say which one you are doing and why; do not silently rename a namespace, because the compile error
it causes appears in files that have nothing to do with the build.

**On `packageSegment`.** Gradle paths allow names such as `sign-up`, `2fa` and Java keywords; package
segments do not. `SourceVersion` uses the JDK's identifier and keyword rules and preserves every
valid segment exactly. An unsafe path fails clearly instead of collapsing with another path after
punctuation or case is removed. Rename that module, or keep its existing namespace explicit; do not
invent a normalisation rule.

## `AndroidApplicationConventionPlugin`

```kotlin
import com.android.build.api.dsl.ApplicationExtension
import extensions.ROOT_PACKAGE
import extensions.androidTargetSdk
import extensions.appVersionCode
import extensions.appVersionName
import extensions.configureAndroid
import extensions.libs
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure

/** Convention for the sole Android application module in a single-application build. */
class AndroidApplicationConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = libs.plugins.android.application.get().pluginId)
        configureAndroid()

        extensions.configure<ApplicationExtension> {
            namespace = ROOT_PACKAGE
            defaultConfig {
                applicationId = ROOT_PACKAGE
                targetSdk = androidTargetSdk
                versionCode = appVersionCode
                versionName = appVersionName
            }

            buildFeatures {
                compose = true
            }

            buildTypes {
                release {
                    isMinifyEnabled = false
                    proguardFiles(
                        getDefaultProguardFile("proguard-android-optimize.txt"),
                        "proguard-rules.pro",
                    )
                }
            }
        }
    }
}
```

This is the **single-application** template: its namespace, application id and version are one
build-wide identity. If the survey finds multiple Android application modules, omit the
`ROOT_PACKAGE`, `appVersionCode` and `appVersionName` imports and their four assignments above.
Keep each module's `namespace`, `applicationId`, `versionCode` and `versionName` in that module;
`targetSdk` may remain in the convention. Omit the matching app-version catalog entries and helper
properties too. A conforming namespace can instead use the distinct derived `<root>.<module path>`
value from `configureAndroid()`.

Apply plugins **by id read from the catalog**, not by a hardcoded string and not by class. The id
comes from the same catalog entry the root `apply false` block uses, so there is exactly one place
where "which AGP plugin" is decided.

`buildFeatures { compose = true }` belongs here only if every module of this type uses Compose. If
Compose is optional across the build, it is its own convention plugin (`<prefix>.compose`) rather
than a flag on this one — that keeps "is this module a Compose module?" visible in the module's
`plugins { }` block instead of hidden in build-logic. Note that the flag alone compiles nothing: the
Compose compiler is a separate KGP plugin, and `references/compose.md` covers both, along with the
dependency list that is the real content of a Compose convention.

## `AndroidLibraryConventionPlugin` (classic)

For `com.android.library` modules — the ordinary, non-multiplatform kind. Same `CommonExtension`
DSL as the application, so `configureAndroid()` covers essentially all of it:

```kotlin
import com.android.build.api.dsl.LibraryExtension
import extensions.configureAndroid
import extensions.libs
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure

class AndroidLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = libs.plugins.android.library.get().pluginId)
        configureAndroid()

        extensions.configure<LibraryExtension> {
            defaultConfig.testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        }
    }
}
```

Unlike the application plugin, nothing registers this one by default: it needs an `android-library`
catalog `[plugins]` entry, a `<prefix>-android-library` convention id, a matching `register(...)` block
in `convention/build.gradle.kts`, and a root `apply false` line — see `references/scaffold.md` for the
catalog and root-build entries.

A library has no `applicationId`, no `versionCode`, and — importantly — should not set `targetSdk`:
it is a property of the application that ships the library, and AGP deprecated it on libraries for
exactly that reason.

## `MultiplatformLibraryConventionPlugin`

A Kotlin Multiplatform Android library is **a different DSL**, not a variation on the one above.
`com.android.kotlin.multiplatform.library` puts no extension on the project at all: its DSL is a
Kotlin target hanging off `kotlin`, which is what build scripts reach through `kotlin { android { } }`.
It declares `namespace`, `compileSdk`, `minSdk` and `packaging` with the same names as
`CommonExtension` and meets it at no supertype, so the assignments read alike but cannot be shared.

```kotlin
import extensions.configureIosFramework
import extensions.configureLibrary
import extensions.libs
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply

/**
 * Convention for a Kotlin Multiplatform library module — the Android target, the Apple targets and
 * the framework they produce. Modules keep their other targets and their dependencies.
 */
class MultiplatformLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = libs.plugins.kotlin.multiplatform.get().pluginId)
        apply(plugin = libs.plugins.multiplatform.library.get().pluginId)
        configureLibrary()
        configureIosFramework()
    }
}
```

with, in `extensions/Android.kt`:

```kotlin
/**
 * The Android defaults for a Kotlin Multiplatform library — everything a multiplatform module needs,
 * so its convention plugin has nothing left to configure.
 *
 * Separate from [configureAndroid] because this DSL is a Kotlin target, not a project extension.
 * Note the name: a plain `com.android.library` module is on the classic DSL and calls
 * [configureAndroid], not this.
 */
internal fun Project.configureLibrary() {
    extensions.configure<KotlinMultiplatformExtension> {
        targets.withType<KotlinMultiplatformAndroidLibraryTarget>().configureEach {
            namespace = androidNamespace
            compileSdk = androidCompileSdk
            minSdk = androidMinSdk
            packaging.resources.excludes += EXCLUDED_RESOURCES

            // No `compileOptions` counterpart: this DSL has none, since it compiles no Java unless
            // the module calls `withJava()`. The JVM target comes off the target itself.
            compilerOptions {
                jvmTarget.set(kotlinJvmTarget)
            }

            androidResources {
                enable = true
            }
            withHostTest {
                isIncludeAndroidResources = true
            }
            withDeviceTestBuilder {
                sourceSetTreeName = "test"
            }.configure {
                instrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
            }
        }
    }
}
```

`targets.withType<...>().configureEach { }` rather than a direct lookup: the Android target may not
exist at the moment the plugin is applied, and `configureEach` is lazy, which is also what keeps the
configuration cache happy.

and, in `extensions/Ios.kt`:

```kotlin
/**
 * The name Xcode links against — the Swift `import <FrameworkName>`, and the product that
 * `embedAndSignAppleFrameworkForXcode` copies into the app bundle. It is fixed by the Xcode project,
 * not derived from the Gradle path, so changing it here means changing the Swift import too.
 */
private const val IOS_FRAMEWORK_NAME = "<FrameworkName>"

internal fun Project.configureIosFramework() {
    extensions.configure<KotlinMultiplatformExtension> {
        listOf(
            iosArm64(),
            iosSimulatorArm64(),
        ).forEach { iosTarget ->
            iosTarget.binaries.framework {
                baseName = IOS_FRAMEWORK_NAME
                isStatic = true
            }
        }
    }
}
```

The block is the same three lines in every multiplatform module that ships to Apple, and the values
in it are build-wide rather than module-wide, which is what earns it a place in the convention. Read
all three out of the module before moving it, because the template cannot know them:

- **The target list** is whatever the module already declares. A module with `iosX64()` for Intel
  simulators keeps it; do not add or drop targets while moving the block, or the move stops being a
  move and starts being a change to what the build produces.
- **The framework name** belongs to the Xcode side. `grep -rn "^import " <ios-app-dir>` names it, and
  the pbxproj build phase names the Gradle task that feeds it. Deriving it from the module path
  breaks the Swift import.
- **`isStatic`** is a linking decision the Xcode project was set up around. Copy the module's value.

One name for every module on this convention is the ceiling: a second multiplatform module would
build a second binary under the same name, and Xcode embeds one. When a second one appears, derive
the name per module the way `androidNamespace` is derived, and update the Xcode project to match.

If some multiplatform modules ship no Apple targets at all, this does not belong in the base
convention — give it its own `<prefix>.ios` add-on applied next to the library convention, the shape
`references/compose.md` describes. A module that gains iOS targets it never asked for compiles Kotlin
for two platforms nobody consumes.

Still deliberately **not** in this plugin: JVM and other targets, and `sourceSets { }` dependencies.
Those are what makes a multiplatform module itself, and hiding them in build-logic makes modules
harder to read for no gain.

## AGP 8 vs AGP 9

The templates above are written for **AGP 9**. On AGP 8 three things differ, and they fail at compile
time in `build-logic`, not at build time in the app — which is the good outcome, but the messages are
opaque.

| | AGP 9 | AGP 8 |
|---|---|---|
| `CommonExtension` | not generic: `configure<CommonExtension> { }` | generic: `configure<CommonExtension<*, *, *, *, *, *>> { }`, and the number of type parameters changed across 8.x minors |
| Kotlin on an Android module | AGP brings built-in Kotlin support, so `KotlinAndroidProjectExtension` is present with no extra plugin | apply `org.jetbrains.kotlin.android` in the convention plugin first, or there is no Kotlin extension to configure |
| KMP Android library | `com.android.kotlin.multiplatform.library` with `KotlinMultiplatformAndroidLibraryTarget` | the API and its type names changed during 8.x; on older 8.x use `com.android.library` plus KMP's `androidTarget()` |

If the star-projection arity fights you on AGP 8, do not guess: configure `ApplicationExtension` and
`LibraryExtension` separately from their own convention plugins. It duplicates four lines and never
breaks on an AGP upgrade, which is a good trade in a build that is not on AGP 9 yet.

## Verify the types before you commit to them

These DSL types move between AGP versions more than most APIs. Rather than trusting a version table
— including the one above — confirm against the AGP actually on the classpath:

```bash
# Locate the AGP jar Gradle resolved, then look for the type you are about to import
find ~/.gradle/caches/modules-2 -name "gradle-api-*.jar" -o -name "gradle-[0-9]*.jar" | grep -i android | head
unzip -l <that jar> | grep -i "KotlinMultiplatformAndroidLibraryTarget\|CommonExtension"
```

Or simply write the plugin, run `./gradlew -p build-logic :convention:compileKotlin`, and read
the error — it names the type it could not resolve. That loop takes seconds and is more reliable
than any documentation, this file included.

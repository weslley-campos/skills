# Migrating module build files onto the conventions

The goal, stated as a test you can apply to any module file when you think you are done: **a module
declares what it is, and what it depends on.** Anything else is either genuinely unique to that
module or it belongs in a convention plugin.

Contents:
- [Order of work](#order-of-work)
- [What moves and what stays](#what-moves-and-what-stays)
- [Before and after: application module](#before-and-after-application-module)
- [Before and after: multiplatform library module](#before-and-after-multiplatform-library-module)
- [Catalog alias renaming](#catalog-alias-renaming)
- [Things that look shared but are not](#things-that-look-shared-but-are-not)

---

## Order of work

One module at a time, verifying after the first. `./gradlew help` after module one costs twenty
seconds and tells you whether the plugin id resolves, whether the classpath is right, and whether
the DSL type was correct. Migrate all five modules first and you get the same three errors tangled
together across five files.

Take the **application module first** if there is one. It exercises the most of the setup — plugin
resolution, the catalog bridge, the namespace derivation and the application-only DSL — so a green
`./gradlew help` after it means the remaining modules are mostly mechanical.

## What moves and what stays

| In the module file | Where it goes | Why |
|---|---|---|
| `compileSdk`, `minSdk`, `targetSdk` | convention, read from catalog | one number per build, by definition |
| `namespace` | derived when it follows `<root>.<path>`; otherwise stays | invalid path segments or existing nonconforming namespaces must remain explicit unless renamed |
| `applicationId`, `versionCode`, `versionName` | single app: application convention; multiple apps: stays | each application must keep its own identity and version |
| `compileOptions { source/targetCompatibility }` | convention | a build-wide bytecode decision |
| `kotlin { compilerOptions { jvmTarget } }` | convention | same decision, other compiler |
| `packaging { resources { excludes } }` | convention | the same licence-file collisions everywhere |
| `buildTypes { release { ... } }` | application convention | applies to what ships, not to libraries |
| `testInstrumentationRunner` | library and multiplatform conventions | set by `AndroidLibraryConventionPlugin` and `configureLibrary()`, not by `configureAndroid()` |
| `buildFeatures { compose = true }` | convention, **only if universal** | otherwise its own `<prefix>.compose` plugin |
| `dependencies { }` | **stays** | this is what makes the module itself |
| KMP targets and target configuration | base only when intrinsic to every module of that role; otherwise additive convention or **stays** | preserve the surveyed topology and exact semantics; see `references/targets.md` |
| KMP `sourceSets { }` dependencies | **stays** unless intrinsic to the module role | dependencies usually define the module rather than its target topology |
| signing configs, flavours, per-module `buildConfigField` | **stays** unless genuinely shared | moving a one-off into build-logic hides it |

An application module with an androidTest suite needs `testInstrumentationRunner` added explicitly to
`defaultConfig` inside the application convention — neither `configureAndroid()` nor
`AndroidApplicationConventionPlugin` sets it, so nothing else will.

## Before and after: application module

This first pair is for a build with exactly one Android application, where the convention owns its
identity and version.

Before:

```kotlin
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.compose.compiler)
}

kotlin {
    compilerOptions { jvmTarget = JvmTarget.JVM_11 }
}

android {
    namespace = "com.example.app"
    compileSdk = libs.versions.android.compile.sdk.get().toInt()
    defaultConfig {
        applicationId = "com.example.app"
        minSdk = libs.versions.android.min.sdk.get().toInt()
        targetSdk = libs.versions.android.target.sdk.get().toInt()
        versionCode = 1
        versionName = "1.0"
    }
    packaging { resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" } }
    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures { compose = true }
}

dependencies {
    implementation(project(":core"))
    implementation(libs.androidx.activity.compose)
}
```

After:

```kotlin
plugins {
    alias(libs.plugins.<prefix>.android.application)
    alias(libs.plugins.compose.compiler)
}

dependencies {
    implementation(project(":core"))
    implementation(libs.androidx.activity.compose)
}
```

The `import` at the top goes with the `kotlin { }` block. Leaving an unused import behind is a
warning, not an error, so it survives migrations easily — check for it.

This application example leaves `compose.compiler` in the module because the application
convention does not apply it. If that convention is specifically for entry points that compile
Compose, apply the compiler there and remove the module alias. An Android wrapper with no Compose
compilation needs neither compiler nor `buildFeatures.compose`.

With multiple application modules, the after-state keeps identity and version explicit:

```kotlin
plugins {
    alias(libs.plugins.<prefix>.android.application)
}

android {
    namespace = "com.example.viewer"
    defaultConfig {
        applicationId = "com.example.viewer"
        versionCode = 1
        versionName = "1.0"
    }
}

dependencies { /* module dependencies */ }
```

Do not add shared app-version catalog entries merely to make this shorter. If a namespace safely
derives from `<root>.<module path>`, only that `namespace` line may be removed.

## Before and after: multiplatform library module

Before:

```kotlin
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlin.multiplatform)
    alias(libs.plugins.multiplatform.library)
    alias(libs.plugins.compose.multiplatform)
    alias(libs.plugins.compose.compiler)
}

kotlin {
    listOf(
        iosArm64(),
        iosSimulatorArm64()
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "Shared"
            isStatic = true
        }
    }

    android {
        namespace = "com.example.shared"
        compileSdk = libs.versions.android.compile.sdk.get().toInt()
        minSdk = libs.versions.android.min.sdk.get().toInt()
        compilerOptions { jvmTarget = JvmTarget.JVM_11 }
        androidResources { enable = true }
        withHostTest { isIncludeAndroidResources = true }
        withDeviceTestBuilder { sourceSetTreeName = "test" }
            .configure { instrumentationRunner = "androidx.test.runner.AndroidJUnitRunner" }
    }

    sourceSets {
        commonMain.dependencies { implementation(libs.compose.runtime) }
    }
}
```

After:

```kotlin
plugins {
    alias(libs.plugins.<prefix>.multiplatform.library)
    alias(libs.plugins.compose.multiplatform)
    alias(libs.plugins.compose.compiler)
}

kotlin {
    sourceSets {
        commonMain.dependencies { implementation(libs.compose.runtime) }
    }
}
```

Here the base convention replaces the two Kotlin/Android aliases while Compose remains in the
module. If shared libraries also share the Compose dependency and resource policy, add the focused
`<prefix>.compose.library` convention beside the base alias and remove both raw Compose aliases and
the moved shared UI dependencies. See [the Compose convention guide](compose.md); keep unique
dependencies in the module.

In this example, the iOS targets and the `framework { }` block went to `configureIosFramework()`
because every module using this specific convention owns them.
Carry the target list, the `baseName` and `isStatic` across unchanged — the framework name is what
the Swift `import` resolves against, so a "tidier" name breaks the iOS app rather than the build.
`./gradlew help` will not catch that; `./gradlew :<module>:linkDebugFrameworkIosArm64` will.

Some modules will show `androidLibrary { }` instead of `android { }` inside `kotlin { }` — that is
simply the pre-AGP-8.12 spelling of the same target block, covered under
[MultiplatformLibraryConventionPlugin](conventions.md#multiplatformlibraryconventionplugin).

**Watch for generated-resource package renames.** Compose Multiplatform resources are generated into
a package derived from the module — change a module's name or namespace during this migration and
imports like `import <something>.generated.resources.Res` move with it. The compile error appears in
UI code, far from the build file that caused it, so if you rename anything, grep for
`generated.resources` before declaring victory.

For JVM/Desktop, JS browser or Node, WasmJS, and other native targets, first apply the ownership
decision in `references/targets.md`. Never make this Android+iOS example the default topology for a
different KMP module role, and configure moved targets before accessing their target source sets.

## Catalog alias renaming

Gradle maps `-` in an alias to `.` in the generated accessor, so kebab-case is what makes
`libs.compose.ui.tooling.preview` readable and predictable. camelCase aliases produce accessors
nobody can guess from the TOML.

| TOML alias | Accessor |
|---|---|
| `compose-ui-tooling-preview` | `libs.compose.ui.tooling.preview` |
| `composeUiToolingPreview` | `libs.composeUiToolingPreview` |
| `android-compile-sdk` | `libs.versions.android.compile.sdk` |

Renaming is mechanical but touches every module. Keep it as **its own commit**, separate from the
convention-plugin migration, so that a reviewer can read the interesting diff without a hundred
rename lines in the way — and so that a revert of one does not undo the other.

## Things that look shared but are not

Resist folding these in on a first pass, even when several modules happen to agree today:

- **A dependency every module currently has.** Convention plugins *can* add dependencies, and Now in
  Android does it for a few. But a dependency added invisibly to every module is hard to trace when
  someone later asks why a module pulls in a library it never asked for. Add it only when the
  dependency is genuinely a property of the module *type* (a testing runner, for instance).
- **`buildConfigField` values.** Usually per-flavour or per-environment; moving them centralises the
  wrong axis.
- **A `signingConfig`.** Belongs with the application, and often with secrets handling that should
  stay visible.
- **Compiler warning suppressions.** These are almost always someone's local workaround for one
  module. Promoting them to build-wide silently changes the compilation of every module.

The common thread: something is shared when it is a property of the *kind* of module, not when it
happens to have the same value in every module right now.

# Scaffold templates

Read the sections required by the chosen profile. All `<...>` values are substitution tokens:
resolve them from the repository before emitting files. Imports of project types must use their
real packages. Examples describe shapes, not new catalog aliases or version recommendations.

## Build blocks

Prefer existing conventions, which may supply all dependencies/settings. Resolve each plugin role
to its actual ID or `alias(...)`; do not reapply direct plugins owned by a convention. Reuse catalog
aliases and platform/BOM policy instead of versions.

Android or JVM Kotlin DSL with conventions:

```kotlin
plugins {
    id("<existing-base-library-convention>")
    id("<existing-compose-convention>")
    id("<existing-di-convention>")
    id("<existing-detekt-convention>")
}

dependencies {
    implementation(project("<shared-ui-project-path>"))
    implementation(project("<navigation-contract-project-path>"))
    implementation(<existing-di-runtime-accessor>) // only if not supplied by convention
}
```

Without conventions, copy the compatible sibling's direct plugin/compiler configuration: Android
needs its installed Android/Kotlin/Compose setup and Android block; JVM needs JVM/toolchain setup.
Do not attach `android {}` to JVM modules. For ordinary Android DSL:

```kotlin
android {
    namespace = "<resolved-package>"
    compileSdk = <existing-compile-sdk-expression>
    defaultConfig { minSdk = <existing-min-sdk-expression> }
}
```

KMP Kotlin DSL when a base convention owns targets:

```kotlin
plugins {
    id("<existing-kmp-library-convention>")
    id("<existing-compose-convention>")
    id("<existing-di-convention>")
    id("<existing-detekt-convention>")
}

kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation(project("<shared-ui-project-path>"))
            implementation(project("<navigation-contract-project-path>"))
            implementation(<existing-common-di-runtime-accessor>)
        }
    }
}
```

If targets are local, reproduce the sibling's actual declarations and hierarchy. Move platform-only
dependencies to their real source sets; never force Hilt, Android navigation, or preview artifacts
into common code. Preserve Android-KMP plugin DSL instead of grafting the ordinary Android block
onto it. Pure core/domain profiles remove UI/navigation blocks.

For Groovy builds preserve Groovy syntax, including plugin/dependency calls:

```groovy
plugins { id '<existing-base-library-convention>' }
dependencies { implementation project('<dependency-project-path>') }
```

Wire the consumer using its accessor style and correct configuration/source set:

```kotlin
// Android/JVM consumer:
dependencies { implementation(project("<new-project-path>")) }
// KMP consumer, alternative placement:
kotlin { sourceSets { commonMain.dependencies { implementation(project("<new-project-path>")) } } }
```

Use only the applicable block; preserve `api` when public contracts expose dependencies.
Connect shared route dependencies to feature and consumer as needed, never in reverse.

## Compose screen and preview

Resolve the text component from the installed design system (Material 3 below is illustrative).
Add only the runtime/UI dependencies used and supported preview tooling when not already supplied.
Keep preview-only artifacts in established debug/tooling configurations.

```kotlin
package <feature-package>

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

@Composable
fun <Name>Screen(modifier: Modifier = Modifier) {
    Text(text = "<screen-label>", modifier = modifier)
}
```

In the appropriate preview file/source set, substitute the project's supported preview import
(Android or multiplatform) and theme; omit the theme wrapper/import when none exists:

```kotlin
package <feature-package>

import androidx.compose.runtime.Composable
import <supported-preview-package>.Preview
import <existing-theme-package>.<ExistingTheme>

@Preview
@Composable
private fun <Name>ScreenPreview() {
    <ExistingTheme> { <Name>Screen() }
}
```

## DI declaration and registration

Choose the existing mechanism; do not introduce a framework or dummy injectable to fill a template.
A stateless screen needs no ViewModel. A full feature still gets the project's module/composition
declaration, even if initially empty; required navigation bindings belong there.

Koin annotations, with existing KSP/compiler wiring on the actual compilations:

```kotlin
package <feature-di-package>

import org.koin.core.annotation.ComponentScan
import org.koin.core.annotation.Module

@Module
@ComponentScan("<feature-package>")
class <Name>Module
```

Register through the existing root's `@Module(includes = [<Name>Module::class])`, preserving other
includes, or add `<Name>Module().module` to the existing `modules(...)` using the project's generated
extension import (commonly `org.koin.ksp.generated.module`). Do not start a second container.
A feature dependency alone does not add its generated module to the running graph.

Koin DSL alternative:

```kotlin
package <feature-di-package>

import org.koin.dsl.module

val <name>Module = module {
    // When the navigation contract uses a provider, emit its actual binding here:
    // single<<ExistingEntryProvider>> { <Name>EntryProvider() }
}
```

Emit the binding as real code with imports when applicable; do not leave required wiring commented.
Register `<name>Module` in the existing root `modules(...)` or aggregate `includes(...)`.

For Hilt, mirror a sibling `@dagger.Module @InstallIn(<ExistingComponent>::class) object <Name>Module`
and its aggregating processor setup. App dependency reachability is required; do not invent a
component or binding. For Dagger, mirror its module form and add it to the actual component's
`modules` or aggregate's `includes` list. Copy multibinding keys/qualifiers for real navigation
providers from the existing contract. For manual DI, expose and invoke the same composition/factory
entry as peers from the actual app owner. Resolve an unknown mechanism/owner before claiming completion.

## Navigation 3

Use when the project uses Nav3 and this API shape is supported by its installed version. The route
owner needs its existing serialization plugin/runtime. Match object/data-object conventions and
keep route arguments serializable:

```kotlin
package <route-package>

import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable
object <Name>Route : NavKey
```

Feature entry builder, placed in the resolved navigation package:

```kotlin
package <feature-navigation-package>

import androidx.navigation3.runtime.EntryProviderScope
import androidx.navigation3.runtime.NavKey
import <route-package>.<Name>Route
import <feature-package>.<Name>Screen

fun EntryProviderScope<NavKey>.<name>EntryBuilder() {
    entry<<Name>Route> { <Name>Screen() }
}
```

If peers implement a custom provider with these methods, adapt this skeleton to its real signatures
and dependencies. `<ExistingEntryProvider>` is project-owned, not AndroidX; do not create an
alternative interface just to fit this example.

```kotlin
package <feature-navigation-package>

import androidx.navigation3.runtime.EntryProviderScope
import androidx.navigation3.runtime.NavKey
import <route-package>.<Name>Route
import <contract-package>.<ExistingEntryProvider>
import kotlinx.serialization.modules.SerializersModule
import kotlinx.serialization.modules.polymorphic

class <Name>EntryProvider : <ExistingEntryProvider> {
    override fun serializerModule() = SerializersModule {
        polymorphic(NavKey::class) {
            subclass(<Name>Route::class, <Name>Route.serializer())
        }
    }
    override fun entryBuilder(): EntryProviderScope<NavKey>.() -> Unit = {
        <name>EntryBuilder()
    }
}
```

For annotation Koin binding add the existing `@Single(binds = [<ExistingEntryProvider>::class])`
with its import; otherwise use the actual DSL/multibinding mechanism. Verify the host consumes
the provider collection AND combines serializers when that is its contract. For direct registration,
add `<name>EntryBuilder()` inside the existing `entryProvider { ... }` and update its serializer
module only if back-stack/persistence policy requires it. Do not invent a provider for a direct
registry. Preserve existing entries and back-stack initialization. Expose the registered route
through the existing navigation API; add visible controls only when requested or required by an
existing navigation menu/registry, otherwise report that no UI entry action was chosen.

## Navigation Compose and other frameworks

For typed Navigation Compose with serialization configured, put the destination in its established
owner and the builder in the feature (separate packages/files with actual imports):

```kotlin
@kotlinx.serialization.Serializable
object <Name>Route

fun androidx.navigation.NavGraphBuilder.<name>Screen() {
    composable<<Name>Route> { <Name>Screen() }
}
```

Import `androidx.navigation.compose.composable`, the route, and screen. Add `<name>Screen()` to the
existing `NavHost { ... }`, preserving `startDestination`. The route is callable with
`navController.navigate(<Name>Route)`; wire a visible action only when requested or required by an
existing navigation menu/registry. Otherwise report registration without a chosen UI entry action.
If the project uses strings, retain its route constant
and `composable(route)` instead of migrating to typed navigation. For other frameworks map route,
screen factory, registration, and callable navigation API to a real sibling's APIs and DI mechanism.

## Quality and completion checks

Determine whether a convention or root policy covers the new module. Apply only its missing Detekt
hook; reuse config/baseline rules. Discover actual Detekt/lint task names with compile/assemble tasks.
Inspect autoCorrect before running quality tasks; use a nonmutating check or new-module scope.
If policy is missing, resolve it through the main skill's convention boundary rather than omitting it.

Compile module and modified consumer for relevant targets. Confirm generated registration is on
that compilation's dependency path; avoid redundant KSP runs. Use existing graph/navigation smoke
checks to verify that the DI module loads, provider is discoverable, and destination renders.
Without such a check, report that compilation verified types/generated code but not runtime
DI/navigation. A plugin, dependency, or successful module compile does not prove runtime success.

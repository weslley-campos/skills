# Scaffold templates

Read the sections required by the chosen profile. All `<...>` values are substitution tokens:
resolve them from the repository before emitting files. Imports of project types must use their
real packages. Examples describe shapes, not new catalog aliases or version recommendations.

## Build blocks

Prefer existing conventions, which may supply all plugins, targets, and libraries. Apply them in
the sibling's order and spelling (`alias(libs.plugins...)` or `id("...")`); do not reapply a
plugin or library a convention owns. Reuse catalog aliases and platform/BOM policy instead of
versions.

KMP feature on conventions, with type-safe project accessors:

```kotlin
plugins {
    alias(libs.plugins.<prefix>.multiplatform.library)
    alias(libs.plugins.<prefix>.compose.library)
    alias(libs.plugins.<prefix>.koin)
    alias(libs.plugins.<prefix>.detekt)
}

kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation(projects.<ui>)
            implementation(projects.<navigation>)
        }
    }
}
```

`<ui>` and `<navigation>` stand for the shared design-system and navigation modules. A DI
convention that adds Compose artifacts only when the Compose compiler is present must come after
the Compose convention. Declare only module-specific dependencies: a feature on a full set of
conventions often needs nothing beyond its project dependencies. An Android or JVM module puts the
same lines in a top-level `dependencies { }`. Without type-safe accessors, use
`project(":<category>:<module-name>")`.

Without conventions, copy the compatible sibling's direct plugin and compiler configuration:
Android needs its installed Android/Kotlin/Compose setup and Android block; JVM needs JVM/toolchain
setup. Do not attach `android {}` to JVM modules. For ordinary Android DSL:

```kotlin
android {
    namespace = "<resolved-package>"
    compileSdk = <existing-compile-sdk-expression>
    defaultConfig { minSdk = <existing-min-sdk-expression> }
}
```

If KMP targets are local, reproduce the sibling's actual declarations and hierarchy. Move
platform-only dependencies to their real source sets; never force Hilt, Android navigation, or
preview tooling into common code. Preserve the Android-KMP library DSL instead of grafting the
ordinary Android block onto it. Pure core/domain profiles drop the UI and navigation blocks.

For Groovy builds preserve Groovy syntax, including plugin/dependency calls:

```groovy
plugins { id '<existing-base-library-convention>' }
dependencies { implementation project(':<dependency-project-path>') }
```

Wire the consumer with its accessor style and source set:

```kotlin
// KMP consumer, such as a shared app module:
kotlin { sourceSets { commonMain.dependencies { implementation(projects.<category>.<name>) } } }
// Android/JVM consumer:
dependencies { implementation(projects.<category>.<name>) }
```

Use only the applicable block; use `api` only when the consumer's public API exposes the module's
types. Connect a shared navigation module to the feature and consumer as needed, never in reverse.

## Compose screen and preview

Resolve the text component and theme from the installed design system (Material 3 below is
illustrative). Current Compose Multiplatform and Android both provide
`androidx.compose.ui.tooling.preview.Preview`; use the import siblings use. Omit the theme wrapper
when the project has none. Keep preview-only artifacts in the debug/tooling configuration where
siblings get them, often from a convention.

```kotlin
package <feature-package>

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import <theme-package>.<AppTheme>

@Composable
fun <Name>Screen(
    modifier: Modifier = Modifier,
) {
    Text(text = "<screen-label>", modifier = modifier)
}

@Preview
@Composable
private fun <Name>ScreenPreview() {
    <AppTheme> {
        <Name>Screen()
    }
}
```

A screen that navigates adds callback parameters, such as `onNavigateUp: () -> Unit`, before
`modifier`, and its preview passes `{}`. Match the siblings' preview visibility: Detekt's `UnusedPrivateMember` flags a
private preview unless its config ignores `@Preview`.

## DI declaration and registration

Choose the existing mechanism; do not introduce a framework or dummy injectable to fill a
template. With module-based DI, a full feature gets the project's module declaration and its
registration; navigation bindings belong there. With no existing DI, use the app's composition
root to construct and pass only the values the screen needs; direct composition is the
registration.

Koin annotations, with the compiler plugin or KSP already wired by the build:

```kotlin
package <feature-package>

import org.koin.core.annotation.ComponentScan
import org.koin.core.annotation.Module

@Module
@ComponentScan
class <Name>Module
```

A bare `@ComponentScan` scans the module's package and its subpackages, so put the module at the
feature's root package. A module placed elsewhere names the package:
`@ComponentScan("<feature-package>")`.

Register it in the existing root module, keeping its other includes and annotations:

```kotlin
@Configuration
@Module(includes = [<ExistingModule>::class, <Name>Module::class])
@ComponentScan
class AppModule
```

If the root lists modules explicitly instead, add the new module to that list in its existing form,
such as KSP's generated `<Name>Module().module`. Do not start a second container. A Gradle
dependency alone does not put the module in the running graph, and the build still compiles
without it.

A ViewModel for a screen that navigates constructor-injects the navigator and delegates to it:

```kotlin
package <feature-package>

import androidx.lifecycle.ViewModel
import <navigation-package>.Navigator
import org.koin.core.annotation.KoinViewModel

@KoinViewModel(binds = [<Screen>ViewModel::class])
class <Screen>ViewModel(
    val navigator: Navigator,
) : ViewModel(), Navigator by navigator
```

Keep the self-binding. Plain `@KoinViewModel` also binds every implemented interface, which makes
the ViewModel a second `Navigator` provider, and Koin reports a cycle (`KOIN-D004`). Use the
`KoinViewModel` import siblings use; older KSP Android setups import
`org.koin.android.annotation.KoinViewModel`.

Koin DSL alternative, registered in the existing root `modules(...)` or aggregate `includes(...)`:

```kotlin
package <feature-package>

import <navigation-package>.EntryProvider
import org.koin.core.module.dsl.viewModelOf
import org.koin.dsl.bind
import org.koin.dsl.module

val <name>Module = module {
    single { <Screen>EntryProvider() } bind EntryProvider::class
    viewModelOf(::<Screen>ViewModel)
}
```

Bind each provider as a secondary type. `single<EntryProvider> { ... }` in every feature declares
the same definition repeatedly, each overriding the last, so `getAll<EntryProvider>()` returns one.

For Hilt, mirror a sibling `@dagger.Module @InstallIn(<ExistingComponent>::class) object
<Name>Module` and its aggregating processor setup; the app must depend on the module for Hilt to
see it. For Dagger, mirror its module form and add it to the actual component's `modules` or an
aggregate's `includes`. Copy multibinding keys and qualifiers for navigation providers from the
existing contract. For manual DI, expose and invoke the same composition or factory entry as peers
from the actual app owner. Resolve an unknown mechanism or owner before claiming completion.

## Navigation 3

Use when the project uses Navigation 3. The module declaring keys needs the Kotlin serialization
plugin, which a base convention may already apply. Use `data object` for keys without arguments
and `data class` with serializable properties otherwise: a navigator that skips a key equal to the
current top relies on value equality. Follow the siblings' suffix (`Key`, `Entry`, `Route`).

```kotlin
package <key-package>

import androidx.navigation3.runtime.NavKey
import kotlinx.serialization.Serializable

@Serializable
data object <Screen>Key : NavKey
```

When hosts collect entry providers from DI, the feature binds one per screen. Plain `@Single`
already binds every supertype, so the provider needs no `binds`; add one only to hide a supertype,
as the ViewModel does. Adapt the skeleton to the project's real interface; it is project-owned, so
do not create a second one to fit this example.

```kotlin
package <feature-package>

import androidx.navigation3.runtime.EntryProviderScope
import androidx.navigation3.runtime.NavKey
import <key-package>.<Screen>Key
import <navigation-package>.EntryProvider
import kotlinx.serialization.modules.SerializersModule
import kotlinx.serialization.modules.polymorphic
import org.koin.compose.viewmodel.koinViewModel
import org.koin.core.annotation.Single

@Single
class <Screen>EntryProvider : EntryProvider {
    override fun serializerModule() = SerializersModule {
        polymorphic(NavKey::class) { subclass(<Screen>Key::class, <Screen>Key.serializer()) }
    }

    override fun entryBuilder(): EntryProviderScope<NavKey>.() -> Unit = {
        entry<<Screen>Key> {
            val viewModel = koinViewModel<<Screen>ViewModel>()
            <Screen>Screen(onNavigateUp = viewModel::navigateUp)
        }
    }
}
```

A screen without a ViewModel renders `entry<<Screen>Key> { <Screen>Screen() }` and drops the
`koinViewModel` import. Register every key the feature declares in `serializerModule()`: outside
Android the back stack is saved polymorphically, and an unregistered key throws
`SerializationException` when the stack is saved. Keep `entryBuilder()` parameterless; entries reach
the navigator through their ViewModels, not through the provider or host.

With a direct registry instead, add the `entry<<Screen>Key> { ... }` block inside the existing
`entryProvider { ... }` and register the key wherever that host configures back-stack
serialization. Do not invent a provider for a direct registry. Preserve existing entries and
back-stack initialization.

## Navigation Compose and other frameworks

For typed Navigation Compose with serialization configured, put the destination in its
established owner and the builder in the feature (separate files with actual imports):

```kotlin
@kotlinx.serialization.Serializable
data object <Name>Route

fun androidx.navigation.NavGraphBuilder.<name>Screen() {
    composable<<Name>Route> { <Name>Screen() }
}
```

Import `androidx.navigation.compose.composable`, the route, and the screen. Add `<name>Screen()` to
the existing `NavHost { ... }`, preserving `startDestination`. The route is callable with
`navController.navigate(<Name>Route)`. If the project uses string routes, keep its route constant
and `composable(route)` instead of migrating to typed navigation. For other frameworks, map route,
screen factory, registration, and callable navigation API to a real sibling's APIs and DI mechanism.

When there is no navigation framework or host, first check whether existing app state and Compose
can provide a real route and back behavior on all requested targets. Wire the host into the app
composition root and expose a callable navigation action. Put the route in the app or a registered
shared module when dependency direction requires it. Do not create a route in an unconsumed module
or leave the screen as an unused import.

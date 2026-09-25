# Modular Navigation 3 wiring examples

Adapt names, packages, module boundaries, and dependency aliases to the target project. These snippets show the contracts; they are not files to copy verbatim.

## Dependencies

Inspect the existing version catalog, Compose conventions, and source sets first. Add missing dependencies to the modules that use them:

| Use | Multiplatform artifact |
| --- | --- |
| `NavKey`, `NavBackStack`, `NavDisplay`, and entry DSL | `org.jetbrains.androidx.navigation3:navigation3-ui` |
| `rememberViewModelStoreNavEntryDecorator()` | `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-navigation3` |
| Adaptive Navigation 3 scenes, if used | `org.jetbrains.compose.material3.adaptive:adaptive-navigation3` |

The Navigation 3 UI artifact includes the common API transitively. In a KMP module, declare it in `commonMain.dependencies` when shared code uses Navigation 3. Use `api` if downstream modules need Navigation 3 types exposed by that module's public declarations; otherwise use `implementation`. Add the ViewModel artifact to the module containing the `NavDisplay` example below. Reuse an existing version catalog alias or add one for each missing artifact, choosing versions compatible with the project's Kotlin and Compose stack.

For `@Serializable` keys, apply `org.jetbrains.kotlin.plugin.serialization` in the declaring module and check that `org.jetbrains.kotlinx:kotlinx-serialization-core` is available there. The [Compose Multiplatform Navigation 3 guide](https://kotlinlang.org/docs/multiplatform/compose-navigation-3.html) lists current coordinates and serialization options.

## Shared keys and navigator

Put keys in a module visible to the code that navigates and the feature that renders them. Apply the Kotlin serialization compiler plugin wherever a key is declared.

```kotlin
@Serializable data object StartKey : NavKey
@Serializable data object FeatureKey : NavKey

interface Navigator {
    val navBackStack: NavBackStack<NavKey>
    fun navigate(key: NavKey)
    fun navigateUp(): Boolean
}

@Single(binds = [Navigator::class])
class NavigatorImpl(@Provided startKey: NavKey) : Navigator {
    override val navBackStack = NavBackStack(startKey)

    override fun navigate(key: NavKey) {
        if (navBackStack.last() != key) navBackStack.add(key)
    }

    override fun navigateUp(): Boolean {
        if (navBackStack.size <= 1) return false
        navBackStack.removeAt(navBackStack.lastIndex)
        return true
    }
}
```

## Koin entry providers

Each feature contributes an entry provider and its Koin module. Include those modules in the app module; adapt the provider collection to the project's DI setup.

```kotlin
interface EntryProvider {
    fun entryBuilder(): EntryProviderScope<NavKey>.() -> Unit
}

@Single
class EntriesAggregator(@Provided val entries: List<EntryProvider>)

@Module
@ComponentScan
class NavigationModule

@Single(binds = [EntryProvider::class])
class FeatureEntryProvider : EntryProvider {
    override fun entryBuilder(): EntryProviderScope<NavKey>.() -> Unit = {
        entry<FeatureKey> { FeatureScreen() }
    }
}

@Module
@ComponentScan
class FeatureModule

@Module(includes = [NavigationModule::class, FeatureModule::class])
@ComponentScan
class AppModule
```

The `NavKeySerializer()` host example below does not use a serializer module from each provider. Add that method only when another serializer path consumes it.

## Android host

Start Koin in the Android `Application`, register it in the manifest, and include the shared app and navigation modules in the Android launcher dependencies. If the navigation module is multiplatform, place this extension in its `src/androidMain` source set:

```kotlin
@Composable
fun Navigator.rememberNavBackStack() = rememberSerializable(
    serializer = NavBackStackSerializer(NavKeySerializer()),
) {
    navBackStack
}
```

The activity resolves the navigator with the start key and passes the entry builders to the shared app composable:

```kotlin
setContent {
    val entriesAggregator by inject<EntriesAggregator>()
    val navigator by inject<Navigator> { parametersOf(StartKey) }

    AppContent(
        navBackStack = navigator.rememberNavBackStack(),
        entryBuilders = entriesAggregator.entries.map { it.entryBuilder() },
    )
}
```

The shared composable combines the providers and entry decorators:

```kotlin
NavDisplay(
    backStack = navBackStack,
    entryDecorators = listOf(
        rememberSaveableStateHolderNavEntryDecorator(),
        rememberViewModelStoreNavEntryDecorator(),
    ),
    entryProvider = entryProvider {
        entryBuilders.forEach { builder -> this.builder() }
    },
)
```

After activity recreation, check that navigation actions still update the displayed stack. `rememberSerializable` can restore a stack distinct from the stack held by `NavigatorImpl`; the example does not bind those instances together.

# Modular Navigation 3 wiring examples

Adapt names, packages, module boundaries, and dependency aliases to the target project. These snippets show the contracts; they are not files to copy verbatim. They use Koin annotations. With the Koin DSL, declare the same singletons, pass the back stack as a definition parameter, and collect providers with `getAll<EntryProvider>()`.

## Dependencies

Inspect the existing version catalog, Compose conventions, and source sets first. Add missing dependencies to the modules that use them:

| Use | Multiplatform artifact |
| --- | --- |
| `NavKey`, `NavBackStack`, `NavDisplay`, entry DSL, `NavBackStackSerializer`, `SavedStateConfiguration` | `org.jetbrains.androidx.navigation3:navigation3-ui` |
| `rememberViewModelStoreNavEntryDecorator()` | `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-navigation3` |
| `koinInject()`, `currentKoinScope()` in `rememberNavigator` | `io.insert-koin:koin-compose` |
| `koinViewModel()` in entries | `io.insert-koin:koin-compose-viewmodel` |
| Adaptive Navigation 3 scenes, if used | `org.jetbrains.compose.material3.adaptive:adaptive-navigation3` |

The Navigation 3 UI artifact brings the runtime, saved-state serialization, and `kotlinx-serialization-core` transitively. In a KMP module, declare it in `commonMain.dependencies`. The navigation module declares it with `api`, because `Navigator`, `EntryProvider`, and `rememberNavigator` expose `NavKey`, `NavBackStack`, and `EntryProviderScope`. Under `implementation`, every launcher that reads `navigator.navBackStack` or `entryBuilder()` fails with `Cannot access class 'androidx.navigation3.runtime.NavKey'`. Every other module uses `implementation`, including `:app`, which renders `NavDisplay`.

```kotlin
// <navigation>/build.gradle.kts
kotlin {
    sourceSets {
        commonMain.dependencies {
            api(libs.navigation3.ui)
        }
    }
}
```

Reuse an existing version catalog alias or add one for each missing artifact, choosing versions compatible with the project's Kotlin and Compose stack.

Apply `org.jetbrains.kotlin.plugin.serialization` in every module that declares a `@Serializable` key. The [Compose Multiplatform Navigation 3 guide](https://kotlinlang.org/docs/multiplatform/compose-navigation-3.html) lists current coordinates.

## Keys and navigator

```kotlin
@Serializable data object StartKey : NavKey

interface Navigator {
    val navBackStack: NavBackStack<NavKey>
    fun navigate(key: NavKey)
    fun navigateUp(): Boolean
}

@Single
class NavigatorImpl(@InjectedParam override val navBackStack: NavBackStack<NavKey>) : Navigator {
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

## Entry providers and serialization

```kotlin
interface EntryProvider {
    fun serializerModule(): SerializersModule
    fun entryBuilder(): EntryProviderScope<NavKey>.() -> Unit
}

@Single
class EntriesAggregator(val entries: List<EntryProvider>)

@Single
fun savedStateConfiguration(aggregator: EntriesAggregator) = SavedStateConfiguration {
    serializersModule = SerializersModule {
        aggregator.entries.forEach { include(it.serializerModule()) }
    }
}

@Module
@ComponentScan
class NavigationModule
```

Each feature registers its keys and resolves its ViewModel in the entry. The start key needs a provider like any other key.

```kotlin
@Serializable data object FeatureKey : NavKey

@KoinViewModel(binds = [FeatureViewModel::class])
class FeatureViewModel(val navigator: Navigator) : ViewModel(), Navigator by navigator

@Single
class FeatureEntryProvider : EntryProvider {
    override fun serializerModule() = SerializersModule {
        polymorphic(NavKey::class) { subclass(FeatureKey::class, FeatureKey.serializer()) }
    }

    override fun entryBuilder(): EntryProviderScope<NavKey>.() -> Unit = {
        entry<FeatureKey> {
            val viewModel = koinViewModel<FeatureViewModel>()
            FeatureScreen(onNavigateUp = viewModel::navigateUp)
        }
    }
}

@Module
@ComponentScan
class FeatureModule

@Configuration
@Module(includes = [NavigationModule::class, FeatureModule::class])
@ComponentScan
class AppModule
```

Every host starts Koin from `AppModule`, whose `includes` bring in the rest.

## Saved state

Place this in the navigation module's `commonMain`:

```kotlin
@Composable
fun rememberNavigator(startKey: NavKey): Navigator {
    val configuration = koinInject<SavedStateConfiguration>()
    val koinScope = currentKoinScope()
    val saver = remember(koinScope, configuration) {
        val serializer = NavBackStackSerializer(PolymorphicSerializer(NavKey::class))
        Saver<Navigator, SavedState>(
            save = { encodeToSavedState(serializer, it.navBackStack, configuration) },
            restore = { savedState ->
                val backStack = decodeFromSavedState(serializer, savedState, configuration)
                koinScope.get<Navigator> { parametersOf(backStack) }
            },
        )
    }
    return rememberSaveable(saver = saver) {
        koinScope.get<Navigator> { parametersOf(NavBackStack(startKey)) }
    }
}
```

## Hosts

Every platform starts Koin once, outside composition, before the first lookup. Its composition root then loads the entry builders from `EntriesAggregator`, remembers the navigator with the start key, and passes both to `App()`. Each launcher applies the project's Koin setup and depends on `:app` and the navigation module, because it calls `startKoin` and references `EntriesAggregator`, `rememberNavigator`, and the start key directly.

The launcher build files use type-safe project accessors, enabled in `settings.gradle.kts`:

```kotlin
enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")
```

An accessor follows the project path, with `:` becoming `.` and dashes or underscores becoming camel case: `:core:navigation` is `projects.core.navigation`, and `:feature:account-settings` is `projects.feature.accountSettings`. Without the preview, use `project(":core:navigation")`.

The typed `startKoin<AppModule>` comes from `org.koin.plugin.module.dsl`, `@KoinApplication` from `org.koin.core.annotation`, `KoinPlatform` from `org.koin.mp`, and Android's `inject()` from `org.koin.android.ext.android` in `koin-android`.

### Android

```kotlin
// <android-app>/build.gradle.kts
dependencies {
    implementation(projects.app)
    implementation(projects.<navigation>)
    implementation(libs.androidx.activity.compose)
}
```

Tag the `Application` subclass `@KoinApplication` and start Koin with `startKoin<AppModule>`, as web and desktop do. Register it in the manifest with `android:name=".MainApplication"`. The launcher activity injects the aggregator and composes in `setContent`:

```kotlin
@KoinApplication
class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin<AppModule> {
            androidContext(this@MainApplication)
        }
    }
}

class MainActivity : ComponentActivity() {
    private val entriesAggregator: EntriesAggregator by inject()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val navigator = rememberNavigator(StartKey)

            App(
                navBackStack = navigator.navBackStack,
                entryBuilders = entriesAggregator.entries.map { it.entryBuilder() },
            )
        }
    }
}
```

### Web (Wasm)

```kotlin
// <web-app>/build.gradle.kts
kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation(projects.app)
            implementation(projects.<navigation>)
        }
    }
}
```

`main()` starts Koin before `ComposeViewport`, which reads the aggregator from `KoinPlatform`:

```kotlin
@OptIn(ExperimentalComposeUiApi::class)
fun main() {
    startKoin<AppModule>()

    ComposeViewport {
        val entries = KoinPlatform.getKoin().get<EntriesAggregator>().entries
        val navigator = rememberNavigator(StartKey)

        App(
            navBackStack = navigator.navBackStack,
            entryBuilders = entries.map { it.entryBuilder() },
        )
    }
}
```

### Desktop (JVM)

```kotlin
// <desktop-app>/build.gradle.kts
dependencies {
    implementation(projects.app)
    implementation(projects.<navigation>)
    implementation(compose.desktop.currentOs)
}
```

`main()` starts Koin before `application { }`, and the window reads the aggregator from `KoinPlatform`:

```kotlin
fun main() {
    startKoin<AppModule>()

    application {
        Window(onCloseRequest = ::exitApplication, title = "<App name>") {
            val entries = KoinPlatform.getKoin().get<EntriesAggregator>().entries
            val navigator = rememberNavigator(StartKey)

            App(
                navBackStack = navigator.navBackStack,
                entryBuilders = entries.map { it.entryBuilder() },
            )
        }
    }
}
```

### iOS

The iOS framework is built from `:app`, so both Kotlin files go in its `iosMain`, which already sees the navigation module. Start Koin untyped, with `startKoin` from `org.koin.core.context` and `module<T>()` from `org.koin.plugin.module.dsl`. With the Koin compiler plugin, a typed start in the iOS compilation reports the aggregator lookup below as a missing definition (`KOIN-D002`).

```kotlin
// app/src/iosMain/kotlin/<package>/Koin.kt
fun initKoin() {
    startKoin { module<AppModule>() }
}
```

```kotlin
// app/src/iosMain/kotlin/<package>/MainViewController.kt
fun MainViewController(): UIViewController = ComposeUIViewController {
    val entries = KoinPlatform.getKoin().get<EntriesAggregator>().entries
    val navigator = rememberNavigator(StartKey)

    App(
        navBackStack = navigator.navBackStack,
        entryBuilders = entries.map { it.entryBuilder() },
    )
}
```

The Swift `App` initializer starts Koin before any Compose view controller exists, and a representable wraps the controller:

```swift
import SwiftUI
import UIKit
import <SharedFramework>

@main
struct iOSApp: App {
    init() {
        KoinKt.doInitKoin()
    }

    var body: some Scene {
        WindowGroup {
            ComposeView().ignoresSafeArea()
        }
    }
}

struct ComposeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        MainViewControllerKt.MainViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
```

Swift reaches a top-level Kotlin function through a class named after its file (`Koin.kt` becomes `KoinKt`), and Kotlin/Native prefixes functions whose names start with `init` with `do`. Renaming either file changes the Swift call.

## Root composable

`App()` in `:app` combines the providers and entry decorators:

```kotlin
@Composable
fun App(
    navBackStack: NavBackStack<NavKey>,
    entryBuilders: List<EntryProviderScope<NavKey>.() -> Unit>,
) {
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
}
```

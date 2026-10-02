---
name: navigation3-multiplatform
description: Add modular Compose Multiplatform Navigation 3 routing with serializable keys, Koin-collected entry providers, a shared navigator, and back-stack restoration on Android, iOS, desktop, and web hosts. Use for Navigation 3 integration, not Navigation Compose 2 graphs.
---

# Modular Navigation 3

Inspect the target project's modules, targets, Gradle conventions, Koin setup, and Navigation 3 APIs. Reuse its navigation module, or add one if needed. Adapt the [wiring examples](references/wiring.md) to its packages, modules, and keys.

## Module layout

The examples call the shared multiplatform module `:app`, holding the root composable `App()` and the Koin root `AppModule`, with one launcher module per platform. In an existing project, keep its module names and map them onto these roles.

When the user is creating the project, and the generated shared module is called `shared`, suggest renaming it to `:app` before wiring navigation. Ask first. The rename touches:

- the directory and `include(":shared")` in `settings.gradle.kts`;
- each launcher's dependency on the module;
- the Xcode run-script phase, `./gradlew :shared:embedAndSignAppleFrameworkForXcode`;
- any framework search path under `shared/build/xcode-frameworks`.

The iOS framework's `baseName` and the Swift `import` can keep the old name; rename them together or not at all.

## Dependencies

Check the version catalog and convention plugins before adding dependencies. Make the multiplatform `org.jetbrains.androidx.navigation3:navigation3-ui` artifact available to every source set that uses Navigation 3 APIs; it brings in the runtime, saved-state serialization, and `kotlinx-serialization-core` transitively. The navigation module declares it with `api`, because its public API exposes Navigation 3 types to the launchers; every other module uses `implementation`. Add `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-navigation3` where `rememberViewModelStoreNavEntryDecorator()` is used, and Koin's Compose artifacts where entries or the navigator resolve from Koin. Apply the Kotlin serialization plugin in modules declaring `@Serializable` keys. See the [dependency examples](references/wiring.md#dependencies).

## Shared contracts

- Declare keys as `@Serializable` `data object` or `data class` types implementing `NavKey`, where both the code that navigates to them and the provider that renders them can see them. A key that only one feature navigates to can stay in that feature. Keep value equality: `navigate` skips a key equal to the current top.
- One singleton `Navigator` owns the `NavBackStack`. It receives the stack as an injected parameter rather than building it from a start key, so a restored stack can be handed to it. `navigateUp` keeps the root entry.
- Each feature binds an `EntryProvider` that returns its entry builder and a `SerializersModule` registering its keys under `polymorphic(NavKey::class)`. Collect the providers in an `EntriesAggregator`, and build one `SavedStateConfiguration` from every provider's module. Only Android can serialize keys by reflection; on every other target the back stack is saved polymorphically. An unregistered key throws `SerializationException` when the stack is saved, for example when the app goes to the background.
- Keep screens stateless, taking navigation callbacks. The entry resolves its ViewModel with `koinViewModel()` and wires the callbacks. The ViewModel constructor-injects `Navigator`; one that delegates `Navigator by navigator` binds only to its own class, or Koin also registers it as a `Navigator` provider and reports a cycle.

## Saved state

`rememberNavigator(startKey)` in the navigation module's `commonMain` remembers the navigator itself, through a `Saver` that encodes its stack with `NavBackStackSerializer(PolymorphicSerializer(NavKey::class))` and the shared configuration. Restoring asks Koin for the `Navigator` with the decoded stack. After a configuration change, Koin returns the live singleton and the decoded copy is dropped. After process death, Koin creates the singleton from the decoded stack. Either way, `NavDisplay` shows the stack the navigator mutates.

Do not remember the stack separately (with `rememberNavBackStack`, `rememberSerializable`, or Android's `NavKeySerializer()`) while a singleton navigator holds its own: after recreation, navigation mutates a stack that is no longer displayed.

## Hosts

Each platform starts Koin once, outside composition. Its composition root then loads the entry builders from `EntriesAggregator`, calls `rememberNavigator(StartKey)`, and passes both to `App()`. Each launcher depends on `:app` and the navigation module. Follow the [per-platform host examples](references/wiring.md#hosts):

- **Android:** the `@KoinApplication` `Application` subclass runs `startKoin<AppModule>` in `onCreate`. The launcher activity injects the aggregator with `by inject()` and composes in `setContent`.
- **Web and desktop:** `main()` runs `startKoin<AppModule>()` before `ComposeViewport` or `application { Window }`, and the composition reads the aggregator from `KoinPlatform.getKoin()`.
- **iOS:** the `iosMain` of `:app` starts Koin untyped from `initKoin()`, which the Swift `App` initializer calls. `MainViewController()` reads the aggregator inside `ComposeUIViewController`.

## Verify

Build every host target, including the module with each Koin entry point, because a library without one skips Koin's graph validation. Launch each host and check that it renders the start entry and follows a navigation. On Android, rotate while a navigation is pending and check that the screen follows it. Then kill the backgrounded process, relaunch, and check that the first frame shows the previous top entry, not the start key.

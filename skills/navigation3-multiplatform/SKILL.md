---
name: navigation3-multiplatform
description: Add modular Compose Multiplatform Navigation 3 routing with shared keys, Koin entry providers, and an Android host. Use for Navigation 3 integration, not Navigation Compose 2 graphs.
---

# Modular Navigation 3

Inspect the target project's modules, Gradle conventions, Koin setup, and Navigation 3 APIs. Reuse its navigation module, or add one if needed. Adapt the [wiring examples](references/wiring.md) to its packages, modules, and entry keys.

## Dependencies

Check the version catalog and convention plugins before adding dependencies. Make the multiplatform `org.jetbrains.androidx.navigation3:navigation3-ui` artifact available to every source set that uses Navigation 3 APIs; it brings in the common API transitively. Use `api` when a module exposes Navigation 3 types in its public contract. Add `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-navigation3` where `rememberViewModelStoreNavEntryDecorator()` is used. Apply the Kotlin serialization plugin in modules declaring `@Serializable` keys. See the [dependency examples](references/wiring.md#dependencies) for module placement and optional artifacts.

## Shared contracts

- Put `@Serializable NavKey` types where both callers and entry providers can use them. Apply the Kotlin serialization plugin in modules that declare keys.
- Let one `Navigator` own the mutable `NavBackStack`. Its `navigate` operation can skip the current key, and `navigateUp` should keep the root entry.
- For modular Koin entries, bind each feature's `EntryProvider` to the interface and collect providers in an `EntriesAggregator`. Include the feature modules in the app's Koin module. Add a custom serializer module only if the chosen serializer actually consumes it.

## Android host

Start Koin in the Android `Application` and name it in the manifest. In the activity, inject the navigator with the start key and pass its stack plus collected entry builders to a shared composable using `NavDisplay`.

For Android saved state, the [extension example](references/wiring.md#android-host) uses `rememberSerializable` with `NavBackStackSerializer(NavKeySerializer())` in the navigation module's `androidMain` source set. Verify that the restored stack is the same stack the navigator mutates after activity recreation; the extension alone does not establish that relationship.

Verify the Android build, Koin provider collection, navigation back to the root, and navigation after activity recreation.

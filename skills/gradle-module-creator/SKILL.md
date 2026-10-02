---
name: gradle-module-creator
description: >
  Scaffold and register Gradle modules for Android, Kotlin/JVM, and Kotlin Multiplatform projects.
  Use when adding a module, feature, screen, core library, or domain subproject. Creates the base
  build and sources plus Compose, DI, Detekt, and navigation wiring for screen features, adapting
  to the repository's conventions, DSL, frameworks, and targets.
---

# Gradle module creator

Deliver a usable scaffold, including its consumer wiring. A feature or screen request implies the
full feature profile below; the user need not separately request each integration. Explicit opt-outs
win. Reuse repository contracts, never project-specific identifiers from an unrelated example.
If the consumer lacks a required DI, navigation, or quality setup, add the smallest compatible
prerequisite and wire it into the consumer as part of the feature. A buildable feature module alone
does not satisfy a screen request.

## 1. Select the module profile

| Profile | Base build + settings | Compose + screen/preview | DI | Detekt | Navigation |
|---|---|---|---|---|---|
| Feature / screen | Required | Required | Module registration or direct composition | Required | Key + entry + registration |
| Core UI | Required | UI entry point + preview | Existing policy / requested bindings | Existing policy | Only when its role requires it |
| Core / infrastructure | Required | No | Existing policy / requested bindings | Existing policy | No |
| Domain / pure Kotlin | Required | No | Only if compatible with domain policy | Existing policy | No |

Categories describe roles, not fixed directories. Keep pure domain modules free of Android/UI
dependencies. Do not invent services, repositories, ViewModels, or base classes without behavior
that needs them. “Base module” means the Gradle project and sources, not `BaseModule` inheritance.

## 2. Read the build, then resolve names

Use `rg --files` to locate settings, the root build, the catalog, `build-logic` or `buildSrc`, and
Kotlin sources. Read the settings, the nearest target-compatible sibling, and the conventions it
applies. Note what those conventions already supply, because the new build file declares only the
rest: targets and source-set hierarchy, Android namespace and SDKs, the serialization plugin,
Compose/lifecycle/navigation libraries, DI libraries and compiler, the iOS framework, and Detekt.
Trace one existing feature end to end: plugins → sources → DI module → navigation key and
entry → the module that registers it → the hosts. The registering consumer is often the shared app
module, not the platform launchers. Read [references/integrations.md](references/integrations.md)
for the selected integrations.

| Value | Derivation |
|---|---|
| Project path and directory | Existing category layout and settings mapping, including custom `projectDir` |
| Package | Repository base package plus the path, the way siblings and the namespace convention derive it |
| `<Name>`, `<name>` | PascalCase type prefix and camelCase function/property prefix from the requested name |
| Source root | Actual root, e.g. `src/commonMain/kotlin` or `src/main/kotlin` |
| Consumer | The module whose DI root or navigation host registers features |

For `account-settings`, derive `AccountSettings` / `accountSettings` and a legal package segment
such as `accountsettings`; never put hyphens in package declarations. A convention that derives the
namespace, package, resource class, or iOS framework name from the project path fails at
configuration on a segment that is not a legal identifier. Check how it maps the path; if it
copies segments, use the legal spelling for both path and directory (`:feature:accountsettings`),
unless siblings already map directories with `projectDir`. Use type-safe project accessors only when settings enable them,
and derive their spelling from the path. Check the destination and Gradle includes for collisions
before creating files; extend an existing module only when that is the user's intent.

One compatible example is enough; integrations do not require unanimous same-role siblings.
Resolve disagreements using the closest applicable convention and actual consumer. When there is
no existing DI or navigation mechanism, prefer direct composition and a small route/host using
dependencies already present or compatible with the build, unless the user chose a framework or
convention. Do not add a framework merely to fill a template. Ask one focused question only when
a consequential choice cannot be inferred from the repository or user intent (for example, an
unspecified platform target or an incompatible framework choice). Continue independent work while
awaiting the answer, then finish the integration; never call a partial scaffold complete. Do not
silently omit a required integration or invent a framework version.

## 3. Create the base project

Register the project in the current settings style, inside its category group:

```kotlin
include(":<category>:<module-name>")
```

Create the build file in the repository's Kotlin or Groovy DSL. Apply the sibling's conventions in
its order and add only the dependencies they do not supply. Where there are no conventions, adapt
the reference build blocks. Keep actual Android, JVM, JS, Wasm, native, and iOS targets and
source-set hierarchy; do not replace KMP topology with generic targets. Match the installed AGP
API (including the Android-KMP library DSL), namespace, SDKs, and compiler setup.

A Koin and Navigation 3 feature typically has this shape; follow the sibling where it differs:

```text
<module-dir>/
  build.gradle.kts                  # or build.gradle
  <source-root>/<package-dir>/
    <Name>Module.kt                 # DI module at the package root
    <Screen>Screen.kt               # screen and its preview, one file
    <Screen>EntryProvider.kt        # key → screen, plus the key's serializer
    <Screen>ViewModel.kt            # only when the screen navigates or holds state
    <Screen>Key.kt                  # only when no other module navigates to it
```

A feature with several screens gives each screen a subpackage holding its screen, entry provider,
ViewModel, and key, and keeps the one DI module at the root. Other stacks fill the same roles with
their own files: a Hilt module, a `NavGraphBuilder` extension, or a factory called from the app.
Add platform files, manifests, or resources only when that target or plugin requires them. Root
ignore rules suffice when they cover build outputs. Never copy sibling business logic or leave
unresolved template tokens.

## 4. Create the screen and DI declaration

For a feature, create a stateless `<Name>Screen(modifier: Modifier = Modifier)` with minimal
visible content using the existing design system. When the screen navigates, it takes callbacks
such as `onNavigateUp: () -> Unit`, placed before `modifier`, and never obtains a ViewModel or DI
instance itself, so its preview runs without DI. Put the preview in the same file unless siblings keep previews elsewhere,
using their preview import and theme. Keep Android-only preview code out of common sources;
unsupported preview tooling is a stated limitation, not a reason to omit the screen.

Create the repository's DI declaration: a Koin annotation or DSL module, a Hilt/Dagger module in
the actual component, or the existing manual composition entry point. Register it in the graph's
root, for Koin annotations the `includes` of the module the hosts start. An applied plugin or Gradle
dependency registers nothing, and a missing registration still compiles. Add a ViewModel only when
the screen navigates or holds state, following the repository's ViewModel and binding pattern. If
the app has no DI mechanism, wire the screen and navigation directly from its composition root; an
empty container or dummy binding is not a prerequisite.

## 5. Create navigation and connect consumers

Create the key or destination where the code that navigates to it can see it: the shared
navigation module when other modules navigate to it, the feature when only the feature does. For
Navigation 3 use the existing `NavKey` contract and serialization; for Navigation Compose, the
existing `NavGraphBuilder` and route style. Other frameworks fill the destination → screen → host
roles through their own APIs. A custom `EntryProvider` is project-owned, not an AndroidX type.

When hosts collect entry providers from DI, the feature's DI module is its navigation
registration, and no host changes. Otherwise add the builder to the existing `entryProvider { }`,
`NavHost { }`, or registry. Add the feature dependency to the consumer, with the correct
configuration and source set. Preserve app layout, start destination, and back-stack behavior.
Keep dependency direction acyclic: the shared navigation module must not depend on a feature.

If no navigation exists and the project is Compose Multiplatform with Koin, set it up with
[navigation3-multiplatform](../navigation3-multiplatform/SKILL.md), then resume here. Otherwise
create the smallest host in the consumer from dependencies it already has; if a navigation library
is needed, verify its version and target compatibility from authoritative release or docs
information before adding it.

The destination must be callable through the navigation API, for example
`navigator.navigate(<Name>Key)`. Add a visible menu, tab, or button only when requested or required
by an existing navigation menu/registry; otherwise report that the destination is registered with
no UI entry action chosen.

## 6. Apply quality coverage

Ensure the feature has Detekt coverage through the existing convention, root policy, or direct
plugin setup, reusing config and baselines without duplication. Check whether the Detekt extension
enables `autoCorrect`; run Detekt on the new module only (`:<project-path>:detekt`), never an
aggregate auto-correcting run, and review any edits it makes.

If existing policy cannot supply required coverage, resolve it rather than silently dropping it.
Adding a needed DI convention or quality hook for the new feature is part of its scaffold; when
that requires convention work, use
[gradle-convention-plugin](../gradle-convention-plugin/SKILL.md), finish its checks, then resume
here. Do not migrate unrelated modules or invent plugin versions.

## 7. Verify and complete

Configure the build, then discover the task names (substitute resolved paths):

```sh
./gradlew help
./gradlew :<project-path>:tasks --all
```

Compile the new module, the consumer, and every host target, such as
`:<android-app>:compileDebugKotlin`. Let compilation run KSP or KAPT; invoke processors separately
only if that task omits required generation. Run the module's Detekt task and any existing DI
graph or navigation smoke checks.

A green compile is not DI proof. The Koin compiler plugin validates only compilations that start
Koin, incremental compilation can skip a launcher whose own sources did not change, and a missing
registration, a key left out of the saved-state serializers, or an unsatisfiable dependency in a
library module all compile. Launch one host and navigate to the new destination; where that is not
possible, report that compilation verified types, not runtime discovery. Report the exact commands
and results.

- [ ] Unique project is included and mapped to the created build/source tree.
- [ ] DSL, packages, plugins, targets, source sets, and dependencies match the build.
- [ ] Feature has a stateless Compose screen and a preview (or an explicit tooling limitation).
- [ ] DI module is registered in the graph root, or the consumer composes the feature directly.
- [ ] Key, entry, serializer, and registration are complete, and the destination is callable.
- [ ] Consumer dependency is wired without cycles or unsolicited UI actions.
- [ ] Required Detekt policy covers the module without duplicated configuration.
- [ ] No unresolved tokens, fake business types, or unrelated migrations remain.
- [ ] Exact verification commands/results and runtime-check limitations are reported.

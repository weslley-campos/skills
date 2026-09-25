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
| Feature / screen | Required | Required | Module registration or direct composition | Required | Route + builder + host/provider wiring |
| Core UI | Required | UI entry point + supported preview | Existing policy / requested bindings | Existing policy | Only when its role requires it |
| Core / infrastructure | Required | No | Existing policy / requested bindings | Existing policy | No |
| Domain / pure Kotlin | Required | No | Only if compatible with domain policy | Existing policy | No |

Categories describe roles, not fixed directories. Keep pure domain modules free of Android/UI
dependencies. Do not invent services, repositories, ViewModels, or base classes without behavior
that needs them. “Base module” means the Gradle project and sources, not `BaseModule` inheritance.

## 2. Resolve the scaffold parameters

Use `rg --files` to locate settings, root/module build files, catalogs, conventions, and Kotlin sources.
Read the settings/root build, catalog, nearest target-compatible sibling, and consuming app/graph.
Trace one existing feature end to end: plugins → sources → DI → navigation → consumer.
Read [references/integrations.md](references/integrations.md) for the selected integrations.

Resolve these values before writing; tokens below are documentation, never generated output:

| Parameter | Derivation |
|---|---|
| `MODULE_DIR`, `PROJECT_PATH` | Existing category layout and settings mapping, including custom `projectDir` |
| `PACKAGE`, `PACKAGE_DIR` | Repository base package + naming policy; directory uses `/` instead of `.` |
| `Name`, `name` | PascalCase type prefix and camelCase function/property prefix from requested name |
| `MAIN` | Actual source root: e.g. `src/main/kotlin` or `src/commonMain/kotlin` |
| Build inputs | Existing DSL, plugin IDs/aliases, catalog, SDK/toolchain, targets/source-set hierarchy |
| Integration owners | Shared route package/project, DI root/aggregate, host/provider collection, consumer |
| Dependencies | Existing UI/theme, navigation contract, DI/compiler, serialization, preview artifacts |

For `account-settings`, preserve Gradle/path spelling if customary, derive `AccountSettings` /
`accountSettings`, and use the repository's legal package spelling (such as `accountsettings`).
Resolve invalid identifiers/keywords explicitly; never put hyphens in package declarations or
assume type-safe project accessor spelling. Check the destination and Gradle includes/mappings
for collisions before creating files; extend an existing module only when that is the user's intent.

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

Create the build file in the repository's Kotlin or Groovy DSL. Apply existing base/library,
Compose, DI, and quality conventions for the selected profile. Where conventions do not supply
configuration, adapt the reference build blocks using existing plugins and dependencies.
Keep actual Android, JVM, JS, Wasm, native, and iOS targets and source-set hierarchy; do not
replace KMP topology with generic targets. Match the installed AGP API (including Android-KMP
library DSL where applicable), namespace, SDKs, and compiler setup.

Register the project using current settings style, for example:

```kotlin
include(":<category>:<module-name>")
```

Create this feature structure, adapted to resolved names/contracts (other profiles omit entries
that do not apply):

```text
MODULE_DIR/
  build.gradle.kts                         # or build.gradle
  MAIN/PACKAGE_DIR/
    NameScreen.kt
    NameScreenPreview.kt                  # or supported preview source set
    di/NameModule.kt                      # only for a module-based DI mechanism
    navigation/NameEntryBuilder.kt        # or NameNavigation.kt for NavGraphBuilder
    navigation/NameEntryProvider.kt       # only when the project has this contract
ROUTE_OWNER/ROUTE_MAIN/ROUTE_PACKAGE_DIR/
  NameRoute.kt                            # may live in the feature instead
```

Use the existing source layout, including package-root DI declarations when customary. Add platform
files, manifests, or resources only when required by that target/plugin. Root ignore rules suffice
when they cover build outputs. Never copy sibling business logic or leave unresolved template tokens.

## 4. Create the screen and DI declaration

For a feature, configure Compose and create `NameScreen(modifier: Modifier = Modifier)` with
minimal visible content using existing UI components. Add a preview with the supported import,
source set, and theme. Keep Android-only preview code out of common sources; unsupported preview
tooling is a stated limitation, not a reason to omit the screen.

Create the repository's DI declaration: Koin annotation/DSL module, Hilt/Dagger module and actual
component contract, or existing manual composition entry point. Wire navigation providers through
DI when that is how the host discovers them. Follow the reference templates; an applied plugin
does not constitute a DI declaration or graph registration. If the app has no DI mechanism, wire
the screen and navigation directly from its composition root; an empty container or dummy binding
is not a prerequisite.

## 5. Create navigation and connect consumers

Create the route/destination in its established owner, then its screen builder and provider/serializer
when required. For Nav3 use the existing typed `NavKey` contract; for Navigation Compose use the
existing `NavGraphBuilder` and route style. Other frameworks fulfill destination → screen → host
roles through their own APIs. A custom `EntryProvider` is not an AndroidX built-in interface.
If no navigation exists, create the smallest host in the consumer and place the route there or in
a shared contract module when dependency direction requires it. Register any new prerequisite
module and its build dependencies. Use existing dependencies where possible; if a navigation
library is needed, verify its version and target compatibility from authoritative release/docs
information before adding it. The destination must be reachable through an actual navigation
call, not just a declared route or unused screen.

Add the feature dependency to the consumer and register its builder/provider with the actual host.
For module-based DI, add the feature's module to the root/aggregate or generated discovery path;
for manual composition, call the feature from the consumer's composition root. For decentralized
discovery, still satisfy classpath, scanning/binding, and collection-consumption requirements.
Make the registered destination callable through the existing or newly created navigation API.
Add a visible menu, tab, or button only when requested or required by an existing navigation
menu/registry; otherwise report that the route is registered with no UI entry action chosen.
Preserve app layout, start destination, and back-stack behavior. Keep dependency direction acyclic:
the shared route contract must not depend on its feature implementation.

## 6. Apply quality coverage

Ensure the full feature scaffold has Detekt coverage through the existing convention, root policy,
or direct plugin setup. Reuse config/baselines without duplication. Inspect whether tasks enable
autoCorrect; use an existing nonmutating check or scope execution to the new module, never broad
aggregate auto-correction. Review any resulting edits.

If existing policy cannot supply required coverage, resolve it rather than silently dropping it.
Adding a needed DI convention or quality hook for the new feature is part of its scaffold;
when that requires convention work, use
[gradle-convention-plugin](../gradle-convention-plugin/SKILL.md), finish its checks, then resume here.
Do not migrate unrelated modules or invent plugin versions.

## 7. Verify and complete

Run configuration first, then discover available tasks (substitute resolved paths):

```sh
./gradlew help
./gradlew :<project-path>:tasks --all
./gradlew :<consumer-path>:tasks --all
```

List consumer tasks when its wiring changed. Run the narrowest listed compile/assemble tasks for
requested targets, applicable Detekt/lint tasks, and consumer compilation. Let compilation run
KSP/KAPT dependencies; invoke processors separately only if that task omits required generation.
Run existing DI graph/navigation smoke checks when available. Compilation alone does not prove
runtime discovery; report that limit and any environment-blocked checks.

- [ ] Unique project is included and mapped to the created build/source tree.
- [ ] DSL, packages, plugins, targets, source sets, and dependencies match the build.
- [ ] Feature has a Compose screen and supported preview (or explicit tooling limitation).
- [ ] DI module registration or direct consumer composition is complete.
- [ ] Route, builder, required provider/serializer, and host integration are complete.
- [ ] Consumer dependency and callable route are wired without cycles or unsolicited UI actions.
- [ ] Required Detekt policy covers the module without duplicated configuration.
- [ ] No unresolved tokens, fake business types, or unrelated migrations remain.
- [ ] Exact verification commands/results and runtime-check limitations are reported.

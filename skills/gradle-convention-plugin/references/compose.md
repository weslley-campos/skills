# The Compose convention plugin

Compose is the one convention plugin whose substance is dependencies rather than DSL settings. The
compiler wiring is three lines. The value is that modules with the same role receive the same UI
stack, test dependencies and generated-resource naming without unrelated entry points inheriting
them too.

Because a dependency list is taste rather than fact, this is the one convention in the skill that
asks the user rather than deciding for them. Step 1 is that question, and it comes first — the plugin
class cannot be written before its content is known.

**Before step 1, confirm `build-logic` exists**, along with the base convention this one attaches to.
If either is missing, "Arguments, and what to do when the ground is missing" in `SKILL.md` is the
route: it is a prerequisite to ask about, not something to bootstrap silently on the way past.

## Step 1 — ask which dependencies to include

Survey the catalog before asking, so the checklist can mark which rows already have an alias and
which mean a new entry:

```bash
grep -nE "compose|material3|lifecycle|navigation" gradle/libs.versions.toml
```

This takes three passes: show everything, let the user toggle, then confirm before writing anything.

**Pass 1 — show the whole set.** Render the table below as a markdown checklist in the message, one
row per dependency, `[x]` on the pre-selected rows and `[ ]` on the rest, each with its one-line
description and a note where the alias is missing from the catalog. Nothing is hidden behind a group
name, and the defaults are visible before a single question is asked.

**Pass 2 — one multi-select question per page, four pages in one call.** The question tool allows four
options per question and four questions per call, so the negotiable rows fit in a single round trip
when paged like this:

| Page | Options, one dependency each | Default |
|---|---|---|
| Adaptive layout | `material3-adaptive`, `material3-adaptive-navigation-suite`, `material3-window-size-class`, `material3-icons-extended` | all off |
| Navigation 3 | the runtime, the display, the lifecycle-viewmodel integration, the adaptive integration | all on |
| Test | `kotlin-test`, `compose-ui-test`, the JVM desktop runtime for `jvmTest` | all on |
| Optional basics | `ui-util`, `animation`, `components-resources`, and the two lifecycle integrations as one option | all on |

Each option is one dependency. **The label is the alias and nothing else, with no `[ ]`, no `[x]` and
no check mark in it.** The tool draws the checkbox itself, so a bracket in the label text renders a
second empty box beside the real one and the row reads as two broken widgets:

```
label:       compose-ui-util
description: Layout and geometry helpers for custom components. default: on, already in catalog
```

The description carries both facts, in words, every time: the default, and whether the alias exists.
Dropping the default on the rows that happen to be in the catalog already — writing only "already in
catalog" — loses exactly the information the user needs to reproduce the marking from pass 1.

The `[x]` and `[ ]` glyphs belong to the pass 1 message and stay there. That is real markdown in
prose, where no widget can collide with it.

Checked at submit is what gets wired — the tool has no pre-checked state, so say plainly in the
question text that a page's selection replaces its defaults rather than adding to them. Two artifacts
may share one option only when nobody takes them apart, as with the lifecycle pair above; anything a
module might reasonably want alone gets its own line.

The rows that appear on no page are the floor: the runtime, foundation and ui artifacts, material3,
and the preview annotation with its IDE renderer. A module that wants none of those is not a Compose
module and does not need this plugin, so offering them as choices only invites a selection that cannot
build.

**Pass 3 — confirm, then write.** Ask one last question listing the final count and the new catalog
entries it implies, with `Proceed` and `Adjust the selection` as the options. This is the last point at
which changing course costs nothing: after it come edits to the catalog, `build-logic` and every
Compose module. Free text at any pass is where a row nobody anticipated gets added.

| Dependency | Default | What it is for |
|---|---|---|
| `compose-runtime` | `[x]` | the reactive state model, recomposition, and effects — `remember`, `mutableStateOf`, `LaunchedEffect`, snapshots |
| `compose-foundation` | `[x]` | layout, gestures, scrolling and focus — `Box`, `Row`, `LazyColumn`, `clickable` |
| `compose-ui` | `[x]` | graphics primitives and the drawing surface — `Color`, `Brush`, `ImageBitmap`, `Canvas` |
| `compose-ui-util` | `[x]` | layout and geometry helpers that custom components lean on |
| `compose-animation` | `[x]` | transitions, animated values, and the enter and exit APIs |
| `compose-material3` | `[x]` | the ready-made component set and theming: buttons, fields, cards, scaffolds |
| `compose-components-resources` | `[x]` | multiplatform strings, images and fonts, and the generated `Res` class that reads them |
| `compose-ui-tooling-preview` | `[x]` | the `@Preview` annotation itself, needed wherever a preview is declared |
| `lifecycle-runtime-compose` | `[x]` | `collectAsStateWithLifecycle`, `LocalLifecycleOwner`, and the lifecycle-aware effects |
| `lifecycle-viewmodel-compose` | `[x]` | `viewModel()` from a composable, with its scope handled |
| `compose-ui-tooling` | `[x]` | `@Preview` *rendering* in the IDE; belongs on the Android source set only, never in `commonMain` |
| `kotlin-test` | `[x]` | `@Test` and the assertion functions, in `commonTest` |
| `compose-ui-test` | `[x]` | semantics matchers, test rules, and `runComposeUiTest` |
| Compose desktop for the current OS | `[x]` | the Skiko and AWT runtime `runComposeUiTest` needs on the JVM; `jvmTest` only, and only when the build has a JVM target. Comes off the Compose extension, so it needs no catalog entry |
| navigation3 runtime | `[x]` | the back stack as an ordinary snapshot-state list the caller owns, and the entries that map a key to its content |
| navigation3 ui | `[x]` | `NavDisplay`, which renders the top of that back stack, with its transitions and predictive back. A separate artifact from the runtime, so a module that only holds keys can take one without the other |
| navigation3 lifecycle-viewmodel integration | `[x]` | a ViewModel scoped to a navigation entry rather than to the screen that shows it |
| navigation3 adaptive integration | `[x]` | scene strategies over that back stack: list-detail and supporting-pane once the window is wide enough |
| `material3-adaptive` | `[ ]` | adaptive scaffolds and the primitives for window size and device posture |
| `material3-adaptive-navigation-suite` | `[ ]` | one component that switches between navigation bar, rail and drawer by window size |
| `material3-window-size-class` | `[ ]` | the size buckets to branch a layout on, without the scaffolds above |
| `material3-icons-extended` | `[ ]` | the full Material icon set. Large in every module that gets it, and a handful of named icons is cheaper to declare by hand |

The default column is a starting point, not a house style: the basics plus the test pair plus
navigation, because those are what a module drawing screens needs before anyone asks. The adaptive
family stays unchecked because it is a layout strategy a build adopts deliberately, not a default.

Four notes that belong in the message rather than in a later surprise:

- **Navigation 3, not Navigation 2.** The four navigation rows are the `navigation3` family: a back
  stack the caller owns as state, a separate artifact that displays it, and one integration artifact
  per neighbour. That is a different API from `navigation-compose`, where a graph is declared up front
  and `NavHost` owns the stack, and the two do not compose — a module takes one or the other. So read
  the survey first. A build already on Navigation 2 keeps it and this step wires nothing new for
  navigation; say that plainly rather than adding a second navigation library beside the first.
- **The table is a portable choice menu, not a fixed dependency list.** Where the catalog
  already has an alias, use it. Where it does not, confirm the current coordinates against the
  library's own documentation before adding the entry. Navigation and adaptive artifacts have
  been renamed more than once, so a table in a skill file is the wrong place to trust for a group id.
  Navigation 3 is the youngest family on the list and the one most likely to have moved since this
  was written, so check all four before
  adding any of them.
- **The artifact family follows the module type, not preference.** A multiplatform module takes the
  `org.jetbrains.compose.*` artifacts; an Android-only module takes `androidx.compose.*` with the
  Compose BOM. Mixing the two in one convention plugin is how a build ends up with two Compose
  runtimes.
- **Rows whose alias is missing are the cost of the answer.** Say how many new catalog entries each
  unchecked-then-checked row adds, in the message, before the question. A count is something the user
  can weigh; "navigation support" is not.

**What a row costs depends on which of three states it is in**, and the survey grep at the top of this
step is what tells them apart. This applies to any convention plugin that brings dependencies, not
only this one:

- **The alias exists and names the same artifact** — use it verbatim, and change nothing about it.
  Never add a second alias for a module that already has one: two aliases for one coordinate drift
  apart at the next version bump, and a reader guessing which accessor to use is wrong half the time.
  Where the existing alias is camelCase, say so and leave it alone; renaming touches every module that
  references it, and that is the separate job in `references/migration.md`.
- **The alias is missing** — add it, taking the version from a `version.ref` that already exists rather
  than inventing a number. Artifacts published as one release share one ref: the whole
  `org.jetbrains.compose.*` set takes the Compose ref, `kotlin-test` takes the Kotlin ref, the two
  lifecycle integrations take the lifecycle ref. Only a genuinely new family needs a new `[versions]`
  entry, and that version comes from the library's own release notes rather than from memory. A
  plausible but wrong version fails at resolution with a message about a module that cannot be found,
  which reads exactly like a typo in the coordinates and sends the next hour in the wrong direction.
- **The coordinate is hardcoded in a module build file** — an `implementation("group:artifact:1.2.3")`
  string with no alias behind it. That row is a move into the catalog and out of the module, which is
  the point of the migration, so do both halves in the same pass rather than leaving the literal
  behind to shadow the new alias.

One artifact family needs no version at all: an Android-only build using the Compose BOM declares the
BOM once and its Compose artifacts without versions. Such a row still needs its alias, just with no
`version.ref` on it.

**Whatever comes back is a work list, not a preference note.** Every checked row has to end the step
with a real `[libraries]` entry in the catalog and a real line in the plugin. A row that is checked
and left unwired is the worst outcome available here, because nothing surfaces until an unresolved
reference at the first use site, in a module file that looks correct.

## Step 2 — decide the plugin shape

Choose from the module roles and base conventions found by the survey. Do not start from a preferred
shape and make every Compose consumer fit it.

Use a focused `<prefix>.compose.library` add-on when shared UI lives in library modules and the build
already has dedicated application conventions. Apply it next to the base library convention:

```kotlin
plugins {
    alias(libs.plugins.<prefix>.library)
    alias(libs.plugins.<prefix>.compose.library)
}
```

That add-on owns the dependency selection from step 1 and the resource policy from steps 5 and 6.
Application conventions own their targets and small role-specific dependency set. Apply the Compose
compiler and, for KMP entry points, Compose Multiplatform only when that entry point compiles Compose.
A JVM launcher may need the desktop runtime; a browser launcher may need browser navigation. An
Android wrapper with no Compose source and no `setContent { }` needs no Compose compiler. Entry
points do not inherit the full shared UI stack or generated-resource policy merely because they apply
`org.jetbrains.kotlin.multiplatform`.

Use a generic `<prefix>.compose` add-on only when the survey shows that the same Compose setup really
spans several module roles: the same dependencies, resource policy and plugin wiring all apply to
each consumer. If its `withPlugin` branches mostly suppress dependencies or resources for entry
points, the roles are different and the generic class is hiding that difference.

List the base convention before a Compose add-on when the base registers source sets that the add-on
configures. Applying the raw third-party plugin creates its extension, but does not register the
base convention's targets. For extension-only configuration that does not depend on those targets,
apply the raw plugin as in step 4 or react to it:

```kotlin
pluginManager.withPlugin(libs.plugins.android.application.get().pluginId) {
    // configuration that needs the Android extension to exist already
}
```

`extensions.findByType<...>()` in place of that reaction returns null on the wrong ordering and
configures nothing, silently — a module that builds, runs, and has no Compose tooling. The reaction is
two lines more and cannot be got wrong.

Before finishing this route, audit every `kotlin { }` block left in each migrated Compose consumer.
When the user asks for a Blog-style, plugin-only module file, or an existing base convention is
deliberately the complete topology for that dedicated role, move that role's remaining target setup
into the base role convention too — including the exact JVM/JS target names, `browser` or `nodejs`,
binary kind, and any source-set dependency intrinsic to that role. Preserve the declarations exactly
and remove them from the module so no target is registered twice. In a compiled plugin class use
`sourceSets.apply { jsMain.dependencies { ... } }`; the build-script `sourceSets { ... }` accessor may
not compile there. A target or dependency that is genuinely specific to the module stays explicit.
See `references/targets.md` for the ownership test; do not give other consumers targets they did not
already have merely to make one module file shorter.

## Step 3 — the compiler, and the two Android DSLs

Three facts drive the conventions, and each one is verifiable in seconds with the recipe in
`references/conventions.md` under "Verify the types before you commit to them":

1. **AGP 9 built-in Kotlin support does not bring the Compose compiler.** AGP applies KGP itself, so
   no `org.jetbrains.kotlin.android` is needed for Kotlin to compile — but
   `org.jetbrains.kotlin.plugin.compose` is a separate KGP plugin that AGP never applies. The
   convention for every module that compiles composables must apply it.
2. **`buildFeatures.compose` is not the compiler and is not obsolete.** It still exists on
   `BuildFeatures` in current AGP and still defaults to `false`; it drives the AGP and IDE side,
   previews and Live Edit. Set it for classic Android modules that compile Compose; it does not
   make composables compile by itself.
3. **It exists on the classic DSL only.** `KotlinMultiplatformAndroidLibraryExtension` has no
   `buildFeatures` member at all, so a multiplatform Android library has nothing to set and needs no
   equivalent. A generic add-on needs separate `withPlugin` reactions because each branch touches a
   DSL the other one does not have; a role-specific convention should touch only its own DSL.

The compiler version is not a decision any more: since Kotlin 2.0 the Compose compiler ships with
KGP and tracks it. A catalog entry pinning a separate compiler version is a leftover to delete.

## Step 4 — the plugin class

For shared Compose library modules, add one focused class beside the existing base library
convention. It applies the raw third-party plugins needed to create its extensions, then delegates
the shared dependency and resource work to `extensions/Compose.kt`:

```kotlin
import extensions.configureComposeMultiplatform
import extensions.configureComposeResources
import extensions.libs
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure
import org.jetbrains.kotlin.gradle.dsl.KotlinMultiplatformExtension

class ComposeLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = libs.plugins.multiplatform.library.get().pluginId)
        apply(plugin = libs.plugins.compose.multiplatform.get().pluginId)
        apply(plugin = libs.plugins.compose.compiler.get().pluginId)

        extensions.configure<KotlinMultiplatformExtension>(::configureComposeMultiplatform)
        configureComposeResources()
    }
}
```

`libs.plugins.multiplatform.library` is the raw third-party id the base convention also applies, not
`<prefix>.library`. The module still declares both project convention aliases, with the base first:
it owns the targets and Android configuration that the Compose helper reads. Reapplying the raw id is
a no-op after the base runs. Do not drop the base alias.

Application conventions apply the Compose compiler only if their entry points compile Compose; KMP
entry points that do so also apply `org.jetbrains.compose`. Keep target declarations and role-specific
dependencies there. Do not call the shared UI or resource helpers from an entry point unless it owns
those policies.

One trap when deciding whether an application convention needs the compiler: `setContent { }` takes
a `@Composable` lambda, so a module whose only Compose is that one call still needs it. Absence of a
declared `@Composable` function in the module proves nothing. A classic Android application that
compiles Compose also sets `buildFeatures.compose = true`; a KMP application DSL has no such member.

### If step 2 chose the generic add-on

Keep the same helpers, but call them only for module roles that share their entire dependency and
resource policy. React to raw third-party ids for extension availability, and still apply the base
convention before this add-on when the helper reads target source sets:

```kotlin
class ComposeConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = libs.plugins.compose.compiler.get().pluginId)

        pluginManager.withPlugin(libs.plugins.kotlin.multiplatform.get().pluginId) {
            apply(plugin = libs.plugins.compose.multiplatform.get().pluginId)
            extensions.configure<KotlinMultiplatformExtension>(::configureComposeMultiplatform)
            configureComposeResources()
        }
    }
}
```

Add only the branches the survey justifies. A branch that exists mainly to avoid giving an entry
point the dependencies or resources configured by another branch is evidence for separate
role-specific conventions instead.

Add only the `DependencyHandler` helpers these conventions need from `references/conventions.md`
under `extensions/Dependencies.kt`. `androidRuntimeClasspath` applies only to an AGP 9 KMP Android
library branch where that configuration exists.

## Step 5 — `extensions/Compose.kt`

The rows checked in step 1 land here. Match source-set access to the module role the convention
guarantees. This example assumes the surveyed library convention always registers Android and may
register JVM; adjust those two accesses to the real target guarantees. A helper reused by library,
web, and desktop roles instead uses `findByName` for each optional platform source set:

```kotlin
package extensions

import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.dependencies
import org.gradle.kotlin.dsl.getByType
import org.jetbrains.compose.ComposeExtension
import org.jetbrains.compose.resources.ResourcesExtension
import org.jetbrains.kotlin.gradle.dsl.KotlinMultiplatformExtension

internal fun Project.configureComposeMultiplatform(extension: KotlinMultiplatformExtension) {
    // Only needed for `compose.desktop.currentOs` below: that one is an accessor on the Compose
    // extension rather than a catalog coordinate, since the artifact varies by host.
    val compose = extensions.getByType<ComposeExtension>().dependencies

    extension.apply {
        sourceSets.apply {
            commonMain.dependencies {
                // One implementation line per checked row, each under a one-line comment saying what
                // the artifact is for. The alias does not say why the module needs it.
                implementation(libs.compose.runtime)
                // ...
            }

            androidMain.dependencies {
                // @Preview rendering in the IDE, as opposed to the annotation.
                implementation(libs.compose.ui.tooling)
            }

            // JVM is optional in this surveyed library role; omit the lookup only when it is a
            // guaranteed target.
            findByName("jvmTest")?.dependencies {
                // The Skiko and AWT runtime that runComposeUiTest needs on the JVM.
                implementation(compose.desktop.currentOs)
            }

            commonTest.dependencies {
                implementation(libs.kotlin.test)
                implementation(libs.compose.ui.test)
            }
        }
    }
}
```

Keep the `extension.apply { sourceSets.apply { ... } }` receiver when passing this helper to
`extensions.configure<KotlinMultiplatformExtension>(::configureComposeMultiplatform)`. Omitting the
outer receiver can fail to compile the helper. The build-script `sourceSets { ... }` accessor may not
be available in a compiled plugin class. Inside it, prefer direct source-set
properties whenever the convention guarantees the target:

```kotlin
sourceSets.apply {
    androidMain.dependencies {
        implementation(libs.compose.ui.tooling)
    }
    commonMain.dependencies {
        // ...
    }
    commonTest.dependencies {
        // ...
    }
}
```

Use `findByName(...)?` only for genuinely optional source sets. A generic KMP helper used across
roles may need it for `androidMain` and `jvmTest`; the focused example above uses direct
`androidMain` because its base convention guarantees Android. Keep a nearby comment explaining
which supported role lacks an optional target.

The preview renderer needs the tooling artifact on the Android **runtime** classpath. The
`androidMain` placement above is the portable one. On the AGP 9 multiplatform library DSL,
`androidRuntimeClasspath` keeps tooling off the compile classpath where it belongs:

```kotlin
dependencies.androidRuntimeClasspath(libs.compose.ui.tooling)
```

Import the helper from `extensions/Dependencies.kt` and use it only in the AGP 9 KMP Android branch
where that configuration exists. Do not add both placements — one of them is then dead weight that
no error will ever point at.

## Step 6 — generated resources, for multiplatform modules

Skip this step for Android-only Compose modules, which use ordinary Android resources.

Compose Multiplatform generates a `Res` class per module. Left at its default, every module generates
the same class name in a package derived from the module coordinates, and a screen importing two of
them has to disambiguate by hand. Naming the class and its package from the module path is what makes
resources usable across a modularised build:

```kotlin
internal fun Project.configureComposeResources() {
    extensions.getByType<ComposeExtension>().extensions.configure<ResourcesExtension> {
        nameOfResClass = path.toResClassName()
        packageOfResClass = "$ROOT_PACKAGE.${path.removePrefix(":").replace(":", ".")}.resources"
        publicResClass = true
        generateResClass = auto
    }
}

/** `:feature:home` becomes `FeatureHomeRes` — unique per module, and readable at the use site. */
internal fun String.toResClassName(): String = split(":")
    .filter(String::isNotEmpty)
    .joinToString("", postfix = "Res") { it.replaceFirstChar(Char::uppercaseChar) }
```

`generateResClass = auto` so a library with no `composeResources/` directory generates nothing,
which keeps the convention applicable to every shared Compose library rather than only the ones
holding assets.

`publicResClass = true` only if modules consume each other's resources; leave it out otherwise, since
an internal class is the better default.

`ResourcesExtension` is the second reason the Compose Gradle plugin has to be on the `build-logic`
compile classpath, alongside step 5. Renaming the `Res` class or its package **changes every
import at the use sites** — expect to fix them in the same commit, and grep for the old name rather
than waiting for the compiler to list them one at a time.

## Step 7 — catalog and classpath entries

Four edits, in addition to the ones in "Working on a build that already has build-logic" in
`SKILL.md`:

```toml
[libraries]
# Dependencies of the included build-logic
compose-gradle-plugin = { module = "org.jetbrains.compose:compose-gradle-plugin", version.ref = "compose" }

[plugins]
compose-multiplatform = { id = "org.jetbrains.compose", version.ref = "compose" }
compose-compiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }

# Focused shared-library add-on, beside the existing base library convention:
<prefix>-compose-library = { id = "<prefix>.compose.library" }
# Use this instead only when the surveyed setup genuinely spans module roles:
<prefix>-compose = { id = "<prefix>.compose" }
```

- `compose-compiler` takes `version.ref = "kotlin"`, not a version of its own. See step 3.
- `compose-gradle-plugin` is what puts `ComposeExtension` on the compile classpath, so it is needed
  by the resource naming in step 6 and by `compose.desktop.currentOs` in step 5. A plugin that applies
  Compose by id and reads no Compose extension needs no new `build-logic` dependency at all.
- `compileOnly(libs.compose.gradle.plugin)` in `convention/build.gradle.kts`, for the same reason AGP
  and KGP are `compileOnly` — invariant 2 in `SKILL.md`.
- `alias(libs.plugins.compose.multiplatform) apply false` and `alias(libs.plugins.compose.compiler)
  apply false` in the root `build.gradle.kts`, so both resolve once for the whole build.

Every alias stays kebab-case: `compose-ui-tooling-preview` reads as `libs.compose.ui.tooling.preview`
at the use site, and a camelCase alias produces an accessor nobody can guess.

## Deliberately not here

**The `composeCompiler { }` block.** Reports, metrics, a stability configuration file and feature
flags are all real reasons to reach for it, and none of them apply to a build that has not yet asked
"why is this screen recomposing". It also costs another `compileOnly` dependency for the typed
extension. Add it when someone wants the numbers, and put the destinations behind a Gradle property
so the reports are opt-in rather than built on every run.

**Per-dependency documentation comments.** A one-line comment naming what an artifact is for is worth
it on a list this long, since the alias alone does not say why the module needs it. A paragraph per
dependency is a second changelog that goes stale silently.

## Verify

The gates in `SKILL.md` apply unchanged. Compose adds one that matters, because a Compose module can
configure and resolve perfectly and still fail to compile a single composable:

```bash
./gradlew -p build-logic :convention:check
./gradlew help
./gradlew assemble          # the only gate that proves the compiler plugin is actually wired
```

If `assemble` reports that a `@Composable` invocation can only happen inside another `@Composable`
function, the compiler plugin is not applied to that module — its role convention in steps 3 and 4
is where to look, not the dependency list.

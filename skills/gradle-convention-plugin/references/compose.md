# The Compose convention plugin

Compose is the one convention plugin whose substance is dependencies rather than DSL settings. The
compiler wiring is three lines. The value is that every Compose module receives the same UI stack,
the same test dependencies and the same generated-resource naming without any module repeating them.

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
- **The table names roles, not coordinates.** Where the catalog already has an alias, use it. Where it
  does not, confirm the current coordinates against the library's own documentation before adding the
  entry — the navigation and adaptive artifacts in particular have been renamed more than once, and a
  table in a skill file is the wrong place to trust for a group id. Navigation 3 is the youngest family
  on the list and the one most likely to have moved since this was written, so check all four before
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

Two shapes work. **Prefer the add-on**, and read the alternative before ruling it out.

Check the base conventions first, though: if they are already two separate classes because their
DSLs share no supertype — a classic `com.android.application`/`com.android.library` extension versus
a Kotlin Multiplatform Android library target's own DSL, the split Step 3 describes — pairing mirrors
a split the codebase already made, instead of re-introducing it as `withPlugin` branches inside one
new class. Prefer the add-on when the base conventions are unified enough that one Compose class
reacting to each ecosystem's plugin id would not be duplicating a division that already exists
elsewhere in `build-logic`.

**An add-on plugin** — `<prefix>.compose`, applied *next to* whichever base convention the module
already has, adding nothing but Compose:

```kotlin
plugins {
    alias(libs.plugins.<prefix>.library)
    alias(libs.plugins.<prefix>.compose)
}
```

One class then serves every module type in the build. That is the whole argument: Compose is
orthogonal to what kind of module something is, so folding it into the base conventions means a
`library`, an `application` and a `jvm` variant of the same twenty dependency lines, and the fourth
module type multiplies again. The module file also says out loud that this module draws UI, which is
worth one extra line.

Name the id `<prefix>.compose`, without a module type in it. An id ending in `library` reads as a
contradiction the moment it sits under `alias(libs.plugins.<prefix>.android.application)`, and it
will, because the application module needs Compose too.

**A pairing plugin** — one class per base convention Compose combines with,
`<prefix>.compose.application` next to `<prefix>.compose.library`, each applying its own base plugin
before wiring Compose. The module still declares both ids:

```kotlin
plugins {
    alias(libs.plugins.<prefix>.library)
    alias(libs.plugins.<prefix>.compose.library)
}
```

**Apply the third-party base plugin from the Compose class — the raw `com.android.application` or the
raw multiplatform-library id — never this project's own base convention id.** A base convention that
does real work beyond enabling Compose (setting `namespace` and `compileSdk`, registering iOS targets,
whatever a `configureAndroid`/`configureLibrary` step does) only runs when *its own* alias is applied.
The trap is applying that convention id from the Compose class instead of the raw plugin, then dropping
the base alias from the module file on the reasoning that the Compose class now covers it — that
configuration silently never runs once the base alias is gone. The failure surfaces far from the cause:
AGP demanding `compileSdk` or a namespace that plainly is set somewhere in the convention plugin —
because it is, just in a class nothing ever applies.

Applying the raw third-party id from the Compose class removes the ordering question below without
removing the base alias: whichever id the module lists first, the other `apply()` call either
configures the extension for the first time or is a no-op on an id already applied — Gradle tolerates
applying the same plugin id twice. What the pairing shape actually buys, once both shapes need two
aliases in the module file, is a smaller class with no `withPlugin` reaction to write, not a shorter
`plugins { }` block.

The add-on carries one real hazard: anything it reads off another plugin's extension is absent if the
module happens to list the add-on first. Guard it by reacting rather than reading:

```kotlin
pluginManager.withPlugin(libs.plugins.android.application.get().pluginId) {
    // configuration that needs the Android extension to exist already
}
```

`extensions.findByType<...>()` in place of that reaction returns null on the wrong ordering and
configures nothing, silently — a module that builds, runs, and has no Compose tooling. The reaction is
two lines more and cannot be got wrong.

## Step 3 — the compiler, and the two Android DSLs

Three facts drive the whole class, and each one is verifiable in seconds with the recipe in
`references/conventions.md` under "Verify the types before you commit to them":

1. **AGP 9 built-in Kotlin support does not bring the Compose compiler.** AGP applies KGP itself, so
   no `org.jetbrains.kotlin.android` is needed for Kotlin to compile — but
   `org.jetbrains.kotlin.plugin.compose` is a separate KGP plugin that AGP never applies. The
   convention plugin applies it, always, for every module type.
2. **`buildFeatures.compose` is not the compiler and is not obsolete.** It still exists on
   `BuildFeatures` in current AGP and still defaults to `false`; it drives the AGP and IDE side,
   previews and Live Edit. Set it, and do not expect it to make anything compile.
3. **It exists on the classic DSL only.** `KotlinMultiplatformAndroidLibraryExtension` has no
   `buildFeatures` member at all, so a multiplatform Android library has nothing to set and needs no
   equivalent. This is the one hard branch in a plugin that covers both module types, and it is why
   the branches in step 4 are `withPlugin` reactions on the base plugin rather than a condition on
   the module: each branch touches a DSL the other one does not have.

The compiler version is not a decision any more: since Kotlin 2.0 the Compose compiler ships with
KGP and tracks it. A catalog entry pinning a separate compiler version is a leftover to delete.

## Step 4 — the plugin class

One class, applied on top of whichever base convention the module declares. The compiler plugin is
unconditional. Everything else hangs off a reaction to the plugin that creates the DSL that branch
needs:

```kotlin
import com.android.build.api.dsl.CommonExtension
import extensions.configureComposeMultiplatform
import extensions.configureComposeResources
import extensions.debugImplementation
import extensions.implementation
import extensions.libs
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.dependencies

/**
 * Compose for any module that opts into it, applied next to that module's own convention plugin —
 * `<prefix>.library` or `<prefix>.android.application` — in either order.
 */
class ComposeMultiplatformConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        // Every module type needs this, and no module type gets it for free: AGP's built-in Kotlin
        // support compiles Kotlin and never applies the Compose compiler.
        apply(plugin = libs.plugins.compose.compiler.get().pluginId)

        // The classic DSL, where `buildFeatures.compose` exists at all.
        pluginManager.withPlugin(libs.plugins.android.application.get().pluginId) {
            extensions.configure<CommonExtension> {
                buildFeatures.compose = true
            }
            dependencies {
                implementation(libs.compose.ui.tooling.preview)
                debugImplementation(libs.compose.ui.tooling)
            }
        }

        // The multiplatform DSL: the shared UI stack and the generated-resource naming.
        pluginManager.withPlugin(libs.plugins.kotlin.multiplatform.get().pluginId) {
            apply(plugin = libs.plugins.compose.multiplatform.get().pluginId)
            configureComposeMultiplatform()
            configureComposeResources()
        }
    }
}
```

Reacting to the **third-party** ids rather than to `<prefix>.library` is what makes the order inside
the module's `plugins { }` block irrelevant. Whichever convention runs second, its `com.android.*` or
`org.jetbrains.kotlin.multiplatform` application fires a reaction that is already registered. Add one
`withPlugin` branch per base plugin the build actually has, `com.android.library` included if there
are classic library modules, and the same Compose plugin serves all of them.

`org.jetbrains.compose` is applied in the multiplatform branch only. An application module consuming
composables from a shared module needs the artifacts and the compiler, not the resource generation
machinery, and applying a plugin whose work has no inputs is how a build acquires tasks nobody can
account for.

The dependency split follows the same line. Where the UI lives in a shared multiplatform module, the
application branch above is complete as written — preview tooling is all it needs, because everything
else arrives transitively. In a single-module Android-only Compose build there is no `commonMain`, so
the rows checked in step 1 go on `implementation` in that branch instead, alongside the Compose BOM.

One trap when deciding whether an application module needs this plugin at all: `setContent { }` takes
a `@Composable` lambda, so a module whose only Compose is that one call still needs the compiler
plugin. Absence of `@Composable` in the module's own sources proves nothing.

### If step 2 chose the pairing shape instead

One class per base convention, each applying the **third-party** base plugin — not this project's own
base convention id — before wiring Compose. Same compiler line, same DSL branch as the add-on above;
the difference is that each class touches only the one DSL its own base plugin creates, applied
directly rather than reacted to:

```kotlin
import com.android.build.api.dsl.CommonExtension
import extensions.debugImplementation
import extensions.implementation
import extensions.libs
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.dependencies

class ComposeApplicationConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = libs.plugins.android.application.get().pluginId)
        apply(plugin = libs.plugins.compose.compiler.get().pluginId)

        extensions.configure<CommonExtension> {
            buildFeatures.compose = true
        }
        dependencies {
            implementation(libs.compose.ui.tooling.preview)
            debugImplementation(libs.compose.ui.tooling)
        }
    }
}
```

```kotlin
import extensions.configureComposeMultiplatform
import extensions.configureComposeResources
import extensions.libs
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.apply

class ComposeLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = libs.plugins.multiplatform.library.get().pluginId)
        apply(plugin = libs.plugins.compose.multiplatform.get().pluginId)
        apply(plugin = libs.plugins.compose.compiler.get().pluginId)

        configureComposeMultiplatform()
        configureComposeResources()
    }
}
```

`libs.plugins.android.application` and `libs.plugins.multiplatform.library` here are the raw AGP ids —
the same ones the base convention plugins themselves apply — not `<prefix>.android.application` or
`<prefix>.library`. Applying this project's own base convention id from inside the Compose class looks
tempting, since it is what would let the module file drop to a single alias, but that base convention
plugin is where `configureAndroid`/`configureLibrary` and everything past enabling Compose lives, and
skipping its alias skips all of it. **Both module files still declare the base convention alias next to
the Compose one**, exactly as step 2 shows; only the raw third-party `apply()` inside the Compose class
is new here, there only to make its own extension available regardless of which alias the module lists
first. `extensions/Compose.kt` from step 5 is unchanged either way; both shapes call the same two
functions, only from a different class.

## Step 5 — `extensions/Compose.kt`

The rows checked in step 1 land here. `commonMain` is the only source set every multiplatform module
is guaranteed to have, so anything platform-specific is a **defensive lookup**:

```kotlin
internal fun Project.configureComposeMultiplatform() {
    // Only needed for `compose.desktop.currentOs` below: that one is an accessor on the Compose
    // extension rather than a catalog coordinate, since the artifact varies by host.
    val compose = extensions.getByType<ComposeExtension>().dependencies

    extensions.configure<KotlinMultiplatformExtension> {
        sourceSets.apply {
            commonMain.dependencies {
                // One implementation line per checked row, each under a one-line comment saying what
                // the artifact is for. The alias does not say why the module needs it.
                implementation(libs.compose.runtime)
                // ...
            }

            // androidMain exists only when an Android target is registered. A single-target module —
            // a desktop or web entry point — has no such source set, and getByName would fail the
            // whole configuration phase for a dependency it does not need.
            findByName("androidMain")?.dependencies {
                // @Preview rendering in the IDE, as opposed to the annotation.
                implementation(libs.compose.ui.tooling)
            }

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

`findByName(...)?` rather than `getByName(...)`, with the comment kept: the next person to add a
single-target module is the one it protects, and the failure it prevents names a source set rather
than the missing target.

The preview renderer needs the tooling artifact on the Android **runtime** classpath. The
`androidMain` placement above is the portable one. On the AGP 9 multiplatform library DSL there is
also a runtime-only configuration, which keeps tooling off the compile classpath where it belongs;
confirm the configuration name against the AGP on the classpath before using it, and do not add both
placements — one of them is then dead weight that no error will ever point at.

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

`generateResClass = auto` so a module with no `composeResources/` directory generates nothing, which
keeps the convention applicable to every Compose module rather than only the ones holding assets.
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

# Plugins defined by this project — the add-on shape takes one id:
<prefix>-compose = { id = "<prefix>.compose" }
# the pairing shape takes one id per base convention, alongside each one's own existing entry:
<prefix>-compose-application = { id = "<prefix>.compose.application" }
<prefix>-compose-library = { id = "<prefix>.compose.library" }
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
function, the compiler plugin is not applied to that module — the module type branch in step 3 is
where to look, not the dependency list.

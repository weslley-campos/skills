---
name: gradle-convention-plugin
description: >
  Set up Gradle convention plugins in a `build-logic` included build and migrate existing module
  build files onto them, for Kotlin, Android and Kotlin Multiplatform projects. Use this skill
  whenever the user mentions convention plugins, build-logic, buildSrc, `includeBuild`, sharing or
  deduplicating Gradle configuration across modules, "every module repeats the same android { }
  block", pulling compileSdk / minSdk / namespace / jvmTarget into one place, the Now in Android
  build setup, shared Compose or Koin setup, or asks to tidy up, standardise or modularise a Gradle
  build — even when they never say "convention plugin" out loud. Also use when adding another
  convention plugin to a build that already has build-logic.
---

# Gradle convention plugins

Take a build where every module repeats the same `android { }`, `compileSdk`, `jvmTarget` and
`compileOptions`, and leave one where a module declares a plugin id and its dependencies, and
nothing else.

This skill is deliberately not tied to one project. Every name, package, version and module type is
read out of the repository you are working in — the templates use `<placeholders>` precisely so they
get filled from a survey of the real build, never copied verbatim.

## Start here

**Bootstrapping a build that has no `build-logic` yet**, and migrating its modules onto it, is the
main path: follow `references/init.md`, which is the whole job in six steps. Begin with step 1, the
survey — it is cheaper and more complete than opening the files one at a time, and every decision
after it derives from what it prints.

**Adding one more convention plugin to a build that already has `build-logic`** is the section at
the bottom of this file, plus its focused reference: `references/compose.md` for Compose,
`references/koin.md` for Koin, or `references/conventions.md` for the base class templates.

Either way, `## Verify` below is the gate, and `references/troubleshooting.md` maps the error you
actually see to the cause.

## Arguments, and what to do when the ground is missing

An argument names one convention to add — `compose` or `koin`, for instance. Run the survey before
deciding anything either way, because the route depends on whether `build-logic` already exists,
and the survey prints exactly that line.

| Invocation | `build-logic` | Route |
|---|---|---|
| an argument | present | straight to that convention's reference, plus the four edits at the bottom of this file |
| an argument | absent | `init` first, but **ask** — see **A missing scaffold** below |
| no argument | absent | `references/init.md`, and **ask** what happens when it finishes — see **An empty argument** |
| no argument | present | survey, then **ask** which convention to add, and never pick one unprompted |

**An empty argument is ambiguous, so treat it as ambiguous.** It might mean "do the whole job", and
it might mean the convention name was left off by accident. Those are cheap to tell apart by asking
and expensive to guess at, since guessing "the whole job" rewrites every module build file in the
repository.

- With no `build-logic`, both readings begin identically, because a named convention needs the
  scaffold underneath it either way. That makes the question a narrow one: run `init` and stop at its
  verify gate, or run `init` and carry straight on into a named convention — and if so, which. Ask
  that as one question rather than two, and let the answer arrive before `init` starts, so the plan
  does not change halfway through a migration.
- With `build-logic` present there is no sensible default at all. Run the survey, report which module
  types have no convention of their own and which blocks are still repeated across module files, and
  ask which to add. The survey output is what makes that question answerable rather than a blank
  prompt: it turns into a short menu of what this specific build is missing.

Never settle an empty argument by picking the most likely convention. A wrong guess is a plugin
class, a catalog entry, a registration and a root `apply false` line, landed in a build whose owner
then has to read the diff to find out what was decided for them.

**A missing scaffold** is a prerequisite, not a mistake. Someone asking for one convention plugin has
not asked for their whole build to be rewritten, and `init` touches the root settings file, the root
build file, the catalog, and every module build file. So state that scope in one short block, then
ask whether to run `init` first and continue into the requested convention afterwards, or to stop
there so they can look at the diff first.

Do not run `init` silently on the grounds that it is required. Required is what makes it worth
asking about — it is a larger change than the one requested, and the person who typed one word gets
to see that before it happens. Do not try to skip it either: without `build-logic` there is nowhere
to put the plugin class, and a convention plugin improvised into a module build file costs more to
unpick than the question costs to ask.

When they approve both, **finish `init` and get its `## Verify` gate green before starting the
requested convention.** Stacking a new convention on an unverified scaffold makes the two failure
modes indistinguishable, and the scaffold errors in this area already point somewhere other than
their cause.

A narrower version of the same situation: `build-logic` exists, but the base convention the
requested add-on sits next to does not — a Compose or Koin add-on with no library or application
convention under it. That single module is an `init`-mode migration of its own, on the same terms.
Say so and ask, rather than inventing a base convention nobody requested.

## The shape you are building

```
<root>/
├── settings.gradle.kts              includeBuild("build-logic"), inside pluginManagement
├── build.gradle.kts                 every plugin declared once, all `apply false`
├── gradle/libs.versions.toml        versions, plugin coordinates, and the convention plugin ids
├── build-logic/
│   ├── settings.gradle.kts          its own repositories, and the catalog re-declared
│   └── convention/
│       ├── build.gradle.kts         compileOnly AGP/KGP, plugin registration, catalog accessors
│       └── src/main/kotlin/
│           ├── <Type>ConventionPlugin.kt   one class per module type, default package
│           └── extensions/                 shared internal helpers, where the real work lives
└── <module>/build.gradle.kts        plugins { alias(...) } + dependencies { }, and that is all
```

## Verify

```bash
./gradlew --stop            # old daemons hold the old plugin classpath and will lie to you
./gradlew -p build-logic :convention:check  # compiles build-logic and runs validatePlugins
./gradlew help              # configures every project: catches ids, classpath and DSL errors
./gradlew assemble          # actually compiles: catches jvmTarget and sdk mistakes
```

The included-build `check` is the plugin-authoring gate because it runs `validatePlugins`. `help` is
the fast root gate — it configures the whole build without compiling, which is where almost every
convention-plugin mistake lives. Only move on when both are green. If any command fails, go to
`references/troubleshooting.md`; the errors in this area are famously indirect, and the table maps
the message you actually see to the cause.

Report the result honestly, including which command you ran. "The build configures" and "the app
compiles" are different claims.

## The four invariants

These are the load-bearing decisions. Everything else is detail, but break one of these and the
build fails in a way whose error message points somewhere else entirely. Invariants 1 and 3 are
settled once, when `build-logic` is created; invariants 2 and 4 bite again every time a convention
plugin is added.

1. **`includeBuild("build-logic")` goes inside `pluginManagement { }`** in the root
   `settings.gradle.kts`. An included build declared at the top level of the settings file
   contributes dependency substitutions but not plugin ids, so the ids never resolve — and the error
   blames the plugin, not the placement.

2. **AGP and KGP are `compileOnly` in `convention/build.gradle.kts`.** The convention plugins need
   them to compile, but must not republish them. The consuming build gets them from the root
   `plugins { alias(...) apply false }` block, which resolves each exactly once for the whole build
   — one AGP, one KGP, one classloader. Use `implementation` instead and you get the same plugin
   loaded twice under different classloaders, which surfaces as a `ClassCastException` between two
   classes with the same name.

3. **`build-logic` needs the catalog re-declared** in its own `settings.gradle.kts` via
   `from(files("../gradle/libs.versions.toml"))`. An included build does not inherit
   `dependencyResolutionManagement`.

4. **Plugin classes do not get `libs` for free.** Gradle injects the typed catalog accessor into
   build *scripts* only ([gradle/gradle#15383](https://github.com/gradle/gradle/issues/15383)).
   Putting `LibrariesForLibs` on the compile classpath and exposing it as one `internal val
   Project.libs` is what lets every convention plugin read the catalog. `references/scaffold.md`
   has the two pieces; they only work together.

## Working on a build that already has build-logic

Adding a convention plugin to an existing setup is the plugin class from
`references/conventions.md`, plus four edits that are easy to forget and produce a confusing failure
when missed:

- Register the new id in `gradlePlugin { plugins { register(...) } }` in
  `convention/build.gradle.kts`. The class is found by registration, not by filename — an
  unregistered plugin class is invisible no matter what it is called.
- Add the id to `[plugins]` in the catalog and read it *through the catalog* in the registration, so
  the registration and the modules' `alias(...)` calls cannot drift apart.
- If the new convention applies a third-party plugin that is not already on the root classpath, give
  it its own entry in `[libraries]` or `[plugins]` in the catalog. Skip it and `build-logic` fails to
  compile with an unresolved catalog accessor, before the new convention plugin ever runs.
- Add that same plugin's `apply false` line to the root `build.gradle.kts`. Skip it and the plugin
  only exists on `build-logic`'s `compileOnly` classpath, which breaks the single-classloader
  guarantee invariant 2 describes.

Before writing it, check that it earns a convention plugin at all: the configuration has to be a
property of a *kind* of module, with more than one module of that kind. One module needing a library
is a dependency line, not a convention — see "Things that look shared but are not" in
`references/migration.md`.

## Reference files

- `references/init.md` — bootstrap `build-logic` and migrate the modules, in six steps
- `references/scaffold.md` — every file `init` creates, and the catalog entries, in full
- `references/conventions.md` — plugin and extension templates per module type, and AGP 8 vs 9
- `references/compose.md` — the Compose convention plugin, whose dependency list is asked, not assumed
- `references/koin.md` — add the Koin compiler plugin, including migration cleanup from KSP
- `references/migration.md` — what to delete from a module, what must stay, with before/after
- `references/troubleshooting.md` — error message → cause → fix

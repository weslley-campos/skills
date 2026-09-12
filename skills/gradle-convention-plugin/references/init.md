# Mode: init — bootstrap build-logic and migrate the modules

This mode bootstraps `build-logic` in a build that has none, then migrates the existing modules
onto it, one at a time. Nothing here is a value to copy verbatim — every name, package, version and
module type is read out of the repository being worked in, which is what the `<placeholders>` are
for.

## Step 1 — Survey before you write anything

Run the bundled script from the repository root:

```bash
bash <skill-dir>/scripts/survey.sh
```

It prints the Gradle and JDK versions, the settings file, the root build file, the version catalog,
every module build file, and whether `build-logic` or `buildSrc` already exists. Read that output
before deciding anything — it is cheaper and more complete than opening the files one at a time.

If the script is unavailable, read by hand: `gradle/wrapper/gradle-wrapper.properties`,
`settings.gradle.kts`, `build.gradle.kts`, `gradle/libs.versions.toml`, and each module's
`build.gradle.kts`.

**Stop early if the ground is wrong.** This skill assumes the Kotlin DSL (`.kts`) and a version
catalog at `gradle/libs.versions.toml`. If the build is Groovy DSL, say so and offer to convert
first — convention plugins on a Groovy build are possible but nothing below applies unmodified. If
there is no catalog, offer to create one first; the whole design leans on it as the single source
of versions.

If `buildSrc` already exists, point out that Gradle recommends an included build for convention
plugins: it is independently structured, and changes to one build-logic subproject need not make
unrelated build-logic subprojects out-of-date. Ask before deleting anything.

## Step 2 — Decide the five things everything else derives from

Work these out from the survey, then state them back to the user in one short block and let them
correct you. Getting these wrong is expensive to undo later; asking costs one message.

| Decision | How to derive it | Example |
|---|---|---|
| **Plugin id prefix** | `rootProject.name` lowercased, letters only — shortened to the recognisable stem if that comes out unwieldy. It namespaces the ids so they can never collide with a third-party plugin, and it appears in every module file, so confirm it. | `nowinandroid`, `acme` |
| **Root package** | The sole app's existing `applicationId`; with multiple apps, the shortest common dot-segment prefix of their ids or module namespaces. | `br.com.example` |
| **Which conventions** | One per *module type present in the build*, not per module. Do not invent a convention for a shape that does not exist yet. | application + kmp-library |
| **Application identity** | Count Android application modules. With one, its namespace, application id and version may be centralised. With more than one, each module keeps those values. | one app: shared; two apps: module-specific |
| **AGP generation** | The `agp` version in the catalog. AGP 8 and AGP 9 differ in ways that will not compile against each other — see `references/conventions.md`. | `9.0.1` → AGP 9 |

The plugin ids follow from the prefix: `<prefix>.android.application`,
`<prefix>.android.library`, `<prefix>.multiplatform.library`. Catalog aliases are the same words in
kebab-case (`<prefix>-android-application`), which is what makes `alias(libs.plugins.<prefix>.android.application)`
resolve.

## Step 3 — Scaffold `build-logic`

Follow `references/scaffold.md`. It has the scaffold files to create and the root files to edit, in
full, with the reasoning attached to each. Create them in this order — `build-logic/settings.gradle.kts` first,
because the rest is meaningless without it.

## Step 4 — Move the constants into the catalog

Every literal you are about to delete from a module needs a home. Add `android-compile-sdk`,
`android-min-sdk`, `android-target-sdk` and `jvm-target` to `[versions]`; for a single application,
also add `app-version-code` and `app-version-name`, while multiple applications keep identity and
version values in their module files. Add the AGP and Kotlin Gradle plugin *artifacts* to
`[libraries]` (the convention plugins compile against them), and the new convention plugin ids to
`[plugins]`.

**When the modules disagree, say so before you pick.** Centralising a value silently resolves every
existing conflict, and that resolution is a real change to the build even though it looks like a
refactor. If one module is on `compileSdk = 34` and the rest on 35, or one sets a different
`jvmTarget`, name the modules and the values, say which you are standardising on and why, and note
the consequence — raising a module's `compileSdk` can surface new deprecation warnings or lint
failures that were previously invisible. Usually the drift is the accident the user is trying to
fix and the highest value wins, but that is their call to confirm, not yours to assume.

Catalog aliases are kebab-case, never camelCase: Gradle maps `-` to `.` in the generated accessors,
so `android-compile-sdk` reads as `libs.versions.android.compile.sdk`, and a camelCase alias
produces an accessor nobody can guess. If the existing catalog is camelCase, renaming it is a
mechanical follow-up worth offering, but keep it as a separate step so the migration diff stays
readable.

Exact entries: `references/scaffold.md`, section "Version catalog".

## Step 5 — Write the convention plugins

Follow `references/conventions.md`. The division of labour that makes this maintainable:

- **`extensions/`** holds everything shared and is where nearly all the code lives. `Project.kt`
  bridges the version catalog into plugin classes; `Android.kt` holds the actual configuration.
- **A convention plugin class** applies the third-party plugins by id, calls the shared helper, and
  then configures only what exists on *its* DSL and no other. An application module has an
  `applicationId`, `targetSdk`, `versionCode` and a release build type; a library has none of those.
  If a setting is common, it belongs in `extensions/`, not repeated in two plugin classes.
- **Derive when safe.** The Android `namespace` is computable from the root package plus valid Java
  identifier segments in the module's Gradle path. Existing nonconforming namespaces stay explicit
  unless the module is renamed; invalid or keyword path segments must fail instead of being rewritten.

## Step 6 — Migrate the modules

Follow `references/migration.md`. One module at a time, and run the verification in the "Verify"
section of `SKILL.md` after the first one before touching the rest — the first module is where the
classpath and DSL mistakes surface, and finding them once beats finding them four times.

A migrated module build file should contain a `plugins { }` block of aliases and a `dependencies { }`
block, plus a `kotlin { sourceSets { } }` block on a multiplatform module. If anything else
survives, either it is genuinely module-specific (a signing config, a unique buildFeature, a target
only this module has) and correctly stays, or it belongs in a convention plugin and you missed it.
Say which of the two it is rather than leaving it unexplained.

## When this is done

The build now has `build-logic`, and every module is migrated onto it. Verify before saying so — the
`Verify` section of `SKILL.md` is the gate. Adding further convention plugins from here is the
"Working on a build that already has build-logic" section of `SKILL.md`.

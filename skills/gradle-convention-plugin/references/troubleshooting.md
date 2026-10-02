# Troubleshooting

Convention-plugin failures are unusually indirect: the message names a symptom several layers away
from the cause. This table maps what you will actually see to what is actually wrong.

Before anything else, when a change "did nothing": `./gradlew --stop`. A running daemon holds the
previous plugin classpath, and it will keep reporting the previous error after you have fixed it.

---

### `Plugin [id: '<prefix>.android.application'] was not found in any of the following sources`

Almost never a catalog problem, despite reading like one. In order of likelihood:

1. `includeBuild("build-logic")` is missing, or is at the top level of `settings.gradle.kts` instead
   of inside `pluginManagement { }`. Outside `pluginManagement`, an included build contributes
   dependency substitutions but no plugin ids.
2. The id is not registered in `gradlePlugin { plugins { register(...) } }` in
   `convention/build.gradle.kts`. The class is found by registration, not by filename.
3. The registered id and the catalog entry disagree. Reading the id from the catalog in the
   `register` block (`libs.plugins.<prefix>.android.application.get().pluginId`) makes this
   impossible; a hardcoded string makes it inevitable.

### `Unresolved reference: libs` inside a convention plugin

The `LibrariesForLibs` accessor is not on the compile classpath. Both halves are required and they
only work together:

- `compileOnly(files(Class.forName("org.gradle.accessors.dm.LibrariesForLibs")...))` in
  `convention/build.gradle.kts`
- `internal val Project.libs: LibrariesForLibs get() = the<LibrariesForLibs>()` in
  `extensions/Project.kt`, imported where used

If the IDE shows the error but Gradle compiles fine, it is the known IDE limitation
([gradle/gradle#15383](https://github.com/gradle/gradle/issues/15383)) — trust the command line.
`File > Invalidate Caches` after the first successful sync usually clears it.

### `ClassCastException: com.android.build.gradle.X cannot be cast to com.android.build.gradle.X`

The same class from two classloaders — AGP is on the classpath twice.

Use `compileOnly`, not `implementation`, for `android-gradle-plugin` and `kotlin-gradle-plugin` in
`convention/build.gradle.kts`, and make sure every one of them appears in the root
`build.gradle.kts` `plugins { }` block with `apply false`. That block is what resolves each plugin
exactly once for the whole build.

### `The request for this plugin could not be satisfied ... already on the classpath with an unknown version`

A module still declares a version for a plugin the convention plugin now applies. Modules should
ask for third-party plugins by alias without a version — the root `apply false` block owns versions.
Check the module you migrated most recently.

### `Namespace not specified` / `Package "X" from AndroidManifest.xml is not a valid Java package name`

The derived namespace did not survive contact with a real module name. `packageSegment` rejects
hyphens, digits-first names and Java keywords instead of rewriting them and risking a collision.
Rename the module, or keep its existing namespace explicit.

If instead the namespace resolved to something *valid but wrong*, the module previously had a
namespace that does not follow `<root>.<path>`. See the note in `references/conventions.md` — you
are choosing between renaming the namespace (which relocates the generated `R`) and keeping an
override.

### `Unresolved reference: CommonExtension` / wrong number of type arguments

AGP 8 vs AGP 9. `CommonExtension` is generic on AGP 8 (`CommonExtension<*, *, *, *, *, *>`, with the
arity varying across 8.x minors) and non-generic on AGP 9. See the comparison table in
`references/conventions.md`. When the arity is unclear, configure `ApplicationExtension` and
`LibraryExtension` separately instead of guessing — it never breaks.

### `Extension of type 'KotlinAndroidProjectExtension' does not exist`

On AGP 8 the Kotlin Android plugin is not applied automatically. Apply
`org.jetbrains.kotlin.android` in the convention plugin before configuring the extension. On AGP 9
this extension comes from AGP's built-in Kotlin support and should already be there — if it is not,
the Android plugin was not applied first, so check the order inside the convention plugin's
`apply` method.

### `Extension of type 'KotlinMultiplatformExtension' does not exist`

The convention plugin configured the multiplatform extension before applying the multiplatform
plugin. Order inside `apply(target)` matters: apply the plugins, then configure. A convention that
spans module types, such as Koin, must not apply the multiplatform plugin itself: check with
`extensions.findByType<KotlinMultiplatformExtension>()` instead of `configure<T>`.

### `invalid source release: 24` (or any version) building `build-logic`

Also seen from `validatePlugins` as `has been compiled by a more recent version of the Java Runtime
(class file version 65.0), this version of the Java Runtime only recognizes class file versions up
to 61.0`.

`build-logic/convention/build.gradle.kts` targets a JDK newer than the daemon compiling it. First
confirm the project's Gradle daemon, toolchain and CI JDK requirement, then run Gradle with that JDK
or align the build-logic target with the documented requirement. Do not lower it merely to match an
accidentally active shell JDK. This is unrelated to the app's `jvm-target`.

Runtime flags such as the build cache, configuration cache and parallelism belong in the root
`gradle.properties`; included-build copies do not enable them for a composite invocation.

### `Cannot access '<catalog entry>': it is internal` or unresolved catalog entries in `build-logic`

`build-logic/settings.gradle.kts` is missing the `versionCatalogs { create("libs") { from(files("../gradle/libs.versions.toml")) } }`
block. An included build does not inherit the root's `dependencyResolutionManagement`.

### Configuration-cache failures mentioning `Project` at execution time

A convention plugin captured `project` inside a task action or a lazy provider. Read values from the
catalog at *configuration* time and pass plain values (or providers) forward. `configureEach { }`
rather than eager lookups also helps, which is why the multiplatform helper uses it.

### It all works locally and fails on CI

Usually one of: a different JDK (see `invalid source release` above), a fresh cache exposing a
missing repository in `build-logic/settings.gradle.kts` — it has its own `repositories` block and
inherits nothing — or `build-logic/build/` having been committed. Check `.gitignore` covers
`build-logic/**/build/`.

## Koin

### `NoDefinitionFoundException` at the first injection, after a green build

The app starts Koin with the typed `startKoin<AppModule>()`, and `AppModule` has `@Module` but not
`@Configuration`. The typed start loads only `@Configuration` modules, so it compiles to an empty
module list. Tag the root module `@Configuration`; see **Starting Koin on each platform** in
`koin.md`.

### `Cannot add extension with name 'kotlin', as there is an extension already registered with that name`

The Koin convention applies the multiplatform plugin on a module that already applied `kotlin.jvm`
or Android. The convention applies only the Koin compiler plugin and branches on the extension the
module-type convention registered.

### `Unresolved reference 'pluginId'` on `libs.plugins.<prefix>.koin`

An older id such as `<prefix>.koin-library` or `<prefix>.koin-android` is still in the catalog, so
`<prefix>.koin` became an accessor group. Delete the old ids, classes and registrations in the same
change.

### `org.koin` imports unresolved in a module that applies `<prefix>.koin`

The module applies `<prefix>.koin` before its module-type or Compose convention. `findByType` and
`hasPlugin` see only what is already applied, so the Koin branch was skipped without an error. Move
the alias after them, then confirm with
`./gradlew :<module>:dependencies --configuration <compileClasspath> | grep koin`.

### `KOIN-D002 Missing definition` at a launcher's `startKoin<T>` or `get<T>()`

The launcher depends on the shared module but has neither the Koin compiler plugin nor
`koin-annotations`, so the plugin cannot read the shared module's definitions. Apply `<prefix>.koin`
to the launcher.

If this appears only in the iOS compilation with a typed start, it is a compiler-plugin false
positive. iOS uses the untyped start; see **iOS** in `koin.md`.

### `Android Source Set Used Without an Android Target`

A convention added `androidMain` dependencies to a module without an Android target, such as a Web
launcher. Keep Android-only Koin artifacts in the Android application branch, or in `androidMain`
only for modules that declare an Android target.

# KMP target topology and application roles

Read this after the survey finds targets beyond a universal Android/iOS shape, or when a request
names a target-specific application convention. This is a migration decision guide, not a catalog
of Kotlin Multiplatform APIs.

## Inventory before choosing conventions

Build a row per module before moving any target block:

| Module | Role | Targets and names | Binary/application semantics |
|---|---|---|---|
| `<module>` | desktop/JVM app, browser app, shared library, … | `android`/`androidTarget`, JVM, JS, WasmJS, iOS, macOS, tvOS, watchOS, Linux, mingw | browser or Node, executable or library, framework/package settings |

Read the actual declarations, including custom target names; preserve those names. Module role and
target are separate axes: two KMP modules may be a browser application and a shared library and
must not inherit the same targets merely because both apply KMP.

For every block, use this ownership test:

1. Put a target in a base convention when every module of that role already owns it. A convention
   dedicated to one exact role, especially a sole consumer, may own that role's complete existing
   topology when that is its intended scope or the user asks for a plugin-only module file; preserve
   it exactly rather than broadening a generic convention.
2. If several but not all modules share it, make an additive convention such as `<prefix>.ios` or
   `<prefix>.web` and apply it beside the base.
3. If it is a module-specific one-off and no dedicated-role/plugin-only outcome was requested, leave
   it explicit in the module.

Migration must never add a target a module did not already have. Do not register the same target in
both the base and an add-on convention. Apply KMP/Kotlin and, where needed, Compose plugins before
configuring their extensions. Configure targets before accessing target source sets because moving
a target block changes when those source sets exist and what they are named.

## Preserve behavior, not just target names

Move the exact existing semantics:

- JS and WasmJS: browser versus Node, executable versus library, webpack/output/dev-server values,
  and test settings.
- JVM: compiler target, Java/Kotlin toolchain, target name, and executable/application behavior.
- Native: the full iOS, macOS, tvOS, watchOS, Linux, and mingw target list, custom names, binary
  types, framework `baseName`, and `isStatic`.
- Desktop packaging: `mainClass`, package formats, package name, and version.

Do not silently normalize ports, output names, disabled tests, package names, target names, or
dependencies. Source-set dependencies stay in the module unless they are truly a property of the
module role rather than its implementation. When a dedicated role convention owns that complete
topology, move such an intrinsic source-set dependency with the target and use
`sourceSets.apply { <sourceSet>.dependencies { ... } }` in the compiled plugin class; the concise
build-script `sourceSets { }` accessor may not compile there.

Compose Desktop packaging is application configuration layered on a JVM target; it is not another
Kotlin target. Plugin classes that configure its DSL types need the Compose Gradle plugin artifact
on build-logic's `compileOnly` classpath, and the consuming root must declare the matching plugin
alias with `apply false`, following the same classloader invariant as AGP and KGP.

## Adaptable shapes

These helpers show placement and ordering only. Replace placeholders with surveyed values and omit
any setting the module did not already have.

```kotlin
internal fun Project.configureWasmJsTarget() {
    extensions.configure<KotlinMultiplatformExtension> {
        wasmJs("<existing-target-name>") {
            browser {
                commonWebpackConfig {
                    outputFileName = "<existing-output-file>"
                }
            }
            binaries.executable()
        }
    }
}
```

If the existing target uses Node, configure `nodejs { ... }` instead of `browser { ... }`; if it is
a library, omit `binaries.executable()`. Preserve existing webpack, development-server, and test
blocks rather than copying settings from this shape.

The next example is only for a module that already applies Kotlin Multiplatform. If the surveyed
desktop module instead uses plain `org.jetbrains.kotlin.jvm`, preserve that plugin and configure its
JVM project/compiler shape (for example, `KotlinJvmProjectExtension.compilerOptions`) rather than
converting the module to KMP merely to reuse this helper.

```kotlin
class DesktopApplicationConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        apply(plugin = libs.plugins.kotlin.multiplatform.get().pluginId)
        apply(plugin = libs.plugins.compose.multiplatform.get().pluginId)
        apply(plugin = libs.plugins.compose.compiler.get().pluginId)

        extensions.configure<KotlinMultiplatformExtension> {
            jvm("<existing-target-name>") {
                compilerOptions { jvmTarget.set(<existing-jvm-target>) }
            }
        }
        extensions.getByType<ComposeExtension>().extensions.configure<DesktopExtension> {
            application {
                mainClass = "<existing-main-class>"
                nativeDistributions {
                    targetFormats(<existing-package-formats>)
                    packageName = "<existing-package-name>"
                    packageVersion = "<existing-package-version>"
                }
            }
        }
    }
}
```

Use the Compose DSL type exposed by the project's resolved plugin version; confirm it by compiling
build-logic rather than guessing an import. For plain Kotlin/JVM modules, retain their project-level
compiler/toolchain configuration; a plain JVM library convention should omit Compose and packaging
entirely.

## Verify the topology that exists

Run the normal gates in `SKILL.md`, then inspect `./gradlew tasks --all` and run the existing tasks
for the migrated targets and binaries. `assemble` may not link every native binary or build every
browser distribution. Derive task names from this build rather than assuming them.

Representative examples include `:<module>:jvmTest`, `:<module>:jsBrowserTest`,
`:<module>:jsBrowserDistribution`, `:<module>:wasmJsBrowserTest`,
`:<module>:wasmJsBrowserDistribution`, `:<module>:linkDebugFrameworkIosArm64`, and desktop packaging
tasks. Run only tasks for targets, environments, and binaries that were already present; host-only
native tasks may be unavailable on the current machine, which must be reported rather than hidden.

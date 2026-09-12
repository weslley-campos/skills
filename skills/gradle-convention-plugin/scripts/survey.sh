#!/usr/bin/env bash
# Survey a Gradle build before introducing convention plugins.
#
# Prints everything step 2 of the skill needs to decide the plugin prefix, the root package, which
# conventions to write and which AGP generation to target — in one pass, so the caller does not
# spend six file reads discovering the same thing.
#
# Usage:  bash survey.sh [project-root]     (defaults to the current directory)

set -uo pipefail

ROOT="${1:-$PWD}"
cd "$ROOT" 2>/dev/null || { echo "Not a directory: $ROOT" >&2; exit 1; }

# Both DSLs are surveyed. The Kotlin DSL is what the skill's templates assume, but a Groovy build
# still has to be read before anyone can advise converting it, so the file names are resolved once
# here and every section below reads through these variables rather than hardcoding `.kts`.
if [ -f "settings.gradle.kts" ]; then
    SETTINGS="settings.gradle.kts"
elif [ -f "settings.gradle" ]; then
    SETTINGS="settings.gradle"
else
    echo "No settings.gradle(.kts) in $ROOT — not a Gradle root. Pass the project root as an argument." >&2
    exit 1
fi

if [ -f "build.gradle" ] && [ ! -f "build.gradle.kts" ]; then
    ROOT_BUILD="build.gradle"
else
    ROOT_BUILD="build.gradle.kts"
fi

# A fixed-width bar sliced to length, rather than `seq`: a title longer than the rule makes `seq`
# count *down* on BSD and emit nothing on GNU, so the same script garbles the header on one platform
# and drops it on the other. Module paths used as titles get long enough for that to matter.
rule() {
    local title="$1"
    local pad=$(( 70 - ${#title} ))
    [ "$pad" -lt 3 ] && pad=3
    printf '\n=== %s %s\n' "$title" "$(printf "%${pad}s" '' | tr ' ' '=')"
}

# Every build file in the project, both DSLs, with the generated directories pruned rather than
# filtered afterwards — `-prune` stops find from descending them at all, and a repo that has been
# built holds tens of thousands of files under build/ and .gradle/ per module.
find_build_files() {
    find . \( -name build -o -name .gradle -o -name .git -o -name .idea \) -prune -o \
        \( -name "build.gradle.kts" -o -name "build.gradle" \) -print 2>/dev/null | sort
}

# Print a file, capped, so one enormous build file cannot bury the rest of the report.
dump() {
    local f="$1" cap="${2:-120}"
    [ -f "$f" ] || { echo "(absent)"; return; }
    local n; n=$(wc -l < "$f" | tr -d ' ')
    head -n "$cap" "$f"
    [ "$n" -gt "$cap" ] && echo "... [$((n - cap)) more lines — read $f directly]"
    return 0
}

rule "TOOLCHAIN"
if [ -f gradle/wrapper/gradle-wrapper.properties ]; then
    grep distributionUrl gradle/wrapper/gradle-wrapper.properties | sed 's/.*gradle-/Gradle wrapper: /; s/-bin.zip//; s/-all.zip//'
else
    echo "Gradle wrapper: (no gradle/wrapper/gradle-wrapper.properties)"
fi
echo "Shell JDK (diagnostic only; use the project/CI/daemon requirement for build-logic): $(java -version 2>&1 | head -1)"
[ -n "${JAVA_HOME:-}" ] && echo "JAVA_HOME: $JAVA_HOME"

rule "EXISTING BUILD LOGIC"
if [ -d build-logic ]; then
    echo "build-logic/ EXISTS — this is an add-a-convention-plugin task, not a bootstrap."
    find build-logic -name build -prune -o \
        \( -name "*.kt" -o -name "*.kts" -o -name "gradle.properties" \) -print \
        | sort | sed 's/^/  /'
else
    echo "build-logic/: absent"
fi
if [ -d buildSrc ]; then
    echo "buildSrc/ EXISTS — an included build replaces it; ask before removing anything."
    find buildSrc -name build -prune -o \( -name "*.kt" -o -name "*.kts" \) -print | sort | sed 's/^/  /'
else
    echo "buildSrc/: absent"
fi

rule "DSL AND CATALOG"
ls settings.gradle settings.gradle.kts build.gradle build.gradle.kts 2>/dev/null | sed 's/^/  /'
# Module build files count too, not just the root: a build converts one file at a time, so the
# mixed state is the common one and it is exactly the state worth naming.
groovy_modules=$(find_build_files | grep -E '\.gradle$')
if [ -n "$groovy_modules" ] || [ "$SETTINGS" = "settings.gradle" ]; then
    echo "  WARNING: Groovy DSL present. The skill's templates assume the Kotlin DSL (.kts)."
    echo "           Offer to convert these before going further — references/init.md, step 1:"
    [ "$SETTINGS" = "settings.gradle" ] && echo "             ./$SETTINGS"
    [ -n "$groovy_modules" ] && echo "$groovy_modules" | sed 's/^/             /'
fi
if [ -f gradle/libs.versions.toml ]; then
    echo "  gradle/libs.versions.toml: present"
    # The hump can fall anywhere in the alias, not just in the first word: `compose-uiToolingPreview`
    # is the far more common half-converted shape than a plain `composeUiToolingPreview`.
    if grep -qE '^[[:space:]]*[A-Za-z0-9_-]*[a-z0-9][A-Z][A-Za-z0-9]*[[:space:]]*=' gradle/libs.versions.toml; then
        echo "  NOTE: camelCase aliases found — see references/migration.md, 'Catalog alias renaming'."
    fi
else
    echo "  gradle/libs.versions.toml: ABSENT. The design leans on a catalog; offer to create one first."
fi

rule "MODULES"
echo "  rootProject.name (the plugin prefix derives from this):"
grep -hE 'rootProject\.name' "$SETTINGS" 2>/dev/null | sed 's/^/    /'
echo "  --- declared in settings ---"
# Match the include line first, then take every quoted string on it. A single pattern over the whole
# call misses `include(":a", ":b")` entirely, and misses Groovy's unparenthesised `include ':a'`.
grep -hE '^[[:space:]]*include(Build)?([[:space:]]|\()' "$SETTINGS" 2>/dev/null \
    | grep -oE "[\"'][^\"']+[\"']" | tr -d "\"'" | sed 's/^/    /'
echo "  --- build files ---"
find_build_files \
    | grep -vE "^\./(build-logic|buildSrc)/" \
    | grep -vE "^\./build\.gradle(\.kts)?$" \
    | sed 's/^/  /'

rule "NAMESPACES AND IDS (what the root package is derived from)"
# Manifests are not dumped later, and this aggregates across every module at once, so it earns its
# place where a re-grep of the catalog would not.
ns_files=$( { find_build_files | grep -vE "^\./(build-logic|buildSrc)/"; \
    find . \( -name build -o -name .gradle -o -name .git \) -prune -o \
        -name AndroidManifest.xml -print 2>/dev/null; } )
found=""
if [ -n "$ns_files" ]; then
    found=$(printf '%s\n' "$ns_files" | tr '\n' '\0' \
        | xargs -0 grep -hE '(namespace|applicationId|package)[[:space:]]*=' 2>/dev/null | sort -u)
fi
if [ -n "$found" ]; then
    echo "$found" | sed 's/^/  /'
else
    echo "  (none declared — either already derived by a convention plugin, or a non-Android build)"
fi

rule "$SETTINGS"
dump "$SETTINGS" 80

rule "$ROOT_BUILD (root)"
dump "$ROOT_BUILD" 80

rule "gradle/libs.versions.toml"
dump gradle/libs.versions.toml 200

# `read` rather than `for f in $(...)`: word splitting breaks every path containing a space, and
# prints "(absent)" for files that are plainly there.
find_build_files \
    | grep -vE "^\./(build-logic|buildSrc)/" \
    | grep -vE "^\./build\.gradle(\.kts)?$" \
    | while IFS= read -r f; do
        rule "$f"
        dump "$f" 120
    done

rule "END OF SURVEY"
echo "Next: references/init.md step 2 — derive the plugin prefix, root package, module types,"
echo "Android application count/identity policy, and AGP generation; state them before writing files."

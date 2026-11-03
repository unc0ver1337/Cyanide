#!/usr/bin/env bash
# Build an unsigned arm64e Release IPA without opening Xcode.
#
# Usage:
#   ./build.sh
#
# Result:
#   build/Cyanide-<version>.ipa
#   build/Cyanide.ipa -> Cyanide-<version>.ipa
#
# Optional overrides:
#   SDK=iphoneos26.2 ARCHS=arm64e IPHONEOS_DEPLOYMENT_TARGET=16.0 ./build.sh
#   SCHEME=CyanideVPhone ./build.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

# WIP branch: exercise the local calling convention before the iOS build.
if [ "${CI:-}" = "true" ]; then
    clang -target arm64-apple-ios15.0 -fobjc-arc -fblocks -std=gnu11 \
        -Wall -Wextra -Werror -nostdinc -I "$ROOT/experiments/chams/stubs" \
        -fsyntax-only "$ROOT/experiments/chams/check_main_syntax.m" \
        "$ROOT/experiments/chams/check_symbols_syntax.m" \
        "$ROOT/experiments/chams/check_metadata_syntax.m"
    node --check "$ROOT/experiments/chams/menu.js"
    (cd "$ROOT" && node experiments/chams/test_menu.cjs)
    clang -Wall -Wextra -Werror -fobjc-arc -framework Foundation \
        "$ROOT/experiments/chams/invocation_probe.m" -o "$RUNNER_TEMP/chams-invocation-probe"
    "$RUNNER_TEMP/chams-invocation-probe"
    clang -std=c11 -Wall -Wextra -Werror \
        "$ROOT/experiments/chams/test_material_filter.c" \
        "$ROOT/Cyanide/tweaks/experimental/chams_material_filter.c" \
        -o "$RUNNER_TEMP/chams-material-filter-test"
    "$RUNNER_TEMP/chams-material-filter-test"
    clang -std=c11 -Wall -Wextra -Werror \
        "$ROOT/experiments/chams/test_materials.c" \
        "$ROOT/Cyanide/tweaks/experimental/chams_material_filter.c" \
        "$ROOT/Cyanide/tweaks/experimental/chams_materials.c" \
        -o "$RUNNER_TEMP/chams-materials-test"
    "$RUNNER_TEMP/chams-materials-test"
fi

export SCHEME="${SCHEME:-Cyanide}"
if [ "$SCHEME" = "CyanideVPhone" ]; then
    export CONFIG="${CONFIG:-VPhone Debug}"
else
    export CONFIG="${CONFIG:-Release}"
fi
export SDK="${SDK:-iphoneos}"
export ARCHS="${ARCHS:-arm64e}"
export IPHONEOS_DEPLOYMENT_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:-16.0}"

# scripts/build.sh owns the one missing-resource check so direct CI builds and
# this Release wrapper cannot recurse or generate twice. An existing resource
# (including release.sh's pending entry or a local custom file) is preserved.
exec "$ROOT/scripts/build.sh"

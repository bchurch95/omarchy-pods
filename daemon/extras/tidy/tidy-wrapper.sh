#!/usr/bin/env bash
# clang-tidy wrapper that strips GCC-only flags from
# compile_commands.json before invoking clang-tidy.
#
# Background: cmake-generated compile_commands.json contains
# `-mno-direct-extern-access` (introduced by Qt's CMake on GCC
# builds) and similar GCC-only flags. clang-tidy refuses to parse
# them — `error: unknown argument: '-mno-direct-extern-access'`.
# SMOKE.sh already strips these for its own tidy stage (see line
# ~144); this script gives a developer the same cleaned build for
# ad-hoc invocations outside the gate.
#
# Usage:
#   linux/extras/tidy/tidy-wrapper.sh [clang-tidy args...]
#
# Example:
#   # Run tidy on the whole tree:
#   linux/extras/tidy/tidy-wrapper.sh -p . linux/**/*.cpp linux/**/*.h
#
#   # Run a single check:
#   linux/extras/tidy/tidy-wrapper.sh -checks=bugprone-unchecked-optional-access \
#       linux/tests/tst_ipcverb.cpp

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BUILD="${ROOT}/linux/build"

if ! command -v clang-tidy > /dev/null 2>&1; then
    echo "clang-tidy not installed (pacman -S clang)" >&2
    exit 2
fi

if [[ ! -f "${BUILD}/compile_commands.json" ]]; then
    echo "compile_commands.json missing — run cmake configure first:" >&2
    echo "  cmake -S linux -B linux/build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON" >&2
    exit 2
fi

# Drop GCC-only flags into a tmp build dir so clang-tidy reads a
# clean db without mutating the original.
TIDY_BUILD="$(mktemp -d -t openpods-tidy-XXXXXX)"
trap 'rm -rf "${TIDY_BUILD}"' EXIT

sed \
    -e 's/-mno-direct-extern-access//g' \
    -e 's/-fcf-protection[^"]*//g' \
    "${BUILD}/compile_commands.json" > "${TIDY_BUILD}/compile_commands.json"

# Caller forwards any args after `-p <dir>`; default is the whole
# linux/ tree if no positional args given.
if (( $# == 0 )); then
    clang-tidy -p "${TIDY_BUILD}" "${ROOT}"/linux/*.cpp "${ROOT}"/linux/*.h
else
    clang-tidy -p "${TIDY_BUILD}" "$@"
fi

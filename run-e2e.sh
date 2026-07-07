#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
GENERATED_ROOT="${ROOT}/.generated"
SHARED_COMMANDS="${SHARED_COMMANDS:-${GENERATED_ROOT}/shared-commands.cj}"
LEFT_OUTPUT="${LEFT_OUTPUT:-${GENERATED_ROOT}/restest-left.out}"
RIGHT_OUTPUT="${RIGHT_OUTPUT:-${GENERATED_ROOT}/restest-right.out}"
LEFT_STRINGS="${LEFT_STRINGS:-${GENERATED_ROOT}/restest-left.strings}"
RIGHT_STRINGS="${RIGHT_STRINGS:-${GENERATED_ROOT}/restest-right.strings}"
RESTEST_LEFT_PROJECT="${RESTEST_LEFT_PROJECT:-../test-test}"
RESTEST_RIGHT_PROJECT="${RESTEST_RIGHT_PROJECT:-../test-test2}"
RESTEST_SEED="${RESTEST_SEED:-0}"

export LD_LIBRARY_PATH="${ROOT}/restest_common/target/release/restest_common:/home/james/cangjie-sdk-linux-x64-28Feb2026-EH-beta/runtime/lib/linux_x86_64_cjnative:/home/james/cangjie-sdk-linux-x64-28Feb2026-EH-beta/lib/linux_x86_64_cjnative:${LD_LIBRARY_PATH:-}"

run_runner() {
    local runner_dir="$1"
    local output_path="$2"

    (
        cd "${runner_dir}"
        RESTEST_COMMANDS="${SHARED_COMMANDS}" RESTEST_SEED="${RESTEST_SEED}" \
            cjpm run > "${output_path}"
    )
}

(
    cd "${ROOT}/apidiff"
    RESTEST_LEFT_PROJECT="${RESTEST_LEFT_PROJECT}" RESTEST_RIGHT_PROJECT="${RESTEST_RIGHT_PROJECT}" \
        cjpm run -- generate-runners
)

run_runner "${GENERATED_ROOT}/runner-left" "${LEFT_OUTPUT}"
run_runner "${GENERATED_ROOT}/runner-right" "${RIGHT_OUTPUT}"

strings "${LEFT_OUTPUT}" > "${LEFT_STRINGS}"
strings "${RIGHT_OUTPUT}" > "${RIGHT_STRINGS}"

diff -u "${LEFT_STRINGS}" "${RIGHT_STRINGS}"

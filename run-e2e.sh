#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SHARED_COMMANDS="${SHARED_COMMANDS:-/tmp/shared-commands.cj}"
LEFT_OUTPUT="${LEFT_OUTPUT:-/tmp/restest-left.out}"
RIGHT_OUTPUT="${RIGHT_OUTPUT:-/tmp/restest-right.out}"
RESTEST_LEFT_PROJECT="${RESTEST_LEFT_PROJECT:-../test-test}"
RESTEST_RIGHT_PROJECT="${RESTEST_RIGHT_PROJECT:-../test-test2}"
RESTEST_SEED="${RESTEST_SEED:-0}"
RUNNER_MANIFEST="${ROOT}/runner/cjpm.toml"
RUNNER_MANIFEST_BACKUP="${RUNNER_MANIFEST}.run-e2e.bak"

#export LD_LIBRARY_PATH="${ROOT}/restest_common/target/release/restest_common:/home/james/cangjie-sdk-linux-x64-28Feb2026-EH-beta/runtime/lib/linux_x86_64_cjnative:/home/james/cangjie-sdk-linux-x64-28Feb2026-EH-beta/lib/linux_x86_64_cjnative:${LD_LIBRARY_PATH:-}"

cp "${RUNNER_MANIFEST}" "${RUNNER_MANIFEST_BACKUP}"
trap 'mv "${RUNNER_MANIFEST_BACKUP}" "${RUNNER_MANIFEST}"' EXIT

run_runner() {
    local dependency_path="$1"
    local output_path="$2"

    perl -0pi -e 's|test_test = \{ path = ".*?", output-type = "static" \}|test_test = { path = "'"${dependency_path}"'", output-type = "static" }|' "${RUNNER_MANIFEST}"

    (
        cd "${ROOT}/runner"
        RESTEST_COMMANDS="${SHARED_COMMANDS}" RESTEST_SEED="${RESTEST_SEED}" \
            cjpm run > "${output_path}"
    )
}

(
    cd "${ROOT}/apidiff"
    RESTEST_LEFT_PROJECT="${RESTEST_LEFT_PROJECT}" RESTEST_RIGHT_PROJECT="${RESTEST_RIGHT_PROJECT}" \
        cjpm run > "${SHARED_COMMANDS}"
)

run_runner "${RESTEST_LEFT_PROJECT}" "${LEFT_OUTPUT}"
run_runner "${RESTEST_RIGHT_PROJECT}" "${RIGHT_OUTPUT}"

diff -u <(strings "${LEFT_OUTPUT}") <(strings "${RIGHT_OUTPUT}")

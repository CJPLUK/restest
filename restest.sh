#!/usr/bin/env bash
set -euo pipefail

usage() {
    printf 'Usage: %s [--seed N|--seed=N] [LEFT_PROJECT RIGHT_PROJECT]\n' "$0" >&2
}

CLI_SEED=""
CLI_LEFT_PROJECT=""
CLI_RIGHT_PROJECT=""
POSITIONAL_COUNT=0

while (($# > 0)); do
    case "$1" in
        --seed)
            if (($# < 2)); then
                usage
                exit 1
            fi
            CLI_SEED="$2"
            shift 2
            ;;
        --seed=*)
            CLI_SEED="${1#--seed=}"
            shift
            ;;
        --*)
            usage
            exit 1
            ;;
        *)
            POSITIONAL_COUNT=$((POSITIONAL_COUNT + 1))
            case "$POSITIONAL_COUNT" in
                1) CLI_LEFT_PROJECT="$1" ;;
                2) CLI_RIGHT_PROJECT="$1" ;;
                *)
                    usage
                    exit 1
                    ;;
            esac
            shift
            ;;
    esac
done

ROOT="$(cd "$(dirname "$0")" && pwd)"
GENERATED_ROOT="${ROOT}/.generated"
SHARED_COMMANDS="${SHARED_COMMANDS:-${GENERATED_ROOT}/shared-commands.cj}"
LEFT_OUTPUT="${LEFT_OUTPUT:-${GENERATED_ROOT}/restest-left.out}"
RIGHT_OUTPUT="${RIGHT_OUTPUT:-${GENERATED_ROOT}/restest-right.out}"
LEFT_STRINGS="${LEFT_STRINGS:-${GENERATED_ROOT}/restest-left.strings}"
RIGHT_STRINGS="${RIGHT_STRINGS:-${GENERATED_ROOT}/restest-right.strings}"
RESTEST_LEFT_PROJECT="${CLI_LEFT_PROJECT:-${RESTEST_LEFT_PROJECT:-./test-test}}"
RESTEST_RIGHT_PROJECT="${CLI_RIGHT_PROJECT:-${RESTEST_RIGHT_PROJECT:-./test-test2}}"
RESTEST_SEED="${CLI_SEED:-${RESTEST_SEED:-0}}"

export LD_LIBRARY_PATH="${ROOT}/restest_common/target/release/restest_common:/home/james/cangjie-sdk-linux-x64-28Feb2026-EH-beta/lib/linux_x86_64_cjnative:$HOME/.cjpm/libs/restest_apidiff:${LD_LIBRARY_PATH:-}"
export RESTEST_ROOT="${ROOT}"

run_runner() {
    local runner_dir="$1"
    local output_path="$2"

    (
        cd "${runner_dir}"
        RESTEST_COMMANDS="${SHARED_COMMANDS}" RESTEST_SEED="${RESTEST_SEED}" \
            cjpm run > "${output_path}"
    )
}

pushd apidiff
cjpm install
popd
RESTEST_LEFT_PROJECT="${RESTEST_LEFT_PROJECT}" RESTEST_RIGHT_PROJECT="${RESTEST_RIGHT_PROJECT}" \
    restest_apidiff generate-runners

run_runner "${GENERATED_ROOT}/runner-left" "${LEFT_OUTPUT}"
run_runner "${GENERATED_ROOT}/runner-right" "${RIGHT_OUTPUT}"

strings "${LEFT_OUTPUT}" > "${LEFT_STRINGS}"
strings "${RIGHT_OUTPUT}" > "${RIGHT_STRINGS}"

diff -u "${LEFT_STRINGS}" "${RIGHT_STRINGS}"

#!/usr/bin/env zsh
set -euo pipefail

runner="${0:A:h}/integration-tests-runner.zsh"
fixture="$(mktemp -d)"
trap 'rm -rf -- "$fixture"' EXIT

function check_case() {
    local name="$1" first_exit="$2" last_exit="$3" expected_exit="$4"
    local case_home="$fixture/$name"
    local source_dir="$case_home/.local/share/chezmoi"
    local actual_exit=0 output
    mkdir -p "$source_dir/tests/integration"
    cat > "$source_dir/install.sh" <<'SH'
install_main() { :; }
log() { printf '%s\n' "$*"; }
SH
    printf 'exit %s\n' "$first_exit" > "$source_dir/tests/integration/01-first.sh"
    printf 'exit 0\n' > "$source_dir/tests/integration/02-middle.sh"
    printf 'exit %s\n' "$last_exit" > "$source_dir/tests/integration/03-last.sh"

    output="$(HOME="$case_home" zsh "$runner" --local)" || actual_exit="$?"
    if [[ "$actual_exit" != "$expected_exit" ]]; then
        printf '%s: expected exit %s, got %s\n%s\n' "$name" "$expected_exit" "$actual_exit" "$output" >&2
        return 1
    fi

    local test_name expected_result
    for test_name in 01-first 02-middle 03-last; do
        expected_result=SUCCESS
        if [[ "$test_name" == 01-first && "$first_exit" != 0 ||
              "$test_name" == 03-last && "$last_exit" != 0 ]]; then
            expected_result=FAILURE
        fi
        if ! printf '%s\n' "$output" | grep -Eq "^$expected_result +$test_name +\\("; then
            printf '%s: missing %s result for %s\n%s\n' "$name" "$expected_result" "$test_name" "$output" >&2
            return 1
        fi
    done
    printf 'PASS %s\n' "$name"
}

check_case all-pass 0 0 0
check_case first-fails 1 0 1
check_case last-fails 0 1 1
check_case both-fail 1 2 1

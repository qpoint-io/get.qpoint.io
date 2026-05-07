#!/usr/bin/env sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCRIPT="$ROOT/qcontrol/install"

fail() {
    printf 'not ok - %s\n' "$*" >&2
    return 1
}

assert_contains() {
    haystack=$1
    needle=$2

    case "$haystack" in
    *"$needle"*) ;;
    *) fail "expected output to contain: $needle" ;;
    esac
}

assert_not_exists() {
    path=$1
    message=$2

    [ ! -e "$path" ] || fail "$message"
}

make_fake_tools() {
    fakebin=$1

    cat >"$fakebin/curl" <<'SH'
#!/usr/bin/env sh

set -eu

: "${QCONTROL_TEST_MARKER:?}"
touch "$QCONTROL_TEST_MARKER/curl-called"
printf '%s\n' "$*" >"$QCONTROL_TEST_MARKER/curl-args"
printf 'fake archive'
SH
    chmod +x "$fakebin/curl"

    cat >"$fakebin/tar" <<'SH'
#!/usr/bin/env sh

set -eu

out=
while [ "$#" -gt 0 ]; do
    case "$1" in
    -C)
        shift
        out=$1
        ;;
    esac
    shift || true
done

if [ -z "$out" ]; then
    printf 'missing output directory\n' >&2
    exit 1
fi

cat >"$out/qcontrol" <<'QCONTROL'
#!/usr/bin/env sh

case "${1:-}" in
--version)
    printf 'qcontrol test version\n'
    ;;
--help)
    printf 'qcontrol help\n'
    ;;
*)
    printf 'qcontrol args: %s\n' "$*"
    ;;
esac
QCONTROL
chmod +x "$out/qcontrol"
SH
    chmod +x "$fakebin/tar"

    cat >"$fakebin/mv" <<'SH'
#!/usr/bin/env sh

set -eu

if [ "${2:-}" = "/usr/local/bin/qcontrol" ]; then
    printf 'refusing to write to real /usr/local/bin/qcontrol in tests\n' >&2
    exit 1
fi

/bin/mv "$@"
SH
    chmod +x "$fakebin/mv"
}

setup_test() {
    TEST_SANDBOX=$(mktemp -d)
    trap 'rm -rf "$TEST_SANDBOX"' EXIT INT

    TEST_HOME="$TEST_SANDBOX/home"
    TEST_FAKEBIN="$TEST_SANDBOX/bin"
    TEST_SYSTEM_BIN="$TEST_SANDBOX/system-bin"
    TEST_WORKDIR="$TEST_SANDBOX/work"
    TEST_OUTPUT="$TEST_SANDBOX/output"

    mkdir -p "$TEST_HOME" "$TEST_FAKEBIN" "$TEST_WORKDIR"
    make_fake_tools "$TEST_FAKEBIN"
}

teardown_test() {
    rm -rf "$TEST_SANDBOX"
}

run_install() {
    (
        cd "$TEST_WORKDIR"
        QCONTROL_TEST_MARKER="$TEST_SANDBOX" QCONTROL_TEST_SYSTEM_BIN="$TEST_SYSTEM_BIN" HOME="$TEST_HOME" PATH="$TEST_FAKEBIN:$PATH" sh "$SCRIPT" "$@" >"$TEST_OUTPUT" 2>&1
    )
}

test_default_scope_installs_to_user_bin() {
    setup_test
    mkdir -p "$TEST_HOME/.local/bin"

    if ! run_install; then
        cat "$TEST_OUTPUT" >&2
        fail 'install command failed'
    fi

    output=$(cat "$TEST_OUTPUT")

    [ -x "$TEST_HOME/.local/bin/qcontrol" ] || fail 'expected qcontrol in user bin'
    [ ! -e "$TEST_WORKDIR/qcontrol" ] || fail 'expected no current-directory fallback'
    assert_contains "$output" 'successfully installed qcontrol test version at'
    assert_contains "$output" "$TEST_HOME/.local/bin/qcontrol"
    assert_contains "$output" 'qcontrol help'

    teardown_test
}

test_explicit_user_scope_installs_to_user_bin() {
    setup_test
    mkdir -p "$TEST_HOME/.local/bin"

    if ! run_install user; then
        cat "$TEST_OUTPUT" >&2
        fail 'install command failed'
    fi

    output=$(cat "$TEST_OUTPUT")

    [ -x "$TEST_HOME/.local/bin/qcontrol" ] || fail 'expected qcontrol in user bin'
    [ ! -e "$TEST_WORKDIR/qcontrol" ] || fail 'expected no current-directory fallback'
    assert_contains "$output" 'successfully installed qcontrol test version at'
    assert_contains "$output" "$TEST_HOME/.local/bin/qcontrol"
    assert_contains "$output" 'qcontrol help'

    teardown_test
}

test_missing_user_bin_fails_before_download() {
    setup_test

    if run_install; then
        fail 'expected install command to fail'
    fi

    output=$(cat "$TEST_OUTPUT")

    assert_not_exists "$TEST_SANDBOX/curl-called" 'expected no download attempt'
    assert_not_exists "$TEST_WORKDIR/qcontrol" 'expected no current-directory fallback'
    assert_contains "$output" "$TEST_HOME/.local/bin"
    assert_contains "$output" 'curl -s https://get.qpoint.io/qcontrol/install | sudo sh -s -- system'

    teardown_test
}

test_unwritable_user_bin_fails_before_download() {
    setup_test
    mkdir -p "$TEST_HOME/.local/bin"
    chmod 555 "$TEST_HOME/.local/bin"

    if run_install; then
        chmod 755 "$TEST_HOME/.local/bin"
        fail 'expected install command to fail'
    fi

    chmod 755 "$TEST_HOME/.local/bin"
    output=$(cat "$TEST_OUTPUT")

    assert_not_exists "$TEST_SANDBOX/curl-called" 'expected no download attempt'
    assert_not_exists "$TEST_WORKDIR/qcontrol" 'expected no current-directory fallback'
    assert_contains "$output" "$TEST_HOME/.local/bin"
    assert_contains "$output" 'is not writable'
    assert_contains "$output" 'curl -s https://get.qpoint.io/qcontrol/install | sudo sh -s -- system'

    teardown_test
}

test_system_scope_installs_to_system_bin() {
    setup_test
    mkdir -p "$TEST_SYSTEM_BIN"

    if ! run_install system; then
        cat "$TEST_OUTPUT" >&2
        fail 'install command failed'
    fi

    output=$(cat "$TEST_OUTPUT")

    [ -x "$TEST_SYSTEM_BIN/qcontrol" ] || fail 'expected qcontrol in system bin'
    assert_not_exists "$TEST_WORKDIR/qcontrol" 'expected no current-directory fallback'
    assert_contains "$output" 'successfully installed qcontrol test version at'
    assert_contains "$output" "$TEST_SYSTEM_BIN/qcontrol"
    assert_contains "$output" 'qcontrol help'

    teardown_test
}

test_missing_system_bin_fails_before_download() {
    setup_test

    if run_install system; then
        fail 'expected install command to fail'
    fi

    output=$(cat "$TEST_OUTPUT")

    assert_not_exists "$TEST_SANDBOX/curl-called" 'expected no download attempt'
    assert_not_exists "$TEST_WORKDIR/qcontrol" 'expected no current-directory fallback'
    assert_contains "$output" "$TEST_SYSTEM_BIN"
    assert_contains "$output" 'curl -s https://get.qpoint.io/qcontrol/install | sudo sh -s -- system'

    teardown_test
}

test_invalid_scope_fails_before_download() {
    setup_test
    mkdir -p "$TEST_HOME/.local/bin" "$TEST_SYSTEM_BIN"

    if run_install banana; then
        fail 'expected install command to fail'
    fi

    output=$(cat "$TEST_OUTPUT")

    assert_not_exists "$TEST_SANDBOX/curl-called" 'expected no download attempt'
    assert_not_exists "$TEST_HOME/.local/bin/qcontrol" 'expected no user install'
    assert_not_exists "$TEST_SYSTEM_BIN/qcontrol" 'expected no system install'
    assert_contains "$output" 'accepted scopes: user, system'

    teardown_test
}

test_extra_argument_fails_before_download() {
    setup_test
    mkdir -p "$TEST_HOME/.local/bin" "$TEST_SYSTEM_BIN"

    if run_install user extra; then
        fail 'expected install command to fail'
    fi

    output=$(cat "$TEST_OUTPUT")

    assert_not_exists "$TEST_SANDBOX/curl-called" 'expected no download attempt'
    assert_not_exists "$TEST_HOME/.local/bin/qcontrol" 'expected no user install'
    assert_not_exists "$TEST_SYSTEM_BIN/qcontrol" 'expected no system install'
    assert_contains "$output" 'accepted scopes: user, system'

    teardown_test
}

test_version_env_is_used_in_download_url() {
    setup_test
    mkdir -p "$TEST_HOME/.local/bin"

    VERSION=v0.9.10
    export VERSION
    if ! run_install; then
        unset VERSION
        cat "$TEST_OUTPUT" >&2
        fail 'install command failed'
    fi
    unset VERSION

    curl_args=$(cat "$TEST_SANDBOX/curl-args")

    assert_contains "$curl_args" 'qcontrol-v0.9.10-'

    teardown_test
}

test_default_scope_installs_to_user_bin
printf 'ok - default scope installs to user bin\n'
test_explicit_user_scope_installs_to_user_bin
printf 'ok - explicit user scope installs to user bin\n'
test_missing_user_bin_fails_before_download
printf 'ok - missing user bin fails before download\n'
test_unwritable_user_bin_fails_before_download
printf 'ok - unwritable user bin fails before download\n'
test_system_scope_installs_to_system_bin
printf 'ok - system scope installs to system bin\n'
test_missing_system_bin_fails_before_download
printf 'ok - missing system bin fails before download\n'
test_invalid_scope_fails_before_download
printf 'ok - invalid scope fails before download\n'
test_extra_argument_fails_before_download
printf 'ok - extra argument fails before download\n'
test_version_env_is_used_in_download_url
printf 'ok - version env is used in download url\n'

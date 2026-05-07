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

make_fake_tools() {
    fakebin=$1

    cat >"$fakebin/curl" <<'SH'
#!/usr/bin/env sh

set -eu

: "${QCONTROL_TEST_MARKER:?}"
touch "$QCONTROL_TEST_MARKER/curl-called"
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
}

test_default_scope_installs_to_user_bin() {
    sandbox=$(mktemp -d)
    trap 'rm -rf "$sandbox"' EXIT INT

    home="$sandbox/home"
    fakebin="$sandbox/bin"
    workdir="$sandbox/work"
    output_file="$sandbox/output"

    mkdir -p "$home/.local/bin" "$fakebin" "$workdir"
    make_fake_tools "$fakebin"

    if ! (
        cd "$workdir"
        QCONTROL_TEST_MARKER="$sandbox" HOME="$home" PATH="$fakebin:$PATH" sh "$SCRIPT" >"$output_file" 2>&1
    ); then
        cat "$output_file" >&2
        fail 'install command failed'
    fi

    output=$(cat "$output_file")

    [ -x "$home/.local/bin/qcontrol" ] || fail 'expected qcontrol in user bin'
    [ ! -e "$workdir/qcontrol" ] || fail 'expected no current-directory fallback'
    assert_contains "$output" 'successfully installed qcontrol test version at'
    assert_contains "$output" "$home/.local/bin/qcontrol"
    assert_contains "$output" 'qcontrol help'
}

test_explicit_user_scope_installs_to_user_bin() {
    sandbox=$(mktemp -d)
    trap 'rm -rf "$sandbox"' EXIT INT

    home="$sandbox/home"
    fakebin="$sandbox/bin"
    workdir="$sandbox/work"
    output_file="$sandbox/output"

    mkdir -p "$home/.local/bin" "$fakebin" "$workdir"
    make_fake_tools "$fakebin"

    if ! (
        cd "$workdir"
        QCONTROL_TEST_MARKER="$sandbox" HOME="$home" PATH="$fakebin:$PATH" sh "$SCRIPT" user >"$output_file" 2>&1
    ); then
        cat "$output_file" >&2
        fail 'install command failed'
    fi

    output=$(cat "$output_file")

    [ -x "$home/.local/bin/qcontrol" ] || fail 'expected qcontrol in user bin'
    [ ! -e "$workdir/qcontrol" ] || fail 'expected no current-directory fallback'
    assert_contains "$output" 'successfully installed qcontrol test version at'
    assert_contains "$output" "$home/.local/bin/qcontrol"
    assert_contains "$output" 'qcontrol help'
}

test_default_scope_installs_to_user_bin
printf 'ok - default scope installs to user bin\n'
test_explicit_user_scope_installs_to_user_bin
printf 'ok - explicit user scope installs to user bin\n'

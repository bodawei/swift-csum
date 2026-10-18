#!/usr/bin/env bash

set -uo pipefail

cd "$(dirname "$0")/.."

BIN="${CSUM_CLI:-.build/debug/csum-cli}"
FAILURES=0

fail() {
    echo "FAIL: $*" >&2
    FAILURES=$((FAILURES + 1))
}

pass() {
    echo "ok: $*"
}

expect_contains() {
    case "$1" in
        *"$2"*) pass "$3" ;;
        *) fail "$3 (missing: $2)" ;;
    esac
}

expect_lacks() {
    case "$1" in
        *"$2"*) fail "$3 (unexpected: $2)" ;;
        *) pass "$3" ;;
    esac
}

expect_exit() {
    local expected="$1" what="$2"
    shift 2
    "$@" >/dev/null 2>&1
    local actual=$?

    if [ "$actual" -eq "$expected" ]; then
        pass "$what"
    else
        fail "$what (exit $actual, wanted $expected)"
    fi
}

digest_of() {
    printf '%s' "$1" | shasum -a "$2" | cut -d' ' -f1
}

echo "building"
swift build >/dev/null || exit 1

if [ ! -x "$BIN" ]; then
    echo "no csum-cli at $BIN" >&2
    exit 1
fi

WORK="$(mktemp -d)"
CANONICAL="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/a/sub" "$WORK/b/sub"
printf 'alpha' > "$WORK/a/a.txt"
printf 'beta' > "$WORK/a/sub/b.txt"
printf 'alpha' > "$WORK/b/a.txt"
printf 'BETA' > "$WORK/b/sub/b.txt"
printf 'new' > "$WORK/b/c.txt"

echo "check"
expect_contains "$("$BIN" check "$WORK/a/a.txt")" "$(digest_of alpha 256)," "check hashes a file with sha256"
expect_contains "$("$BIN" check -a sha1 "$WORK/a/a.txt")" "$(digest_of alpha 1)," "check -a sha1 agrees with shasum"
expect_contains "$("$BIN" check -a md5 "$WORK/a/a.txt")" "$(printf '%s' alpha | md5)," "check -a md5 agrees with md5"

"$BIN" check "$WORK/a" > "$WORK/a.csum.csv"
expect_contains "$(cat "$WORK/a.csum.csv")" "# csum-root" "check writes the root comment"
expect_contains "$(cat "$WORK/a.csum.csv")" "# csum-algorithm sha256" "check writes the algorithm"
expect_contains "$(cat "$WORK/a.csum.csv")" "$(digest_of beta 256)" "check walks a folder"

"$BIN" check -a sha1 "$WORK/a" > "$WORK/a-sha1.csum.csv"
"$BIN" check "$WORK/a" > "$WORK/a-sha256.csum.csv"

echo "compare"
expect_contains "$("$BIN" compare "$WORK/a" "$WORK/b")" "# Added" "compare finds an added file"
expect_contains "$("$BIN" compare "$WORK/a" "$WORK/b")" "# Changed" "compare finds a changed file"
expect_lacks "$("$BIN" compare "$WORK/a" "$WORK/b")" "# Unchanged" "compare omits unchanged by default"
expect_contains "$("$BIN" compare -u "$WORK/a" "$WORK/b")" "# Unchanged" "compare -u includes unchanged"
expect_lacks "$("$BIN" compare -c "$WORK/a" "$WORK/b")" "# Added" "compare -c selects only changed"
expect_contains "$("$BIN" compare -c "$WORK/a" "$WORK/b")" "Old Path" "changed entries carry both sides"

expect_contains "$("$BIN" compare -u "$WORK/a.csum.csv" "$WORK/a")" "# Unchanged" "a saved file matches the folder it came from"
expect_lacks "$("$BIN" compare -u "$WORK/a.csum.csv" "$WORK/a")" "# Changed" "a saved file has nothing changed"

echo "roots"
cp -R "$WORK/a" "$WORK/moved"
MOVED="$("$BIN" compare -u "$WORK/a.csum.csv" "$WORK/moved")"
expect_contains "$MOVED" "# Unchanged" "the same tree elsewhere is unchanged"
expect_lacks "$MOVED" "# Moved" "the same tree elsewhere is not all moved"
expect_contains "$MOVED" "csum-first-root $CANONICAL/a" "the first root is recorded"
expect_contains "$MOVED" "csum-second-root $CANONICAL/moved" "the second root is recorded"

echo "algorithm"
expect_contains "$("$BIN" compare -u "$WORK/a-sha1.csum.csv" "$WORK/a")" "# Unchanged" "a saved file's algorithm is used for the live side"
expect_contains "$("$BIN" compare -u "$WORK/a-sha1.csum.csv" "$WORK/a")" "csum-algorithm sha1" "the comparison records the adopted algorithm"

echo "errors"
expect_exit 64 "a missing path fails" "$BIN" check "$WORK/nope"
expect_exit 64 "a missing comparison source fails" "$BIN" compare "$WORK/a.csum.csv" "$WORK/nope"

printf 'nonsense\r\n' > "$WORK/broken.csum.csv"
expect_exit 64 "a malformed csum file fails" "$BIN" compare "$WORK/broken.csum.csv" "$WORK/a"

expect_exit 64 "mismatched algorithms fail" "$BIN" compare "$WORK/a-sha1.csum.csv" "$WORK/a-sha256.csum.csv"

expect_contains "$("$BIN" --help)" "check" "the help lists check"
expect_contains "$("$BIN" --help)" "compare" "the help lists compare"
expect_contains "$("$BIN" check --help)" "--algorithm" "check documents its algorithm option"
expect_lacks "$("$BIN" compare --help)" "--algorithm" "compare has no algorithm option"

if [ "$FAILURES" -ne 0 ]; then
    echo "$FAILURES check(s) failed" >&2
    exit 1
fi

echo "all checks passed"

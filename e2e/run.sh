#!/usr/bin/env bash
# e2e smoke test for mbtx-install: install fixture scripts and run them.
# Scope is intentionally thin — "can install and it runs" is enough.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOON_BIN="${MOON_HOME:-$HOME/.moon}/bin"
SCRIPTS="$ROOT/e2e/scripts"

fail() { echo "e2e FAIL: $*" >&2; exit 1; }

# 1. Install mbtx-install itself from source (moon update first so the
# registry index exists on fresh machines).
(cd "$ROOT" && moon update >/dev/null 2>&1) || true
moon install "$ROOT/cmd/mbtx-install" >/dev/null
MBTX_INSTALL="$MOON_BIN/mbtx-install"
[ -x "$MBTX_INSTALL" ] || fail "mbtx-install not installed at $MBTX_INSTALL"

# 2. Install fixtures into an isolated --bin dir and run them.
TMPBIN="$(mktemp -d)"
trap 'rm -rf "$TMPBIN"' EXIT

# moon's own log lines look different across toolchain versions
# ("INFO ..." on older moon, "Finished. moon: ran N tasks" on newer) —
# match either as a marker that moon's output leaked into ours.
install_log="$("$MBTX_INSTALL" "$SCRIPTS/hello.mbtx" --bin "$TMPBIN" 2>&1)"
echo "$install_log" | grep -q "Installed" || fail "hello: missing 'Installed' line: $install_log"
echo "$install_log" | grep -qE "INFO |moon: ran" && fail "quiet mode leaked moon logs: $install_log"
out="$("$TMPBIN/hello")"
[ "$out" = "hello from mbtx-install e2e" ] || fail "hello: unexpected output: $out"
echo "e2e: hello ok (quiet by default)"

# -v/--verbose passes moon's logs through.
verbose_log="$("$MBTX_INSTALL" "$SCRIPTS/hello.mbtx" --bin "$TMPBIN" -v 2>&1)"
echo "$verbose_log" | grep -qE "INFO |moon: ran" || fail "verbose mode hid moon logs: $verbose_log"
echo "e2e: verbose ok"

# Installing records the name in the manifest (~/.mbtx-install/config.json).
MANIFEST="$HOME/.mbtx-install/config.json"
[ -f "$MANIFEST" ] || fail "manifest not created: $MANIFEST"
grep -q '"hello"' "$MANIFEST" || fail "manifest does not record 'hello'"
echo "e2e: manifest ok"

"$MBTX_INSTALL" "$SCRIPTS/argv-echo.mbtx" --bin "$TMPBIN" >/dev/null
out="$("$TMPBIN/argv-echo" alpha "b c")"
expected="arg[0]=$TMPBIN/argv-echo
arg[1]=alpha
arg[2]=b c"
[ "$out" = "$expected" ] || fail "argv-echo: unexpected output: $out"
echo "e2e: argv-echo ok"

"$MBTX_INSTALL" "$SCRIPTS/dep-json5.mbtx" --bin "$TMPBIN" >/dev/null
out="$("$TMPBIN/dep-json5")"
[ "$out" = 'Object({a: Number(1), b: String(x)})' ] || fail "dep-json5: unexpected output: $out"
echo "e2e: dep-json5 ok (external mooncakes dep resolved)"

# 4. Same command reinstalls cleanly (unconditional overwrite).
"$MBTX_INSTALL" "$SCRIPTS/hello.mbtx" --bin "$TMPBIN" >/dev/null
out="$("$TMPBIN/hello")"
[ "$out" = "hello from mbtx-install e2e" ] || fail "reinstall: unexpected output: $out"
echo "e2e: reinstall ok"

# 5. A binary mbtx-install did not install must not be overwritten.
printf '#!/bin/sh\nexit 0\n' > "$TMPBIN/foreign"
chmod +x "$TMPBIN/foreign"
if "$MBTX_INSTALL" "$SCRIPTS/hello.mbtx" --bin "$TMPBIN" -o foreign >/dev/null 2>&1; then
  fail "overwrite guard: expected refusal for a foreign binary"
fi
[ -x "$TMPBIN/foreign" ] || fail "overwrite guard clobbered the foreign binary"
echo "e2e: overwrite guard ok"

echo "e2e: all smoke tests passed"

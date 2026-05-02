#!/usr/bin/env bash
# Smoke-test the HighTide bazel-remote cache (cache.hightide-benchmarks.dev).
# Runs from any machine with curl + sha256sum/shasum + openssl.
#
# Usage:
#   ./test-cache.sh                   # anonymous read-only check
#   ./test-cache.sh -u USER -p TOKEN  # full read+write check (needs the shared write credential)
#   USER=... PASS=... ./test-cache.sh # same, via env vars
set -euo pipefail

HOST="${HOST:-cache.hightide-benchmarks.dev}"
URL="https://${HOST}"
USER="${USER:-}"
PASS="${PASS:-}"
while getopts "u:p:h:" opt; do
  case "$opt" in
    u) USER="$OPTARG" ;;
    p) PASS="$OPTARG" ;;
    h) URL="https://$OPTARG" ;;
    *) echo "usage: $0 [-u user] [-p pass] [-h host]"; exit 2 ;;
  esac
done

# Pick the right SHA256 tool (Linux uses sha256sum, macOS ships shasum)
sha256() {
  if command -v sha256sum >/dev/null; then sha256sum | awk '{print $1}';
  else                                     shasum -a 256 | awk '{print $1}'; fi
}

pass=0; fail=0
check() {
  local name=$1 expect=$2 got=$3
  if [[ "$got" == "$expect" ]]; then echo "  PASS  $name (got $got)"; pass=$((pass+1));
  else                               echo "  FAIL  $name (expected $expect, got $got)"; fail=$((fail+1)); fi
}

echo "Target: $URL"
echo

echo "[1] /status reachable (anonymous):"
code=$(curl -sS -o /dev/null -w "%{http_code}" "$URL/status" || echo "ERR")
check "GET /status" 200 "$code"

# Generate a fresh test blob each run so we exercise both cold-write and warm-read
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
printf 'hightide-cache-smoke-test %s' "$(date -u +%FT%TZ)" > "$TMP/blob"
KEY=$(sha256 < "$TMP/blob")
echo
echo "[2] Anonymous PUT (should be rejected):"
code=$(curl -sS -o /dev/null -w "%{http_code}" -X PUT --data-binary @"$TMP/blob" "$URL/cas/$KEY" || echo "ERR")
check "anonymous PUT /cas/<sha>" 401 "$code"

if [[ -n "$USER" && -n "$PASS" ]]; then
  echo
  echo "[3] Authenticated PUT (should succeed):"
  code=$(curl -sS -o /dev/null -w "%{http_code}" -u "${USER}:${PASS}" -X PUT --data-binary @"$TMP/blob" "$URL/cas/$KEY" || echo "ERR")
  check "auth PUT /cas/<sha>" 200 "$code"

  echo
  echo "[4] Anonymous GET round-trip (should return the bytes we just wrote):"
  curl -sS -o "$TMP/got" -w "" "$URL/cas/$KEY" || true
  if cmp -s "$TMP/blob" "$TMP/got"; then echo "  PASS  GET /cas/<sha> body matches"; pass=$((pass+1));
  else                                   echo "  FAIL  GET /cas/<sha> body mismatch"; fail=$((fail+1)); fi
else
  echo
  echo "[3,4] Skipped — no -u/-p (or USER/PASS) provided.  Pass credentials to test write+roundtrip."
fi

echo
echo "Result: $pass passed, $fail failed"
[[ $fail -eq 0 ]]

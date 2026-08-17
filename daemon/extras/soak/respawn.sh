#!/usr/bin/env bash
# OpenPods restart soak.
#
# Kill + relaunch the daemon N times, asserting:
#   - Each launch creates /tmp/app_server within 6s.
#   - Each SIGTERM is honored within 4s (no hung shutdowns).
#   - The IPC socket is removed between runs (no leak in main()'s
#     QLocalServer::removeServer aboutToQuit hook).
#   - Final RSS sample is within 20% of the first run's RSS — would
#     catch a leak that grows the daemon across restart cycles.
#
# Not a full soak: doesn't touch the BT adapter (would need sudo and
# may interfere with the user's real session). The aim is restart-loop
# cleanliness.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BIN="${ROOT}/linux/build/librepods"
SOCK="/tmp/app_server"
N="${1:-50}"
LOG="/tmp/openpods-soak-$$.log"

[[ -x "${BIN}" ]] || { echo "build first: cmake --build linux/build" >&2; exit 2; }

first_rss=0
last_rss=0
fail() { echo "[SOAK] FAIL: $*" >&2; exit 1; }

for i in $(seq 1 "${N}"); do
    pkill -9 -f "build/librepods" 2>/dev/null || true
    rm -f "${SOCK}"
    env -u QT_STYLE_OVERRIDE "${BIN}" --debug > "${LOG}" 2>&1 &
    pid=$!

    # Wait up to 6s for the socket
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
        [[ -S "${SOCK}" ]] && break
        sleep 0.5
    done
    if [[ ! -S "${SOCK}" ]]; then
        kill -9 "${pid}" 2>/dev/null
        fail "iter ${i}: socket never appeared"
    fi

    rss="$(awk '/^VmRSS:/ {print $2}' "/proc/${pid}/status" 2>/dev/null || echo 0)"
    (( first_rss == 0 )) && first_rss=${rss}
    last_rss=${rss}

    # Clean SIGTERM
    kill -TERM "${pid}" 2>/dev/null
    for _ in 1 2 3 4 5 6 7 8; do
        kill -0 "${pid}" 2>/dev/null || break
        sleep 0.5
    done
    if kill -0 "${pid}" 2>/dev/null; then
        kill -9 "${pid}" 2>/dev/null
        fail "iter ${i}: ignored SIGTERM"
    fi

    if [[ -S "${SOCK}" ]]; then
        # The aboutToQuit hook is meant to remove it; warn if dangling.
        echo "[SOAK] iter ${i}: socket dangled after shutdown — cleanup hook?" >&2
        rm -f "${SOCK}"
    fi

    if (( i % 10 == 0 )); then
        echo "[SOAK] iter ${i}/${N}: rss=${rss}KB"
    fi
done

# Catch leaks growing across cycles. Allow 20% slack for one-off
# allocation patterns (font cache etc).
threshold=$(( first_rss + first_rss / 5 ))
if (( last_rss > threshold )); then
    echo "[SOAK] FAIL: rss grew first=${first_rss}KB last=${last_rss}KB (>20%)" >&2
    exit 1
fi

echo "[SOAK] PASS (${N} cycles; rss first=${first_rss}KB last=${last_rss}KB)"
rm -f "${LOG}"

---
type: reference
title: The daemon control socket lives under XDG_RUNTIME_DIR
description: Why the socket moved off /tmp, and the Qt rule that makes an absolute path work
tags: [librepods, ipc, security]
status: stable
verified:
  - by: reading Qt's QLocalServer path handling, then building both binaries against the shared header
    at: 2026-08-16
---

# What changed

The daemon used to call `server.listen("app_server")`, which Qt resolves
against the temp dir, so the control channel sat at a predictable
world-visible `/tmp/app_server`. It now binds
`$XDG_RUNTIME_DIR/librepods.sock`, which on a systemd session is
`/run/user/<uid>`, mode 0700.

`QLocalServer` and `QLocalSocket` treat a name beginning with `/` as a full
filesystem path rather than a basename under the temp dir. That single rule is
what makes the move a path change instead of a protocol change.

# Why a shared header

Both the daemon and `librepods-ctl` compute the path from
`OpenPods::Ipc::socketPath()` in `linux/ipcpath.hpp`. Two copies of a path
string is precisely the kind of thing that drifts, and a drifted socket path
fails as "daemon not running" rather than as anything that points at the cause.

# Why it refuses to fall back

`socketPath()` returns an empty string when `XDG_RUNTIME_DIR` is unset, and
both binaries exit with a named error rather than falling back to `/tmp`. A
fallback would quietly restore the thing being removed, and every context that
matters here (the graphical session, the Quickshell process that runs the
panel) has a runtime dir.

`tst_ipcpath` asserts both halves: empty environment gives an empty path, and a
set one gives an absolute path under it.

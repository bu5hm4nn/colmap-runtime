#!/usr/bin/env bash
# Stable entrypoint so the harness can run arbitrary commands:
#   docker run --rm <image> <cmd> [args...]
# With no args, drop into bash. Runs unprivileged; no docker socket needed.
set -euo pipefail
if [ "$#" -gt 0 ]; then
  exec "$@"
fi
exec bash

#!/bin/sh
# Replace this container's SSH host keys with fresh ones, exactly once.
#
# The image ships stock host keys so that sshd's first start cannot fail with
# "sshd: no hostkeys available -- exiting" (that failure races with the host's
# port forwarding and left an instance unreachable, incident 2026-09-28). Those
# stock keys are shared by every instance of this public image, so they are
# replaced per container before sshd reads them.
#
# Usage: ssh-host-keys-rotate.sh [prefix] [marker]
#   prefix  filesystem prefix holding etc/ssh (default /, overridable for tests)
#   marker  rotation marker (default /run/..., container-local so it resets)
# A second rotation would invalidate a client's pinned known_hosts entry, so the
# marker makes this idempotent for the life of the container.
set -eu
prefix=$(echo "${1:-/}" | sed 's:/*$::')
marker=${2:-/run/colmap-runtime-host-keys-rotated}
if [ -e "$marker" ]; then
    exit 0
fi
rm -f "$prefix/etc/ssh"/ssh_host_*_key "$prefix/etc/ssh"/ssh_host_*_key.pub
ssh-keygen -A -f "$prefix" >/dev/null 2>&1 || true
: > "$marker"

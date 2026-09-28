#!/bin/sh
# OS first-start hook for sshd: rotate host keys, then start the packaged service.
#
# The packaged Debian/Ubuntu init script is installed as ssh.dist and does not
# generate missing host keys (verified against debian/ssh.init), so rotation
# cannot be delegated to it. This wrapper is the hook that runs before sshd
# starts, on every service invocation, independent of any platform startup
# mechanism.
set -eu
/usr/local/lib/colmap-runtime/ssh-host-keys-rotate.sh / || true
exec /etc/init.d/ssh.dist "$@"

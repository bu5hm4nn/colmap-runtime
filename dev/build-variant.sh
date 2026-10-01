#!/usr/bin/env bash
# Build a COLMAP variant tree (control) in its own source + build dirs, so the
# PR#3 dev image can build the parent/static controls in the same environment.
#
# Usage:
#   build-variant.sh <name> <tarball-url> <tarball-sha256> [patch-file]
# Examples:
#   build-variant.sh parent32 \
#     https://codeload.github.com/uncloud-tech/colmap/tar.gz/78f41b8c6cb2629775115ee2dc3b50f21a51c4f1 \
#     9f132c88a3b2b8b6b8680c5eff4a20dc1dbd96fe2da1f47f4356c5d5aedb8575
#   build-variant.sh static8 <same-url> <same-sha> /path/to/static8.patch
#
# Separates trees (/src/<name>) and build dirs (/src/<name>-build), so variants
# never mutate each other or the candidate PR#3 tree.
set -euo pipefail
NAME="${1:?usage: build-variant.sh <name> <url> <sha256> [patch]}"
URL="${2:?}"
SHA="${3:?}"
PATCH="${4:-}"
ARCH="${CUDA_ARCHITECTURES:-86;120}"
ROOT="/src/${NAME}"
BUILD="/src/${NAME}-build"

if [ ! -d "$ROOT" ]; then
  curl -fsSL "$URL" -o "/tmp/${NAME}.tar.gz"
  echo "${SHA}  /tmp/${NAME}.tar.gz" | sha256sum -c -
  mkdir -p "$ROOT"
  tar -xzf "/tmp/${NAME}.tar.gz" -C "$ROOT" --strip-components=1
  rm "/tmp/${NAME}.tar.gz"
fi

if [ -n "$PATCH" ]; then
  echo "applying $(sha256sum "$PATCH")"
  ( cd "$ROOT" && patch -p1 < "$PATCH" )
fi

cmake -S "$ROOT" -B "$BUILD" -GNinja -DCMAKE_BUILD_TYPE=Release \
  -DCUDA_ENABLED=ON -DCMAKE_CUDA_ARCHITECTURES="$ARCH" \
  -DONNX_ENABLED=OFF -DGUI_ENABLED=OFF -DCGAL_ENABLED=OFF -DLSD_ENABLED=OFF \
  -DCASPAR_ENABLED=OFF -DBUILD_SHARED_LIBS=OFF -DTESTS_ENABLED=ON \
  -DCMAKE_INSTALL_PREFIX="/opt/${NAME}"
cmake --build "$BUILD" -j"$(nproc)"
cmake --install "$BUILD"
echo "built ${NAME} -> /opt/${NAME} (arches ${ARCH})"

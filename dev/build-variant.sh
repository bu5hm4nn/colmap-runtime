#!/usr/bin/env bash
# Build a COLMAP control variant in its own FRESH source + build dirs, against the
# SAME shared deps prefix and explicit offline flags as the PR#3 candidate.
#
# Guarantees:
#  - enforces the exact source tarball SHA256 (fresh extraction, no mutation),
#  - for a patched variant: verifies the patch SHA256 and applies it with
#    `git apply --check` then `git apply` (never `patch`, never the rejected v4),
#  - configures with the identical offline flags/dep prefix as the image build,
#  - preserves configure/build logs, compile_commands.json and binary SHA256.
#
# Usage:
#   build-variant.sh <name> <tarball-url> <expected-tarball-sha256> [patch] [expected-patch-sha256]
#
# Examples:
#   # parent32 = exact parent, unchanged:
#   build-variant.sh parent32 \
#     https://codeload.github.com/uncloud-tech/colmap/tar.gz/78f41b8c6cb2629775115ee2dc3b50f21a51c4f1 \
#     9f132c88a3b2b8b6b8680c5eff4a20dc1dbd96fe2da1f47f4356c5d5aedb8575
#   # static8 = exact parent + source-only patch (hash enforced):
#   build-variant.sh static8 <same-url> <same-sha> \
#     /opt/colmap-dev/patches/parent-static8.patch \
#     aac4f42489a4e458c1241de574c9c1841838c68cf5296944bf02c0643c51deed
set -euo pipefail
NAME="${1:?usage: build-variant.sh <name> <url> <sha256> [patch] [patch-sha256]}"
URL="${2:?}"; SRC_SHA="${3:?}"; PATCH="${4:-}"; PATCH_SHA="${5:-}"
ARCH="${CUDA_ARCHITECTURES:-86-real;120-real}"
DEP=/opt/deps
ROOT="/src/${NAME}"
BUILD="/src/${NAME}-build"

# 1) acquire the EXACT source, fresh, hash-enforced
if [ ! -d "$ROOT" ]; then
  curl -fsSL "$URL" -o "/tmp/${NAME}.tar.gz"
  echo "${SRC_SHA}  /tmp/${NAME}.tar.gz" | sha256sum -c -
  mkdir -p "$ROOT"
  tar -xzf "/tmp/${NAME}.tar.gz" -C "$ROOT" --strip-components=1
  rm -f "/tmp/${NAME}.tar.gz"
fi

# 2) optional patch: enforce its hash, apply only after a clean check
if [ -n "$PATCH" ]; then
  [ -n "$PATCH_SHA" ] || { echo "patch supplied without expected sha256" >&2; exit 2; }
  echo "${PATCH_SHA}  ${PATCH}" | sha256sum -c -
  ( cd "$ROOT" && git apply --check "$PATCH" && git apply "$PATCH" )
fi

# 3) configure/build with the SAME explicit offline flags/dep prefix as PR#3
mkdir -p "$BUILD"
cmake -S "$ROOT" -B "$BUILD" -GNinja -DCMAKE_BUILD_TYPE=Release \
  -DCUDA_ENABLED=ON -DCMAKE_CUDA_ARCHITECTURES="$ARCH" \
  -DONNX_ENABLED=OFF -DGUI_ENABLED=OFF -DCGAL_ENABLED=OFF -DLSD_ENABLED=OFF -DCASPAR_ENABLED=OFF \
  -DBUILD_SHARED_LIBS=OFF -DTESTS_ENABLED=ON -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DFETCH_BOOST=OFF -DFETCH_POSELIB=OFF -DFETCH_FAISS=OFF -DFETCH_ONNX=OFF \
  -DCMAKE_PREFIX_PATH="$DEP" -DBOOST_ROOT="$DEP" \
  -DCMAKE_INSTALL_PREFIX="/opt/${NAME}" 2>&1 | tee "$BUILD/configure.log"
cmake --build "$BUILD" -j"$(nproc)" 2>&1 | tee "$BUILD/build.log"
cmake --install "$BUILD"

# 4) provenance: patched .cu SHA, compile commands, installed binary SHA
{
  echo "variant=${NAME}"
  echo "source_url=${URL}"
  echo "source_sha256=${SRC_SHA}"
  if [ -n "$PATCH" ]; then echo "patch=${PATCH}"; echo "patch_sha256=${PATCH_SHA}"; fi
  echo "cuda_architectures=${ARCH}"
  echo "dep_prefix=${DEP}"
  echo "patch_match_cuda.cu_sha256=$(sha256sum "$ROOT/src/colmap/mvs/patch_match_cuda.cu" | awk '{print $1}')"
  find "/opt/${NAME}" \( -name '*.a' -o -name '*.so' \) -print0 2>/dev/null \
    | xargs -0 -r sha256sum
} | tee "$BUILD/MANIFEST.txt"
echo "built ${NAME} -> /opt/${NAME} ; logs+manifest in ${BUILD}"

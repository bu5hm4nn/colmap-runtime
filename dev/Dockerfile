# TEMPORARY DEV image: exact COLMAP PR#3 tree (uncloud-tech/colmap) for the
# runtime sweep-tile work. CPU-built only — NOT production, NOT GPU-validated.
#
# Design notes:
# - Base is CUDA 12.8 (not 12.9) so it is compatible with the Spheron driver
#   570.195.03 (CUDA 12.8 min driver 570.26; 12.9 would need >= 575).
# - Source is the PR#3 fork tarball at the exact commit, freshly extracted.
#   The rejected v4 `patch_match_cuda.2streams.patch` is NOT applied here.
# - Tests/tooling are retained (unlike the production image): COLMAP uses
#   system find_package(GTest), so a pinned GTest 1.18.0 is installed.
# - ONNX is OFF explicitly (documented omission for benchmark scope).
# - Arch list is an ARG; the built MVS code coverage is verified statically by
#   verify-targets.sh (no GPU launch).
FROM nvidia/cuda:12.8.1-devel-ubuntu24.04@sha256:520292dbb4f755fd360766059e62956e9379485d9e073bbd2f6e3c20c270ed66

ARG COLMAP_COMMIT=2a5c9c81b2e77f10aad25582679c8d344c3f6694
ARG COLMAP_TARBALL_SHA256=b9132fdd6ebb1c92969ce60c37acc29000de22e2b8c6017e5605e7b574697a69
ARG PARENT_COMMIT=78f41b8c6cb2629775115ee2dc3b50f21a51c4f1
ARG PARENT_TARBALL_SHA256=9f132c88a3b2b8b6b8680c5eff4a20dc1dbd96fe2da1f47f4356c5d5aedb8575
ARG CUDA_ARCHITECTURES="86;120"
ARG GTEST_COMMIT=063de7e9578f82b369302001269680b4b1553359
ARG GTEST_SHA256=623fe05d283020f37a579a8985ba338091ac7229da62b5591ff40acdf05b95e2

ENV DEBIAN_FRONTEND=noninteractive
LABEL org.opencontainers.image.description="TEMPORARY dev image: COLMAP PR#3 (runtime sweep tiles); CPU-built, not GPU-validated"

# Build dependencies (same set the production builder needs) plus test tooling.
# openimageio-tools + empty /usr/include/opencv4 are required for COLMAP's
# find_package(OpenImageIO) to configure (see the production Dockerfile).
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git cmake ninja-build build-essential \
        libboost-program-options-dev libboost-graph-dev libboost-system-dev \
        libeigen3-dev libceres-dev libgoogle-glog-dev libgflags-dev \
        libfreeimage-dev libmetis-dev libopenimageio-dev openimageio-tools \
        libsqlite3-dev libcurl4-openssl-dev libssl-dev libglew-dev \
        libgtest-dev libgmock-dev \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/include/opencv4

# Pinned GTest 1.18.0, installed under /usr/local (COLMAP find_package(GTest)).
RUN curl -fsSL "https://github.com/google/googletest/archive/${GTEST_COMMIT}.tar.gz" \
        -o /tmp/gtest.tar.gz && \
    echo "${GTEST_SHA256}  /tmp/gtest.tar.gz" | sha256sum -c - && \
    mkdir -p /opt/gtest-src && tar -xzf /tmp/gtest.tar.gz -C /opt/gtest-src --strip-components=1 && \
    cmake -S /opt/gtest-src -B /opt/gtest-build -GNinja -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=17 -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_GMOCK=OFF -DINSTALL_GTEST=ON && \
    cmake --build /opt/gtest-build -j"$(nproc)" && cmake --install /opt/gtest-build && \
    rm -rf /opt/gtest-src /opt/gtest-build /tmp/gtest.tar.gz

# Exact PR#3 tree, fresh writable extraction (no preserved-cache mutation; the
# PoseLib/ONNX configure steps have source-side effects). A git baseline lets
# the control helper diff/apply patches cleanly.
WORKDIR /src
RUN curl -fsSL "https://codeload.github.com/uncloud-tech/colmap/tar.gz/${COLMAP_COMMIT}" \
        -o /tmp/colmap-pr3.tar.gz && \
    echo "${COLMAP_TARBALL_SHA256}  /tmp/colmap-pr3.tar.gz" | sha256sum -c - && \
    mkdir -p /src/colmap-pr3 && tar -xzf /tmp/colmap-pr3.tar.gz -C /src/colmap-pr3 --strip-components=1 && \
    rm /tmp/colmap-pr3.tar.gz && \
    git -C /src/colmap-pr3 init -q && git -C /src/colmap-pr3 add -A && \
    git -C /src/colmap-pr3 -c user.email=dev@local -c user.name=dev \
        commit -qm "colmap PR#3 ${COLMAP_COMMIT}"

# Build COLMAP (CUDA, tests ON, ONNX OFF) for the requested arches, then install.
RUN cmake -S /src/colmap-pr3 -B /src/colmap-pr3/build -GNinja -DCMAKE_BUILD_TYPE=Release \
        -DCUDA_ENABLED=ON -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES}" \
        -DONNX_ENABLED=OFF -DGUI_ENABLED=OFF -DCGAL_ENABLED=OFF -DLSD_ENABLED=OFF \
        -DCASPAR_ENABLED=OFF -DBUILD_SHARED_LIBS=OFF -DTESTS_ENABLED=ON \
        -DCMAKE_INSTALL_PREFIX=/opt/colmap-dev && \
    cmake --build /src/colmap-pr3/build -j"$(nproc)" && \
    cmake --install /src/colmap-pr3/build

# Record a build/architecture manifest (source SHA, deps, arch list). Runtime
# values (driver/toolkit) are appended at run time by the CI step.
RUN { echo "image=colmap-dev"; echo "source_repo=https://github.com/uncloud-tech/colmap"; \
      echo "source_commit=${COLMAP_COMMIT}"; \
      echo "source_tarball_sha256=${COLMAP_TARBALL_SHA256}"; \
      echo "parent_commit=${PARENT_COMMIT}"; \
      echo "parent_tarball_sha256=${PARENT_TARBALL_SHA256}"; \
      echo "cuda_architectures=${CUDA_ARCHITECTURES}"; \
      echo "onnx=OFF"; echo "tests=ON"; \
      echo "gtest_commit=${GTEST_COMMIT}"; echo "gtest_sha256=${GTEST_SHA256}"; \
      echo "nvcc=$(nvcc --version | tail -1)"; } > /opt/colmap-dev/BUILD-MANIFEST.txt

COPY build-variant.sh verify-targets.sh /opt/colmap-dev/
RUN chmod +x /opt/colmap-dev/build-variant.sh /opt/colmap-dev/verify-targets.sh

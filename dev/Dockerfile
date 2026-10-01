# TEMPORARY DEV image: build/test ENVIRONMENT for the COLMAP runtime sweep-tile
# work, with the exact PR#3 tree prebuilt. CPU-built only — NOT production, NOT
# GPU-validated.
#
# Offline/reproducible model (per coordinator): ALL dependencies are acquired and
# installed into a shared immutable prefix (/opt/deps) in a NETWORK-ENABLED stage;
# COLMAP is then configured/built with FETCH_*=OFF, explicit dependency paths, and
# --network=none, so nothing is fetched opportunistically during configure/build.
#
# - Base: CUDA 12.8.1 / Ubuntu 24.04 (amd64 digest 4b9ed5fa...). NOT 12.9: the
#   5090 path needs PTX-JIT and 12.9 PTX may exceed driver 570.195.03's JIT support.
# - MVS target (workaround-aware): global "86-real;120-real" yields native sm_86
#   SASS + compute_90 PTX (the workaround drops sm_100+ from MVS).
# - GUI/ONNX OFF explicitly. Tests ON (GTest+GMock) for the CPU host tests.
# - This stage is shared/immutable across pr3 | parent32 | static8.
FROM nvidia/cuda:12.8.1-devel-ubuntu24.04@sha256:4b9ed5fa8361736996499f64ecebf25d4ec37ff56e4d11323ccde10aa36e0c43 AS toolchain

ARG COLMAP_COMMIT=2a5c9c81b2e77f10aad25582679c8d344c3f6694
ARG COLMAP_TARBALL_SHA256=b9132fdd6ebb1c92969ce60c37acc29000de22e2b8c6017e5605e7b574697a69
ARG BOOST_VERSION=1.92.0
ARG BOOST_SHA256=9bed76128d4e46755dbe818487788c6fceb6f72b378f4daa49b7e1e600d9088d
ARG POSELIB_COMMIT=1bb8881f08e68f0b3d9b2ecc411fc15e7766ef1b
ARG POSELIB_SHA256=ee46322581c7901fe24e91434eeec27163f820d481cba5faa43d37651fabc8e8
ARG FAISS_VERSION=1.14.1
ARG FAISS_SHA256=4b1ae7e7a0a46385b4084f0e3945623a15fcf99d793bf44d82aae8e24f11e5f5
ARG GTEST_COMMIT=063de7e9578f82b369302001269680b4b1553359
ARG GTEST_SHA256=623fe05d283020f37a579a8985ba338091ac7229da62b5591ff40acdf05b95e2
ARG CUDA_ARCHITECTURES="86-real;120-real"

ENV DEBIAN_FRONTEND=noninteractive
LABEL org.opencontainers.image.description="DEV build/test env: COLMAP PR#3 (runtime sweep tiles); CPU-built, offline deps, not GPU-validated"

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git cmake ninja-build build-essential ccache unzip xz-utils \
        libeigen3-dev libgoogle-glog-dev libgflags-dev libfreeimage-dev libmetis-dev \
        libopenimageio-dev openimageio-tools libsqlite3-dev libcurl4-openssl-dev \
        libssl-dev libglew-dev libgtest-dev libgmock-dev \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/include/opencv4 /opt/deps /opt/src /opt/colmap-dev

# Exported runtime libraries of the shared deps + COLMAP install, so the built
# binaries/tests resolve them offline (no network, no host installs).
ENV LD_LIBRARY_PATH=/opt/deps/lib:/opt/colmap-pr3/lib

# ---- ACQUIRE + INSTALL pinned deps into the shared prefix /opt/deps (network) ----
RUN set -eux; \
    curl -fsSL "https://github.com/google/googletest/archive/${GTEST_COMMIT}.tar.gz" -o /tmp/gtest.tar.gz; \
    echo "${GTEST_SHA256}  /tmp/gtest.tar.gz" | sha256sum -c -; \
    mkdir -p /tmp/gtest-src; tar -xzf /tmp/gtest.tar.gz -C /tmp/gtest-src --strip-components=1; \
    cmake -S /tmp/gtest-src -B /tmp/gtest-build -GNinja -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_STANDARD=17 -DCMAKE_INSTALL_PREFIX=/opt/deps -DBUILD_GMOCK=ON -DINSTALL_GTEST=ON; \
    cmake --build /tmp/gtest-build -j"$(nproc)"; cmake --install /tmp/gtest-build; rm -rf /tmp/gtest-*; \
    \
    curl -fsSL "https://github.com/boostorg/boost/releases/download/boost-${BOOST_VERSION}/boost-${BOOST_VERSION}-cmake.tar.xz" -o /tmp/boost.tar.xz; \
    echo "${BOOST_SHA256}  /tmp/boost.tar.xz" | sha256sum -c -; \
    mkdir -p /tmp/boost-src; tar -xf /tmp/boost.tar.xz -C /tmp/boost-src --strip-components=1; \
    cmake -S /tmp/boost-src -B /tmp/boost-build -GNinja -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/opt/deps -DBOOST_INCLUDE_LIBRARIES="graph;program_options;system"; \
    cmake --build /tmp/boost-build -j"$(nproc)"; cmake --install /tmp/boost-build; rm -rf /tmp/boost-*; \
    \
    curl -fsSL "https://github.com/PoseLib/PoseLib/archive/${POSELIB_COMMIT}.zip" -o /tmp/poselib.zip; \
    echo "${POSELIB_SHA256}  /tmp/poselib.zip" | sha256sum -c -; \
    unzip -q /tmp/poselib.zip -d /tmp/poselib-src; \
    cmake -S "/tmp/poselib-src/PoseLib-${POSELIB_COMMIT}" -B /tmp/poselib-build -GNinja \
          -DCMAKE_BUILD_TYPE=Release -DMARCH_NATIVE=OFF -DCMAKE_INSTALL_PREFIX=/opt/deps; \
    cmake --build /tmp/poselib-build -j"$(nproc)"; cmake --install /tmp/poselib-build; rm -rf /tmp/poselib-*; \
    \
    curl -fsSL "https://github.com/facebookresearch/faiss/archive/refs/tags/v${FAISS_VERSION}.zip" -o /tmp/faiss.zip; \
    echo "${FAISS_SHA256}  /tmp/faiss.zip" | sha256sum -c -; \
    unzip -q /tmp/faiss.zip -d /tmp/faiss-src; \
    cmake -S "/tmp/faiss-src/faiss-${FAISS_VERSION}" -B /tmp/faiss-build -GNinja \
          -DCMAKE_BUILD_TYPE=Release -DFAISS_ENABLE_GPU=OFF -DFAISS_ENABLE_PYTHON=OFF \
          -DFAISS_ENABLE_MKL=OFF -DFAISS_OPT_LEVEL=dd -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/opt/deps; \
    cmake --build /tmp/faiss-build -j"$(nproc)"; cmake --install /tmp/faiss-build; rm -rf /tmp/faiss-*; \
    \
    curl -fsSL "https://codeload.github.com/uncloud-tech/colmap/tar.gz/${COLMAP_COMMIT}" -o /tmp/colmap.tar.gz; \
    echo "${COLMAP_TARBALL_SHA256}  /tmp/colmap.tar.gz" | sha256sum -c -; \
    mkdir -p /opt/src/colmap-pr3; tar -xzf /tmp/colmap.tar.gz -C /opt/src/colmap-pr3 --strip-components=1; \
    rm -f /tmp/colmap.tar.gz; \
    git -C /opt/src/colmap-pr3 init -q; git -C /opt/src/colmap-pr3 add -A; \
    git -C /opt/src/colmap-pr3 -c user.email=dev@local -c user.name=dev commit -qm "colmap PR#3 ${COLMAP_COMMIT}"

# Record the immutable dependency/toolchain manifest (source/dep hashes, toolchain).
RUN { echo "image=colmap-dev"; echo "source_repo=https://github.com/uncloud-tech/colmap"; \
      echo "source_commit=${COLMAP_COMMIT}"; echo "source_tarball_sha256=${COLMAP_TARBALL_SHA256}"; \
      echo "boost_version=${BOOST_VERSION}"; echo "boost_sha256=${BOOST_SHA256}"; \
      echo "poselib_commit=${POSELIB_COMMIT}"; echo "poselib_sha256=${POSELIB_SHA256}"; \
      echo "faiss_version=${FAISS_VERSION}"; echo "faiss_sha256=${FAISS_SHA256}"; \
      echo "gtest_commit=${GTEST_COMMIT}"; echo "gtest_sha256=${GTEST_SHA256}"; \
      echo "cuda_architectures=${CUDA_ARCHITECTURES}"; echo "onnx=OFF"; echo "gui=OFF"; echo "tests=ON"; \
      echo "dep_prefix=/opt/deps"; \
      echo "platform=$(uname -s -m)"; \
      echo "cmake=$(cmake --version | head -1)"; \
      echo "nvcc=$(nvcc --version | tail -1)"; \
      echo "cuda=$(tr -d '\n ' < /usr/local/cuda/version.json 2>/dev/null || echo unknown)"; \
      echo "ccache=$(ccache --version | head -1)"; \
      echo "compute_sanitizer=$(ls -1 /usr/local/cuda/bin/compute-sanitizer 2>/dev/null || echo MISSING)"; \
    } > /opt/colmap-dev/BUILD-MANIFEST.txt

# ---- COLMAP configure/build: OFFLINE (no network), explicit dep paths ----
FROM toolchain AS dev-pr3
ARG CUDA_ARCHITECTURES="86-real;120-real"
RUN --network=none cmake -S /opt/src/colmap-pr3 -B /opt/src/colmap-pr3/build -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCUDA_ENABLED=ON -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES}" \
        -DONNX_ENABLED=OFF -DGUI_ENABLED=OFF -DCGAL_ENABLED=OFF -DLSD_ENABLED=OFF \
        -DCASPAR_ENABLED=OFF -DBUILD_SHARED_LIBS=OFF -DTESTS_ENABLED=ON \
        -DFETCH_BOOST=OFF -DFETCH_POSELIB=OFF -DFETCH_FAISS=OFF -DFETCH_ONNX=OFF \
        -DCMAKE_PREFIX_PATH=/opt/deps -DBOOST_ROOT=/opt/deps \
        -DCMAKE_INSTALL_PREFIX=/opt/colmap-pr3 && \
    cmake --build /opt/src/colmap-pr3/build -j"$(nproc)" && \
    cmake --install /opt/src/colmap-pr3/build

# Append the EXACT executed Release/CUDA flags (shared across all arms) and the
# runtime-library resolution to the manifest, so the flags are auditable.
RUN { echo "--- executed build flags ---"; \
      echo "cmake_build_type=Release"; \
      echo "cuda_architectures=${CUDA_ARCHITECTURES}"; \
      grep -m1 '^CMAKE_CXX_FLAGS:' /opt/src/colmap-pr3/build/CMakeCache.txt || true; \
      grep -m1 '^CMAKE_CUDA_FLAGS:' /opt/src/colmap-pr3/build/CMakeCache.txt || true; \
      echo "ld_library_path=${LD_LIBRARY_PATH}"; \
      echo "fast_math=$([ -n \"$(grep -m1 'use_fast_math' /opt/src/colmap-pr3/build/CMakeCache.txt || true)\" ] && echo on || echo off)"; \
    } >> /opt/colmap-dev/BUILD-MANIFEST.txt

# Stable entrypoint + unprivileged operation (harness runs as UID 1002).
COPY build-variant.sh verify-targets.sh entrypoint.sh /opt/colmap-dev/
RUN chmod +x /opt/colmap-dev/*.sh \
    && chmod -R a+rX /opt/colmap-pr3 /opt/colmap-dev /opt/deps /opt/src \
    && mkdir -p /work && chmod 0777 /work
ENTRYPOINT ["/opt/colmap-dev/entrypoint.sh"]

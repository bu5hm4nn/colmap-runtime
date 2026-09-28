FROM nvidia/cuda@sha256:1199283a7fd5fc7dcb472ea4c6b6d8eb378ef8c0b9aae5e731491c01a219ca43 AS base
LABEL org.opencontainers.image.source="https://github.com/bu5hm4nn/colmap-runtime"
LABEL org.opencontainers.image.description="Pinned CUDA-enabled PyCOLMAP runtime; GPU validation requires a separate test"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -o APT::Get::Always-Include-Phased-Updates=true upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl openssh-server libsm6 libice6 libx11-6 libxext6 \
    libgl1 libopengl0 libglib2.0-0t64 libgomp1 libstdc++6 && \
    rm -rf /var/lib/apt/lists/* && mkdir -p /run/sshd /opt/colmap-runtime && \
    ssh-keygen -A
ENV PATH="/opt/colmap-runtime/python/bin:${PATH}" \
    PYTHONNOUSERSITE=1 PYTHONDONTWRITEBYTECODE=1 PIP_DISABLE_PIP_VERSION_CHECK=1 \
    LD_LIBRARY_PATH="/opt/colmap-runtime/python/lib/python3.14/site-packages/nvidia/cuda_runtime/lib:/opt/colmap-runtime/python/lib/python3.14/site-packages/nvidia/curand/lib:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/local/cuda/lib64"

FROM base AS builder
COPY runtime-lock.json requirements.lock THIRD_PARTY_NOTICES.md /opt/colmap-runtime/
RUN curl --fail --location --retry 3 \
    https://github.com/astral-sh/python-build-standalone/releases/download/20260924/cpython-3.14.7+20260924-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz \
    -o /opt/colmap-runtime/python.tar.gz && \
    echo 'bd0d0568ccded07bbf1c87727230dc5dd0187e706a87da23c4de78388a229b78  /opt/colmap-runtime/python.tar.gz' | sha256sum -c - && \
    tar -xzf /opt/colmap-runtime/python.tar.gz -C /opt/colmap-runtime && rm /opt/colmap-runtime/python.tar.gz
RUN (python3.14 -m pip --version || python3.14 -m ensurepip) && \
    python3.14 -m pip --isolated install --no-cache-dir --no-deps --require-hashes \
      --only-binary=:all: --index-url https://pypi.org/simple -r /opt/colmap-runtime/requirements.lock && \
    python3.14 -m pip check && \
    rm -rf /opt/colmap-runtime/python/lib/python3.14/site-packages/pip \
           /opt/colmap-runtime/python/lib/python3.14/site-packages/pip-*.dist-info \
           /opt/colmap-runtime/python/lib/python3.14/ensurepip && \
    rm -f /opt/colmap-runtime/python/bin/pip*
COPY verify_runtime.py /opt/colmap-runtime/verify_runtime.py


# Measured GPU provenance: BabelStream (the GPU counterpart of STREAM) for
# per-device memory bandwidth. Pinned, unmodified upstream source compiled here;
# its licence requires published results to follow the run rules, so the
# measurement records array size, iterations and thread/device count and the
# binary is not patched. `nvidia/nvbandwidth` for host<->device throughput is a
# follow-up (Apache-2.0); it needs cmake and Boost, so it is deliberately not in
# this stage yet.
FROM nvidia/cuda@sha256:020bc241a628776338f4d4053fed4c38f6f7f3d7eb5919fecb8de313bb8ba47c AS babelstream
ARG BABELSTREAM_SHA256=63aab1bc42a1e953dcae26e279ab100866f8491ab5ce7167269f2ca4b16bb2fb
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl cmake make g++ && rm -rf /var/lib/apt/lists/*
WORKDIR /build
# Architectures cover the GPU families this launcher rents: Ampere (8.6),
# Ada (8.9) and Blackwell (12.0). Fixed at build time; never tuned for the build host.
RUN curl --fail --location --retry 3 https://api.github.com/repos/UoB-HPC/BabelStream/tarball/v5.0 -o babelstream.tar.gz \
 && echo "$BABELSTREAM_SHA256  babelstream.tar.gz" | sha256sum -c - \
 && mkdir source && tar -xzf babelstream.tar.gz -C source --strip-components=1 \
 && cmake -S source -B build -DMODEL=cuda -DCMAKE_CUDA_ARCHITECTURES="86;89;120" -DCMAKE_BUILD_TYPE=Release \
 && cmake --build build -j"$(nproc)" \
 && test -n "$(find build -maxdepth 3 -type f -name babelstream | head -1)" \
 && install -m 0755 "$(find build -maxdepth 3 -type f -name babelstream | head -1)" /usr/local/bin/babelstream

FROM base AS runtime
COPY --from=babelstream /usr/local/bin/babelstream /usr/local/bin/babelstream
COPY --from=builder /opt/colmap-runtime /opt/colmap-runtime
RUN python3.14 /opt/colmap-runtime/verify_runtime.py --mode cpu --require-installer-free --output /opt/colmap-runtime/runtime-manifest.json && \
    dpkg-query -W > /opt/colmap-runtime/system-packages.txt && \
    python3.14 -c 'from importlib.metadata import distributions; print("\n".join(sorted(d.metadata["Name"]+"=="+d.version for d in distributions())))' > /opt/colmap-runtime/python-packages.txt

# SSH startup and authorized_keys must be configured at deployment time.
# Do not bake host keys or start SSH automatically here.
ENTRYPOINT []
CMD ["/bin/bash"]

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

FROM base AS runtime
COPY --from=builder /opt/colmap-runtime /opt/colmap-runtime
RUN python3.14 /opt/colmap-runtime/verify_runtime.py --mode cpu --require-installer-free --output /opt/colmap-runtime/runtime-manifest.json && \
    dpkg-query -W > /opt/colmap-runtime/system-packages.txt && \
    python3.14 -c 'from importlib.metadata import distributions; print("\n".join(sorted(d.metadata["Name"]+"=="+d.version for d in distributions())))' > /opt/colmap-runtime/python-packages.txt

# SSH startup and authorized_keys must be configured at deployment time.
# Do not bake host keys or start SSH automatically here.
ENTRYPOINT []
CMD ["/bin/bash"]

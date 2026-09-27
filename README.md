# colmap-runtime

GPU-ready PyCOLMAP container with pinned scientific dependencies.

**Status:** native imports have been validated in a CPU-only build. The current
revision requires a fresh build. GPU execution and reconstruction quality have
not been validated. No container image is published yet.

## Build

Use the manually dispatched **Build runtime candidate** GitHub Actions workflow,
leaving `publish` false. Locally, with Docker:

```sh
python3 -m unittest discover -s tests -v
docker build --pull --platform linux/amd64 --progress=plain -t colmap-runtime:candidate image
```

The build context is only `image/`, with an explicit file allowlist. Never include
credentials, datasets, private metadata or SSH keys in that context. Supply any
required authentication externally at runtime.

## Environment

- NVIDIA CUDA 12.9.1 runtime / Ubuntu 24.04, amd64 base pinned by digest.
- CPython 3.14.7 standalone archive pinned by SHA256.
- PyCOLMAP CUDA12 4.2.0 and scientific dependencies pinned by wheel hashes;
  see `image/runtime-lock.json` and `image/requirements.lock`.
- Pinned pip CUDA runtime/curand libraries take precedence over base equivalents.
  Verification records and asserts actual mapped paths, not just search paths.
- Interpreter: `/opt/colmap-runtime/python/bin/python3.14`.
- Runtime manifest: `/opt/colmap-runtime/runtime-manifest.json`.

Ubuntu packages resolve security updates at build time. **Rebuilds are not
bit-identical**; use published images by immutable digest. Exact Python and system
package inventories are generated during the build.

## Validation

The build checks package versions, `pip check`, native imports and CUDA build
support. It repeats the import check with networking disabled. Full chained loader
exceptions remain visible in logs. These checks do not establish GPU execution;
the verifier's GPU mode reports device model and driver information only.

The workflow emits a CycloneDX SBOM and vulnerability report. Scan completion does
not imply zero vulnerabilities. An all-layer audit checks a synthetic context
canary and common credential patterns, including files hidden by later layers;
it is not a guarantee against all sensitive content.

## Synthetic GPU check

`scripts/synthetic_canary.py --output /tmp/colmap-canary` generates five small
textured-plane views, runs CUDA feature extraction/matching and dense stereo,
and checks fused geometry against known depth. Run it with the image's Python
interpreter; the output directory must be fresh. It uses known camera poses and
is not a test of SfM pose recovery. A separate worker-process timeout is 300 seconds.
The script is unit-tested, but its GPU execution has not yet been validated.

## Deployment

The image has no SSH host keys and does not start SSH automatically. Configure
startup explicitly if SSH is needed, generating unique host keys with
`ssh-keygen -A` and providing authorized keys externally. Use a writable CUDA cache
directory when needed. Compatibility with the host driver and GPU must be tested
on the intended system.

## Third-party software

Dependencies retain their own licences, including NVIDIA CUDA redistribution
conditions. See `image/THIRD_PARTY_NOTICES.md`. Publication remains disabled pending
review of those conditions and security results. This repository does not relicense
third-party binaries.

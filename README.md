# colmap-runtime

GPU-ready PyCOLMAP container with pinned scientific dependencies.

**Status:** a CPU-validated candidate is published. Anonymous pull and offline
imports by digest passed; GPU execution and reconstruction quality remain unvalidated.

```text
ghcr.io/bu5hm4nn/colmap-runtime@sha256:3922f73194629e3f1b9d83b639d03bf8b7188cbec9776706d49dfa9438f64fde
```

Built from commit `800cd7d4dd56933c647caedee7eea4210ca22158` in
[workflow run 36315027809](https://github.com/bu5hm4nn/colmap-runtime/actions/runs/36315027809).
Later repository changes are not automatically included in this image.

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

Ubuntu packages receive security updates at build time. Build-only pip/ensurepip
are removed before the Python runtime is copied into the final image; runtime
package installation is intentionally unavailable. **Rebuilds are not
bit-identical**; use published images by immutable digest. Exact Python and system
package inventories are generated during the build.

## Validation

The build checks package versions, `pip check`, native imports and CUDA build
support. It repeats the import check with networking disabled. Full chained loader
exceptions remain visible in logs. These checks do not establish GPU execution;
the verifier's GPU mode reports device model and driver information only.

The workflow emits a CycloneDX SBOM and vulnerability report and refuses HIGH or
CRITICAL findings. Lower-severity findings remain visible for review; passing does
not imply zero vulnerabilities. An all-layer audit checks a synthetic context
canary and common credential patterns, including files hidden by later layers;
it is not a guarantee against all sensitive content.

## Synthetic GPU check

`scripts/synthetic_canary.py --output /tmp/colmap-canary` generates five small
textured-plane views, runs CUDA feature extraction/matching and dense stereo,
and checks fused geometry against known depth. Run it with the image's Python
interpreter; the output directory must be fresh. It uses known camera poses and
is not a test of SfM pose recovery. A separate worker-process timeout is 300 seconds.
Use `--check-api` for CPU feature extraction, matching, undistortion and dense-option
validation against the installed bindings. This mode explicitly does not certify
GPU execution. The GPU path has not yet been validated.

## Deployment

The image has no SSH host keys and does not start SSH automatically. Configure
startup explicitly if SSH is needed, generating unique host keys with
`ssh-keygen -A` and providing authorized keys externally. Use a writable CUDA cache
directory when needed. Compatibility with the host driver and GPU must be tested
on the intended system.

## Candidate publication

Publication is manual: enable `publish` and, after reviewing the notices, explicitly
confirm `accept_redistribution_terms`. Both default to false. The workflow publishes
only after its CPU, layer-audit and security gates pass, using a unique candidate
tag. It records the digest, verifies anonymous access and repeats verification
against that digest. A new GHCR package may need its visibility set to public by
the repository owner. A pushed but private package is not considered ready.

Candidates remain GPU-unvalidated until an actual GPU test passes. Registry login
uses only the workflow's short-lived token; it is not passed to Docker builds.
Package-write permission is job-wide, not isolated to the publication step.
A failed anonymous-access check leaves the pushed candidate in the registry;
it does not roll back the push or establish public deployability.

## Third-party software

Dependencies retain their own licences, including NVIDIA CUDA redistribution
conditions. See `image/THIRD_PARTY_NOTICES.md`. Publication requires publisher acknowledgement of those conditions and passing
security gates. This repository does not relicense
third-party binaries.

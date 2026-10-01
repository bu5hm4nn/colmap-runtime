# Blacksmith migration (PR #1)

## Scope

- Production: `blacksmith-4vcpu-ubuntu-2404`.
- Temporary dev image: `blacksmith-32vcpu-ubuntu-2404`.
- Official checkout remains SHA-pinned with persisted credentials disabled.
- Builder: `useblacksmith/setup-docker-builder` v2.2.0, pinned to
  `19215110ab936351210feebdfa5b440b4493e184`.
- Buildx: v0.37.2, explicitly selected instead of the builder action's older default.
- Blacksmith sticky cache keys: `${{ github.repository }}/runtime` and
  `${{ github.repository }}/dev`. Existing separate GHCR registry caches remain
  imported/exported with `mode=max` for portability back to GitHub runners.
- `nofallback: true` makes builder setup failures visible. It does not remove the
  GHCR cache; cache transport and builder fallback are separate concerns.

Version sources checked 2026-10-01:

- https://github.com/useblacksmith/setup-docker-builder/releases/tag/v2.2.0
- https://github.com/useblacksmith/setup-docker-builder/blob/19215110ab936351210feebdfa5b440b4493e184/action.yml
- https://github.com/docker/buildx/releases/tag/v0.37.2
- https://docs.blacksmith.sh/blacksmith-runners/overview
- https://docs.blacksmith.sh/blacksmith-caching/docker-builds

The API's `/releases/latest` currently selects the newer-dated v1.13.0 maintenance
release; the release list includes stable v2.2.0, and current Blacksmith guidance
recommends v2 for new setups. v2 requires an explicit cache key.

US-East is the intended organization setting; this PR neither changes nor verifies
that dashboard setting. Runner labels above do not encode a region.

## Preserved behavior

Raw `docker buildx build --load`, registry cache import/export, image tags,
permissions, manual-only triggers, concurrency groups, and all existing test,
evidence and publication steps are unchanged. Production publication still adds
`--no-cache` and requires redistribution consent plus the existing security gate.
The dev workflow's existing publication/cache/security behavior is unchanged;
this migration does not claim that its informational vulnerability step is a
blocking gate or that dev publication is a fresh `--no-cache` build.

No Dockerfile or dependency recipe changes are part of the migration diff against
main. Main was merged into the PR branch without rewriting its history.

## Validation and rollout

Local contract tests and YAML/shell validation are not evidence that a Blacksmith
runner has executed successfully. No workflow was dispatched for this rework;
the in-flight dev candidate must finish independently.

After the current candidate run is closed and a migration trial is authorized:

1. Confirm the Blacksmith organization region is US-East.
2. Dispatch the PR branch with `publish=false`; do not overlap the candidate build.
3. Repeat the same revision with `publish=false` for a warm-cache comparison.
4. Compare build duration and `CACHED` output; retain full evidence and verify the
   intended Blacksmith builder was used. Production also records Buildx inspect
   output. Do not describe warm-cache performance before observing it.
5. Resolve any pre-existing dev-image gate failures independently; a runner
   migration does not validate CPU tests, CUDA coverage or GPU behavior.
6. Merge only with owner approval. There is no automatic publication on merge.

Rollback is to restore `ubuntu-24.04` and the prior pinned
`docker/setup-buildx-action@f87e5991a6d7451dcb8d9637bfbc97413f497069`, removing the
Blacksmith-specific inputs. Keep the registry cache flags and validation gates.

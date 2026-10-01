# Dev post-build path/gate repair

Historical repair record for workflow f971b94. The subsequent owner-approved
header-only exception and GnuPG/Nsight remediation are documented in
[experimental-dev-security-exception.md](experimental-dev-security-exception.md).
The production zero-HIGH/CRITICAL policy is unchanged.

Failure evidence retained from run 36922317229 (recipe/workflow 42bd483):
`cd: /src/colmap-pr3/build: No such file or directory`. Full image build/install
succeeded; no CPU tests, architecture gate or publication succeeded in that run.

## Layout audit against unchanged dev/Dockerfile

| Evidence | Actual image path / handling |
| --- | --- |
| Candidate source | `/opt/src/colmap-pr3` |
| CMake/CTest/Ninja build | `/opt/src/colmap-pr3/build` |
| Installed binary | `/opt/colmap-pr3/bin/colmap`; hash and `ldd` recorded |
| Boost/dependency prefix | `/opt/deps`; inventory and directly included Boost header hashes recorded |
| MVS CUDA objects | `build/src/colmap/mvs/CMakeFiles/colmap_mvs_cuda.dir/*.cu.o` |
| Manifest | `/opt/colmap-dev/BUILD-MANIFEST.txt`; copied verbatim |
| Parent archive | `/opt/archives/colmap-parent-78f41b8c6cb2629775115ee2dc3b50f21a51c4f1.tar.gz`; pinned checksum enforced |
| Helpers/patches | `/opt/colmap-dev/*.sh`, `/opt/colmap-dev/patches/*`; hashes recorded |
| Compiler/toolkit | `g++ --version`, `nvcc --version`; absent CUDA version.json explicitly noted |
| System packages | `dpkg-query` manifest |
| Reports | Writable container `/evidence` bind-mounted from workflow `reports/` |

The verification script is mounted read-only, outside `dev/` and its Docker build
context. This repair does not change dependency/kernel/helper image layers.

## Gates

- Exact candidate source identity checked against the baked source manifest; the
  recipe already hash-verifies the source archive. Local initialized git commit
  is not substituted for the upstream source identity.
- Only `sweep_tile` CTest selection executes. Nonzero discovery, `--no-tests=error`,
  verbose execution, nonzero passing summary and no selected skips are required.
  Full CPU/device suite and GPU execution are not claimed.
- All three production `colmap_mvs_cuda` objects must expose matching native sm86
  function symbols and compute90 PTX entries. PTX `.target sm_90` is virtual
  compute90 evidence, not native sm90 evidence. All patch-match Sweep, initial
  cost and normal-init families must be present. Native Blackwell SASS or symbols
  from another object cannot replace missing PTX. Raw ELF/PTX lists and dumps
  remain in reports. The separate gpu_mat_test target is not subject to the MVS
  library workaround and is deliberately excluded from this architecture check.
- Security scan/parse failures and any HIGH/CRITICAL findings now stop publishing;
  no ignore-list, severity exception, recipe update or security waiver is added.
- Publishing records the exact revision/run tag and immutable digest only after
  these gates pass. Checksums are collected even on failure.

## Evidence corrections and remaining limits

The retained manifest's `fast_math` inference from CMakeCache can be wrong:
actual generated NVCC command recipes are collected separately (not represented
as observed execution logs). CUDA base evidence now identifies the actual
12.8.1 Ubuntu24.04 amd64 digest. Driver570.195.03 is above the toolkit's documented
minimum, but GPU execution and Blackwell driver PTX-JIT are still unvalidated.

The unchanged Boost recipe includes the nonfatal warning:
`Library 'next_prior' given in BOOST_INCLUDE_LIBRARIES has not been found.`
The original run's logs also show installation of `/opt/deps/include/boost/next_prior.hpp`
via the real `iterator` module. Current installed-header checks verify availability,
not merely inferred module ownership. No selector cleanup is hidden in this repair.

The baked target helper remains stale; this workflow uses external verification
instead. The baked sanitizer helper must receive `/opt/src/colmap-pr3` explicitly.
Its standalone binaries, UID1002 control-build usability, writable nonroot CTest
logs, and control execution are not validated by this workflow. Those remain
separate handoff work, not reasons to claim the candidate ready for GPU use.

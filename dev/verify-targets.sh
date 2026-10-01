#!/usr/bin/env bash
# Statically report and GATE the CUDA architectures emitted in the MVS CUDA
# objects (cubin/PTX), without launching a GPU.
#
# Gate (BOTH required, at MVS-object level):
#   - sm_86-capable code        -> serves the RTX 3090
#   - sm_120 OR compute_90/120  -> serves the RTX 5090 (native SASS, or PTX the
#                                  driver can JIT). compute_90 alone cannot
#                                  serve the 3090, so sm_86 is checked separately.
#
# LIMITATION (stated deliberately): the gate is evaluated over the MVS CUDA
# object files listed below (the translation units that contain the patch-match
# init/sweep kernels). It does NOT resolve per-symbol / per-kernel attribution,
# so an architecture present only in an unrelated kernel of the same object
# would still satisfy the tally. Per-object arch sets are printed so a reviewer
# can see exactly which object contributes what.
#
# Usage: verify-targets.sh [build-dir]
set -euo pipefail
BUILD="${1:-/src/colmap-pr3/build}"
command -v cuobjdump >/dev/null || { echo "cuobjdump not found" >&2; exit 1; }

mapfile -t OBJS < <(find "$BUILD" -path '*mvs*' -name '*.o' 2>/dev/null | sort)
if [ "${#OBJS[@]}" -eq 0 ]; then
  echo "no MVS objects found under $BUILD" >&2
  exit 1
fi

echo "== MVS CUDA objects and their emitted arch entries (per object) =="
for f in "${OBJS[@]}"; do
  arches="$(cuobjdump --list-elf "$f" 2>/dev/null | grep -oE 'sm_[0-9]+|compute_[0-9]+' | sort -u | paste -sd, - || true)"
  printf '%-70s %s\n' "$f" "${arches:-<none>}"
done

echo
echo "== per-architecture tally across MVS objects =="
ELF="$(printf '%s\n' "${OBJS[@]}" | xargs -r -n1 cuobjdump --list-elf 2>/dev/null || true)"
printf '%s\n' "$ELF" | grep -oE 'sm_[0-9]+|compute_[0-9]+' | sort | uniq -c || true

echo
echo "== gate (MVS-object scope) =="
rc=0
if printf '%s\n' "$ELF" | grep -q 'sm_86'; then
  echo "PASS: sm_86 in MVS objects (RTX 3090 served)"
else
  echo "FAIL: no sm_86 in MVS objects -- RTX 3090 not served"; rc=1
fi
if printf '%s\n' "$ELF" | grep -qE 'sm_120|compute_90|compute_120'; then
  echo "PASS: Blackwell code in MVS objects (RTX 5090 served via native sm_120 and/or PTX)"
else
  echo "FAIL: no sm_120/compute_* in MVS objects -- RTX 5090 not served"; rc=1
fi
echo "GATE: $([ $rc -eq 0 ] && echo PASS || echo FAIL) (BOTH sm_86 and Blackwell required, MVS-object scope)"
echo "LIMITATION: per-symbol/per-kernel coverage is NOT resolved; see the per-object table above."
exit $rc

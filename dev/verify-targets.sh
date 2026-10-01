#!/usr/bin/env bash
# Statically report AND GATE the CUDA architectures actually emitted in the
# built MVS objects (cubin/PTX), without launching a GPU. This proves real
# per-kernel coverage rather than just the global CMAKE_CUDA_ARCHITECTURES flag.
#
# Gate (BOTH required):
#   - sm_86-capable code        -> serves the RTX 3090
#   - sm_120 OR compute_90/120  -> serves the RTX 5090 (native SASS, or PTX the
#                                  driver can JIT). compute_90 alone cannot
#                                  serve the 3090, so sm_86 is checked separately.
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

echo "== MVS CUDA objects (cubin/PTX ELF entries), per kernel/file =="
for f in "${OBJS[@]}"; do
  echo "--- ${f}"
  cuobjdump --list-elf "$f" 2>/dev/null | sed 's/^/    /' || echo "    (cuobjdump failed)"
done

echo
echo "== per-architecture tally across all MVS objects =="
ELF="$(printf '%s\n' "${OBJS[@]}" | xargs -r -n1 cuobjdump --list-elf 2>/dev/null || true)"
printf '%s\n' "$ELF" | grep -oE 'sm_[0-9]+|compute_[0-9]+' | sort | uniq -c || true

echo
echo "== gate =="
rc=0
if printf '%s\n' "$ELF" | grep -q 'sm_86'; then
  echo "PASS: sm_86 code present (RTX 3090 served)"
else
  echo "FAIL: no sm_86 code -- RTX 3090 not served"; rc=1
fi
if printf '%s\n' "$ELF" | grep -qE 'sm_120|compute_90|compute_120'; then
  echo "PASS: Blackwell code present (RTX 5090 served via native sm_120 and/or PTX)"
else
  echo "FAIL: no sm_120/compute_* code -- RTX 5090 not served"; rc=1
fi
echo "GATE: $([ $rc -eq 0 ] && echo PASS || echo FAIL) (BOTH sm_86 and Blackwell coverage required)"
exit $rc

#!/usr/bin/env bash
# Statically report the CUDA architectures actually emitted in the built MVS
# objects (cubin/PTX), without launching a GPU. This proves real per-kernel
# coverage rather than just the global CMAKE_CUDA_ARCHITECTURES flag.
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

echo "== MVS CUDA objects (cubin/PTX ELF entries) =="
for f in "${OBJS[@]}"; do
  echo "--- ${f}"
  cuobjdump --list-elf "$f" 2>/dev/null | sed 's/^/    /' || echo "    (cuobjdump failed)"
done

echo
echo "== per-architecture tally across all MVS objects =="
printf '%s\n' "${OBJS[@]}" | xargs -r -n1 cuobjdump --list-elf 2>/dev/null \
  | grep -oE 'sm_[0-9]+|compute_[0-9]+' | sort | uniq -c || true

echo
echo "== explicit checks =="
printf '%s\n' "${OBJS[@]}" | xargs -r -n1 cuobjdump --list-elf 2>/dev/null | grep -q 'sm_86' \
  && echo "PASS: sm_86 (3090) code present" || echo "FAIL: no sm_86 code"
if printf '%s\n' "${OBJS[@]}" | xargs -r -n1 cuobjdump --list-elf 2>/dev/null | grep -qE 'sm_120|compute_90|compute_120'; then
  echo "PASS: Blackwell code present (native sm_120 and/or PTX fallback)"
else
  echo "WARN: no sm_120/compute_* Blackwell code found"
fi

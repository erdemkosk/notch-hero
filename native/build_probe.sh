#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/bin"
mkdir -p "$OUT"

swiftc -O \
  "$ROOT/native/notch_probe.swift" \
  -o "$OUT/notch_probe"

echo "Built $OUT/notch_probe"

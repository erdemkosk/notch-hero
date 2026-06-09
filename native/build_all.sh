#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/native/build_probe.sh"
"$ROOT/native/build_bridge.sh"

echo "Native bilesenler hazir."

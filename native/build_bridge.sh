#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_CPP="$ROOT/native/godot-cpp"
BRIDGE="$ROOT/native/notch_bridge"

if [[ ! -f "$GODOT_CPP/SConstruct" ]]; then
  echo "godot-cpp bulunamadi: $GODOT_CPP"
  exit 1
fi

SCONS=(python3 -m SCons)

if [[ ! -f "$GODOT_CPP/bin/libgodot-cpp.macos.template_debug.a" ]]; then
  echo "godot-cpp kutuphanesi derleniyor..."
  "${SCONS[@]}" -C "$GODOT_CPP" platform=macos target=template_debug -j"$(sysctl -n hw.ncpu)"
  "${SCONS[@]}" -C "$GODOT_CPP" platform=macos target=template_release -j"$(sysctl -n hw.ncpu)"
fi

echo "NotchBridge GDExtension derleniyor..."
"${SCONS[@]}" -C "$BRIDGE" platform=macos target=template_debug -j"$(sysctl -n hw.ncpu)"
"${SCONS[@]}" -C "$BRIDGE" platform=macos target=template_release -j"$(sysctl -n hw.ncpu)"

echo "Tamam: $BRIDGE/bin"

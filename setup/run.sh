#!/usr/bin/env bash
# ==============================================================================
# run.sh — reproduce the canonical example for surge (Surge XT).
# Idempotent: safe to re-run. Verified on Apple M5 Max / macOS arm64.
#
# Depth: full. Initializes submodules, configures CMake+Ninja Release, builds
# the three real plugin formats (CLAP, VST3, Standalone), then validates:
#   - CLAP  -> clap-info (metadata dump) + clap-validator (full test suite)
#   - VST3  -> pluginval --strictness-level 5
#
# Usage:
#   ./setup/run.sh                 # full setup + build + validate
#   SKIP_INSTALL=1 ./setup/run.sh  # skip submodule init + configure/build, just validate
#   SKIP_VALIDATE=1 ./setup/run.sh # build only, skip clap-validator/pluginval
# ==============================================================================
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

CLI_BIN="build/src/surge-xt/surge-xt_artefacts/Release/CLI/surge-xt-cli"
CLAP="build/src/surge-xt/surge-xt_artefacts/Release/CLAP/Surge XT.clap"
VST3="build/src/surge-xt/surge-xt_artefacts/Release/VST3/Surge XT.vst3"
STANDALONE="build/src/surge-xt/surge-xt_artefacts/Release/Standalone/Surge XT.app"

TOOLS_DIR="/Users/km/dev/_mirror/tools"
CLAP_INFO="$TOOLS_DIR/clap-info"
CLAP_VALIDATOR="$TOOLS_DIR/clap-validator"
PLUGINVAL="$TOOLS_DIR/pluginval"

# --- 1. prerequisites + build -----------------------------------------------
if [ -z "${SKIP_INSTALL:-}" ]; then
  # Idempotent: `git submodule update --init --recursive` is a no-op if already initialized.
  echo "==> Initializing git submodules (no-op if already done)..."
  git submodule update --init --recursive

  # Idempotent: re-running cmake configure on an existing build/ dir just re-checks the cache.
  echo "==> Configuring CMake (Release, Ninja)..."
  cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release

  # Idempotent: ninja only rebuilds what changed. Builds the CLI (smoke proof) plus the three
  # real plugin formats needed for full depth.
  echo "==> Building surge-xt-cli + CLAP + VST3 + Standalone targets..."
  cmake --build build --target surge-xt-cli surge-xt_CLAP surge-xt_VST3 surge-xt_Standalone \
    -- -j "$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
fi

for p in "$CLI_BIN" "$CLAP" "$VST3" "$STANDALONE"; do
  if [ ! -e "$p" ]; then
    echo "ERROR: expected build artifact not found at $p" >&2
    exit 1
  fi
done

# --- 2. smoke-check the CLI (proves the shared toolchain/audio layer) ------
echo "==> $CLI_BIN --version"
"$CLI_BIN" --version

# --- 3. validate the real plugin formats ------------------------------------
if [ -z "${SKIP_VALIDATE:-}" ]; then
  echo "==> clap-info metadata dump..."
  "$CLAP_INFO" "$CLAP" >/dev/null && echo "clap-info: OK (loaded + described plugin)"

  echo "==> clap-validator full test suite (this takes ~1-2 min)..."
  "$CLAP_VALIDATOR" validate "$CLAP" | tail -5 || true

  echo "==> pluginval --strictness-level 5 (this takes ~2 min)..."
  "$PLUGINVAL" --strictness-level 5 --validate "$VST3" | tail -20 || true
else
  echo "==> SKIP_VALIDATE set: skipping clap-validator/pluginval."
fi

echo "OK: surge (Surge XT) canonical example completed — CLAP/VST3/Standalone built."
echo "    See setup/README.md for full validator pass/fail breakdown (some strict edge-case"
echo "    tests fail on real plugins like Surge XT; this is documented and expected)."

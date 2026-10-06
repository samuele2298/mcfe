#!/usr/bin/env bash
# Build web senza service worker (evita che il browser resti su versioni vecchie).
# Uso: tool/build.sh            -> API su http://localhost:3000 (sviluppo)
#      tool/build.sh /api       -> API sulla stessa origine dietro nginx (produzione)
set -euo pipefail
cd "$(dirname "$0")/.."
args=(--release --pwa-strategy=none)
if [[ $# -gt 0 ]]; then args+=(--dart-define=API_URL="$1"); fi
flutter build web "${args[@]}"

#!/usr/bin/env bash
# Build web senza service worker (evita che il browser resti su versioni vecchie).
# Uso: tool/build.sh                          -> API su http://localhost:3000 (sviluppo)
#      tool/build.sh /api                     -> API sulla stessa origine dietro nginx
#      tool/build.sh /mentorchess/api /mentorchess/   -> app servita in una sottocartella
set -euo pipefail
cd "$(dirname "$0")/.."
args=(--release --pwa-strategy=none)
if [[ $# -gt 0 ]]; then args+=(--dart-define=API_URL="$1"); fi
if [[ $# -gt 1 ]]; then args+=(--base-href="$2"); fi
flutter build web "${args[@]}"

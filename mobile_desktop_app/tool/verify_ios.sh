#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS verification requires macOS." >&2
  exit 1
fi

command -v flutter >/dev/null
command -v xcodebuild >/dev/null
command -v pod >/dev/null

flutter pub get
(cd ios && pod install)
flutter analyze
flutter test
flutter build ios --debug --no-codesign

if [[ -n "${IOS_DEVICE_ID:-}" ]]; then
  flutter test integration_test/ios_crypto_runtime_test.dart \
    -d "$IOS_DEVICE_ID" \
    --dart-define=RUNTIME_PLATFORM=iOS
fi

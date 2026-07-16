#!/usr/bin/env bash
set -euo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly app_root="$(cd "$script_dir/.." && pwd)"
readonly target="${1:-integration_test/android_crypto_runtime_test.dart}"
readonly target_path="$app_root/$target"
readonly artifact_dir="$app_root/build/firebase-test-lab"
readonly app_apk="$app_root/build/app/outputs/apk/debug/app-debug.apk"
readonly test_apk="$app_root/build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk"

if [[ ! "$target" =~ ^integration_test/[A-Za-z0-9_]+_test\.dart$ ]]; then
  echo "Target must be an integration_test/*_test.dart path." >&2
  exit 2
fi
if [[ ! -f "$target_path" ]]; then
  echo "Integration test target was not found: $target" >&2
  exit 2
fi

command -v flutter >/dev/null
command -v java >/dev/null

mkdir -p "$artifact_dir"
flutter pub get --enforce-lockfile
flutter build apk --debug --no-pub

pushd "$app_root/android" >/dev/null
./gradlew --no-daemon app:assembleAndroidTest
./gradlew --no-daemon app:assembleDebug "-Ptarget=$target_path"
popd >/dev/null

for apk in "$app_apk" "$test_apk"; do
  if [[ ! -s "$apk" ]]; then
    echo "Expected APK was not created: $apk" >&2
    exit 1
  fi
done

cp "$app_apk" "$artifact_dir/app-debug.apk"
cp "$test_apk" "$artifact_dir/app-debug-androidTest.apk"

(
  cd "$artifact_dir"
  sha256sum app-debug.apk app-debug-androidTest.apk > SHA256SUMS
)

echo "Firebase Test Lab APKs are ready in $artifact_dir"

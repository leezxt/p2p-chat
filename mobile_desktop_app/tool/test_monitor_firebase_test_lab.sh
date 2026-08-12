#!/usr/bin/env bash
set -euo pipefail

readonly script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly monitor="$script_dir/monitor_firebase_test_lab.sh"
readonly extractor="$script_dir/extract_firebase_test_lab_matrix_id.py"
readonly workflow="$script_dir/../../.github/workflows/firebase-test-lab.yml"
readonly temp_root="$(mktemp -d)"
trap 'rm -rf "$temp_root"' EXIT

make_fakes() {
  local case_dir="$1"
  mkdir -p "$case_dir/bin" "$case_dir/artifacts"
  cat > "$case_dir/bin/gcloud" <<'SH'
#!/usr/bin/env bash
printf 'fake-access-token\n'
SH
  cat > "$case_dir/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
for arg in "$@"; do
  if [[ "$arg" == *:cancel ]]; then
    printf 'cancelled\n' >> "$FAKE_CANCEL_LOG"
    printf '{"testState":"CANCELLED"}\n'
    exit 0
  fi
done
count=0
if [[ -f "$FAKE_COUNT_FILE" ]]; then count="$(cat "$FAKE_COUNT_FILE")"; fi
count=$((count + 1))
printf '%s' "$count" > "$FAKE_COUNT_FILE"
response="$(sed -n "${count}p" "$FAKE_RESPONSES")"
if [[ "$response" == "CURL_ERROR" ]]; then exit 22; fi
printf '%s\n' "$response"
SH
  chmod +x "$case_dir/bin/gcloud" "$case_dir/bin/curl"
}

run_case() {
  local name="$1"
  local expected_status="$2"
  local responses="$3"
  local queue_timeout="${4:-60}"
  local case_dir="$temp_root/$name"
  make_fakes "$case_dir"
  printf '%s\n' "$responses" > "$case_dir/responses.jsonl"

  set +e
  PATH="$case_dir/bin:$PATH" \
    GCP_PROJECT_ID="p2p-chat-ftl-test" \
    FTL_QUEUE_TIMEOUT_SECONDS="$queue_timeout" \
    FTL_RUN_TIMEOUT_SECONDS=60 \
    FTL_POLL_INTERVAL_SECONDS=0 \
    PYTHON_BIN="${PYTHON_BIN:-python}" \
    FAKE_RESPONSES="$case_dir/responses.jsonl" \
    FAKE_COUNT_FILE="$case_dir/count" \
    FAKE_CANCEL_LOG="$case_dir/cancel.log" \
    bash "$monitor" matrix-test123 "$case_dir/artifacts"
  status=$?
  set -e

  if [[ "$status" -ne "$expected_status" ]]; then
    echo "$name: expected status $expected_status, got $status" >&2
    exit 1
  fi
  CASE_DIR="$case_dir"
}

run_case success 0 \
  '{"testMatrixId":"matrix-test123","state":"FINISHED","outcomeSummary":"SUCCESS"}'
[[ ! -f "$CASE_DIR/cancel.log" ]]
grep -q '^outcome=SUCCESS$' "$CASE_DIR/artifacts/matrix-summary.txt"

run_case queue_timeout 124 \
  '{"testMatrixId":"matrix-test123","state":"PENDING"}' 0
grep -q '^cancelled$' "$CASE_DIR/cancel.log"

run_case failed \
  1 \
  $'{"testMatrixId":"matrix-test123","state":"RUNNING"}\n{"testMatrixId":"matrix-test123","state":"FINISHED","outcomeSummary":"FAILURE"}'
[[ ! -f "$CASE_DIR/cancel.log" ]]
grep -q '^outcome=FAILURE$' "$CASE_DIR/artifacts/matrix-summary.txt"

run_case transient_poll_error \
  0 \
  $'CURL_ERROR\n{"testMatrixId":"matrix-test123","state":"FINISHED","outcomeSummary":"SUCCESS"}'
[[ ! -f "$CASE_DIR/cancel.log" ]]

printf '{"testMatrixId":"matrix-valid123"}\n' > "$temp_root/submission.json"
[[ "$("${PYTHON_BIN:-python}" "$extractor" "$temp_root/submission.json")" == \
  "matrix-valid123" ]]
printf '{"testMatrixId":"invalid"}\n' > "$temp_root/submission.json"
if "${PYTHON_BIN:-python}" "$extractor" "$temp_root/submission.json" >/dev/null 2>&1; then
  echo "Invalid submission matrix ID was accepted." >&2
  exit 1
fi

grep -q '^    timeout-minutes: 180$' "$workflow"
grep -q '^      allow_low_capacity:$' "$workflow"
grep -q 'if \[\[ "$SUBMIT_TEST" == "true" && "$GITHUB_REF" != "refs/heads/main" \]\]; then' "$workflow"
grep -q 'Paid Firebase Test Lab submission must run from main.' "$workflow"
grep -q '^            --async \\$' "$workflow"
grep -q 'monitor_firebase_test_lab.sh' "$workflow"
grep -q 'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1' "$workflow"

echo "Firebase Test Lab monitor tests passed."

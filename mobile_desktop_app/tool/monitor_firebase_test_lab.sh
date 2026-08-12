#!/usr/bin/env bash
set -euo pipefail

readonly matrix_id="${1:-}"
readonly artifact_dir="${2:-build/firebase-test-lab}"
readonly project_id="${GCP_PROJECT_ID:-}"
readonly queue_timeout="${FTL_QUEUE_TIMEOUT_SECONDS:-5400}"
readonly run_timeout="${FTL_RUN_TIMEOUT_SECONDS:-1500}"
readonly poll_interval="${FTL_POLL_INTERVAL_SECONDS:-30}"
readonly max_poll_failures="${FTL_MAX_POLL_FAILURES:-5}"
readonly api_base="${FTL_API_BASE:-https://testing.googleapis.com/v1}"
readonly python_bin="${PYTHON_BIN:-python3}"
readonly matrix_url="${api_base}/projects/${project_id}/testMatrices/${matrix_id}"
readonly latest_json="${artifact_dir}/matrix-latest.json"
readonly summary_file="${artifact_dir}/matrix-summary.txt"

if [[ ! "$matrix_id" =~ ^matrix-[a-z0-9]+$ ]]; then
  echo "Invalid Firebase Test Lab matrix ID." >&2
  exit 2
fi
if [[ ! "$project_id" =~ ^[a-z][a-z0-9-]{4,61}[a-z0-9]$ ]]; then
  echo "GCP_PROJECT_ID is missing or invalid." >&2
  exit 2
fi
for value in "$queue_timeout" "$run_timeout" "$poll_interval" "$max_poll_failures"; do
  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    echo "Firebase Test Lab timeouts must be non-negative integers." >&2
    exit 2
  fi
done

command -v curl >/dev/null
command -v gcloud >/dev/null
command -v "$python_bin" >/dev/null
mkdir -p "$artifact_dir"

terminal=0
started_at="$(date +%s)"
running_at=""
poll_failures=0

access_token() {
  gcloud auth print-access-token --quiet
}

cancel_matrix() {
  if (( terminal )); then return; fi
  local token
  echo "Cancelling unfinished Test Lab matrix ${matrix_id}." >&2
  if ! token="$(access_token)"; then
    echo "Unable to obtain an access token for matrix cancellation." >&2
    return 0
  fi
  curl --silent --show-error --fail-with-body \
    --request POST \
    --header "Authorization: Bearer $token" \
    --header "Content-Type: application/json" \
    --data '{}' \
    "${matrix_url}:cancel" \
    > "${artifact_dir}/matrix-cancel.json" || true
}

on_signal() {
  exit 130
}

trap cancel_matrix EXIT
trap on_signal INT TERM

while true; do
  temp_json="${latest_json}.tmp"
  if ! curl --silent --show-error --fail-with-body \
    --header "Authorization: Bearer $(access_token)" \
    "$matrix_url" > "$temp_json"; then
    poll_failures=$((poll_failures + 1))
    rm -f "$temp_json"
    echo "Test Lab status request failed (${poll_failures}/${max_poll_failures})." >&2
    if (( poll_failures >= max_poll_failures )); then exit 1; fi
    sleep "$poll_interval"
    continue
  fi
  poll_failures=0
  mv "$temp_json" "$latest_json"

  mapfile -t matrix_fields < <(
    "$python_bin" - "$latest_json" "$matrix_id" <<'PY'
import json
import sys

path, expected_id = sys.argv[1:]
with open(path, encoding="utf-8") as source:
    matrix = json.load(source)
if matrix.get("testMatrixId") != expected_id:
    raise SystemExit("Test Lab response matrix ID did not match the request")
print(matrix.get("state", ""))
print(matrix.get("outcomeSummary", ""))
PY
  )
  state="${matrix_fields[0]//$'\r'/}"
  outcome="${matrix_fields[1]//$'\r'/}"
  now="$(date +%s)"

  printf 'matrix_id=%s\nstate=%s\noutcome=%s\nupdated_at_epoch=%s\n' \
    "$matrix_id" "$state" "$outcome" "$now" > "$summary_file"
  echo "Test Lab matrix ${matrix_id}: state=${state}, outcome=${outcome:-pending}"

  case "$state" in
    VALIDATING|PENDING)
      if (( now - started_at >= queue_timeout )); then
        echo "Test Lab queue timeout reached after ${queue_timeout}s." >&2
        exit 124
      fi
      ;;
    RUNNING)
      if [[ -z "$running_at" ]]; then running_at="$now"; fi
      if (( now - running_at >= run_timeout )); then
        echo "Test Lab execution monitoring timeout reached after ${run_timeout}s." >&2
        exit 124
      fi
      ;;
    FINISHED)
      terminal=1
      if [[ "$outcome" == "SUCCESS" ]]; then exit 0; fi
      echo "Test Lab matrix finished without success: ${outcome:-unknown}." >&2
      exit 1
      ;;
    ERROR|UNSUPPORTED_ENVIRONMENT|INCOMPATIBLE_ENVIRONMENT)
      terminal=1
      echo "Test Lab matrix reached terminal state ${state}." >&2
      exit 1
      ;;
    *)
      echo "Unknown Test Lab matrix state: ${state:-empty}." >&2
      exit 1
      ;;
  esac

  sleep "$poll_interval"
done

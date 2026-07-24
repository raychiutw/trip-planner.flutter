#!/usr/bin/env bash

set -euo pipefail

evidence_url="${1:-}"
release_sha="${2:-}"
max_bytes=1048576

if [[ ! "$evidence_url" =~ ^https://[^/?#[:space:]]+([/?#].*)?$ ]]; then
  echo "manual evidence URL must use HTTPS and include a host" >&2
  exit 64
fi
if [[ ! "$release_sha" =~ ^[0-9a-fA-F]{40}$ ]]; then
  echo "release SHA must be a full 40-character commit SHA" >&2
  exit 64
fi

report_path="$(mktemp)"
trap 'rm -f "$report_path"' EXIT

curl \
  --fail \
  --silent \
  --show-error \
  --location \
  --proto '=https' \
  --proto-redir '=https' \
  --connect-timeout 10 \
  --max-time 30 \
  --max-filesize "$max_bytes" \
  --output "$report_path" \
  "$evidence_url"

report_bytes="$(wc -c <"$report_path" | tr -d '[:space:]')"
if [[ -z "$report_bytes" || "$report_bytes" -gt "$max_bytes" ]]; then
  echo "manual evidence report exceeds ${max_bytes} bytes" >&2
  exit 1
fi

required_case_ids='[
  "A11Y-VOICEOVER",
  "A11Y-VOICE-CONTROL",
  "A11Y-SWITCH-CONTROL",
  "A11Y-FULL-KEYBOARD",
  "A11Y-POINTER",
  "A11Y-BUTTON-SHAPES",
  "A11Y-BOLD-TEXT",
  "A11Y-DIFFERENTIATE-WITHOUT-COLOR",
  "APPEARANCE-LIGHT-DARK",
  "A11Y-INCREASE-CONTRAST",
  "A11Y-REDUCE-TRANSPARENCY",
  "A11Y-REDUCE-MOTION",
  "LAYOUT-SAFE-AREA",
  "LAYOUT-KEYBOARD",
  "NAV-EDGE-BACK"
]'
required_fields='[
  "case_id",
  "result",
  "source_sha",
  "version",
  "build",
  "install_source",
  "tester",
  "device",
  "os_version",
  "viewport",
  "setting_or_assistive_technology",
  "flow",
  "expected",
  "observation",
  "blocker",
  "remediation",
  "started_at",
  "evidence"
]'

jq -e \
  --arg release_sha "$release_sha" \
  --argjson required_case_ids "$required_case_ids" \
  --argjson required_fields "$required_fields" \
  '
    def nonempty_string:
      type == "string" and test("\\S");

    (.schema_version == 1) and
    (.cases | type == "array" and length > 0) and
    (
      [.cases[].case_id] as $case_ids |
      ($case_ids | length) == ($case_ids | unique | length) and
      (($required_case_ids - $case_ids) | length == 0)
    ) and
    (
      all(
        .cases[];
        . as $case |
        all(
          $required_fields[];
          . as $field |
          $case[$field] | nonempty_string
        ) and
        $case.result == "PASS" and
        $case.source_sha == $release_sha and
        ($case.evidence | test("^https://[^/?#[:space:]]+(?:[/?#]|$)"))
      )
    ) and
    ([.cases[].version] | unique | length == 1) and
    ([.cases[].build] | unique | length == 1)
  ' "$report_path" >/dev/null

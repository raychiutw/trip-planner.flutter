#!/usr/bin/env bash
set -euo pipefail

: "${STAGING_API_BASE_URL:?Set the non-production Tripline API base URL}"
: "${STAGING_ORIGIN:?Set the allowed non-production Origin}"
: "${STAGING_SESSION_COOKIE:?Set the owner staging session cookie}"
: "${STAGING_OTHER_SESSION_COOKIE:?Set a second-user staging session cookie}"
: "${STAGING_FAVORITE_POI_ID:?Set a disposable staging POI id}"
: "${STAGING_CONTRACT_GUARD:?Set the explicit staging mutation guard}"

if [[ "$STAGING_CONTRACT_GUARD" != 'tripline-staging-favorite-restore-v1' ]]; then
  echo 'Refusing mutations: STAGING_CONTRACT_GUARD is invalid.' >&2
  exit 2
fi

base_url=${STAGING_API_BASE_URL%/}
if [[ ! "$base_url" =~ ^https://([A-Za-z0-9.-]+)$ ]]; then
  echo 'Refusing mutations: STAGING_API_BASE_URL must match an exact committed HTTPS origin without a port or path.' >&2
  exit 2
fi
canonical_host() {
  local host
  host=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  printf '%s' "${host%.}"
}
staging_host=$(canonical_host "${BASH_REMATCH[1]}")
readonly staging_origin="https://$staging_host"
readonly production_hosts=(
  'trip-planner-dby.pages.dev'
)
for production_host in "${production_hosts[@]}"; do
  if [[ "$staging_host" == "$production_host" ]]; then
    echo 'Refusing mutations: staging API uses a committed production hostname.' >&2
    exit 2
  fi
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly staging_environments_file="$script_dir/staging-release-environments.txt"
if [[ ! -r "$staging_environments_file" ]]; then
  echo 'Refusing mutations: committed staging environment allowlist is missing.' >&2
  exit 2
fi
expected_environment_id=''
while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line%%#*}
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  if [[ ! "$line" =~ ^[[:space:]]*https://([A-Za-z0-9.-]+)[[:space:]]+([A-Za-z0-9._-]+)[[:space:]]*$ ]]; then
    echo 'Refusing mutations: committed staging environment allowlist is invalid.' >&2
    exit 2
  fi
  candidate_host=$(canonical_host "${BASH_REMATCH[1]}")
  candidate_environment_id=${BASH_REMATCH[2]}
  for production_host in "${production_hosts[@]}"; do
    if [[ "$candidate_host" == "$production_host" ]]; then
      echo 'Refusing mutations: committed staging environment contains a production hostname.' >&2
      exit 2
    fi
  done
  if [[ "$staging_origin" == "https://$candidate_host" ]]; then
    if [[ -n "$expected_environment_id" ]]; then
      echo 'Refusing mutations: committed staging origin is duplicated.' >&2
      exit 2
    fi
    expected_environment_id=$candidate_environment_id
  fi
done < "$staging_environments_file"
if [[ -z "$expected_environment_id" ]]; then
  echo 'Refusing mutations: API origin is not in the committed staging environment allowlist.' >&2
  exit 2
fi

if [[ ! "$STAGING_FAVORITE_POI_ID" =~ ^[0-9]+$ ]]; then
  echo 'STAGING_FAVORITE_POI_ID must be numeric.' >&2
  exit 2
fi

tmp_dir=$(mktemp -d)
favorite_id=''

request() {
  local method=$1
  local path=$2
  local cookie=$3
  local csrf_token=$4
  local output=$5
  local body=${6-}
  local -a args=(
    --silent --show-error
    --connect-timeout 10
    --max-time 30
    --request "$method"
    --output "$output"
    --write-out '%{http_code}'
    --header 'Accept: application/json'
    --header "Origin: $STAGING_ORIGIN"
    --header "Cookie: $cookie"
  )
  if [[ -n "$csrf_token" ]]; then
    args+=(--header "X-CSRF-Token: $csrf_token")
  fi
  if [[ -n "$body" ]]; then
    args+=(--header 'Content-Type: application/json' --data "$body")
  fi
  curl "${args[@]}" "$base_url$path"
}

cleanup() {
  if [[ -n "$favorite_id" ]]; then
    request DELETE "/api/poi-favorites/$favorite_id" \
      "$STAGING_SESSION_COOKIE" "${STAGING_CSRF_TOKEN:-}" \
      "$tmp_dir/cleanup.json" >/dev/null || true
  fi
  rm -r -- "$tmp_dir"
}
trap cleanup EXIT

# Verify backend identity before any create/delete/restore request. This catches
# a reviewed staging hostname whose DNS or proxy route drifts to production.
status=$(request GET /api/environment-identity "$STAGING_SESSION_COOKIE" '' \
  "$tmp_dir/environment-identity.json")
if [[ "$status" != 200 ]]; then
  echo "Staging environment identity check failed with HTTP $status." >&2
  exit 2
fi
actual_environment_id=$(jq -r '.environmentId // empty' \
  "$tmp_dir/environment-identity.json")
if [[ "$actual_environment_id" != "$expected_environment_id" ]]; then
  echo 'Refusing mutations: backend environment identity does not match the committed staging environment.' >&2
  exit 2
fi

# Recover safely from a previous interrupted smoke that left the fixture active.
status=$(request GET /api/poi-favorites "$STAGING_SESSION_COOKIE" '' \
  "$tmp_dir/preflight.json")
if [[ "$status" != 200 ]]; then
  echo "Staging favorites preflight failed with HTTP $status." >&2
  exit 1
fi
existing_id=$(jq -r --argjson poi "$STAGING_FAVORITE_POI_ID" '
  [.. | objects
    | select((.poi_id? // .poiId? // null) == $poi)
    | .id?]
  | map(select(. != null))
  | first // empty
' "$tmp_dir/preflight.json")
if [[ -n "$existing_id" ]]; then
  status=$(request DELETE "/api/poi-favorites/$existing_id" \
    "$STAGING_SESSION_COOKIE" "${STAGING_CSRF_TOKEN:-}" \
    "$tmp_dir/preflight-delete.json")
  [[ "$status" == 204 ]] || {
    echo "Could not reset the staging fixture (HTTP $status)." >&2
    exit 1
  }
fi

note="ci-restore-contract-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}"
create_body=$(jq -nc \
  --argjson poiId "$STAGING_FAVORITE_POI_ID" \
  --arg note "$note" \
  '{poiId: $poiId, note: $note}')
status=$(request POST /api/poi-favorites "$STAGING_SESSION_COOKIE" \
  "${STAGING_CSRF_TOKEN:-}" "$tmp_dir/create.json" "$create_body")
if [[ "$status" != 201 ]]; then
  echo "Staging favorite create failed with HTTP $status." >&2
  exit 1
fi
favorite_id=$(jq -r '.id // empty' "$tmp_dir/create.json")
if [[ ! "$favorite_id" =~ ^[0-9]+$ ]]; then
  echo 'Staging favorite create did not return a numeric id.' >&2
  exit 1
fi
favorited_at=$(jq -r '.favorited_at // .favoritedAt // empty' "$tmp_dir/create.json")
if [[ -z "$favorited_at" ]]; then
  echo 'Staging favorite create did not return favorited_at.' >&2
  exit 1
fi

status=$(request DELETE "/api/poi-favorites/$favorite_id" \
  "$STAGING_SESSION_COOKIE" "${STAGING_CSRF_TOKEN:-}" \
  "$tmp_dir/delete.json")
[[ "$status" == 204 ]] || {
  echo "Staging favorite delete failed with HTTP $status." >&2
  exit 1
}

status=$(request GET /api/poi-favorites "$STAGING_SESSION_COOKIE" '' \
  "$tmp_dir/after-delete.json")
[[ "$status" == 200 ]] || {
  echo "Staging favorites GET after delete failed with HTTP $status." >&2
  exit 1
}
if jq -e --argjson id "$favorite_id" \
  '.. | objects | select(.id? == $id)' "$tmp_dir/after-delete.json" >/dev/null; then
  echo 'Deleted staging favorite is still visible in the active list.' >&2
  exit 1
fi

status=$(request POST "/api/poi-favorites/$favorite_id/restore" \
  "$STAGING_OTHER_SESSION_COOKIE" "${STAGING_OTHER_CSRF_TOKEN:-}" \
  "$tmp_dir/other-owner.json" '{}')
if [[ "$status" != 403 && "$status" != 404 ]]; then
  echo "Owner containment failed: second user received HTTP $status." >&2
  exit 1
fi

status=$(request POST "/api/poi-favorites/$favorite_id/restore" \
  "$STAGING_SESSION_COOKIE" "${STAGING_CSRF_TOKEN:-}" \
  "$tmp_dir/restore.json" '{}')
[[ "$status" == 200 ]] || {
  echo "Staging favorite restore failed with HTTP $status." >&2
  exit 1
}
jq -e \
  --argjson id "$favorite_id" \
  --argjson poi "$STAGING_FAVORITE_POI_ID" \
  --arg note "$note" \
  --arg favoritedAt "$favorited_at" \
  '(.id == $id)
    and ((.poi_id? // .poiId?) == $poi)
    and (.note == $note)
    and ((.favorited_at? // .favoritedAt?) == $favoritedAt)
    and ((.deleted_at? // .deletedAt? // null) == null)' \
  "$tmp_dir/restore.json" >/dev/null || {
  echo 'Restored favorite did not preserve its id, POI, note, and active state.' >&2
  exit 1
}

status=$(request GET /api/poi-favorites "$STAGING_SESSION_COOKIE" '' \
  "$tmp_dir/after-restore.json")
[[ "$status" == 200 ]] || {
  echo "Staging favorites GET after restore failed with HTTP $status." >&2
  exit 1
}
active_count=$(jq \
  --argjson id "$favorite_id" \
  --argjson poi "$STAGING_FAVORITE_POI_ID" \
  '[.. | objects
    | select(.id? == $id and ((.poi_id? // .poiId? // null) == $poi))]
  | length' "$tmp_dir/after-restore.json")
if [[ "$active_count" != 1 ]]; then
  echo "Expected exactly one restored active favorite, found $active_count." >&2
  exit 1
fi

status=$(request DELETE "/api/poi-favorites/$favorite_id" \
  "$STAGING_SESSION_COOKIE" "${STAGING_CSRF_TOKEN:-}" \
  "$tmp_dir/final-delete.json")
[[ "$status" == 204 ]] || {
  echo "Final staging fixture cleanup failed with HTTP $status." >&2
  exit 1
}
favorite_id=''

echo 'Staging favorite restore contract passed.'

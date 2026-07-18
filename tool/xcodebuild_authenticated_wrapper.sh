#!/usr/bin/env bash
set -euo pipefail

for argument in "$@"; do
  if [[ "$argument" == "build-for-testing" ]]; then
    : "${APPSTORE_API_KEY_PATH:?Set APPSTORE_API_KEY_PATH}"
    : "${APPSTORE_API_KEY_ID:?Set APPSTORE_API_KEY_ID}"
    : "${APPSTORE_ISSUER_ID:?Set APPSTORE_ISSUER_ID}"

    exec /usr/bin/xcodebuild "$@" \
      -allowProvisioningUpdates \
      -authenticationKeyPath "$APPSTORE_API_KEY_PATH" \
      -authenticationKeyID "$APPSTORE_API_KEY_ID" \
      -authenticationKeyIssuerID "$APPSTORE_ISSUER_ID"
  fi
done

exec /usr/bin/xcodebuild "$@"

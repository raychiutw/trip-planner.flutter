#!/usr/bin/env bash

set -euo pipefail

root="${1:-}"
if [[ -z "$root" || "$root" == "/" || ! -d "$root" ]]; then
  echo "usage: $0 <test-lab-evidence-directory>" >&2
  exit 64
fi
if [[ ! -f "$root/.tripline-test-lab-evidence-root" ]]; then
  echo "refusing to sanitize an unmarked directory: $root" >&2
  exit 64
fi

# Test Lab stores uploaded app and test bundles beside result evidence. Keep
# GitHub artifacts useful for diagnosis without republishing signed binaries.
find "$root" -type l -delete
find "$root" -type f ! \( \
  -iname '*.xml' -o \
  -iname '*.log' -o \
  -iname '*logcat*' -o \
  -iname '*.results' -o \
  -iname '*.mp4' -o \
  -iname '*.png' -o \
  -iname '*.jpg' -o \
  -iname '*.jpeg' -o \
  -iname '*.webp' -o \
  -iname '*.json' -o \
  -iname '*.txt' -o \
  -iname '*.html' -o \
  -iname '*.plist' -o \
  -iname '*.csv' \
\) -delete

if find "$root" -type f \( \
  -iname '*.apk' -o \
  -iname '*.aab' -o \
  -iname '*.ipa' -o \
  -iname '*.zip' \
\) -print -quit | grep -q .; then
  echo "signed Test Lab binary remained after evidence sanitization" >&2
  exit 1
fi

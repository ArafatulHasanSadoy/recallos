#!/usr/bin/env bash
# Fails if the release bundle asks for any permission not on the allowlist.
#
# Reads the *bundle* — the artifact Play receives — not the source manifest.
# Plugins merge permissions in at build time (ML Kit once merged INTERNET into
# an app that had never declared it), so the source says nothing about what
# ships. `docs/RELEASE.md` explains the rest of the artifact checks.
#
# Usage: tool/ci/check_permissions.sh [path/to/app-release.aab]
# Needs `bundletool` on PATH, or BUNDLETOOL="java -jar /path/bundletool.jar".
set -euo pipefail

bundle="${1:-build/app/outputs/bundle/release/app-release.aab}"
bundletool="${BUNDLETOOL:-bundletool}"

# Every permission the release build may carry, and why.
allowed=(
  android.permission.CAMERA                 # photographing cards
  android.permission.USE_BIOMETRIC          # the optional wallet lock
  android.permission.USE_FINGERPRINT        # local_auth, for older Android
  com.recallos.recallos.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION # AndroidX, app-private
)

if [[ ! -f "$bundle" ]]; then
  echo "No bundle at $bundle — build it first: flutter build appbundle --release" >&2
  echo "(without android/key.properties, add RECALLOS_ALLOW_DEBUG_SIGNING=true for a local check)" >&2
  exit 2
fi

actual="$($bundletool dump manifest --bundle "$bundle" \
  --xpath '/manifest/uses-permission/@android:name' | sort -u)"

status=0
while IFS= read -r perm; do
  [[ -z "$perm" ]] && continue
  if ! printf '%s\n' "${allowed[@]}" | grep -qx -- "$perm"; then
    echo "NOT ALLOWED: $perm" >&2
    status=1
  fi
done <<< "$actual"

# The other direction: losing the camera would break capture, not tighten it.
if ! grep -qx 'android.permission.CAMERA' <<< "$actual"; then
  echo "MISSING: android.permission.CAMERA — the app cannot scan without it" >&2
  status=1
fi

echo "Permissions in $bundle:"
sed 's/^/  /' <<< "$actual"
if [[ $status -eq 0 ]]; then
  echo "OK — every permission is on the allowlist, and INTERNET is not among them."
else
  echo "Fix the manifest (tools:node=\"remove\"), or add the permission to the" >&2
  echo "allowlist in this script with the reason — and update docs/RELEASE.md." >&2
fi
exit $status

#!/usr/bin/env bash
# OpenIPTV — One-shot project setup.
# Run this ONCE inside the project root on a machine with Flutter installed:
#   ./tool/setup.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Generating platform projects (Android, iOS, macOS)"
flutter create --platforms=android,ios,macos --org dev.openiptv --project-name open_iptv .

echo "==> Fetching dependencies"
flutter pub get

echo "==> Generating Drift database code"
dart run build_runner build --delete-conflicting-outputs

echo "==> Android: enabling Leanback (Android TV) support"
python3 - <<'PY'
import re, pathlib
mf = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = mf.read_text()
if "android.software.leanback" not in s:
    s = s.replace(
        "<application",
        "    <uses-feature android:name=\"android.software.leanback\" android:required=\"false\" />\n    <uses-feature android:name=\"android.hardware.touchscreen\" android:required=\"false\" />\n    <application",
    )
mf.write_text(s)
print("AndroidManifest patched")
PY

echo "==> Done. Next steps:"
echo "    1. Create a Supabase project and run supabase/schema.sql in its SQL editor."
echo "    2. Put your Supabase URL + anon key into lib/core/config.dart."
echo "    3. flutter run        (Android)   flutter run -d macos   (Intel/Apple Silicon)"

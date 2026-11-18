#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.50.0}"
SDK_ARCHIVE="/tmp/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
SDK_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

curl --fail --location --retry 3 --output "$SDK_ARCHIVE" "$SDK_URL"
tar -xf "$SDK_ARCHIVE" -C /tmp
export PATH="/tmp/flutter/bin:$PATH"

flutter --version
flutter pub get
flutter build web --release

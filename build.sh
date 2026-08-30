#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# xcodebuild needs the full Xcode toolchain, not just the Command Line Tools.
if [[ "$(xcode-select -p)" == *CommandLineTools* ]] && [[ -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

PROJECT="StarSaver.xcodeproj"
TARGET="StarSaver"

build() {
  local configuration="$1"
  echo
  echo "==> Building $configuration..."
  xcodebuild -project "$PROJECT" -target "$TARGET" -configuration "$configuration" build
  echo "==> Done: build/$configuration/StarSaver.saver"
}

echo "Which build do you want?"
echo "  0) Exit without building"
echo "  1) Universal (Intel + Apple Silicon)"
echo "  2) Intel only"
echo "  3) Apple Silicon only"
echo "  4) All three"
read -rp "Enter 0-4: " choice

case "$choice" in
  0) exit 0 ;;
  1) build "Release" ;;
  2) build "Release-Intel" ;;
  3) build "Release-AppleSilicon" ;;
  4)
    build "Release"
    build "Release-Intel"
    build "Release-AppleSilicon"
    ;;
  *)
    echo "Invalid choice: $choice" >&2
    exit 1
    ;;
esac

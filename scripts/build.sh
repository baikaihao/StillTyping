#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
xcodebuild -quiet -project StillTyping.xcodeproj -scheme StillTyping \
    -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$PWD/build/Xcode" build
task_app_dir="$PWD/build/StillTyping!!!.app"
task_staging_dir="$(mktemp -d "$PWD/build/.StillTyping.XXXXXX")"
trap 'rm -rf "$task_staging_dir"' EXIT
ditto "$PWD/build/Xcode/Build/Products/Release/StillTyping!!!.app" "$task_staging_dir/StillTyping!!!.app"
codesign --verify --deep --strict "$task_staging_dir/StillTyping!!!.app"
rm -rf "$task_app_dir"
mv "$task_staging_dir/StillTyping!!!.app" "$task_app_dir"
print -r -- "$task_app_dir"

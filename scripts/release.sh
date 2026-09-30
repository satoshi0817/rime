#!/bin/zsh
# Usage: ./scripts/release.sh <notarytool-keychain-profile> [--publish]
set -euo pipefail
cd "$(dirname "$0")/.."

if (( $# < 1 || $# > 2 )); then
    echo "Usage: $0 <notarytool-keychain-profile> [--publish]" >&2
    exit 2
fi
profile="$1"
publish="${2:-}"
if [[ -n "$publish" && "$publish" != "--publish" ]]; then
    echo "Unknown option: $publish" >&2
    exit 2
fi
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Commit changes before creating a release." >&2
    exit 1
fi
if [[ -n "$publish" ]] && ! gh repo view >/dev/null; then
    echo "A GitHub remote and repository are required." >&2
    exit 1
fi

identity="Developer ID Application: SATOSHI SUZUKI (4LPTZP2QZM)"
security find-identity -v -p codesigning | grep -Fq "$identity"
xcrun notarytool history --keychain-profile "$profile" >/dev/null

version=$(sed -n 's/^[[:space:]]*MARKETING_VERSION: //p' project.yml | head -1)
tag="v$version"
app="build/DerivedData/Build/Products/Release/Rime.app"
archive="release/Rime-$version-macOS-universal.zip"

mkdir -p release
xcodegen generate
xcodebuild -project Rime.xcodeproj -scheme Rime -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath build/DerivedData \
    CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$identity" DEVELOPMENT_TEAM=4LPTZP2QZM \
    'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build

[[ "$(lipo -archs "$app/Contents/MacOS/Rime")" == *arm64* ]]
[[ "$(lipo -archs "$app/Contents/MacOS/Rime")" == *x86_64* ]]
codesign --force --sign "$identity" --options runtime --timestamp "$app"
codesign --verify --deep --strict --verbose=2 "$app"
codesign -dv --verbose=4 "$app" 2>&1 | grep -Fq 'flags=0x10000(runtime)'
codesign -dv --verbose=4 "$app" 2>&1 | grep -Fq 'Timestamp='
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"

xcrun notarytool submit "$archive" --keychain-profile "$profile" --wait \
    --output-format json > release/notarization-result.json
status=$(/usr/bin/plutil -extract status raw -o - release/notarization-result.json)
if [[ "$status" != "Accepted" ]]; then
    echo "Notarization status: $status" >&2
    exit 1
fi
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
shasum -a 256 "$archive" > "$archive.sha256"

if [[ -n "$publish" ]]; then
    git tag -a "$tag" -m "Rime $version"
    git push origin HEAD:main "$tag"
    gh release create "$tag" "$archive" "$archive.sha256" \
        --title "Rime $version" --notes-file docs/release-notes.md
fi
echo "Ready: $archive"

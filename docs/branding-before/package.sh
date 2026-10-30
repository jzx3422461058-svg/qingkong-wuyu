#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
configuration="${1:-release}"
swift build -c "$configuration" --product Campus
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
app="dist/晴屿.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/Campus" "$app/Contents/MacOS/Campus"
ditto "$binary_dir/Campus_CampusApp.bundle" "$app/Contents/Resources/Campus_CampusApp.bundle"
if [[ ! -f dist/AppIcon.icns ]]; then
  swift scripts/make-icon.swift dist/AppIcon.iconset
  iconutil -c icns dist/AppIcon.iconset -o dist/AppIcon.icns
fi
cp dist/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Campus</string>
<key>CFBundleIdentifier</key><string>local.qingyu.campus</string>
<key>CFBundleName</key><string>晴屿</string>
<key>CFBundleDisplayName</key><string>晴屿</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$app"
printf '%s\n' "$PWD/$app"

#!/bin/zsh
# Build, bundle, sign (hardened runtime) and install OED.app.
# Env: SIGN_IDENTITY (default ad hoc "-"), BUNDLE_ID.
set -euo pipefail
cd "${0:A:h}"
IDENTITY="${SIGN_IDENTITY:--}"
BUNDLE_ID="${BUNDLE_ID:-io.github.oed2reader.OED}"
VERSION=0.9.0; BUILD=1
swift build -c release
BIN=$(swift build -c release --show-bin-path)/OED
OUT=build/OED.app; rm -rf build; mkdir -p $OUT/Contents/{MacOS,Frameworks,Resources}
cp "$BIN" $OUT/Contents/MacOS/OED
cp ThirdParty/zstd/libzstd.dylib $OUT/Contents/Frameworks/
cp Resources/oed.css Resources/help.html $OUT/Contents/Resources/
ICONSET=build/AppIcon.iconset; mkdir -p $ICONSET
for s in 16 32 128 256 512; do
  sips -z $s $s Resources/AppIcon-1024.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
  sips -z $((s*2)) $((s*2)) Resources/AppIcon-1024.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
done
iconutil -c icns $ICONSET -o $OUT/Contents/Resources/AppIcon.icns; rm -rf $ICONSET
cat > $OUT/Contents/Info.plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleExecutable</key><string>OED</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>OED</string>
<key>CFBundleDisplayName</key><string>OED</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD</string>
<key>LSApplicationCategoryType</key><string>public.app-category.reference</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHumanReadableCopyright</key><string>OED2 Reader, GPLv3. Dictionary content © Oxford University Press; not included.</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PL
codesign --force --timestamp=none --options runtime --sign "$IDENTITY" $OUT/Contents/Frameworks/libzstd.dylib
codesign --force --timestamp=none --options runtime --sign "$IDENTITY" $OUT
codesign --verify --strict --deep $OUT
if [[ "${1:-}" == "--install" ]]; then
  rm -rf /Applications/OED.app && ditto $OUT /Applications/OED.app
  LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
  $LSREG -f /Applications/OED.app
  # Drop the build copy so Spotlight/LaunchServices don't list a duplicate OED.app.
  $LSREG -u "$PWD/$OUT"
  rm -rf build
  echo "installed /Applications/OED.app (build/ removed)"
else
  echo "built $OUT"
fi

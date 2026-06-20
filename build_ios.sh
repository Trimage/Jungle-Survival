#!/bin/bash
# 〈초록의 무덤〉 iOS 빌드 → 세로 패치 → 재서명 → 기기 설치 (원커맨드)
# 사용: bash build_ios.sh [--no-install]
# 주의: Godot 4.6 iOS 익스포터가 Info.plist 방향을 항상 가로로 박는 문제가 있어,
#       빌드 후 Info.plist를 세로로 패치하고 같은 인증서로 재서명한다.
set -e

PROJ="/Users/trimage/Claude/verdant_tomb"
OUT="/Users/trimage/Claude/verdant_tomb_build/ios"
APPNAME="verdant_tomb"
SIGN_ID="A020B6C7C2BBA4208D9ED1FA4327EF457A82078E"   # Apple Development: seokwon0127@naver.com (49K7FW373N)
TEAM="36N7ZXWT6P"
BUNDLE="com.trimagestudio.verdanttomb"
DEVICE="2C293EC1-499D-55FF-9DD1-7E02D8DAEEA1"          # iPhone 16 Pro

echo "==> 임포트"
godot --headless --path "$PROJ" --import >/dev/null 2>&1 || true

echo "==> iOS export"
rm -rf "$OUT"; mkdir -p "$OUT"
godot --headless --path "$PROJ" --export-debug "iOS" "$OUT/$APPNAME.ipa" 2>&1 | grep -iE "ARCHIVE (SUCCEEDED|FAILED)|EXPORT (SUCCEEDED|FAILED)|error:" || true

echo "==> 세로 방향 패치 + 재서명"
WORK="$(mktemp -d)"
cd "$WORK"
unzip -q "$OUT/$APPNAME.ipa"
APP="Payload/$APPNAME.app"
plutil -replace UISupportedInterfaceOrientations -json '["UIInterfaceOrientationPortrait"]' "$APP/Info.plist"
plutil -replace "UISupportedInterfaceOrientations~ipad" -json '["UIInterfaceOrientationPortrait"]' "$APP/Info.plist"
cat > ent.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>application-identifier</key><string>${TEAM}.${BUNDLE}</string>
  <key>com.apple.developer.team-identifier</key><string>${TEAM}</string>
  <key>get-task-allow</key><true/>
</dict></plist>
EOF
for d in "$APP"/Frameworks/*.dylib; do [ -e "$d" ] && codesign -f -s "$SIGN_ID" "$d"; done
codesign -f -s "$SIGN_ID" --entitlements ent.plist "$APP"
codesign --verify --strict "$APP" && echo "   서명 검증 OK"
rm -f "$OUT/$APPNAME.ipa"
zip -qr "$OUT/$APPNAME.ipa" Payload
echo "   ipa: $OUT/$APPNAME.ipa (Portrait)"

if [ "$1" != "--no-install" ]; then
  echo "==> 기기 설치"
  xcrun devicectl device install app --device "$DEVICE" "$OUT/$APPNAME.ipa" 2>&1 | grep -iE "App installed|bundleID|error" || true
fi
echo "==> 완료"

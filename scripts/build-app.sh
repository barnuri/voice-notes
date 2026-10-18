#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/VoiceNotes.app"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
BUNDLE_ID="com.barnuri.voicenotes"
LOG_DIR="$ROOT/logs"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

signing_identity() {
  if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    print -- "$SIGN_IDENTITY"
    return
  fi
  security find-identity -v -p codesigning \
    | sed -nE 's/.*"((Apple Development|Developer ID Application|VoiceNotes Local Signing)[^"]*)".*/\1/p' \
    | head -1
}

cd "$ROOT"
swift build -c release --product VoiceNotes
BIN="$(swift build -c release --show-bin-path)/VoiceNotes"

trash "$APP" 2>/dev/null || true
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/VoiceNotes"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

IDENTITY="$(signing_identity)"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$APP"
  print "signed with: $IDENTITY"
else
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
  print "warning: no signing identity found. The app is ad-hoc signed, so macOS asks for permissions again after every build."
fi

if [[ "${1:-}" != "--install" ]]; then
  print "built: $APP"
  exit 0
fi

INSTALLED="$INSTALL_DIR/VoiceNotes.app"
if [[ -n "$IDENTITY" && -d "$INSTALLED" ]] && codesign -dv "$INSTALLED" 2>&1 | grep -q "Signature=adhoc"; then
  tccutil reset Microphone "$BUNDLE_ID" || true
  tccutil reset Accessibility "$BUNDLE_ID" || true
  print "cleared old permissions from the ad-hoc build. macOS asks one last time."
fi

if pgrep -xq VoiceNotes; then
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" 2>/dev/null || true
  for _ in {1..50}; do pgrep -xq VoiceNotes || break; sleep 0.2; done
  pkill -x VoiceNotes || true
fi
mkdir -p "$INSTALL_DIR" "$LOG_DIR"
trash "$INSTALLED" 2>/dev/null || true
cp -R "$APP" "$INSTALL_DIR/"
"$LSREGISTER" -u "$APP" 2>/dev/null || true
defaults write "$BUNDLE_ID" logDirectory "$LOG_DIR"
open "$INSTALLED"
print "installed: $INSTALLED"
print "logs: $LOG_DIR"

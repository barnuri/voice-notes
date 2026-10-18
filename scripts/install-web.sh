#!/bin/zsh
set -euo pipefail

LABEL="com.barnuri.voicenotes.web"
PORT=5555
REPO="${0:A:h:h}"
PLIST_SRC="$REPO/backend/$LABEL.plist"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
PUBLIC_URL=""
if command -v tailscale >/dev/null; then
  TS_HOST="$(tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')"
  PUBLIC_URL="https://$TS_HOST:$PORT"
fi

sed -e "s#__REPO__#$REPO#g" -e "s#__HOME__#$HOME#g" -e "s#__PUBLIC_URL__#$PUBLIC_URL#g" "$PLIST_SRC" > "$PLIST_DST"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
for _ in {1..50}; do
  launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || break
  sleep 0.2
done
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"

print "VoiceNotes web: http://localhost:$PORT  (this Mac)"
if [[ -z "$PUBLIC_URL" ]]; then
  print "Tailscale is not installed, so the web app is reachable from this Mac only."
  exit 0
fi

print "Publishing $PUBLIC_URL with tailscale serve (tailnet only)."
print "If Tailscale prints an approval link, open it, approve Serve/HTTPS, and this step finishes."
tailscale serve --bg --https="$PORT" "http://127.0.0.1:$PORT"
print "                $PUBLIC_URL  (any device on your tailnet)"

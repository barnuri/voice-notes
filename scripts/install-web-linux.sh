#!/usr/bin/env bash
set -euo pipefail

UNIT="voicenotes-web"
PORT=5555
MIN_NODE_MAJOR=22
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_SRC="$REPO/backend/$UNIT.service"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT_DST="$UNIT_DIR/$UNIT.service"

NODE="$(command -v node || true)"
if [[ -z "$NODE" ]]; then
  echo "Node.js is not on PATH. Install Node $MIN_NODE_MAJOR or later, then run this script again." >&2
  exit 1
fi
if ! "$NODE" -e "process.exit(Number(process.versions.node.split('.')[0]) >= $MIN_NODE_MAJOR ? 0 : 1)"; then
  echo "Node $("$NODE" --version) is too old. Install Node $MIN_NODE_MAJOR or later." >&2
  exit 1
fi

PUBLIC_URL=""
if command -v tailscale >/dev/null; then
  TS_HOST="$(tailscale status --json | "$NODE" -e 'let s="";process.stdin.on("data",(c)=>s+=c).on("end",()=>console.log(JSON.parse(s).Self.DNSName.replace(/\.$/,"")))')"
  PUBLIC_URL="https://$TS_HOST:$PORT"
fi

mkdir -p "$UNIT_DIR"
sed -e "s#__NODE__#$NODE#g" -e "s#__REPO__#$REPO#g" -e "s#__PUBLIC_URL__#$PUBLIC_URL#g" "$UNIT_SRC" > "$UNIT_DST"
systemctl --user daemon-reload
systemctl --user enable "$UNIT"
systemctl --user restart "$UNIT"

echo "VoiceNotes web: http://localhost:$PORT  (this computer)"
echo "Logs: journalctl --user -u $UNIT"
echo "The server stops when you log out. To keep it running, run: loginctl enable-linger $USER"
if [[ -z "$PUBLIC_URL" ]]; then
  echo "Tailscale is not installed, so the web app is reachable from this computer only."
  exit 0
fi

echo "Publishing $PUBLIC_URL with tailscale serve (tailnet only)."
echo "If Tailscale prints an approval link, open it, approve Serve/HTTPS, and this step finishes."
echo "If Tailscale denies access, run: sudo tailscale set --operator=$USER"
tailscale serve --bg --https="$PORT" "http://127.0.0.1:$PORT"
echo "                $PUBLIC_URL  (any device on your tailnet)"

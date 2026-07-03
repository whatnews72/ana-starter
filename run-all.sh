#!/usr/bin/env bash
# Run the dashboard (②) + the fakechat relay (③) together.
# The other two pieces of the loop — ④ the fakechat channel (:8787) and
# ⑤ a Claude Code session — are the runtime environment (see README).
set -e
cd "$(dirname "$0")"

node server.js &          SRV=$!
node fakechat-bridge.js & REL=$!
trap 'kill $SRV $REL 2>/dev/null' EXIT INT TERM

echo "▶ dashboard  http://localhost:${PORT:-8777}"
echo "▶ relay      → fakechat  ${FAKECHAT_WS:-ws://127.0.0.1:8787/ws}"
echo "  To complete the loop, run a Claude Code session that has the fakechat"
echo "  channel connected (it answers via POST /api/agent). See README."
wait

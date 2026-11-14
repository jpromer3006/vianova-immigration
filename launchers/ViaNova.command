#!/bin/bash
# ViaNova Immigration — macOS launcher
# Double-click this file, or use the desktop icon made by make_mac_app.sh.
cd "$(dirname "$0")/.."

# Activate conda env
source /Users/jpromero/anaconda3/bin/activate 2>/dev/null || true
conda activate dev2 2>/dev/null || true

# Install deps if needed (first run)
pip install -q -r requirements.txt 2>/dev/null

PORT=8505   # ViaNova Immigration — dedicated port (avoids conflicts)

# Kill any stale process on this port before starting fresh
OLD=$(lsof -ti :$PORT 2>/dev/null)
if [ -n "$OLD" ]; then
  kill $OLD 2>/dev/null
  sleep 1
fi

# Start ViaNova Immigration
streamlit run app.py --server.port $PORT \
  --browser.gatherUsageStats false \
  >/tmp/vianova_immigration.log 2>&1 &

# Wait for the server to be ready (up to 20 s)
for i in {1..40}; do
  curl -s "http://localhost:$PORT" >/dev/null && break
  sleep 0.5
done

# Open in Chrome app-mode (no browser chrome) for a clean console feel
URL="http://localhost:$PORT"
if [ -d "/Applications/Google Chrome.app" ]; then
  open -na "Google Chrome" --args --app="$URL" --start-fullscreen
else
  open "$URL"
fi

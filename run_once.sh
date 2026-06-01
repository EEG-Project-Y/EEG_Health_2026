#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || {
  echo "ERROR: failed to enter script directory: $SCRIPT_DIR" >&2
  exit 1
}

DATAPROC="./bin/dataproc"
EEGPROMT="./bin/eegpromt"

LATEST_RAW="./data/latestRaw.json"
CURRENT_DATA="./data/currentData.json"
LAST_DATA="./data/lastData.json"
TO_APP="./data/ToApp.json"

DATAPROC_LOG="./logs/dataproc.log"
EEGPROMT_LOG="./logs/eegpromt.log"

echo "[1/5] checking files"

mkdir -p ./data ./logs || {
  echo "ERROR: failed to create data/ or logs/ directory" >&2
  exit 1
}

if [ ! -f "$DATAPROC" ]; then
  echo "ERROR: dataproc not found: $DATAPROC" >&2
  exit 1
fi

if [ ! -x "$DATAPROC" ]; then
  echo "ERROR: dataproc is not executable: $DATAPROC" >&2
  exit 1
fi

if [ ! -f "$EEGPROMT" ]; then
  echo "ERROR: eegpromt not found: $EEGPROMT" >&2
  exit 1
fi

if [ ! -x "$EEGPROMT" ]; then
  echo "ERROR: eegpromt is not executable: $EEGPROMT" >&2
  exit 1
fi

echo "[2/5] preparing mock input"

if [ ! -f "$LATEST_RAW" ]; then
  cat > "$LATEST_RAW" <<'JSON'
{
  "seq": 1,
  "type": "eeg",
  "alpha": 12.3,
  "beta": 8.1,
  "theta": 5.6,
  "delta": 2.4,
  "quality": 85,
  "raw_hex": "AA5501010C08545455",
  "mock": true
}
JSON
  echo "Created mock input: $LATEST_RAW"
else
  echo "Using existing input: $LATEST_RAW"
fi

echo "[3/5] running dataproc"

"$DATAPROC" "$LATEST_RAW" "$CURRENT_DATA" "$LAST_DATA" > "$DATAPROC_LOG" 2>&1
DATAPROC_STATUS=$?

if [ "$DATAPROC_STATUS" -ne 0 ]; then
  echo "ERROR: dataproc failed with exit code $DATAPROC_STATUS" >&2
  echo "See log: $DATAPROC_LOG" >&2
  exit "$DATAPROC_STATUS"
fi

echo "[4/5] running eegpromt"

"$EEGPROMT" "$CURRENT_DATA" "$TO_APP" > "$EEGPROMT_LOG" 2>&1
EEGPROMT_STATUS=$?

if [ "$EEGPROMT_STATUS" -ne 0 ]; then
  echo "ERROR: eegpromt failed with exit code $EEGPROMT_STATUS" >&2
  echo "See log: $EEGPROMT_LOG" >&2
  exit "$EEGPROMT_STATUS"
fi

echo "[5/5] done"

if [ ! -f "$TO_APP" ]; then
  echo "ERROR: ToApp.json was not generated: $TO_APP" >&2
  exit 1
fi

echo "Generated output: $TO_APP"
echo "----- ToApp.json -----"
cat "$TO_APP"
echo

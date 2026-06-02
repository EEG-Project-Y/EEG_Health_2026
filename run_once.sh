#!/bin/sh

set -u

ROOT_DIR="/data/eeg_health"
BIN_DIR="$ROOT_DIR/bin"
DATA_DIR="$ROOT_DIR/data"
LOG_DIR="$ROOT_DIR/logs"

DATAPROC="$BIN_DIR/dataproc"
EEGPROMT="$BIN_DIR/eegpromt"

LATEST_RAW="$DATA_DIR/latestRaw.json"
CURRENT_DATA="$DATA_DIR/currentData.json"
LAST_DATA="$DATA_DIR/lastData.json"
TO_APP="$DATA_DIR/ToApp.json"

RUN_LOG="$LOG_DIR/run_once.log"
DATAPROC_LOG="$LOG_DIR/dataproc.log"
EEGPROMT_LOG="$LOG_DIR/eegpromt.log"
EEGPROMT_STDOUT="$LOG_DIR/eegpromt.stdout.tmp"

log()
{
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$RUN_LOG"
}

fail()
{
  log "ERROR: $*"
  exit 1
}

mkdir -p "$DATA_DIR" "$LOG_DIR" || {
  echo "ERROR: failed to create data/log directories" >&2
  exit 1
}

: > "$RUN_LOG" || {
  echo "ERROR: failed to write log: $RUN_LOG" >&2
  exit 1
}

log "[1/5] checking files"
log "ROOT_DIR=$ROOT_DIR"
log "BIN_DIR=$BIN_DIR"
log "DATA_DIR=$DATA_DIR"
log "LOG_DIR=$LOG_DIR"
log "CURRENT_DATA=$CURRENT_DATA"
log "LAST_DATA=$LAST_DATA"
log "TO_APP=$TO_APP"

if [ ! -f "$DATAPROC" ]; then
  fail "dataproc not found: $DATAPROC"
fi

if [ ! -x "$DATAPROC" ]; then
  fail "dataproc is not executable: $DATAPROC"
fi

if [ ! -f "$EEGPROMT" ]; then
  fail "eegpromt not found: $EEGPROMT"
fi

if [ ! -x "$EEGPROMT" ]; then
  fail "eegpromt is not executable: $EEGPROMT"
fi

if [ -d "$BIN_DIR/lib" ]; then
  if [ "${LD_LIBRARY_PATH+x}" = "x" ] && [ -n "$LD_LIBRARY_PATH" ]; then
    LD_LIBRARY_PATH="$BIN_DIR/lib:$LD_LIBRARY_PATH"
  else
    LD_LIBRARY_PATH="$BIN_DIR/lib"
  fi
  export LD_LIBRARY_PATH
  log "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
fi

log "[2/5] preparing input"

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
  chmod 644 "$LATEST_RAW" 2>/dev/null || true
  log "created mock input: $LATEST_RAW"
else
  log "using existing input: $LATEST_RAW"
fi

log "[3/5] running dataproc"
: > "$DATAPROC_LOG" || fail "failed to write log: $DATAPROC_LOG"

"$DATAPROC" "$LATEST_RAW" "$CURRENT_DATA" "$LAST_DATA" > "$DATAPROC_LOG" 2>&1
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  log "dataproc log:"
  tail -n 40 "$DATAPROC_LOG" 2>/dev/null | tee -a "$RUN_LOG"
  fail "dataproc failed with exit code $STATUS"
fi

if [ ! -f "$CURRENT_DATA" ]; then
  fail "currentData.json was not generated: $CURRENT_DATA"
fi

chmod 644 "$CURRENT_DATA" "$LAST_DATA" 2>/dev/null || true
log "dataproc ok"

log "[4/5] running eegpromt"
: > "$EEGPROMT_LOG" || fail "failed to write log: $EEGPROMT_LOG"
rm -f "$EEGPROMT_STDOUT"

"$EEGPROMT" "$CURRENT_DATA" "$TO_APP" > "$EEGPROMT_STDOUT" 2> "$EEGPROMT_LOG"
STATUS=$?

if [ -s "$EEGPROMT_STDOUT" ]; then
  {
    echo "----- stdout -----"
    cat "$EEGPROMT_STDOUT"
  } >> "$EEGPROMT_LOG"
fi

if [ "$STATUS" -ne 0 ]; then
  log "eegpromt log:"
  tail -n 40 "$EEGPROMT_LOG" 2>/dev/null | tee -a "$RUN_LOG"
  fail "eegpromt failed with exit code $STATUS"
fi

if [ ! -s "$TO_APP" ] && [ -s "$EEGPROMT_STDOUT" ]; then
  cp "$EEGPROMT_STDOUT" "$TO_APP" || fail "failed to save eegpromt stdout to $TO_APP"
  log "saved eegpromt stdout to $TO_APP"
fi

rm -f "$EEGPROMT_STDOUT"

if [ ! -f "$TO_APP" ]; then
  fail "ToApp.json was not generated: $TO_APP"
fi

if [ ! -s "$TO_APP" ]; then
  fail "ToApp.json is empty: $TO_APP"
fi

chmod 644 "$TO_APP" 2>/dev/null || true
log "eegpromt ok"

log "[5/5] done"
log "finished successfully"

echo "----- ToApp.json -----"
cat "$TO_APP"
echo

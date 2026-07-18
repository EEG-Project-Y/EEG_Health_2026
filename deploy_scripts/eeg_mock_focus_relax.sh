#!/bin/sh
set -eu

BASE_DIR=${BASE_DIR:-/data/eeg_health}
RUNTIME_DIR="$BASE_DIR/runtime"
TOAPP_PATH="$RUNTIME_DIR/ToApp.json"
PID_FILE="$RUNTIME_DIR/eeg_mock_focus_relax.pid"
INTERVAL="${EEG_LIVE_INTERVAL:-5}"

mkdir -p "$RUNTIME_DIR"

stop_loop() {
  if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE" 2>/dev/null || true)
    case "$old_pid" in
      ''|*[!0-9]*) ;;
      *)
        if kill -0 "$old_pid" 2>/dev/null; then
          kill "$old_pid" 2>/dev/null || true
          sleep 1
        fi
        ;;
    esac
    rm -f "$PID_FILE"
  fi
  echo "eeg_mock_focus_relax stopped"
}

random_small_int() {
  range=$1
  val=$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | head -n 1 | sed 's/ //g')
  if [ -z "$val" ]; then
    val=$(( ( $(date +%s) * 1103515245 + 12345 ) & 0xFFFF ))
  fi
  echo $(( val % range ))
}

write_focus() {
  seq=$1
  timestamp=$2
  noise=$(random_small_int 11)

  focus=$(( 78 + (noise - 5) ))
  fatigue=$(( 15 + $(random_small_int 6) - 2 ))
  relax=$(( 28 + $(random_small_int 12) - 4 ))
  load=$(( 38 + $(random_small_int 10) - 3 ))
  quality=$(( 92 + $(random_small_int 7) - 2 ))
  confidence="0.$(( 90 + $(random_small_int 6) - 2 ))"

  [ $focus -lt 70 ] && focus=70
  [ $focus -gt 92 ] && focus=92
  [ $fatigue -lt 8 ] && fatigue=8
  [ $fatigue -gt 30 ] && fatigue=30
  [ $relax -lt 15 ] && relax=15
  [ $relax -gt 45 ] && relax=45
  [ $load -lt 25 ] && load=25
  [ $load -gt 55 ] && load=55
  [ $quality -lt 88 ] && quality=88
  [ $quality -gt 98 ] && quality=98

  focusTrend=1
  fatigueTrend=-1
  relaxTrend=0
  loadTrend=1

  state="focused"
  stateLabel="专注"
  direction="focus_training"
  b_alpha="0.$(printf '%02d' $(( 38 + $(random_small_int 12) )))"
  b_beta="0.$(printf '%02d' $(( 55 + $(random_small_int 20) )))"
  advice="建议：当前专注状态良好，适合进行高效工作或深度学习；注意保持坐姿稳定。"

  tmp="$TOAPP_PATH.tmp.$$"
  cat > "$tmp" <<EOF_JSON
{
  "sequence": $seq,
  "timestamp": $timestamp,
  "message": "mock: 专注模式",
  "focus": $focus,
  "fatigue": $fatigue,
  "relax": $relax,
  "load": $load,
  "quality": $quality,
  "confidence": $confidence,
  "focusTrend": $focusTrend,
  "fatigueTrend": $fatigueTrend,
  "relaxTrend": $relaxTrend,
  "loadTrend": $loadTrend,
  "state": "$state",
  "stateLabel": "$stateLabel",
  "direction": "$direction",
  "channelMode": "single",
  "ch1Valid": true,
  "ch2Valid": false,
  "channelStatus": "ch1_active",
  "source": "mock_focus",
  "dataSource": "mock",
  "bands": {
    "delta": "0.12",
    "theta": "0.18",
    "alpha": "$b_alpha",
    "beta": "$b_beta"
  },
  "advice": "${advice}",
  "local": true,
  "model": "mock-focus-relax",
  "summary": ["mock", "$stateLabel"]
}
EOF_JSON
  mv "$tmp" "$TOAPP_PATH"
}

write_relax() {
  seq=$1
  timestamp=$2
  noise=$(random_small_int 11)

  relax=$(( 72 + (noise - 5) ))
  fatigue=$(( 10 + $(random_small_int 6) - 2 ))
  focus=$(( 35 + $(random_small_int 12) - 4 ))
  load=$(( 22 + $(random_small_int 10) - 3 ))
  quality=$(( 90 + $(random_small_int 7) - 2 ))
  confidence="0.$(( 88 + $(random_small_int 6) - 2 ))"

  [ $relax -lt 62 ] && relax=62
  [ $relax -gt 88 ] && relax=88
  [ $fatigue -lt 5 ] && fatigue=5
  [ $fatigue -gt 25 ] && fatigue=25
  [ $focus -lt 22 ] && focus=22
  [ $focus -gt 50 ] && focus=50
  [ $load -lt 12 ] && load=12
  [ $load -gt 38 ] && load=38
  [ $quality -lt 86 ] && quality=86
  [ $quality -gt 97 ] && quality=97

  focusTrend=-1
  fatigueTrend=-1
  relaxTrend=1
  loadTrend=-1

  state="relaxed"
  stateLabel="放松"
  direction="steady_relax"
  b_alpha="0.$(printf '%02d' $(( 58 + $(random_small_int 18) )))"
  b_beta="0.$(printf '%02d' $(( 18 + $(random_small_int 15) )))"
  advice="建议：当前处于放松状态，疲劳度较低，可继续保持轻松节奏或进行冥想练习。"

  tmp="$TOAPP_PATH.tmp.$$"
  cat > "$tmp" <<EOF_JSON
{
  "sequence": $seq,
  "timestamp": $timestamp,
  "message": "mock: 放松模式",
  "focus": $focus,
  "fatigue": $fatigue,
  "relax": $relax,
  "load": $load,
  "quality": $quality,
  "confidence": $confidence,
  "focusTrend": $focusTrend,
  "fatigueTrend": $fatigueTrend,
  "relaxTrend": $relaxTrend,
  "loadTrend": $loadTrend,
  "state": "$state",
  "stateLabel": "$stateLabel",
  "direction": "$direction",
  "channelMode": "single",
  "ch1Valid": true,
  "ch2Valid": false,
  "channelStatus": "ch1_active",
  "source": "mock_relax",
  "dataSource": "mock",
  "bands": {
    "delta": "0.22",
    "theta": "0.35",
    "alpha": "$b_alpha",
    "beta": "$b_beta"
  },
  "advice": "${advice}",
  "local": true,
  "model": "mock-focus-relax",
  "summary": ["mock", "$stateLabel"]
}
EOF_JSON
  mv "$tmp" "$TOAPP_PATH"
}

run_loop() {
  stop_loop
  echo $$ > "$PID_FILE"
  trap 'rm -f "$PID_FILE"; exit 0' INT TERM EXIT

  base_sequence=0
  if [ -f "$TOAPP_PATH" ]; then
    parsed=$(sed -n 's/.*"sequence"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$TOAPP_PATH" | head -n 1)
    case "$parsed" in
      ''|*[!0-9]*) base_sequence=0 ;;
      *) base_sequence=$parsed ;;
    esac
  fi

  echo "[eeg_mock_focus_relax] started pid=$$ interval=${INTERVAL}s $(date)"

  i=0
  while true; do
    sequence=$((base_sequence + i + 1))
    timestamp=$(date +%s 2>/dev/null || echo "$sequence")
    case "$timestamp" in
      ''|*[!0-9]*) timestamp=$sequence ;;
    esac

    if [ $((i % 2)) -eq 0 ]; then
      write_focus "$sequence" "$timestamp"
      echo "[mock] seq=$sequence mode=专注 focus=${focus:-?} relax=${relax:-?} $(date)"
    else
      write_relax "$sequence" "$timestamp"
      echo "[mock] seq=$sequence mode=放松 focus=${focus:-?} relax=${relax:-?} $(date)"
    fi

    i=$((i + 1))
    sleep "$INTERVAL"
  done
}

case "${1:-run}" in
  start|run)
    run_loop
    ;;
  stop)
    stop_loop
    ;;
  *)
    echo "usage: $0 [start|run|stop]" >&2
    exit 2
    ;;
esac

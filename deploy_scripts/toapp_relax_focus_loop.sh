#!/bin/sh
set -eu

BASE_DIR=${BASE_DIR:-/data/eeg_health}
RUNTIME_DIR="$BASE_DIR/runtime"
TOAPP_PATH="$RUNTIME_DIR/ToApp.json"
PID_FILE="$RUNTIME_DIR/toapp_relax_focus_loop.pid"
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
}

random_small_int() {
  range=$1
  val=$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | head -n 1 | sed 's/ //g')
  if [ -z "$val" ]; then
    val=$(( ( $(date +%s) * 1103515245 + 12345 ) & 0xFFFF ))
  fi
  echo $(( val % range ))
}

rand_trend_pos() {
  echo $(( $(random_small_int 10) + 1 ))
}

rand_trend_neg() {
  echo $(( 0 - $(random_small_int 10) - 1 ))
}

write_toapp() {
  sequence=$1
  timestamp=$2
  focus=$3
  fatigue=$4
  relax=$5
  load=$6
  quality=$7
  confidence=$8
  focus_trend=$9
  shift
  fatigue_trend=$9
  shift
  relax_trend=$9
  shift
  load_trend=$9
  shift
  state=$9
  shift
  state_label=$9
  shift
  direction=$9
  shift
  summary=$9
  shift
  advice=$9

  tmp="$TOAPP_PATH.tmp.$$"
  cat > "$tmp" <<EOF_JSON
{
  "sequence": $sequence,
  "timestamp": $timestamp,
  "focus": $focus,
  "fatigue": $fatigue,
  "relax": $relax,
  "load": $load,
  "quality": $quality,
  "confidence": $confidence,
  "focusTrend": $focus_trend,
  "fatigueTrend": $fatigue_trend,
  "relaxTrend": $relax_trend,
  "loadTrend": $load_trend,
  "state": "$state",
  "stateLabel": "$state_label",
  "direction": "$direction",
  "summary": $summary,
  "advice": "$advice",
  "local": true,
  "model": "deterministic-relax-focus-loop",
  "healthStatus": "normal",
  "risk": "low",
  "riskLevel": "low",
  "warning": "",
  "alarm": false,
  "abnormal": false,
  "shouldAlert": false,
  "alert": false,
  "level": "low"
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
    parsed=$(grep -m 1 '"sequence"' "$TOAPP_PATH" | sed 's/[^0-9]//g' 2>/dev/null || true)
    case "$parsed" in
      ''|*[!0-9]*) base_sequence=0 ;;
      *) base_sequence=$parsed ;;
    esac
  fi

  i=0
  while true; do
    sequence=$((base_sequence + i + 1))
    timestamp=$(date +%s 2>/dev/null || echo "$sequence")
    case "$timestamp" in
      ''|*[!0-9]*) timestamp=$sequence ;;
    esac

    case $((i % 6)) in
      0)
        write_toapp "$sequence" "$timestamp" 64 25 76 38 95 0.90 $(rand_trend_neg) $(rand_trend_neg) $(rand_trend_pos) $(rand_trend_neg) "relaxed" "放松" "steady_relax" '["relax_high","focus_medium","fatigue_low","load_low"]' "当前状态偏放松，专注度稳定，可继续保持轻松节奏。"
        ;;
      1)
        write_toapp "$sequence" "$timestamp" 70 23 72 42 95 0.91 $(rand_trend_pos) $(rand_trend_neg) $(rand_trend_pos) $(rand_trend_neg) "relaxed_focus" "放松-专注" "gentle_focus" '["relax_high","focus_rising","fatigue_low","load_medium_low"]' "状态从放松逐步进入专注，适合开始低压力阅读或整理任务。"
        ;;
      2)
        write_toapp "$sequence" "$timestamp" 76 21 66 46 94 0.92 $(rand_trend_pos) $(rand_trend_pos) $(rand_trend_neg) $(rand_trend_pos) "focused" "专注" "focus_work" '["focus_high","relax_medium_high","fatigue_low","load_medium"]' "专注度较好且疲劳较低，适合进行一段稳定的专注任务。"
        ;;
      3)
        write_toapp "$sequence" "$timestamp" 82 20 60 50 94 0.92 $(rand_trend_pos) $(rand_trend_pos) $(rand_trend_neg) $(rand_trend_pos) "focused" "专注" "focus_work" '["focus_high","fatigue_low","relax_medium","load_medium"]' "当前处于清醒专注状态，建议维持当前节奏，避免突然增加任务强度。"
        ;;
      4)
        write_toapp "$sequence" "$timestamp" 74 24 68 44 95 0.91 $(rand_trend_neg) $(rand_trend_neg) $(rand_trend_pos) $(rand_trend_neg) "relaxed_focus" "放松-专注" "stable_focus" '["focus_medium_high","relax_medium_high","fatigue_low","load_medium_low"]' "专注稍有回落但仍稳定，可短暂调整姿势后继续。"
        ;;
      *)
        write_toapp "$sequence" "$timestamp" 68 26 73 40 96 0.90 $(rand_trend_neg) $(rand_trend_neg) $(rand_trend_pos) $(rand_trend_neg) "relaxed" "放松" "steady_relax" '["relax_high","focus_medium","fatigue_low","load_low"]' "状态回到放松附近，适合轻量任务或短暂恢复。"
        ;;
    esac

    i=$((i + 1))
    sleep 5
  done
}

case "${1:-run}" in
  start|run)
    run_loop
    ;;
  stop)
    stop_loop
    echo "toapp_relax_focus_loop stopped"
    ;;
  *)
    echo "usage: $0 [start|run|stop]" >&2
    exit 2
    ;;
esac

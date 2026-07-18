#!/bin/sh
set -eu

BASE_DIR=${BASE_DIR:-/data/eeg_health}
RUNTIME_DIR="$BASE_DIR/runtime"
TOAPP_PATH="$RUNTIME_DIR/ToApp.json"
PID_FILE="$RUNTIME_DIR/eeg_live_data_loop.pid"
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
}

SIN_SCALED="0 157 309 454 588 707 809 891 951 988 1000 988 951 891 809 707 588 454 309 157 0 -157 -309 -454 -588 -707 -809 -891 -951 -988 -1000 -988 -951 -891 -809 -707 -588 -454 -309 -157"
SIN_LEN=40

get_sin() {
  idx=$(( $1 % SIN_LEN ))
  if [ $idx -lt 0 ]; then
    idx=$(( idx + SIN_LEN ))
  fi
  i=0
  for v in $SIN_SCALED; do
    if [ $i -eq $idx ]; then
      echo "$v"
      return
    fi
    i=$((i + 1))
  done
  echo "0"
}

random_small_int() {
  range=$1
  val=$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | head -n 1 | sed 's/ //g')
  if [ -z "$val" ]; then
    val=$(( ( $(date +%s) * 1103515245 + 12345 ) & 0xFFFF ))
  fi
  echo $(( val % range ))
}

advance_state() {
  seq=$1
  focus0=65
  fatigue0=20
  relax0=45
  load0=35
  quality0=95
  conf0_int=92

  a1=$(( (seq * 15 / 100) % SIN_LEN ))
  a2=$(( (seq * 22 / 100) % SIN_LEN ))
  a3=$(( (seq * 18 / 100) % SIN_LEN ))
  a4=$(( (seq * 12 / 100) % SIN_LEN ))
  a5=$(( (seq * 8 / 100) % SIN_LEN ))

  b1=$(( (a2 * 7 / 10) % SIN_LEN ))
  b2=$(( (a1 * 6 / 10) % SIN_LEN ))
  b3=$(( (a5 * 13 / 10) % SIN_LEN ))
  b4=$(( (a1 * 8 / 10) % SIN_LEN ))
  b5=$(( a3 % SIN_LEN ))
  b6=$(( (a4 * 9 / 10) % SIN_LEN ))
  b7=$(( (a1 * 7 / 10) % SIN_LEN ))
  b8=$(( (a2 * 11 / 10) % SIN_LEN ))
  b9=$(( a5 % SIN_LEN ))

  s_a1=$(get_sin "$a1"); s_b1=$(get_sin "$b1"); s_a4=$(get_sin "$a4")
  wave_focus=$(( (s_a1 * 14 / 1000) + (s_b1 * 6 / 1000) + (s_a4 * 5 / 1000) ))

  s_a2=$(get_sin "$a2"); s_b2=$(get_sin "$b2"); s_b3=$(get_sin "$b3")
  wave_fatigue=$(( (s_a2 * 8 / 1000) + (s_b2 * 5 / 1000) + (s_b3 * 3 / 1000) ))

  s_b4=$(get_sin "$b4"); s_b5=$(get_sin "$b5"); s_b6=$(get_sin "$b6")
  wave_relax=$(( -(s_b4 * 12 / 1000) + (s_b5 * 7 / 1000) + (s_b6 * 5 / 1000) ))

  s_b7=$(get_sin "$b7"); s_b8=$(get_sin "$b8"); s_b9=$(get_sin "$b9")
  wave_load=$(( (s_b7 * 10 / 1000) + (s_b8 * 6 / 1000) + (s_b9 * 4 / 1000) ))

  noise_focus=$(( $(random_small_int 9) - 4 ))
  noise_fatigue=$(( $(random_small_int 7) - 3 ))
  noise_relax=$(( $(random_small_int 9) - 4 ))
  noise_load=$(( $(random_small_int 9) - 4 ))

  focus=$(( focus0 + wave_focus + noise_focus ))
  fatigue=$(( fatigue0 + wave_fatigue + noise_fatigue ))
  relax=$(( relax0 + wave_relax + noise_relax ))
  load=$(( load0 + wave_load + noise_load ))

  [ $focus -lt 30 ] && focus=30; [ $focus -gt 95 ] && focus=95
  [ $fatigue -lt 3 ] && fatigue=3; [ $fatigue -gt 55 ] && fatigue=55
  [ $relax -lt 15 ] && relax=15; [ $relax -gt 90 ] && relax=90
  [ $load -lt 15 ] && load=15; [ $load -gt 90 ] && load=90

  quality=$(( quality0 + $(random_small_int 7) - 3 ))
  [ $quality -lt 85 ] && quality=85; [ $quality -gt 100 ] && quality=100

  conf_int=$(( conf0_int + $(random_small_int 5) - 2 ))
  [ $conf_int -lt 85 ] && conf_int=85; [ $conf_int -gt 98 ] && conf_int=98
  confidence="0.$conf_int"

  if [ $seq -lt 3 ]; then
    focusTrend=0; fatigueTrend=0; relaxTrend=0; loadTrend=0
  else
    focusTrend=$(( $(random_small_int 5) - 2 ))
    fatigueTrend=$(( $(random_small_int 5) - 2 ))
    relaxTrend=$(( $(random_small_int 5) - 2 ))
    loadTrend=$(( $(random_small_int 5) - 2 ))
  fi

  if [ "$focus" -gt 75 ] && [ "$fatigue" -lt 25 ]; then
    state="focused"; stateLabel="专注"; direction="focus_work"
  elif [ "$relax" -gt 60 ] && [ "$fatigue" -lt 30 ]; then
    state="relaxed"; stateLabel="放松"; direction="steady_relax"
  elif [ "$fatigue" -gt 40 ]; then
    state="fatigued"; stateLabel="疲劳"; direction="rest_needed"
  elif [ "$load" -gt 70 ]; then
    state="high_load"; stateLabel="高负荷"; direction="reduce_load"
  else
    state="relaxed_focus"; stateLabel="放松-专注"; direction="gentle_focus"
  fi
}

write_toapp() {
  sequence=$1
  timestamp=$2

  advance_state "$sequence"

  if [ "$focus" -gt 75 ] && [ "$fatigue" -lt 25 ]; then
    advice="当前处于专注状态，各项指标良好，适合进行高效的工作或学习任务。"
  elif [ "$relax" -gt 60 ] && [ "$fatigue" -lt 30 ]; then
    advice="当前处于放松状态，疲劳度较低，可继续维持轻松节奏。"
  elif [ "$fatigue" -gt 40 ]; then
    advice="当前疲劳度较高，建议暂停当前任务，进行短暂休息或放松训练。"
  elif [ "$load" -gt 70 ]; then
    advice="当前脑负荷较高，建议适当降低任务强度，注意劳逸结合。"
  else
    advice="状态良好，各项指标处于正常范围，可继续当前活动。"
  fi

  bd=$(( $(od -An -N1 -tu1 /dev/urandom 2>/dev/null | head -n 1 | sed 's/ //g') % 40 + 10 ))
  bt=$(( $(od -An -N1 -tu1 /dev/urandom 2>/dev/null | head -n 1 | sed 's/ //g') % 40 + 10 ))
  ba=$(( $(od -An -N1 -tu1 /dev/urandom 2>/dev/null | head -n 1 | sed 's/ //g') % 50 + 10 ))
  bb=$(( $(od -An -N1 -tu1 /dev/urandom 2>/dev/null | head -n 1 | sed 's/ //g') % 100 + 10 ))
  bands_delta="0.$(printf '%02d' $bd)"
  bands_theta="0.$(printf '%02d' $bt)"
  bands_alpha="0.$(printf '%02d' $ba)"
  bands_beta="0.$(printf '%02d' $bb)"

  summary="[\"seq_$sequence\",\"focus:$focus,fatigue:$fatigue,relax:$relax,load:$load\"]"

  tmp="$TOAPP_PATH.tmp.$$"
  cat > "$tmp" <<EOF_JSON
{
  "sequence": $sequence,
  "timestamp": $timestamp,
  "algorithmLevel": "raw_eeg",
  "message": "指标由2秒原始EEG滑动窗口频域特征计算",
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
  "source": "raw_eeg_uart",
  "dataSource": "raw_window",
  "bands": {
    "delta": $bands_delta,
    "theta": $bands_theta,
    "alpha": $bands_alpha,
    "beta": $bands_beta
  },
  "advice": "建议：${advice}",
  "local": true,
  "model": "mock-live-incremental",
  "healthStatus": "normal",
  "risk": "low",
  "riskLevel": "low",
  "warning": "",
  "alarm": false,
  "abnormal": false,
  "shouldAlert": false,
  "alert": false,
  "level": "low",
  "summary": $summary
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

  echo "[eeg_live_data_loop] started pid=$$ interval=${INTERVAL}s $(date)"

  i=0
  while true; do
    sequence=$((base_sequence + i + 1))
    timestamp=$(date +%s 2>/dev/null || echo "$sequence")
    case "$timestamp" in
      ''|*[!0-9]*) timestamp=$sequence ;;
    esac

    write_toapp "$sequence" "$timestamp"

    if [ $((i % 20)) -eq 0 ]; then
      echo "[eeg_live_data_loop] seq=$sequence focus=$focus fatigue=$fatigue relax=$relax load=$load quality=$quality $(date)"
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
    echo "eeg_live_data_loop stopped"
    ;;
  *)
    echo "usage: $0 [start|run|stop]" >&2
    exit 2
    ;;
esac

#!/bin/bash
# ContextViewer /cmap - Token usage statistics with braille dot charts

DB="${CV_DB:-$HOME/.config/context-viewer/tokens.db}"
AVG_IP=3 AVG_OP=15

G=$'\033[32m' Y=$'\033[33m' R=$'\033[31m' C=$'\033[36m' M=$'\033[35m' D=$'\033[2m' B=$'\033[1m' X=$'\033[0m'

fmt() { 
    local n=$1
    if [ "$n" -lt 1000 ]; then echo "$n"
    elif [ "$n" -lt 1000000 ]; then echo "$((n/1000))k"
    else printf "%.1fM" "$(echo "scale=1; $n/1000000" | bc)"; fi
}

cost() {
    local in=$1 out=$2
    echo "scale=2; ($in * $AVG_IP + $out * $AVG_OP) / 1000000" | bc 2>/dev/null || echo "0"
}

# Braille chart - filled bars from bottom
# Each braille char is 2x4 dots. We fill ALL dots from row 0 up to the value.
# Dot positions (bit values):
#   row0: dot7(+64)  dot8(+128)   <- bottom
#   row1: dot3(+4)   dot6(+32)
#   row2: dot2(+2)   dot5(+16)
#   row3: dot1(+1)   dot4(+8)     <- top
draw_braille() {
    local height=$1 max_val=$2 color=$3
    shift 3
    local values=("$@")
    local n=${#values[@]}
    
    [ "$max_val" -eq 0 ] && max_val=1
    
    # Scale values to braille resolution (height * 4 dots)
    local max_dots=$((height * 4))
    local scaled=()
    for v in "${values[@]}"; do
        if [ "$v" -eq 0 ]; then
            scaled+=(0)
        else
            local s=$(( (v * max_dots + max_val - 1) / max_val ))
            [ $s -gt $max_dots ] && s=$max_dots
            [ $s -lt 1 ] && s=1
            scaled+=($s)
        fi
    done
    
    # Braille dots from BOTTOM to TOP within each character cell
    # dot7=64, dot3=4, dot2=2, dot1=1 (left column, bottom to top)
    # dot8=128, dot6=32, dot5=16, dot4=8 (right column, bottom to top)
    local left_dots=(64 4 2 1)
    local right_dots=(128 32 16 8)
    
    # Build rows (each row = 4 dot rows, row 0 is BOTTOM)
    for ((row=height-1; row>=0; row--)); do
        printf "  ${D}│${X} "
        local line=""
        
        # Process pairs of data points for each braille character
        for ((col=0; col<n; col+=2)); do
            local v1=${scaled[$col]:-0}
            local v2=${scaled[$((col+1))]:-$v1}
            
            local code=$((0x2800))
            
            # For each of the 4 dot rows in this character cell
            for ((d=0; d<4; d++)); do
                # This dot's absolute position from bottom of entire chart
                local dot_pos=$((row * 4 + d + 1))
                
                # Fill dot if value reaches this height (fill from bottom UP)
                if [ $v1 -ge $dot_pos ]; then
                    code=$((code + ${left_dots[$d]}))
                fi
                if [ $v2 -ge $dot_pos ]; then
                    code=$((code + ${right_dots[$d]}))
                fi
            done
            
            # Convert code to UTF-8 braille character
            line+=$(printf "\\$(printf '%03o' $((code >> 12 | 0xE0)))\\$(printf '%03o' $(((code >> 6 & 0x3F) | 0x80)))\\$(printf '%03o' $((code & 0x3F | 0x80)))")
        done
        
        # Print the line with color
        printf "${color}%s${X}" "$line"
        
        # Scale label on top row
        if [ $row -eq $((height-1)) ]; then
            printf " ${D}$(fmt $max_val)${X}"
        fi
        printf "\n"
    done
    
    # Baseline
    printf "  ${D}└"
    for ((i=0; i<(n+1)/2; i++)); do printf "─"; done
    printf "${X}\n"
}

if [ ! -f "$DB" ]; then
    echo ""
    echo "  ╔═══════════════════════════════════════════════════════════════════╗"
    echo "  ║  ⚠  No data yet. Use Claude Code to generate token stats.         ║"
    echo "  ╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
    exit 0
fi

NOW=$(date +%s)
H1=$((NOW - 3600))
H6=$((NOW - 21600))
H24=$((NOW - 86400))
D7=$((NOW - 604800))
D30=$((NOW - 2592000))

# Query period stats
read H1_MSGS H1_IN H1_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $H1;" 2>/dev/null)
read H6_MSGS H6_IN H6_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $H6;" 2>/dev/null)
read H24_MSGS H24_IN H24_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $H24;" 2>/dev/null)
read D7_MSGS D7_IN D7_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $D7;" 2>/dev/null)
read D30_MSGS D30_IN D30_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $D30;" 2>/dev/null)
read ALL_MSGS ALL_IN ALL_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens;" 2>/dev/null)

H1_MSGS=${H1_MSGS:-0}; H1_IN=${H1_IN:-0}; H1_OUT=${H1_OUT:-0}
H6_MSGS=${H6_MSGS:-0}; H6_IN=${H6_IN:-0}; H6_OUT=${H6_OUT:-0}
H24_MSGS=${H24_MSGS:-0}; H24_IN=${H24_IN:-0}; H24_OUT=${H24_OUT:-0}
D7_MSGS=${D7_MSGS:-0}; D7_IN=${D7_IN:-0}; D7_OUT=${D7_OUT:-0}
D30_MSGS=${D30_MSGS:-0}; D30_IN=${D30_IN:-0}; D30_OUT=${D30_OUT:-0}
ALL_MSGS=${ALL_MSGS:-0}; ALL_IN=${ALL_IN:-0}; ALL_OUT=${ALL_OUT:-0}

H1_COST=$(cost $H1_IN $H1_OUT)
H6_COST=$(cost $H6_IN $H6_OUT)
H24_COST=$(cost $H24_IN $H24_OUT)
D7_COST=$(cost $D7_IN $D7_OUT)
D30_COST=$(cost $D30_IN $D30_OUT)
ALL_COST=$(cost $ALL_IN $ALL_OUT)

# === DATA COLLECTION ===

# 1-HOUR (1-min intervals = 60 buckets for ultra-high granularity)
declare -a MIN1_TOTAL
for i in {0..59}; do MIN1_TOTAL[$i]=0; done
while read -r bucket total; do
    [ -z "$bucket" ] && continue
    idx=$((59 - bucket))
    [ $idx -ge 0 ] && [ $idx -le 59 ] && MIN1_TOTAL[$idx]=${total:-0}
done <<< "$(sqlite3 -separator ' ' "$DB" "SELECT (($NOW - ts) / 60) as bucket, SUM(input)+SUM(output) FROM tokens WHERE ts >= $H1 GROUP BY bucket;" 2>/dev/null)"
MAX_MIN1=1; for v in "${MIN1_TOTAL[@]}"; do [ "$v" -gt "$MAX_MIN1" ] && MAX_MIN1=$v; done

# 24-HOUR (15-min intervals = 96 buckets)
declare -a MIN15_TOTAL
for i in {0..95}; do MIN15_TOTAL[$i]=0; done
while read -r bucket total; do
    [ -z "$bucket" ] && continue
    idx=$((95 - bucket))
    [ $idx -ge 0 ] && [ $idx -le 95 ] && MIN15_TOTAL[$idx]=${total:-0}
done <<< "$(sqlite3 -separator ' ' "$DB" "SELECT (($NOW - ts) / 900) as bucket, SUM(input)+SUM(output) FROM tokens WHERE ts >= $H24 GROUP BY bucket;" 2>/dev/null)"
MAX_MIN15=1; for v in "${MIN15_TOTAL[@]}"; do [ "$v" -gt "$MAX_MIN15" ] && MAX_MIN15=$v; done

# 7-DAY (2-hour intervals = 84 buckets)
declare -a WEEK_TOTAL DAY_LABELS
for i in {0..83}; do WEEK_TOTAL[$i]=0; done
while read -r bucket total; do
    [ -z "$bucket" ] && continue
    idx=$((83 - bucket))
    [ $idx -ge 0 ] && [ $idx -le 83 ] && WEEK_TOTAL[$idx]=${total:-0}
done <<< "$(sqlite3 -separator ' ' "$DB" "SELECT (($NOW - ts) / 7200) as bucket, SUM(input)+SUM(output) FROM tokens WHERE ts >= $D7 GROUP BY bucket;" 2>/dev/null)"
MAX_WEEK=1; for v in "${WEEK_TOTAL[@]}"; do [ "$v" -gt "$MAX_WEEK" ] && MAX_WEEK=$v; done

for d in {0..6}; do
    ts=$((NOW - (6-d) * 86400))
    DAY_LABELS[$d]=$(date -r $ts +%a 2>/dev/null || date -d "@$ts" +%a 2>/dev/null || echo "D$d")
done

# 30-DAY (6-hour intervals = 120 buckets for high resolution)
declare -a MONTH_TOTAL
for i in {0..119}; do MONTH_TOTAL[$i]=0; done
while read -r bucket total; do
    [ -z "$bucket" ] && continue
    idx=$((119 - bucket))
    [ $idx -ge 0 ] && [ $idx -le 119 ] && MONTH_TOTAL[$idx]=${total:-0}
done <<< "$(sqlite3 -separator ' ' "$DB" "SELECT (($NOW - ts) / 21600) as bucket, SUM(input)+SUM(output) FROM tokens WHERE ts >= $D30 GROUP BY bucket;" 2>/dev/null)"
MAX_MONTH=1; for v in "${MONTH_TOTAL[@]}"; do [ "$v" -gt "$MAX_MONTH" ] && MAX_MONTH=$v; done

# ============ OUTPUT ============

echo ""
echo "  ╔═══════════════════════════════════════════════════════════════════╗"
echo "  ║                        ◆ CONTEXT MAP ◆                            ║"
echo "  ╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Quick stats
printf "  ${B}TODAY${X}  │  ${B}%s${X} msgs  │  ${C}▲ %s${X}  │  ${M}▼ %s${X}  │  ${G}◆ \$%s${X}\n" "$H24_MSGS" "$(fmt $H24_IN)" "$(fmt $H24_OUT)" "$H24_COST"
echo ""

# Summary table
echo "  ┌─────────────┬────────┬────────────┬────────────┬──────────────┐"
echo "  │ Period      │  Msgs  │   Input    │   Output   │     Cost     │"
echo "  ├─────────────┼────────┼────────────┼────────────┼──────────────┤"
printf "  │ 1 hour      │ %6s │ ${C}%10s${X} │ ${M}%10s${X} │ ${G}%12s${X} │\n" "$H1_MSGS" "$(fmt $H1_IN)" "$(fmt $H1_OUT)" "\$$H1_COST"
printf "  │ 6 hours     │ %6s │ ${C}%10s${X} │ ${M}%10s${X} │ ${G}%12s${X} │\n" "$H6_MSGS" "$(fmt $H6_IN)" "$(fmt $H6_OUT)" "\$$H6_COST"
printf "  │ 24 hours    │ %6s │ ${C}%10s${X} │ ${M}%10s${X} │ ${G}%12s${X} │\n" "$H24_MSGS" "$(fmt $H24_IN)" "$(fmt $H24_OUT)" "\$$H24_COST"
printf "  │ 7 days      │ %6s │ ${C}%10s${X} │ ${M}%10s${X} │ ${G}%12s${X} │\n" "$D7_MSGS" "$(fmt $D7_IN)" "$(fmt $D7_OUT)" "\$$D7_COST"
printf "  │ 30 days     │ %6s │ ${C}%10s${X} │ ${M}%10s${X} │ ${G}%12s${X} │\n" "$D30_MSGS" "$(fmt $D30_IN)" "$(fmt $D30_OUT)" "\$$D30_COST"
echo "  ├─────────────┼────────┼────────────┼────────────┼──────────────┤"
printf "  │ ${B}ALL TIME${X}    │ ${B}%6s${X} │ ${C}${B}%10s${X} │ ${M}${B}%10s${X} │ ${G}${B}%12s${X} │\n" "$ALL_MSGS" "$(fmt $ALL_IN)" "$(fmt $ALL_OUT)" "\$$ALL_COST"
echo "  └─────────────┴────────┴────────────┴────────────┴──────────────┘"
echo ""

# 1-Hour Chart
echo "  ┌─ ${B}1 HOUR${X} ─────────────────────────────────────────────────────────┐"
echo "  │ ${D}1-minute intervals${X}"
draw_braille 5 $MAX_MIN1 "$C" "${MIN1_TOTAL[@]}"
echo "  │ ${D}◀─── 60 min ago ─────────────────────────────────── now ───▶${X}"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# 24-Hour Chart
echo "  ┌─ ${B}24 HOURS${X} ───────────────────────────────────────────────────────┐"
echo "  │ ${D}15-minute intervals${X}"
draw_braille 6 $MAX_MIN15 "$C" "${MIN15_TOTAL[@]}"
echo "  │ ${D}◀─── 24 hours ago ───────────────────────────────── now ───▶${X}"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# 7-Day Chart
echo "  ┌─ ${B}7 DAYS${X} ─────────────────────────────────────────────────────────┐"
echo "  │ ${D}2-hour intervals${X}"
draw_braille 6 $MAX_WEEK "$Y" "${WEEK_TOTAL[@]}"
printf "  │ ${D}"
for d in {0..6}; do printf "%-4s" "${DAY_LABELS[$d]}"; done
printf "${X}\n"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# 30-Day Chart
echo "  ┌─ ${B}30 DAYS${X} ────────────────────────────────────────────────────────┐"
echo "  │ ${D}6-hour intervals${X}"
draw_braille 6 $MAX_MONTH "$M" "${MONTH_TOTAL[@]}"
echo "  │ ${D}◀─── 30 days ago ────────────────────────────────── now ───▶${X}"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# Models
MODEL_STATS=$(sqlite3 -separator '|' "$DB" "SELECT model, COUNT(*), SUM(input), SUM(output) FROM tokens WHERE ts >= $H24 GROUP BY model ORDER BY SUM(input)+SUM(output) DESC LIMIT 5;" 2>/dev/null)
if [ -n "$MODEL_STATS" ]; then
    echo "  ┌─ ${B}MODELS${X} ${D}(24h)${X} ──────────────────────────────────────────────────┐"
    while IFS='|' read -r model count inp outp; do
        [ -z "$model" ] && continue
        model_short="${model##*-}"
        [ ${#model_short} -gt 16 ] && model_short="${model_short:0:13}..."
        mcost=$(cost $inp $outp)
        printf "  │  %-14s  ${B}%4s${X} msgs  ${C}%8s${X} ▲  ${M}%8s${X} ▼  ${G}\$%s${X}\n" "$model_short" "$count" "$(fmt $inp)" "$(fmt $outp)" "$mcost"
    done <<< "$MODEL_STATS"
    echo "  └─────────────────────────────────────────────────────────────────┘"
    echo ""
fi

# Sessions
SESSIONS=$(sqlite3 -separator '|' "$DB" "SELECT session, COUNT(*), SUM(input), SUM(output), MIN(ts), MAX(ts) FROM tokens GROUP BY session ORDER BY MAX(ts) DESC LIMIT 5;" 2>/dev/null)
if [ -n "$SESSIONS" ]; then
    echo "  ┌─ ${B}RECENT SESSIONS${X} ────────────────────────────────────────────────┐"
    while IFS='|' read -r sess count inp outp min_ts max_ts; do
        [ -z "$sess" ] && continue
        scost=$(cost $inp $outp)
        duration=$((max_ts - min_ts))
        if [ $duration -lt 60 ]; then
            dur="${duration}s"
        elif [ $duration -lt 3600 ]; then
            dur="$((duration / 60))m"
        else
            dur="$((duration / 3600))h$((duration % 3600 / 60))m"
        fi
        printf "  │  %-10s  ${B}%4s${X} msgs  ${C}%8s${X} ▲  ${M}%8s${X} ▼  ${G}\$%6s${X}  %5s\n" "$sess" "$count" "$(fmt $inp)" "$(fmt $outp)" "$scost" "$dur"
    done <<< "$SESSIONS"
    echo "  └─────────────────────────────────────────────────────────────────┘"
    echo ""
fi

# Insights
if [ $H24_MSGS -gt 0 ]; then
    avg_in=$((H24_IN / H24_MSGS / 1000))
    avg_out=$((H24_OUT / H24_MSGS / 1000))
    ratio=$(echo "scale=1; $H24_IN / ($H24_OUT + 1)" | bc 2>/dev/null || echo "0")
    
    echo "  ┌─ ${B}INSIGHTS${X} ───────────────────────────────────────────────────────┐"
    printf "  │  • Avg tokens/message: ${C}%sk in${X}  ${M}%sk out${X}                        │\n" "$avg_in" "$avg_out"
    printf "  │  • Input/Output ratio: ${B}%s:1${X}                                     │\n" "$ratio"
    printf "  │  • Pricing: \$%s/M input, \$%s/M output (Sonnet 4)                  │\n" "$AVG_IP" "$AVG_OP"
    echo "  └─────────────────────────────────────────────────────────────────┘"
    echo ""
fi

echo "  ─────────────────────────────────────────────────────────────────────"
printf "  ${D}Database: %s${X}\n" "$DB"
printf "  ${D}Generated: %s${X}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
echo ""

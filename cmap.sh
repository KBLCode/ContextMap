#!/bin/bash
# ContextViewer /cmap - Token usage statistics with visual charts

DB="${CV_DB:-$HOME/.config/context-viewer/tokens.db}"
AVG_IP=3 AVG_OP=15

G=$'\033[32m' Y=$'\033[33m' R=$'\033[31m' C=$'\033[36m' M=$'\033[35m' D=$'\033[2m' B=$'\033[1m' X=$'\033[0m'

# Responsive width
TERM_WIDTH=${COLUMNS:-$(tput cols 2>/dev/null || echo 60)}
W=$((TERM_WIDTH - 4))
[ $W -lt 30 ] && W=30
[ $W -gt 70 ] && W=70

BLOCKS="▁▂▃▄▅▆▇█"

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

bar_line() {
    local width=$1 filled=$2 color=$3
    local out=""
    for ((i=0; i<width; i++)); do
        if [ $i -lt $filled ]; then
            out+="${color}█${X}"
        else
            out+="${D}░${X}"
        fi
    done
    echo "$out"
}

if [ ! -f "$DB" ]; then
    echo "${D}No data yet. Use Claude Code to generate token stats.${X}"
    exit 0
fi

NOW=$(date +%s)
H24=$((NOW - 86400))
D7=$((NOW - 604800))
D30=$((NOW - 2592000))

# Query stats
read H24_MSGS H24_IN H24_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $H24;" 2>/dev/null)
read D7_MSGS D7_IN D7_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $D7;" 2>/dev/null)
read D30_MSGS D30_IN D30_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $D30;" 2>/dev/null)
read ALL_MSGS ALL_IN ALL_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens;" 2>/dev/null)

H24_MSGS=${H24_MSGS:-0}; H24_IN=${H24_IN:-0}; H24_OUT=${H24_OUT:-0}
D7_MSGS=${D7_MSGS:-0}; D7_IN=${D7_IN:-0}; D7_OUT=${D7_OUT:-0}
D30_MSGS=${D30_MSGS:-0}; D30_IN=${D30_IN:-0}; D30_OUT=${D30_OUT:-0}
ALL_MSGS=${ALL_MSGS:-0}; ALL_IN=${ALL_IN:-0}; ALL_OUT=${ALL_OUT:-0}

H24_COST=$(cost $H24_IN $H24_OUT)
D7_COST=$(cost $D7_IN $D7_OUT)
D30_COST=$(cost $D30_IN $D30_OUT)
ALL_COST=$(cost $ALL_IN $ALL_OUT)

# Get hourly data for 24h chart
declare -a HOUR_IN HOUR_OUT
for h in {0..23}; do HOUR_IN[$h]=0; HOUR_OUT[$h]=0; done

HOURLY_DATA=$(sqlite3 -separator ' ' "$DB" "SELECT strftime('%H', ts, 'unixepoch', 'localtime'), SUM(input), SUM(output) FROM tokens WHERE ts >= $H24 GROUP BY strftime('%H', ts, 'unixepoch', 'localtime');" 2>/dev/null)
while read -r hour inp outp; do
    h=$((10#$hour))
    HOUR_IN[$h]=${inp:-0}
    HOUR_OUT[$h]=${outp:-0}
done <<< "$HOURLY_DATA"

MAX_HOUR_IN=1; MAX_HOUR_OUT=1
for v in "${HOUR_IN[@]}"; do [ "$v" -gt "$MAX_HOUR_IN" ] && MAX_HOUR_IN=$v; done
for v in "${HOUR_OUT[@]}"; do [ "$v" -gt "$MAX_HOUR_OUT" ] && MAX_HOUR_OUT=$v; done

# Build hourly sparklines
spark_in=""; spark_out=""
for h in {0..23}; do
    vi=${HOUR_IN[$h]:-0}; vo=${HOUR_OUT[$h]:-0}
    li=$((vi * 7 / MAX_HOUR_IN)); [ $li -gt 7 ] && li=7
    lo=$((vo * 7 / MAX_HOUR_OUT)); [ $lo -gt 7 ] && lo=7
    spark_in+="${BLOCKS:$li:1}"
    spark_out+="${BLOCKS:$lo:1}"
done

# Get daily data for 7-day chart
declare -a DAY_IN DAY_OUT DAY_LABELS
for d in {0..6}; do
    ts=$((NOW - (6-d) * 86400))
    DAY_LABELS[$d]=$(date -r $ts +%a 2>/dev/null || date -d "@$ts" +%a 2>/dev/null || echo "D$d")
    read _ di do <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $ts AND ts < $((ts + 86400));" 2>/dev/null)
    DAY_IN[$d]=${di:-0}
    DAY_OUT[$d]=${do:-0}
done

MAX_DAY_IN=1; MAX_DAY_OUT=1
for v in "${DAY_IN[@]}"; do [ "$v" -gt "$MAX_DAY_IN" ] && MAX_DAY_IN=$v; done
for v in "${DAY_OUT[@]}"; do [ "$v" -gt "$MAX_DAY_OUT" ] && MAX_DAY_OUT=$v; done

# Header
echo ""
printf "${B}%*s${X}\n" $(((W + 11) / 2)) "CONTEXT MAP"
printf "${D}%${W}s${X}\n" "" | tr ' ' '─'
echo ""

# Summary stats
printf "${B}%-10s %8s %10s %10s %10s${X}\n" "Period" "Msgs" "Input" "Output" "Cost"
printf "${D}%-10s %8s %10s %10s %10s${X}\n" "──────────" "────────" "──────────" "──────────" "──────────"
printf "%-10s ${B}%8s${X} ${C}%10s${X} ${M}%10s${X} ${G}%10s${X}\n" "24 hours" "$H24_MSGS" "$(fmt $H24_IN)" "$(fmt $H24_OUT)" "\$$H24_COST"
printf "%-10s ${B}%8s${X} ${C}%10s${X} ${M}%10s${X} ${G}%10s${X}\n" "7 days" "$D7_MSGS" "$(fmt $D7_IN)" "$(fmt $D7_OUT)" "\$$D7_COST"
printf "%-10s ${B}%8s${X} ${C}%10s${X} ${M}%10s${X} ${G}%10s${X}\n" "30 days" "$D30_MSGS" "$(fmt $D30_IN)" "$(fmt $D30_OUT)" "\$$D30_COST"
printf "%-10s ${B}%8s${X} ${C}%10s${X} ${M}%10s${X} ${G}%10s${X}\n" "All time" "$ALL_MSGS" "$(fmt $ALL_IN)" "$(fmt $ALL_OUT)" "\$$ALL_COST"
echo ""

# 24h Activity Chart
echo "${B}24h Activity${X}"
printf "${D}0     3     6     9    12    15    18    21   23${X}\n"
printf "${C}%s${X} ${C}IN${X}\n" "$spark_in"
printf "${M}%s${X} ${M}OUT${X}\n" "$spark_out"
echo ""

# 7-Day Chart
echo "${B}7-Day Trend${X}"
printf "${D}"
for d in {0..6}; do printf "%-4s" "${DAY_LABELS[$d]}"; done
printf "${X}\n"

# Build 7-day bars
day_spark_in=""; day_spark_out=""
for d in {0..6}; do
    vi=${DAY_IN[$d]:-0}; vo=${DAY_OUT[$d]:-0}
    li=$((vi * 7 / MAX_DAY_IN)); [ $li -gt 7 ] && li=7
    lo=$((vo * 7 / MAX_DAY_OUT)); [ $lo -gt 7 ] && lo=7
    # Each day gets 4 chars width
    day_spark_in+="${BLOCKS:$li:1}${BLOCKS:$li:1}${BLOCKS:$li:1} "
    day_spark_out+="${BLOCKS:$lo:1}${BLOCKS:$lo:1}${BLOCKS:$lo:1} "
done
printf "${C}%s${X}${C}IN${X}\n" "$day_spark_in"
printf "${M}%s${X}${M}OUT${X}\n" "$day_spark_out"
echo ""

# Model breakdown
MODEL_STATS=$(sqlite3 -separator '|' "$DB" "SELECT model, COUNT(*), SUM(input), SUM(output) FROM tokens WHERE ts >= $H24 GROUP BY model ORDER BY SUM(input)+SUM(output) DESC LIMIT 5;" 2>/dev/null)
if [ -n "$MODEL_STATS" ]; then
    echo "${B}Models (24h)${X}"
    MAX_MODEL_TOTAL=1
    while IFS='|' read -r _ _ inp outp; do
        t=$((inp + outp))
        [ $t -gt $MAX_MODEL_TOTAL ] && MAX_MODEL_TOTAL=$t
    done <<< "$MODEL_STATS"
    
    while IFS='|' read -r model count inp outp; do
        model_short="${model##*-}"
        [ ${#model_short} -gt 15 ] && model_short="${model_short:0:12}..."
        mcost=$(cost $inp $outp)
        total=$((inp + outp))
        bar_w=$((W - 35))
        [ $bar_w -lt 10 ] && bar_w=10
        filled=$((total * bar_w / MAX_MODEL_TOTAL))
        bar=$(bar_line $bar_w $filled "$G")
        printf "%-15s %s ${B}%4s${X} ${G}\$%s${X}\n" "$model_short" "$bar" "$count" "$mcost"
    done <<< "$MODEL_STATS"
    echo ""
fi

# Recent sessions
SESSIONS=$(sqlite3 -separator '|' "$DB" "SELECT session, COUNT(*), SUM(input), SUM(output) FROM tokens GROUP BY session ORDER BY session DESC LIMIT 5;" 2>/dev/null)
if [ -n "$SESSIONS" ]; then
    echo "${B}Recent Sessions${X}"
    MAX_SESS_TOTAL=1
    while IFS='|' read -r _ _ inp outp; do
        t=$((inp + outp))
        [ $t -gt $MAX_SESS_TOTAL ] && MAX_SESS_TOTAL=$t
    done <<< "$SESSIONS"
    
    while IFS='|' read -r sess count inp outp; do
        scost=$(cost $inp $outp)
        total=$((inp + outp))
        bar_w=$((W - 35))
        [ $bar_w -lt 10 ] && bar_w=10
        filled=$((total * bar_w / MAX_SESS_TOTAL))
        bar=$(bar_line $bar_w $filled "$Y")
        printf "%-10s %s ${B}%4s${X} ${G}\$%s${X}\n" "$sess" "$bar" "$count" "$scost"
    done <<< "$SESSIONS"
    echo ""
fi

printf "${D}DB: %s | \$%s/M in, \$%s/M out${X}\n" "$DB" "$AVG_IP" "$AVG_OP"
echo ""

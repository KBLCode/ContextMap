#!/bin/bash
# ContextViewer - Claude Code Statusline (Compact Block Bars)

input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
MODEL_ID=$(echo "$input" | jq -r '.model.id // ""')
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
USAGE=$(echo "$input" | jq '.context_window.current_usage')

G=$'\033[32m' Y=$'\033[33m' R=$'\033[31m' C=$'\033[36m' M=$'\033[35m' D=$'\033[2m' B=$'\033[1m' X=$'\033[0m'

if [ "$USAGE" != "null" ]; then
    IN=$(echo "$USAGE" | jq '.input_tokens // 0')
    OUT=$(echo "$USAGE" | jq '.output_tokens // 0')
    CREAD=$(echo "$USAGE" | jq '.cache_read_input_tokens // 0')
    CWRITE=$(echo "$USAGE" | jq '.cache_creation_input_tokens // 0')
    TOTAL=$(echo "$USAGE" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    PCT=$((TOTAL * 100 / CTX_SIZE))
else
    IN=0 OUT=0 CREAD=0 CWRITE=0 TOTAL=0 PCT=0
fi

AVG_IP=3 AVG_OP=15

fmt() { 
    local n=$1
    if [ "$n" -lt 1000 ]; then echo "$n"
    elif [ "$n" -lt 1000000 ]; then echo "$((n/1000))k"
    else echo "$((n/1000000))M"; fi
}

DB="${CV_DB:-$HOME/.config/context-viewer/tokens.db}"
SESSION="${CV_SESSION:-$(date +%Y%m%d)}"
HIST_FILE="$HOME/.config/context-viewer/history.txt"

mkdir -p "$(dirname "$DB")"

# Append current to history
if [ $IN -gt 0 ] || [ $OUT -gt 0 ]; then
    echo "$IN $OUT" >> "$HIST_FILE"
    tail -50 "$HIST_FILE" > "$HIST_FILE.tmp" && mv "$HIST_FILE.tmp" "$HIST_FILE"
fi

# Responsive width - fit terminal
TERM_WIDTH=${COLUMNS:-$(tput cols 2>/dev/null || echo 60)}
W=$((TERM_WIDTH - 16))
[ $W -lt 16 ] && W=16
[ $W -gt 40 ] && W=40

# Load history
IN_HIST=(); OUT_HIST=()
[ -f "$HIST_FILE" ] && while read -r i o; do IN_HIST+=("$i"); OUT_HIST+=("$o"); done < "$HIST_FILE"

# Block characters (8 levels)
BLOCKS="▁▂▃▄▅▆▇█"

# Find max for relative scaling
MAX_IN=1; MAX_OUT=1
for v in "${IN_HIST[@]}"; do [ "$v" -gt "$MAX_IN" ] && MAX_IN=$v; done
for v in "${OUT_HIST[@]}"; do [ "$v" -gt "$MAX_OUT" ] && MAX_OUT=$v; done

# Build block bars
in_bar=""; out_bar=""
hist_len=${#IN_HIST[@]}
for ((i=0; i<W; i++)); do
    idx=$((hist_len - W + i))
    if [ $idx -ge 0 ] && [ $idx -lt $hist_len ]; then
        iv=${IN_HIST[$idx]:-0}; ov=${OUT_HIST[$idx]:-0}
        il=$((iv * 7 / MAX_IN)); [ $il -gt 7 ] && il=7
        ol=$((ov * 7 / MAX_OUT)); [ $ol -gt 7 ] && ol=7
        in_bar+="${BLOCKS:$il:1}"
        out_bar+="${BLOCKS:$ol:1}"
    else
        in_bar+="${BLOCKS:0:1}"; out_bar+="${BLOCKS:0:1}"
    fi
done

# Session stats
SESS_IN=0; SESS_OUT=0
[ -f "$DB" ] && read _ SESS_IN SESS_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE session='$SESSION';" 2>/dev/null)
SESS_IN=${SESS_IN:-0}; SESS_OUT=${SESS_OUT:-0}
SESS_IN=$((SESS_IN + IN)); SESS_OUT=$((SESS_OUT + OUT))
SESS_COST=$(echo "scale=2; ($SESS_IN * $AVG_IP + $SESS_OUT * $AVG_OP) / 1000000" | bc 2>/dev/null || echo "0")

# Context bar
ctx_bar=""; filled=$(( (PCT * W + 50) / 100 )); [ $filled -gt $W ] && filled=$W
for ((i=0; i<W; i++)); do
    if [ $i -lt $filled ]; then
        [ $i -lt $((W/2)) ] && ctx_bar+="${G}█${X}" || { [ $i -lt $((W*3/4)) ] && ctx_bar+="${Y}█${X}" || ctx_bar+="${R}█${X}"; }
    else ctx_bar+="${D}░${X}"; fi
done

# Record to DB
if [ "${CV_RECORD:-1}" = "1" ] && { [ $IN -gt 0 ] || [ $OUT -gt 0 ]; }; then
    NOW=$(date +%s)
    
    # Create tables if needed
    if [ ! -f "$DB" ]; then
        sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS tokens(id INTEGER PRIMARY KEY,ts INTEGER,session TEXT,input INTEGER,output INTEGER,cache_read INTEGER,cache_write INTEGER,ctx_pct INTEGER,model TEXT);" 2>/dev/null
        sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS chats(session TEXT PRIMARY KEY,title TEXT,model TEXT,ctx_size INTEGER,first_ts INTEGER,last_ts INTEGER,total_input INTEGER,total_output INTEGER);" 2>/dev/null
    fi
    
    # Ensure chats table exists (for existing DBs)
    sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS chats(session TEXT PRIMARY KEY,title TEXT,model TEXT,ctx_size INTEGER,first_ts INTEGER,last_ts INTEGER,total_input INTEGER,total_output INTEGER);" 2>/dev/null
    
    # Insert token record
    sqlite3 "$DB" "INSERT INTO tokens(ts,session,input,output,cache_read,cache_write,ctx_pct,model) VALUES($NOW,'$SESSION',$IN,$OUT,$CREAD,$CWRITE,$PCT,'$MODEL_ID');" 2>/dev/null
    
    # Upsert chat record
    sqlite3 "$DB" "INSERT INTO chats(session,title,model,ctx_size,first_ts,last_ts,total_input,total_output) 
        VALUES('$SESSION','','$MODEL_ID',$CTX_SIZE,$NOW,$NOW,$IN,$OUT)
        ON CONFLICT(session) DO UPDATE SET 
            model=CASE WHEN excluded.model != '' THEN excluded.model ELSE model END,
            ctx_size=CASE WHEN excluded.ctx_size > 0 THEN excluded.ctx_size ELSE ctx_size END,
            last_ts=excluded.last_ts,
            total_input=total_input+excluded.total_input,
            total_output=total_output+excluded.total_output;" 2>/dev/null
fi

# Output - 3 compact lines
printf "%s \$%s %s↑ %s↓\n" "${B}$MODEL${X}" "${G}${SESS_COST}${X}" "${C}$(fmt $SESS_IN)${X}" "${M}$(fmt $SESS_OUT)${X}"
printf "${C}%s${X}%s↑ ${M}%s${X}%s↓\n" "$in_bar" "$(fmt $IN)" "$out_bar" "$(fmt $OUT)"
printf "%s %s%% %s/%s\n" "$ctx_bar" "${B}${PCT}${X}" "$(fmt $TOTAL)" "${D}$(fmt $CTX_SIZE)${X}"

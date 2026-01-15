#!/usr/bin/env bash
# ContextViewer /cmap - Token usage analytics dashboard

DB="${CV_DB:-$HOME/.config/context-viewer/tokens.db}"

# Colors
G=$'\033[32m' Y=$'\033[33m' R=$'\033[31m' C=$'\033[36m' M=$'\033[35m' D=$'\033[2m' B=$'\033[1m' X=$'\033[0m'

# ════════════════════════════════════════════════════════════════════════════
# HELP (defined first so it can be called early)
# ════════════════════════════════════════════════════════════════════════════
show_help() {
    echo "${B}◆ CONTEXT MAP ◆${X} - Claude Code Token Analytics"
    echo ""
    echo "${B}USAGE:${X}"
    echo "  /cmap              Show main dashboard with charts"
    echo "  /cmap -c           Show chat history (last 100)"
    echo "  /cmap -c 20        Show last 20 chats"
    echo "  /cmap -c -l 200    Show last 200 chats"
    echo "  /cmap --init       Backfill database from Claude history"
    echo "  /cmap -h           Show this help"
    echo ""
    echo "${B}FLAGS:${X}"
    echo "  ${C}-c, --chats${X}     List all tracked chats with tokens & cost"
    echo "  ${C}-l, --limit${X}     Limit number of chats shown (default: 100)"
    echo "  ${C}--init${X}          Import all historical chats from Claude Code"
    echo "  ${C}-h, --help${X}      Show this help message"
    echo ""
    echo "${B}EXAMPLES:${X}"
    echo "  ${D}/cmap${X}            Main dashboard with usage charts"
    echo "  ${D}/cmap -c${X}         All chats with session ID, title, tokens, cost"
    echo "  ${D}/cmap -c 10${X}      Last 10 chats only"
    echo "  ${D}/cmap --init${X}     First-time setup: import all past chats"
    echo ""
    echo "${B}DATA:${X}"
    echo "  Database: ${D}$DB${X}"
    echo "  Claude:   ${D}~/.claude/projects/${X}"
    exit 0
}

# Parse flags
SHOW_CHATS=0
CHAT_LIMIT=100
DO_INIT=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--chats)
            SHOW_CHATS=1
            # Check if next arg is a number (limit)
            if [[ $2 =~ ^[0-9]+$ ]]; then
                CHAT_LIMIT=$2
                shift
            fi
            shift
            ;;
        -l|--limit)
            if [[ $2 =~ ^[0-9]+$ ]]; then
                CHAT_LIMIT=$2
                shift
            fi
            shift
            ;;
        --init|init)
            DO_INIT=1
            shift
            ;;
        -h|--help|help)
            show_help
            ;;
        *)
            shift
            ;;
    esac
done

# Box width: 92 total = ║ + 90 inner + ║
W=90

# ════════════════════════════════════════════════════════════════════════════
# SYNC CHAT DATA FROM CLAUDE CODE SESSION FILES
# Extracts: session ID, title/summary, model, tokens (input/output), timestamps
# ════════════════════════════════════════════════════════════════════════════
sync_chats() {
    local claude_projects="$HOME/.claude/projects"
    [ ! -d "$claude_projects" ] && return
    
    # Ensure tables exist with cache columns
    sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS tokens(id INTEGER PRIMARY KEY,ts INTEGER,session TEXT,input INTEGER,output INTEGER,cache_read INTEGER,cache_write INTEGER,ctx_pct INTEGER,model TEXT);" 2>/dev/null
    sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS chats(session TEXT PRIMARY KEY,title TEXT,model TEXT,ctx_size INTEGER,first_ts INTEGER,last_ts INTEGER,total_input INTEGER,total_output INTEGER,cache_read INTEGER DEFAULT 0,cache_write INTEGER DEFAULT 0);" 2>/dev/null
    # Add cache columns if missing (migration)
    sqlite3 "$DB" "ALTER TABLE chats ADD COLUMN cache_read INTEGER DEFAULT 0;" 2>/dev/null
    sqlite3 "$DB" "ALTER TABLE chats ADD COLUMN cache_write INTEGER DEFAULT 0;" 2>/dev/null
    
    # Track which sessions we've already synced (avoid re-processing)
    local synced_file="$HOME/.config/context-viewer/.synced_sessions"
    touch "$synced_file" 2>/dev/null
    
    # Find all session JSONL files - use process substitution to avoid subshell
    while IFS= read -r jsonl; do
        local filename=$(basename "$jsonl" .jsonl)
        
        # Skip agent files and already synced sessions
        [[ "$filename" == agent-* ]] && continue
        grep -q "^$filename$" "$synced_file" 2>/dev/null && continue
        
        # Extract token types separately for correct pricing
        local inp_tokens=$(grep -o '"input_tokens":[0-9]*' "$jsonl" 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
        local cache_create=$(grep -o '"cache_creation_input_tokens":[0-9]*' "$jsonl" 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
        local cache_read=$(grep -o '"cache_read_input_tokens":[0-9]*' "$jsonl" 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
        local out_tokens=$(grep -o '"output_tokens":[0-9]*' "$jsonl" 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
        
        # Store input_tokens only (not cache) - cache stored separately
        local total_in=$inp_tokens
        local total_out=$out_tokens
        
        # Get model and summary
        local model=$(grep -o '"model":"[^"]*"' "$jsonl" 2>/dev/null | tail -1 | sed 's/"model":"//;s/"$//')
        local summary=$(grep -o '"summary":"[^"]*"' "$jsonl" 2>/dev/null | tail -1 | sed 's/"summary":"//;s/"$//' | sed "s/'/''/g")
        
        # Get timestamps
        local first_ts_str=$(grep -o '"timestamp":"[^"]*"' "$jsonl" 2>/dev/null | head -1 | sed 's/"timestamp":"//;s/"$//')
        local last_ts_str=$(grep -o '"timestamp":"[^"]*"' "$jsonl" 2>/dev/null | tail -1 | sed 's/"timestamp":"//;s/"$//')
        
        # Convert timestamps
        local first_ts=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${first_ts_str%%.*}" +%s 2>/dev/null || date +%s)
        local last_ts=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${last_ts_str%%.*}" +%s 2>/dev/null || date +%s)
        
        # Only insert if we found actual token data
        if [ "$total_in" -gt 0 ] || [ "$total_out" -gt 0 ] || [ "$cache_read" -gt 0 ] || [ "$cache_create" -gt 0 ]; then
            # Insert/update chat record with separate cache columns
            sqlite3 "$DB" "INSERT INTO chats(session,title,model,ctx_size,first_ts,last_ts,total_input,total_output,cache_read,cache_write)
                VALUES('$filename','$summary','$model',200000,$first_ts,$last_ts,$total_in,$total_out,$cache_read,$cache_create)
                ON CONFLICT(session) DO UPDATE SET 
                    title=CASE WHEN excluded.title != '' THEN excluded.title ELSE title END,
                    model=CASE WHEN excluded.model != '' THEN excluded.model ELSE model END,
                    first_ts=MIN(first_ts, excluded.first_ts),
                    last_ts=MAX(last_ts, excluded.last_ts),
                    total_input=excluded.total_input,
                    total_output=excluded.total_output,
                    cache_read=excluded.cache_read,
                    cache_write=excluded.cache_write;" 2>/dev/null
            
            # Mark as synced
            echo "$filename" >> "$synced_file"
        fi
    done < <(find "$claude_projects" -name "*.jsonl" -type f 2>/dev/null)
    
    # Also update from our tokens table (for sessions logged by statusline)
    sqlite3 "$DB" "INSERT INTO chats(session,title,model,ctx_size,first_ts,last_ts,total_input,total_output,cache_read,cache_write)
        SELECT session, '', 
            (SELECT model FROM tokens t2 WHERE t2.session=tokens.session ORDER BY ts DESC LIMIT 1),
            200000, MIN(ts), MAX(ts), SUM(input), SUM(output), SUM(COALESCE(cache_read,0)), SUM(COALESCE(cache_write,0))
        FROM tokens GROUP BY session
        ON CONFLICT(session) DO UPDATE SET 
            model=COALESCE(NULLIF(chats.model,''), excluded.model),
            first_ts=MIN(chats.first_ts, excluded.first_ts),
            last_ts=MAX(chats.last_ts, excluded.last_ts),
            total_input=MAX(chats.total_input, excluded.total_input),
            total_output=MAX(chats.total_output, excluded.total_output),
            cache_read=MAX(chats.cache_read, excluded.cache_read),
            cache_write=MAX(chats.cache_write, excluded.cache_write);" 2>/dev/null
}

# Get context size for model
get_ctx_size() {
    case "$1" in
        *opus*|*sonnet*) echo 200000 ;;
        *haiku*) echo 200000 ;;
        *) echo 200000 ;;
    esac
}

# ════════════════════════════════════════════════════════════════════════════
# INIT MODE - Full backfill of all historical chat data
# Sequential processing with progress display
# Stores all 4 token types for accurate cost calculation
# ════════════════════════════════════════════════════════════════════════════

init_backfill() {
    local claude_projects="$HOME/.claude/projects"
    
    echo "${B}◆ CONTEXT MAP INIT ◆${X}"
    echo ""
    
    if [ ! -d "$claude_projects" ]; then
        echo "${R}Error:${X} Claude projects directory not found at $claude_projects"
        exit 1
    fi
    
    # Create/ensure database and tables with all token types
    mkdir -p "$(dirname "$DB")"
    sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS tokens(id INTEGER PRIMARY KEY,ts INTEGER,session TEXT,input INTEGER,output INTEGER,cache_read INTEGER,cache_write INTEGER,ctx_pct INTEGER,model TEXT);" 2>/dev/null
    sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS chats(session TEXT PRIMARY KEY,title TEXT,model TEXT,ctx_size INTEGER,first_ts INTEGER,last_ts INTEGER,total_input INTEGER,total_output INTEGER,cache_read INTEGER DEFAULT 0,cache_write INTEGER DEFAULT 0);" 2>/dev/null
    # Migration: add cache columns if missing
    sqlite3 "$DB" "ALTER TABLE chats ADD COLUMN cache_read INTEGER DEFAULT 0;" 2>/dev/null
    sqlite3 "$DB" "ALTER TABLE chats ADD COLUMN cache_write INTEGER DEFAULT 0;" 2>/dev/null
    
    # Get list of files (excluding agent files)
    local files=()
    while IFS= read -r f; do
        local fname=$(basename "$f" .jsonl)
        [[ "$fname" == agent-* ]] && continue
        files+=("$f")
    done < <(find "$claude_projects" -name "*.jsonl" -type f 2>/dev/null)
    
    local total=${#files[@]}
    echo "Found ${C}$total${X} session files"
    echo ""
    
    local processed=0
    local imported=0
    
    for jsonl in "${files[@]}"; do
        local filename=$(basename "$jsonl" .jsonl)
        processed=$((processed + 1))
        
        # Extract all 4 token types separately
        local inp_tokens=$(grep -o '"input_tokens":[0-9]*' "$jsonl" 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
        local cache_create=$(grep -o '"cache_creation_input_tokens":[0-9]*' "$jsonl" 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
        local cache_read=$(grep -o '"cache_read_input_tokens":[0-9]*' "$jsonl" 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
        local out_tokens=$(grep -o '"output_tokens":[0-9]*' "$jsonl" 2>/dev/null | grep -o '[0-9]*' | awk '{s+=$1} END {print s+0}')
        
        # Skip if no tokens at all
        [ "$inp_tokens" -eq 0 ] && [ "$out_tokens" -eq 0 ] && [ "$cache_read" -eq 0 ] && [ "$cache_create" -eq 0 ] && continue
        
        # Get model and summary
        local model=$(grep -o '"model":"[^"]*"' "$jsonl" 2>/dev/null | tail -1 | sed 's/"model":"//;s/"$//')
        local summary=$(grep -o '"summary":"[^"]*"' "$jsonl" 2>/dev/null | tail -1 | sed 's/"summary":"//;s/"$//' | sed "s/'/''/g")
        
        # Get timestamps
        local first_ts=$(grep -o '"timestamp":"[^"]*"' "$jsonl" 2>/dev/null | head -1 | sed 's/"timestamp":"//;s/"$//')
        local last_ts=$(grep -o '"timestamp":"[^"]*"' "$jsonl" 2>/dev/null | tail -1 | sed 's/"timestamp":"//;s/"$//')
        
        # Convert timestamps (macOS date format)
        local first_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${first_ts%%.*}" +%s 2>/dev/null || date +%s)
        local last_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${last_ts%%.*}" +%s 2>/dev/null || date +%s)
        
        # Insert into DB with all 4 token types
        sqlite3 "$DB" "INSERT INTO chats(session,title,model,ctx_size,first_ts,last_ts,total_input,total_output,cache_read,cache_write)
            VALUES('$filename','$summary','$model',200000,$first_epoch,$last_epoch,$inp_tokens,$out_tokens,$cache_read,$cache_create)
            ON CONFLICT(session) DO UPDATE SET 
                title=CASE WHEN excluded.title != '' THEN excluded.title ELSE title END,
                model=CASE WHEN excluded.model != '' THEN excluded.model ELSE model END,
                first_ts=MIN(first_ts, excluded.first_ts),
                last_ts=MAX(last_ts, excluded.last_ts),
                total_input=excluded.total_input,
                total_output=excluded.total_output,
                cache_read=excluded.cache_read,
                cache_write=excluded.cache_write;" 2>/dev/null
        
        imported=$((imported + 1))
        
        # Progress display - show all token types
        local total_ctx=$((inp_tokens + cache_create + cache_read))
        printf "\r${G}✓${X} [%d/%d] %-20s ${C}%5sk${X}+${D}%5sk${X}r+${D}%5sk${X}w ${M}%5sk${X}out" \
            "$processed" "$total" "${filename:0:20}" "$((inp_tokens/1000))" "$((cache_read/1000))" "$((cache_create/1000))" "$((out_tokens/1000))"
    done
    
    echo ""
    echo ""
    
    # Get final stats with CORRECT per-model cost calculation
    local chat_count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM chats;" 2>/dev/null || echo 0)
    
    # Token totals
    local sum_input=$(sqlite3 "$DB" "SELECT COALESCE(SUM(total_input),0) FROM chats;" 2>/dev/null || echo 0)
    local sum_output=$(sqlite3 "$DB" "SELECT COALESCE(SUM(total_output),0) FROM chats;" 2>/dev/null || echo 0)
    local sum_cache_read=$(sqlite3 "$DB" "SELECT COALESCE(SUM(cache_read),0) FROM chats;" 2>/dev/null || echo 0)
    local sum_cache_write=$(sqlite3 "$DB" "SELECT COALESCE(SUM(cache_write),0) FROM chats;" 2>/dev/null || echo 0)
    local total_tokens=$((sum_input + sum_output + sum_cache_read + sum_cache_write))
    
    # Calculate cost per model family (correct pricing for each)
    local total_cost=0
    while IFS='|' read -r model inp outp cread cwrite; do
        [ -z "$model" ] && continue
        local c=$(cost_full "$inp" "$outp" "$cread" "$cwrite" "$model")
        total_cost=$(echo "$total_cost + $c" | bc)
    done < <(sqlite3 -separator '|' "$DB" "SELECT model, SUM(total_input), SUM(total_output), SUM(cache_read), SUM(cache_write) FROM chats GROUP BY model;" 2>/dev/null)
    
    echo "${G}════════════════════════════════════════${X}"
    echo "${G}✓ Backfill complete!${X}"
    echo "${G}════════════════════════════════════════${X}"
    echo ""
    echo "  ${B}Chats imported:${X}  ${C}$chat_count${X}"
    echo ""
    echo "  ${B}Token breakdown:${X}"
    echo "    Input:        ${C}$(printf "%'12d" "$sum_input")${X}"
    echo "    Cache write:  ${Y}$(printf "%'12d" "$sum_cache_write")${X}"
    echo "    Cache read:   ${G}$(printf "%'12d" "$sum_cache_read")${X}  ${D}(90% cheaper!)${X}"
    echo "    Output:       ${M}$(printf "%'12d" "$sum_output")${X}"
    echo "    ─────────────────────────"
    echo "    Total:        $(printf "%'12d" "$total_tokens")"
    echo ""
    echo "  ${B}Cost by model:${X}"
    # Group by model family (opus/sonnet/haiku) for cleaner display
    local opus_cost=0 sonnet_cost=0 haiku_cost=0
    while IFS='|' read -r model inp outp cread cwrite; do
        [ -z "$model" ] && continue
        local c=$(cost_full "$inp" "$outp" "$cread" "$cwrite" "$model")
        case "$(model_family "$model")" in
            opus) opus_cost=$(echo "$opus_cost + $c" | bc) ;;
            haiku) haiku_cost=$(echo "$haiku_cost + $c" | bc) ;;
            *) sonnet_cost=$(echo "$sonnet_cost + $c" | bc) ;;
        esac
    done < <(sqlite3 -separator '|' "$DB" "SELECT model, SUM(total_input), SUM(total_output), SUM(cache_read), SUM(cache_write) FROM chats GROUP BY model;" 2>/dev/null)
    [ "$(echo "$opus_cost > 0" | bc)" -eq 1 ] && printf "    ${R}Opus${X}     ${G}\$%8.2f${X}\n" "$opus_cost"
    [ "$(echo "$sonnet_cost > 0" | bc)" -eq 1 ] && printf "    ${Y}Sonnet${X}   ${G}\$%8.2f${X}\n" "$sonnet_cost"
    [ "$(echo "$haiku_cost > 0" | bc)" -eq 1 ] && printf "    ${C}Haiku${X}    ${G}\$%8.2f${X}\n" "$haiku_cost"
    echo "    ─────────────────────────"
    printf "    ${B}TOTAL    ${G}\$%8.2f${X}\n" "$total_cost"
    echo ""
    echo "Run ${C}/cmap${X} to see your dashboard"
    echo "Run ${C}/cmap -c${X} to see all chats"
}

# Output a line with proper padding - strips ANSI to measure visual width
line() {
    local content="$1"
    # Strip ANSI codes and measure visual width
    local stripped=$(echo -n "$content" | sed $'s/\033\\[[0-9;]*m//g')
    local visual_len=${#stripped}
    local pad=$((W - visual_len))
    [ $pad -lt 0 ] && pad=0
    printf "║%s%*s║\n" "$content" "$pad" ""
}

# Model pricing ($/MTok) - returns price for: input, cache_write, cache_read, output
# Pricing as of Jan 2025
get_price() {
    local model="$1" type="$2"
    case "$model" in
        *opus*)
            case "$type" in
                input) echo "15" ;;
                cache_write) echo "18.75" ;;
                cache_read) echo "1.50" ;;
                output) echo "75" ;;
            esac
            ;;
        *haiku*)
            case "$type" in
                input) echo "0.80" ;;
                cache_write) echo "1.00" ;;
                cache_read) echo "0.08" ;;
                output) echo "4" ;;
            esac
            ;;
        *)  # sonnet/default
            case "$type" in
                input) echo "3" ;;
                cache_write) echo "3.75" ;;
                cache_read) echo "0.30" ;;
                output) echo "15" ;;
            esac
            ;;
    esac
}

model_family() {
    case "$1" in *opus*) echo "opus" ;; *haiku*) echo "haiku" ;; *) echo "sonnet" ;; esac
}

# Calculate cost for a chat with all 4 token types
# Args: input output cache_read cache_write model
calc_cost() {
    local inp=$1 outp=$2 cread=$3 cwrite=$4 model=$5
    local pi=$(get_price "$model" "input")
    local po=$(get_price "$model" "output")
    local pcr=$(get_price "$model" "cache_read")
    local pcw=$(get_price "$model" "cache_write")
    echo "scale=2; ($inp * $pi + $outp * $po + $cread * $pcr + $cwrite * $pcw) / 1000000" | bc 2>/dev/null || echo "0"
}

fmt() { 
    local n=$1
    [ "$n" -lt 1000 ] && printf "%s" "$n" && return
    [ "$n" -lt 1000000 ] && printf "%sk" "$((n/1000))" && return
    printf "%.1fM" "$(echo "scale=1; $n/1000000" | bc)"
}

# Legacy cost function (for tokens table which doesn't have cache breakdown)
cost_model() {
    local inp=$1 outp=$2 model=$3
    local pi=$(get_price "$model" "input")
    local po=$(get_price "$model" "output")
    echo "scale=2; ($inp * $pi + $outp * $po) / 1000000" | bc 2>/dev/null || echo "0"
}

# Full cost function with cache (for chats table)
cost_full() {
    local inp=$1 outp=$2 cread=$3 cwrite=$4 model=$5
    local pi=$(get_price "$model" "input")
    local po=$(get_price "$model" "output")
    local pcr=$(get_price "$model" "cache_read")
    local pcw=$(get_price "$model" "cache_write")
    echo "scale=2; ($inp * $pi + $outp * $po + $cread * $pcr + $cwrite * $pcw) / 1000000" | bc 2>/dev/null || echo "0"
}

# Dual braille row: alternating input/output chars with different colors
# Args: max_val height row color_in color_out in_arr_name out_arr_name
braille_dual_row() {
    local max_val=$1 height=$2 row=$3 color_in=$4 color_out=$5 in_name=$6 out_name=$7
    [ "$max_val" -eq 0 ] && max_val=1
    local max_dots=$((height * 4)) left_dots=(64 4 2 1) right_dots=(128 32 16 8) line=""
    
    # Get array values via eval
    eval "local in_vals=(\"\${${in_name}[@]}\")"
    eval "local out_vals=(\"\${${out_name}[@]}\")"
    local n=${#in_vals[@]}
    
    for ((i=0; i<n; i++)); do
        local inp=${in_vals[$i]:-0} outp=${out_vals[$i]:-0}
        local s_in=0 s_out=0
        [ $inp -gt 0 ] && s_in=$(( (inp * max_dots + max_val - 1) / max_val )) && [ $s_in -gt $max_dots ] && s_in=$max_dots
        [ $outp -gt 0 ] && s_out=$(( (outp * max_dots + max_val - 1) / max_val )) && [ $s_out -gt $max_dots ] && s_out=$max_dots
        
        # Input char uses left dots only, output char uses right dots only
        local code_in=$((0x2800)) code_out=$((0x2800))
        for ((d=0; d<4; d++)); do
            local dot_pos=$((row * 4 + d + 1))
            [ $s_in -ge $dot_pos ] && code_in=$((code_in + ${left_dots[$d]}))
            [ $s_out -ge $dot_pos ] && code_out=$((code_out + ${right_dots[$d]}))
        done
        
        # Output: input char (left half) in color_in, output char (right half) in color_out
        line+="${color_in}$(printf "\\$(printf '%03o' $((code_in >> 12 | 0xE0)))\\$(printf '%03o' $(((code_in >> 6 & 0x3F) | 0x80)))\\$(printf '%03o' $((code_in & 0x3F | 0x80)))")${X}"
        line+="${color_out}$(printf "\\$(printf '%03o' $((code_out >> 12 | 0xE0)))\\$(printf '%03o' $(((code_out >> 6 & 0x3F) | 0x80)))\\$(printf '%03o' $((code_out & 0x3F | 0x80)))")${X}"
    done
    echo "$line"
}

# Generate box lines dynamically
BOX_TOP="╔$(printf '═%.0s' $(seq 1 $W))╗"
BOX_MID="╠$(printf '═%.0s' $(seq 1 $W))╣"
BOX_SEP="╟$(printf '─%.0s' $(seq 1 $W))╢"
BOX_BOT="╚$(printf '═%.0s' $(seq 1 $W))╝"

# Handle init mode (works even without existing DB)
if [ "$DO_INIT" = "1" ]; then
    mkdir -p "$(dirname "$DB")"
    init_backfill
    exit 0
fi

[ ! -f "$DB" ] && echo "$BOX_TOP" && line "  No data yet. Run ${C}/cmap --init${X} to import history." && echo "$BOX_BOT" && exit 0

# Sync chat data on every run (lightweight - only new sessions)
sync_chats

NOW=$(date +%s)

# ════════════════════════════════════════════════════════════════════════════
# CHAT LIST MODE (-c flag)
# ════════════════════════════════════════════════════════════════════════════
if [ "$SHOW_CHATS" = "1" ]; then
    CHAT_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM chats;" 2>/dev/null || echo 0)
    
    echo "$BOX_TOP"
    line "                              ${B}◆ CHAT HISTORY ◆${X}"
    line "                            ${D}$CHAT_COUNT chats tracked${X}"
    echo "$BOX_MID"
    line " ${D}Session${X}  │ ${D}Model${X}  │ ${D}Title${X}                          │ ${D}In${X}     │ ${D}Out${X}    │ ${D}Cache${X}   │ ${D}Cost${X}"
    echo "$BOX_SEP"
    
    # Alternating row brightness
    row_num=0
    
    # Use process substitution to avoid subshell (no 'local' issues)
    while IFS='|' read -r sess title model ctx_size inp outp cread cwrite first_ts last_ts; do
        [ -z "$sess" ] && continue
        
        # Add divider between rows (except before first)
        if [ "$row_num" -gt 0 ]; then
            line " ${D}─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─${X}"
        fi
        row_num=$((row_num + 1))
        
        # Truncate title to fit
        [ ${#title} -gt 30 ] && title="${title:0:27}..."
        [ -z "$title" ] && title="(untitled)"
        
        # Model family with color (red for opus, yellow for sonnet, cyan for haiku)
        fam=$(model_family "$model")
        case "$fam" in
            opus) model_display="${R}opus${X}  " ;;
            haiku) model_display="${C}haiku${X} " ;;
            *) model_display="${Y}sonnet${X}" ;;
        esac
        
        # Calculate cost with all token types
        cost=$(cost_full "$inp" "$outp" "$cread" "$cwrite" "$model")
        
        # Total cache (read + write)
        cache_total=$((cread + cwrite))
        
        # Format: session | model | title | in | out | cache | cost
        line " $(printf '%-8s' "${sess:0:8}") │ ${model_display} │ $(printf '%-30s' "$title") │ ${C}$(printf '%6s' "$(fmt $inp)")${X} │ $(printf '%6s' "$(fmt $outp)") │ ${D}$(printf '%7s' "$(fmt $cache_total)")${X} │ ${G}\$$(printf '%7s' "$cost")${X}"
    done < <(sqlite3 -separator '|' "$DB" "
        SELECT session, title, model, ctx_size, total_input, total_output, 
               COALESCE(cache_read,0), COALESCE(cache_write,0), first_ts, last_ts 
        FROM chats 
        ORDER BY last_ts DESC 
        LIMIT $CHAT_LIMIT;" 2>/dev/null)
    
    echo "$BOX_SEP"
    line " ${D}Use${X} /cmap -c 20 ${D}to show last 20 chats${X}"
    line " $(date '+%Y-%m-%d %H:%M')"
    echo "$BOX_BOT"
    exit 0
fi
H1=$((NOW - 3600)); H6=$((NOW - 21600)); H24=$((NOW - 86400)); D7=$((NOW - 604800)); D30=$((NOW - 2592000))

read H1_MSGS H1_IN H1_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $H1;" 2>/dev/null)
read H6_MSGS H6_IN H6_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $H6;" 2>/dev/null)
read H24_MSGS H24_IN H24_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $H24;" 2>/dev/null)
read D7_MSGS D7_IN D7_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $D7;" 2>/dev/null)
read D30_MSGS D30_IN D30_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens WHERE ts >= $D30;" 2>/dev/null)
read ALL_MSGS ALL_IN ALL_OUT <<< $(sqlite3 -separator ' ' "$DB" "SELECT COUNT(*), COALESCE(SUM(input),0), COALESCE(SUM(output),0) FROM tokens;" 2>/dev/null)
: ${H1_MSGS:=0} ${H1_IN:=0} ${H1_OUT:=0} ${H6_MSGS:=0} ${H6_IN:=0} ${H6_OUT:=0}
: ${H24_MSGS:=0} ${H24_IN:=0} ${H24_OUT:=0} ${D7_MSGS:=0} ${D7_IN:=0} ${D7_OUT:=0}
: ${D30_MSGS:=0} ${D30_IN:=0} ${D30_OUT:=0} ${ALL_MSGS:=0} ${ALL_IN:=0} ${ALL_OUT:=0}

calc_period_cost() {
    local total=0
    while IFS='|' read -r model inp outp; do
        [ -z "$model" ] && continue
        total=$(echo "$total + $(cost_model "$inp" "$outp" "$model")" | bc 2>/dev/null)
    done <<< "$(sqlite3 -separator '|' "$DB" "SELECT model, SUM(input), SUM(output) FROM tokens WHERE ts >= $1 GROUP BY model;" 2>/dev/null)"
    printf "%.2f" "${total:-0}"
}

H1_COST=$(calc_period_cost $H1); H6_COST=$(calc_period_cost $H6); H24_COST=$(calc_period_cost $H24)
D7_COST=$(calc_period_cost $D7); D30_COST=$(calc_period_cost $D30); ALL_COST=$(calc_period_cost 0)

OPUS_IN=0; OPUS_OUT=0; OPUS_COST="0"; SONNET_IN=0; SONNET_OUT=0; SONNET_COST="0"; HAIKU_IN=0; HAIKU_OUT=0; HAIKU_COST="0"
while IFS='|' read -r model inp outp; do
    [ -z "$model" ] && continue
    c=$(cost_model "$inp" "$outp" "$model")
    case "$(model_family "$model")" in
        opus) OPUS_IN=$((OPUS_IN + inp)); OPUS_OUT=$((OPUS_OUT + outp)); OPUS_COST=$(echo "$OPUS_COST + $c" | bc) ;;
        sonnet) SONNET_IN=$((SONNET_IN + inp)); SONNET_OUT=$((SONNET_OUT + outp)); SONNET_COST=$(echo "$SONNET_COST + $c" | bc) ;;
        haiku) HAIKU_IN=$((HAIKU_IN + inp)); HAIKU_OUT=$((HAIKU_OUT + outp)); HAIKU_COST=$(echo "$HAIKU_COST + $c" | bc) ;;
    esac
done <<< "$(sqlite3 -separator '|' "$DB" "SELECT model, SUM(input), SUM(output) FROM tokens GROUP BY model;" 2>/dev/null)"

# Chart data - 1 HOUR (30 points, 2-min intervals)
declare -a MIN1_IN MIN1_OUT; for i in {0..29}; do MIN1_IN[$i]=0; MIN1_OUT[$i]=0; done
while read -r bucket inp outp; do [ -n "$bucket" ] && idx=$((29 - bucket)) && [ $idx -ge 0 ] && [ $idx -le 29 ] && MIN1_IN[$idx]=${inp:-0} && MIN1_OUT[$idx]=${outp:-0}; done <<< "$(sqlite3 -separator ' ' "$DB" "SELECT (($NOW - ts) / 120) as bucket, SUM(input), SUM(output) FROM tokens WHERE ts >= $H1 GROUP BY bucket;" 2>/dev/null)"
MAX_MIN1=1; for i in {0..29}; do v=$((MIN1_IN[$i] + MIN1_OUT[$i])); [ "$v" -gt "$MAX_MIN1" ] && MAX_MIN1=$v; done

# ════════════════════════════════════════════════════════════════════════════
# OUTPUT - 70 chars wide (║ + 68 inner + ║)
# ════════════════════════════════════════════════════════════════════════════

echo "$BOX_TOP"
line "                      ${B}◆ CONTEXT MAP ◆${X}"
echo "$BOX_MID"
line " ${B}TODAY${X} $(printf '%3s' "$H24_MSGS")msg ${C}▲$(printf '%6s' "$(fmt $H24_IN)")${X} ${M}▼$(printf '%6s' "$(fmt $H24_OUT)")${X} ${G}\$$(printf '%-6s' "$H24_COST")${X}"
echo "$BOX_SEP"
line " Period    │ Msgs │   In   │  Out   │    Cost"
echo "$BOX_SEP"
line " 1 hour    │$(printf '%5s' "$H1_MSGS") │ ${C}$(printf '%6s' "$(fmt $H1_IN)")${X} │ ${M}$(printf '%6s' "$(fmt $H1_OUT)")${X} │ ${G}$(printf '%8s' "\$$H1_COST")${X}"
line " 6 hours   │$(printf '%5s' "$H6_MSGS") │ ${C}$(printf '%6s' "$(fmt $H6_IN)")${X} │ ${M}$(printf '%6s' "$(fmt $H6_OUT)")${X} │ ${G}$(printf '%8s' "\$$H6_COST")${X}"
line " 24 hours  │$(printf '%5s' "$H24_MSGS") │ ${C}$(printf '%6s' "$(fmt $H24_IN)")${X} │ ${M}$(printf '%6s' "$(fmt $H24_OUT)")${X} │ ${G}$(printf '%8s' "\$$H24_COST")${X}"
line " 7 days    │$(printf '%5s' "$D7_MSGS") │ ${C}$(printf '%6s' "$(fmt $D7_IN)")${X} │ ${M}$(printf '%6s' "$(fmt $D7_OUT)")${X} │ ${G}$(printf '%8s' "\$$D7_COST")${X}"
line " 30 days   │$(printf '%5s' "$D30_MSGS") │ ${C}$(printf '%6s' "$(fmt $D30_IN)")${X} │ ${M}$(printf '%6s' "$(fmt $D30_OUT)")${X} │ ${G}$(printf '%8s' "\$$D30_COST")${X}"
echo "$BOX_SEP"
line " ${B}ALL TIME${X}  │${B}$(printf '%5s' "$ALL_MSGS")${X} │ ${C}${B}$(printf '%6s' "$(fmt $ALL_IN)")${X} │ ${M}${B}$(printf '%6s' "$(fmt $ALL_OUT)")${X} │ ${G}${B}$(printf '%8s' "\$$ALL_COST")${X}"
echo "$BOX_MID"

# 1 HOUR - 30 points = 60 braille chars
line " ${B}1 HOUR${X} (2-min)                            ${C}▌${X}in ${M}▐${X}out"
for row in 3 2 1 0; do
    chart=$(braille_dual_row $MAX_MIN1 4 $row "$C" "$M" MIN1_IN MIN1_OUT)
    [ $row -eq 3 ] && line " ${chart} $(printf '%-6s' "$(fmt $MAX_MIN1)")" || line " ${chart}"
done
line " ◀─ 60m ago ─────────────────────────────── now ─▶"
echo "$BOX_SEP"

# 24 HOURS - 30 buckets (48-min intervals)
declare -a H24_IN H24_OUT; for i in {0..29}; do H24_IN[$i]=0; H24_OUT[$i]=0; done
while read -r bucket inp outp; do [ -n "$bucket" ] && idx=$((29 - bucket)) && [ $idx -ge 0 ] && [ $idx -le 29 ] && H24_IN[$idx]=${inp:-0} && H24_OUT[$idx]=${outp:-0}; done <<< "$(sqlite3 -separator ' ' "$DB" "SELECT (($NOW - ts) / 2880) as bucket, SUM(input), SUM(output) FROM tokens WHERE ts >= $H24 GROUP BY bucket;" 2>/dev/null)"
MAX_H24=1; for i in {0..29}; do v=$((H24_IN[$i] + H24_OUT[$i])); [ "$v" -gt "$MAX_H24" ] && MAX_H24=$v; done

line " ${B}24 HOURS${X} (48-min)                          ${C}▌${X}in ${M}▐${X}out"
for row in 3 2 1 0; do
    chart=$(braille_dual_row $MAX_H24 4 $row "$C" "$M" H24_IN H24_OUT)
    [ $row -eq 3 ] && line " ${chart} $(printf '%-6s' "$(fmt $MAX_H24)")" || line " ${chart}"
done
line " ◀─ 24h ago ─────────────────────────────── now ─▶"
echo "$BOX_SEP"

# 7 DAYS - 30 buckets (5.6-hour intervals)
declare -a D7_IN D7_OUT; for i in {0..29}; do D7_IN[$i]=0; D7_OUT[$i]=0; done
while read -r bucket inp outp; do [ -n "$bucket" ] && idx=$((29 - bucket)) && [ $idx -ge 0 ] && [ $idx -le 29 ] && D7_IN[$idx]=${inp:-0} && D7_OUT[$idx]=${outp:-0}; done <<< "$(sqlite3 -separator ' ' "$DB" "SELECT (($NOW - ts) / 20160) as bucket, SUM(input), SUM(output) FROM tokens WHERE ts >= $D7 GROUP BY bucket;" 2>/dev/null)"
MAX_D7=1; for i in {0..29}; do v=$((D7_IN[$i] + D7_OUT[$i])); [ "$v" -gt "$MAX_D7" ] && MAX_D7=$v; done

line " ${B}7 DAYS${X} (6-hour)                            ${Y}▌${X}in ${G}▐${X}out"
for row in 3 2 1 0; do
    chart=$(braille_dual_row $MAX_D7 4 $row "$Y" "$G" D7_IN D7_OUT)
    [ $row -eq 3 ] && line " ${chart} $(printf '%-6s' "$(fmt $MAX_D7)")" || line " ${chart}"
done
line " ◀─ 7d ago ──────────────────────────────── now ─▶"
echo "$BOX_SEP"

# 30 DAYS - 30 buckets (1-day intervals)
declare -a D30_IN D30_OUT; for i in {0..29}; do D30_IN[$i]=0; D30_OUT[$i]=0; done
while read -r bucket inp outp; do [ -n "$bucket" ] && idx=$((29 - bucket)) && [ $idx -ge 0 ] && [ $idx -le 29 ] && D30_IN[$idx]=${inp:-0} && D30_OUT[$idx]=${outp:-0}; done <<< "$(sqlite3 -separator ' ' "$DB" "SELECT (($NOW - ts) / 86400) as bucket, SUM(input), SUM(output) FROM tokens WHERE ts >= $D30 GROUP BY bucket;" 2>/dev/null)"
MAX_D30=1; for i in {0..29}; do v=$((D30_IN[$i] + D30_OUT[$i])); [ "$v" -gt "$MAX_D30" ] && MAX_D30=$v; done

line " ${B}30 DAYS${X} (1-day)                            ${M}▌${X}in ${R}▐${X}out"
for row in 3 2 1 0; do
    chart=$(braille_dual_row $MAX_D30 4 $row "$M" "$R" D30_IN D30_OUT)
    [ $row -eq 3 ] && line " ${chart} $(printf '%-6s' "$(fmt $MAX_D30)")" || line " ${chart}"
done
line " ◀─ 30d ago ─────────────────────────────── now ─▶"
echo "$BOX_MID"

# Cost by model
line " ${B}COST BY MODEL${X}"
echo "$BOX_SEP"
[ "$OPUS_IN" -gt 0 ] || [ "$OPUS_OUT" -gt 0 ] && line " ${R}Opus${X}   ${C}$(printf '%7s' "$(fmt $OPUS_IN)")${X} in ${M}$(printf '%7s' "$(fmt $OPUS_OUT)")${X} out ${G}\$$(printf '%-7s' "$OPUS_COST")${X}"
[ "$SONNET_IN" -gt 0 ] || [ "$SONNET_OUT" -gt 0 ] && line " ${Y}Sonnet${X} ${C}$(printf '%7s' "$(fmt $SONNET_IN)")${X} in ${M}$(printf '%7s' "$(fmt $SONNET_OUT)")${X} out ${G}\$$(printf '%-7s' "$SONNET_COST")${X}"
[ "$HAIKU_IN" -gt 0 ] || [ "$HAIKU_OUT" -gt 0 ] && line " ${C}Haiku${X}  ${C}$(printf '%7s' "$(fmt $HAIKU_IN)")${X} in ${M}$(printf '%7s' "$(fmt $HAIKU_OUT)")${X} out ${G}\$$(printf '%-7s' "$HAIKU_COST")${X}"
echo "$BOX_SEP"
line " ${B}TOTAL${X}  ${C}$(printf '%7s' "$(fmt $ALL_IN)")${X} in ${M}$(printf '%7s' "$(fmt $ALL_OUT)")${X} out ${G}${B}\$$(printf '%-7s' "$ALL_COST")${X}"
echo "$BOX_MID"

# Sessions
line " ${B}SESSIONS${X}"
echo "$BOX_SEP"
sqlite3 -separator '|' "$DB" "SELECT session, COUNT(*), SUM(input), SUM(output), MIN(ts), MAX(ts), model FROM tokens GROUP BY session ORDER BY MAX(ts) DESC LIMIT 3;" 2>/dev/null | while IFS='|' read -r sess count inp outp min_ts max_ts model; do
    [ -z "$sess" ] && continue
    dur=$((max_ts - min_ts))
    [ $dur -lt 60 ] && d="${dur}s" || { [ $dur -lt 3600 ] && d="$((dur/60))m" || d="$((dur/3600))h$((dur%3600/60))m"; }
    c=$(cost_model "$inp" "$outp" "$model")
    line " $(printf '%-6s' "${sess:0:6}") $(printf '%3s' "$count")msg ${C}$(printf '%5s' "$(fmt $inp)")${X}/${M}$(printf '%5s' "$(fmt $outp)")${X} ${G}\$$(printf '%-5s' "$c")${X} $(printf '%4s' "$d")"
done
echo "$BOX_SEP"
line " $(date '+%Y-%m-%d %H:%M')"
echo "$BOX_BOT"

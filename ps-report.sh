#!/usr/bin/env bash
# ps-report.sh — Analyze running processes for duplicates, heavy hitters, and stale processes.

set -uo pipefail

BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

divider() {
  printf '%*s\n' 80 '' | tr ' ' '─'
}

header() {
  echo ""
  divider
  printf "${BOLD}${CYAN}  %s${NC}\n" "$1"
  divider
}

# ─── Total memory usage ──────────────────────────────────────────────────────
total_mem_gb=$(sysctl -n hw.memsize | awk '{printf "%.0f", $1/1024/1024/1024}')
used_pct=$(ps aux | awk 'NR>1 {sum+=$4} END {printf "%.1f", sum}')

header "SYSTEM OVERVIEW"
printf "  Total RAM: ${BOLD}%s GB${NC}  |  User processes memory: ${BOLD}%s%%${NC}\n" "$total_mem_gb" "$used_pct"

# ─── Top processes by memory ─────────────────────────────────────────────────
header "TOP PROCESSES BY MEMORY"
printf "  ${DIM}%-40s %6s %10s${NC}\n" "PROCESS GROUP" "MEM%" "RSS (MB)"
divider

ps aux | awk 'NR>1 {
  cmd = $11
  n = split(cmd, parts, "/")
  base = parts[n]
  count[base]++
  mem[base] += $4
  rss[base] += $6
}
END {
  for (b in count) {
    if (mem[b] >= 0.3) {
      printf "  %-40s %6.1f %10.0f   (%d procs)\n", b, mem[b], rss[b]/1024, count[b]
    }
  }
}' | sort -t'%' -k2 -rn | sort -k2 -rn | head -15

# ─── Duplicate / multi-instance processes ────────────────────────────────────
header "MULTI-INSTANCE PROCESSES"
printf "  ${DIM}%-40s %6s %10s${NC}\n" "PROCESS" "COUNT" "TOTAL MB"
divider

ps aux | awk 'NR>1 {
  cmd = $11
  n = split(cmd, parts, "/")
  base = parts[n]
  count[base]++
  rss[base] += $6
}
END {
  for (b in count) {
    if (count[b] > 2) {
      printf "  %-40s %6d %10.0f\n", b, count[b], rss[b]/1024
    }
  }
}' | sort -k2 -rn | head -15

# ─── Stale / long-running dev processes ──────────────────────────────────────
header "STALE PROCESSES (dev servers older than 1 day)"

now=$(date +%s)
found_stale=0

# Only match actual dev servers / build tools, not VS Code or browser node processes
while IFS= read -r line; do
  pid=$(echo "$line" | awk '{print $2}')
  tty=$(echo "$line" | awk '{print $7}')
  cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')

  # Skip VS Code, browser, and system node processes
  echo "$cmd" | grep -qiE '(Visual Studio|Code Helper|Brave|Chrome|Electron)' && continue

  # Get process start time via ps -p
  start_epoch=$(ps -p "$pid" -o lstart= 2>/dev/null | xargs -I{} date -j -f "%a %b %d %T %Y" "{}" "+%s" 2>/dev/null || echo "0")

  if [ "$start_epoch" != "0" ]; then
    age_hours=$(( (now - start_epoch) / 3600 ))
    if [ "$age_hours" -gt 24 ]; then
      age_days=$(( age_hours / 24 ))
      found_stale=1
      printf "  ${RED}PID %-8s${NC} ${YELLOW}%3d days old${NC}  TTY: %-5s  %s\n" \
        "$pid" "$age_days" "$tty" "$(echo "$cmd" | cut -c1-60)"
    fi
  fi
done < <(ps aux | grep -E '(pnpm|npm|node|next-server|turbo)' | grep -v grep | grep -v 'ps aux')

if [ "$found_stale" -eq 0 ]; then
  printf "  ${GREEN}No stale dev processes found.${NC}\n"
fi

# ─── Duplicate Claude instances ──────────────────────────────────────────────
header "CLAUDE CODE INSTANCES"

claude_count=0
while IFS= read -r line; do
  pid=$(echo "$line" | awk '{print $2}')
  mem=$(echo "$line" | awk '{print $4}')
  tty=$(echo "$line" | awk '{print $7}')
  cpu=$(echo "$line" | awk '{print $3}')
  printf "  PID: %-8s  MEM: %5s%%  CPU: %5s%%  TTY: %s\n" "$pid" "$mem" "$cpu" "$tty"
  claude_count=$((claude_count + 1))
done < <(ps aux | grep -E '[c]laude$' || true)

if [ "$claude_count" -eq 0 ]; then
  printf "  ${DIM}No Claude instances found.${NC}\n"
elif [ "$claude_count" -gt 1 ]; then
  printf "\n  ${YELLOW}Multiple Claude instances detected. Close unused sessions to free memory.${NC}\n"
fi

# ─── MCP server instances ───────────────────────────────────────────────────
header "MCP SERVERS"

mcp_count=0
while IFS= read -r line; do
  pid=$(echo "$line" | awk '{print $2}')
  mem=$(echo "$line" | awk '{print $4}')
  cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i}')
  # Extract the mcp name
  mcp_name=$(echo "$cmd" | grep -oE '[a-z0-9-]+-mcp' | head -1)
  [ -z "$mcp_name" ] && mcp_name="unknown-mcp"
  printf "  PID: %-8s  MEM: %5s%%  %s\n" "$pid" "$mem" "$mcp_name"
  mcp_count=$((mcp_count + 1))
done < <(ps aux | grep -E '[m]cp' | grep node || true)

if [ "$mcp_count" -eq 0 ]; then
  printf "  ${DIM}No MCP servers found.${NC}\n"
elif [ "$mcp_count" -gt 4 ]; then
  printf "\n  ${YELLOW}Multiple MCP server sets detected (likely from multiple Claude sessions).${NC}\n"
fi

# ─── Browsers ────────────────────────────────────────────────────────────────
header "BROWSERS"

for browser in "Google Chrome" "Brave Browser" "Firefox" "Safari" "Arc"; do
  # Match against the full command line
  count=$(ps aux | grep -i "$browser" | grep -v grep | wc -l | tr -d ' ')
  if [ "$count" -gt 0 ]; then
    mem=$(ps aux | grep -i "$browser" | grep -v grep | awk '{sum+=$4} END {printf "%.1f", sum}')
    rss=$(ps aux | grep -i "$browser" | grep -v grep | awk '{sum+=$6} END {printf "%.0f", sum/1024}')
    printf "  %-20s %3s procs  %5s%% mem  %s MB\n" "$browser" "$count" "$mem" "$rss"
  fi
done

# ─── Heavy apps ──────────────────────────────────────────────────────────────
header "HEAVY APPS (>500 MB RSS)"

ps aux | awk 'NR>1 {
  cmd = $11
  n = split(cmd, parts, "/")
  base = parts[n]
  rss[base] += $6
  mem[base] += $4
}
END {
  for (b in rss) {
    mb = rss[b] / 1024
    if (mb > 500) {
      printf "  %-35s %8.0f MB  (%5.1f%%)\n", b, mb, mem[b]
    }
  }
}' | sort -k2 -rn

# ─── Summary & recommendations ──────────────────────────────────────────────
header "RECOMMENDATIONS"

# Check for stale node/pnpm dev servers
stale_pids=""
while IFS= read -r line; do
  pid=$(echo "$line" | awk '{print $2}')
  start_epoch=$(ps -p "$pid" -o lstart= 2>/dev/null | xargs -I{} date -j -f "%a %b %d %T %Y" "{}" "+%s" 2>/dev/null || echo "0")
  if [ "$start_epoch" != "0" ]; then
    age_hours=$(( ($(date +%s) - start_epoch) / 3600 ))
    if [ "$age_hours" -gt 24 ]; then
      stale_pids="$stale_pids $pid"
    fi
  fi
done < <(ps aux | grep -E '(pnpm|npm) .*(dev|start)' | grep -v grep)

if [ -n "$stale_pids" ]; then
  printf "  ${RED}[!]${NC} Stale dev servers found. Kill them with:\n"
  printf "      ${BOLD}kill%s${NC}\n" "$stale_pids"
fi

# Check multiple browsers
browser_count=0
for browser in "Google Chrome" "Brave Browser" "Firefox" "Arc"; do
  if pgrep -fi "$browser" > /dev/null 2>&1; then
    browser_count=$((browser_count + 1))
  fi
done
if [ "$browser_count" -gt 1 ]; then
  printf "  ${YELLOW}[~]${NC} Multiple browsers running. Close unused ones to save RAM.\n"
fi

# Check OrbStack
if pgrep -f "OrbStack" > /dev/null 2>&1; then
  orb_mem=$(ps aux | grep -i orbstack | grep -v grep | awk '{sum+=$6} END {printf "%.0f", sum/1024}')
  if [ "$orb_mem" -gt 1000 ]; then
    printf "  ${YELLOW}[~]${NC} OrbStack using ${BOLD}%s MB${NC}. Quit if Docker not needed.\n" "$orb_mem"
  fi
fi

# Check multiple Claude instances
if [ "$claude_count" -gt 1 ]; then
  printf "  ${YELLOW}[~]${NC} %d Claude Code sessions running. Close unused ones.\n" "$claude_count"
fi

echo ""
divider
printf "  ${DIM}Report generated: %s${NC}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
divider
echo ""

#!/bin/bash

SAMPLE_COUNT=5
SAMPLE_INTERVAL=1

cpu_values=()
mem_used_values=()

get_os_type() {
    local os
    case "$(uname -s)" in
        Linux*)   os="linux" ;;
        Darwin*)  os="macos" ;;
        CYGWIN*)  os="windows" ;;
        MINGW*)   os="windows" ;;
        *)        os="unknown" ;;
    esac
    echo "$os"
}

get_cpu_usage_linux() {
    if [ ! -f "/proc/stat" ]; then
        echo "0.00"
        return
    fi
    
    local stat1=$(grep '^cpu ' /proc/stat)
    sleep $SAMPLE_INTERVAL
    local stat2=$(grep '^cpu ' /proc/stat)
    
    local user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1
    read -r cpu user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 <<< "$stat1"
    
    local user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2
    read -r cpu user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 <<< "$stat2"
    
    local idle_diff=$(( (idle2 + iowait2) - (idle1 + iowait1) ))
    local total1=$(( user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1 ))
    local total2=$(( user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2 ))
    local total_diff=$(( total2 - total1 ))
    
    if [ "$total_diff" -eq 0 ]; then
        echo "0.00"
        return
    fi
    
    local cpu_usage=$(awk -v idle="$idle_diff" -v total="$total_diff" 'BEGIN {
        usage = 100.0 * (1.0 - idle / total)
        if (usage < 0) usage = 0
        if (usage > 100) usage = 100
        printf "%.2f", usage
    }')
    
    echo "$cpu_usage"
}

get_cpu_usage_macos() {
    local cpu_line=$(top -l 2 -n 0 | grep 'CPU usage:' | tail -n 1)
    
    if [ -z "$cpu_line" ]; then
        echo "0.00"
        return
    fi
    
    local idle=$(echo "$cpu_line" | awk -F'idle' '{print $1}' | awk -F',' '{print $NF}' | sed 's/%//' | tr -d ' ')
    
    if [ -z "$idle" ] || [[ "$idle" =~ [^0-9.] ]]; then
        echo "0.00"
        return
    fi
    
    local cpu_usage=$(awk -v idle="$idle" 'BEGIN {
        usage = 100.0 - idle
        if (usage < 0) usage = 0
        if (usage > 100) usage = 100
        printf "%.2f", usage
    }')
    
    echo "$cpu_usage"
}

get_cpu_usage_windows() {
    local cpu_usage=$(wmic cpu get LoadPercentage 2>/dev/null | grep -E '^[0-9]' | head -n 1)
    
    if [ -z "$cpu_usage" ] || [[ "$cpu_usage" =~ [^0-9] ]]; then
        echo "0.00"
    else
        cpu_usage=$(awk -v cpu="$cpu_usage" 'BEGIN {printf "%.2f", cpu}')
        echo "$cpu_usage"
    fi
}

get_memory_info_linux() {
    if [ ! -f "/proc/meminfo" ]; then
        echo "0.00 0 0"
        return
    fi
    
    local mem_total=$(grep '^MemTotal:' /proc/meminfo 2>/dev/null | awk '{print $2}')
    local mem_available=$(grep '^MemAvailable:' /proc/meminfo 2>/dev/null | awk '{print $2}')
    
    if [ -z "$mem_total" ] || [ -z "$mem_available" ]; then
        echo "0.00 0 0"
        return
    fi
    
    local mem_used_percent=$(awk -v total="$mem_total" -v available="$mem_available" 'BEGIN {
        if (total > 0) {
            used = total - available
            printf "%.2f %d %d", 100.0 * used / total, total, available
        } else {
            printf "0.00 0 0"
        }
    }')
    
    echo "$mem_used_percent"
}

get_memory_info_macos() {
    local mem_total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    
    if [ -z "$mem_total_bytes" ]; then
        echo "0.00 0 0"
        return
    fi
    
    local mem_total_kb=$(( mem_total_bytes / 1024 ))
    
    local vm_stat_output=$(vm_stat 2>/dev/null)
    
    if [ -z "$vm_stat_output" ]; then
        echo "0.00 0 0"
        return
    fi
    
    local page_size=$(echo "$vm_stat_output" | grep 'page size of' | awk '{print $8}')
    if [ -z "$page_size" ] || [[ "$page_size" =~ [^0-9] ]]; then
        page_size=16384
    fi
    
    local free_pages=$(echo "$vm_stat_output" | grep 'Pages free:' | awk '{print $3}' | sed 's/\.//')
    local active_pages=$(echo "$vm_stat_output" | grep 'Pages active:' | awk '{print $3}' | sed 's/\.//')
    local inactive_pages=$(echo "$vm_stat_output" | grep 'Pages inactive:' | awk '{print $3}' | sed 's/\.//')
    local speculative_pages=$(echo "$vm_stat_output" | grep 'Pages speculative:' | awk '{print $3}' | sed 's/\.//')
    local wired_pages=$(echo "$vm_stat_output" | grep 'Pages wired down:' | awk '{print $4}' | sed 's/\.//')
    local compressed_pages=$(echo "$vm_stat_output" | grep 'Pages occupied by compressor:' | awk '{print $5}' | sed 's/\.//')
    
    for var in free_pages active_pages inactive_pages speculative_pages wired_pages compressed_pages; do
        if [ -z "${!var}" ] || [[ "${!var}" =~ [^0-9] ]]; then
            eval "$var=0"
        fi
    done
    
    local free_kb=$(( free_pages * page_size / 1024 ))
    local inactive_kb=$(( inactive_pages * page_size / 1024 ))
    local speculative_kb=$(( speculative_pages * page_size / 1024 ))
    
    local mem_available_kb=$(( free_kb + inactive_kb + speculative_kb ))
    
    local mem_used_percent=$(awk -v total="$mem_total_kb" -v available="$mem_available_kb" 'BEGIN {
        if (total > 0) {
            used = total - available
            printf "%.2f %d %d", 100.0 * used / total, total, available
        } else {
            printf "0.00 0 0"
        }
    }')
    
    echo "$mem_used_percent"
}

get_memory_info_windows() {
    local mem_info=$(wmic OS get FreePhysicalMemory,TotalVisibleMemorySize 2>/dev/null | grep -E '^[0-9]' | head -n 1)
    
    if [ -z "$mem_info" ]; then
        echo "0.00 0 0"
        return
    fi
    
    local mem_free=$(echo "$mem_info" | awk '{print $1}')
    local mem_total=$(echo "$mem_info" | awk '{print $2}')
    
    if [ -z "$mem_free" ] || [ -z "$mem_total" ] || [[ "$mem_free" =~ [^0-9] ]] || [[ "$mem_total" =~ [^0-9] ]]; then
        echo "0.00 0 0"
        return
    fi
    
    local mem_used_percent=$(awk -v total="$mem_total" -v free="$mem_free" 'BEGIN {
        if (total > 0) {
            used = total - free
            printf "%.2f %d %d", 100.0 * used / total, total, free
        } else {
            printf "0.00 0 0"
        }
    }')
    
    echo "$mem_used_percent"
}

get_cpu_usage() {
    local os=$(get_os_type)
    case "$os" in
        linux)   get_cpu_usage_linux ;;
        macos)   get_cpu_usage_macos ;;
        windows) get_cpu_usage_windows ;;
        *)       echo "0.00" ;;
    esac
}

get_memory_info() {
    local os=$(get_os_type)
    case "$os" in
        linux)   get_memory_info_linux ;;
        macos)   get_memory_info_macos ;;
        windows) get_memory_info_windows ;;
        *)       echo "0.00 0 0" ;;
    esac
}

calculate_stats() {
    local label=$1
    shift
    local values=("$@")
    
    if [ ${#values[@]} -eq 0 ]; then
        printf "%-6s %8.2f %8.2f %8.2f %8.2f\n" "$label" 0.00 0.00 0.00 0.00
        return
    fi
    
    local result=$(printf "%s\n" "${values[@]}" | awk -v label="$label" '
    BEGIN {
        min = 1000000000
        max = -1000000000
        sum = 0
        count = 0
    }
    {
        val = $1 + 0
        if (val < min) min = val
        if (val > max) max = val
        sum += val
        count++
    }
    END {
        if (count > 0) {
            mean = sum / count
            fluctuation = max - min
            printf "%-6s %8.2f %8.2f %8.2f %8.2f\n", label, mean, max, min, fluctuation
        } else {
            printf "%-6s %8.2f %8.2f %8.2f %8.2f\n", label, 0.00, 0.00, 0.00, 0.00
        }
    }
    ')
    
    echo "$result"
}

main() {
    local os=$(get_os_type)
    echo "========================================"
    echo "系统状态监控脚本"
    echo "操作系统: $os"
    echo "采样次数: $SAMPLE_COUNT 次"
    echo "采样间隔: $SAMPLE_INTERVAL 秒"
    echo "========================================"
    echo ""
    
    printf "%-6s %8s %10s %12s %15s\n" "次数" "CPU(%)" "内存(%)" "总内存(KB)" "可用内存(KB)"
    echo "---------------------------------------------------------------"
    
    for i in $(seq 1 $SAMPLE_COUNT); do
        local cpu_usage
        if [ "$os" = "linux" ]; then
            cpu_usage=$(get_cpu_usage_linux)
        else
            cpu_usage=$(get_cpu_usage)
        fi
        
        local mem_info=$(get_memory_info)
        local mem_used_percent=$(echo "$mem_info" | awk '{print $1}')
        local mem_total=$(echo "$mem_info" | awk '{print $2}')
        local mem_available=$(echo "$mem_info" | awk '{print $3}')
        
        if [ -z "$cpu_usage" ] || [[ "$cpu_usage" =~ [^0-9.] ]]; then
            cpu_usage="0.00"
        fi
        if [ -z "$mem_used_percent" ] || [[ "$mem_used_percent" =~ [^0-9.] ]]; then
            mem_used_percent="0.00"
        fi
        if [ -z "$mem_total" ] || [[ "$mem_total" =~ [^0-9] ]]; then
            mem_total="0"
        fi
        if [ -z "$mem_available" ] || [[ "$mem_available" =~ [^0-9] ]]; then
            mem_available="0"
        fi
        
        cpu_values+=("$cpu_usage")
        mem_used_values+=("$mem_used_percent")
        
        printf "%-6d %8s %10s %12d %15d\n" "$i" "$cpu_usage" "$mem_used_percent" "$mem_total" "$mem_available"
        
        if [ "$i" -lt "$SAMPLE_COUNT" ]; then
            if [ "$os" != "linux" ]; then
                sleep $SAMPLE_INTERVAL
            fi
        fi
    done
    
    echo "---------------------------------------------------------------"
    echo ""
    echo "========================================"
    echo "汇总统计"
    echo "========================================"
    printf "%-6s %8s %8s %8s %8s\n" "指标" "均值" "最大" "最小" "波动"
    echo "------------------------------------------------"
    
    calculate_stats "CPU" "${cpu_values[@]}"
    calculate_stats "内存" "${mem_used_values[@]}"
    
    echo "------------------------------------------------"
    echo ""
    echo "监控完成！"
}

main

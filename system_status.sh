#!/bin/bash

SAMPLE_COUNT=5
SAMPLE_INTERVAL=1
OUTPUT_FORMAT="text"

CPU_THRESHOLD=${CPU_THRESHOLD:-80.0}
MEM_THRESHOLD=${MEM_THRESHOLD:-80.0}

ALARM_ENABLED=${ALARM_ENABLED:-true}

show_help() {
    cat << EOF
用法: $0 [选项]

系统状态监控脚本，支持动态配置采样参数和多种输出格式。

选项:
    -n 次数      设置采样次数 (默认: 5)
    -i 秒数      设置采样间隔时间 (默认: 1秒)
    -f 格式      设置输出格式 (text/json, 默认: text)
    -h, --help   显示此帮助信息

示例:
    $0 -n 10 -i 2          采样10次，间隔2秒，文本格式输出
    $0 -n 5 -i 1 -f json   采样5次，间隔1秒，JSON格式输出
    $0                      使用默认配置 (5次采样，间隔1秒，文本格式)
EOF
}

parse_args() {
    while getopts ":n:i:f:h-" opt; do
        case $opt in
            n)
                if ! is_number "$OPTARG"; then
                    echo "错误: 采样次数必须是有效的数字"
                    exit 1
                fi
                SAMPLE_COUNT=$OPTARG
                ;;
            i)
                if ! is_number "$OPTARG"; then
                    echo "错误: 采样间隔必须是有效的数字"
                    exit 1
                fi
                SAMPLE_INTERVAL=$OPTARG
                ;;
            f)
                case "$OPTARG" in
                    text|json)
                        OUTPUT_FORMAT=$OPTARG
                        ;;
                    *)
                        echo "错误: 输出格式只能是 'text' 或 'json'"
                        exit 1
                        ;;
                esac
                ;;
            h)
                show_help
                exit 0
                ;;
            -)
                case "${OPTARG}" in
                    help)
                        show_help
                        exit 0
                        ;;
                    *)
                        echo "错误: 无效选项 --$OPTARG"
                        show_help
                        exit 1
                        ;;
                esac
                ;;
            \?)
                echo "错误: 无效选项 -$OPTARG"
                show_help
                exit 1
                ;;
            :)
                echo "错误: 选项 -$OPTARG 需要参数"
                show_help
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))
}

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

is_number() {
    [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]
}

check_threshold() {
    local value="$1"
    local threshold="$2"
    
    if ! is_number "$value" || ! is_number "$threshold"; then
        echo "0"
        return
    fi
    
    local result=$(awk -v val="$value" -v thresh="$threshold" 'BEGIN {
        if (val > thresh) {
            print "1"
        } else {
            print "0"
        }
    }')
    
    echo "$result"
}

get_alarm_log_dir() {
    local os=$(get_os_type)
    local log_dir
    
    case "$os" in
        linux)
            if [ -d "/var/log" ]; then
                log_dir="/var/log/system_monitor"
            else
                log_dir="./logs"
            fi
            ;;
        macos)
            if [ -d "/Library/Logs" ]; then
                log_dir="/Library/Logs/SystemMonitor"
            else
                log_dir="./logs"
            fi
            ;;
        windows)
            log_dir="./logs"
            ;;
        *)
            log_dir="./logs"
            ;;
    esac
    
    if [ -n "$LOG_DIR" ]; then
        log_dir="$LOG_DIR"
    fi
    
    echo "$log_dir"
}

get_weekly_log_filename() {
    local year=$(date +%Y)
    local week=$(date +%V)
    echo "alarm_${year}_${week}.log"
}

get_server_id() {
    local server_id="${SERVER_ID:-}"
    
    if [ -z "$server_id" ]; then
        server_id=$(hostname 2>/dev/null)
        if [ $? -ne 0 ] || [ -z "$server_id" ]; then
            server_id="unknown_server"
        fi
    fi
    
    echo "$server_id"
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
    local cpu_line=$(top -l 2 -n 0 2>/dev/null | grep 'CPU usage:' | tail -n 1)
    
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

calculate_stats_json() {
    local label=$1
    shift
    local values=("$@")
    
    if [ ${#values[@]} -eq 0 ]; then
        printf '{"label":"%s","mean":0.00,"max":0.00,"min":0.00,"fluctuation":0.00}' "$label"
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
            printf "{\"label\":\"%s\",\"mean\":%.2f,\"max\":%.2f,\"min\":%.2f,\"fluctuation\":%.2f}", label, mean, max, min, fluctuation
        } else {
            printf "{\"label\":\"%s\",\"mean\":0.00,\"max\":0.00,\"min\":0.00,\"fluctuation\":0.00}", label
        }
    }
    ')
    
    echo "$result"
}

escape_json_string() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

write_alarm_log() {
    local sample_num="$1"
    local cpu_usage="$2"
    local mem_used_percent="$3"
    local mem_total="$4"
    local mem_available="$5"
    local os="$6"
    local server_id="$7"
    local cpu_threshold="$8"
    local mem_threshold="$9"
    
    if [ "$ALARM_ENABLED" != "true" ]; then
        return
    fi
    
    local cpu_exceed=$(check_threshold "$cpu_usage" "$cpu_threshold")
    local mem_exceed=$(check_threshold "$mem_used_percent" "$mem_threshold")
    
    if [ "$cpu_exceed" -eq 0 ] && [ "$mem_exceed" -eq 0 ]; then
        return
    fi
    
    local log_dir=$(get_alarm_log_dir)
    local log_filename=$(get_weekly_log_filename)
    local log_file="$log_dir/$log_filename"
    
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local week_year=$(date "+%Y年第%V周")
    
    if [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir" 2>/dev/null
        if [ $? -ne 0 ]; then
            log_dir="./logs"
            log_file="$log_dir/$log_filename"
            mkdir -p "$log_dir" 2>/dev/null
        fi
    fi
    
    local cpu_alarm_msg=""
    if [ "$cpu_exceed" -eq 1 ]; then
        cpu_alarm_msg="[ALARM] CPU=$cpu_usage% (阈值=$cpu_threshold%)"
    fi
    
    local mem_alarm_msg=""
    if [ "$mem_exceed" -eq 1 ]; then
        mem_alarm_msg="[ALARM] 内存=$mem_used_percent% (阈值=$mem_threshold%)"
    fi
    
    local log_entry="[$timestamp] [$week_year] [采样=$sample_num] [ServerID=$server_id] [OS=$os] 总内存=${mem_total}KB 可用内存=${mem_available}KB"
    
    if [ -n "$cpu_alarm_msg" ]; then
        log_entry="$log_entry $cpu_alarm_msg"
    fi
    if [ -n "$mem_alarm_msg" ]; then
        log_entry="$log_entry $mem_alarm_msg"
    fi
    
    echo "$log_entry" >> "$log_file" 2>/dev/null
    
    if [ "$cpu_exceed" -eq 1 ]; then
        echo -e "\033[0;31m[ALARM] CPU使用率 $cpu_usage% 超过阈值 $cpu_threshold%\033[0m"
    fi
    if [ "$mem_exceed" -eq 1 ]; then
        echo -e "\033[0;31m[ALARM] 内存使用率 $mem_used_percent% 超过阈值 $mem_threshold%\033[0m"
    fi
}

main() {
    parse_args "$@"
    
    local os=$(get_os_type)
    local server_id=$(get_server_id)
    local log_dir=$(get_alarm_log_dir)
    local log_filename=$(get_weekly_log_filename)
    
    local cpu_values=()
    local mem_used_values=()
    local mem_total_values=()
    local mem_available_values=()
    local samples_json=""
    
    if [ "$OUTPUT_FORMAT" = "text" ]; then
        echo "========================================"
        echo "系统状态监控脚本 (带告警功能)"
        echo "========================================"
        echo "操作系统: $os"
        echo "服务器ID: $server_id"
        echo "采样次数: $SAMPLE_COUNT 次"
        echo "采样间隔: $SAMPLE_INTERVAL 秒"
        echo "========================================"
        echo "告警配置:"
        echo "  CPU阈值: ${CPU_THRESHOLD}%"
        echo "  内存阈值: ${MEM_THRESHOLD}%"
        echo "  告警日志: $log_dir/$log_filename"
        echo "========================================"
        echo ""
        
        printf "%-6s %8s %10s %12s %15s\n" "次数" "CPU(%)" "内存(%)" "总内存(KB)" "可用内存(KB)"
        echo "---------------------------------------------------------------"
    fi
    
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
        mem_total_values+=("$mem_total")
        mem_available_values+=("$mem_available")
        
        write_alarm_log "$i" "$cpu_usage" "$mem_used_percent" "$mem_total" "$mem_available" "$os" "$server_id" "$CPU_THRESHOLD" "$MEM_THRESHOLD"
        
        if [ "$OUTPUT_FORMAT" = "json" ]; then
            local sample_json="{\"sample_num\":$i,\"cpu_usage\":$cpu_usage,\"memory_used_percent\":$mem_used_percent,\"memory_total_kb\":$mem_total,\"memory_available_kb\":$mem_available}"
            if [ -z "$samples_json" ]; then
                samples_json="$sample_json"
            else
                samples_json="$samples_json,$sample_json"
            fi
        else
            printf "%-6d %8s %10s %12d %15d\n" "$i" "$cpu_usage" "$mem_used_percent" "$mem_total" "$mem_available"
        fi
        
        if [ "$i" -lt "$SAMPLE_COUNT" ]; then
            if [ "$os" != "linux" ]; then
                sleep $SAMPLE_INTERVAL
            fi
        fi
    done
    
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        local cpu_stats=$(calculate_stats_json "CPU" "${cpu_values[@]}")
        local mem_stats=$(calculate_stats_json "内存" "${mem_used_values[@]}")
        
        local escaped_os=$(escape_json_string "$os")
        local escaped_server_id=$(escape_json_string "$server_id")
        local escaped_log_dir=$(escape_json_string "$log_dir")
        local escaped_log_filename=$(escape_json_string "$log_filename")
        
        cat << EOF
{
    "config": {
        "sample_count": $SAMPLE_COUNT,
        "sample_interval": $SAMPLE_INTERVAL,
        "cpu_threshold": $CPU_THRESHOLD,
        "memory_threshold": $MEM_THRESHOLD,
        "alarm_enabled": "$ALARM_ENABLED"
    },
    "system_info": {
        "os": "$escaped_os",
        "server_id": "$escaped_server_id",
        "alarm_log_file": "$escaped_log_dir/$escaped_log_filename"
    },
    "samples": [
        $samples_json
    ],
    "statistics": [
        $cpu_stats,
        $mem_stats
    ]
}
EOF
    else
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
    fi
}

main "$@"

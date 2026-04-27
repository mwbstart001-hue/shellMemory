#!/bin/bash

DEFAULT_SAMPLE_COUNT=5
DEFAULT_SAMPLE_INTERVAL=1
DEFAULT_OUTPUT_FORMAT="text"
DEFAULT_CPU_THRESHOLD=80.0
DEFAULT_MEM_THRESHOLD=80.0
DEFAULT_ALARM_ENABLED=true

init_defaults() {
    SAMPLE_COUNT=$DEFAULT_SAMPLE_COUNT
    SAMPLE_INTERVAL=$DEFAULT_SAMPLE_INTERVAL
    OUTPUT_FORMAT=$DEFAULT_OUTPUT_FORMAT
    CPU_THRESHOLD=$DEFAULT_CPU_THRESHOLD
    MEM_THRESHOLD=$DEFAULT_MEM_THRESHOLD
    ALARM_ENABLED=$DEFAULT_ALARM_ENABLED
}

load_config() {
    local config_file=""
    
    if [ -f "./monitor.conf" ]; then
        config_file="./monitor.conf"
    elif [ -f "$HOME/.monitor.conf" ]; then
        config_file="$HOME/.monitor.conf"
    fi
    
    if [ -n "$config_file" ]; then
        local line
        while IFS= read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            if [ -z "$line" ] || [[ "$line" =~ ^# ]]; then
                continue
            fi
            
            if [[ "$line" =~ ^([A-Z_]+)=(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                
                value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                value=$(echo "$value" | sed 's/^"//;s/"$//')
                value=$(echo "$value" | sed "s/^'//;s/'$//")
                
                case "$key" in
                    SAMPLE_COUNT)
                        if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -gt 0 ]; then
                            SAMPLE_COUNT="$value"
                        fi
                        ;;
                    SAMPLE_INTERVAL)
                        if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            SAMPLE_INTERVAL="$value"
                        fi
                        ;;
                    OUTPUT_FORMAT)
                        if [ "$value" = "text" ] || [ "$value" = "json" ]; then
                            OUTPUT_FORMAT="$value"
                        fi
                        ;;
                    CPU_THRESHOLD)
                        if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            CPU_THRESHOLD="$value"
                        fi
                        ;;
                    MEM_THRESHOLD)
                        if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                            MEM_THRESHOLD="$value"
                        fi
                        ;;
                    ALARM_ENABLED)
                        local lower_value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
                        if [ "$lower_value" = "true" ] || [ "$lower_value" = "1" ] || [ "$lower_value" = "yes" ]; then
                            ALARM_ENABLED="true"
                        elif [ "$lower_value" = "false" ] || [ "$lower_value" = "0" ] || [ "$lower_value" = "no" ]; then
                            ALARM_ENABLED="false"
                        fi
                        ;;
                esac
            fi
        done < "$config_file"
    fi
}

apply_env_overrides() {
    if [ -n "${ENV_SAMPLE_COUNT:-}" ]; then
        if [[ "$ENV_SAMPLE_COUNT" =~ ^[0-9]+$ ]] && [ "$ENV_SAMPLE_COUNT" -gt 0 ]; then
            SAMPLE_COUNT="$ENV_SAMPLE_COUNT"
        fi
    fi
    
    if [ -n "${ENV_SAMPLE_INTERVAL:-}" ]; then
        if [[ "$ENV_SAMPLE_INTERVAL" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            SAMPLE_INTERVAL="$ENV_SAMPLE_INTERVAL"
        fi
    fi
    
    if [ -n "${ENV_OUTPUT_FORMAT:-}" ]; then
        if [ "$ENV_OUTPUT_FORMAT" = "text" ] || [ "$ENV_OUTPUT_FORMAT" = "json" ]; then
            OUTPUT_FORMAT="$ENV_OUTPUT_FORMAT"
        fi
    fi
    
    if [ -n "${ENV_CPU_THRESHOLD:-}" ]; then
        if [[ "$ENV_CPU_THRESHOLD" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            CPU_THRESHOLD="$ENV_CPU_THRESHOLD"
        fi
    fi
    
    if [ -n "${ENV_MEM_THRESHOLD:-}" ]; then
        if [[ "$ENV_MEM_THRESHOLD" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            MEM_THRESHOLD="$ENV_MEM_THRESHOLD"
        fi
    fi
    
    if [ -n "${ENV_ALARM_ENABLED:-}" ]; then
        local lower_value=$(echo "$ENV_ALARM_ENABLED" | tr '[:upper:]' '[:lower:]')
        if [ "$lower_value" = "true" ] || [ "$lower_value" = "1" ] || [ "$lower_value" = "yes" ]; then
            ALARM_ENABLED="true"
        elif [ "$lower_value" = "false" ] || [ "$lower_value" = "0" ] || [ "$lower_value" = "no" ]; then
            ALARM_ENABLED="false"
        fi
    fi
}

show_config_help() {
    cat << EOF
用法: $0 config <子命令> [选项]

配置文件管理子命令。

子命令:
    init        在当前目录生成 monitor.conf 配置模板文件

示例:
    $0 config init              生成配置模板文件

配置文件加载优先级:
    1. ./monitor.conf (项目级，当前目录)
    2. ~/.monitor.conf (用户级，主目录)

配置文件格式:
    # 采样配置
    SAMPLE_COUNT=5           # 采样次数 (默认: 5)
    SAMPLE_INTERVAL=1        # 采样间隔，单位秒 (默认: 1)
    OUTPUT_FORMAT=text       # 输出格式: text/json (默认: text)
    
    # 告警阈值配置
    CPU_THRESHOLD=80.0       # CPU使用率告警阈值，百分比 (默认: 80.0)
    MEM_THRESHOLD=80.0       # 内存使用率告警阈值，百分比 (默认: 80.0)
    ALARM_ENABLED=true       # 是否启用告警: true/false (默认: true)

配置优先级 (后者覆盖前者):
    配置文件 -> 环境变量 -> 命令行参数

环境变量名 (可选):
    ENV_SAMPLE_COUNT, ENV_SAMPLE_INTERVAL, ENV_OUTPUT_FORMAT
    ENV_CPU_THRESHOLD, ENV_MEM_THRESHOLD, ENV_ALARM_ENABLED
EOF
}

config_init() {
    local config_file="./monitor.conf"
    
    if [ -f "$config_file" ]; then
        echo "错误: 配置文件 '$config_file' 已存在" >&2
        echo "如需重新生成，请先删除现有文件" >&2
        return 1
    fi
    
    cat > "$config_file" << 'EOF'
# ========================================
# 系统状态监控脚本 - 配置文件
# ========================================
# 
# 配置优先级 (后者覆盖前者):
#   配置文件 -> 环境变量 -> 命令行参数
#
# 配置文件加载优先级:
#   1. ./monitor.conf (项目级，当前目录)
#   2. ~/.monitor.conf (用户级，主目录)
# ========================================

# ========================================
# 采样配置
# ========================================

# 采样次数
# 每次运行脚本时执行多少次采样
# 默认值: 5
SAMPLE_COUNT=5

# 采样间隔
# 两次采样之间的等待时间，单位秒
# 默认值: 1
SAMPLE_INTERVAL=1

# 输出格式
# 可选值: text, json
# 默认值: text
OUTPUT_FORMAT=text

# ========================================
# 告警阈值配置
# ========================================

# CPU使用率告警阈值
# 当CPU使用率超过此值时触发告警，单位百分比
# 默认值: 80.0
CPU_THRESHOLD=80.0

# 内存使用率告警阈值
# 当内存使用率超过此值时触发告警，单位百分比
# 默认值: 80.0
MEM_THRESHOLD=80.0

# 是否启用告警
# 可选值: true, false, yes, no, 1, 0
# 默认值: true
ALARM_ENABLED=true

# ========================================
# 配置说明
# ========================================
# 
# 支持的环境变量 (可选，优先级高于配置文件):
#   ENV_SAMPLE_COUNT   - 覆盖 SAMPLE_COUNT
#   ENV_SAMPLE_INTERVAL - 覆盖 SAMPLE_INTERVAL
#   ENV_OUTPUT_FORMAT  - 覆盖 OUTPUT_FORMAT
#   ENV_CPU_THRESHOLD  - 覆盖 CPU_THRESHOLD
#   ENV_MEM_THRESHOLD  - 覆盖 MEM_THRESHOLD
#   ENV_ALARM_ENABLED  - 覆盖 ALARM_ENABLED
#
# 命令行参数优先级最高:
#   -n <次数>  - 覆盖采样次数
#   -i <秒数>  - 覆盖采样间隔
#   -f <格式>  - 覆盖输出格式
# ========================================
EOF
    
    if [ $? -eq 0 ]; then
        echo "配置模板已生成: $config_file"
        echo ""
        echo "配置说明:"
        echo "  - 请根据需要修改配置值"
        echo "  - 以 # 开头的行是注释"
        echo "  - 配置格式: KEY=VALUE"
        echo ""
        echo "示例:"
        echo "  SAMPLE_COUNT=10"
        echo "  CPU_THRESHOLD=90.0"
        echo "  OUTPUT_FORMAT=json"
        return 0
    else
        echo "错误: 无法创建配置文件 '$config_file'" >&2
        return 1
    fi
}

SAMPLE_COUNT=5
SAMPLE_INTERVAL=1
OUTPUT_FORMAT="text"

CPU_THRESHOLD=${CPU_THRESHOLD:-80.0}
MEM_THRESHOLD=${MEM_THRESHOLD:-80.0}

ALARM_ENABLED=${ALARM_ENABLED:-true}

show_help() {
    cat << EOF
用法: $0 [子命令] [选项]

系统状态监控脚本，支持动态配置采样参数、多种输出格式和告警历史查询。

子命令:
    query       查询告警历史记录
    stats       按天统计告警频率
    config      配置文件管理
    (无)       执行系统状态监控（默认行为）

监控选项:
    -n 次数      设置采样次数 (默认: 5)
    -i 秒数      设置采样间隔时间 (默认: 1秒)
    -f 格式      设置输出格式 (text/json, 默认: text)
    -c 阈值      设置CPU告警阈值，百分比 (默认: 80.0)
    -m 阈值      设置内存告警阈值，百分比 (默认: 80.0)
    -a true/false 设置是否启用告警 (默认: true)
    -h, --help   显示此帮助信息

查询选项 (与 query 子命令配合使用):
    -n 数量      查询最近 N 条告警 (默认: 10)
    -d 日期      筛选指定日期 (格式: YYYY-MM-DD)
    -t 类型      筛选告警类型 (cpu/memory/all, 默认: all)
    -f 格式      输出格式 (text/json, 默认: text)
    -h, --help   显示查询子命令帮助

统计选项 (与 stats 子命令配合使用):
    -d 天数      统计最近 N 天 (默认: 7)
    -t 类型      筛选告警类型 (cpu/memory/all, 默认: all)
    -f 格式      输出格式 (text/json, 默认: text)
    -h, --help   显示统计子命令帮助

配置管理选项:
    config init  在当前目录生成 monitor.conf 配置模板文件
    config help  显示配置管理帮助信息

配置文件说明:
    加载优先级 (找到第一个即停止):
        1. ./monitor.conf      (项目级，当前目录)
        2. ~/.monitor.conf     (用户级，主目录)

    配置优先级 (后者覆盖前者):
        配置文件 -> 环境变量 -> 命令行参数

    支持的配置字段:
        SAMPLE_COUNT      采样次数 (默认: 5)
        SAMPLE_INTERVAL   采样间隔，单位秒 (默认: 1)
        OUTPUT_FORMAT     输出格式: text/json (默认: text)
        CPU_THRESHOLD     CPU告警阈值，百分比 (默认: 80.0)
        MEM_THRESHOLD     内存告警阈值，百分比 (默认: 80.0)
        ALARM_ENABLED     是否启用告警: true/false (默认: true)

    支持的环境变量 (可选，优先级高于配置文件):
        ENV_SAMPLE_COUNT, ENV_SAMPLE_INTERVAL, ENV_OUTPUT_FORMAT
        ENV_CPU_THRESHOLD, ENV_MEM_THRESHOLD, ENV_ALARM_ENABLED

示例:
    $0 -n 10 -i 2          采样10次，间隔2秒，文本格式输出
    $0 -n 5 -i 1 -f json   采样5次，间隔1秒，JSON格式输出
    $0 -c 90.0 -m 85.0     设置CPU阈值90%，内存阈值85%
    $0 -a false             禁用告警功能
    $0 -c 70 -m 70 -a true  自定义阈值并启用告警
    
    $0 query -n 20          查询最近20条告警记录
    $0 query -d 2026-04-26 查询指定日期的告警记录
    $0 query -t cpu -f json 查询CPU类型的告警并以JSON格式输出
    $0 query -n 50 -t memory -f json
                            查询最近50条内存告警并以JSON格式输出
    
    $0 stats                统计最近7天告警频率
    $0 stats -d 30          统计最近30天告警频率
    $0 stats -t cpu         统计最近7天CPU告警频率
    $0 stats -d 14 -f json  统计最近14天告警频率并以JSON格式输出
    
    $0 config init          生成配置模板文件
    $0 config help          显示配置管理帮助信息
EOF
}

parse_args() {
    while getopts ":n:i:f:c:m:a:h-" opt; do
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
            c)
                if ! is_number "$OPTARG"; then
                    echo "错误: CPU阈值必须是有效的数字"
                    exit 1
                fi
                CPU_THRESHOLD=$OPTARG
                ;;
            m)
                if ! is_number "$OPTARG"; then
                    echo "错误: 内存阈值必须是有效的数字"
                    exit 1
                fi
                MEM_THRESHOLD=$OPTARG
                ;;
            a)
                local lower_value=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')
                if [ "$lower_value" = "true" ] || [ "$lower_value" = "1" ] || [ "$lower_value" = "yes" ]; then
                    ALARM_ENABLED="true"
                elif [ "$lower_value" = "false" ] || [ "$lower_value" = "0" ] || [ "$lower_value" = "no" ]; then
                    ALARM_ENABLED="false"
                else
                    echo "错误: 告警启用选项只能是 'true', 'false', 'yes', 'no', '1', '0'"
                    exit 1
                fi
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
    local year=$(date +%G)
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
    local week_year=$(date "+%G年第%V周")
    
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
        echo -e "\033[0;31m[ALARM] CPU使用率 $cpu_usage% 超过阈值 $cpu_threshold%\033[0m" >&2
    fi
    if [ "$mem_exceed" -eq 1 ]; then
        echo -e "\033[0;31m[ALARM] 内存使用率 $mem_used_percent% 超过阈值 $mem_threshold%\033[0m" >&2
    fi
}

generate_sample_json() {
    local sample_num="$1"
    local cpu_usage="$2"
    local mem_used_percent="$3"
    local mem_total="$4"
    local mem_available="$5"
    local indent="$6"
    
    printf '%s{\n' "$indent"
    printf '%s    "sample_num": %s,\n' "$indent" "$sample_num"
    printf '%s    "cpu_usage": %s,\n' "$indent" "$cpu_usage"
    printf '%s    "memory_used_percent": %s,\n' "$indent" "$mem_used_percent"
    printf '%s    "memory_total_kb": %s,\n' "$indent" "$mem_total"
    printf '%s    "memory_available_kb": %s\n' "$indent" "$mem_available"
    printf '%s}' "$indent"
}

generate_stat_json() {
    local label="$1"
    local mean="$2"
    local max="$3"
    local min="$4"
    local fluctuation="$5"
    local indent="$6"
    
    printf '%s{\n' "$indent"
    printf '%s    "label": "%s",\n' "$indent" "$label"
    printf '%s    "mean": %.2f,\n' "$indent" "$mean"
    printf '%s    "max": %.2f,\n' "$indent" "$max"
    printf '%s    "min": %.2f,\n' "$indent" "$min"
    printf '%s    "fluctuation": %.2f\n' "$indent" "$fluctuation"
    printf '%s}' "$indent"
}

show_query_help() {
    cat << EOF
用法: $0 query [选项]

查询告警历史记录。

选项:
    -n 数量      查询最近 N 条告警 (默认: 10)
    -d 日期      筛选指定日期 (格式: YYYY-MM-DD)
    -t 类型      筛选告警类型 (cpu/memory/all, 默认: all)
    -f 格式      输出格式 (text/json/csv, 默认: text)
    -h, --help   显示此帮助信息

示例:
    $0 query -n 20               查询最近20条告警记录
    $0 query -d 2026-04-26       查询指定日期的告警记录
    $0 query -t cpu -f json       查询CPU类型的告警并以JSON格式输出
    $0 query -t cpu -f csv        查询CPU类型的告警并以CSV格式输出
    $0 query -n 50 -t memory      查询最近50条内存告警
    $0 query -d 2026-04-26 -t cpu -f json
                                   查询指定日期的CPU告警并以JSON格式输出
    $0 query -n 20 -f csv
                                   查询最近20条告警并以CSV格式输出

CSV输出格式:
    timestamp,type,value,threshold,server_id
    2026-04-26 15:36:10,memory,81.30,80.0,V_AWBMA-MB0
    2026-04-26 15:35:23,cpu,82.60,80.0,V_AWBMA-MB0
EOF
}

show_stats_help() {
    cat << EOF
用法: $0 stats [选项]

按天统计告警频率。

选项:
    -d 天数      统计最近 N 天 (默认: 7)
    -t 类型      筛选告警类型 (cpu/memory/all, 默认: all)
    -f 格式      输出格式 (text/json, 默认: text)
    -h, --help   显示此帮助信息

示例:
    $0 stats                    统计最近7天告警频率
    $0 stats -d 30              统计最近30天告警频率
    $0 stats -t cpu             统计最近7天CPU告警频率
    $0 stats -t memory          统计最近7天内存告警频率
    $0 stats -d 14 -f json      统计最近14天告警频率并以JSON格式输出
EOF
}

is_valid_date() {
    local date_str="$1"
    if [[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        date -j -f "%Y-%m-%d" "$date_str" +"%Y-%m-%d" >/dev/null 2>&1
        return $?
    fi
    return 1
}

parse_query_args() {
    local QUERY_COUNT=10
    local QUERY_DATE=""
    local QUERY_TYPE="all"
    local QUERY_FORMAT="text"
    
    while getopts ":n:d:t:f:h-" opt; do
        case $opt in
            n)
                if ! is_number "$OPTARG"; then
                    echo "错误: 查询数量必须是有效的数字" >&2
                    exit 1
                fi
                if [ "$OPTARG" -lt 1 ]; then
                    echo "错误: 查询数量必须大于0" >&2
                    exit 1
                fi
                QUERY_COUNT=$OPTARG
                ;;
            d)
                if ! is_valid_date "$OPTARG"; then
                    echo "错误: 无效的日期格式，请使用 YYYY-MM-DD 格式" >&2
                    exit 1
                fi
                QUERY_DATE=$OPTARG
                ;;
            t)
                case "$OPTARG" in
                    cpu|memory|all)
                        QUERY_TYPE=$OPTARG
                        ;;
                    CPU)
                        QUERY_TYPE="cpu"
                        ;;
                    MEMORY|Memory)
                        QUERY_TYPE="memory"
                        ;;
                    ALL|All)
                        QUERY_TYPE="all"
                        ;;
                    *)
                        echo "错误: 告警类型只能是 'cpu'、'memory' 或 'all'" >&2
                        exit 1
                        ;;
                esac
                ;;
            f)
                case "$OPTARG" in
                    text|json)
                        QUERY_FORMAT=$OPTARG
                        ;;
                    TEXT|JSON)
                        QUERY_FORMAT=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')
                        ;;
                    *)
                        echo "错误: 输出格式只能是 'text' 或 'json'" >&2
                        exit 1
                        ;;
                esac
                ;;
            h)
                show_query_help
                exit 0
                ;;
            -)
                case "${OPTARG}" in
                    help)
                        show_query_help
                        exit 0
                        ;;
                    *)
                        echo "错误: 无效选项 --$OPTARG" >&2
                        show_query_help
                        exit 1
                        ;;
                esac
                ;;
            \?)
                echo "错误: 无效选项 -$OPTARG" >&2
                show_query_help
                exit 1
                ;;
            :)
                echo "错误: 选项 -$OPTARG 需要参数" >&2
                show_query_help
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))
    
    echo "$QUERY_COUNT|$QUERY_DATE|$QUERY_TYPE|$QUERY_FORMAT"
}

GLOBAL_RAW_ALARMS=()
GLOBAL_FILTERED_ALARMS=()
GLOBAL_STATS_DAYS=()
GLOBAL_STATS_TOTAL=()

parse_alarm_logs() {
    local log_dir="$1"
    
    if [ ! -d "$log_dir" ]; then
        return 0
    fi
    
    local log_file
    local line
    local timestamp
    local week_year
    local sample_num
    local server_id
    local os
    local mem_total
    local mem_available
    local cpu_value
    local cpu_threshold
    local mem_value
    local mem_threshold
    
    while IFS= read -r -d '' log_file; do
        if [ ! -f "$log_file" ]; then
            continue
        fi
        
        while IFS= read -r line; do
            if [ -z "$line" ]; then
                continue
            fi
            
            if [[ "$line" =~ \[([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2})\]\ \[([^]]+)\]\ \[采样=([0-9]+)\]\ \[ServerID=([^]]+)\]\ \[OS=([^]]+)\]\ 总内存=([0-9]+)KB\ 可用内存=([0-9]+)KB ]]; then
                timestamp="${BASH_REMATCH[1]}"
                week_year="${BASH_REMATCH[2]}"
                sample_num="${BASH_REMATCH[3]}"
                server_id="${BASH_REMATCH[4]}"
                os="${BASH_REMATCH[5]}"
                mem_total="${BASH_REMATCH[6]}"
                mem_available="${BASH_REMATCH[7]}"
                
                local alarm_entry=""
                alarm_entry+="timestamp=$timestamp|"
                alarm_entry+="week_year=$week_year|"
                alarm_entry+="sample_num=$sample_num|"
                alarm_entry+="server_id=$server_id|"
                alarm_entry+="os=$os|"
                alarm_entry+="mem_total=$mem_total|"
                alarm_entry+="mem_available=$mem_available|"
                
                if [[ "$line" =~ CPU=([0-9.]+)%\ \(阈值=([0-9.]+)%\) ]]; then
                    cpu_value="${BASH_REMATCH[1]}"
                    cpu_threshold="${BASH_REMATCH[2]}"
                    GLOBAL_RAW_ALARMS+=("${alarm_entry}type=cpu|value=$cpu_value|threshold=$cpu_threshold")
                fi
                
                if [[ "$line" =~ 内存=([0-9.]+)%\ \(阈值=([0-9.]+)%\) ]]; then
                    mem_value="${BASH_REMATCH[1]}"
                    mem_threshold="${BASH_REMATCH[2]}"
                    GLOBAL_RAW_ALARMS+=("${alarm_entry}type=memory|value=$mem_value|threshold=$mem_threshold")
                fi
            fi
        done < "$log_file"
    done < <(find "$log_dir" -name "alarm_*.log" -type f 2>/dev/null -print0 | sort -z)
}

filter_alarms() {
    local query_date="$1"
    local query_type="$2"
    local query_count="$3"
    
    GLOBAL_FILTERED_ALARMS=()
    
    if [ ${#GLOBAL_RAW_ALARMS[@]} -eq 0 ]; then
        return 0
    fi
    
    local -a temp_list=()
    local entry
    local timestamp
    local alarm_type
    
    for entry in "${GLOBAL_RAW_ALARMS[@]}"; do
        if [[ "$entry" =~ timestamp=([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}) ]]; then
            timestamp="${BASH_REMATCH[1]}"
        else
            continue
        fi
        
        if [[ "$entry" =~ type=([a-z]+) ]]; then
            alarm_type="${BASH_REMATCH[1]}"
        else
            continue
        fi
        
        if [ -n "$query_date" ]; then
            local entry_date="${timestamp%% *}"
            if [ "$entry_date" != "$query_date" ]; then
                continue
            fi
        fi
        
        if [ "$query_type" != "all" ] && [ "$alarm_type" != "$query_type" ]; then
            continue
        fi
        
        temp_list+=("$timestamp|$entry")
    done
    
    if [ ${#temp_list[@]} -eq 0 ]; then
        return 0
    fi
    
    local -a sorted_list=()
    while IFS= read -r line; do
        [ -n "$line" ] && sorted_list+=("$line")
    done < <(printf '%s\n' "${temp_list[@]}" | sort -r)
    
    local count=0
    local item
    local -a selected_list=()
    for item in "${sorted_list[@]}"; do
        if [ $count -ge "$query_count" ]; then
            break
        fi
        
        local entry_data="${item#*|}"
        selected_list+=("$entry_data")
        ((count++))
    done
    
    if [ ${#selected_list[@]} -eq 0 ]; then
        return 0
    fi

    while IFS= read -r line; do
        [ -n "$line" ] && GLOBAL_FILTERED_ALARMS+=("$line")
    done < <(printf '%s\n' "${selected_list[@]}" | tail -r)
}

extract_alarm_field() {
    local entry="$1"
    local field_name="$2"
    
    if [[ "$entry" =~ $field_name=([^|]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

output_alarms_text() {
    local query_count="$1"
    local query_date="$2"
    local query_type="$3"
    
    if [ ${#GLOBAL_FILTERED_ALARMS[@]} -eq 0 ]; then
        echo "========================================"
        echo "告警历史查询结果"
        echo "========================================"
        echo ""
        echo "查询条件:"
        echo "  数量: 最近 $query_count 条"
        if [ -n "$query_date" ]; then
            echo "  日期: $query_date"
        fi
        echo "  类型: $query_type"
        echo ""
        echo "----------------------------------------"
        echo "未找到任何告警记录"
        echo "========================================"
        return 0
    fi
    
    echo "========================================"
    echo "告警历史查询结果"
    echo "========================================"
    echo ""
    echo "查询条件:"
    echo "  数量: 最近 $query_count 条"
    if [ -n "$query_date" ]; then
        echo "  日期: $query_date"
    fi
    echo "  类型: $query_type"
    echo ""
    echo "查询结果: 共 ${#GLOBAL_FILTERED_ALARMS[@]} 条告警记录"
    echo "========================================"
    echo ""
    
    printf "%-20s %-8s %-12s %-12s %-8s\n" "时间" "类型" "当前值(%)" "阈值(%)" "服务器ID"
    echo "-------------------------------------------------------------------------"
    
    local entry
    for entry in "${GLOBAL_FILTERED_ALARMS[@]}"; do
        local timestamp=$(extract_alarm_field "$entry" "timestamp")
        local alarm_type=$(extract_alarm_field "$entry" "type")
        local value=$(extract_alarm_field "$entry" "value")
        local threshold=$(extract_alarm_field "$entry" "threshold")
        local server_id=$(extract_alarm_field "$entry" "server_id")
        
        local display_type
        if [ "$alarm_type" = "cpu" ]; then
            display_type="CPU"
        elif [ "$alarm_type" = "memory" ]; then
            display_type="内存"
        else
            display_type="$alarm_type"
        fi
        
        printf "%-20s %-8s %-12s %-12s %-8s\n" "$timestamp" "$display_type" "$value" "$threshold" "$server_id"
    done
    
    echo "-------------------------------------------------------------------------"
    echo ""
    echo "查询完成！"
}

output_alarms_json() {
    local query_count="$1"
    local query_date="$2"
    local query_type="$3"
    
    echo "{"
    echo "    \"query_info\": {"
    echo "        \"count_requested\": $query_count,"
    if [ -n "$query_date" ]; then
        echo "        \"filter_date\": \"$query_date\","
    else
        echo "        \"filter_date\": null,"
    fi
    echo "        \"filter_type\": \"$query_type\","
    echo "        \"count_found\": ${#GLOBAL_FILTERED_ALARMS[@]}"
    echo "    },"
    
    if [ ${#GLOBAL_FILTERED_ALARMS[@]} -eq 0 ]; then
        echo "    \"alarms\": []"
    else
        echo "    \"alarms\": ["
        
        local entry
        local -i index=0
        local total=${#GLOBAL_FILTERED_ALARMS[@]}
        
        for entry in "${GLOBAL_FILTERED_ALARMS[@]}"; do
            local timestamp=$(extract_alarm_field "$entry" "timestamp")
            local week_year=$(extract_alarm_field "$entry" "week_year")
            local sample_num=$(extract_alarm_field "$entry" "sample_num")
            local server_id=$(extract_alarm_field "$entry" "server_id")
            local os=$(extract_alarm_field "$entry" "os")
            local mem_total=$(extract_alarm_field "$entry" "mem_total")
            local mem_available=$(extract_alarm_field "$entry" "mem_available")
            local alarm_type=$(extract_alarm_field "$entry" "type")
            local value=$(extract_alarm_field "$entry" "value")
            local threshold=$(extract_alarm_field "$entry" "threshold")
            
            local escaped_timestamp=$(escape_json_string "$timestamp")
            local escaped_week_year=$(escape_json_string "$week_year")
            local escaped_server_id=$(escape_json_string "$server_id")
            local escaped_os=$(escape_json_string "$os")
            local escaped_type=$(escape_json_string "$alarm_type")
            
            echo "        {"
            echo "            \"timestamp\": \"$escaped_timestamp\","
            echo "            \"week_year\": \"$escaped_week_year\","
            echo "            \"sample_num\": $sample_num,"
            echo "            \"server_id\": \"$escaped_server_id\","
            echo "            \"os\": \"$escaped_os\","
            echo "            \"memory_total_kb\": $mem_total,"
            echo "            \"memory_available_kb\": $mem_available,"
            echo "            \"type\": \"$escaped_type\","
            echo "            \"value\": $value,"
            echo "            \"threshold\": $threshold"
            
            if [ $index -lt $((total - 1)) ]; then
                echo "        },"
            else
                echo "        }"
            fi
            
            ((index++))
        done
        
        echo "    ]"
    fi
    
    echo "}"
}

escape_csv_field() {
    local field="$1"
    
    if [[ "$field" == *,* ]] || [[ "$field" == *'"'* ]] || [[ "$field" == *$'\n'* ]] || [[ "$field" == *' '* ]]; then
        field="${field//\"/\"\"}"
        echo "\"$field\""
    else
        echo "$field"
    fi
}

output_alarms_csv() {
    local query_count="$1"
    local query_date="$2"
    local query_type="$3"
    
    echo "timestamp,type,value,threshold,server_id"
    
    if [ ${#GLOBAL_FILTERED_ALARMS[@]} -eq 0 ]; then
        return 0
    fi
    
    local entry
    for entry in "${GLOBAL_FILTERED_ALARMS[@]}"; do
        local timestamp=$(extract_alarm_field "$entry" "timestamp")
        local alarm_type=$(extract_alarm_field "$entry" "type")
        local value=$(extract_alarm_field "$entry" "value")
        local threshold=$(extract_alarm_field "$entry" "threshold")
        local server_id=$(extract_alarm_field "$entry" "server_id")
        
        local escaped_timestamp=$(escape_csv_field "$timestamp")
        local escaped_type=$(escape_csv_field "$alarm_type")
        local escaped_value=$(escape_csv_field "$value")
        local escaped_threshold=$(escape_csv_field "$threshold")
        local escaped_server_id=$(escape_csv_field "$server_id")
        
        echo "$escaped_timestamp,$escaped_type,$escaped_value,$escaped_threshold,$escaped_server_id"
    done
}

query_alarms() {
    shift
    
    for arg in "$@"; do
        if [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
            show_query_help
            exit 0
        fi
    done
    
    local QUERY_COUNT=10
    local QUERY_DATE=""
    local QUERY_TYPE="all"
    local QUERY_FORMAT="text"
    
    OPTIND=1
    while getopts ":n:d:t:f:h-" opt; do
        case $opt in
            n)
                if ! is_number "$OPTARG"; then
                    echo "错误: 查询数量必须是有效的数字" >&2
                    show_query_help
                    exit 1
                fi
                if [ "$OPTARG" -lt 1 ]; then
                    echo "错误: 查询数量必须大于0" >&2
                    show_query_help
                    exit 1
                fi
                QUERY_COUNT=$OPTARG
                ;;
            d)
                if ! is_valid_date "$OPTARG"; then
                    echo "错误: 无效的日期格式，请使用 YYYY-MM-DD 格式" >&2
                    show_query_help
                    exit 1
                fi
                QUERY_DATE=$OPTARG
                ;;
            t)
                case "$OPTARG" in
                    cpu|memory|all)
                        QUERY_TYPE=$OPTARG
                        ;;
                    CPU)
                        QUERY_TYPE="cpu"
                        ;;
                    MEMORY|Memory)
                        QUERY_TYPE="memory"
                        ;;
                    ALL|All)
                        QUERY_TYPE="all"
                        ;;
                    *)
                        echo "错误: 告警类型只能是 'cpu'、'memory' 或 'all'" >&2
                        show_query_help
                        exit 1
                        ;;
                esac
                ;;
            f)
                case "$OPTARG" in
                    text|json|csv)
                        QUERY_FORMAT=$OPTARG
                        ;;
                    TEXT|JSON|CSV)
                        QUERY_FORMAT=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')
                        ;;
                    *)
                        echo "错误: 输出格式只能是 'text'、'json' 或 'csv'" >&2
                        show_query_help
                        exit 1
                        ;;
                esac
                ;;
            h)
                show_query_help
                exit 0
                ;;
            -)
                case "${OPTARG}" in
                    help)
                        show_query_help
                        exit 0
                        ;;
                    *)
                        echo "错误: 无效选项 --$OPTARG" >&2
                        show_query_help
                        exit 1
                        ;;
                esac
                ;;
            \?)
                echo "错误: 无效选项 -$OPTARG" >&2
                show_query_help
                exit 1
                ;;
            :)
                echo "错误: 选项 -$OPTARG 需要参数" >&2
                show_query_help
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))
    
    local log_dir="./logs"
    
    GLOBAL_RAW_ALARMS=()
    GLOBAL_FILTERED_ALARMS=()
    
    if [ -d "$log_dir" ]; then
        parse_alarm_logs "$log_dir"
    fi
    
    filter_alarms "$QUERY_DATE" "$QUERY_TYPE" "$QUERY_COUNT"
    
    if [ "$QUERY_FORMAT" = "json" ]; then
        output_alarms_json "$QUERY_COUNT" "$QUERY_DATE" "$QUERY_TYPE"
    elif [ "$QUERY_FORMAT" = "csv" ]; then
        output_alarms_csv "$QUERY_COUNT" "$QUERY_DATE" "$QUERY_TYPE"
    else
        output_alarms_text "$QUERY_COUNT" "$QUERY_DATE" "$QUERY_TYPE"
    fi
}

calculate_daily_stats() {
    local days_count="$1"
    local query_type="$2"
    
    GLOBAL_STATS_DAYS=()
    GLOBAL_STATS_TOTAL=()
    
    if [ ${#GLOBAL_RAW_ALARMS[@]} -eq 0 ]; then
        GLOBAL_STATS_TOTAL=("total_count=0" "total_cpu=0" "total_memory=0")
        return 0
    fi
    
    local total_count=0
    local total_cpu=0
    local total_memory=0
    
    local today=$(date "+%Y-%m-%d")
    local today_sec=$(date -j -f "%Y-%m-%d" "$today" "+%s" 2>/dev/null || echo "0")
    local cutoff_sec=$(( today_sec - days_count * 86400 ))
    
    local -a filtered_entries=()
    local entry
    local timestamp
    local alarm_type
    local entry_date
    local entry_sec
    
    for entry in "${GLOBAL_RAW_ALARMS[@]}"; do
        if [[ "$entry" =~ timestamp=([0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}) ]]; then
            timestamp="${BASH_REMATCH[1]}"
        else
            continue
        fi
        
        if [[ "$entry" =~ type=([a-z]+) ]]; then
            alarm_type="${BASH_REMATCH[1]}"
        else
            continue
        fi
        
        if [ "$query_type" != "all" ] && [ "$alarm_type" != "$query_type" ]; then
            continue
        fi
        
        entry_date="${timestamp%% *}"
        entry_sec=$(date -j -f "%Y-%m-%d" "$entry_date" "+%s" 2>/dev/null || echo "0")
        
        if [ "$entry_sec" -lt "$cutoff_sec" ]; then
            continue
        fi
        
        filtered_entries+=("${entry_date}|${alarm_type}")
    done
    
    if [ ${#filtered_entries[@]} -eq 0 ]; then
        GLOBAL_STATS_TOTAL=("total_count=0" "total_cpu=0" "total_memory=0")
        return 0
    fi
    
    local -a sorted_entries=()
    while IFS= read -r line; do
        [ -n "$line" ] && sorted_entries+=("$line")
    done < <(printf '%s\n' "${filtered_entries[@]}" | sort)
    
    local current_date=""
    local day_count=0
    local day_cpu=0
    local day_memory=0
    
    local item
    local item_date
    local item_type
    
    for item in "${sorted_entries[@]}"; do
        item_date="${item%%|*}"
        item_type="${item#*|}"
        
        if [ "$current_date" != "$item_date" ]; then
            if [ -n "$current_date" ]; then
                GLOBAL_STATS_DAYS+=("date=${current_date}|count=${day_count}|cpu_count=${day_cpu}|memory_count=${day_memory}")
            fi
            current_date="$item_date"
            day_count=0
            day_cpu=0
            day_memory=0
        fi
        
        ((day_count++))
        ((total_count++))
        
        if [ "$item_type" = "cpu" ]; then
            ((day_cpu++))
            ((total_cpu++))
        elif [ "$item_type" = "memory" ]; then
            ((day_memory++))
            ((total_memory++))
        fi
    done
    
    if [ -n "$current_date" ]; then
        GLOBAL_STATS_DAYS+=("date=${current_date}|count=${day_count}|cpu_count=${day_cpu}|memory_count=${day_memory}")
    fi
    
    GLOBAL_STATS_TOTAL=("total_count=$total_count" "total_cpu=$total_cpu" "total_memory=$total_memory")
}

extract_stats_field() {
    local entry="$1"
    local field_name="$2"
    
    if [[ "$entry" =~ $field_name=([^|]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

output_stats_text() {
    local days_count="$1"
    local query_type="$2"
    
    echo "========================================"
    echo "告警频率统计结果"
    echo "========================================"
    echo ""
    echo "查询条件:"
    echo "  时间范围: 最近 $days_count 天"
    echo "  类型: $query_type"
    echo ""
    
    local total_count=$(extract_stats_field "${GLOBAL_STATS_TOTAL[0]}" "total_count")
    local total_cpu=$(extract_stats_field "${GLOBAL_STATS_TOTAL[1]}" "total_cpu")
    local total_memory=$(extract_stats_field "${GLOBAL_STATS_TOTAL[2]}" "total_memory")
    
    if [ ${#GLOBAL_STATS_DAYS[@]} -eq 0 ]; then
        echo "----------------------------------------"
        echo "未找到任何告警记录"
        echo "========================================"
        return 0
    fi
    
    echo "统计汇总:"
    echo "  总告警次数: $total_count"
    if [ "$query_type" = "all" ]; then
        echo "  CPU告警: $total_cpu 次"
        echo "  内存告警: $total_memory 次"
    fi
    echo "========================================"
    echo ""
    
    if [ "$query_type" = "all" ]; then
        printf "%-12s %-8s %-8s %-8s\n" "日期" "总次数" "CPU次数" "内存次数"
        echo "----------------------------------------"
        
        local entry
        for entry in "${GLOBAL_STATS_DAYS[@]}"; do
            local date=$(extract_stats_field "$entry" "date")
            local count=$(extract_stats_field "$entry" "count")
            local cpu_count=$(extract_stats_field "$entry" "cpu_count")
            local memory_count=$(extract_stats_field "$entry" "memory_count")
            
            printf "%-12s %-8s %-8s %-8s\n" "$date" "$count" "$cpu_count" "$memory_count"
        done
    else
        printf "%-12s %-8s\n" "日期" "告警次数"
        echo "----------------------------------------"
        
        local entry
        for entry in "${GLOBAL_STATS_DAYS[@]}"; do
            local date=$(extract_stats_field "$entry" "date")
            local count=$(extract_stats_field "$entry" "count")
            
            printf "%-12s %-8s\n" "$date" "$count"
        done
    fi
    
    echo "----------------------------------------"
    echo ""
    echo "统计完成！"
}

output_stats_json() {
    local days_count="$1"
    local query_type="$2"
    
    local total_count=$(extract_stats_field "${GLOBAL_STATS_TOTAL[0]}" "total_count")
    local total_cpu=$(extract_stats_field "${GLOBAL_STATS_TOTAL[1]}" "total_cpu")
    local total_memory=$(extract_stats_field "${GLOBAL_STATS_TOTAL[2]}" "total_memory")
    
    echo "{"
    echo "    \"query_info\": {"
    echo "        \"days_requested\": $days_count,"
    echo "        \"filter_type\": \"$query_type\""
    echo "    },"
    echo "    \"total\": {"
    echo "        \"total_count\": $total_count,"
    echo "        \"cpu_count\": $total_cpu,"
    echo "        \"memory_count\": $total_memory"
    echo "    },"
    
    if [ ${#GLOBAL_STATS_DAYS[@]} -eq 0 ]; then
        echo "    \"days\": []"
    else
        echo "    \"days\": ["
        
        local entry
        local -i index=0
        local total=${#GLOBAL_STATS_DAYS[@]}
        
        for entry in "${GLOBAL_STATS_DAYS[@]}"; do
            local date=$(extract_stats_field "$entry" "date")
            local count=$(extract_stats_field "$entry" "count")
            local cpu_count=$(extract_stats_field "$entry" "cpu_count")
            local memory_count=$(extract_stats_field "$entry" "memory_count")
            
            echo "        {"
            echo "            \"date\": \"$date\","
            echo "            \"total_count\": $count,"
            echo "            \"cpu_count\": $cpu_count,"
            echo "            \"memory_count\": $memory_count"
            
            if [ $index -lt $((total - 1)) ]; then
                echo "        },"
            else
                echo "        }"
            fi
            
            ((index++))
        done
        
        echo "    ]"
    fi
    
    echo "}"
}

stats_alarms() {
    shift
    
    for arg in "$@"; do
        if [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
            show_stats_help
            exit 0
        fi
    done
    
    local STATS_DAYS=7
    local STATS_TYPE="all"
    local STATS_FORMAT="text"
    
    OPTIND=1
    while getopts ":d:t:f:h-" opt; do
        case $opt in
            d)
                if ! is_number "$OPTARG"; then
                    echo "错误: 天数必须是有效的数字" >&2
                    show_stats_help
                    exit 1
                fi
                if [ "$OPTARG" -lt 1 ]; then
                    echo "错误: 天数必须大于0" >&2
                    show_stats_help
                    exit 1
                fi
                STATS_DAYS=$OPTARG
                ;;
            t)
                case "$OPTARG" in
                    cpu|memory|all)
                        STATS_TYPE=$OPTARG
                        ;;
                    CPU)
                        STATS_TYPE="cpu"
                        ;;
                    MEMORY|Memory)
                        STATS_TYPE="memory"
                        ;;
                    ALL|All)
                        STATS_TYPE="all"
                        ;;
                    *)
                        echo "错误: 告警类型只能是 'cpu'、'memory' 或 'all'" >&2
                        show_stats_help
                        exit 1
                        ;;
                esac
                ;;
            f)
                case "$OPTARG" in
                    text|json)
                        STATS_FORMAT=$OPTARG
                        ;;
                    TEXT|JSON)
                        STATS_FORMAT=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')
                        ;;
                    *)
                        echo "错误: 输出格式只能是 'text' 或 'json'" >&2
                        show_stats_help
                        exit 1
                        ;;
                esac
                ;;
            h)
                show_stats_help
                exit 0
                ;;
            -)
                case "${OPTARG}" in
                    help)
                        show_stats_help
                        exit 0
                        ;;
                    *)
                        echo "错误: 无效选项 --$OPTARG" >&2
                        show_stats_help
                        exit 1
                        ;;
                esac
                ;;
            \?)
                echo "错误: 无效选项 -$OPTARG" >&2
                show_stats_help
                exit 1
                ;;
            :)
                echo "错误: 选项 -$OPTARG 需要参数" >&2
                show_stats_help
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))
    
    local log_dir="./logs"
    
    GLOBAL_RAW_ALARMS=()
    GLOBAL_STATS_DAYS=()
    GLOBAL_STATS_TOTAL=()
    
    if [ -d "$log_dir" ]; then
        parse_alarm_logs "$log_dir"
    fi
    
    calculate_daily_stats "$STATS_DAYS" "$STATS_TYPE"
    
    if [ "$STATS_FORMAT" = "json" ]; then
        output_stats_json "$STATS_DAYS" "$STATS_TYPE"
    else
        output_stats_text "$STATS_DAYS" "$STATS_TYPE"
    fi
}

main() {
    if [ "$1" = "config" ]; then
        shift
        if [ "$1" = "init" ]; then
            config_init
            return $?
        elif [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
            show_config_help
            return 0
        else
            if [ -n "$1" ]; then
                echo "错误: 未知的 config 子命令: $1" >&2
            fi
            show_config_help
            return 1
        fi
    fi
    
    if [ "$1" = "query" ]; then
        query_alarms "$@"
        return $?
    fi
    
    if [ "$1" = "stats" ]; then
        stats_alarms "$@"
        return $?
    fi
    
    init_defaults
    load_config
    apply_env_overrides
    
    parse_args "$@"
    
    local os=$(get_os_type)
    local server_id=$(get_server_id)
    local log_dir=$(get_alarm_log_dir)
    local log_filename=$(get_weekly_log_filename)
    
    local cpu_values=()
    local mem_used_values=()
    local mem_total_values=()
    local mem_available_values=()
    local -a sample_jsons=()
    
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
            local sample_json=$(generate_sample_json "$i" "$cpu_usage" "$mem_used_percent" "$mem_total" "$mem_available" "        ")
            sample_jsons+=("$sample_json")
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
        local cpu_stats=$(printf "%s\n" "${cpu_values[@]}" | awk '
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
                printf "%.2f %.2f %.2f %.2f", mean, max, min, fluctuation
            } else {
                printf "0.00 0.00 0.00 0.00"
            }
        }
        ')
        
        local mem_stats=$(printf "%s\n" "${mem_used_values[@]}" | awk '
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
                printf "%.2f %.2f %.2f %.2f", mean, max, min, fluctuation
            } else {
                printf "0.00 0.00 0.00 0.00"
            }
        }
        ')
        
        local cpu_mean=$(echo "$cpu_stats" | awk '{print $1}')
        local cpu_max=$(echo "$cpu_stats" | awk '{print $2}')
        local cpu_min=$(echo "$cpu_stats" | awk '{print $3}')
        local cpu_fluctuation=$(echo "$cpu_stats" | awk '{print $4}')
        
        local mem_mean=$(echo "$mem_stats" | awk '{print $1}')
        local mem_max=$(echo "$mem_stats" | awk '{print $2}')
        local mem_min=$(echo "$mem_stats" | awk '{print $3}')
        local mem_fluctuation=$(echo "$mem_stats" | awk '{print $4}')
        
        local cpu_stat_json=$(generate_stat_json "CPU" "$cpu_mean" "$cpu_max" "$cpu_min" "$cpu_fluctuation" "        ")
        local mem_stat_json=$(generate_stat_json "内存" "$mem_mean" "$mem_max" "$mem_min" "$mem_fluctuation" "        ")
        
        local escaped_os=$(escape_json_string "$os")
        local escaped_server_id=$(escape_json_string "$server_id")
        local escaped_log_dir=$(escape_json_string "$log_dir")
        local escaped_log_filename=$(escape_json_string "$log_filename")
        
        echo "{"
        echo "    \"config\": {"
        echo "        \"sample_count\": $SAMPLE_COUNT,"
        echo "        \"sample_interval\": $SAMPLE_INTERVAL,"
        echo "        \"cpu_threshold\": $CPU_THRESHOLD,"
        echo "        \"memory_threshold\": $MEM_THRESHOLD,"
        echo "        \"alarm_enabled\": \"$ALARM_ENABLED\""
        echo "    },"
        echo "    \"system_info\": {"
        echo "        \"os\": \"$escaped_os\","
        echo "        \"server_id\": \"$escaped_server_id\","
        echo "        \"alarm_log_file\": \"$escaped_log_dir/$escaped_log_filename\""
        echo "    },"
        echo "    \"samples\": ["
        
        local sample_count=${#sample_jsons[@]}
        for ((i=0; i<sample_count; i++)); do
            if [ $i -lt $((sample_count - 1)) ]; then
                echo "${sample_jsons[$i]},"
            else
                echo "${sample_jsons[$i]}"
            fi
        done
        
        echo "    ],"
        echo "    \"statistics\": ["
        echo "$cpu_stat_json,"
        echo "$mem_stat_json"
        echo "    ]"
        echo "}"
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

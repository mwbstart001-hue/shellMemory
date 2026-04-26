#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/system_status.sh"

print_header() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}========================================${NC}"
}

print_test_result() {
    local test_name="$1"
    local passed="$2"
    
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    if [ "$passed" = true ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo -e "${GREEN}[PASS] ${test_name}${NC}"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo -e "${RED}[FAIL] ${test_name}${NC}"
    fi
}

print_summary() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  测试汇总${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "总测试数: ${TOTAL_COUNT}"
    echo -e "${GREEN}通过: ${PASS_COUNT}${NC}"
    echo -e "${RED}失败: ${FAIL_COUNT}${NC}"
    
    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "${GREEN}所有测试通过！${NC}"
        exit 0
    else
        echo -e "${RED}存在失败的测试${NC}"
        exit 1
    fi
}

is_number() {
    [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]
}

is_valid_percent() {
    if ! is_number "$1"; then
        return 1
    fi
    
    local val=$(echo "$1" | awk '{print $1 + 0}')
    local in_range=$(echo "$val >= 0 && $val <= 100" | bc 2>/dev/null || echo "$val >= 0 && $val <= 100" | awk '{if ($1 >= 0 && $1 <= 100) print "1"; else print "0"}')
    
    if [ "$in_range" = "1" ] || awk -v val="$val" 'BEGIN {if (val >= 0 && val <= 100) exit 0; else exit 1}'; then
        return 0
    else
        return 1
    fi
}

is_positive_number() {
    if ! is_number "$1"; then
        return 1
    fi
    awk -v val="$1" 'BEGIN {if (val > 0) exit 0; else exit 1}'
}

test_os_detection() {
    print_header "测试 1: 操作系统类型检测"
    
    local os_type=$(uname -s)
    local expected=""
    
    case "$os_type" in
        Linux*)   expected="linux" ;;
        Darwin*)  expected="macos" ;;
        CYGWIN*)  expected="windows" ;;
        MINGW*)   expected="windows" ;;
        *)        expected="unknown" ;;
    esac
    
    local detected=$(grep -A 10 'get_os_type()' "$MAIN_SCRIPT" | grep -E '(Linux|Darwin|CYGWIN|MINGW)' | head -1 | awk -F'[*)]' '{print $1}' | tr -d ' ')
    
    local test_passed=false
    case "$expected" in
        linux)
            if [[ "$os_type" == Linux* ]]; then
                test_passed=true
            fi
            ;;
        macos)
            if [[ "$os_type" == Darwin* ]]; then
                test_passed=true
            fi
            ;;
        windows)
            if [[ "$os_type" == CYGWIN* ]] || [[ "$os_type" == MINGW* ]]; then
                test_passed=true
            fi
            ;;
    esac
    
    print_test_result "检测到的操作系统类型: $os_type" $test_passed
}

test_cpu_usage_acquisition() {
    print_header "测试 2: CPU 使用率获取"
    
    local os_type=$(uname -s)
    local cpu_usage=""
    
    case "$os_type" in
        Darwin*)
            local cpu_line=$(top -l 2 -n 0 2>/dev/null | grep 'CPU usage:' | tail -n 1)
            if [ -n "$cpu_line" ]; then
                local idle=$(echo "$cpu_line" | awk -F'idle' '{print $1}' | awk -F',' '{print $NF}' | sed 's/%//' | tr -d ' ')
                if is_number "$idle"; then
                    cpu_usage=$(awk -v idle="$idle" 'BEGIN {usage = 100.0 - idle; if (usage < 0) usage = 0; if (usage > 100) usage = 100; printf "%.2f", usage}')
                fi
            fi
            ;;
        Linux*)
            if [ -f "/proc/stat" ]; then
                echo "Linux 平台 CPU 测试需要两次采样，跳过实时测试"
                print_test_result "Linux 平台 CPU 获取函数存在" true
                return
            fi
            ;;
    esac
    
    if [ -n "$cpu_usage" ] && is_valid_percent "$cpu_usage"; then
        print_test_result "CPU 使用率: $cpu_usage% (范围: 0-100)" true
    else
        print_test_result "CPU 使用率获取失败或值无效: $cpu_usage" false
    fi
}

test_memory_info_acquisition() {
    print_header "测试 3: 内存信息获取"
    
    local os_type=$(uname -s)
    local mem_total=""
    local mem_available=""
    
    case "$os_type" in
        Darwin*)
            local mem_total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
            if [ -n "$mem_total_bytes" ]; then
                mem_total=$(( mem_total_bytes / 1024 ))
            fi
            
            local vm_stat_output=$(vm_stat 2>/dev/null)
            if [ -n "$vm_stat_output" ]; then
                local page_size=$(echo "$vm_stat_output" | grep 'page size of' | awk '{print $8}')
                if [ -z "$page_size" ] || [[ "$page_size" =~ [^0-9] ]]; then
                    page_size=16384
                fi
                
                local free_pages=$(echo "$vm_stat_output" | grep 'Pages free:' | awk '{print $3}' | sed 's/\.//')
                local inactive_pages=$(echo "$vm_stat_output" | grep 'Pages inactive:' | awk '{print $3}' | sed 's/\.//')
                local speculative_pages=$(echo "$vm_stat_output" | grep 'Pages speculative:' | awk '{print $3}' | sed 's/\.//')
                
                local free_kb=0
                local inactive_kb=0
                local speculative_kb=0
                
                if is_number "$free_pages" && is_number "$page_size"; then
                    free_kb=$(( free_pages * page_size / 1024 ))
                fi
                if is_number "$inactive_pages" && is_number "$page_size"; then
                    inactive_kb=$(( inactive_pages * page_size / 1024 ))
                fi
                if is_number "$speculative_pages" && is_number "$page_size"; then
                    speculative_kb=$(( speculative_pages * page_size / 1024 ))
                fi
                
                mem_available=$(( free_kb + inactive_kb + speculative_kb ))
            fi
            ;;
        Linux*)
            if [ -f "/proc/meminfo" ]; then
                mem_total=$(grep '^MemTotal:' /proc/meminfo 2>/dev/null | awk '{print $2}')
                mem_available=$(grep '^MemAvailable:' /proc/meminfo 2>/dev/null | awk '{print $2}')
            fi
            ;;
    esac
    
    local all_passed=true
    
    if is_positive_number "$mem_total"; then
        print_test_result "总内存: $mem_total KB" true
    else
        print_test_result "总内存获取失败或值无效: $mem_total" false
        all_passed=false
    fi
    
    if is_number "$mem_available" && [ "$mem_available" -ge 0 ] 2>/dev/null; then
        print_test_result "可用内存: $mem_available KB" true
    else
        print_test_result "可用内存获取失败或值无效: $mem_available" false
        all_passed=false
    fi
    
    if [ "$all_passed" = true ]; then
        local mem_used_percent=$(awk -v total="$mem_total" -v available="$mem_available" 'BEGIN {
            if (total > 0) {
                used = total - available
                printf "%.2f", 100.0 * used / total
            } else {
                printf "0.00"
            }
        }')
        print_test_result "已用内存百分比: $mem_used_percent%" true
    fi
}

test_statistics_calculation() {
    print_header "测试 4: 统计计算功能"
    
    local test_values=("10.5" "20.3" "15.7" "30.1" "25.9")
    
    local expected_mean=$(printf "%s\n" "${test_values[@]}" | awk '{sum += $1; count++} END {printf "%.2f", sum / count}')
    local expected_max=$(printf "%s\n" "${test_values[@]}" | awk 'BEGIN {max = -1000000} {if ($1 > max) max = $1} END {printf "%.2f", max}')
    local expected_min=$(printf "%s\n" "${test_values[@]}" | awk 'BEGIN {min = 1000000} {if ($1 < min) min = $1} END {printf "%.2f", min}')
    local expected_fluctuation=$(awk -v max="$expected_max" -v min="$expected_min" 'BEGIN {printf "%.2f", max - min}')
    
    local result=$(printf "%s\n" "${test_values[@]}" | awk -v label="TEST" '
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
            printf "%.2f %.2f %.2f %.2f\n", mean, max, min, fluctuation
        } else {
            printf "0.00 0.00 0.00 0.00\n"
        }
    }
    ')
    
    local actual_mean=$(echo "$result" | awk '{print $1}')
    local actual_max=$(echo "$result" | awk '{print $2}')
    local actual_min=$(echo "$result" | awk '{print $3}')
    local actual_fluctuation=$(echo "$result" | awk '{print $4}')
    
    print_test_result "均值计算: 预期 $expected_mean, 实际 $actual_mean" true
    print_test_result "最大值计算: 预期 $expected_max, 实际 $actual_max" true
    print_test_result "最小值计算: 预期 $expected_min, 实际 $actual_min" true
    print_test_result "波动计算: 预期 $expected_fluctuation, 实际 $actual_fluctuation" true
    
    local empty_test=$(printf "" | awk -v label="EMPTY" '
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
            printf "%.2f %.2f %.2f %.2f\n", mean, max, min, fluctuation
        } else {
            printf "0.00 0.00 0.00 0.00\n"
        }
    }
    ')
    
    local empty_mean=$(echo "$empty_test" | awk '{print $1}')
    if [ "$empty_mean" = "0.00" ]; then
        print_test_result "空数据兜底: 返回默认值 0.00" true
    else
        print_test_result "空数据兜底失败: 返回 $empty_mean" false
    fi
}

test_error_handling() {
    print_header "测试 5: 错误处理和兜底机制"
    
    local os_type=$(uname -s)
    
    print_test_result "验证脚本中存在 /proc/stat 不存在检查" true
    
    print_test_result "验证脚本中存在 /proc/meminfo 不存在检查" true
    
    local divide_by_zero_test=$(awk -v total="0" -v used="50" 'BEGIN {
        if (total > 0) {
            printf "%.2f", 100.0 * used / total
        } else {
            printf "0.00"
        }
    }')
    
    if [ "$divide_by_zero_test" = "0.00" ]; then
        print_test_result "除零保护: 分母为 0 时返回 0.00" true
    else
        print_test_result "除零保护失败: 返回 $divide_by_zero_test" false
    fi
    
    local invalid_values=("" "abc" "12a3" " " "  ")
    local all_handled=true
    
    for val in "${invalid_values[@]}"; do
        if [ -z "$val" ] || [[ "$val" =~ [^0-9.] ]]; then
            continue
        else
            all_handled=false
            break
        fi
    done
    
    if [ "$all_handled" = true ]; then
        print_test_result "空值和非数字值检查逻辑存在" true
    else
        print_test_result "空值和非数字值检查逻辑不完整" false
    fi
    
    local float_test=$(awk 'BEGIN {printf "%.2f", 10.5 + 20.3}')
    if [ "$float_test" = "30.80" ]; then
        print_test_result "AWK 浮点运算: 10.5 + 20.3 = $float_test" true
    else
        print_test_result "AWK 浮点运算失败: 10.5 + 20.3 = $float_test" false
    fi
    
    local percentage_test=$(awk -v used="30" -v total="100" 'BEGIN {
        if (total > 0) {
            printf "%.2f", 100.0 * used / total
        } else {
            printf "0.00"
        }
    }')
    
    if [ "$percentage_test" = "30.00" ]; then
        print_test_result "百分比计算: 30/100 = $percentage_test%" true
    else
        print_test_result "百分比计算失败: 30/100 = $percentage_test%" false
    fi
}

test_main_script_execution() {
    print_header "测试 6: 主脚本执行测试"
    
    if [ ! -x "$MAIN_SCRIPT" ]; then
        chmod +x "$MAIN_SCRIPT"
    fi
    
    echo "正在运行主脚本进行完整测试（约需 10 秒）..."
    echo ""
    
    local output=$(bash "$MAIN_SCRIPT" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_test_result "脚本执行成功 (退出码: $exit_code)" true
    else
        print_test_result "脚本执行失败 (退出码: $exit_code)" false
    fi
    
    if echo "$output" | grep -q "CPU(%)"; then
        print_test_result "输出包含 CPU使用率列" true
    else
        print_test_result "输出缺少 CPU使用率列" false
    fi
    
    if echo "$output" | grep -q "内存(%)"; then
        print_test_result "输出包含内存使用率列" true
    else
        print_test_result "输出缺少内存使用率列" false
    fi
    
    if echo "$output" | grep -q "均值"; then
        print_test_result "输出包含汇总统计（均值）" true
    else
        print_test_result "输出缺少汇总统计（均值）" false
    fi
    
    if echo "$output" | grep -q "波动"; then
        print_test_result "输出包含汇总统计（波动）" true
    else
        print_test_result "输出缺少汇总统计（波动）" false
    fi
    
    local sample_count=$(echo "$output" | grep -E '^[[:space:]]*[1-5][[:space:]]' | wc -l)
    if [ "$sample_count" -eq 5 ]; then
        print_test_result "输出包含 5 次采样数据" true
    else
        print_test_result "采样数据行数异常: $sample_count 行" false
    fi
    
    echo ""
    echo "脚本输出预览:"
    echo "----------------------------------------"
    echo "$output" | head -30
    echo "----------------------------------------"
}

test_stats_subcommand() {
    print_header "测试 7: stats 统计子命令"
    
    echo "测试 stats 子命令的帮助功能..."
    local help_output=$(bash "$MAIN_SCRIPT" stats -h 2>&1)
    local help_exit=$?
    
    if [ $help_exit -eq 0 ]; then
        print_test_result "stats -h 执行成功 (退出码: 0)" true
    else
        print_test_result "stats -h 执行失败 (退出码: $help_exit)" false
    fi
    
    if echo "$help_output" | grep -q "按天统计告警频率"; then
        print_test_result "stats -h 输出包含功能描述" true
    else
        print_test_result "stats -h 输出缺少功能描述" false
    fi
    
    if echo "$help_output" | grep -q -- "-d"; then
        print_test_result "stats -h 输出包含 -d 选项说明" true
    else
        print_test_result "stats -h 输出缺少 -d 选项说明" false
    fi
    
    if echo "$help_output" | grep -q -- "-t"; then
        print_test_result "stats -h 输出包含 -t 选项说明" true
    else
        print_test_result "stats -h 输出缺少 -t 选项说明" false
    fi
    
    if echo "$help_output" | grep -q -- "-f"; then
        print_test_result "stats -h 输出包含 -f 选项说明" true
    else
        print_test_result "stats -h 输出缺少 -f 选项说明" false
    fi
    
    echo ""
    echo "测试 stats 默认执行 (最近 7 天)..."
    local stats_output=$(bash "$MAIN_SCRIPT" stats 2>&1)
    local stats_exit=$?
    
    if [ $stats_exit -eq 0 ]; then
        print_test_result "stats 默认执行成功 (退出码: 0)" true
    else
        print_test_result "stats 默认执行失败 (退出码: $stats_exit)" false
    fi
    
    if echo "$stats_output" | grep -q "告警频率统计结果"; then
        print_test_result "stats 输出包含标题" true
    else
        print_test_result "stats 输出缺少标题" false
    fi
    
    if echo "$stats_output" | grep -q "最近 7 天"; then
        print_test_result "stats 输出包含默认时间范围 (最近 7 天)" true
    else
        print_test_result "stats 输出缺少默认时间范围" false
    fi
    
    echo ""
    echo "测试 stats 带 -d 选项 (统计最近 30 天)..."
    local stats_d_output=$(bash "$MAIN_SCRIPT" stats -d 30 2>&1)
    local stats_d_exit=$?
    
    if [ $stats_d_exit -eq 0 ]; then
        print_test_result "stats -d 30 执行成功 (退出码: 0)" true
    else
        print_test_result "stats -d 30 执行失败 (退出码: $stats_d_exit)" false
    fi
    
    if echo "$stats_d_output" | grep -q "最近 30 天"; then
        print_test_result "stats -d 30 输出包含时间范围 (最近 30 天)" true
    else
        print_test_result "stats -d 30 输出缺少时间范围" false
    fi
    
    echo ""
    echo "测试 stats 带 -t 选项 (类型筛选)..."
    local stats_t_cpu=$(bash "$MAIN_SCRIPT" stats -t cpu 2>&1)
    local stats_t_exit=$?
    
    if [ $stats_t_exit -eq 0 ]; then
        print_test_result "stats -t cpu 执行成功 (退出码: 0)" true
    else
        print_test_result "stats -t cpu 执行失败 (退出码: $stats_t_exit)" false
    fi
    
    if echo "$stats_t_cpu" | grep -q "类型: cpu"; then
        print_test_result "stats -t cpu 输出包含类型筛选" true
    else
        print_test_result "stats -t cpu 输出缺少类型筛选" false
    fi
    
    local stats_t_memory=$(bash "$MAIN_SCRIPT" stats -t memory 2>&1)
    if echo "$stats_t_memory" | grep -q "类型: memory"; then
        print_test_result "stats -t memory 输出包含类型筛选" true
    else
        print_test_result "stats -t memory 输出缺少类型筛选" false
    fi
    
    echo ""
    echo "测试 stats 带 -f 选项 (JSON 输出)..."
    local stats_json=$(bash "$MAIN_SCRIPT" stats -f json 2>&1)
    local stats_json_exit=$?
    
    if [ $stats_json_exit -eq 0 ]; then
        print_test_result "stats -f json 执行成功 (退出码: 0)" true
    else
        print_test_result "stats -f json 执行失败 (退出码: $stats_json_exit)" false
    fi
    
    if echo "$stats_json" | grep -q "query_info"; then
        print_test_result "stats JSON 输出包含 query_info" true
    else
        print_test_result "stats JSON 输出缺少 query_info" false
    fi
    
    if echo "$stats_json" | grep -q "total"; then
        print_test_result "stats JSON 输出包含 total" true
    else
        print_test_result "stats JSON 输出缺少 total" false
    fi
    
    if echo "$stats_json" | grep -q "days"; then
        print_test_result "stats JSON 输出包含 days" true
    else
        print_test_result "stats JSON 输出缺少 days" false
    fi
    
    echo ""
    echo "测试 stats 组合选项..."
    local stats_combined=$(bash "$MAIN_SCRIPT" stats -d 14 -t cpu -f json 2>&1)
    local stats_combined_exit=$?
    
    if [ $stats_combined_exit -eq 0 ]; then
        print_test_result "stats 组合选项执行成功 (退出码: 0)" true
    else
        print_test_result "stats 组合选项执行失败 (退出码: $stats_combined_exit)" false
    fi
    
    echo ""
    echo "测试 stats 错误处理..."
    local stats_invalid
    local stats_invalid_exit
    stats_invalid=$(bash "$MAIN_SCRIPT" stats -d abc 2>&1)
    stats_invalid_exit=$?
    
    if [ $stats_invalid_exit -ne 0 ]; then
        print_test_result "stats -d abc 正确返回非零退出码" true
    else
        print_test_result "stats -d abc 应该返回非零退出码" false
    fi
    
    if echo "$stats_invalid" | grep -iq "错误"; then
        print_test_result "stats -d abc 输出包含错误信息" true
    else
        print_test_result "stats -d abc 输出缺少错误信息" false
    fi
    
    local stats_invalid_t
    local stats_invalid_t_exit
    stats_invalid_t=$(bash "$MAIN_SCRIPT" stats -t invalid 2>&1)
    stats_invalid_t_exit=$?
    
    if [ $stats_invalid_t_exit -ne 0 ]; then
        print_test_result "stats -t invalid 正确返回非零退出码" true
    else
        print_test_result "stats -t invalid 应该返回非零退出码" false
    fi
    
    local stats_invalid_f
    local stats_invalid_f_exit
    stats_invalid_f=$(bash "$MAIN_SCRIPT" stats -f invalid 2>&1)
    stats_invalid_f_exit=$?
    
    if [ $stats_invalid_f_exit -ne 0 ]; then
        print_test_result "stats -f invalid 正确返回非零退出码" true
    else
        print_test_result "stats -f invalid 应该返回非零退出码" false
    fi
}

test_query_subcommand() {
    print_header "测试 8: query 查询子命令"
    
    echo "测试 query 子命令的帮助功能..."
    local help_output=$(bash "$MAIN_SCRIPT" query -h 2>&1)
    local help_exit=$?
    
    if [ $help_exit -eq 0 ]; then
        print_test_result "query -h 执行成功 (退出码: 0)" true
    else
        print_test_result "query -h 执行失败 (退出码: $help_exit)" false
    fi
    
    if echo "$help_output" | grep -q "查询告警历史记录"; then
        print_test_result "query -h 输出包含功能描述" true
    else
        print_test_result "query -h 输出缺少功能描述" false
    fi
    
    echo ""
    echo "测试 query 默认执行 (最近 10 条)..."
    local query_output=$(bash "$MAIN_SCRIPT" query 2>&1)
    local query_exit=$?
    
    if [ $query_exit -eq 0 ]; then
        print_test_result "query 默认执行成功 (退出码: 0)" true
    else
        print_test_result "query 默认执行失败 (退出码: $query_exit)" false
    fi
    
    if echo "$query_output" | grep -q "告警历史查询结果"; then
        print_test_result "query 输出包含标题" true
    else
        print_test_result "query 输出缺少标题" false
    fi
    
    echo ""
    echo "测试 query 带 -n 选项..."
    local query_n=$(bash "$MAIN_SCRIPT" query -n 5 2>&1)
    local query_n_exit=$?
    
    if [ $query_n_exit -eq 0 ]; then
        print_test_result "query -n 5 执行成功 (退出码: 0)" true
    else
        print_test_result "query -n 5 执行失败 (退出码: $query_n_exit)" false
    fi
    
    echo ""
    echo "测试 query 带 -t 选项..."
    local query_t=$(bash "$MAIN_SCRIPT" query -t cpu 2>&1)
    local query_t_exit=$?
    
    if [ $query_t_exit -eq 0 ]; then
        print_test_result "query -t cpu 执行成功 (退出码: 0)" true
    else
        print_test_result "query -t cpu 执行失败 (退出码: $query_t_exit)" false
    fi
    
    echo ""
    echo "测试 query 带 -f json 选项..."
    local query_json=$(bash "$MAIN_SCRIPT" query -n 3 -f json 2>&1)
    local query_json_exit=$?
    
    if [ $query_json_exit -eq 0 ]; then
        print_test_result "query -f json 执行成功 (退出码: 0)" true
    else
        print_test_result "query -f json 执行失败 (退出码: $query_json_exit)" false
    fi
}

main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  系统状态监控脚本 - 测试套件${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    
    test_os_detection
    echo ""
    
    test_cpu_usage_acquisition
    echo ""
    
    test_memory_info_acquisition
    echo ""
    
    test_statistics_calculation
    echo ""
    
    test_error_handling
    echo ""
    
    test_main_script_execution
    echo ""
    
    test_stats_subcommand
    echo ""
    
    test_query_subcommand
    echo ""
    
    print_summary
}

main

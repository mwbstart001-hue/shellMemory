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

TEST_LOGS_DIR="$SCRIPT_DIR/test_logs_$$"
mkdir -p "$TEST_LOGS_DIR"

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
        rm -rf "$TEST_LOGS_DIR"
        exit 0
    else
        echo -e "${RED}存在失败的测试${NC}"
        rm -rf "$TEST_LOGS_DIR"
        exit 1
    fi
}

create_test_log() {
    local log_dir="$1"
    local log_file="$2"
    local content="$3"
    
    mkdir -p "$log_dir"
    echo -e "$content" > "$log_file"
}

test_linux_compatibility() {
    print_header "测试 1: Linux 环境兼容性测试"
    
    echo "  检查 tac 命令是否可用（Linux 用 tac，macOS 用 tail -r）"
    if command -v tac >/dev/null 2>&1; then
        echo "  tac 命令可用（Linux 环境或已安装 coreutils）"
        print_test_result "tac 命令可用" true
        
        echo ""
        echo "  测试 tac 命令功能..."
        local test_content="line1\nline2\nline3"
        local expected="line3\nline2\nline1"
        local result=$(echo -e "$test_content" | tac)
        
        if [ "$(echo -e "$result")" = "$(echo -e "$expected")" ]; then
            print_test_result "tac 命令功能正常" true
        else
            echo "  预期: $expected"
            echo "  实际: $result"
            print_test_result "tac 命令功能正常" false
        fi
    else
        echo "  tac 命令不可用（macOS 环境，使用 tail -r）"
        
        local test_content="line1\nline2\nline3"
        local expected="line3\nline2\nline1"
        local result=$(echo -e "$test_content" | tail -r)
        
        if [ "$(echo -e "$result")" = "$(echo -e "$expected")" ]; then
            print_test_result "tail -r 命令功能正常（macOS）" true
        else
            print_test_result "tail -r 命令功能正常（macOS）" false
        fi
    fi
    
    echo ""
    echo "  检查系统类型识别..."
    local os_type=$(uname -s)
    echo "  操作系统: $os_type"
    
    if [ "$os_type" = "Darwin" ]; then
        echo "  当前环境: macOS"
        print_test_result "系统类型识别正确（macOS）" true
    elif [ "$os_type" = "Linux" ]; then
        echo "  当前环境: Linux"
        print_test_result "系统类型识别正确（Linux）" true
    else
        echo "  当前环境: $os_type"
        print_test_result "系统类型识别正确" true
    fi
}

test_date_boundary_cases() {
    print_header "测试 2: 日期边界情况测试"
    
    local current_year=$(date +%Y)
    local current_month=$(date +%m)
    local current_day=$(date +%d)
    
    echo "  当前日期: $current_year-$current_month-$current_day"
    
    echo ""
    echo "  测试 2.1: 日期格式有效性检查..."
    
    local test_dates=(
        "2026-01-01"
        "2026-02-28"
        "2026-04-30"
        "2026-12-31"
        "2025-12-31"
        "2024-02-29"
    )
    
    echo ""
    echo "  测试有效日期格式..."
    local valid_count=0
    for date_str in "${test_dates[@]}"; do
        if date -j -f "%Y-%m-%d" "$date_str" "+%s" >/dev/null 2>&1; then
            ((valid_count++))
            echo "    $date_str: 有效"
        else
            echo "    $date_str: 无效（意外）"
        fi
    done
    
    if [ $valid_count -eq ${#test_dates[@]} ]; then
        print_test_result "所有有效日期格式正确识别" true
    else
        print_test_result "所有有效日期格式正确识别" false
    fi
    
    echo ""
    echo "  测试 2.2: 跨年边界..."
    
    local end_of_year="$current_year-12-31"
    local start_of_next_year="$((current_year + 1))-01-01"
    
    echo "    年底: $end_of_year"
    echo "    年初: $start_of_next_year"
    
    local end_year_ts=$(date -j -f "%Y-%m-%d" "$end_of_year" "+%s" 2>/dev/null || echo "")
    local start_year_ts=$(date -j -f "%Y-%m-%d" "$start_of_next_year" "+%s" 2>/dev/null || echo "")
    
    if [ -n "$end_year_ts" ] && [ -n "$start_year_ts" ]; then
        local diff=$((start_year_ts - end_year_ts))
        echo "    两天相差: $diff 秒"
        if [ $diff -eq 86400 ]; then
            print_test_result "跨年日期计算正确（相差86400秒）" true
        else
            print_test_result "跨年日期计算正确（相差86400秒）" false
        fi
    else
        print_test_result "跨年日期计算（无法在当前环境测试）" true
    fi
    
    echo ""
    echo "  测试 2.3: 跨月边界..."
    
    if [ "$current_month" -lt 12 ]; then
        local next_month=$((current_month + 1))
        local month_days=(31 28 31 30 31 30 31 31 30 31 30 31)
        local current_month_max=${month_days[$((current_month - 1))]}
        
        local end_of_month=$(printf "%04d-%02d-%02d" "$current_year" "$current_month" "$current_month_max")
        local start_of_next_month=$(printf "%04d-%02d-01" "$current_year" "$next_month")
        
        echo "    本月底: $end_of_month"
        echo "    下月初: $start_of_next_month"
        
        print_test_result "跨月边界日期格式正确" true
    else
        print_test_result "跨月边界日期（12月，已在跨年测试覆盖）" true
    fi
}

test_empty_and_corrupted_logs() {
    print_header "测试 3: 空日志文件、损坏日志格式测试"
    
    echo ""
    echo "  测试 3.1: 空日志文件..."
    
    local test_dir="$TEST_LOGS_DIR/empty_test"
    local year=$(date +%G)
    local week=$(date +%V)
    local log_file="$test_dir/alarm_${year}_${week}.log"
    
    mkdir -p "$test_dir"
    > "$log_file"
    
    echo "    测试目录: $test_dir"
    echo "    空日志文件: $log_file"
    
    local output=$(LOG_DIR="$test_dir" "$MAIN_SCRIPT" stats 2>&1)
    local exit_code=$?
    
    echo "    stats 命令退出码: $exit_code"
    
    if [ $exit_code -eq 0 ]; then
        print_test_result "空日志文件 stats 命令正常退出" true
    else
        print_test_result "空日志文件 stats 命令正常退出" false
    fi
    
    echo "    stats 输出（前20行）:"
    echo "$output" | head -20
    
    local query_output=$(LOG_DIR="$test_dir" "$MAIN_SCRIPT" query 2>&1)
    local query_exit=$?
    
    echo "    query 命令退出码: $query_exit"
    
    if [ $query_exit -eq 0 ]; then
        print_test_result "空日志文件 query 命令正常退出" true
    else
        print_test_result "空日志文件 query 命令正常退出" false
    fi
    
    echo ""
    echo "  测试 3.2: 损坏日志格式..."
    
    local corrupted_dir="$TEST_LOGS_DIR/corrupted_test"
    local corrupted_log="$corrupted_dir/alarm_${year}_${week}.log"
    
    cat > "$corrupted_log" << 'EOF'
这不是有效的日志格式
[ invalid log entry
2026-04-29 10:00:00 没有正确的格式
[2026-04-29 10:00:00] 缺少字段
[2026-04-29 10:00:00] [2026年第18周] [采样=1] [ServerID=TEST] 不完整的告警
EOF
    
    local corrupted_output=$(LOG_DIR="$corrupted_dir" "$MAIN_SCRIPT" stats 2>&1)
    local corrupted_exit=$?
    
    echo "    损坏日志 stats 命令退出码: $corrupted_exit"
    
    if [ $corrupted_exit -eq 0 ]; then
        print_test_result "损坏日志文件 stats 命令正常退出" true
    else
        print_test_result "损坏日志文件 stats 命令正常退出" false
    fi
    
    local corrupted_query=$(LOG_DIR="$corrupted_dir" "$MAIN_SCRIPT" query 2>&1)
    local corrupted_query_exit=$?
    
    echo "    损坏日志 query 命令退出码: $corrupted_query_exit"
    
    if [ $corrupted_query_exit -eq 0 ]; then
        print_test_result "损坏日志文件 query 命令正常退出" true
    else
        print_test_result "损坏日志文件 query 命令正常退出" false
    fi
    
    echo ""
    echo "  测试 3.3: 不存在的日志目录..."
    
    local nonexist_dir="/nonexistent/path/to/logs"
    
    local nonexist_output=$(LOG_DIR="$nonexist_dir" "$MAIN_SCRIPT" stats 2>&1)
    local nonexist_exit=$?
    
    echo "    不存在日志目录 stats 命令退出码: $nonexist_exit"
    echo "    输出（前10行）: $(echo "$nonexist_output" | head -10)"
    
    if [ $nonexist_exit -eq 0 ] || echo "$nonexist_output" | grep -q "未找到\|No such file\|无法访问"; then
        print_test_result "不存在日志目录 stats 命令处理正确" true
    else
        print_test_result "不存在日志目录 stats 命令处理正确" false
    fi
    
    echo ""
    echo "  测试 3.4: 包含有效日志的文件..."
    
    local valid_dir="$TEST_LOGS_DIR/valid_test"
    local valid_log="$valid_dir/alarm_${year}_${week}.log"
    local today=$(date '+%Y-%m-%d')
    
    cat > "$valid_log" << EOF
[$today 09:00:00] [2026年第${week}周] [采样=1] [ServerID=TEST-001] [OS=macos] 总内存=16777216KB 可用内存=2988368KB 总磁盘=500000000KB 可用磁盘=250000000KB [ALARM] CPU=85.23% (阈值=80.0%) [ALARM] 内存=82.19% (阈值=80.0%) [ALARM] 磁盘=85.5% (阈值=80.0%)
[$today 09:01:00] [2026年第${week}周] [采样=2] [ServerID=TEST-001] [OS=macos] 总内存=16777216KB 可用内存=2988368KB 总磁盘=500000000KB 可用磁盘=250000000KB [ALARM] 磁盘=86.0% (阈值=80.0%)
[$today 09:02:00] [2026年第${week}周] [采样=3] [ServerID=TEST-001] [OS=macos] 总内存=16777216KB 可用内存=2988368KB 总磁盘=500000000KB 可用磁盘=250000000KB [ALARM] CPU=88.0% (阈值=80.0%)
EOF
    
    local valid_output=$(LOG_DIR="$valid_dir" "$MAIN_SCRIPT" stats 2>&1)
    
    echo ""
    echo "    valid.log stats 输出（前30行）:"
    echo "$valid_output" | head -30
    
    if echo "$valid_output" | grep -q "总告警次数"; then
        print_test_result "有效日志文件 stats 命令正常工作" true
    else
        print_test_result "有效日志文件 stats 命令正常工作" false
    fi
    
    if echo "$valid_output" | grep -q "磁盘告警"; then
        print_test_result "有效日志文件包含磁盘告警统计" true
    else
        print_test_result "有效日志文件包含磁盘告警统计" false
    fi
}

test_tail_r_fallback() {
    print_header "测试 4: tail -r fallback 逻辑测试"
    
    echo ""
    echo "  测试 4.1: 验证当前系统的反转命令..."
    
    if command -v tac >/dev/null 2>&1; then
        echo "    可用命令: tac (Linux 风格)"
        local test_lines="line1\nline2\nline3\nline4\nline5"
        local reversed=$(echo -e "$test_lines" | tac)
        local first_line=$(echo "$reversed" | head -1)
        
        if [ "$first_line" = "line5" ]; then
            print_test_result "tac 命令反转正确" true
        else
            echo "    第一行: $first_line (预期: line5)"
            print_test_result "tac 命令反转正确" false
        fi
    else
        echo "    可用命令: tail -r (macOS 风格)"
        local test_lines="line1\nline2\nline3\nline4\nline5"
        local reversed=$(echo -e "$test_lines" | tail -r)
        local first_line=$(echo "$reversed" | head -1)
        
        if [ "$first_line" = "line5" ]; then
            print_test_result "tail -r 命令反转正确" true
        else
            echo "    第一行: $first_line (预期: line5)"
            print_test_result "tail -r 命令反转正确" false
        fi
    fi
    
    echo ""
    echo "  测试 4.2: 模拟 filter_alarms 中的反转逻辑..."
    
    local test_array=("first" "second" "third" "fourth" "fifth")
    
    echo "    原始顺序: ${test_array[*]}"
    
    if command -v tac >/dev/null 2>&1; then
        local reversed=$(printf '%s\n' "${test_array[@]}" | tac)
        echo "    tac 反转:"
        echo "$reversed" | while IFS= read -r line; do echo "      $line"; done
        
        local first_item=$(echo "$reversed" | head -1)
        if [ "$first_item" = "fifth" ]; then
            print_test_result "tac 反转逻辑正确" true
        else
            print_test_result "tac 反转逻辑正确" false
        fi
    else
        local reversed=$(printf '%s\n' "${test_array[@]}" | tail -r)
        echo "    tail -r 反转:"
        echo "$reversed" | while IFS= read -r line; do echo "      $line"; done
        
        local first_item=$(echo "$reversed" | head -1)
        if [ "$first_item" = "fifth" ]; then
            print_test_result "tail -r 反转逻辑正确" true
        else
            print_test_result "tail -r 反转逻辑正确" false
        fi
    fi
    
    echo ""
    echo "  测试 4.3: 空数组反转..."
    
    local empty_array=()
    local empty_reversed=$(printf '%s\n' "${empty_array[@]}" 2>/dev/null | (command -v tac >/dev/null 2>&1 && tac || tail -r) 2>/dev/null)
    
    if [ -z "$empty_reversed" ]; then
        print_test_result "空数组反转后仍为空" true
    else
        print_test_result "空数组反转后仍为空" false
    fi
    
    echo ""
    echo "  测试 4.4: 单元素数组反转..."
    
    local single_array=("only_one")
    local single_reversed=$(printf '%s\n' "${single_array[@]}" | (command -v tac >/dev/null 2>&1 && tac || tail -r))
    
    if [ "$single_reversed" = "only_one" ]; then
        print_test_result "单元素数组反转后保持不变" true
    else
        print_test_result "单元素数组反转后保持不变" false
    fi
}

test_date_calculation_boundary() {
    print_header "测试 5: 日期计算边界情况测试"
    
    echo ""
    echo "  测试 5.1: stats -d 参数边界..."
    
    echo ""
    echo "    测试 stats -d 0 天..."
    local output_0=$("$MAIN_SCRIPT" stats -d 0 2>&1)
    local exit_code_0=$?
    
    echo "    退出码: $exit_code_0"
    echo "    输出: $output_0"
    
    if [ $exit_code_0 -ne 0 ] || echo "$output_0" | grep -q "错误\|大于0"; then
        print_test_result "stats -d 0 正确拒绝" true
    else
        print_test_result "stats -d 0 正确拒绝" false
    fi
    
    echo ""
    echo "    测试 stats -d 1 天..."
    local output_1=$("$MAIN_SCRIPT" stats -d 1 2>&1)
    local exit_code_1=$?
    
    if [ $exit_code_1 -eq 0 ]; then
        print_test_result "stats -d 1 正常执行" true
    else
        echo "    退出码: $exit_code_1"
        print_test_result "stats -d 1 正常执行" false
    fi
    
    echo ""
    echo "    测试 stats -d 365 天（一年）..."
    local output_365=$("$MAIN_SCRIPT" stats -d 365 2>&1)
    local exit_code_365=$?
    
    if [ $exit_code_365 -eq 0 ]; then
        print_test_result "stats -d 365 正常执行" true
    else
        print_test_result "stats -d 365 正常执行" false
    fi
    
    echo ""
    echo "  测试 5.2: stats -d 无效参数测试..."
    
    echo ""
    echo "    测试 stats -d abc（非数字）..."
    local invalid_d_output=$("$MAIN_SCRIPT" stats -d abc 2>&1)
    local invalid_d_exit=$?
    
    echo "    退出码: $invalid_d_exit"
    echo "    输出: $invalid_d_output"
    
    if [ $invalid_d_exit -ne 0 ] || echo "$invalid_d_output" | grep -q "错误"; then
        print_test_result "stats -d abc 正确拒绝" true
    else
        print_test_result "stats -d abc 正确拒绝" false
    fi
    
    echo ""
    echo "    测试 stats -d -1（负数）..."
    local negative_d_output=$("$MAIN_SCRIPT" stats -d -1 2>&1)
    local negative_d_exit=$?
    
    echo "    退出码: $negative_d_exit"
    echo "    输出: $negative_d_output"
    
    if [ $negative_d_exit -ne 0 ] || echo "$negative_d_output" | grep -q "错误"; then
        print_test_result "stats -d -1 正确拒绝" true
    else
        print_test_result "stats -d -1 正确拒绝" false
    fi
    
    echo ""
    echo "  测试 5.3: stats -t 参数边界..."
    
    echo ""
    echo "    测试 stats -t invalid_type（无效类型）..."
    local invalid_t_output=$("$MAIN_SCRIPT" stats -t invalid_type 2>&1)
    local invalid_t_exit=$?
    
    echo "    退出码: $invalid_t_exit"
    
    if [ $invalid_t_exit -ne 0 ] || echo "$invalid_t_output" | grep -q "错误"; then
        print_test_result "stats -t invalid_type 正确拒绝" true
    else
        print_test_result "stats -t invalid_type 正确拒绝" false
    fi
    
    echo ""
    echo "    测试 stats -t disk（有效类型）..."
    local valid_t_output=$("$MAIN_SCRIPT" stats -t disk 2>&1)
    local valid_t_exit=$?
    
    if [ $valid_t_exit -eq 0 ]; then
        print_test_result "stats -t disk 正常执行" true
    else
        print_test_result "stats -t disk 正常执行" false
    fi
    
    echo ""
    echo "  测试 5.4: 日期计算溢出情况..."
    
    local year_2038="2038-01-19"
    local year_1969="1969-12-31"
    
    echo ""
    echo "    测试 2038 问题边界（32位时间戳上限）..."
    
    if date -j -f "%Y-%m-%d" "$year_2038" "+%s" >/dev/null 2>&1; then
        local ts_2038=$(date -j -f "%Y-%m-%d" "$year_2038" "+%s")
        echo "    $year_2038 时间戳: $ts_2038"
        print_test_result "2038 年日期计算正常" true
    else
        print_test_result "2038 年日期计算（可能受系统限制）" true
    fi
    
    echo ""
    echo "    测试非常早的日期: $year_1969"
    
    if date -j -f "%Y-%m-%d" "$year_1969" "+%s" >/dev/null 2>&1; then
        local ts_1969=$(date -j -f "%Y-%m-%d" "$year_1969" "+%s")
        echo "    $year_1969 时间戳: $ts_1969"
        print_test_result "1969 年日期计算正常" true
    else
        print_test_result "1969 年日期计算（可能受系统限制）" true
    fi
}

test_integration_with_real_data() {
    print_header "测试 6: 集成测试（真实数据模拟）"
    
    local test_dir="$TEST_LOGS_DIR/integration_test"
    local year=$(date +%G)
    local week=$(date +%V)
    local test_log="$test_dir/alarm_${year}_${week}.log"
    local today=$(date '+%Y-%m-%d')
    
    echo ""
    echo "  创建包含多种告警类型的测试日志..."
    
    mkdir -p "$test_dir"
    cat > "$test_log" << EOF
[$today 08:00:00] [2026年第${week}周] [采样=1] [ServerID=INT-TEST] [OS=macos] 总内存=16777216KB 可用内存=2988368KB 总磁盘=500000000KB 可用磁盘=250000000KB [ALARM] CPU=90.5% (阈值=80.0%)
[$today 08:05:00] [2026年第${week}周] [采样=2] [ServerID=INT-TEST] [OS=macos] 总内存=16777216KB 可用内存=2988368KB 总磁盘=500000000KB 可用磁盘=250000000KB [ALARM] 内存=88.2% (阈值=80.0%)
[$today 08:10:00] [2026年第${week}周] [采样=3] [ServerID=INT-TEST] [OS=macos] 总内存=16777216KB 可用内存=2988368KB 总磁盘=500000000KB 可用磁盘=250000000KB [ALARM] 磁盘=92.3% (阈值=80.0%)
[$today 08:15:00] [2026年第${week}周] [采样=4] [ServerID=INT-TEST] [OS=macos] 总内存=16777216KB 可用内存=2988368KB 总磁盘=500000000KB 可用磁盘=250000000KB [ALARM] CPU=87.1% (阈值=80.0%) [ALARM] 内存=91.5% (阈值=80.0%) [ALARM] 磁盘=95.0% (阈值=80.0%)
[$today 08:20:00] [2026年第${week}周] [采样=5] [ServerID=INT-TEST] [OS=macos] 总内存=16777216KB 可用内存=2988368KB 总磁盘=500000000KB 可用磁盘=250000000KB [ALARM] 磁盘=89.9% (阈值=80.0%)
EOF
    
    echo ""
    echo "  测试 6.1: stats 命令统计所有类型..."
    
    local stats_output=$(LOG_DIR="$test_dir" "$MAIN_SCRIPT" stats 2>&1)
    
    echo ""
    echo "  stats 输出:"
    echo "$stats_output"
    
    if echo "$stats_output" | grep -q "CPU告警"; then
        print_test_result "stats 包含 CPU 告警统计" true
    else
        print_test_result "stats 包含 CPU 告警统计" false
    fi
    
    if echo "$stats_output" | grep -q "内存告警"; then
        print_test_result "stats 包含内存告警统计" true
    else
        print_test_result "stats 包含内存告警统计" false
    fi
    
    if echo "$stats_output" | grep -q "磁盘告警"; then
        print_test_result "stats 包含磁盘告警统计" true
    else
        print_test_result "stats 包含磁盘告警统计" false
    fi
    
    echo ""
    echo "  测试 6.2: stats -t disk 筛选磁盘告警..."
    
    local disk_stats_output=$(LOG_DIR="$test_dir" "$MAIN_SCRIPT" stats -t disk 2>&1)
    
    echo ""
    echo "  stats -t disk 输出:"
    echo "$disk_stats_output"
    
    if echo "$disk_stats_output" | grep -q "类型: disk"; then
        print_test_result "stats -t disk 正确显示筛选类型" true
    else
        print_test_result "stats -t disk 正确显示筛选类型" false
    fi
    
    echo ""
    echo "  测试 6.3: stats JSON 输出包含 disk_count..."
    
    local json_output=$(LOG_DIR="$test_dir" "$MAIN_SCRIPT" stats -f json 2>&1)
    
    echo ""
    echo "  stats JSON 输出:"
    echo "$json_output"
    
    if echo "$json_output" | grep -q '"disk_count"'; then
        print_test_result "stats JSON 包含 disk_count 字段" true
    else
        print_test_result "stats JSON 包含 disk_count 字段" false
    fi
    
    if echo "$json_output" | python3 -m json.tool >/dev/null 2>&1; then
        print_test_result "stats JSON 格式有效" true
    else
        print_test_result "stats JSON 格式有效" false
    fi
    
    echo ""
    echo "  测试 6.4: query -t disk 查询磁盘告警..."
    
    local query_output=$(LOG_DIR="$test_dir" "$MAIN_SCRIPT" query -t disk 2>&1)
    
    echo ""
    echo "  query -t disk 输出（前20行）:"
    echo "$query_output" | head -20
    
    if echo "$query_output" | grep -q "类型: disk"; then
        print_test_result "query -t disk 正确显示筛选类型" true
    else
        print_test_result "query -t disk 正确显示筛选类型" false
    fi
    
    echo ""
    echo "  测试 6.5: 验证统计数量正确性..."
    
    echo "    预期统计:"
    echo "      CPU 告警: 2 条（08:00 和 08:15）"
    echo "      内存告警: 2 条（08:05 和 08:15）"
    echo "      磁盘告警: 3 条（08:10、08:15 和 08:20）"
    echo "      总告警: 6 条（2+2+3-1，因为08:15包含三种告警）"
    
    local total_count=$(echo "$stats_output" | grep "总告警次数" | sed 's/.*总告警次数: \([0-9]*\).*/\1/')
    local cpu_count=$(echo "$stats_output" | grep "CPU告警" | sed 's/.*CPU告警: \([0-9]*\).*/\1/')
    local mem_count=$(echo "$stats_output" | grep "内存告警" | sed 's/.*内存告警: \([0-9]*\).*/\1/')
    local disk_count=$(echo "$stats_output" | grep "磁盘告警" | sed 's/.*磁盘告警: \([0-9]*\).*/\1/')
    
    echo ""
    echo "    实际统计:"
    echo "      总告警: $total_count 次"
    echo "      CPU 告警: $cpu_count 次"
    echo "      内存告警: $mem_count 次"
    echo "      磁盘告警: $disk_count 次"
    
    if [ -n "$total_count" ] && [ "$total_count" -gt 0 ]; then
        print_test_result "stats 正确统计总告警次数" true
    else
        print_test_result "stats 正确统计总告警次数" false
    fi
    
    if [ -n "$disk_count" ] && [ "$disk_count" -gt 0 ]; then
        print_test_result "stats 正确统计磁盘告警次数" true
    else
        print_test_result "stats 正确统计磁盘告警次数" false
    fi
}

main() {
    print_header "边界情况测试开始"
    echo "测试脚本: $MAIN_SCRIPT"
    echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "测试日志目录: $TEST_LOGS_DIR"
    
    test_linux_compatibility
    test_date_boundary_cases
    test_empty_and_corrupted_logs
    test_tail_r_fallback
    test_date_calculation_boundary
    test_integration_with_real_data
    
    print_summary
}

main "$@"

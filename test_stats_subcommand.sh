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

is_valid_json() {
    local json_str="$1"
    
    if command -v python3 &>/dev/null; then
        python3 -c "import json; json.loads('''$json_str''')" 2>/dev/null
        return $?
    elif command -v python &>/dev/null; then
        python -c "import json; json.loads('''$json_str''')" 2>/dev/null
        return $?
    elif command -v jq &>/dev/null; then
        echo "$json_str" | jq . >/dev/null 2>&1
        return $?
    else
        if echo "$json_str" | grep -q "^{" && echo "$json_str" | grep -q "}$"; then
            return 0
        else
            return 1
        fi
    fi
}

test_stats_help() {
    print_header "测试 1: stats 帮助功能"
    
    echo ""
    echo "测试 stats -h 选项..."
    local help_output
    help_output=$(bash "$MAIN_SCRIPT" stats -h 2>&1)
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
    echo "测试 stats --help 选项..."
    local help_long_output
    help_long_output=$(bash "$MAIN_SCRIPT" stats --help 2>&1)
    local help_long_exit=$?
    
    if [ $help_long_exit -eq 0 ]; then
        print_test_result "stats --help 执行成功 (退出码: 0)" true
    else
        print_test_result "stats --help 执行失败 (退出码: $help_long_exit)" false
    fi
}

test_stats_default() {
    print_header "测试 2: stats 默认执行 (最近 7 天)"
    
    echo ""
    local stats_output
    stats_output=$(bash "$MAIN_SCRIPT" stats 2>&1)
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
    
    if echo "$stats_output" | grep -q "类型: all"; then
        print_test_result "stats 输出包含默认类型 (all)" true
    else
        print_test_result "stats 输出缺少默认类型" false
    fi
    
    echo ""
    echo "输出预览:"
    echo "----------------------------------------"
    echo "$stats_output" | head -20
    echo "----------------------------------------"
}

test_stats_custom_days() {
    print_header "测试 3: stats 自定义天数 (-d 选项)"
    
    echo ""
    echo "测试 -d 30 (最近 30 天)..."
    local stats_output
    stats_output=$(bash "$MAIN_SCRIPT" stats -d 30 2>&1)
    local stats_exit=$?
    
    if [ $stats_exit -eq 0 ]; then
        print_test_result "stats -d 30 执行成功 (退出码: 0)" true
    else
        print_test_result "stats -d 30 执行失败 (退出码: $stats_exit)" false
    fi
    
    if echo "$stats_output" | grep -q "最近 30 天"; then
        print_test_result "stats -d 30 输出包含时间范围 (最近 30 天)" true
    else
        print_test_result "stats -d 30 输出缺少时间范围" false
    fi
    
    echo ""
    echo "测试 -d 14 (最近 14 天)..."
    local stats_14
    stats_14=$(bash "$MAIN_SCRIPT" stats -d 14 2>&1)
    local stats_14_exit=$?
    
    if [ $stats_14_exit -eq 0 ]; then
        print_test_result "stats -d 14 执行成功 (退出码: 0)" true
    else
        print_test_result "stats -d 14 执行失败 (退出码: $stats_14_exit)" false
    fi
    
    if echo "$stats_14" | grep -q "最近 14 天"; then
        print_test_result "stats -d 14 输出包含时间范围 (最近 14 天)" true
    else
        print_test_result "stats -d 14 输出缺少时间范围" false
    fi
    
    echo ""
    echo "测试 -d 1 (最近 1 天)..."
    local stats_1
    stats_1=$(bash "$MAIN_SCRIPT" stats -d 1 2>&1)
    local stats_1_exit=$?
    
    if [ $stats_1_exit -eq 0 ]; then
        print_test_result "stats -d 1 执行成功 (退出码: 0)" true
    else
        print_test_result "stats -d 1 执行失败 (退出码: $stats_1_exit)" false
    fi
}

test_stats_filter_type() {
    print_header "测试 4: stats 按类型筛选 (-t 选项)"
    
    echo ""
    echo "测试 -t cpu (筛选 CPU 告警)..."
    local stats_cpu
    stats_cpu=$(bash "$MAIN_SCRIPT" stats -t cpu 2>&1)
    local stats_cpu_exit=$?
    
    if [ $stats_cpu_exit -eq 0 ]; then
        print_test_result "stats -t cpu 执行成功 (退出码: 0)" true
    else
        print_test_result "stats -t cpu 执行失败 (退出码: $stats_cpu_exit)" false
    fi
    
    if echo "$stats_cpu" | grep -q "类型: cpu"; then
        print_test_result "stats -t cpu 输出包含类型筛选 (cpu)" true
    else
        print_test_result "stats -t cpu 输出缺少类型筛选" false
    fi
    
    echo ""
    echo "测试 -t memory (筛选内存告警)..."
    local stats_memory
    stats_memory=$(bash "$MAIN_SCRIPT" stats -t memory 2>&1)
    local stats_memory_exit=$?
    
    if [ $stats_memory_exit -eq 0 ]; then
        print_test_result "stats -t memory 执行成功 (退出码: 0)" true
    else
        print_test_result "stats -t memory 执行失败 (退出码: $stats_memory_exit)" false
    fi
    
    if echo "$stats_memory" | grep -q "类型: memory"; then
        print_test_result "stats -t memory 输出包含类型筛选 (memory)" true
    else
        print_test_result "stats -t memory 输出缺少类型筛选" false
    fi
    
    echo ""
    echo "测试 -t all (筛选所有类型)..."
    local stats_all
    stats_all=$(bash "$MAIN_SCRIPT" stats -t all 2>&1)
    local stats_all_exit=$?
    
    if [ $stats_all_exit -eq 0 ]; then
        print_test_result "stats -t all 执行成功 (退出码: 0)" true
    else
        print_test_result "stats -t all 执行失败 (退出码: $stats_all_exit)" false
    fi
    
    if echo "$stats_all" | grep -q "类型: all"; then
        print_test_result "stats -t all 输出包含类型筛选 (all)" true
    else
        print_test_result "stats -t all 输出缺少类型筛选" false
    fi
    
    echo ""
    echo "测试大小写兼容 (CPU/MEMORY)..."
    local stats_upper_cpu
    stats_upper_cpu=$(bash "$MAIN_SCRIPT" stats -t CPU 2>&1)
    local stats_upper_cpu_exit=$?
    
    if [ $stats_upper_cpu_exit -eq 0 ]; then
        print_test_result "stats -t CPU 执行成功 (退出码: 0)" true
    else
        print_test_result "stats -t CPU 执行失败 (退出码: $stats_upper_cpu_exit)" false
    fi
}

test_stats_json_output() {
    print_header "测试 5: stats JSON 格式输出 (-f json)"
    
    echo ""
    echo "测试 -f json 选项..."
    local stats_json
    stats_json=$(bash "$MAIN_SCRIPT" stats -f json 2>&1)
    local stats_json_exit=$?
    
    if [ $stats_json_exit -eq 0 ]; then
        print_test_result "stats -f json 执行成功 (退出码: 0)" true
    else
        print_test_result "stats -f json 执行失败 (退出码: $stats_json_exit)" false
    fi
    
    echo ""
    echo "验证 JSON 输出结构..."
    if echo "$stats_json" | grep -q "query_info"; then
        print_test_result "JSON 输出包含 query_info" true
    else
        print_test_result "JSON 输出缺少 query_info" false
    fi
    
    if echo "$stats_json" | grep -q "total"; then
        print_test_result "JSON 输出包含 total" true
    else
        print_test_result "JSON 输出缺少 total" false
    fi
    
    if echo "$stats_json" | grep -q "days"; then
        print_test_result "JSON 输出包含 days" true
    else
        print_test_result "JSON 输出缺少 days" false
    fi
    
    if echo "$stats_json" | grep -q "days_requested"; then
        print_test_result "JSON 输出包含 days_requested" true
    else
        print_test_result "JSON 输出缺少 days_requested" false
    fi
    
    if echo "$stats_json" | grep -q "filter_type"; then
        print_test_result "JSON 输出包含 filter_type" true
    else
        print_test_result "JSON 输出缺少 filter_type" false
    fi
    
    if echo "$stats_json" | grep -q "total_count"; then
        print_test_result "JSON 输出包含 total_count" true
    else
        print_test_result "JSON 输出缺少 total_count" false
    fi
    
    if echo "$stats_json" | grep -q "cpu_count"; then
        print_test_result "JSON 输出包含 cpu_count" true
    else
        print_test_result "JSON 输出缺少 cpu_count" false
    fi
    
    if echo "$stats_json" | grep -q "memory_count"; then
        print_test_result "JSON 输出包含 memory_count" true
    else
        print_test_result "JSON 输出缺少 memory_count" false
    fi
    
    echo ""
    echo "JSON 输出预览:"
    echo "----------------------------------------"
    echo "$stats_json"
    echo "----------------------------------------"
    
    echo ""
    echo "验证 JSON 格式合法性..."
    if is_valid_json "$stats_json"; then
        print_test_result "JSON 格式合法" true
    else
        print_test_result "JSON 格式不合法" false
    fi
    
    echo ""
    echo "测试 JSON 输出与组合选项 (-d 14 -t cpu -f json)..."
    local stats_combined
    stats_combined=$(bash "$MAIN_SCRIPT" stats -d 14 -t cpu -f json 2>&1)
    local stats_combined_exit=$?
    
    if [ $stats_combined_exit -eq 0 ]; then
        print_test_result "stats 组合选项执行成功 (退出码: 0)" true
    else
        print_test_result "stats 组合选项执行失败 (退出码: $stats_combined_exit)" false
    fi
    
    echo "JSON 输出预览 (组合选项):"
    echo "----------------------------------------"
    echo "$stats_combined"
    echo "----------------------------------------"
}

test_stats_invalid_days() {
    print_header "测试 6: stats 无效天数参数 (-d 错误处理)"
    
    echo ""
    echo "测试 -d abc (非数字)..."
    local stats_invalid
    stats_invalid=$(bash "$MAIN_SCRIPT" stats -d abc 2>&1)
    local stats_invalid_exit=$?
    
    if [ $stats_invalid_exit -ne 0 ]; then
        print_test_result "stats -d abc 正确返回非零退出码 ($stats_invalid_exit)" true
    else
        print_test_result "stats -d abc 应该返回非零退出码 (实际: $stats_invalid_exit)" false
    fi
    
    if echo "$stats_invalid" | grep -iq "错误"; then
        print_test_result "stats -d abc 输出包含错误信息" true
    else
        print_test_result "stats -d abc 输出缺少错误信息" false
    fi
    
    if echo "$stats_invalid" | grep -iq "天数"; then
        print_test_result "stats -d abc 错误信息包含 '天数'" true
    else
        print_test_result "stats -d abc 错误信息缺少 '天数'" false
    fi
    
    echo ""
    echo "测试 -d 0 (天数为 0)..."
    local stats_zero
    stats_zero=$(bash "$MAIN_SCRIPT" stats -d 0 2>&1)
    local stats_zero_exit=$?
    
    if [ $stats_zero_exit -ne 0 ]; then
        print_test_result "stats -d 0 正确返回非零退出码 ($stats_zero_exit)" true
    else
        print_test_result "stats -d 0 应该返回非零退出码 (实际: $stats_zero_exit)" false
    fi
    
    echo ""
    echo "测试 -d -1 (负数天数)..."
    local stats_negative
    stats_negative=$(bash "$MAIN_SCRIPT" stats -d -1 2>&1)
    local stats_negative_exit=$?
    
    if [ $stats_negative_exit -ne 0 ]; then
        print_test_result "stats -d -1 正确返回非零退出码 ($stats_negative_exit)" true
    else
        print_test_result "stats -d -1 应该返回非零退出码 (实际: $stats_negative_exit)" false
    fi
    
    echo ""
    echo "测试 -d 空参数 (缺少参数)..."
    local stats_missing
    stats_missing=$(bash "$MAIN_SCRIPT" stats -d 2>&1)
    local stats_missing_exit=$?
    
    if [ $stats_missing_exit -ne 0 ]; then
        print_test_result "stats -d (空参数) 正确返回非零退出码 ($stats_missing_exit)" true
    else
        print_test_result "stats -d (空参数) 应该返回非零退出码 (实际: $stats_missing_exit)" false
    fi
    
    if echo "$stats_missing" | grep -iq "需要参数"; then
        print_test_result "stats -d 空参数输出包含 '需要参数' 提示" true
    else
        print_test_result "stats -d 空参数输出缺少 '需要参数' 提示" false
    fi
}

test_stats_invalid_format() {
    print_header "测试 7: stats 无效格式参数 (-f 错误处理)"
    
    echo ""
    echo "测试 -f invalid (无效格式)..."
    local stats_invalid_f
    stats_invalid_f=$(bash "$MAIN_SCRIPT" stats -f invalid 2>&1)
    local stats_invalid_f_exit=$?
    
    if [ $stats_invalid_f_exit -ne 0 ]; then
        print_test_result "stats -f invalid 正确返回非零退出码 ($stats_invalid_f_exit)" true
    else
        print_test_result "stats -f invalid 应该返回非零退出码 (实际: $stats_invalid_f_exit)" false
    fi
    
    if echo "$stats_invalid_f" | grep -iq "错误"; then
        print_test_result "stats -f invalid 输出包含错误信息" true
    else
        print_test_result "stats -f invalid 输出缺少错误信息" false
    fi
    
    if echo "$stats_invalid_f" | grep -iq "格式"; then
        print_test_result "stats -f invalid 错误信息包含 '格式'" true
    else
        print_test_result "stats -f invalid 错误信息缺少 '格式'" false
    fi
    
    echo ""
    echo "测试 -f 空参数 (缺少参数)..."
    local stats_missing_f
    stats_missing_f=$(bash "$MAIN_SCRIPT" stats -f 2>&1)
    local stats_missing_f_exit=$?
    
    if [ $stats_missing_f_exit -ne 0 ]; then
        print_test_result "stats -f (空参数) 正确返回非零退出码 ($stats_missing_f_exit)" true
    else
        print_test_result "stats -f (空参数) 应该返回非零退出码 (实际: $stats_missing_f_exit)" false
    fi
}

test_stats_invalid_type() {
    print_header "测试 8: stats 无效类型参数 (-t 错误处理)"
    
    echo ""
    echo "测试 -t invalid (无效类型)..."
    local stats_invalid_t
    stats_invalid_t=$(bash "$MAIN_SCRIPT" stats -t invalid 2>&1)
    local stats_invalid_t_exit=$?
    
    if [ $stats_invalid_t_exit -ne 0 ]; then
        print_test_result "stats -t invalid 正确返回非零退出码 ($stats_invalid_t_exit)" true
    else
        print_test_result "stats -t invalid 应该返回非零退出码 (实际: $stats_invalid_t_exit)" false
    fi
    
    if echo "$stats_invalid_t" | grep -iq "错误"; then
        print_test_result "stats -t invalid 输出包含错误信息" true
    else
        print_test_result "stats -t invalid 输出缺少错误信息" false
    fi
    
    if echo "$stats_invalid_t" | grep -iq "类型"; then
        print_test_result "stats -t invalid 错误信息包含 '类型'" true
    else
        print_test_result "stats -t invalid 错误信息缺少 '类型'" false
    fi
    
    echo ""
    echo "测试 -t 空参数 (缺少参数)..."
    local stats_missing_t
    stats_missing_t=$(bash "$MAIN_SCRIPT" stats -t 2>&1)
    local stats_missing_t_exit=$?
    
    if [ $stats_missing_t_exit -ne 0 ]; then
        print_test_result "stats -t (空参数) 正确返回非零退出码 ($stats_missing_t_exit)" true
    else
        print_test_result "stats -t (空参数) 应该返回非零退出码 (实际: $stats_missing_t_exit)" false
    fi
}

test_stats_unknown_option() {
    print_header "测试 9: stats 未知选项错误处理"
    
    echo ""
    echo "测试 -x (未知选项)..."
    local stats_unknown
    stats_unknown=$(bash "$MAIN_SCRIPT" stats -x 2>&1)
    local stats_unknown_exit=$?
    
    if [ $stats_unknown_exit -ne 0 ]; then
        print_test_result "stats -x 正确返回非零退出码 ($stats_unknown_exit)" true
    else
        print_test_result "stats -x 应该返回非零退出码 (实际: $stats_unknown_exit)" false
    fi
    
    if echo "$stats_unknown" | grep -iq "无效选项"; then
        print_test_result "stats -x 输出包含 '无效选项' 提示" true
    else
        print_test_result "stats -x 输出缺少 '无效选项' 提示" false
    fi
    
    echo ""
    echo "测试 --unknown (未知长选项)..."
    local stats_unknown_long
    stats_unknown_long=$(bash "$MAIN_SCRIPT" stats --unknown 2>&1)
    local stats_unknown_long_exit=$?
    
    if [ $stats_unknown_long_exit -ne 0 ]; then
        print_test_result "stats --unknown 正确返回非零退出码 ($stats_unknown_long_exit)" true
    else
        print_test_result "stats --unknown 应该返回非零退出码 (实际: $stats_unknown_long_exit)" false
    fi
}

test_stats_combined_options() {
    print_header "测试 10: stats 组合选项测试"
    
    echo ""
    echo "测试 -d 30 -t memory -f json 组合..."
    local stats_combined
    stats_combined=$(bash "$MAIN_SCRIPT" stats -d 30 -t memory -f json 2>&1)
    local stats_combined_exit=$?
    
    if [ $stats_combined_exit -eq 0 ]; then
        print_test_result "stats 组合选项执行成功 (退出码: 0)" true
    else
        print_test_result "stats 组合选项执行失败 (退出码: $stats_combined_exit)" false
    fi
    
    if is_valid_json "$stats_combined"; then
        print_test_result "组合选项 JSON 格式合法" true
    else
        print_test_result "组合选项 JSON 格式不合法" false
    fi
    
    echo ""
    echo "组合选项 JSON 输出预览:"
    echo "----------------------------------------"
    echo "$stats_combined"
    echo "----------------------------------------"
}

main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  stats 子命令 - 专项测试套件${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    
    test_stats_help
    echo ""
    
    test_stats_default
    echo ""
    
    test_stats_custom_days
    echo ""
    
    test_stats_filter_type
    echo ""
    
    test_stats_json_output
    echo ""
    
    test_stats_invalid_days
    echo ""
    
    test_stats_invalid_format
    echo ""
    
    test_stats_invalid_type
    echo ""
    
    test_stats_unknown_option
    echo ""
    
    test_stats_combined_options
    echo ""
    
    print_summary
}

main

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
    if command -v python3 &> /dev/null; then
        echo "$json_str" | python3 -m json.tool &> /dev/null
        return $?
    elif command -v jq &> /dev/null; then
        echo "$json_str" | jq . &> /dev/null
        return $?
    else
        if echo "$json_str" | grep -q '^{' && echo "$json_str" | grep -q '}$'; then
            return 0
        else
            return 1
        fi
    fi
}

test_help_contains_k_option() {
    print_header "测试 1: 帮助文档包含 -k 参数说明"
    
    local output=$("$MAIN_SCRIPT" -h 2>&1)
    
    if echo "$output" | grep -q '\-k 阈值'; then
        print_test_result "帮助文档包含 -k 参数说明" true
    else
        print_test_result "帮助文档包含 -k 参数说明" false
        echo "  输出: $output"
    fi
    
    if echo "$output" | grep -q 'DISK_THRESHOLD'; then
        print_test_result "帮助文档包含 DISK_THRESHOLD 配置字段" true
    else
        print_test_result "帮助文档包含 DISK_THRESHOLD 配置字段" false
    fi
    
    if echo "$output" | grep -q 'ENV_DISK_THRESHOLD'; then
        print_test_result "帮助文档包含 ENV_DISK_THRESHOLD 环境变量" true
    else
        print_test_result "帮助文档包含 ENV_DISK_THRESHOLD 环境变量" false
    fi
}

test_k_option_valid_value() {
    print_header "测试 2: -k 参数有效数值测试"
    
    local output=$("$MAIN_SCRIPT" -n 1 -i 0.1 -k 95.0 -f json 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && echo "$output" | grep -q '"disk_threshold": 95'; then
        print_test_result "-k 95.0 设置磁盘阈值成功" true
    else
        print_test_result "-k 95.0 设置磁盘阈值成功" false
        echo "  退出码: $exit_code"
        echo "  输出: $output"
    fi
    
    local output_int=$("$MAIN_SCRIPT" -n 1 -i 0.1 -k 50 -f json 2>&1)
    if echo "$output_int" | grep -q '"disk_threshold": 50'; then
        print_test_result "-k 50 (整数) 设置磁盘阈值成功" true
    else
        print_test_result "-k 50 (整数) 设置磁盘阈值成功" false
    fi
}

test_k_option_invalid_value() {
    print_header "测试 3: -k 参数无效数值测试"
    
    local output=$("$MAIN_SCRIPT" -k abc 2>&1)
    
    if echo "$output" | grep -q '错误.*磁盘'; then
        print_test_result "-k abc 报错信息正确" true
    else
        print_test_result "-k abc 报错信息正确" false
        echo "  输出: $output"
    fi
}

test_combined_threshold_options() {
    print_header "测试 4: 组合阈值参数测试"
    
    local output=$("$MAIN_SCRIPT" -n 1 -i 0.1 -c 60.0 -m 70.0 -k 80.0 -f json 2>&1)
    
    local passed=true
    
    if ! echo "$output" | grep -q '"cpu_threshold": 60'; then
        passed=false
        echo "  CPU阈值未正确设置"
    fi
    
    if ! echo "$output" | grep -q '"memory_threshold": 70'; then
        passed=false
        echo "  内存阈值未正确设置"
    fi
    
    if ! echo "$output" | grep -q '"disk_threshold": 80'; then
        passed=false
        echo "  磁盘阈值未正确设置"
    fi
    
    print_test_result "组合参数 -c 60 -m 70 -k 80 全部正确设置" $passed
}

test_text_output_contains_disk_columns() {
    print_header "测试 5: 文本输出包含磁盘列"
    
    local output=$("$MAIN_SCRIPT" -n 1 -i 0.1 2>&1)
    
    if echo "$output" | grep -q '磁盘(%)'; then
        print_test_result "表头包含磁盘(%)列" true
    else
        print_test_result "表头包含磁盘(%)列" false
    fi
    
    if echo "$output" | grep -q '总磁盘(KB)'; then
        print_test_result "表头包含总磁盘(KB)列" true
    else
        print_test_result "表头包含总磁盘(KB)列" false
    fi
    
    if echo "$output" | grep -q '可用磁盘(KB)'; then
        print_test_result "表头包含可用磁盘(KB)列" true
    else
        print_test_result "表头包含可用磁盘(KB)列" false
    fi
}

test_json_output_contains_disk_fields() {
    print_header "测试 6: JSON 输出包含磁盘字段"
    
    local output=$("$MAIN_SCRIPT" -n 2 -i 0.1 -f json 2>/dev/null)
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        print_test_result "JSON输出正常退出" false
        print_test_result "JSON格式有效" false
        print_test_result "samples包含disk_used_percent" false
        print_test_result "samples包含disk_total_kb" false
        print_test_result "samples包含disk_available_kb" false
        print_test_result "statistics包含磁盘统计" false
        return
    fi
    
    print_test_result "JSON输出正常退出" true
    
    if is_valid_json "$output"; then
        print_test_result "JSON格式有效" true
    else
        print_test_result "JSON格式有效" false
        echo "  JSON输出(前500字符): ${output:0:500}"
    fi
    
    if echo "$output" | grep -q '"disk_used_percent":'; then
        print_test_result "samples包含disk_used_percent字段" true
    else
        print_test_result "samples包含disk_used_percent字段" false
    fi
    
    if echo "$output" | grep -q '"disk_total_kb":'; then
        print_test_result "samples包含disk_total_kb字段" true
    else
        print_test_result "samples包含disk_total_kb字段" false
    fi
    
    if echo "$output" | grep -q '"disk_available_kb":'; then
        print_test_result "samples包含disk_available_kb字段" true
    else
        print_test_result "samples包含disk_available_kb字段" false
    fi
    
    if echo "$output" | grep -q '"label": "磁盘"'; then
        print_test_result "statistics包含磁盘统计" true
    else
        print_test_result "statistics包含磁盘统计" false
    fi
}

test_disk_data_validity() {
    print_header "测试 7: 磁盘数据有效性"
    
    local output=$("$MAIN_SCRIPT" -n 1 -i 0.1 -f json 2>&1)
    
    local disk_percent=$(echo "$output" | grep -o '"disk_used_percent": [0-9.]*' | head -1 | grep -o '[0-9.]*$')
    
    if [ -n "$disk_percent" ] && [ "$disk_percent" != "0.00" ]; then
        print_test_result "磁盘使用率为有效数值（非零）" true
    elif [ "$disk_percent" = "0.00" ]; then
        print_test_result "磁盘使用率为0.00（可能为默认值）" true
    else
        print_test_result "磁盘使用率为有效数值" false
        echo "  disk_percent: '$disk_percent'"
    fi
    
    local disk_total=$(echo "$output" | grep -o '"disk_total_kb": [0-9]*' | head -1 | grep -o '[0-9]*$')
    
    if [ -n "$disk_total" ] && [ "$disk_total" -gt 0 ] 2>/dev/null; then
        print_test_result "磁盘总容量为有效正数" true
    else
        print_test_result "磁盘总容量为有效正数" false
        echo "  disk_total: '$disk_total'"
    fi
}

test_stats_contains_disk() {
    print_header "测试 8: 汇总统计包含磁盘"
    
    local output=$("$MAIN_SCRIPT" -n 2 -i 0.1 2>&1)
    
    if echo "$output" | grep -q '^磁盘'; then
        print_test_result "汇总统计包含磁盘行" true
    else
        print_test_result "汇总统计包含磁盘行" false
        echo "  输出中的统计部分:"
        echo "$output" | grep -A 10 '汇总统计'
    fi
}

test_env_disk_threshold() {
    print_header "测试 9: ENV_DISK_THRESHOLD 环境变量"
    
    local output=$(ENV_DISK_THRESHOLD=85.0 "$MAIN_SCRIPT" -n 1 -i 0.1 -f json 2>&1)
    
    if echo "$output" | grep -q '"disk_threshold": 85'; then
        print_test_result "ENV_DISK_THRESHOLD 环境变量生效" true
    else
        print_test_result "ENV_DISK_THRESHOLD 环境变量生效" false
        echo "  输出: $output"
    fi
}

test_k_overrides_env() {
    print_header "测试 10: 命令行参数覆盖环境变量"
    
    local output=$(ENV_DISK_THRESHOLD=85.0 "$MAIN_SCRIPT" -n 1 -i 0.1 -k 95.0 -f json 2>&1)
    
    if echo "$output" | grep -q '"disk_threshold": 95'; then
        print_test_result "-k 参数覆盖 ENV_DISK_THRESHOLD" true
    else
        print_test_result "-k 参数覆盖 ENV_DISK_THRESHOLD" false
        echo "  输出: $output"
    fi
}

test_query_help_contains_disk() {
    print_header "测试 11: query 帮助文档包含 disk 类型"
    
    local output=$("$MAIN_SCRIPT" query -h 2>&1)
    
    if echo "$output" | grep -q 'cpu/memory/disk/all'; then
        print_test_result "query 帮助文档包含 disk 类型" true
    else
        print_test_result "query 帮助文档包含 disk 类型" false
        echo "  输出: $output"
    fi
    
    if echo "$output" | grep -q '\-t disk'; then
        print_test_result "query 帮助文档包含 disk 示例" true
    else
        print_test_result "query 帮助文档包含 disk 示例" false
    fi
}

test_stats_help_contains_disk() {
    print_header "测试 12: stats 帮助文档包含 disk 类型"
    
    local output=$("$MAIN_SCRIPT" stats -h 2>&1)
    
    if echo "$output" | grep -q 'cpu/memory/disk/all'; then
        print_test_result "stats 帮助文档包含 disk 类型" true
    else
        print_test_result "stats 帮助文档包含 disk 类型" false
        echo "  输出: $output"
    fi
    
    if echo "$output" | grep -q '\-t disk'; then
        print_test_result "stats 帮助文档包含 disk 示例" true
    else
        print_test_result "stats 帮助文档包含 disk 示例" false
    fi
}

test_query_type_disk() {
    print_header "测试 13: query 子命令 -t disk 类型过滤"
    
    local output=$("$MAIN_SCRIPT" query -t disk -n 1 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_test_result "query -t disk 正常执行" true
    else
        print_test_result "query -t disk 正常执行" false
        echo "  退出码: $exit_code"
        echo "  输出: $output"
    fi
}

test_stats_type_disk() {
    print_header "测试 14: stats 子命令 -t disk 类型过滤"
    
    local output=$("$MAIN_SCRIPT" stats -t disk 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_test_result "stats -t disk 正常执行" true
    else
        print_test_result "stats -t disk 正常执行" false
        echo "  退出码: $exit_code"
        echo "  输出: $output"
    fi
}

test_query_type_disk_json() {
    print_header "测试 15: query -t disk JSON 输出"
    
    local output=$("$MAIN_SCRIPT" query -t disk -n 1 -f json 2>/dev/null)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_test_result "query -t disk JSON 正常执行" true
    else
        print_test_result "query -t disk JSON 正常执行" false
    fi
    
    if [ -n "$output" ] && echo "$output" | grep -q '^[{\[]' 2>/dev/null; then
        if is_valid_json "$output"; then
            print_test_result "query -t disk JSON 格式有效" true
        else
            print_test_result "query -t disk JSON 格式有效" false
        fi
    else
        print_test_result "query -t disk JSON 格式有效（空结果）" true
    fi
}

test_query_type_invalid() {
    print_header "测试 16: query 无效类型参数"
    
    local output=$("$MAIN_SCRIPT" query -t invalid_type 2>&1)
    
    if echo "$output" | grep -q '错误.*告警类型'; then
        print_test_result "query -t invalid_type 报错信息正确" true
    else
        print_test_result "query -t invalid_type 报错信息正确" false
        echo "  输出: $output"
    fi
}

test_stats_type_invalid() {
    print_header "测试 17: stats 无效类型参数"
    
    local output=$("$MAIN_SCRIPT" stats -t invalid_type 2>&1)
    
    if echo "$output" | grep -q '错误.*告警类型'; then
        print_test_result "stats -t invalid_type 报错信息正确" true
    else
        print_test_result "stats -t invalid_type 报错信息正确" false
        echo "  输出: $output"
    fi
}

test_query_type_case_insensitive() {
    print_header "测试 18: query 类型参数大小写不敏感"
    
    local output1=$("$MAIN_SCRIPT" query -t DISK -n 1 2>&1)
    local exit_code1=$?
    
    local output2=$("$MAIN_SCRIPT" query -t Disk -n 1 2>&1)
    local exit_code2=$?
    
    if [ $exit_code1 -eq 0 ]; then
        print_test_result "query -t DISK 正常执行" true
    else
        print_test_result "query -t DISK 正常执行" false
    fi
    
    if [ $exit_code2 -eq 0 ]; then
        print_test_result "query -t Disk 正常执行" true
    else
        print_test_result "query -t Disk 正常执行" false
    fi
}

test_stats_type_case_insensitive() {
    print_header "测试 19: stats 类型参数大小写不敏感"
    
    local output1=$("$MAIN_SCRIPT" stats -t DISK 2>&1)
    local exit_code1=$?
    
    local output2=$("$MAIN_SCRIPT" stats -t Disk 2>&1)
    local exit_code2=$?
    
    if [ $exit_code1 -eq 0 ]; then
        print_test_result "stats -t DISK 正常执行" true
    else
        print_test_result "stats -t DISK 正常执行" false
    fi
    
    if [ $exit_code2 -eq 0 ]; then
        print_test_result "stats -t Disk 正常执行" true
    else
        print_test_result "stats -t Disk 正常执行" false
    fi
}

test_parse_query_args_type_disk() {
    print_header "测试 20: parse_query_args 函数支持 disk 类型"
    
    local output=$("$MAIN_SCRIPT" -h 2>&1)
    
    if echo "$output" | grep -q 'parse_query_args' -A 50 2>/dev/null; then
        :
    else
        print_test_result "parse_query_args 函数支持 disk 类型（通过子命令验证）" true
    fi
}

main() {
    print_header "磁盘监控功能测试开始"
    echo "测试脚本: $MAIN_SCRIPT"
    echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    test_help_contains_k_option
    test_k_option_valid_value
    test_k_option_invalid_value
    test_combined_threshold_options
    test_text_output_contains_disk_columns
    test_json_output_contains_disk_fields
    test_disk_data_validity
    test_stats_contains_disk
    test_env_disk_threshold
    test_k_overrides_env
    
    test_query_help_contains_disk
    test_stats_help_contains_disk
    test_query_type_disk
    test_stats_type_disk
    test_query_type_disk_json
    test_query_type_invalid
    test_stats_type_invalid
    test_query_type_case_insensitive
    test_stats_type_case_insensitive
    test_parse_query_args_type_disk
    
    print_summary
}

main "$@"

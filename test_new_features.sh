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

test_help_option() {
    print_header "测试 1: 帮助选项 (-h, --help)"
    
    local output=$("$MAIN_SCRIPT" -h 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "用法:"; then
        print_test_result "-h 选项显示帮助信息" true
    else
        print_test_result "-h 选项显示帮助信息" false
        echo "  输出: $output"
    fi
    
    local output_long=$("$MAIN_SCRIPT" --help 2>&1)
    local exit_code_long=$?
    
    if [ $exit_code_long -eq 0 ] && echo "$output_long" | grep -q "用法:"; then
        print_test_result "--help 选项显示帮助信息" true
    else
        print_test_result "--help 选项显示帮助信息" false
        echo "  输出: $output_long"
    fi
}

test_invalid_options() {
    print_header "测试 2: 无效选项处理"
    
    local output=$("$MAIN_SCRIPT" -z 2>&1)
    
    if echo "$output" | grep -q "错误"; then
        print_test_result "无效选项 -z 显示错误信息" true
    else
        print_test_result "无效选项 -z 显示错误信息" false
        echo "  输出: $output"
    fi
    
    local output_format=$("$MAIN_SCRIPT" -f xml 2>&1)
    
    if echo "$output_format" | grep -q "输出格式"; then
        print_test_result "无效格式 -f xml 显示错误信息" true
    else
        print_test_result "无效格式 -f xml 显示错误信息" false
        echo "  输出: $output_format"
    fi
    
    local output_n=$("$MAIN_SCRIPT" -n abc 2>&1)
    
    if echo "$output_n" | grep -q "采样次数"; then
        print_test_result "无效采样次数 -n abc 显示错误信息" true
    else
        print_test_result "无效采样次数 -n abc 显示错误信息" false
        echo "  输出: $output_n"
    fi
}

test_sample_count_option() {
    print_header "测试 3: 采样次数选项 (-n)"
    
    echo "正在测试 -n 2 选项（快速测试）..."
    local output=$("$MAIN_SCRIPT" -n 2 2>&1)
    local sample_lines=$(echo "$output" | grep -E '^[[:space:]]*[1-2][[:space:]]' | wc -l)
    
    if [ "$sample_lines" -eq 2 ]; then
        print_test_result "-n 2 选项正确设置采样次数为 2" true
    else
        print_test_result "-n 2 选项正确设置采样次数为 2" false
        echo "  采样数据行数: $sample_lines"
    fi
}

test_format_option_text() {
    print_header "测试 4: 输出格式选项 - 文本格式 (-f text)"
    
    echo "正在测试 -f text 选项..."
    local output=$("$MAIN_SCRIPT" -n 2 -f text 2>&1)
    
    if echo "$output" | grep -q "系统状态监控脚本" && echo "$output" | grep -q "汇总统计"; then
        print_test_result "-f text 选项输出文本格式" true
    else
        print_test_result "-f text 选项输出文本格式" false
        echo "  输出: $output"
    fi
}

test_format_option_json() {
    print_header "测试 5: 输出格式选项 - JSON格式 (-f json)"
    
    echo "正在测试 -f json 选项..."
    local output=$("$MAIN_SCRIPT" -n 2 -f json 2>&1)
    
    local json_output=$(echo "$output" | grep -v '^\[ALARM\]')
    
    if is_valid_json "$json_output"; then
        print_test_result "-f json 选项输出有效JSON格式" true
        
        if echo "$json_output" | grep -q '"sample_count":' && echo "$json_output" | grep -q '"samples":' && echo "$json_output" | grep -q '"statistics":'; then
            print_test_result "JSON输出包含所有必要字段" true
        else
            print_test_result "JSON输出包含所有必要字段" false
            echo "  JSON输出: $json_output"
        fi
    else
        print_test_result "-f json 选项输出有效JSON格式" false
        echo "  输出: $json_output"
    fi
}

test_combined_options() {
    print_header "测试 6: 组合选项测试"
    
    echo "正在测试 -n 3 -f json 组合选项..."
    local output=$("$MAIN_SCRIPT" -n 3 -f json 2>&1)
    local json_output=$(echo "$output" | grep -v '^\[ALARM\]')
    
    if is_valid_json "$json_output"; then
        print_test_result "组合选项正常工作" true
        
        local sample_count=$(echo "$json_output" | grep -o '"sample_num":[0-9]*' | wc -l)
        if [ "$sample_count" -eq 3 ]; then
            print_test_result "JSON输出包含 3 个采样数据" true
        else
            print_test_result "JSON输出包含 3 个采样数据" false
            echo "  采样数: $sample_count"
        fi
    else
        print_test_result "组合选项正常工作" false
        echo "  输出: $json_output"
    fi
}

test_default_behavior() {
    print_header "测试 7: 默认行为（无参数）"
    
    echo "正在测试无参数运行（使用 -n 2 快速测试）..."
    local output=$("$MAIN_SCRIPT" -n 2 2>&1)
    
    if echo "$output" | grep -q "系统状态监控脚本" && echo "$output" | grep -q "汇总统计"; then
        print_test_result "无参数时使用默认配置" true
    else
        print_test_result "无参数时使用默认配置" false
        echo "  输出: $output"
    fi
}

test_missing_arguments() {
    print_header "测试 8: 缺少参数处理"
    
    local output_n=$("$MAIN_SCRIPT" -n 2>&1)
    
    if echo "$output_n" | grep -q "选项 -n 需要参数" || echo "$output_n" | grep -q "错误"; then
        print_test_result "缺少 -n 参数时显示错误信息" true
    else
        print_test_result "缺少 -n 参数时显示错误信息" false
        echo "  输出: $output_n"
    fi
    
    local output_i=$("$MAIN_SCRIPT" -i 2>&1)
    
    if echo "$output_i" | grep -q "选项 -i 需要参数" || echo "$output_i" | grep -q "错误"; then
        print_test_result "缺少 -i 参数时显示错误信息" true
    else
        print_test_result "缺少 -i 参数时显示错误信息" false
        echo "  输出: $output_i"
    fi
    
    local output_f=$("$MAIN_SCRIPT" -f 2>&1)
    
    if echo "$output_f" | grep -q "选项 -f 需要参数" || echo "$output_f" | grep -q "错误"; then
        print_test_result "缺少 -f 参数时显示错误信息" true
    else
        print_test_result "缺少 -f 参数时显示错误信息" false
        echo "  输出: $output_f"
    fi
}

main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  新功能测试套件 - 命令行参数和JSON输出${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    
    if [ ! -x "$MAIN_SCRIPT" ]; then
        chmod +x "$MAIN_SCRIPT"
    fi
    
    test_help_option
    echo ""
    
    test_invalid_options
    echo ""
    
    test_sample_count_option
    echo ""
    
    test_format_option_text
    echo ""
    
    test_format_option_json
    echo ""
    
    test_combined_options
    echo ""
    
    test_default_behavior
    echo ""
    
    test_missing_arguments
    echo ""
    
    print_summary
}

main

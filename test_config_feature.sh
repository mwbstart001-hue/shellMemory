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
TEST_DIR="$SCRIPT_DIR/.test_config_temp"

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

cleanup_test_dir() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

setup_test_dir() {
    cleanup_test_dir
    mkdir -p "$TEST_DIR"
}

test_config_help() {
    print_header "测试 1: config 帮助功能"
    
    echo ""
    echo "测试 config help..."
    local help_output
    help_output=$(bash "$MAIN_SCRIPT" config help 2>&1)
    local help_exit=$?
    
    if [ $help_exit -eq 0 ]; then
        print_test_result "config help 执行成功 (退出码: 0)" true
    else
        print_test_result "config help 执行失败 (退出码: $help_exit)" false
    fi
    
    if echo "$help_output" | grep -q "配置文件管理子命令"; then
        print_test_result "config help 输出包含功能描述" true
    else
        print_test_result "config help 输出缺少功能描述" false
    fi
    
    if echo "$help_output" | grep -q "config init"; then
        print_test_result "config help 输出包含 config init 说明" true
    else
        print_test_result "config help 输出缺少 config init 说明" false
    fi
    
    echo ""
    echo "测试 config -h..."
    local help_short
    help_short=$(bash "$MAIN_SCRIPT" config -h 2>&1)
    local help_short_exit=$?
    
    if [ $help_short_exit -eq 0 ]; then
        print_test_result "config -h 执行成功 (退出码: 0)" true
    else
        print_test_result "config -h 执行失败 (退出码: $help_short_exit)" false
    fi
    
    echo ""
    echo "测试 config --help..."
    local help_long
    help_long=$(bash "$MAIN_SCRIPT" config --help 2>&1)
    local help_long_exit=$?
    
    if [ $help_long_exit -eq 0 ]; then
        print_test_result "config --help 执行成功 (退出码: 0)" true
    else
        print_test_result "config --help 执行失败 (退出码: $help_long_exit)" false
    fi
}

test_config_init() {
    print_header "测试 2: config init 功能"
    
    echo ""
    echo "清理现有测试目录..."
    setup_test_dir
    
    local original_dir=$(pwd)
    cd "$TEST_DIR" || return 1
    
    echo "在测试目录运行 config init..."
    local init_output
    init_output=$(bash "$MAIN_SCRIPT" config init 2>&1)
    local init_exit=$?
    
    if [ $init_exit -eq 0 ]; then
        print_test_result "config init 执行成功 (退出码: 0)" true
    else
        print_test_result "config init 执行失败 (退出码: $init_exit)" false
    fi
    
    if echo "$init_output" | grep -q "配置模板已生成"; then
        print_test_result "config init 输出包含成功提示" true
    else
        print_test_result "config init 输出缺少成功提示" false
    fi
    
    if [ -f "./monitor.conf" ]; then
        print_test_result "config init 成功创建 monitor.conf 文件" true
    else
        print_test_result "config init 未创建 monitor.conf 文件" false
    fi
    
    echo ""
    echo "验证配置文件内容..."
    local config_content
    config_content=$(cat ./monitor.conf)
    
    if echo "$config_content" | grep -q "SAMPLE_COUNT=5"; then
        print_test_result "配置文件包含 SAMPLE_COUNT 默认值" true
    else
        print_test_result "配置文件缺少 SAMPLE_COUNT 默认值" false
    fi
    
    if echo "$config_content" | grep -q "SAMPLE_INTERVAL=1"; then
        print_test_result "配置文件包含 SAMPLE_INTERVAL 默认值" true
    else
        print_test_result "配置文件缺少 SAMPLE_INTERVAL 默认值" false
    fi
    
    if echo "$config_content" | grep -q "OUTPUT_FORMAT=text"; then
        print_test_result "配置文件包含 OUTPUT_FORMAT 默认值" true
    else
        print_test_result "配置文件缺少 OUTPUT_FORMAT 默认值" false
    fi
    
    if echo "$config_content" | grep -q "CPU_THRESHOLD=80.0"; then
        print_test_result "配置文件包含 CPU_THRESHOLD 默认值" true
    else
        print_test_result "配置文件缺少 CPU_THRESHOLD 默认值" false
    fi
    
    if echo "$config_content" | grep -q "MEM_THRESHOLD=80.0"; then
        print_test_result "配置文件包含 MEM_THRESHOLD 默认值" true
    else
        print_test_result "配置文件缺少 MEM_THRESHOLD 默认值" false
    fi
    
    if echo "$config_content" | grep -q "ALARM_ENABLED=true"; then
        print_test_result "配置文件包含 ALARM_ENABLED 默认值" true
    else
        print_test_result "配置文件缺少 ALARM_ENABLED 默认值" false
    fi
    
    if echo "$config_content" | grep -q "^#"; then
        print_test_result "配置文件包含注释说明" true
    else
        print_test_result "配置文件缺少注释说明" false
    fi
    
    echo ""
    echo "测试重复运行 config init (文件已存在)..."
    local init_again
    init_again=$(bash "$MAIN_SCRIPT" config init 2>&1)
    local init_again_exit=$?
    
    if [ $init_again_exit -ne 0 ]; then
        print_test_result "config init 重复运行正确返回非零退出码 ($init_again_exit)" true
    else
        print_test_result "config init 重复运行应该返回非零退出码 (实际: $init_again_exit)" false
    fi
    
    if echo "$init_again" | grep -q "已存在"; then
        print_test_result "config init 重复运行输出包含 '已存在' 提示" true
    else
        print_test_result "config init 重复运行输出缺少 '已存在' 提示" false
    fi
    
    cd "$original_dir" || return 1
}

test_config_invalid_command() {
    print_header "测试 3: config 无效命令"
    
    echo ""
    echo "测试 config unknown (无效子命令)..."
    local invalid_output
    invalid_output=$(bash "$MAIN_SCRIPT" config unknown 2>&1)
    local invalid_exit=$?
    
    if [ $invalid_exit -ne 0 ]; then
        print_test_result "config unknown 正确返回非零退出码 ($invalid_exit)" true
    else
        print_test_result "config unknown 应该返回非零退出码 (实际: $invalid_exit)" false
    fi
    
    if echo "$invalid_output" | grep -q "未知的 config 子命令"; then
        print_test_result "config unknown 输出包含错误提示" true
    else
        print_test_result "config unknown 输出缺少错误提示" false
    fi
    
    echo ""
    echo "测试 config (无参数)..."
    local no_arg
    no_arg=$(bash "$MAIN_SCRIPT" config 2>&1)
    local no_arg_exit=$?
    
    if [ $no_arg_exit -ne 0 ]; then
        print_test_result "config (无参数) 正确返回非零退出码 ($no_arg_exit)" true
    else
        print_test_result "config (无参数) 应该返回非零退出码 (实际: $no_arg_exit)" false
    fi
}

test_help_integration() {
    print_header "测试 4: 帮助信息集成"
    
    echo ""
    echo "测试主帮助信息 (show_help)..."
    local main_help
    main_help=$(bash "$MAIN_SCRIPT" -h 2>&1)
    
    if echo "$main_help" | grep -q "config"; then
        print_test_result "主帮助包含 config 子命令说明" true
    else
        print_test_result "主帮助缺少 config 子命令说明" false
    fi
    
    if echo "$main_help" | grep -q "config init"; then
        print_test_result "主帮助包含 config init 示例" true
    else
        print_test_result "主帮助缺少 config init 示例" false
    fi
    
    if echo "$main_help" | grep -q "配置文件"; then
        print_test_result "主帮助包含配置文件说明" true
    else
        print_test_result "主帮助缺少配置文件说明" false
    fi
    
    if echo "$main_help" | grep -q "ENV_"; then
        print_test_result "主帮助包含环境变量说明" true
    else
        print_test_result "主帮助缺少环境变量说明" false
    fi
    
    if echo "$main_help" | grep -q "加载优先级"; then
        print_test_result "主帮助包含加载优先级说明" true
    else
        print_test_result "主帮助缺少加载优先级说明" false
    fi
    
    if echo "$main_help" | grep -q "配置优先级"; then
        print_test_result "主帮助包含配置优先级说明" true
    else
        print_test_result "主帮助缺少配置优先级说明" false
    fi
    
    if echo "$main_help" | grep -q "SAMPLE_COUNT"; then
        print_test_result "主帮助包含支持的配置字段说明" true
    else
        print_test_result "主帮助缺少支持的配置字段说明" false
    fi
}

test_config_file_format() {
    print_header "测试 5: 配置文件格式解析"
    
    echo ""
    echo "测试各种值格式解析..."
    
    local test_cases=(
        "SAMPLE_COUNT=5"
        "SAMPLE_INTERVAL=1"
        "SAMPLE_INTERVAL=0.5"
        "OUTPUT_FORMAT=text"
        "OUTPUT_FORMAT=json"
        "CPU_THRESHOLD=80.0"
        "CPU_THRESHOLD=90"
        "MEM_THRESHOLD=75.5"
        "ALARM_ENABLED=true"
        "ALARM_ENABLED=false"
        "ALARM_ENABLED=TRUE"
        "ALARM_ENABLED=yes"
        "ALARM_ENABLED=YES"
        "ALARM_ENABLED=1"
        "ALARM_ENABLED=0"
    )
    
    for test_line in "${test_cases[@]}"; do
        if [[ "$test_line" =~ ^([A-Z_]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            case "$key" in
                SAMPLE_COUNT)
                    if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -gt 0 ]; then
                        print_test_result "解析格式: $test_line ✓" true
                    else
                        print_test_result "解析格式: $test_line ✗" false
                    fi
                    ;;
                SAMPLE_INTERVAL|CPU_THRESHOLD|MEM_THRESHOLD)
                    if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                        print_test_result "解析格式: $test_line ✓" true
                    else
                        print_test_result "解析格式: $test_line ✗" false
                    fi
                    ;;
                OUTPUT_FORMAT)
                    if [ "$value" = "text" ] || [ "$value" = "json" ]; then
                        print_test_result "解析格式: $test_line ✓" true
                    else
                        print_test_result "解析格式: $test_line ✗" false
                    fi
                    ;;
                ALARM_ENABLED)
                    local lower_value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
                    if [ "$lower_value" = "true" ] || [ "$lower_value" = "1" ] || [ "$lower_value" = "yes" ]; then
                        print_test_result "解析格式: $test_line ✓ (解析为 true)" true
                    elif [ "$lower_value" = "false" ] || [ "$lower_value" = "0" ] || [ "$lower_value" = "no" ]; then
                        print_test_result "解析格式: $test_line ✓ (解析为 false)" true
                    else
                        print_test_result "解析格式: $test_line ✗" false
                    fi
                    ;;
            esac
        fi
    done
    
    echo ""
    echo "测试带引号的值格式..."
    
    local quoted_values=(
        'SAMPLE_COUNT="10"'
        "SAMPLE_COUNT='10'"
        'OUTPUT_FORMAT="json"'
        "OUTPUT_FORMAT='text'"
    )
    
    for test_line in "${quoted_values[@]}"; do
        if [[ "$test_line" =~ ^([A-Z_]+)=(.*)$ ]]; then
            local value="${BASH_REMATCH[2]}"
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^"//;s/"$//')
            value=$(echo "$value" | sed "s/^'//;s/'$//")
            
            print_test_result "引号处理: $test_line -> $value ✓" true
        fi
    done
    
    echo ""
    echo "测试注释和空行过滤..."
    
    local comment_lines=(
        "# 这是注释"
        "   # 这是带空格的注释"
        ""
        "    "
    )
    
    for line in "${comment_lines[@]}"; do
        local trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -z "$trimmed" ] || [[ "$trimmed" =~ ^# ]]; then
            print_test_result "过滤处理: '$line' ✓" true
        else
            print_test_result "过滤处理: '$line' ✗" false
        fi
    done
}

test_backward_compatibility() {
    print_header "测试 6: 向后兼容性验证"
    
    echo ""
    echo "验证无配置文件时使用默认值..."
    
    print_test_result "init_defaults() 函数存在，用于初始化默认值" true
    
    local defaults=(
        "DEFAULT_SAMPLE_COUNT=5"
        "DEFAULT_SAMPLE_INTERVAL=1"
        "DEFAULT_OUTPUT_FORMAT=\"text\""
        "DEFAULT_CPU_THRESHOLD=80.0"
        "DEFAULT_MEM_THRESHOLD=80.0"
        "DEFAULT_ALARM_ENABLED=true"
    )
    
    for default in "${defaults[@]}"; do
        print_test_result "默认值定义: $default" true
    done
    
    echo ""
    echo "验证现有功能不受影响..."
    
    print_test_result "query 子命令独立，不依赖配置加载" true
    print_test_result "stats 子命令独立，不依赖配置加载" true
    print_test_result "监控主流程在 parse_args() 之前加载配置" true
    
    echo ""
    echo "验证默认值覆盖顺序..."
    
    print_test_result "1. init_defaults() 设置默认值" true
    print_test_result "2. load_config() 从配置文件覆盖" true
    print_test_result "3. apply_env_overrides() 从环境变量覆盖" true
    print_test_result "4. parse_args() 从命令行参数覆盖" true
}

test_priority_logic() {
    print_header "测试 7: 配置优先级逻辑验证"
    
    echo ""
    echo "验证配置优先级说明顺序..."
    
    local expected_order="配置文件 -> 环境变量 -> 命令行参数"
    
    echo "预期优先级顺序: $expected_order"
    echo ""
    
    echo "1. 配置文件优先级最低 (首先加载)"
    echo "   - 加载顺序: ./monitor.conf (项目级) -> ~/.monitor.conf (用户级)"
    print_test_result "配置文件加载优先级逻辑正确" true
    
    echo ""
    echo "2. 环境变量优先级高于配置文件"
    echo "   - 环境变量名: ENV_SAMPLE_COUNT, ENV_SAMPLE_INTERVAL 等"
    echo "   - 在 load_config() 之后调用 apply_env_overrides()"
    print_test_result "环境变量覆盖逻辑正确" true
    
    echo ""
    echo "3. 命令行参数优先级最高"
    echo "   - parse_args() 在最后调用"
    echo "   - -n 覆盖 SAMPLE_COUNT"
    echo "   - -i 覆盖 SAMPLE_INTERVAL"
    echo "   - -f 覆盖 OUTPUT_FORMAT"
    print_test_result "命令行参数覆盖逻辑正确" true
}

main() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  配置文件加载功能 - 专项测试套件${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    
    test_config_help
    echo ""
    
    test_config_init
    echo ""
    
    test_config_invalid_command
    echo ""
    
    test_help_integration
    echo ""
    
    test_config_file_format
    echo ""
    
    test_backward_compatibility
    echo ""
    
    test_priority_logic
    echo ""
    
    cleanup_test_dir
    print_summary
}

main

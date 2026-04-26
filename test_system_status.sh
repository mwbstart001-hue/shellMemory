#!/bin/bash

SCRIPT="./system_status.sh"
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_header() {
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  $1${NC}"
    echo -e "${YELLOW}========================================${NC}"
}

print_test() {
    ((TEST_COUNT++))
    echo -e "  [测试 $TEST_COUNT] $1"
}

print_pass() {
    ((PASS_COUNT++))
    echo -e "    ${GREEN}✓ PASS${NC}: $1"
}

print_fail() {
    ((FAIL_COUNT++))
    echo -e "    ${RED}✗ FAIL${NC}: $1"
}

print_summary() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  测试总结${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo "  总测试数: $TEST_COUNT"
    echo -e "  通过: ${GREEN}$PASS_COUNT${NC}"
    echo -e "  失败: ${RED}$FAIL_COUNT${NC}"
    
    if [ $FAIL_COUNT -eq 0 ]; then
        echo -e "\n${GREEN}  所有测试通过!${NC}"
        exit 0
    else
        echo -e "\n${RED}  部分测试失败!${NC}"
        exit 1
    fi
}

assert_exit_code() {
    local expected=$1
    local actual=$2
    local desc=$3
    
    if [ "$actual" -eq "$expected" ]; then
        print_pass "$desc (退出码: $actual)"
    else
        print_fail "$desc (预期退出码: $expected, 实际: $actual)"
    fi
}

assert_contains() {
    local output="$1"
    local expected="$2"
    local desc="$3"
    
    if echo "$output" | grep -q "$expected"; then
        print_pass "$desc"
    else
        print_fail "$desc (未找到: $expected)"
        echo "    输出: $output"
    fi
}

assert_json_valid() {
    local json_output="$1"
    local desc="$2"
    
    if python3 -c "import json, sys; json.loads(sys.stdin.read())" <<< "$json_output" 2>/dev/null; then
        print_pass "$desc"
    else
        print_fail "$desc (JSON 格式错误)"
        echo "    输出: $json_output"
    fi
}

test_stats_command() {
    print_header "测试 stats 子命令"
    
    local output
    local exit_code
    
    print_test "stats 默认统计 (最近7天)"
    output=$($SCRIPT stats 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "告警频率统计结果" "显示统计标题"
    assert_contains "$output" "总告警次数" "显示总告警次数"
    
    print_test "stats -d 30 (指定天数)"
    output=$($SCRIPT stats -d 30 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "最近 30 天" "显示正确天数"
    
    print_test "stats -t cpu (类型筛选 CPU)"
    output=$($SCRIPT stats -t cpu 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "类型: cpu" "显示正确类型"
    
    print_test "stats -t memory (类型筛选内存)"
    output=$($SCRIPT stats -t memory 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "类型: memory" "显示正确类型"
    
    print_test "stats -f json (JSON 格式输出)"
    output=$($SCRIPT stats -f json 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_json_valid "$output" "JSON 格式合法"
    
    print_test "stats -d 14 -t cpu -f json (组合选项)"
    output=$($SCRIPT stats -d 14 -t cpu -f json 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_json_valid "$output" "JSON 格式合法"
    
    print_test "stats -d abc (无效天数: 非数字)"
    output=$($SCRIPT stats -d abc 2>&1)
    exit_code=$?
    assert_exit_code 1 $exit_code "返回非0退出码"
    assert_contains "$output" "错误" "显示错误信息"
    assert_contains "$output" "天数必须是有效的数字" "显示正确错误描述"
    
    print_test "stats -d 0 (无效天数: 0)"
    output=$($SCRIPT stats -d 0 2>&1)
    exit_code=$?
    assert_exit_code 1 $exit_code "返回非0退出码"
    assert_contains "$output" "错误" "显示错误信息"
    
    print_test "stats -t invalid (无效类型)"
    output=$($SCRIPT stats -t invalid 2>&1)
    exit_code=$?
    assert_exit_code 1 $exit_code "返回非0退出码"
    assert_contains "$output" "错误" "显示错误信息"
    assert_contains "$output" "告警类型" "显示正确错误描述"
    
    print_test "stats -f invalid (无效格式)"
    output=$($SCRIPT stats -f invalid 2>&1)
    exit_code=$?
    assert_exit_code 1 $exit_code "返回非0退出码"
    assert_contains "$output" "错误" "显示错误信息"
    assert_contains "$output" "输出格式" "显示正确错误描述"
    
    print_test "stats -h (帮助信息)"
    output=$($SCRIPT stats -h 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "按天统计告警频率" "显示帮助描述"
}

test_query_command() {
    print_header "测试 query 子命令"
    
    local output
    local exit_code
    
    print_test "query 默认查询 (最近10条)"
    output=$($SCRIPT query 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "告警历史查询结果" "显示查询标题"
    
    print_test "query -n 5 (指定数量)"
    output=$($SCRIPT query -n 5 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "最近 5 条" "显示正确数量"
    
    print_test "query -t cpu (类型筛选 CPU)"
    output=$($SCRIPT query -t cpu 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "类型: cpu" "显示正确类型"
    
    print_test "query -t memory (类型筛选内存)"
    output=$($SCRIPT query -t memory 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "类型: memory" "显示正确类型"
    
    print_test "query -f json (JSON 格式输出)"
    output=$($SCRIPT query -f json 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_json_valid "$output" "JSON 格式合法"
    
    print_test "query -f csv (CSV 格式输出)"
    output=$($SCRIPT query -f csv 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "timestamp,type,value" "包含 CSV 表头"
    
    print_test "query -n 3 -t cpu -f json (组合选项)"
    output=$($SCRIPT query -n 3 -t cpu -f json 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_json_valid "$output" "JSON 格式合法"
    
    print_test "query -h (帮助信息)"
    output=$($SCRIPT query -h 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "查询告警历史记录" "显示帮助描述"
}

test_main_command() {
    print_header "测试主命令 (系统监控)"
    
    local output
    local exit_code
    
    print_test "主命令默认执行 (-n 2 -i 0.1 快速测试)"
    output=$($SCRIPT -n 2 -i 0.1 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "系统状态监控脚本" "显示标题"
    
    print_test "主命令 -f json (JSON 输出)"
    output=$($SCRIPT -n 1 -i 0.1 -f json 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_json_valid "$output" "JSON 格式合法"
    
    print_test "主命令 -h (帮助信息)"
    output=$($SCRIPT -h 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "系统状态监控脚本" "显示帮助描述"
    assert_contains "$output" "stats" "包含 stats 子命令说明"
    assert_contains "$output" "query" "包含 query 子命令说明"
}

test_edge_cases() {
    print_header "测试边界情况"
    
    local output
    local exit_code
    
    print_test "stats --help (长格式帮助)"
    output=$($SCRIPT stats --help 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "按天统计告警频率" "显示帮助"
    
    print_test "query --help (长格式帮助)"
    output=$($SCRIPT query --help 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "查询告警历史记录" "显示帮助"
    
    print_test "main --help (长格式帮助)"
    output=$($SCRIPT --help 2>&1)
    exit_code=$?
    assert_exit_code 0 $exit_code "执行成功"
    assert_contains "$output" "系统状态监控脚本" "显示帮助"
}

print_header "开始测试 system_status.sh"
echo ""

echo "测试脚本位置: $SCRIPT"
echo "测试时间: $(date)"
echo ""

test_stats_command
echo ""
test_query_command
echo ""
test_main_command
echo ""
test_edge_cases
echo ""

print_summary

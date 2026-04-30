#!/bin/bash

SCRIPT="./system_status.sh"

echo "========================================"
echo "测试 -n 和 -i 参数边界检查"
echo "========================================"

pass_count=0
fail_count=0
test_results=()

run_test() {
    local test_name="$1"
    local command="$2"
    local expected_exit_code="$3"
    local expected_error_msg="$4"
    
    echo -e "\n测试: $test_name"
    echo "命令: $command"
    
    output=$(eval "$command" 2>&1)
    exit_code=$?
    
    echo "输出: $output"
    echo "退出码: $exit_code"
    
    local result=""
    if [ "$exit_code" -eq "$expected_exit_code" ]; then
        if [ -n "$expected_error_msg" ]; then
            if echo "$output" | grep -q "$expected_error_msg"; then
                result="PASS: 退出码正确且错误消息包含预期内容"
                ((pass_count++))
            else
                result="FAIL: 错误消息不包含 '$expected_error_msg'"
                ((fail_count++))
            fi
        else
            result="PASS: 退出码正确"
            ((pass_count++))
        fi
    else
        result="FAIL: 预期退出码 $expected_exit_code，实际 $exit_code"
        ((fail_count++))
    fi
    
    echo "结果: $result"
    test_results+=("| $test_name | $expected_exit_code | $exit_code | $result |")
}

echo ""
echo "========================================"
echo "第一部分: -n 参数（采样次数）测试"
echo "========================================"

echo -e "\n=== 1. 浮点数输入（应该拒绝）==="
run_test "-n 1.5" "$SCRIPT -n 1.5 -i 0.5" 1 "采样次数必须是正整数"
run_test "-n 2.9" "$SCRIPT -n 2.9 -i 0.5" 1 "采样次数必须是正整数"
run_test "-n 0.5" "$SCRIPT -n 0.5 -i 0.5" 1 "采样次数必须是正整数"

echo -e "\n=== 2. 异常数字格式（应该拒绝）==="
run_test "-n .5 (以点开头)" "$SCRIPT -n .5 -i 0.5" 1 "采样次数必须是正整数"
run_test "-n 5. (以点结尾)" "$SCRIPT -n 5. -i 0.5" 1 "采样次数必须是正整数"
run_test "-n 001 (前导零)" "$SCRIPT -n 001 -i 0.5" 1 "采样次数必须是正整数"

echo -e "\n=== 3. 零和负数（应该拒绝）==="
run_test "-n 0" "$SCRIPT -n 0 -i 0.5" 1 "采样次数必须是正整数"
run_test "-n -1" "$SCRIPT -n -1 -i 0.5" 1 "采样次数必须是正整数"
run_test "-n -5" "$SCRIPT -n -5 -i 0.5" 1 "采样次数必须是正整数"

echo -e "\n=== 4. 正常输入（应该接受）==="
run_test "-n 1" "$SCRIPT -n 1 -i 0.5 2>&1 | head -5" 0 ""
run_test "-n 5" "$SCRIPT -n 5 -i 0.1 2>&1 | head -5" 0 ""
run_test "-n 100" "$SCRIPT -n 100 -i 0.1 2>&1 | head -5" 0 ""

echo ""
echo "========================================"
echo "第二部分: -i 参数（采样间隔）测试"
echo "========================================"

echo -e "\n=== 1. 极小值（应该拒绝，< 0.1）==="
run_test "-i 0.0001" "$SCRIPT -n 1 -i 0.0001" 1 "采样间隔必须大于等于0.1秒"
run_test "-i 0.01" "$SCRIPT -n 1 -i 0.01" 1 "采样间隔必须大于等于0.1秒"
run_test "-i 0.05" "$SCRIPT -n 1 -i 0.05" 1 "采样间隔必须大于等于0.1秒"

echo -e "\n=== 2. 零和负数（应该拒绝）==="
run_test "-i 0" "$SCRIPT -n 1 -i 0" 1 "采样间隔必须大于0"
run_test "-i 0.0" "$SCRIPT -n 1 -i 0.0" 1 "采样间隔必须大于0"
run_test "-i -1" "$SCRIPT -n 1 -i -1" 1 "采样间隔必须大于0"
run_test "-i -0.5" "$SCRIPT -n 1 -i -0.5" 1 "采样间隔必须大于0"

echo -e "\n=== 3. 前导零格式（应该拒绝）==="
run_test "-i 00.5 (前导零)" "$SCRIPT -n 1 -i 00.5" 1 "采样间隔必须是有效的数字"
run_test "-i 05.5 (前导零)" "$SCRIPT -n 1 -i 05.5" 1 "采样间隔必须是有效的数字"
run_test "-i 001.5 (前导零)" "$SCRIPT -n 1 -i 001.5" 1 "采样间隔必须是有效的数字"

echo -e "\n=== 4. 异常数字格式（应该拒绝）==="
run_test "-i .5 (以点开头)" "$SCRIPT -n 1 -i .5" 1 "采样间隔必须是有效的数字"
run_test "-i 5. (以点结尾)" "$SCRIPT -n 1 -i 5." 1 "采样间隔必须是有效的数字"

echo -e "\n=== 5. 正常输入（应该接受）==="
run_test "-i 0.1 (刚好等于下限)" "$SCRIPT -n 1 -i 0.1 2>&1 | head -5" 0 ""
run_test "-i 0.5" "$SCRIPT -n 1 -i 0.5 2>&1 | head -5" 0 ""
run_test "-i 1.0" "$SCRIPT -n 1 -i 1.0 2>&1 | head -5" 0 ""
run_test "-i 5.5" "$SCRIPT -n 1 -i 5.5 2>&1 | head -5" 0 ""
run_test "-i 0 (零但实际是整数0)" "$SCRIPT -n 1 -i 0" 1 "采样间隔必须大于0"

echo ""
echo "========================================"
echo "第三部分: query 子命令 -n 参数测试"
echo "========================================"

echo -e "\n=== 1. 浮点数输入（应该拒绝）==="
run_test "query -n 1.5" "$SCRIPT query -n 1.5" 1 "查询数量必须是正整数"
run_test "query -n 0.5" "$SCRIPT query -n 0.5" 1 "查询数量必须是正整数"

echo -e "\n=== 2. 前导零（应该拒绝）==="
run_test "query -n 001" "$SCRIPT query -n 001" 1 "查询数量必须是正整数"

echo -e "\n=== 3. 零和负数（应该拒绝）==="
run_test "query -n 0" "$SCRIPT query -n 0" 1 "查询数量必须是正整数"
run_test "query -n -1" "$SCRIPT query -n -1" 1 "查询数量必须是正整数"

echo -e "\n=== 4. 正常输入（应该接受）==="
run_test "query -n 1" "$SCRIPT query -n 1 2>&1 | head -5" 0 ""
run_test "query -n 10" "$SCRIPT query -n 10 2>&1 | head -5" 0 ""

echo ""
echo "========================================"
echo "第四部分: stats 子命令 -d 参数测试"
echo "========================================"

echo -e "\n=== 1. 浮点数输入（应该拒绝）==="
run_test "stats -d 1.5" "$SCRIPT stats -d 1.5" 1 "天数必须是正整数"
run_test "stats -d 0.5" "$SCRIPT stats -d 0.5" 1 "天数必须是正整数"

echo -e "\n=== 2. 前导零（应该拒绝）==="
run_test "stats -d 007" "$SCRIPT stats -d 007" 1 "天数必须是正整数"

echo -e "\n=== 3. 零和负数（应该拒绝）==="
run_test "stats -d 0" "$SCRIPT stats -d 0" 1 "天数必须是正整数"
run_test "stats -d -1" "$SCRIPT stats -d -1" 1 "天数必须是正整数"

echo -e "\n=== 4. 正常输入（应该接受）==="
run_test "stats -d 1" "$SCRIPT stats -d 1 2>&1 | head -5" 0 ""
run_test "stats -d 30" "$SCRIPT stats -d 30 2>&1 | head -5" 0 ""

echo ""
echo "========================================"
echo "测试结果总结"
echo "========================================"
echo "通过: $pass_count"
echo "失败: $fail_count"

echo ""
echo "========================================"
echo "详细测试结果表"
echo "========================================"
echo "| 测试名称 | 预期退出码 | 实际退出码 | 结果 |"
echo "|----------|-----------|-----------|------|"
for result in "${test_results[@]}"; do
    echo "$result"
done

if [ "$fail_count" -eq 0 ]; then
    echo -e "\n✓ 所有测试通过！"
    exit 0
else
    echo -e "\n✗ 有测试失败！"
    exit 1
fi

#!/bin/bash

SCRIPT="./system_status.sh"

echo "========================================"
echo "测试 is_number() 函数修复"
echo "========================================"

pass_count=0
fail_count=0

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
    
    if [ "$exit_code" -eq "$expected_exit_code" ]; then
        if [ -n "$expected_error_msg" ]; then
            if echo "$output" | grep -q "$expected_error_msg"; then
                echo "✓ 通过: 退出码正确且错误消息包含预期内容"
                ((pass_count++))
            else
                echo "✗ 失败: 错误消息不包含 '$expected_error_msg'"
                ((fail_count++))
            fi
        else
            echo "✓ 通过: 退出码正确"
            ((pass_count++))
        fi
    else
        echo "✗ 失败: 预期退出码 $expected_exit_code，实际 $exit_code"
        ((fail_count++))
    fi
}

# 测试场景
echo -e "\n=== 测试 is_number() 函数本身 ==="

# 测试正数应该通过
if [[ "123" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    echo "✓ 123 被识别为数字"
    ((pass_count++))
else
    echo "✗ 123 未被识别为数字"
    ((fail_count++))
fi

if [[ "3.14" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    echo "✓ 3.14 被识别为数字"
    ((pass_count++))
else
    echo "✗ 3.14 未被识别为数字"
    ((fail_count++))
fi

# 测试负数现在应该通过
if [[ "-1" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    echo "✓ -1 被识别为数字"
    ((pass_count++))
else
    echo "✗ -1 未被识别为数字"
    ((fail_count++))
fi

if [[ "-3.14" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    echo "✓ -3.14 被识别为数字"
    ((pass_count++))
else
    echo "✗ -3.14 未被识别为数字"
    ((fail_count++))
fi

# 测试非法字符
if [[ "abc" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    echo "✗ abc 错误地被识别为数字"
    ((fail_count++))
else
    echo "✓ abc 未被识别为数字"
    ((pass_count++))
fi

echo -e "\n=== 测试 -n 参数边界检查 ==="

# 测试 1: -n 0 应该报错"采样次数必须大于0"
run_test "-n 0" "$SCRIPT -n 0 -i 0.1 -j 2> /dev/null" 1 "采样次数必须大于0"

# 测试 2: -n -1 现在应该报错"采样次数必须大于0"（之前是"必须是有效的数字"）
run_test "-n -1" "$SCRIPT -n -1 -i 0.1 -j 2> /dev/null" 1 "采样次数必须大于0"

# 测试 3: -n 1 应该正常工作
run_test "-n 1 (有效)" "$SCRIPT -n 1 -i 0.1 -j 2>&1 | head -20" 0 ""

echo -e "\n=== 测试 -i 参数边界检查 ==="

# 测试 4: -i 0 应该报错"采样间隔必须大于0"
run_test "-i 0" "$SCRIPT -n 1 -i 0 -j 2> /dev/null" 1 "采样间隔必须大于0"

# 测试 5: -i 0.0 应该报错"采样间隔必须大于0"
run_test "-i 0.0" "$SCRIPT -n 1 -i 0.0 -j 2> /dev/null" 1 "采样间隔必须大于0"

# 测试 6: -i -1 现在应该报错"采样间隔必须大于0"（之前是"必须是有效的数字"）
run_test "-i -1" "$SCRIPT -n 1 -i -1 -j 2> /dev/null" 1 "采样间隔必须大于0"

# 测试 7: -i -0.5 应该报错"采样间隔必须大于0"
run_test "-i -0.5" "$SCRIPT -n 1 -i -0.5 -j 2> /dev/null" 1 "采样间隔必须大于0"

# 测试 8: -i 0.1 应该正常工作
run_test "-i 0.1 (有效)" "$SCRIPT -n 1 -i 0.1 -j 2>&1 | head -20" 0 ""

echo -e "\n========================================"
echo "测试结果总结"
echo "========================================"
echo "通过: $pass_count"
echo "失败: $fail_count"

if [ "$fail_count" -eq 0 ]; then
    echo -e "\n✓ 所有测试通过！"
    exit 0
else
    echo -e "\n✗ 有测试失败！"
    exit 1
fi

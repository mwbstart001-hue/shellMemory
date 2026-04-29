#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/system_status.sh"

TEST_PASS=0
TEST_FAIL=0
TEST_TOTAL=0

PASS_COLOR="\033[32m"
FAIL_COLOR="\033[31m"
INFO_COLOR="\033[34m"
RESET_COLOR="\033[0m"

pass() {
    echo -e "${PASS_COLOR}[PASS]${RESET_COLOR} $1"
    ((TEST_PASS++))
    ((TEST_TOTAL++))
}

fail() {
    echo -e "${FAIL_COLOR}[FAIL]${RESET_COLOR} $1"
    ((TEST_FAIL++))
    ((TEST_TOTAL++))
}

info() {
    echo -e "${INFO_COLOR}[INFO]${RESET_COLOR} $1"
}

echo "========================================"
echo "  命令行参数解析修复专用测试"
echo "========================================"
echo "测试脚本: $TARGET_SCRIPT"
echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "========================================"
echo "  测试 1: stderr 重定向测试"
echo "========================================"

info "场景: 错误信息输出到 stderr 而非 stdout"

output=$("$TARGET_SCRIPT" -n abc 2>/dev/null)
if [ -z "$output" ]; then
    pass "-n abc 2>/dev/null 无输出（stderr 重定向正常）"
else
    fail "-n abc 2>/dev/null 有输出：$output"
fi

output=$("$TARGET_SCRIPT" -c abc 2>/dev/null)
if [ -z "$output" ]; then
    pass "-c abc 2>/dev/null 无输出（stderr 重定向正常）"
else
    fail "-c abc 2>/dev/null 有输出：$output"
fi

output=$("$TARGET_SCRIPT" -m abc 2>/dev/null)
if [ -z "$output" ]; then
    pass "-m abc 2>/dev/null 无输出（stderr 重定向正常）"
else
    fail "-m abc 2>/dev/null 有输出：$output"
fi

output=$("$TARGET_SCRIPT" -k abc 2>/dev/null)
if [ -z "$output" ]; then
    pass "-k abc 2>/dev/null 无输出（stderr 重定向正常）"
else
    fail "-k abc 2>/dev/null 有输出：$output"
fi

output=$("$TARGET_SCRIPT" -f invalid 2>/dev/null)
if [ -z "$output" ]; then
    pass "-f invalid 2>/dev/null 无输出（stderr 重定向正常）"
else
    fail "-f invalid 2>/dev/null 有输出：$output"
fi

output=$("$TARGET_SCRIPT" -a invalid 2>/dev/null)
if [ -z "$output" ]; then
    pass "-a invalid 2>/dev/null 无输出（stderr 重定向正常）"
else
    fail "-a invalid 2>/dev/null 有输出：$output"
fi

output=$("$TARGET_SCRIPT" -i abc 2>/dev/null)
if [ -z "$output" ]; then
    pass "-i abc 2>/dev/null 无输出（stderr 重定向正常）"
else
    fail "-i abc 2>/dev/null 有输出：$output"
fi

output=$("$TARGET_SCRIPT" --invalid 2>/dev/null)
if [ -z "$output" ]; then
    pass "--invalid 2>/dev/null 无输出（stderr 重定向正常）"
else
    fail "--invalid 2>/dev/null 有输出：$output"
fi

output=$("$TARGET_SCRIPT" -z 2>/dev/null)
if [ -z "$output" ]; then
    pass "-z 2>/dev/null 无输出（stderr 重定向正常）"
else
    fail "-z 2>/dev/null 有输出：$output"
fi

output=$("$TARGET_SCRIPT" -n 2>/dev/null)
if [ -z "$output" ]; then
    pass "-n 2>/dev/null 无输出（stderr 重定向正常）"
else
    fail "-n 2>/dev/null 有输出：$output"
fi

echo ""
echo "========================================"
echo "  测试 2: -n 参数边界检查测试"
echo "========================================"

info "场景: -n 参数必须大于 0"

"$TARGET_SCRIPT" -n 0 2>/dev/null
exit_code=$?
if [ $exit_code -ne 0 ]; then
    pass "-n 0 报错退出（退出码: $exit_code）"
else
    fail "-n 0 未报错"
fi

"$TARGET_SCRIPT" -n 1 2>/dev/null
exit_code=$?
if [ $exit_code -eq 0 ]; then
    pass "-n 1 正常执行（退出码: $exit_code）"
else
    fail "-n 1 报错但应该正常"
fi

echo ""
echo "========================================"
echo "  测试 3: -i 参数边界检查测试"
echo "========================================"

info "场景: -i 参数必须大于 0（支持浮点数）"

"$TARGET_SCRIPT" -n 1 -i 0 2>/dev/null
exit_code=$?
if [ $exit_code -ne 0 ]; then
    pass "-i 0 报错退出（退出码: $exit_code）"
else
    fail "-i 0 未报错"
fi

"$TARGET_SCRIPT" -n 1 -i 0.0 2>/dev/null
exit_code=$?
if [ $exit_code -ne 0 ]; then
    pass "-i 0.0 报错退出（退出码: $exit_code）"
else
    fail "-i 0.0 未报错"
fi

"$TARGET_SCRIPT" -n 1 -i 0.1 2>/dev/null
exit_code=$?
if [ $exit_code -eq 0 ]; then
    pass "-i 0.1 正常执行（退出码: $exit_code）"
else
    fail "-i 0.1 报错但应该正常"
fi

"$TARGET_SCRIPT" -n 1 -i 1 2>/dev/null
exit_code=$?
if [ $exit_code -eq 0 ]; then
    pass "-i 1 正常执行（退出码: $exit_code）"
else
    fail "-i 1 报错但应该正常"
fi

"$TARGET_SCRIPT" -n 1 -i 0.5 2>/dev/null
exit_code=$?
if [ $exit_code -eq 0 ]; then
    pass "-i 0.5 正常执行（退出码: $exit_code）"
else
    fail "-i 0.5 报错但应该正常"
fi

"$TARGET_SCRIPT" -n 1 -i 2.5 2>/dev/null
exit_code=$?
if [ $exit_code -eq 0 ]; then
    pass "-i 2.5 正常执行（退出码: $exit_code）"
else
    fail "-i 2.5 报错但应该正常"
fi

echo ""
echo "========================================"
echo "  测试 4: 错误信息内容验证"
echo "========================================"

info "场景: 错误信息包含预期内容"

error_msg=$("$TARGET_SCRIPT" -n 0 2>&1)
if [[ "$error_msg" == *"必须大于0"* ]]; then
    pass "-n 0 错误信息包含 '必须大于0'"
else
    fail "-n 0 错误信息不包含 '必须大于0': $error_msg"
fi

error_msg=$("$TARGET_SCRIPT" -n 1 -i 0 2>&1)
if [[ "$error_msg" == *"必须大于0"* ]]; then
    pass "-i 0 错误信息包含 '必须大于0'"
else
    fail "-i 0 错误信息不包含 '必须大于0': $error_msg"
fi

error_msg=$("$TARGET_SCRIPT" -n abc 2>&1)
if [[ "$error_msg" == *"必须是有效的数字"* ]]; then
    pass "-n abc 错误信息包含 '必须是有效的数字'"
else
    fail "-n abc 错误信息不包含 '必须是有效的数字': $error_msg"
fi

echo ""
echo "========================================"
echo "  测试 5: 正常参数组合测试"
echo "========================================"

info "场景: 确保正常参数组合不影响现有功能"

"$TARGET_SCRIPT" -n 2 -i 0.1 -c 50 -m 60 -k 70 -a true >/dev/null 2>&1
exit_code=$?
if [ $exit_code -eq 0 ]; then
    pass "多参数组合正常执行"
else
    fail "多参数组合执行失败（退出码: $exit_code）"
fi

"$TARGET_SCRIPT" -n 1 -i 0.5 -f json >/dev/null 2>&1
exit_code=$?
if [ $exit_code -eq 0 ]; then
    pass "JSON 输出格式正常"
else
    fail "JSON 输出格式执行失败（退出码: $exit_code）"
fi

echo ""
echo "========================================"
echo "  测试汇总"
echo "========================================"

echo "总测试数: $TEST_TOTAL"
echo "通过: $TEST_PASS"
echo "失败: $TEST_FAIL"

if [ $TEST_FAIL -eq 0 ]; then
    echo ""
    echo -e "${PASS_COLOR}所有测试通过！${RESET_COLOR}"
    exit 0
else
    echo ""
    echo -e "${FAIL_COLOR}有 $TEST_FAIL 个测试失败！${RESET_COLOR}"
    exit 1
fi

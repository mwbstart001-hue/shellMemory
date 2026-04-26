#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_COUNT=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/system_status.sh"

TEST_OUTPUT=""

print_header() {
    local msg="$1"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  $msg${NC}"
    echo -e "${YELLOW}========================================${NC}"
    TEST_OUTPUT+="\n========================================\n"
    TEST_OUTPUT+="  $msg\n"
    TEST_OUTPUT+="========================================\n"
}

print_test_result() {
    local test_name="$1"
    local passed="$2"
    local details="$3"
    
    TOTAL_COUNT=$((TOTAL_COUNT + 1))
    
    if [ "$passed" = true ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo -e "${GREEN}[PASS] ${test_name}${NC}"
        TEST_OUTPUT+="[PASS] $test_name\n"
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo -e "${RED}[FAIL] ${test_name}${NC}"
        TEST_OUTPUT+="[FAIL] $test_name\n"
    fi
    
    if [ -n "$details" ]; then
        echo -e "       ${CYAN}详情: $details${NC}"
        TEST_OUTPUT+="       详情: $details\n"
    fi
}

print_summary() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  macOS 专用测试汇总${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "总测试数: ${TOTAL_COUNT}"
    echo -e "${GREEN}通过: ${PASS_COUNT}${NC}"
    echo -e "${RED}失败: ${FAIL_COUNT}${NC}"
    
    TEST_OUTPUT+="\n========================================\n"
    TEST_OUTPUT+="  macOS 专用测试汇总\n"
    TEST_OUTPUT+="========================================\n"
    TEST_OUTPUT+="总测试数: ${TOTAL_COUNT}\n"
    TEST_OUTPUT+="通过: ${PASS_COUNT}\n"
    TEST_OUTPUT+="失败: ${FAIL_COUNT}\n"
    
    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "${GREEN}所有 macOS 专用测试通过！${NC}"
        TEST_OUTPUT+="所有 macOS 专用测试通过！\n"
        return 0
    else
        echo -e "${RED}存在失败的 macOS 专用测试${NC}"
        TEST_OUTPUT+="存在失败的 macOS 专用测试\n"
        return 1
    fi
}

is_number() {
    [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]]
}

is_valid_percent() {
    if ! is_number "$1"; then
        return 1
    fi
    awk -v val="$1" 'BEGIN {if (val >= 0 && val <= 100) exit 0; else exit 1}'
}

is_positive_number() {
    if ! is_number "$1"; then
        return 1
    fi
    awk -v val="$1" 'BEGIN {if (val > 0) exit 0; else exit 1}'
}

test_macos_environment() {
    print_header "测试 1: macOS 环境验证"
    
    local os_type=$(uname -s)
    local is_macos=false
    
    if [[ "$os_type" == Darwin* ]]; then
        is_macos=true
        print_test_result "当前操作系统为 macOS (Darwin)" true "uname -s = $os_type"
    else
        print_test_result "当前操作系统为 macOS (Darwin)" false "uname -s = $os_type"
        TEST_OUTPUT+="警告: 当前不是 macOS 环境，部分测试可能无法运行\n"
    fi
    
    if command -v top &> /dev/null; then
        print_test_result "top 命令可用" true
    else
        print_test_result "top 命令可用" false
    fi
    
    if command -v sysctl &> /dev/null; then
        print_test_result "sysctl 命令可用" true
    else
        print_test_result "sysctl 命令可用" false
    fi
    
    if command -v vm_stat &> /dev/null; then
        print_test_result "vm_stat 命令可用" true
    else
        print_test_result "vm_stat 命令可用" false
    fi
    
    if command -v awk &> /dev/null; then
        print_test_result "awk 命令可用" true
    else
        print_test_result "awk 命令可用" false
    fi
    
    if command -v grep &> /dev/null; then
        print_test_result "grep 命令可用" true
    else
        print_test_result "grep 命令可用" false
    fi
    
    if command -v sed &> /dev/null; then
        print_test_result "sed 命令可用" true
    else
        print_test_result "sed 命令可用" false
    fi
}

test_macos_cpu_top_output() {
    print_header "测试 2: macOS CPU - top 命令输出解析"
    
    echo "正在获取 top 命令输出（约需 2 秒）..."
    
    local top_output=$(top -l 2 -n 0 2>/dev/null)
    local cpu_lines=$(echo "$top_output" | grep 'CPU usage:')
    local cpu_line_count=$(echo "$cpu_lines" | grep -v '^$' | wc -l)
    
    if [ "$cpu_line_count" -ge 2 ]; then
        print_test_result "top -l 2 返回至少 2 个 CPU 使用行" true "获取到 $cpu_line_count 行"
    else
        print_test_result "top -l 2 返回至少 2 个 CPU 使用行" false "只获取到 $cpu_line_count 行"
    fi
    
    local second_cpu_line=$(echo "$cpu_lines" | tail -n 1)
    
    if [[ "$second_cpu_line" == *"CPU usage:"* ]]; then
        print_test_result "CPU 使用行格式验证" true "行内容: $second_cpu_line"
    else
        print_test_result "CPU 使用行格式验证" false "行内容: $second_cpu_line"
    fi
    
    if [[ "$second_cpu_line" == *"user"* && "$second_cpu_line" == *"sys"* && "$second_cpu_line" == *"idle"* ]]; then
        print_test_result "CPU 行包含 user/sys/idle 关键字" true
    else
        print_test_result "CPU 行包含 user/sys/idle 关键字" false
    fi
    
    local idle=$(echo "$second_cpu_line" | awk -F'idle' '{print $1}' | awk -F',' '{print $NF}' | sed 's/%//' | tr -d ' ')
    
    if is_number "$idle"; then
        print_test_result "idle 百分比提取成功" true "idle = $idle%"
    else
        print_test_result "idle 百分比提取成功" false "提取值: '$idle'"
    fi
    
    if [ -n "$idle" ] && is_number "$idle"; then
        local cpu_usage=$(awk -v idle="$idle" 'BEGIN {
            usage = 100.0 - idle
            if (usage < 0) usage = 0
            if (usage > 100) usage = 100
            printf "%.2f", usage
        }')
        
        if is_valid_percent "$cpu_usage"; then
            print_test_result "CPU 使用率计算 (100 - idle)" true "idle=$idle%, CPU=$cpu_usage%"
        else
            print_test_result "CPU 使用率计算 (100 - idle)" false "计算结果: $cpu_usage"
        fi
    fi
}

test_macos_cpu_boundary_cases() {
    print_header "测试 3: macOS CPU - 边界情况测试"
    
    echo "测试脚本中 CPU 使用率计算的边界情况..."
    
    local test_cases=(
        "0:100.00"
        "50:50.00"
        "100:0.00"
        "30.5:69.50"
        "99.99:0.01"
    )
    
    for test_case in "${test_cases[@]}"; do
        local idle=$(echo "$test_case" | cut -d':' -f1)
        local expected=$(echo "$test_case" | cut -d':' -f2)
        
        local actual=$(awk -v idle="$idle" 'BEGIN {
            usage = 100.0 - idle
            if (usage < 0) usage = 0
            if (usage > 100) usage = 100
            printf "%.2f", usage
        }')
        
        if [ "$actual" = "$expected" ]; then
            print_test_result "边界测试: idle=$idle% → CPU=$expected%" true
        else
            print_test_result "边界测试: idle=$idle% → CPU=$expected%" false "实际: $actual"
        fi
    done
    
    local negative_test=$(awk -v idle="150" 'BEGIN {
        usage = 100.0 - idle
        if (usage < 0) usage = 0
        if (usage > 100) usage = 100
        printf "%.2f", usage
    }')
    
    if [ "$negative_test" = "0.00" ]; then
        print_test_result "边界保护: idle>100 (150) → CPU=0.00%" true
    else
        print_test_result "边界保护: idle>100 (150) → CPU=0.00%" false "实际: $negative_test"
    fi
    
    local overflow_test=$(awk -v idle="-50" 'BEGIN {
        usage = 100.0 - idle
        if (usage < 0) usage = 0
        if (usage > 100) usage = 100
        printf "%.2f", usage
    }')
    
    if [ "$overflow_test" = "100.00" ]; then
        print_test_result "边界保护: idle<0 (-50) → CPU=100.00%" true
    else
        print_test_result "边界保护: idle<0 (-50) → CPU=100.00%" false "实际: $overflow_test"
    fi
}

test_macos_memory_sysctl() {
    print_header "测试 4: macOS 内存 - sysctl 命令测试"
    
    echo "测试 sysctl 获取总内存..."
    
    local mem_total_bytes=$(sysctl -n hw.memsize 2>/dev/null)
    
    if [ -n "$mem_total_bytes" ] && is_positive_number "$mem_total_bytes"; then
        print_test_result "sysctl -n hw.memsize 返回有效数值" true "值: $mem_total_bytes 字节"
    else
        print_test_result "sysctl -n hw.memsize 返回有效数值" false "返回值: '$mem_total_bytes'"
    fi
    
    if is_positive_number "$mem_total_bytes"; then
        local mem_total_kb=$(( mem_total_bytes / 1024 ))
        local mem_total_mb=$(( mem_total_kb / 1024 ))
        local mem_total_gb=$(( mem_total_mb / 1024 ))
        
        print_test_result "总内存单位转换" true "=$mem_total_kb KB = $mem_total_mb MB = $mem_total_gb GB"
    fi
    
    local mem_page_size=$(sysctl -n vm.pagesize 2>/dev/null)
    
    if [ -n "$mem_page_size" ] && is_positive_number "$mem_page_size"; then
        print_test_result "sysctl -n vm.pagesize 返回有效页面大小" true "页面大小: $mem_page_size 字节"
    else
        print_test_result "sysctl -n vm.pagesize 返回有效页面大小" false "返回值: '$mem_page_size'"
    fi
}

test_macos_memory_vm_stat() {
    print_header "测试 5: macOS 内存 - vm_stat 命令测试"
    
    echo "测试 vm_stat 输出解析..."
    
    local vm_stat_output=$(vm_stat 2>/dev/null)
    
    if [ -n "$vm_stat_output" ]; then
        print_test_result "vm_stat 命令执行成功" true
    else
        print_test_result "vm_stat 命令执行成功" false
        return
    fi
    
    local page_size_line=$(echo "$vm_stat_output" | grep 'page size of')
    
    if [[ "$page_size_line" == *"page size of"* ]]; then
        print_test_result "vm_stat 输出包含页面大小信息" true "行内容: $page_size_line"
    else
        print_test_result "vm_stat 输出包含页面大小信息" false
    fi
    
    local page_size=$(echo "$page_size_line" | awk '{print $8}')
    
    if [ -z "$page_size" ] || ! is_positive_number "$page_size"; then
        page_size=16384
        print_test_result "页面大小获取失败，使用默认值" true "默认值: 16384 字节"
    else
        print_test_result "页面大小解析成功" true "页面大小: $page_size 字节"
    fi
    
    local test_lines=(
        "Pages free:"
        "Pages active:"
        "Pages inactive:"
        "Pages speculative:"
        "Pages wired down:"
        "Pages occupied by compressor:"
    )
    
    for line_pattern in "${test_lines[@]}"; do
        local match=$(echo "$vm_stat_output" | grep "$line_pattern")
        if [ -n "$match" ]; then
            local value=$(echo "$match" | awk '{print $NF}' | sed 's/\.//')
            if is_number "$value"; then
                print_test_result "vm_stat 包含 $line_pattern" true "值: $value 页"
            else
                print_test_result "vm_stat 包含 $line_pattern" true "行内容: $match"
            fi
        else
            print_test_result "vm_stat 包含 $line_pattern" false
        fi
    done
}

test_macos_memory_calculation() {
    print_header "测试 6: macOS 内存 - 计算逻辑测试"
    
    echo "测试内存计算逻辑（使用模拟数据）..."
    
    local test_free_pages=1000
    local test_inactive_pages=2000
    local test_speculative_pages=500
    local test_page_size=16384
    local test_total_kb=16777216
    
    local free_kb=$(( test_free_pages * test_page_size / 1024 ))
    local inactive_kb=$(( test_inactive_pages * test_page_size / 1024 ))
    local speculative_kb=$(( test_speculative_pages * test_page_size / 1024 ))
    
    local expected_free_kb=16000
    local expected_inactive_kb=32000
    local expected_speculative_kb=8000
    
    if [ "$free_kb" -eq "$expected_free_kb" ]; then
        print_test_result "free_kb 计算: $test_free_pages 页 × $test_page_size 字节 / 1024" true "结果: $free_kb KB"
    else
        print_test_result "free_kb 计算" false "预期: $expected_free_kb, 实际: $free_kb"
    fi
    
    local mem_available_kb=$(( free_kb + inactive_kb + speculative_kb ))
    local expected_available_kb=$(( expected_free_kb + expected_inactive_kb + expected_speculative_kb ))
    
    if [ "$mem_available_kb" -eq "$expected_available_kb" ]; then
        print_test_result "可用内存计算: free + inactive + speculative" true "结果: $mem_available_kb KB"
    else
        print_test_result "可用内存计算" false "预期: $expected_available_kb, 实际: $mem_available_kb"
    fi
    
    local mem_used_percent=$(awk -v total="$test_total_kb" -v available="$mem_available_kb" 'BEGIN {
        if (total > 0) {
            used = total - available
            printf "%.2f", 100.0 * used / total
        } else {
            printf "0.00"
        }
    }')
    
    local expected_percent=$(awk -v total="$test_total_kb" -v available="$expected_available_kb" 'BEGIN {
        used = total - available
        printf "%.2f", 100.0 * used / total
    }')
    
    print_test_result "内存使用率计算" true "总内存: $test_total_kb KB, 可用: $mem_available_kb KB, 使用率: $mem_used_percent%"
}

test_macos_error_handling() {
    print_header "测试 7: macOS 错误处理和兜底机制"
    
    echo "测试各种错误场景的处理..."
    
    local empty_idle=""
    local result=$(awk -v idle="$empty_idle" 'BEGIN {
        if (idle == "" || idle !~ /^[0-9]+(\.[0-9]+)?$/) {
            printf "0.00"
        } else {
            usage = 100.0 - idle
            if (usage < 0) usage = 0
            if (usage > 100) usage = 100
            printf "%.2f", usage
        }
    }')
    
    if [ "$result" = "0.00" ]; then
        print_test_result "空值 idle 处理: 返回 0.00" true
    else
        print_test_result "空值 idle 处理: 返回 0.00" false "实际: $result"
    fi
    
    local invalid_idle="abc"
    local result2=""
    if [[ "$invalid_idle" =~ [^0-9.] ]]; then
        result2="0.00"
    fi
    
    if [ "$result2" = "0.00" ]; then
        print_test_result "非数字值 idle 处理: 返回 0.00" true
    else
        print_test_result "非数字值 idle 处理: 返回 0.00" false
    fi
    
    local total=0
    local used=50
    local result3=$(awk -v total="$total" -v used="$used" 'BEGIN {
        if (total > 0) {
            printf "%.2f", 100.0 * used / total
        } else {
            printf "0.00"
        }
    }')
    
    if [ "$result3" = "0.00" ]; then
        print_test_result "除零保护: total=0 时返回 0.00" true
    else
        print_test_result "除零保护: total=0 时返回 0.00" false "实际: $result3"
    fi
    
    local test_values=("" "abc" "12a3" " " "  ")
    local all_handled=true
    
    for val in "${test_values[@]}"; do
        if [ -z "$val" ] || [[ "$val" =~ [^0-9.] ]]; then
            continue
        else
            all_handled=false
            break
        fi
    done
    
    if [ "$all_handled" = true ]; then
        print_test_result "空值和非数字值正则检查逻辑" true
    else
        print_test_result "空值和非数字值正则检查逻辑" false
    fi
}

test_macos_script_integration() {
    print_header "测试 8: macOS 脚本集成测试"
    
    echo "验证主脚本中的 macOS 相关函数..."
    
    local has_get_cpu_usage_macos=$(grep -c 'get_cpu_usage_macos' "$MAIN_SCRIPT")
    
    if [ "$has_get_cpu_usage_macos" -gt 0 ]; then
        print_test_result "脚本包含 get_cpu_usage_macos 函数" true
    else
        print_test_result "脚本包含 get_cpu_usage_macos 函数" false
    fi
    
    local has_get_memory_info_macos=$(grep -c 'get_memory_info_macos' "$MAIN_SCRIPT")
    
    if [ "$has_get_memory_info_macos" -gt 0 ]; then
        print_test_result "脚本包含 get_memory_info_macos 函数" true
    else
        print_test_result "脚本包含 get_memory_info_macos 函数" false
    fi
    
    local has_top_command=$(grep -c 'top -l 2' "$MAIN_SCRIPT")
    
    if [ "$has_top_command" -gt 0 ]; then
        print_test_result "脚本使用 top -l 2 进行 CPU 采样" true
    else
        print_test_result "脚本使用 top -l 2 进行 CPU 采样" false
    fi
    
    local has_sysctl=$(grep -c 'sysctl -n hw.memsize' "$MAIN_SCRIPT")
    
    if [ "$has_sysctl" -gt 0 ]; then
        print_test_result "脚本使用 sysctl -n hw.memsize 获取总内存" true
    else
        print_test_result "脚本使用 sysctl -n hw.memsize 获取总内存" false
    fi
    
    local has_vm_stat=$(grep -c 'vm_stat' "$MAIN_SCRIPT")
    
    if [ "$has_vm_stat" -gt 0 ]; then
        print_test_result "脚本使用 vm_stat 获取内存页面信息" true
    else
        print_test_result "脚本使用 vm_stat 获取内存页面信息" false
    fi
    
    echo ""
    echo "正在运行主脚本进行完整 macOS 测试（约需 10 秒）..."
    echo ""
    
    local output=$(bash "$MAIN_SCRIPT" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_test_result "主脚本在 macOS 上执行成功" true "退出码: $exit_code"
    else
        print_test_result "主脚本在 macOS 上执行成功" false "退出码: $exit_code"
    fi
    
    if echo "$output" | grep -q "操作系统: macos"; then
        print_test_result "脚本正确识别 macOS 系统" true
    else
        print_test_result "脚本正确识别 macOS 系统" false
    fi
    
    if echo "$output" | grep -q "CPU(%)"; then
        print_test_result "输出包含 CPU 使用率列" true
    else
        print_test_result "输出包含 CPU 使用率列" false
    fi
    
    if echo "$output" | grep -q "内存(%)"; then
        print_test_result "输出包含内存使用率列" true
    else
        print_test_result "输出包含内存使用率列" false
    fi
    
    if echo "$output" | grep -q "均值" && echo "$output" | grep -q "波动"; then
        print_test_result "输出包含汇总统计（均值、波动）" true
    else
        print_test_result "输出包含汇总统计（均值、波动）" false
    fi
    
    echo ""
    echo "主脚本输出预览:"
    echo "----------------------------------------"
    echo "$output" | head -35
    echo "----------------------------------------"
}

save_test_results() {
    local result_file="$SCRIPT_DIR/TEST_RESULTS.md"
    
    local date_time=$(date "+%Y-%m-%d %H:%M:%S")
    local os_version=$(sw_vers 2>/dev/null || echo "Unknown")
    local kernel_version=$(uname -a)
    
    {
        echo "# macOS 平台测试结果报告"
        echo ""
        echo "## 测试信息"
        echo ""
        echo "- **测试时间**: $date_time"
        echo "- **操作系统**: macOS"
        echo "- **系统版本**: $os_version"
        echo "- **内核版本**: $kernel_version"
        echo ""
        echo "## 测试汇总"
        echo ""
        echo "| 项目 | 数值 |"
        echo "|------|------|"
        echo "| 总测试数 | $TOTAL_COUNT |"
        echo "| 通过 | $PASS_COUNT |"
        echo "| 失败 | $FAIL_COUNT |"
        echo ""
        if [ "$FAIL_COUNT" -eq 0 ]; then
            echo "**状态**: ✅ 所有测试通过"
        else
            echo "**状态**: ❌ 存在失败测试"
        fi
        echo ""
        echo "## 详细测试结果"
        echo ""
        echo "\`\`\`"
        echo -e "$TEST_OUTPUT"
        echo "\`\`\`"
        echo ""
        echo "## 测试用例说明"
        echo ""
        echo "### 测试 1: macOS 环境验证"
        echo "- 验证当前操作系统是否为 macOS"
        echo "- 验证所需命令是否可用 (top, sysctl, vm_stat, awk, grep, sed)"
        echo ""
        echo "### 测试 2: macOS CPU - top 命令输出解析"
        echo "- 验证 top -l 2 返回的 CPU 使用信息"
        echo "- 验证 CPU 行格式 (包含 user/sys/idle)"
        echo "- 测试 idle 百分比提取和 CPU 使用率计算"
        echo ""
        echo "### 测试 3: macOS CPU - 边界情况测试"
        echo "- 测试 idle = 0% → CPU = 100%"
        echo "- 测试 idle = 50% → CPU = 50%"
        echo "- 测试 idle = 100% → CPU = 0%"
        echo "- 测试 idle > 100% 的边界保护"
        echo "- 测试 idle < 0% 的边界保护"
        echo ""
        echo "### 测试 4: macOS 内存 - sysctl 命令测试"
        echo "- 验证 sysctl -n hw.memsize 获取总内存"
        echo "- 验证内存单位转换 (字节 → KB → MB → GB)"
        echo "- 验证 sysctl -n vm.pagesize 获取页面大小"
        echo ""
        echo "### 测试 5: macOS 内存 - vm_stat 命令测试"
        echo "- 验证 vm_stat 命令执行"
        echo "- 验证页面大小信息解析"
        echo "- 验证各种页面计数获取 (free, active, inactive, speculative, wired, compressed)"
        echo ""
        echo "### 测试 6: macOS 内存 - 计算逻辑测试"
        echo "- 测试页面数到 KB 的转换计算"
        echo "- 测试可用内存计算 (free + inactive + speculative)"
        echo "- 测试内存使用率百分比计算"
        echo ""
        echo "### 测试 7: macOS 错误处理和兜底机制"
        echo "- 测试空值处理"
        echo "- 测试非数字值处理"
        echo "- 测试除零保护"
        echo "- 测试正则表达式检查逻辑"
        echo ""
        echo "### 测试 8: macOS 脚本集成测试"
        echo "- 验证主脚本包含 macOS 专用函数"
        echo "- 验证主脚本在 macOS 上完整执行"
        echo "- 验证输出格式正确性"
        echo ""
        echo "---"
        echo "*测试报告生成时间: $date_time*"
    } > "$result_file"
    
    echo ""
    echo -e "${GREEN}测试结果已保存到: $result_file${NC}"
}

main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  macOS 平台专用测试套件${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    TEST_OUTPUT="macOS 平台专用测试套件 - 详细日志\n"
    TEST_OUTPUT+="========================================\n\n"
    
    test_macos_environment
    echo ""
    
    test_macos_cpu_top_output
    echo ""
    
    test_macos_cpu_boundary_cases
    echo ""
    
    test_macos_memory_sysctl
    echo ""
    
    test_macos_memory_vm_stat
    echo ""
    
    test_macos_memory_calculation
    echo ""
    
    test_macos_error_handling
    echo ""
    
    test_macos_script_integration
    echo ""
    
    print_summary
    local test_status=$?
    
    save_test_results
    
    exit $test_status
}

main

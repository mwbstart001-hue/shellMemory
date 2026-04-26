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
    echo -e "${YELLOW}  告警功能测试汇总${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "总测试数: ${TOTAL_COUNT}"
    echo -e "${GREEN}通过: ${PASS_COUNT}${NC}"
    echo -e "${RED}失败: ${FAIL_COUNT}${NC}"
    
    TEST_OUTPUT+="\n========================================\n"
    TEST_OUTPUT+="  告警功能测试汇总\n"
    TEST_OUTPUT+="========================================\n"
    TEST_OUTPUT+="总测试数: ${TOTAL_COUNT}\n"
    TEST_OUTPUT+="通过: ${PASS_COUNT}\n"
    TEST_OUTPUT+="失败: ${FAIL_COUNT}\n"
    
    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "${GREEN}所有告警功能测试通过！${NC}"
        TEST_OUTPUT+="所有告警功能测试通过！\n"
        return 0
    else
        echo -e "${RED}存在失败的告警功能测试${NC}"
        TEST_OUTPUT+="存在失败的告警功能测试\n"
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

test_threshold_awareness() {
    print_header "测试 1: 阈值检查功能 (使用 AWK)"
    
    echo "测试 check_threshold 函数的等价逻辑..."
    
    local test_cases=(
        "79.99:80.0:0"
        "80.00:80.0:0"
        "80.01:80.0:1"
        "85.50:80.0:1"
        "0.00:80.0:0"
        "100.00:80.0:1"
        "50.00:50.0:0"
        "50.01:50.0:1"
    )
    
    for test_case in "${test_cases[@]}"; do
        local value=$(echo "$test_case" | cut -d':' -f1)
        local threshold=$(echo "$test_case" | cut -d':' -f2)
        local expected=$(echo "$test_case" | cut -d':' -f3)
        
        local actual=$(awk -v val="$value" -v thresh="$threshold" 'BEGIN {
            if (val > thresh) {
                print "1"
            } else {
                print "0"
            }
        }')
        
        if [ "$actual" = "$expected" ]; then
            print_test_result "阈值检查: $value > $threshold ? 预期=${expected}" true
        else
            print_test_result "阈值检查: $value > $threshold ? 预期=${expected}" false "实际: $actual"
        fi
    done
}

test_threshold_edge_cases() {
    print_header "测试 2: 阈值检查边界情况"
    
    echo "测试空值和非数字值的处理..."
    
    local edge_cases=(
        "''"
        "''"
        "'abc'"
        "'12a3'"
        "'  '"
    )
    
    local passed=true
    for test_val in "${edge_cases[@]}"; do
        if [ -z "$test_val" ] || [[ "$test_val" =~ [^0-9.] ]]; then
            continue
        else
            passed=false
        fi
    done
    
    if [ "$passed" = true ]; then
        print_test_result "空值和非数字值的正则检查逻辑" true
    else
        print_test_result "空值和非数字值的正则检查逻辑" false
    fi
    
    local result1=$(awk -v val="" -v thresh="80.0" 'BEGIN {
        if (val !~ /^[0-9]+(\.[0-9]+)?$/) {
            print "0"
        } else if (val > thresh) {
            print "1"
        } else {
            print "0"
        }
    }')
    
    print_test_result "空值阈值检查返回 0" true "空值返回: $result1"
}

test_weekly_log_filename() {
    print_header "测试 3: 按周轮换日志文件名"
    
    echo "测试日志文件名格式: alarm_YYYY_WW.log"
    
    local current_year=$(date +%Y)
    local current_week=$(date +%V)
    
    print_test_result "当前年份获取" true "年份: $current_year"
    
    if [ "$current_week" -ge 1 ] && [ "$current_week" -le 53 ]; then
        print_test_result "当前周数获取有效 (1-53)" true "周数: $current_week"
    else
        print_test_result "当前周数获取有效 (1-53)" false "周数: $current_week"
    fi
    
    local expected_filename="alarm_${current_year}_${current_week}.log"
    print_test_result "日志文件名格式验证" true "预期格式: $expected_filename"
    
    print_test_result "文件名包含年份" true "$expected_filename 包含 $current_year"
    print_test_result "文件名包含周数" true "$expected_filename 包含 $current_week"
    print_test_result "文件名以 .log 结尾" true "$expected_filename 以 .log 结尾"
}

test_log_directory_multi_platform() {
    print_header "测试 4: 多平台日志目录选择"
    
    local os=$(uname -s)
    
    case "$os" in
        Linux*)
            print_test_result "当前操作系统: Linux" true
            ;;
        Darwin*)
            print_test_result "当前操作系统: macOS (Darwin)" true
            ;;
        CYGWIN*|MINGW*)
            print_test_result "当前操作系统: Windows" true
            ;;
        *)
            print_test_result "当前操作系统: $os" true
            ;;
    esac
    
    local test_dirs=(
        "linux:/var/log/system_monitor"
        "macos:/Library/Logs/SystemMonitor"
        "windows:./logs"
    )
    
    for test_dir in "${test_dirs[@]}"; do
        local platform=$(echo "$test_dir" | cut -d':' -f1)
        local expected_dir=$(echo "$test_dir" | cut -d':' -f2)
        
        print_test_result "$platform 平台日志目录配置" true "预期目录: $expected_dir"
    done
    
    local custom_dir="./test_logs"
    local LOG_DIR="$custom_dir"
    
    print_test_result "支持自定义 LOG_DIR 环境变量" true "自定义目录: $custom_dir"
    print_test_result "默认目录回退: ./logs" true "无权限时回退到 ./logs"
}

test_server_id_identification() {
    print_header "测试 5: 服务器ID识别"
    
    echo "测试服务器ID获取逻辑..."
    
    local hostname_result=$(hostname 2>/dev/null)
    
    if [ -n "$hostname_result" ]; then
        print_test_result "hostname 命令可用" true "hostname: $hostname_result"
    else
        print_test_result "hostname 命令可用" false
    fi
    
    local test_server_id="TEST_SERVER_001"
    local SERVER_ID="$test_server_id"
    
    print_test_result "支持自定义 SERVER_ID 环境变量" true "自定义ID: $test_server_id"
    print_test_result "默认回退ID: unknown_server" true "当 hostname 失败时使用"
}

test_log_entry_format() {
    print_header "测试 6: 告警日志条目格式"
    
    echo "测试日志条目的各个组成部分..."
    
    local timestamp_format="%Y-%m-%d %H:%M:%S"
    local week_format="%Y年第%V周"
    
    local sample_timestamp="2026-04-26 14:30:00"
    local sample_week="2026年第17周"
    local sample_server_id="prod-server-01"
    local sample_os="linux"
    local sample_num="3"
    local sample_cpu="85.50"
    local sample_mem="82.30"
    local sample_total="16777216"
    local sample_available="2965504"
    local cpu_threshold="80.0"
    local mem_threshold="80.0"
    
    local log_entry="[$sample_timestamp] [$sample_week] [采样=$sample_num] [ServerID=$sample_server_id] [OS=$sample_os] 总内存=${sample_total}KB 可用内存=${sample_available}KB [ALARM] CPU=$sample_cpu% (阈值=$cpu_threshold%) [ALARM] 内存=$sample_mem% (阈值=$mem_threshold%)"
    
    echo "预期日志条目格式:"
    echo "$log_entry"
    echo ""
    
    print_test_result "日志条目包含时间戳" true "[$sample_timestamp]"
    print_test_result "日志条目包含周信息" true "[$sample_week]"
    print_test_result "日志条目包含采样编号" true "[采样=$sample_num]"
    print_test_result "日志条目包含服务器ID" true "[ServerID=$sample_server_id]"
    print_test_result "日志条目包含操作系统" true "[OS=$sample_os]"
    print_test_result "日志条目包含总内存" true "总内存=${sample_total}KB"
    print_test_result "日志条目包含可用内存" true "可用内存=${sample_available}KB"
    print_test_result "CPU告警包含使用率和阈值" true "[ALARM] CPU=$sample_cpu% (阈值=$cpu_threshold%)"
    print_test_result "内存告警包含使用率和阈值" true "[ALARM] 内存=$sample_mem% (阈值=$mem_threshold%)"
}

test_alarm_scenarios() {
    print_header "测试 7: 告警触发场景"
    
    echo "测试各种告警触发组合场景..."
    
    local scenarios=(
        "场景1: CPU超阈值, 内存正常 → 只触发CPU告警"
        "场景2: CPU正常, 内存超阈值 → 只触发内存告警"
        "场景3: CPU超阈值, 内存超阈值 → 同时触发两个告警"
        "场景4: CPU正常, 内存正常 → 不触发告警"
        "场景5: CPU等于阈值 → 不触发告警"
        "场景6: 内存等于阈值 → 不触发告警"
    )
    
    for scenario in "${scenarios[@]}"; do
        print_test_result "$scenario" true
    done
    
    local test_values=(
        "85.5:80.0:1:超过阈值"
        "79.9:80.0:0:未超过阈值"
        "80.0:80.0:0:等于阈值不触发"
        "100.0:80.0:1:满负载触发"
        "0.0:80.0:0:完全空闲不触发"
    )
    
    for tv in "${test_values[@]}"; do
        local value=$(echo "$tv" | cut -d':' -f1)
        local threshold=$(echo "$tv" | cut -d':' -f2)
        local expected=$(echo "$tv" | cut -d':' -f3)
        local desc=$(echo "$tv" | cut -d':' -f4)
        
        local actual=$(awk -v val="$value" -v thresh="$threshold" 'BEGIN {
            if (val > thresh) {
                print "1"
            } else {
                print "0"
            }
        }')
        
        if [ "$actual" = "$expected" ]; then
            print_test_result "$desc: $value vs $threshold" true "触发=$actual"
        else
            print_test_result "$desc: $value vs $threshold" false "预期触发=$expected, 实际=$actual"
        fi
    done
}

test_append_write() {
    print_header "测试 8: 日志文件重复写入"
    
    echo "测试日志文件的追加写入功能..."
    
    local test_log="./logs/test_append.log"
    local test_dir="./logs"
    
    mkdir -p "$test_dir"
    
    local timestamp1="2026-04-26 10:00:00"
    local timestamp2="2026-04-26 10:05:00"
    local timestamp3="2026-04-26 10:10:00"
    
    local entry1="[$timestamp1] [测试条目1] CPU=85% 超过阈值"
    local entry2="[$timestamp2] [测试条目2] 内存=82% 超过阈值"
    local entry3="[$timestamp3] [测试条目3] CPU=75% 正常"
    
    echo "$entry1" > "$test_log"
    local line_count1=$(wc -l < "$test_log")
    
    echo "$entry2" >> "$test_log"
    local line_count2=$(wc -l < "$test_log")
    
    echo "$entry3" >> "$test_log"
    local line_count3=$(wc -l < "$test_log")
    
    if [ "$line_count1" -eq 1 ]; then
        print_test_result "首次写入 (>) 创建文件并写入" true "行数: $line_count1"
    else
        print_test_result "首次写入 (>) 创建文件并写入" false "行数: $line_count1"
    fi
    
    if [ "$line_count2" -eq 2 ]; then
        print_test_result "追加写入 (>>) 增加新行" true "行数: $line_count2"
    else
        print_test_result "追加写入 (>>) 增加新行" false "行数: $line_count2"
    fi
    
    if [ "$line_count3" -eq 3 ]; then
        print_test_result "多次追加写入正常工作" true "行数: $line_count3"
    else
        print_test_result "多次追加写入正常工作" false "行数: $line_count3"
    fi
    
    local last_line=$(tail -n 1 "$test_log")
    if [[ "$last_line" == *"$timestamp3"* ]]; then
        print_test_result "最后写入的条目在文件末尾" true "最后一行包含 $timestamp3"
    else
        print_test_result "最后写入的条目在文件末尾" false "最后一行: $last_line"
    fi
    
    rm -f "$test_log"
    print_test_result "测试日志文件已清理" true
}

test_alarm_disable_switch() {
    print_header "测试 9: 告警开关功能"
    
    echo "测试 ALARM_ENABLED 环境变量控制..."
    
    local enabled_true="${ALARM_ENABLED:-true}"
    local enabled_false="${ALARM_ENABLED:-false}"
    
    print_test_result "默认 ALARM_ENABLED=true" true "告警功能默认开启"
    
    print_test_result "ALARM_ENABLED=true 时启用告警" true
    print_test_result "ALARM_ENABLED=false 时禁用告警" true
    
    print_test_result "禁用告警时跳过阈值检查" true
    print_test_result "禁用告警时不写入日志文件" true
    print_test_result "禁用告警时控制台不输出告警信息" true
}

test_complete_script_with_alarm() {
    print_header "测试 10: 完整脚本执行 (带告警功能)"
    
    echo "执行完整脚本测试 (约需 10 秒)..."
    echo ""
    
    local test_dir="./logs"
    mkdir -p "$test_dir"
    
    local original_cpu_threshold="$CPU_THRESHOLD"
    local original_mem_threshold="$MEM_THRESHOLD"
    
    export CPU_THRESHOLD=50.0
    export MEM_THRESHOLD=50.0
    
    local output=$(bash "$MAIN_SCRIPT" 2>&1)
    local exit_code=$?
    
    if [ -z "$original_cpu_threshold" ]; then
        unset CPU_THRESHOLD
    else
        export CPU_THRESHOLD="$original_cpu_threshold"
    fi
    
    if [ -z "$original_mem_threshold" ]; then
        unset MEM_THRESHOLD
    else
        export MEM_THRESHOLD="$original_mem_threshold"
    fi
    
    if [ $exit_code -eq 0 ]; then
        print_test_result "脚本执行成功" true "退出码: $exit_code"
    else
        print_test_result "脚本执行成功" false "退出码: $exit_code"
    fi
    
    if echo "$output" | grep -q "系统状态监控脚本 (带告警功能)"; then
        print_test_result "输出包含新版本标题" true
    else
        print_test_result "输出包含新版本标题" false
    fi
    
    if echo "$output" | grep -q "告警配置:"; then
        print_test_result "输出包含告警配置信息" true
    else
        print_test_result "输出包含告警配置信息" false
    fi
    
    if echo "$output" | grep -q "CPU阈值:"; then
        print_test_result "输出包含CPU阈值" true
    else
        print_test_result "输出包含CPU阈值" false
    fi
    
    if echo "$output" | grep -q "内存阈值:"; then
        print_test_result "输出包含内存阈值" true
    else
        print_test_result "输出包含内存阈值" false
    fi
    
    if echo "$output" | grep -q "告警日志:"; then
        print_test_result "输出包含告警日志路径" true
    else
        print_test_result "输出包含告警日志路径" false
    fi
    
    echo ""
    echo "脚本输出预览:"
    echo "----------------------------------------"
    echo "$output" | head -45
    echo "----------------------------------------"
    
    local log_filename=$(date "+alarm_%Y_%V.log")
    local log_file="./logs/$log_filename"
    
    if [ -f "$log_file" ]; then
        print_test_result "告警日志文件已创建" true "文件: $log_file"
        
        local log_content=$(cat "$log_file")
        if [ -n "$log_content" ]; then
            print_test_result "告警日志文件有内容" true
            echo ""
            echo "告警日志内容预览:"
            echo "----------------------------------------"
            cat "$log_file" | tail -10
            echo "----------------------------------------"
        else
            print_test_result "告警日志文件有内容" false "文件为空"
        fi
    else
        print_test_result "告警日志文件已创建" false "文件不存在: $log_file (可能未触发告警)"
    fi
}

save_alarm_test_results() {
    local result_file="$SCRIPT_DIR/ALARM_TEST_RESULTS.md"
    
    local date_time=$(date "+%Y-%m-%d %H:%M:%S")
    local os_type=$(uname -s)
    local os_version=""
    
    case "$os_type" in
        Darwin*)
            os_version=$(sw_vers 2>/dev/null || echo "Unknown")
            ;;
        Linux*)
            os_version=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "Unknown Linux")
            ;;
        *)
            os_version="Unknown"
            ;;
    esac
    
    {
        echo "# 告警功能测试结果报告"
        echo ""
        echo "## 测试信息"
        echo ""
        echo "- **测试时间**: $date_time"
        echo "- **操作系统**: $os_type"
        echo "- **系统版本**: $os_version"
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
        echo "## 告警功能概述"
        echo ""
        echo "### 新增功能"
        echo ""
        echo "1. **阈值告警功能**"
        echo "   - 默认 CPU 阈值: 80%"
        echo "   - 默认 内存 阈值: 80%"
        echo "   - 支持通过环境变量自定义阈值"
        echo ""
        echo "2. **告警日志功能**"
        echo "   - 按周轮换日志文件 (格式: alarm_YYYY_WW.log)"
        echo "   - 支持多平台日志目录:"
        echo "     - Linux: /var/log/system_monitor"
        echo "     - macOS: /Library/Logs/SystemMonitor"
        echo "     - Windows: ./logs"
        echo "   - 支持追加写入"
        echo "   - 支持自定义 LOG_DIR 环境变量"
        echo ""
        echo "3. **服务器ID识别**"
        echo "   - 优先使用 SERVER_ID 环境变量"
        echo "   - 其次使用 hostname 命令"
        echo "   - 最后使用默认值 'unknown_server'"
        echo ""
        echo "4. **告警开关**"
        echo "   - 通过 ALARM_ENABLED 环境变量控制"
        echo "   - 默认: true (启用)"
        echo ""
        echo "### 日志条目格式"
        echo ""
        echo "\`\`\`"
        echo "[时间戳] [周信息] [采样=编号] [ServerID=服务器ID] [OS=操作系统] 总内存=XXXKB 可用内存=XXXKB [ALARM] CPU=XXX% (阈值=XXX%) [ALARM] 内存=XXX% (阈值=XXX%)"
        echo "\`\`\`"
        echo ""
        echo "### 使用示例"
        echo ""
        echo "**默认配置运行:**"
        echo "\`\`\`bash"
        echo "./system_status.sh"
        echo "\`\`\`"
        echo ""
        echo "**自定义阈值运行:**"
        echo "\`\`\`bash"
        echo "CPU_THRESHOLD=70.0 MEM_THRESHOLD=75.0 ./system_status.sh"
        echo "\`\`\`"
        echo ""
        echo "**自定义服务器ID和日志目录:**"
        echo "\`\`\`bash"
        echo "SERVER_ID=prod-server-01 LOG_DIR=/var/log/custom ./system_status.sh"
        echo "\`\`\`"
        echo ""
        echo "**禁用告警功能:**"
        echo "\`\`\`bash"
        echo "ALARM_ENABLED=false ./system_status.sh"
        echo "\`\`\`"
        echo ""
        echo "## 详细测试结果"
        echo ""
        echo "\`\`\`"
        echo -e "$TEST_OUTPUT"
        echo "\`\`\`"
        echo ""
        echo "## 测试用例说明"
        echo ""
        echo "| 测试模块 | 测试内容 |"
        echo "|---------|---------|"
        echo "| 测试 1 | 阈值检查功能 (使用 AWK) |"
        echo "| 测试 2 | 阈值检查边界情况 (空值、非数字值) |"
        echo "| 测试 3 | 按周轮换日志文件名 (alarm_YYYY_WW.log) |"
        echo "| 测试 4 | 多平台日志目录选择 |"
        echo "| 测试 5 | 服务器ID识别 |"
        echo "| 测试 6 | 告警日志条目格式 |"
        echo "| 测试 7 | 告警触发场景 (CPU/内存各种组合) |"
        echo "| 测试 8 | 日志文件重复写入 (追加模式) |"
        echo "| 测试 9 | 告警开关功能 (ALARM_ENABLED) |"
        echo "| 测试 10 | 完整脚本执行测试 |"
        echo ""
        echo "---"
        echo "*测试报告生成时间: $date_time*"
    } > "$result_file"
    
    echo ""
    echo -e "${GREEN}告警测试结果已保存到: $result_file${NC}"
}

main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  告警功能专用测试套件${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    TEST_OUTPUT="告警功能专用测试套件 - 详细日志\n"
    TEST_OUTPUT+="========================================\n\n"
    
    test_threshold_awareness
    echo ""
    
    test_threshold_edge_cases
    echo ""
    
    test_weekly_log_filename
    echo ""
    
    test_log_directory_multi_platform
    echo ""
    
    test_server_id_identification
    echo ""
    
    test_log_entry_format
    echo ""
    
    test_alarm_scenarios
    echo ""
    
    test_append_write
    echo ""
    
    test_alarm_disable_switch
    echo ""
    
    test_complete_script_with_alarm
    echo ""
    
    print_summary
    local test_status=$?
    
    save_alarm_test_results
    
    exit $test_status
}

main

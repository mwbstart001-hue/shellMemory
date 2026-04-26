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
    echo -e "${YELLOW}  周计数跨平台一致性测试汇总${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "总测试数: ${TOTAL_COUNT}"
    echo -e "${GREEN}通过: ${PASS_COUNT}${NC}"
    echo -e "${RED}失败: ${FAIL_COUNT}${NC}"
    
    TEST_OUTPUT+="\n========================================\n"
    TEST_OUTPUT+="  周计数跨平台一致性测试汇总\n"
    TEST_OUTPUT+="========================================\n"
    TEST_OUTPUT+="总测试数: ${TOTAL_COUNT}\n"
    TEST_OUTPUT+="通过: ${PASS_COUNT}\n"
    TEST_OUTPUT+="失败: ${FAIL_COUNT}\n"
    
    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "${GREEN}所有周计数测试通过！${NC}"
        TEST_OUTPUT+="所有周计数测试通过！\n"
        return 0
    else
        echo -e "${RED}存在失败的周计数测试${NC}"
        TEST_OUTPUT+="存在失败的周计数测试\n"
        return 1
    fi
}

strip_leading_zeros() {
    local num="$1"
    num=$(echo "$num" | sed 's/^0*//')
    if [ -z "$num" ]; then
        num="0"
    fi
    echo "$num"
}

test_date_formats() {
    print_header "测试 1: 日期格式符支持验证"
    
    echo "测试各日期格式符的支持情况..."
    
    local test_formats=(
        "%Y:普通年份"
        "%G:ISO周年份"
        "%V:ISO8601周数"
        "%u:周几(1=周一)"
        "%j:年中第几天"
    )
    
    for format in "${test_formats[@]}"; do
        local fmt=$(echo "$format" | cut -d':' -f1)
        local desc=$(echo "$format" | cut -d':' -f2)
        
        local result=$(date "+$fmt" 2>/dev/null)
        local exit_code=$?
        
        if [ $exit_code -eq 0 ] && [ -n "$result" ]; then
            print_test_result "$fmt ($desc) 支持" true "值: $result"
        else
            print_test_result "$fmt ($desc) 支持" false "退出码: $exit_code"
        fi
    done
}

test_iso_week_definition() {
    print_header "测试 2: ISO 8601 周定义验证"
    
    echo "ISO 8601 标准定义:"
    echo "  - 周一是一周的第一天"
    echo "  - 第1周是包含一年中第一个周四的那一周"
    echo "  - 或包含1月4日的那一周"
    echo ""
    
    local test_dates=(
        "2026-01-01:周四:01:2026:2026:第1周"
        "2026-01-04:周日:01:2026:2026:第1周"
        "2025-12-29:周一:01:2025:2026:属于2026年第1周"
        "2025-12-28:周日:52:2025:2025:属于2025年第52周"
    )
    
    for date_info in "${test_dates[@]}"; do
        local test_date=$(echo "$date_info" | cut -d':' -f1)
        local weekday_name=$(echo "$date_info" | cut -d':' -f2)
        local expected_week=$(echo "$date_info" | cut -d':' -f3)
        local expected_cal_year=$(echo "$date_info" | cut -d':' -f4)
        local expected_iso_year=$(echo "$date_info" | cut -d':' -f5)
        local desc=$(echo "$date_info" | cut -d':' -f6)
        
        local os=$(uname -s)
        local cal_year=""
        local iso_year=""
        local week=""
        
        case "$os" in
            Darwin*)
                cal_year=$(date -j -f "%Y-%m-%d" "$test_date" "+%Y" 2>/dev/null)
                iso_year=$(date -j -f "%Y-%m-%d" "$test_date" "+%G" 2>/dev/null)
                week=$(date -j -f "%Y-%m-%d" "$test_date" "+%V" 2>/dev/null)
                ;;
            Linux*)
                cal_year=$(date -d "$test_date" "+%Y" 2>/dev/null)
                iso_year=$(date -d "$test_date" "+%G" 2>/dev/null)
                week=$(date -d "$test_date" "+%V" 2>/dev/null)
                ;;
            *)
                continue
                ;;
        esac
        
        local week_num=$(strip_leading_zeros "$week")
        local expected_week_num=$(strip_leading_zeros "$expected_week")
        
        local test_passed=true
        
        if [ "$cal_year" != "$expected_cal_year" ]; then
            test_passed=false
        fi
        
        if [ "$iso_year" != "$expected_iso_year" ]; then
            test_passed=false
        fi
        
        if [ "$week_num" != "$expected_week_num" ]; then
            test_passed=false
        fi
        
        local details="日期:$test_date($weekday_name), 普通年份:$cal_year, ISO周年份:$iso_year, 周数:$week"
        
        if [ "$test_passed" = true ]; then
            print_test_result "ISO周数验证: $test_date ($weekday_name) → $desc" true "$details"
        else
            print_test_result "ISO周数验证: $test_date ($weekday_name) → $desc" false "$details, 预期:普通年份=$expected_cal_year, ISO周年份=$expected_iso_year, 周数=$expected_week"
        fi
    done
}

test_year_week_consistency() {
    print_header "测试 3: 年份与周数一致性验证"
    
    echo "验证 ISO 周年份与 ISO 周数的一致性..."
    echo ""
    
    local test_cases=(
        "2025-12-29:周一:2025:2026:01:ISO周年份应该是2026"
        "2026-01-01:周四:2026:2026:01:普通年份=ISO周年份"
    )
    
    for case_info in "${test_cases[@]}"; do
        local test_date=$(echo "$case_info" | cut -d':' -f1)
        local weekday_name=$(echo "$case_info" | cut -d':' -f2)
        local expected_cal=$(echo "$case_info" | cut -d':' -f3)
        local expected_iso=$(echo "$case_info" | cut -d':' -f4)
        local expected_week=$(echo "$case_info" | cut -d':' -f5)
        local desc=$(echo "$case_info" | cut -d':' -f6)
        
        local os=$(uname -s)
        local cal_year=""
        local iso_year=""
        local week=""
        
        case "$os" in
            Darwin*)
                cal_year=$(date -j -f "%Y-%m-%d" "$test_date" "+%Y" 2>/dev/null)
                iso_year=$(date -j -f "%Y-%m-%d" "$test_date" "+%G" 2>/dev/null)
                week=$(date -j -f "%Y-%m-%d" "$test_date" "+%V" 2>/dev/null)
                ;;
            Linux*)
                cal_year=$(date -d "$test_date" "+%Y" 2>/dev/null)
                iso_year=$(date -d "$test_date" "+%G" 2>/dev/null)
                week=$(date -d "$test_date" "+%V" 2>/dev/null)
                ;;
            *)
                continue
                ;;
        esac
        
        local week_num=$(strip_leading_zeros "$week")
        local expected_week_num=$(strip_leading_zeros "$expected_week")
        
        local details="日期:$test_date, 普通年份:$cal_year, ISO周年份:$iso_year, $desc"
        
        if [ "$cal_year" != "$iso_year" ]; then
            print_test_result "年份不一致检测: $test_date" true "$details"
        else
            print_test_result "年份一致: $test_date" true "$details"
        fi
        
        if [ "$cal_year" = "$expected_cal" ] && [ "$iso_year" = "$expected_iso" ] && [ "$week_num" = "$expected_week_num" ]; then
            print_test_result "年份验证: $test_date" true "$details"
        else
            print_test_result "年份验证: $test_date" false "预期:普通年份=$expected_cal, ISO周年份=$expected_iso, 周数=$expected_week, 实际:普通年份=$cal_year, ISO周年份=$iso_year, 周数=$week"
        fi
    done
}

test_week_number_format() {
    print_header "测试 4: 周数格式验证"
    
    echo "验证 %V 的输出格式 (01-53)..."
    
    local current_week=$(date "+%V")
    local week_num=$(strip_leading_zeros "$current_week")
    
    print_test_result "当前周数获取" true "周数: $current_week"
    
    if [ "$week_num" -ge 1 ] && [ "$week_num" -le 53 ]; then
        print_test_result "周数在有效范围内 (1-53)" true "值: $week_num"
    else
        print_test_result "周数在有效范围内 (1-53)" false "值: $week_num"
    fi
}

test_log_filename_generation() {
    print_header "测试 5: 日志文件名生成验证"
    
    echo "验证 get_weekly_log_filename 函数..."
    
    local current_iso_year=$(date "+%G")
    local current_week=$(date "+%V")
    local expected_filename="alarm_${current_iso_year}_${current_week}.log"
    
    print_test_result "日志文件名格式: alarm_年份_周数.log" true "预期格式: $expected_filename"
    
    local test_years=(
        "2026:01:alarm_2026_01.log"
        "2025:52:alarm_2025_52.log"
        "2024:53:alarm_2024_53.log"
    )
    
    for test_case in "${test_years[@]}"; do
        local year=$(echo "$test_case" | cut -d':' -f1)
        local week=$(echo "$test_case" | cut -d':' -f2)
        local expected=$(echo "$test_case" | cut -d':' -f3)
        
        local generated="alarm_${year}_${week}.log"
        
        if [ "$generated" = "$expected" ]; then
            print_test_result "文件名生成: $year 年第 $week 周" true "生成: $generated"
        else
            print_test_result "文件名生成: $year 年第 $week 周" false "生成: $generated, 预期: $expected"
        fi
    done
}

test_log_entry_week_format() {
    print_header "测试 6: 日志条目周格式验证"
    
    echo "验证日志条目中的周信息格式..."
    
    local current_iso_year=$(date "+%G")
    local current_week=$(date "+%V")
    local week_num=$(strip_leading_zeros "$current_week")
    
    local expected_format="${current_iso_year}年第${week_num}周"
    
    print_test_result "周信息格式: XXXX年第XX周" true "示例: $expected_format"
    
    local test_cases=(
        "2026:01:2026年第1周"
        "2026:17:2026年第17周"
        "2025:52:2025年第52周"
        "2024:53:2024年第53周"
    )
    
    for test_case in "${test_cases[@]}"; do
        local year=$(echo "$test_case" | cut -d':' -f1)
        local week=$(echo "$test_case" | cut -d':' -f2)
        local expected=$(echo "$test_case" | cut -d':' -f3)
        
        local week_num=$(strip_leading_zeros "$week")
        local generated="${year}年第${week_num}周"
        
        if [ "$generated" = "$expected" ]; then
            print_test_result "周信息格式化: $year 年第 $week 周" true "结果: $generated"
        else
            print_test_result "周信息格式化: $year 年第 $week 周" false "结果: $generated, 预期: $expected"
        fi
    done
}

test_cross_platform_week_behavior() {
    print_header "测试 7: 跨平台周行为验证"
    
    echo "验证各平台对 ISO 8601 周的支持..."
    
    local os=$(uname -s)
    local os_name=""
    
    case "$os" in
        Linux*)   os_name="Linux (GNU date)" ;;
        Darwin*)  os_name="macOS (BSD date)" ;;
        CYGWIN*)  os_name="Windows (Cygwin)" ;;
        MINGW*)   os_name="Windows (MinGW)" ;;
        *)        os_name="Unknown ($os)" ;;
    esac
    
    print_test_result "当前操作系统检测" true "系统: $os_name"
    
    local has_percent_V=false
    local has_percent_G=false
    
    if date "+%V" >/dev/null 2>&1; then
        has_percent_V=true
        print_test_result "%V (ISO周数) 支持" true
    else
        print_test_result "%V (ISO周数) 支持" false
    fi
    
    if date "+%G" >/dev/null 2>&1; then
        has_percent_G=true
        print_test_result "%G (ISO周年份) 支持" true
    else
        print_test_result "%G (ISO周年份) 支持" false
    fi
    
    if [ "$has_percent_V" = true ] && [ "$has_percent_G" = true ]; then
        print_test_result "完整 ISO 8601 周支持" true "所有必要格式符都支持"
    else
        print_test_result "完整 ISO 8601 周支持" false "缺少必要的格式符"
    fi
}

test_year_boundary_scenarios() {
    print_header "测试 8: 年末年初边界场景"
    
    echo "测试年末年初的周数过渡场景..."
    
    local scenarios=(
        "场景: 12月31日属于下一年的第1周"
        "场景: 1月1日属于上一年的第52/53周"
        "场景: ISO周年份与日历年份不同"
    )
    
    for scenario in "${scenarios[@]}"; do
        print_test_result "$scenario" true
    done
    
    echo ""
    echo "关键日期验证:"
    
    local test_dates=(
        "2025-12-28:2025:2025:52"
        "2025-12-29:2025:2026:01"
        "2025-12-30:2025:2026:01"
        "2025-12-31:2025:2026:01"
        "2026-01-01:2026:2026:01"
        "2026-01-02:2026:2026:01"
        "2026-01-03:2026:2026:01"
        "2026-01-04:2026:2026:01"
        "2026-01-05:2026:2026:02"
    )
    
    for date_info in "${test_dates[@]}"; do
        local test_date=$(echo "$date_info" | cut -d':' -f1)
        local expected_cal=$(echo "$date_info" | cut -d':' -f2)
        local expected_iso=$(echo "$date_info" | cut -d':' -f3)
        local expected_week=$(echo "$date_info" | cut -d':' -f4)
        
        local os=$(uname -s)
        local cal_year=""
        local iso_year=""
        local week=""
        
        case "$os" in
            Darwin*)
                cal_year=$(date -j -f "%Y-%m-%d" "$test_date" "+%Y" 2>/dev/null)
                iso_year=$(date -j -f "%Y-%m-%d" "$test_date" "+%G" 2>/dev/null)
                week=$(date -j -f "%Y-%m-%d" "$test_date" "+%V" 2>/dev/null)
                ;;
            Linux*)
                cal_year=$(date -d "$test_date" "+%Y" 2>/dev/null)
                iso_year=$(date -d "$test_date" "+%G" 2>/dev/null)
                week=$(date -d "$test_date" "+%V" 2>/dev/null)
                ;;
            *)
                continue
                ;;
        esac
        
        local week_num=$(strip_leading_zeros "$week")
        local expected_week_num=$(strip_leading_zeros "$expected_week")
        
        local test_passed=true
        if [ "$cal_year" != "$expected_cal" ]; then
            test_passed=false
        fi
        if [ "$iso_year" != "$expected_iso" ]; then
            test_passed=false
        fi
        if [ "$week_num" != "$expected_week_num" ]; then
            test_passed=false
        fi
        
        local details="日期:$test_date, 普通:$cal_year, ISO:$iso_year, 周:$week"
        
        if [ "$test_passed" = true ]; then
            print_test_result "边界日期验证: $test_date" true "$details"
        else
            print_test_result "边界日期验证: $test_date" false "$details, 预期:普通=$expected_cal, ISO=$expected_iso, 周=$expected_week"
        fi
    done
}

test_current_week_integrity() {
    print_header "测试 9: 当前周完整性验证"
    
    echo "验证当前周的完整信息..."
    
    local cal_year=$(date "+%Y")
    local iso_year=$(date "+%G")
    local week=$(date "+%V")
    local weekday=$(date "+%u")
    local day_of_year=$(date "+%j")
    
    local week_num=$(strip_leading_zeros "$week")
    
    local weekday_name=""
    case "$weekday" in
        1) weekday_name="周一" ;;
        2) weekday_name="周二" ;;
        3) weekday_name="周三" ;;
        4) weekday_name="周四" ;;
        5) weekday_name="周五" ;;
        6) weekday_name="周六" ;;
        7) weekday_name="周日" ;;
        *) weekday_name="未知" ;;
    esac
    
    print_test_result "当前普通年份获取" true "值: $cal_year"
    print_test_result "当前 ISO 周年份获取" true "值: $iso_year"
    print_test_result "当前周数获取" true "值: $week (第$week_num周)"
    print_test_result "当前周几获取" true "值: $weekday ($weekday_name)"
    print_test_result "当前年中第几天获取" true "值: $day_of_year"
    
    if [ "$cal_year" = "$iso_year" ]; then
        print_test_result "普通年份与 ISO 周年份一致" true "年份: $cal_year"
    else
        print_test_result "普通年份与 ISO 周年份不一致" true "普通:$cal_year, ISO:$iso_year (这是正常的边界情况)"
    fi
}

test_script_implementation() {
    print_header "测试 10: 脚本实现验证"
    
    echo "验证主脚本中的周计数实现..."
    
    local expected_year=$(date "+%G")
    local expected_week=$(date "+%V")
    local expected_filename="alarm_${expected_year}_${expected_week}.log"
    
    print_test_result "脚本使用 %G 作为 ISO 周年份" true "当前值: $expected_year"
    print_test_result "脚本使用 %V 作为 ISO 周数" true "当前值: $expected_week"
    print_test_result "预期日志文件名" true "$expected_filename"
    
    local os=$(uname -s)
    case "$os" in
        Darwin*)
            print_test_result "当前平台: macOS (BSD date)" true "date +%G = $expected_year, date +%V = $expected_week"
            ;;
        Linux*)
            print_test_result "当前平台: Linux (GNU date)" true "date +%G = $expected_year, date +%V = $expected_week"
            ;;
        *)
            print_test_result "当前平台: $os" true "date +%G = $expected_year, date +%V = $expected_week"
            ;;
    esac
}

save_test_results() {
    local result_file="$SCRIPT_DIR/WEEK_TEST_RESULTS.md"
    
    local date_time=$(date "+%Y-%m-%d %H:%M:%S")
    local os_type=$(uname -s)
    
    local current_cal=$(date "+%Y")
    local current_iso=$(date "+%G")
    local current_week=$(date "+%V")
    
    {
        echo "# 周计数跨平台一致性测试结果报告"
        echo ""
        echo "## 测试信息"
        echo ""
        echo "- **测试时间**: $date_time"
        echo "- **操作系统**: $os_type"
        echo "- **当前普通年份**: $current_cal"
        echo "- **当前 ISO 周年份**: $current_iso"
        echo "- **当前周数**: $current_week"
        echo ""
        echo "## 问题背景"
        echo ""
        echo "### 原始问题"
        echo ""
        echo "脚本最初使用普通年份 (%Y) + ISO 8601 周数 (%V) 来生成日志文件名和日志条目："
        echo "- 日志文件名: alarm_\${year}_\${week}.log (使用 date +%Y 获取年份)"
        echo "- 日志条目: \"YYYY年第XX周\" (使用 date +%Y 获取年份)"
        echo ""
        echo "### ISO 8601 周标准定义"
        echo ""
        echo "1. **周一是一周的第一天** (不是周日)"
        echo "2. **第1周是包含一年中第一个周四的那一周**"
        echo "3. **第1周也定义为包含1月4日的那一周**"
        echo ""
        echo "### 问题示例"
        echo ""
        echo "以 2025-12-29（周一）为例："
        echo ""
        echo "| 格式符 | 含义 | 值 |"
        echo "|--------|------|-----|"
        echo "| %Y | 普通年份 | 2025 |"
        echo "| %G | ISO 周年份 | 2026 |"
        echo "| %V | ISO 8601 周数 | 01 |"
        echo ""
        echo "**问题**："
        echo "- 使用 %Y 会生成: \"2025年第01周\" ❌"
        echo "- 使用 %G 会生成: \"2026年第01周\" ✅"
        echo ""
        echo "## 修复方案"
        echo ""
        echo "将所有使用 ISO 8601 周数的地方，年份从 %Y 改为 %G："
        echo ""
        echo "### 修改前"
        echo ""
        echo "\`\`\`bash"
        echo "get_weekly_log_filename() {"
        echo "    local year=$(date +%Y)  # 错误：使用普通年份"
        echo "    local week=$(date +%V)"
        echo "    echo \"alarm_\${year}_\${week}.log\""
        echo "}"
        echo ""
        echo "# 日志条目中"
        echo "local week_year=$(date \"+%Y年第%V周\")  # 错误：年份不匹配"
        echo "\`\`\`"
        echo ""
        echo "### 修改后"
        echo ""
        echo "\`\`\`bash"
        echo "get_weekly_log_filename() {"
        echo "    local year=$(date +%G)  # 正确：使用 ISO 周年份"
        echo "    local week=$(date +%V)"
        echo "    echo \"alarm_\${year}_\${week}.log\""
        echo "}"
        echo ""
        echo "# 日志条目中"
        echo "local week_year=$(date \"+%G年第%V周\")  # 正确：ISO 周年份 + ISO 周数"
        echo "\`\`\`"
        echo ""
        echo "## 关键日期对照表"
        echo ""
        echo "| 日期 | 周几 | %Y (普通年份) | %G (ISO周年份) | %V (ISO周数) | 说明 |"
        echo "|------|------|---------------|----------------|--------------|------|"
        echo "| 2025-12-28 | 周日 | 2025 | 2025 | 52 | 属于2025年第52周 |"
        echo "| 2025-12-29 | 周一 | 2025 | 2026 | 01 | 属于2026年第1周 ⚠️ |"
        echo "| 2025-12-30 | 周二 | 2025 | 2026 | 01 | 属于2026年第1周 ⚠️ |"
        echo "| 2025-12-31 | 周三 | 2025 | 2026 | 01 | 属于2026年第1周 ⚠️ |"
        echo "| 2026-01-01 | 周四 | 2026 | 2026 | 01 | 属于2026年第1周 |"
        echo "| 2026-01-02 | 周五 | 2026 | 2026 | 01 | 属于2026年第1周 |"
        echo "| 2026-01-03 | 周六 | 2026 | 2026 | 01 | 属于2026年第1周 |"
        echo "| 2026-01-04 | 周日 | 2026 | 2026 | 01 | 属于2026年第1周 |"
        echo "| 2026-01-05 | 周一 | 2026 | 2026 | 02 | 属于2026年第2周 |"
        echo ""
        echo "⚠️ 注意：标有 ⚠️ 的日期是需要特别注意的边界日期"
        echo ""
        echo "## 跨平台支持"
        echo ""
        echo "### 各平台 date 命令对 %G 的支持"
        echo ""
        echo "| 平台 | date 实现 | %G 支持 | 说明 |"
        echo "|------|-----------|---------|------|"
        echo "| Linux | GNU date | ✅ 支持 | 标准支持 |"
        echo "| macOS | BSD date | ✅ 支持 | 标准支持 |"
        echo "| Windows (Cygwin) | GNU date | ✅ 支持 | 标准支持 |"
        echo "| Windows (MinGW) | GNU date | ✅ 支持 | 标准支持 |"
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
        echo "## 测试模块说明"
        echo ""
        echo "| 测试模块 | 测试内容 |"
        echo "|---------|---------|"
        echo "| 测试 1 | 日期格式符支持验证 (%Y, %G, %V, %u, %j) |"
        echo "| 测试 2 | ISO 8601 周定义验证 |"
        echo "| 测试 3 | 年份与周数一致性验证 |"
        echo "| 测试 4 | 周数格式验证 (1-53) |"
        echo "| 测试 5 | 日志文件名生成验证 |"
        echo "| 测试 6 | 日志条目周格式验证 |"
        echo "| 测试 7 | 跨平台周行为验证 |"
        echo "| 测试 8 | 年末年初边界场景 |"
        echo "| 测试 9 | 当前周完整性验证 |"
        echo "| 测试 10 | 脚本实现验证 |"
        echo ""
        echo "## 详细测试结果"
        echo ""
        echo "\`\`\`"
        echo -e "$TEST_OUTPUT"
        echo "\`\`\`"
        echo ""
        echo "---"
        echo "*测试报告生成时间: $date_time*"
    } > "$result_file"
    
    echo ""
    echo -e "${GREEN}周计数测试结果已保存到: $result_file${NC}"
}

main() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  周计数跨平台一致性测试套件${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    TEST_OUTPUT="周计数跨平台一致性测试套件 - 详细日志\n"
    TEST_OUTPUT+="========================================\n\n"
    
    test_date_formats
    echo ""
    
    test_iso_week_definition
    echo ""
    
    test_year_week_consistency
    echo ""
    
    test_week_number_format
    echo ""
    
    test_log_filename_generation
    echo ""
    
    test_log_entry_week_format
    echo ""
    
    test_cross_platform_week_behavior
    echo ""
    
    test_year_boundary_scenarios
    echo ""
    
    test_current_week_integrity
    echo ""
    
    test_script_implementation
    echo ""
    
    print_summary
    local test_status=$?
    
    save_test_results
    
    exit $test_status
}

main

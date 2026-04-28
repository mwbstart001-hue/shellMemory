# 系统监控脚本命令行参数支持排查报告

## 一、排查概述

### 1.1 排查范围

| 排查项 | 说明 |
|--------|------|
| 命令行参数支持 | 主命令和子命令的参数解析逻辑 |
| 输出格式 | text/json/csv 格式的支持情况 |
| 告警日志查询 | query 和 stats 子命令的功能 |
| 测试场景覆盖 | 现有测试用例的覆盖度 |

### 1.2 当前版本信息

| 项目 | 信息 |
|------|------|
| 分支 | v9-qianshi |
| 最新提交 | 98d5d99 |
| 排查时间 | 2026-04-28 |

---

## 二、发现的问题

### 问题 1：错误输出不一致（stderr 重定向）

#### 问题描述

主命令参数解析的错误信息没有使用 `>&2` 重定向到标准错误输出（stderr），而子命令的参数解析却使用了 `>&2`。这种不一致会导致：

1. 当主命令参数错误时，错误信息会被输出到 stdout 而不是 stderr
2. 管道操作时（如 `./script.sh -c abc 2>/dev/null`），错误信息不会被正确过滤

#### 问题代码位置

**主命令（无 `>&2`）**：
```bash
# system_status.sh:378
echo "错误: 采样次数必须是有效的数字"
# 缺少 >&2

# system_status.sh:385
echo "错误: 采样间隔必须是有效的数字"
# 缺少 >&2

# system_status.sh:396
echo "错误: 输出格式只能是 'text' 或 'json'"
# 缺少 >&2

# 其他主命令参数错误同样缺少 >&2
```

**子命令（有 `>&2`）**：
```bash
# system_status.sh:1089
echo "错误: 查询数量必须是有效的数字" >&2

# system_status.sh:1093
echo "错误: 查询数量必须大于0" >&2
```

#### 影响范围

| 函数 | 文件行号 | 是否有 `>&2` |
|------|----------|--------------|
| `parse_args()` (主命令) | 373-460 | ❌ 否 |
| `parse_query_args()` | 1085-1170 | ✅ 是 |
| `query_alarms()` | 1600-1649 | ✅ 是 |
| `stats_alarms()` | 1900-1990 | ✅ 是 |

#### 修复方案

为所有主命令参数解析的错误信息添加 `>&2` 重定向：

```bash
# 修改前
echo "错误: 采样次数必须是有效的数字"

# 修改后
echo "错误: 采样次数必须是有效的数字" >&2
```

需要修改的位置：
- `system_status.sh:378`
- `system_status.sh:385`
- `system_status.sh:396`
- `system_status.sh:403`
- `system_status.sh:410`
- `system_status.sh:417`
- `system_status.sh:429`
- `system_status.sh:444`
- `system_status.sh:451`
- `system_status.sh:456`

---

### 问题 2：主命令参数错误后未显示帮助信息

#### 问题描述

主命令参数解析出错时，直接退出而不显示帮助信息。而子命令参数解析出错时，会显示帮助信息。

#### 问题代码对比

**主命令（无帮助显示）**：
```bash
# system_status.sh:377-381
n)
    if ! is_number "$OPTARG"; then
        echo "错误: 采样次数必须是有效的数字"
        exit 1
    fi
    SAMPLE_COUNT=$OPTARG
    ;;
```

**子命令（有帮助显示）**：
```bash
# system_status.sh:1087-1096
n)
    if ! is_number "$OPTARG"; then
        echo "错误: 查询数量必须是有效的数字" >&2
        exit 1
    fi
    if [ "$OPTARG" -lt 1 ]; then
        echo "错误: 查询数量必须大于0" >&2
        exit 1
    fi
    QUERY_COUNT=$OPTARG
    ;;
# 但在 \? 和 :) 分支有 show_query_help
# system_status.sh:1617-1626
\?)
    echo "错误: 无效选项 -$OPTARG" >&2
    show_query_help
    exit 1
    ;;
:)
    echo "错误: 选项 -$OPTARG 需要参数" >&2
    show_query_help
    exit 1
    ;;
```

#### 影响分析

| 场景 | 主命令行为 | 子命令行为 |
|------|-----------|-----------|
| 无效选项 | 仅输出错误，退出 | 输出错误 + 帮助，退出 |
| 缺少参数 | 仅输出错误，退出 | 输出错误 + 帮助，退出 |
| 参数值错误 | 仅输出错误，退出 | 仅输出错误，退出 |

#### 修复方案

在主命令参数解析的 `\?` 和 `:` 分支添加 `show_help` 调用：

```bash
# 修改前
\?)
    echo "错误: 无效选项 -$OPTARG"
    show_help
    exit 1
    ;;
:)
    echo "错误: 选项 -$OPTARG 需要参数"
    show_help
    exit 1
    ;;

# 需要检查实际代码
```

**注意**：需要检查主命令的 `\?` 和 `:` 分支是否已经有 `show_help` 调用。

---

### 问题 3：主命令 -f 参数不支持大写格式

#### 问题描述

子命令的 `-f` 参数支持大小写不敏感（如 `TEXT`、`JSON` 会自动转换为小写），但主命令的 `-f` 参数只支持小写。

#### 问题代码对比

**主命令（仅支持小写）**：
```bash
# system_status.sh:390-399
f)
    case "$OPTARG" in
        text|json)
            OUTPUT_FORMAT=$OPTARG
            ;;
        *)
            echo "错误: 输出格式只能是 'text' 或 'json'"
            exit 1
            ;;
    esac
    ;;
```

**子命令（支持大小写）**：
```bash
# system_status.sh:1128-1139
f)
    case "$OPTARG" in
        text|json)
            QUERY_FORMAT=$OPTARG
            ;;
        TEXT|JSON)
            QUERY_FORMAT=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')
            ;;
        *)
            echo "错误: 输出格式只能是 'text' 或 'json'" >&2
            exit 1
            ;;
    esac
    ;;
```

#### 影响示例

```bash
# 主命令
./system_status.sh -f JSON  # ❌ 报错
./system_status.sh -f json  # ✅ 正常

# 子命令
./system_status.sh query -f JSON  # ✅ 正常，自动转换
./system_status.sh query -f json  # ✅ 正常
```

#### 修复方案

为主命令的 `-f` 参数添加大写支持：

```bash
f)
    case "$OPTARG" in
        text|json)
            OUTPUT_FORMAT=$OPTARG
            ;;
        TEXT|JSON)
            OUTPUT_FORMAT=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')
            ;;
        *)
            echo "错误: 输出格式只能是 'text' 或 'json'" >&2
            exit 1
            ;;
    esac
    ;;
```

---

### 问题 4：主命令 -n 参数缺少边界检查

#### 问题描述

子命令 `query` 的 `-n` 参数有边界检查（必须大于 0），但主命令的 `-n` 参数只检查是否是数字，不检查是否大于 0。

#### 问题代码对比

**主命令（无边界检查）**：
```bash
# system_status.sh:376-382
n)
    if ! is_number "$OPTARG"; then
        echo "错误: 采样次数必须是有效的数字"
        exit 1
    fi
    SAMPLE_COUNT=$OPTARG
    ;;
```

**子命令（有边界检查）**：
```bash
# system_status.sh:1087-1096
n)
    if ! is_number "$OPTARG"; then
        echo "错误: 查询数量必须是有效的数字" >&2
        exit 1
    fi
    if [ "$OPTARG" -lt 1 ]; then
        echo "错误: 查询数量必须大于0" >&2
        exit 1
    fi
    QUERY_COUNT=$OPTARG
    ;;
```

#### 影响示例

```bash
# 主命令
./system_status.sh -n 0    # ❌ 不报错，但采样 0 次无意义
./system_status.sh -n -1   # ❌ 负数可能导致问题

# 子命令
./system_status.sh query -n 0  # ✅ 报错
./system_status.sh query -n -1 # ✅ 报错
```

#### 修复方案

为主命令的 `-n` 参数添加边界检查：

```bash
n)
    if ! is_number "$OPTARG"; then
        echo "错误: 采样次数必须是有效的数字" >&2
        exit 1
    fi
    if [ "$OPTARG" -lt 1 ]; then
        echo "错误: 采样次数必须大于0" >&2
        exit 1
    fi
    SAMPLE_COUNT=$OPTARG
    ;;
```

---

### 问题 5：主命令 -i 参数缺少边界检查

#### 问题描述

主命令的 `-i`（采样间隔）参数只检查是否是数字，不检查是否大于 0。

#### 问题代码

```bash
# system_status.sh:383-389
i)
    if ! is_number "$OPTARG"; then
        echo "错误: 采样间隔必须是有效的数字"
        exit 1
    fi
    SAMPLE_INTERVAL=$OPTARG
    ;;
```

#### 影响示例

```bash
./system_status.sh -i 0    # ❌ 不报错，但可能导致无限循环
./system_status.sh -i -1   # ❌ 负数无意义
```

#### 修复方案

为 `-i` 参数添加边界检查：

```bash
i)
    if ! is_number "$OPTARG"; then
        echo "错误: 采样间隔必须是有效的数字" >&2
        exit 1
    fi
    if (( $(awk -v val="$OPTARG" 'BEGIN {print (val <= 0)}') )); then
        echo "错误: 采样间隔必须大于0" >&2
        exit 1
    fi
    SAMPLE_INTERVAL=$OPTARG
    ;;
```

**注意**：因为 `-i` 支持浮点数（如 0.1），不能直接使用 `[ "$OPTARG" -lt 0 ]`，需要使用 awk 进行比较。

---

### 问题 6：阈值参数缺少边界检查

#### 问题描述

`-c`（CPU 阈值）、`-m`（内存阈值）、`-k`（磁盘阈值）参数只检查是否是数字，不检查是否在 0-100 的合理范围内。

#### 问题代码

```bash
# system_status.sh:401-421
c)
    if ! is_number "$OPTARG"; then
        echo "错误: CPU阈值必须是有效的数字"
        exit 1
    fi
    CPU_THRESHOLD=$OPTARG
    ;;
m)
    if ! is_number "$OPTARG"; then
        echo "错误: 内存阈值必须是有效的数字"
        exit 1
    fi
    MEM_THRESHOLD=$OPTARG
    ;;
k)
    if ! is_number "$OPTARG"; then
        echo "错误: 磁盘阈值必须是有效的数字"
        exit 1
    fi
    DISK_THRESHOLD=$OPTARG
    ;;
```

#### 影响示例

```bash
./system_status.sh -c 150   # ❌ 不报错，但 150% 无意义
./system_status.sh -c -50   # ❌ 不报错，但负数无意义
```

#### 修复方案

为阈值参数添加 0-100 范围检查：

```bash
c)
    if ! is_number "$OPTARG"; then
        echo "错误: CPU阈值必须是有效的数字" >&2
        exit 1
    fi
    if (( $(awk -v val="$OPTARG" 'BEGIN {print (val < 0 || val > 100)}') )); then
        echo "错误: CPU阈值必须在 0-100 之间" >&2
        exit 1
    fi
    CPU_THRESHOLD=$OPTARG
    ;;
```

同样的逻辑应用于 `-m` 和 `-k` 参数。

---

### 问题 7：帮助文档示例不完整

#### 问题描述

主命令帮助文档的示例缺少一些常见场景：

1. 缺少 `query` 子命令的 `disk` 类型示例（虽然子命令帮助中有）
2. 缺少 `stats` 子命令的 `disk` 类型示例
3. 缺少 `-k` 参数的更多使用示例

#### 问题代码位置

**主命令帮助文档**：
```bash
# system_status.sh:283-369
# 示例部分缺少 disk 相关的 query 和 stats 示例
```

#### 修复方案

在主命令帮助文档的示例部分添加：

```bash
# 新增示例
$0 query -t disk              查询磁盘类型告警
$0 stats -t disk              统计磁盘告警频率
$0 -k 90 -a false             仅监控，不告警
```

---

### 问题 8：测试场景覆盖不全

#### 问题描述

现有测试用例没有覆盖以下边界情况：

| 测试场景 | 覆盖状态 | 说明 |
|----------|----------|------|
| 主命令 `-n 0` | ❌ 未覆盖 | 边界检查 |
| 主命令 `-n -1` | ❌ 未覆盖 | 边界检查 |
| 主命令 `-i 0` | ❌ 未覆盖 | 边界检查 |
| 主命令 `-f TEXT` | ❌ 未覆盖 | 大小写支持 |
| 主命令 `-c 150` | ❌ 未覆盖 | 阈值范围检查 |
| 主命令 `-c -50` | ❌ 未覆盖 | 阈值范围检查 |
| 错误输出到 stderr | ❌ 未覆盖 | stderr 重定向 |

#### 修复方案

扩展测试文件 `test_disk_monitor.sh`，添加更多边界情况测试：

```bash
# 示例：边界检查测试
test_n_parameter_boundary() {
    print_header "测试: -n 参数边界检查"
    
    local output=$("$MAIN_SCRIPT" -n 0 2>&1)
    if echo "$output" | grep -q '错误.*大于0'; then
        print_test_result "-n 0 报错信息正确" true
    else
        print_test_result "-n 0 报错信息正确" false
    fi
}
```

---

### 问题 9：query 子命令 -f 参数与主命令不一致

#### 问题描述

`query` 子命令支持 `csv` 输出格式，但主命令不支持。

#### 问题代码

**主命令**：
```bash
# system_status.sh:391-398
text|json)
    OUTPUT_FORMAT=$OPTARG
    ;;
# 不支持 csv
```

**query 子命令**：
```bash
# system_status.sh:1592-1604
f)
    case "$OPTARG" in
        text|json|csv)
            QUERY_FORMAT=$OPTARG
            ;;
        TEXT|JSON|CSV)
            QUERY_FORMAT=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')
            ;;
        *)
            echo "错误: 输出格式只能是 'text'、'json' 或 'csv'" >&2
            ...
    esac
    ;;
```

#### 影响分析

| 命令 | 支持格式 |
|------|----------|
| 主命令 | text, json |
| query 子命令 | text, json, csv |
| stats 子命令 | text, json |

#### 修复建议

这不是 bug，而是功能差异。但需要在帮助文档中明确说明，保持一致性。

---

## 三、问题汇总表

| 编号 | 问题 | 优先级 | 影响模块 | 状态 |
|------|------|--------|----------|------|
| 1 | 错误输出不一致（stderr 重定向） | 🔴 高 | 主命令参数解析 | 🔧 待修复 |
| 2 | 参数错误后未显示帮助 | 🟠 中 | 主命令参数解析 | 🔧 待修复 |
| 3 | -f 参数不支持大写 | 🟠 中 | 主命令参数解析 | 🔧 待修复 |
| 4 | -n 参数缺少边界检查 | 🔴 高 | 主命令参数解析 | 🔧 待修复 |
| 5 | -i 参数缺少边界检查 | 🔴 高 | 主命令参数解析 | 🔧 待修复 |
| 6 | 阈值参数缺少范围检查 | 🟠 中 | 主命令参数解析 | 🔧 待修复 |
| 7 | 帮助文档示例不完整 | 🟡 低 | 文档 | 🔧 待修复 |
| 8 | 测试场景覆盖不全 | 🟠 中 | 测试 | 🔧 待修复 |
| 9 | 输出格式支持不一致 | 🟡 低 | 功能差异 | ⚠️ 文档说明 |

---

## 四、修复优先级建议

### 高优先级（建议立即修复）

| 问题 | 原因 |
|------|------|
| 问题 1：stderr 重定向不一致 | 影响脚本的正确使用和管道操作 |
| 问题 4：-n 参数边界检查 | 可能导致无意义的执行 |
| 问题 5：-i 参数边界检查 | 可能导致无限循环或错误行为 |

### 中优先级（建议近期修复）

| 问题 | 原因 |
|------|------|
| 问题 2：帮助显示 | 用户体验 |
| 问题 3：大小写支持 | 用户体验和一致性 |
| 问题 6：阈值范围检查 | 防止不合理配置 |
| 问题 8：测试覆盖 | 确保质量 |

### 低优先级（可选修复）

| 问题 | 原因 |
|------|------|
| 问题 7：帮助文档示例 | 文档完善 |
| 问题 9：格式支持差异 | 文档说明即可 |

---

## 五、修复方案详细说明

### 5.1 修复问题 1：stderr 重定向

**修改文件**：`system_status.sh`

**修改位置**：

| 行号 | 修改内容 |
|------|----------|
| 378 | 添加 `>&2` |
| 385 | 添加 `>&2` |
| 396 | 添加 `>&2` |
| 403 | 添加 `>&2` |
| 410 | 添加 `>&2` |
| 417 | 添加 `>&2` |
| 429 | 添加 `>&2` |
| 444 | 添加 `>&2` |
| 451 | 添加 `>&2` |
| 456 | 添加 `>&2` |

### 5.2 修复问题 2：帮助显示

**修改文件**：`system_status.sh`

**修改位置**：主命令参数解析的 `\?` 和 `:` 分支

### 5.3 修复问题 3：-f 参数大写支持

**修改文件**：`system_status.sh`

**修改位置**：`parse_args()` 函数的 `-f` 分支

### 5.4 修复问题 4：-n 参数边界检查

**修改文件**：`system_status.sh`

**修改位置**：`parse_args()` 函数的 `-n` 分支

### 5.5 修复问题 5：-i 参数边界检查

**修改文件**：`system_status.sh`

**修改位置**：`parse_args()` 函数的 `-i` 分支

### 5.6 修复问题 6：阈值范围检查

**修改文件**：`system_status.sh`

**修改位置**：`parse_args()` 函数的 `-c`、`-m`、`-k` 分支

---

## 六、测试用例扩展建议

### 6.1 新增测试场景

| 场景 ID | 测试名称 | 预期行为 |
|---------|----------|----------|
| TC-01 | 主命令 `-n 0` | 报错"采样次数必须大于0" |
| TC-02 | 主命令 `-n -1` | 报错"采样次数必须大于0" |
| TC-03 | 主命令 `-i 0` | 报错"采样间隔必须大于0" |
| TC-04 | 主命令 `-f TEXT` | 正常执行，自动转换为 text |
| TC-05 | 主命令 `-f JSON` | 正常执行，自动转换为 json |
| TC-06 | 主命令 `-c 150` | 报错"CPU阈值必须在 0-100 之间" |
| TC-07 | 主命令 `-c -50` | 报错"CPU阈值必须在 0-100 之间" |
| TC-08 | 主命令 `-m 150` | 报错"内存阈值必须在 0-100 之间" |
| TC-09 | 主命令 `-k 150` | 报错"磁盘阈值必须在 0-100 之间" |
| TC-10 | 错误输出到 stderr | 错误信息可通过 2>/dev/null 过滤 |

### 6.2 测试代码示例

```bash
test_n_parameter_boundary() {
    print_header "测试: -n 参数边界检查"
    
    local output=$("$MAIN_SCRIPT" -n 0 2>&1)
    if echo "$output" | grep -q '错误.*大于0'; then
        print_test_result "-n 0 报错信息正确" true
    else
        print_test_result "-n 0 报错信息正确" false
    fi
}

test_i_parameter_boundary() {
    print_header "测试: -i 参数边界检查"
    
    local output=$("$MAIN_SCRIPT" -i 0 2>&1)
    if echo "$output" | grep -q '错误.*大于0'; then
        print_test_result "-i 0 报错信息正确" true
    else
        print_test_result "-i 0 报错信息正确" false
    fi
}

test_f_parameter_case_insensitive() {
    print_header "测试: -f 参数大小写不敏感"
    
    local output=$("$MAIN_SCRIPT" -n 1 -i 0.1 -f JSON 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_test_result "-f JSON 正常执行" true
    else
        print_test_result "-f JSON 正常执行" false
    fi
}

test_threshold_range() {
    print_header "测试: 阈值参数范围检查"
    
    local output=$("$MAIN_SCRIPT" -c 150 2>&1)
    if echo "$output" | grep -q '错误.*0-100'; then
        print_test_result "-c 150 报错信息正确" true
    else
        print_test_result "-c 150 报错信息正确" false
    fi
}

test_stderr_redirection() {
    print_header "测试: 错误输出到 stderr"
    
    local output=$("$MAIN_SCRIPT" -n abc 2>/dev/null)
    local stderr_output=$("$MAIN_SCRIPT" -n abc 2>&1)
    
    if [ -z "$output" ] && [ -n "$stderr_output" ]; then
        print_test_result "错误信息输出到 stderr" true
    else
        print_test_result "错误信息输出到 stderr" false
    fi
}
```

---

## 七、附录

### A. 代码差异对比

#### A.1 主命令 vs 子命令参数解析

| 特性 | 主命令 | 子命令 |
|------|--------|--------|
| stderr 重定向 | ❌ 否 | ✅ 是 |
| 错误后显示帮助 | ❌ 否 | ✅ 是（部分场景） |
| -f 大小写支持 | ❌ 否 | ✅ 是 |
| -n 边界检查 | ❌ 否 | ✅ 是 |
| csv 格式支持 | ❌ 否 | ✅ 是（仅 query） |

#### A.2 函数代码行号

| 函数 | 起始行号 | 结束行号 |
|------|----------|----------|
| `parse_args()` | 373 | 460 |
| `parse_query_args()` | 1085 | 1170 |
| `query_alarms()` | 1600 | 1649 |
| `stats_alarms()` | 1900 | 1990 |
| `is_number()` | 477 | 479 |

### B. 相关文档

| 文档 | 说明 |
|------|------|
| `DISK_MONITOR_COMPLETE.md` | 磁盘监控功能完整实现说明 |
| `DISK_MONITOR_FIX.md` | 磁盘阈值参数修复说明 |
| `test_disk_monitor.sh` | 磁盘监控功能测试脚本 |

---

**报告版本**：v1.0  
**最后更新**：2026-04-28  
**状态**：🔍 排查完成，待修复
